"""Build-only native carrier aircraft data from original US bank four."""

import struct
from roms import load

TEMPLATES = (0x9263, 0xB346, 0xA183, 0xA676, 0x8392, 0x83B2)


def prepare(out, patterns=None):
    bank = load()[0]["maincpu"][0x20000:0x24000]
    text = []
    paths = set()
    for name, start, size in (
        ("ship_launch_paths", 0x93AB, 64),
        ("ship_dive_paths", 0xA371, 64),
        ("ship_homing_paths", 0xA72E, 64),
        ("large_plane_paths", 0xB4B3, 34),
    ):
        values = struct.unpack_from("<%dH" % (size // 2), bank, start - 0x8000)
        paths.update(values)
        text += [name + ":", "  .word " + ",".join("$%04x" % v for v in values)]
    for name, start, size in (
        ("ship_wrap_positions", 0x931C, 32),
        ("ship_depart_sequence", 0x9313, 9),
        ("large_plane_positions", 0xB438, 32),
        ("large_plane_sequence", 0xB42F, 9),
    ):
        text += [
            name + ":",
            "  .byte "
            + ",".join("$%02x" % v for v in bank[start - 0x8000 : start - 0x8000 + size]),
        ]
    text += ["ship_launch_templates:"]
    for ptr in TEMPLATES:
        data = bank[ptr - 0x8000 : ptr - 0x8000 + 32]
        paths.add(struct.unpack_from("<H", data, 30)[0] + 7)
        text += ["  .byte " + ",".join("$%02x" % v for v in data)]
    paths.update(
        (
            0x9411,
            0x943B,
            0x944C,
            0x945D,
            0x946E,
            0x9478,
            0xA207,
            0xA22D,
            0xA2B5,
            0xA2EC,
            0xA2DB,
            0xA2AF,
            0x843C,
            0x84A6,
            0x8510,
            0xB526,
            0xB550,
            0xB561,
            0xB572,
            0xB583,
            0xB58D,
            0xB6BF,
            0xB797,
        )
    )
    (out / "ship_data.inc").write_text("\n".join(text) + "\n")
    return [(4, p) for p in sorted(paths)]

