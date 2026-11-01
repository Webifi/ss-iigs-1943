"""The disk step, after the links: the card load records from
build/secondsight/secondsight.elf, the boot volume (scripts/boot_disk.py)
and the debug symbol file.

The card load records hold every loaded byte of the Second Sight program.
The SRAM ranges that the firmware uses until the entry (staged_N of
secondsight.ld) and the runtime block load into plane 0 of the video RAM
staging groups (entry_stage_N); the entry copies them into place
(src/secondsight/playfield.s entry_staging).
"""

import boot_disk
import debug_symbols
import elf32
from arcade import ROOT

PLANE = 0x200000  # load addresses of one VGA plane: PLANE + plane * 0x40000 + group
PART = 16384  # the most bytes of one card load record


def card_records(elf):
    """(load address, bytes) of the card load records."""
    symbols = elf32.global_symbols(elf)
    sections = elf32.loads(elf)
    loads = []
    for _, load, data in sorted((v for v in sections.values() if v[1] < symbols["load_packets"]), key=lambda v: v[1]):
        if loads and loads[-1][0] + len(loads[-1][1]) > load:
            raise RuntimeError(f"card load records overlap at {load:06X}")
        if loads and loads[-1][0] + len(loads[-1][1]) == load:
            loads[-1] = (loads[-1][0], loads[-1][1] + data)
        else:
            loads.append((load, data))
    staged = {}
    while f"staged_{len(staged)}__start" in symbols:
        n = len(staged)
        start = symbols[f"staged_{n}__start"]
        staged[start] = bytearray(symbols[f"staged_{n}__end"] - start)
    records = []

    def record(dst, data):
        for start, block in staged.items():
            lo, hi = max(dst, start), min(dst + len(data), start + len(block))
            if lo < hi:
                if dst < lo:
                    record(dst, data[: lo - dst])
                block[lo - start : hi - start] = data[lo - dst : hi - dst]
                if hi < dst + len(data):
                    record(hi, data[hi - dst :])
                return
        for offset in range(0, len(data), PART):
            records.append((dst + offset, bytes(data[offset : offset + PART])))

    for address, data in loads:
        record(address, data)
    runtime = sections[".entry_runtime"][2]
    for n, data in enumerate([*staged.values(), runtime]):
        record(PLANE + symbols[f"entry_stage_{n}"], data)
    return records


def main():
    game, disk = ROOT / "build/game", ROOT / "build/game-disk"
    records = card_records(ROOT / "build/secondsight/secondsight.elf")
    (game / "card-startup.bin").write_bytes(
        b"".join(a.to_bytes(3, "little") + len(d).to_bytes(3, "little") + d for a, d in records) + bytes(6)
    )
    boot_disk.build(game, disk)
    debug_symbols.write(game, disk / "debug.sym")


if __name__ == "__main__":
    main()
