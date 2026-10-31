"""The linker script of the Second Sight code, from the memory map and the
assembled objects.

src/card/memory.toml gives the regions of code and data. The assembled
objects give the size and alignment of every section; a section's size does
not change with its address. The allocator packs each other section into the
free space where its kind may live, largest first into the tightest free
space. It stops with a report when a section has no place.

Addresses are load addresses: 0x100000 + physical SRAM, or linear video RAM.

Command (the Makefile runs it): card_layout.py BUILD OBJECT... writes
BUILD/card.ld and BUILD/gen/placements.ld.
"""

import json
import re
import sys
import tomllib
from pathlib import Path

MAP = Path(__file__).resolve().parents[1] / "src/card/memory.toml"
SRAM = 0x100000
NOLOAD = 0x400000  # load addresses of code that no card load record writes
PAGE = 0x1000
VIEW = 0x2000  # the bank area at $C000 shows 8 KB of SRAM

# Kinds of placeable sections, by name.
#   record:  banked data read through the bank area; stays in one 4 KB page.
#   entries: banked data that the card copies in 16-byte pieces through the
#            8 KB bank area; may cross a page.
#   group:   a glyph group program; common SRAM, or the pattern view.
#   rows:    the glyph row programs; the pattern view.
#   common:  data or code that the CPU reads at its physical address in
#            common SRAM.
#   vram:    linear video RAM (addresses 0x000000-0x0FFFFF); .vram.bN.NAME
#            stays inside one window of N groups (4 bytes each).
KINDS = (
    (".vram.", "vram"),
    (".common.", "common"),
    (".desc.", "record"),
    (".fonts.", "entries"),
    (".cab_group.", "group"),
    (".cab_rows", "rows"),
)


class Space:
    """Free card memory: [start, end) load addresses, the kinds it takes,
    and how its run addresses follow from its load addresses."""

    def __init__(self, name, start, end, kinds, run=0, view=None):
        self.name = name
        self.free = [[start, end]]
        self.kinds = kinds
        self.run = run  # run address = load address + run, for data
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


PLANE = 0x200000  # plane address space: PLANE + plane * 0x40000 + group
runs = {}  # plane section name -> run address, for code that runs elsewhere
pinned = {}  # section name -> load address, for data at a place of the memory map
free_vram = None  # function: the free video RAM ranges, read at link time


def memory_map():
    """src/card/memory.toml: the regions, the layout symbols and the checks."""
    return tomllib.loads(MAP.read_text())


def region(name):
    """The entry of region NAME of the memory map."""
    return next(r for r in memory_map()["region"] if r["name"] == name)


def symbol_name(region):
    return region.replace("-", "_")


def code_regions(section, only=None):
    """The output sections of the regions of the memory map, the free spaces
    in them, the place of each section, and the region symbols.
    SECTION(source, name) returns (object file, size, alignment). With
    ONLY, the region of that name alone.

    A region with "run" holds code: its labels are run (CPU) addresses. A
    region without "run" holds data: its labels are load addresses."""
    lines, free, places, symbols = [], [], {}, {}
    for region in memory_map()["region"]:
        if only and region["name"] != only:
            continue
        load = region.get("load")
        base = address = region.get("run", load)
        parts = places.setdefault(region["name"], [])
        for i, entry in enumerate(region["sections"]):
            words = entry.split()
            if words[0] in ("at", "limit"):
                value = int(words[1], 0)
                if address > value:
                    raise RuntimeError(f"{region['name']}: the code before \"{entry}\" ends at 0x{address:X}")
                if words[0] == "at":
                    address = value
                continue
            if words[0] == "free":
                _, name, kinds, end = words[:4]
                options = dict(zip(words[4::2], (int(v, 0) for v in words[5::2])))
                align = options.get("align", 1)
                start = (address + align - 1) & -align
                lo = load + start - base
                view = (lo, options["view"]) if "view" in options else None
                # Data labels hold the load address of the place where the
                # data is at run time: a staged region loads elsewhere.
                run = SRAM + start - lo if "run" in region else 0
                free.append(Space(name, lo, load + int(end, 0) - base, set(kinds.split(",")), run, view))
                address = int(end, 0)
                continue
            source, name = words[0], words[1]
            options = dict(zip(words[2::2], (int(v, 0) for v in words[3::2])))
            obj, size, align = section(source, name)
            if "run" in options:
                vma = options["run"]
            elif "window" in options:
                vma = options["window"] + address - base
            else:
                vma = address
            pad = -vma % max(align, 1)
            lma = NOLOAD + address if load is None else load + address - base
            out = f".{region['name']}.{i}"
            lines.append(f"  {out} 0x{vma:X} : AT(0x{lma:X}) {{ {obj}({name}) }}")
            parts.append((out, address, pad + size, vma + pad, obj, name))
            address += pad + size
        if address > region["limit"]:
            raise RuntimeError(f"{region['name']}: the code ends at 0x{address:X}, after its limit 0x{region['limit']:X}")
        prefix = symbol_name(region["name"])
        symbols[f"{prefix}__run"] = base
        symbols[f"{prefix}__end"] = max((a + s for _, a, s, _, _, _ in parts), default=base)
        symbols[f"{prefix}__limit"] = region["limit"]
        symbols[f"{prefix}__size"] = region["limit"] - base
        if load is not None:
            symbols[f"{prefix}__load"] = load
    return lines, free, places, symbols


def placeable(name):
    """True for a section that the allocator or a pin places."""
    return name.startswith((".plane.", ".vram_area.", ".fixed.")) or any(
        name.startswith(prefix) for prefix, _ in KINDS
    )


def checks():
    """The ld ASSERT lines of the [[check]] entries of the memory map."""
    return [f'ASSERT({c["expression"]}, "{c["message"]}")' for c in memory_map().get("check", [])]


def spaces():
    """The free video RAM. The free SRAM comes from the memory map."""
    return [Space(f"video RAM {lo:05X}", lo, hi, {"vram"}) for lo, hi in (free_vram() if free_vram else [])]


def place(sections, spaces, path):
    """SECTIONS: (object, section name, size, alignment). Write the placement
    of each into PATH; return {section name: (run, load)}."""
    items = []
    for obj, name, size, align in sections:
        kind = next((k for prefix, k in KINDS if name.startswith(prefix)), None)
        window = keep = None
        if kind == "vram":
            rule = dict((part[0], int(part[1:])) for part in name.split(".")[2].split("_"))
            # A section larger than its window stays inside one 64 KB segment.
            window = 4 * rule["b"]
            window = window if size <= window else 0x10000
            align = max(align, rule.get("a", 4))
            keep = rule.get("k", 0)
        if kind and size:
            items.append((kind, obj, name, size, max(align, 1), window, keep))
    # Pattern code first: it must share one 8 KB view. Then largest first.
    order = {"rows": 0, "group": 1, "entries": 2, "record": 2, "common": 2, "vram": 2}
    items.sort(key=lambda item: (order[item[0]], -item[3], item[2]))
    placed = {}
    lines = ["/* Generated by scripts/card_layout.py: the placed card sections. */"]
    for obj, name, size, _ in sections:
        if name in pinned:
            placed[name] = (pinned[name], pinned[name])
            lines.append(f"  .asset.{name[1:].replace('.', '_')} 0x{pinned[name]:X} : AT(0x{pinned[name]:X}) {{ {obj}({name}) }}")
    items = [item for item in items if item[2] not in pinned]
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
                f"  {s.name}: " + ", ".join(f"{a:06X}-{b:06X} ({b - a})" for a, b in s.free)
                for s in spaces
            )
            raise RuntimeError(f"no free card memory for {name} ({kind}, {size} bytes). Free:\n{report}")
        _, space, interval, at = options[0]
        space.take(interval, at, size)
        run = space.run_address(at, kind)
        placed[name] = (run, at)
        lines.append(f"  .asset.p{i} 0x{run:X} : AT(0x{at:X}) {{ {obj}({name}) }}")
    # The plane sections of each placed video RAM block.
    parts = {}
    for obj, name, size, align in sections:
        if name.startswith(".plane."):
            _, _, block, plane, order = name.split(".")
            parts.setdefault(block, []).append((int(plane), int(order), obj, name, size))
    for block, pieces in sorted(parts.items()):
        base = next((run for key, (run, _) in placed.items() if key.split(".")[-1] == block), None)
        if base is None:
            raise RuntimeError(f"plane sections of {block} have no block")
        group = base >> 2
        used = {}
        for plane, _, obj, name, size in sorted(pieces, key=lambda part: part[:2]):
            load = PLANE + plane * 0x40000 + group + used.get(plane, 0)
            used[plane] = used.get(plane, 0) + size
            run = runs.get(name, load)
            placed[name] = (run, load)
            lines.append(f"  .asset.{block}.{plane}.{used[plane]} 0x{run:X} : AT(0x{load:X}) {{ {obj}({name}) }}")
        block_size = next(size for _, n, size, _ in sections if n.split(".")[-1] == block and n.startswith(".vram."))
        if max(used.values()) > block_size // 4:
            raise RuntimeError(f"plane sections of {block} exceed it: {used}, {block_size // 4} groups")
    path.write_text("\n".join(lines) + "\n")
    report = ", ".join(f"{s.name} {sum(b - a for a, b in s.free)}" for s in spaces)
    print(f"Card layout: {len(placed)} sections placed; free bytes: {report}", flush=True)
    return placed


def link_script(build, objects):
    """Write BUILD/card.ld for OBJECTS (paths as ld gets them)."""
    import elf32
    from asset_source import derive, formulas

    global free_vram
    layout = json.loads((build / "gen/layout.json").read_text())
    pinned.update(layout["pinned"])
    runs.update(layout["runs"])
    free_vram = lambda: [tuple(r) for r in layout["free_vram"]]
    by_source = {}
    for obj in objects:
        stem = Path(obj).stem
        by_source["gen/" + stem[4:] if stem.startswith("gen_") else stem] = obj
    lists = {obj: elf32.section_list(Path(obj)) for obj in objects}

    def section(source, name):
        obj = by_source[source]
        size, align = next((s, a) for n, s, a in lists[obj] if n == name)
        return obj, size, align

    lines, free, _, regions = code_regions(section)
    defined, undefined = set(), set()
    for obj in objects:
        table, _ = elf32.read_object(Path(obj))
        for name, (_, where, bind, _) in table.items():
            if bind == "GLOBAL":
                (undefined if where == "UND" else defined).add(name)
    given = set()
    for part in ("defines.ld", "formulas.ld"):
        given |= set(re.findall(r"^(\w+) =", (build / "gen" / part).read_text(), re.M))
    symbols = dict(memory_map()["symbols"], **regions)
    clash = sorted(set(symbols) & (defined | given))
    if clash:
        raise SystemExit(f"src/card/memory.toml defines symbols that the build defines: {clash}")
    for name in sorted(undefined - defined - given - set(symbols)):
        derive(name)  # else ld reports it if a kept section uses it
    sections = [(obj, *part) for obj in objects for part in lists[obj]]
    place(sections, spaces() + list(free), build / "gen/placements.ld")
    (build / "card.ld").write_text(
        "/* Generated by scripts/card_layout.py from src/card/memory.toml. */\n"
        'INCLUDE "src/card/variables.ld"\n'
        + "".join(f"{name} = 0x{value:x};\n" for name, value in sorted(symbols.items()))
        + "INCLUDE defines.ld\nSECTIONS\n{\n"
        + "\n".join(lines)
        + "\n  INCLUDE placements.ld"
        + "\n  /DISCARD/ : { *(.text*) *(.rodata*) *(.data*) *(.bss*) }\n}\n"
        # Derived symbols follow the sections that place their labels.
        + "INCLUDE formulas.ld\n"
        + formulas()
        + "".join(f"{line}\n" for line in checks())
    )


if __name__ == "__main__":
    link_script(Path(sys.argv[1]), sys.argv[2:])

