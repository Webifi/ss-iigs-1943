"""Original US paths for the native spiral, pursuit and turning formations."""

import struct
from roms import load


def prepare(out):
    rom = load()[0]["maincpu"]
    text = ["formation_paths:"]
    roots = [(0, 0x8342), (0, 0x83B1)]
    for bank, address in (
        (4, 0x9811),
        (4, 0x9BF7),
        (4, 0x9F74),
        (6, 0x8D6E),
        (0, 0x853D),
        (0, 0x9430),
        (0, 0x97CF),
        (6, 0x9095),
    ):
        offset = 0x10000 + bank * 0x4000 + address - 0x8000
        # The crossing formation has thirteen headings, not a 32-entry
        # compass. Bytes after $97E8 are movement records, not pointers.
        count = 13 if (bank, address) == (0, 0x97CF) else 32
        paths = struct.unpack_from("<%dH" % count, rom, offset)
        text += ["  .word " + ",".join("$%04x" % p for p in paths + (0,) * (32 - count))]
        roots.extend((bank, p) for p in paths)
    roots.extend((0, p) for p in (0x985F, 0x98E7))
    roots.extend(
        (6, p) for p in (0x90DF, 0x90E9, 0x915C, 0xB514, 0xB54F, 0xB5D3, 0xB58A, 0xB634, 0xB61C)
    )
    (out / "formation_data.inc").write_text("\n".join(text) + "\n")
    return roots
