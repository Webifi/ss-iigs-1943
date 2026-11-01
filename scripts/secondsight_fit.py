"""The fitter of the Second Sight link: it puts the asset sections into the
free space of src/secondsight/secondsight.ld and into free video RAM.

The Makefile links twice:
    secondsight_fit.py park PLACEMENTS FIT OBJECT...
        writes PLACEMENTS, which parks the asset sections for the first link
        (each at its run address, loading nothing).
    secondsight_fit.py place PLACEMENTS FIT FIRST_LINK OBJECT...
        reads the free spaces of the first link (the fit_NAME__* symbols of
        secondsight.ld) and writes PLACEMENTS for the final link.
FIT is build/secondsight/gen/fit.txt from the asset builder: its lines are
    pin SECTION ADDRESS   a section at a place of the memory map
    run SECTION RUN       the run address (a number or a symbol) of a plane section
    vram START END        free video RAM [START, END)

The allocator packs each asset section into the free space where its kind may
live, largest first into the tightest free space, and keeps the rules of the
kind (one 4 KB page, one 8 KB view, one video RAM window). It stops with a
report when a section has no place. A section's size does not change with
its address, so the first link gives the final free space.

Addresses are load addresses: 0x100000 + physical SRAM, or linear video RAM.
"""

import re
import sys
from pathlib import Path

import elf32

SRAM = 0x100000  # load address of SRAM byte 0 (secondsight.ld load_sram)
PLANE = 0x200000  # plane space: PLANE + plane * 0x40000 + group
PAGE = 0x1000  # an MMU page
VIEW = 0x2000  # the bank area at $C000 shows 8 KB of SRAM

# The kinds of placeable sections, by name prefix (secondsight.ld FIT_KIND):
#   record:  banked data read through the bank area; stays in one 4 KB page.
#   entries: banked data copied in 16-byte pieces through the 8 KB bank area.
#   group:   a glyph group program; common SRAM, or the pattern view.
#   rows:    the glyph row programs; the pattern view.
#   common:  data or code that the CPU reads at its physical address.
#   vram:    linear video RAM; .vram.bN_aA_kK.NAME stays inside one window
#            of N groups (4 bytes each), aligned to A, out of the first K
#            groups of each 64K-group segment.
KINDS = (
    (".vram.", "vram"),
    (".common.", "common"),
    (".desc.", "record"),
    (".fonts.", "entries"),
    (".cab_group.", "group"),
    (".cab_rows", "rows"),
)


class Space:
    """Free card memory: [start, end) load addresses, the kinds it takes, the
    label of a record at its start, and the 8 KB view of its pattern code."""

    def __init__(self, name, start, end, kinds, label=None, view=None):
        self.name = name
        self.free = [[start, end]]
        self.kinds = kinds
        self.run = (start if label is None else label) - start  # record label - load address
        self.view = view  # pattern code: (load base, run base); it stays in one 8 KB view

    def fits(self, size, align, kind, window=None, keep=0):
        """Free intervals and the first address in each that takes SIZE."""
        for interval in self.free:
            end = interval[1]
            if self.view and kind in ("group", "rows"):
                end = min(end, self.view[0] + VIEW)
            at = (interval[0] + align - 1) & -align
            # Keep out of the first KEEP groups of each 64K-group segment.
            if keep and (at >> 2) & 0xFFFF < keep:
                at = (((at >> 18) << 18) + keep * 4 + align - 1) & -align
            boundary = PAGE if kind == "record" else window
            if boundary and size <= boundary and (at & (boundary - 1)) + size > boundary:
                at = (at + boundary - 1) & -boundary
            if at + size <= end:
                yield interval, at

    def take(self, interval, at, size):
        self.free.remove(interval)
        self.free += [r for r in ([interval[0], at], [at + size, interval[1]]) if r[0] < r[1]]
        self.free.sort()

    def run_address(self, at, kind):
        if kind in ("group", "rows") and self.view:
            base, run = self.view
            return run + at - base
        if kind in ("group", "common"):
            return at - SRAM  # common SRAM: the CPU address is the physical one
        if kind == "vram":
            return at
        return at + self.run


def kind_of(name):
    return next((kind for prefix, kind in KINDS if name.startswith(prefix)), None)


def placeable(name):
    return name.startswith((".plane.", ".vram_area.", ".fixed.")) or kind_of(name) is not None


def read_fit(path):
    """The pins, the runs and the free video RAM of fit.txt."""
    pinned, runs, free_vram = {}, {}, []
    for line in Path(path).read_text().splitlines():
        words = line.split()
        if not words or words[0].startswith("#"):
            continue
        if words[0] == "pin":
            pinned[words[1]] = int(words[2], 0)
        elif words[0] == "run":
            runs[words[1]] = words[2]
        elif words[0] == "vram":
            free_vram.append((int(words[1], 0), int(words[2], 0)))
        else:
            raise SystemExit(f"{path}: unknown line: {line}")
    return pinned, runs, free_vram


def free_spaces(first_link, free_vram):
    """The free spaces of the first link (fit_NAME__* symbols), then the free
    video RAM of the asset builder."""
    symbols = elf32.global_symbols(Path(first_link))
    flags = {kind: symbols[f"FIT_{kind.upper()}"] for kind in ("record", "entries", "group", "rows", "common")}
    spaces = []
    for name in sorted({m.group(1) for m in map(re.compile(r"fit_(\w+)__start$").match, symbols) if m}):
        value = {key: symbols.get(f"fit_{name}__{key}") for key in ("start", "end", "label", "kinds", "align", "view")}
        align = value["align"] or 1
        start = (value["start"] + align - 1) & -align
        label = value["label"] + start - value["start"]
        view = (start, value["view"]) if value["view"] is not None else None
        kinds = {kind for kind, flag in flags.items() if value["kinds"] & flag}
        spaces.append(Space(name, start, value["end"], kinds, label, view))
    spaces.sort(key=lambda space: space.free[0][0])
    return spaces + [Space(f"video RAM {lo:05X}", lo, hi, {"vram"}) for lo, hi in free_vram]


def place(sections, spaces, pinned, runs):
    """SECTIONS: (object, section name, size, alignment). The output section
    lines that place each."""
    # A video RAM block is as large as its fullest plane: the groups of its
    # plane sections (.plane.BLOCK.PLANE.PART).
    plane_groups = {}
    for _, name, size, _ in sections:
        if name.startswith(".plane."):
            _, _, block, plane, _ = name.split(".")
            groups = plane_groups.setdefault(block, {})
            groups[plane] = groups.get(plane, 0) + size
    items = []
    for obj, name, size, align in sections:
        if name.startswith(".vram."):
            size = max([size] + [4 * groups for groups in plane_groups.get(name.split(".")[-1], {}).values()])
        kind = kind_of(name)
        window = keep = None
        if kind == "vram":
            rule = {part[0]: int(part[1:]) for part in name.split(".")[2].split("_")}
            # A section larger than its window stays inside one 64 KB segment.
            window = 4 * rule["b"]
            window = window if size <= window else 0x10000
            align = max(align, rule.get("a", 4))
            keep = rule.get("k", 0)
        if kind and size and name not in pinned:
            items.append((kind, obj, name, size, max(align, 1), window, keep))
    # Pattern code first: it must share one 8 KB view. Then largest first.
    order = {"rows": 0, "group": 1, "entries": 2, "record": 2, "common": 2, "vram": 2}
    items.sort(key=lambda item: (order[item[0]], -item[3], item[2]))
    placed = {}
    lines = ["/* Generated by scripts/secondsight_fit.py: the placed asset sections. */"]
    for obj, name, _, _ in sections:
        if name in pinned:
            placed[name] = pinned[name]
            lines.append(f"  .asset.{name[1:].replace('.', '_')} 0x{pinned[name]:X} : AT(0x{pinned[name]:X}) {{ {obj}({name}) }}")
    for i, (kind, obj, name, size, align, window, keep) in enumerate(items):
        options = [
            (interval[1] - interval[0], space, interval, at)
            for space in spaces
            if kind in space.kinds
            for interval, at in space.fits(size, align, kind, window, keep)
        ]
        if kind == "group":
            # Common SRAM first: a call there needs no bank.
            options.sort(key=lambda o: (o[1].view is not None, o[0]))
        else:
            options.sort(key=lambda o: o[0])
        if not options:
            report = "\n".join(
                f"  {s.name}: " + ", ".join(f"0x{a:X}-0x{b:X} ({b - a})" for a, b in s.free) for s in spaces
            )
            raise SystemExit(f"no free card memory for {name} ({kind}, {size} bytes). Free:\n{report}")
        _, space, interval, at = options[0]
        space.take(interval, at, size)
        placed[name] = at
        lines.append(f"  .asset.p{i} 0x{space.run_address(at, kind):X} : AT(0x{at:X}) {{ {obj}({name}) }}")
    # The plane sections of each placed video RAM block. A plane section runs
    # at its load address, or at the run address (a number or a symbol of
    # secondsight.ld) that the asset builder gives it.
    parts = {}
    for obj, name, size, _ in sections:
        if name.startswith(".plane."):
            _, _, block, plane, order = name.split(".")
            parts.setdefault(block, []).append((int(plane), int(order), obj, name, size))
    for block, pieces in sorted(parts.items()):
        base = next((at for key, at in placed.items() if key.split(".")[-1] == block), None)
        if base is None:
            raise SystemExit(f"plane sections of {block} have no block")
        used = {}
        for plane, _, obj, name, size in sorted(pieces, key=lambda part: part[:2]):
            load = PLANE + plane * 0x40000 + (base >> 2) + used.get(plane, 0)
            used[plane] = used.get(plane, 0) + size
            run = runs.get(name, f"0x{load:X}")
            lines.append(f"  .asset.{block}.{plane}.{used[plane]} {run} : AT(0x{load:X}) {{ {obj}({name}) }}")
    return lines


def park(sections, pinned, runs):
    """The output section lines of the first link: every asset section at its
    run address (a pin or a run of the asset builder) or at 0, loading nothing."""
    lines = ["/* Generated by scripts/secondsight_fit.py: the asset sections, parked for the first link. */"]
    for i, (obj, name, _, _) in enumerate(sections):
        if placeable(name):
            run = runs.get(name, f"0x{pinned[name]:X}" if name in pinned else "0x0")
            lines.append(f"  .park.{i} {run} (NOLOAD) : {{ {obj}({name}) }}")
    return lines


def main(args):
    if len(args) >= 3 and args[0] == "park":
        command, placements, fit, objects = args[0], args[1], args[2], args[3:]
    elif len(args) >= 4 and args[0] == "place":
        command, placements, fit, first_link, objects = args[0], args[1], args[2], args[3], args[4:]
    else:
        raise SystemExit("usage: secondsight_fit.py park PLACEMENTS FIT OBJECT... | place PLACEMENTS FIT FIRST_LINK OBJECT...")
    pinned, runs, free_vram = read_fit(fit)
    sections = [(obj, *part) for obj in objects for part in elf32.section_list(Path(obj))]
    if command == "park":
        lines = park(sections, pinned, runs)
    else:
        lines = place(sections, free_spaces(first_link, free_vram), pinned, runs)
    Path(placements).write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main(sys.argv[1:])
