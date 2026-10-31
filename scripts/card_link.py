"""Generated sources of the Second Sight code (src/card), and the final link.

The asset builder writes its sources into build/card/gen with generate().
final_link() writes the layout inputs, runs "make card" (assemble each
source, place the sections with scripts/card_layout.py, link with ld) and
reads build/card/card.elf: the load records take their bytes from it.
"""

import json
import os
import subprocess
import sys

import elf32
from roms import ROOT
from toolchain import z80

SOURCE = ROOT / "src/card"
OUT = ROOT / "build/card"
GENERATED = OUT / "gen"
_objects = {}
_generated = []  # names of the generated sources of this build
_defines = {}  # values that the asset builder computes, for the final link
_aliases = {}  # layout symbol -> linker expression of asset labels
_linked = None  # output section name -> bytes, set by final_link
_symbols = None  # global symbol -> value of card.elf, set by final_link
_loads = []  # (load address, bytes) of the loaded output sections, set by final_link
_places = {}  # memory map region -> its placed sections, set by final_link
NOLOAD = 0x400000  # load addresses of code that no card load record writes


class Late:
    """SIZE card bytes that are known only after the final link."""

    def __init__(self, size, make):
        self.size = size
        self.make = make

    def __len__(self):
        return self.size

    def __bytes__(self):
        data = bytes(self.make())
        assert len(data) == self.size, (len(data), self.size)
        return data

    def __getitem__(self, part):
        start, stop, step = part.indices(self.size)
        assert step == 1
        return Late(stop - start, lambda: bytes(self)[start:stop])

    def __add__(self, other):
        return Late(self.size + len(other), lambda: bytes(self) + bytes(other))

    def __radd__(self, other):
        return Late(len(other) + self.size, lambda: bytes(other) + bytes(self))


class Block:
    """SIZE bytes of card memory: zero, then each write in order. A write can
    hold Late bytes."""

    def __init__(self, size):
        self.size = size
        self.writes = []

    def __len__(self):
        return self.size

    def write(self, offset, data):
        assert 0 <= offset and offset + len(data) <= self.size
        self.writes.append((offset, data))

    def __bytes__(self):
        out = bytearray(self.size)
        for offset, data in self.writes:
            out[offset : offset + len(data)] = bytes(data)
        return bytes(out)


def _region(name):
    """(start, end) of region NAME: its first address and the end of its last
    section. The sizes of the sections do not depend on their addresses, so
    this is known before the final link."""
    import card_layout

    _, _, _, symbols = card_layout.code_regions(_map_section, only=name)
    prefix = card_layout.symbol_name(name)
    return symbols[f"{prefix}__run"], symbols[f"{prefix}__end"]


def region_image(name):
    """The bytes of region NAME of the memory map in the final link, from its
    first address to the end of its last section; zero between sections."""
    if _linked is None:
        raise RuntimeError("the final card link has not run")
    start, end = _region(name)
    data = bytearray(end - start)
    for out, address, size, _, _, _ in _places[name]:
        part = _linked.get(out, b"")
        assert len(part) == size, (out, len(part), size)
        data[address - start : address - start + size] = part
    return bytes(data)


def region_bytes(name, address, size):
    """SIZE bytes of region NAME at its run ADDRESS, from the final link."""
    start, _ = _region(name)
    return region_image(name)[address - start : address - start + size]


def region_late(name):
    """Late bytes of region NAME: region_image after the final link."""
    start, end = _region(name)
    return Late(end - start, lambda: region_image(name))


def generate(name, text):
    """Write build/card/gen/NAME.s, the source "gen/NAME" of this build."""
    GENERATED.mkdir(parents=True, exist_ok=True)
    path = GENERATED / f"{name}.s"
    if not (path.exists() and path.read_text() == text):
        path.write_text(text)
        _objects.pop(f"gen/{name}", None)
    if name not in _generated:
        _generated.append(name)
    return f"gen/{name}"


def generate_include(name, text):
    """Write build/card/gen/NAME.inc for `.include "NAME.inc"` in card sources."""
    path = GENERATED / f"{name}.inc"
    if path.exists() and path.read_text() == text:
        return
    GENERATED.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    _objects.clear()


def _path(source):
    return GENERATED / f"{source[4:]}.s" if source.startswith("gen/") else SOURCE / f"{source}.s"


def object_path(source):
    """build/card/NAME.o for src/card/NAME.s, build/card/gen_NAME.o for gen/NAME."""
    return OUT / (source.replace("/", "_") + ".o")


def assemble(source):
    """Object file and tables of SOURCE: symbols and relocations. The command
    is the one of the Makefile, so make takes the object as up to date."""
    if source in _objects:
        return _objects[source]
    OUT.mkdir(parents=True, exist_ok=True)
    obj = object_path(source)
    subprocess.run(
        [
            z80("as"),
            "-march=z180",
            "--fatal-warnings",
            "-I",
            "src/card/include",
            "-I",
            "build/card/gen",
            "--MD",
            str(obj.with_suffix(".d").relative_to(ROOT)),
            "-o",
            str(obj.relative_to(ROOT)),
            str(_path(source).relative_to(ROOT)),
        ],
        check=True,
        cwd=ROOT,
    )
    symbols, relocs = elf32.read_object(obj)
    _objects[source] = (obj, symbols, relocs)
    return _objects[source]


def define(name, value):
    """Set the symbol NAME to a value of the asset builder in the final link."""
    _defines[name] = value


def alias(name, expression):
    """Define the layout symbol NAME in the final link as EXPRESSION of asset
    labels and derived symbols (asset_source)."""
    _defines.pop(name, None)
    _aliases[name] = expression


def asset(name, source):
    """Write an asset_source.Source as build/card/gen/NAME.s. The memory map
    or the allocator places its sections."""
    return generate(name, source.text())


def symbol(name):
    """The value of a global symbol of card.elf."""
    if _symbols is None:
        raise RuntimeError("the final card link has not run")
    return _symbols[name]


def export_host(path):
    """Write the global symbols of card.elf as ca65 constants, card_NAME."""
    lines = [f"card_{k} = ${v:06X}" for k, v in sorted(_symbols.items()) if k.isidentifier()]
    path.write_text("; Generated from build/card/card.elf: the card symbols.\n" + "\n".join(lines) + "\n")


def section_sizes(source):
    """The size of each section of an assembled source."""
    obj, _, _ = assemble(source)
    return {name: size for name, size, _ in elf32.section_list(obj)}


def _map_section(source, name):
    """(object file, size, alignment) of section NAME of SOURCE."""
    obj, _, _ = assemble(source)
    size, align = next((s, a) for n, s, a in elf32.section_list(obj) if n == name)
    return obj, size, align


_later = []  # (name, function that returns a Source) for the final link
_after = []  # functions that use the card symbols, run after the final link


def after_link(function):
    """Run FUNCTION after the final link: host data that holds card addresses."""
    _after.append(function)


def run_after_link():
    for function in _after:
        function()


def asset_later(name, make):
    """Add the Source that MAKE returns to the final link, after the build has
    added every part of it."""
    _later.append((name, make))


_fixed = {}  # load address -> byte: data at fixed places of the card memory map


def load(address, data):
    """DATA at card load ADDRESS (0x100000 + physical SRAM, or video RAM). The
    final link places it there; a later load of the same byte wins."""
    for i, value in enumerate(bytes(data)):
        _fixed[address + i] = value


def _zero_gaps(free, places):
    """The bytes between the sections of a loaded code region start as zero,
    where no other data and no free space of the allocator lives."""
    import card_layout

    spaces = [(lo, hi) for space in free for lo, hi in space.free]
    for region in card_layout.memory_map()["region"]:
        load = region.get("load")
        if load is None:
            continue
        base = region.get("run", load)
        end = max((address + size for _, address, size, _, _, _ in places[region["name"]]), default=base)
        covered = bytearray(end - base)
        for _, address, size, _, _, _ in places[region["name"]]:
            covered[address - base : address - base + size] = b"\1" * size
        for offset in range(end - base):
            address = load + offset
            if not covered[offset] and address not in _fixed and not any(lo <= address < hi for lo, hi in spaces):
                _fixed[address] = 0


def _fixed_source():
    """One section for each run of fixed bytes, pinned at its address."""
    import card_layout
    from asset_source import Source

    source = Source("data at fixed places of the card memory map")
    runs = []
    for address in sorted(_fixed):
        if runs and runs[-1][0] + len(runs[-1][1]) == address and address != 0x100000:
            runs[-1][1].append(_fixed[address])
        else:
            runs.append((address, bytearray((_fixed[address],))))
    for i, (address, data) in enumerate(runs):
        name = f".fixed.{i}"
        card_layout.pinned[name] = address
        source.section(name).data(data)
    return source


def asset_loads():
    """(load address, bytes) of each loaded output section of card.elf."""
    if _linked is None:
        raise RuntimeError("the final card link has not run")
    return list(_loads)


def _layout_inputs():
    """The files that "make card" reads besides the sources: the generated
    sources of this build, the places that the asset builder chose, and its
    symbols."""
    import card_layout
    from asset_source import formulas

    names = " ".join(_generated)
    (GENERATED / "sources.mk").write_text(f"# Generated by scripts/card_link.py.\nGENERATED := {names}\n")
    free_vram = card_layout.free_vram() if card_layout.free_vram else []
    layout = dict(pinned=card_layout.pinned, runs=card_layout.runs, free_vram=free_vram)
    (GENERATED / "layout.json").write_text(json.dumps(layout, indent=1, sort_keys=True) + "\n")
    (GENERATED / "defines.ld").write_text(
        "/* Generated by scripts/card_link.py: values of the asset builder. */\n"
        + "".join(f"{name} = 0x{value:x};\n" for name, value in sorted(_defines.items()))
    )
    (GENERATED / "formulas.ld").write_text(
        "/* Generated by scripts/card_link.py: layout symbols of the asset builder. */\n"
        + "".join(f"{name} = {expression};\n" for name, expression in sorted(_aliases.items()))
        + formulas()
    )


def final_link():
    """Write the last generated sources and the layout inputs, run "make card"
    and read build/card/card.elf."""
    global _linked, _symbols
    import card_layout

    for name, make in _later:
        asset(name, make())
    _, free, places, _ = card_layout.code_regions(_map_section)
    _zero_gaps(free, places)
    if _fixed:
        asset("fixed_loads", _fixed_source())
    _layout_inputs()
    subprocess.run(["make", f"-j{os.cpu_count()}", "card", f"PYTHON={sys.executable}"], check=True, cwd=ROOT)
    elf = OUT / "card.elf"
    _linked = elf32.sections(elf)
    _symbols = elf32.global_symbols(elf)
    _places.clear()
    _places.update(card_layout.code_regions(_map_section)[2])
    # Every placeable section must be placed: the map lists the discarded
    # ones (name, address, size, file) before the memory configuration.
    discarded = (OUT / "card.map").read_text().split("Memory Configuration")[0].splitlines()
    lost = [
        part[0]
        for part in map(str.split, discarded)
        if len(part) == 4 and card_layout.placeable(part[0]) and int(part[2], 16)
    ]
    if lost:
        raise RuntimeError(f"sections that the memory map and the allocator do not place: {lost}")
    loads = elf32.loads(elf)
    _loads[:] = []
    for _, load, data in sorted((v for v in loads.values() if v[1] < NOLOAD), key=lambda v: v[1]):
        if _loads and _loads[-1][0] + len(_loads[-1][1]) > load:
            owners = [n for n, (_, at, d) in loads.items() if at <= load < at + len(d)]
            raise RuntimeError(f"card load records overlap at {load:06X}: {owners}")
        if _loads and _loads[-1][0] + len(_loads[-1][1]) == load:
            _loads[-1] = (_loads[-1][0], _loads[-1][1] + data)
        else:
            _loads.append((load, data))
