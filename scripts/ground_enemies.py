"""Original-US ground-target paths and turning-bullet data."""

import struct
from roms import load

CALLBACKS = (0xAD42, 0xAF09, 0xB185, 0xB34E, 0xB4ED, 0xB9B0, 0xBB4C)


def prepare(out):
    r = load()[0]["maincpu"]
    b = r[0x10000:0x14000]
    roots = []
    lines = ["ground_paths:"]
    for p in (0xADE0, 0xAF59, 0xB1ED, 0xB3CF, 0xB573, 0xBA24, 0xBBBE):
        values = struct.unpack_from("<16H", b, p - 0x8000)
        roots.extend((0, v) for v in values)
        lines += ["  .word " + ",".join("$%04x" % v for v in values)]
    for name, p, n in [
        ("ground_bullet_template", 0x3E8B, 32),
        ("ground_small_muzzles", 0x3E01, 32),
    ]:
        lines += [name + ":", "  .byte " + ",".join(str(v) for v in r[p : p + n])]
    for name, p in [("ground_bullet_paths", 0x3EED), ("ground_bullet_turn_paths", 0x3F0D)]:
        values = struct.unpack_from("<16H", r, p)
        roots.extend((8, v) for v in values)
        lines += [name + ":", "  .word " + ",".join("$%04x" % v for v in values)]
    for name, values in [
        ("ground_spread_speeds", (10, 14, 10, 10, 14, 18, 10, 14)),
        ("ground_random_speeds", (10, 18, 14, 10, 14, 18, 14, 10)),
    ]:
        lines += [name + ":", "  .byte " + ",".join(str(v) for v in values)]
    roots.append((8, 0x4173))
    (out / "ground_data.inc").write_text("\n".join(lines) + "\n")
    return roots
