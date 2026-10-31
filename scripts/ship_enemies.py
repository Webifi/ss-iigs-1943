"""Build-only native carrier aircraft data from original US bank four."""

import struct
from roms import load

CALLBACKS = (
    0x9283,
    0x928D,
    0x92F9,
    0x9309,
    0x933C,
    0xA1EF,
    0xA218,
    0xA233,
    0xA267,
    0xA28E,
    0xA33E,
    0xA343,
    0xA348,
    0xA6B5,
    0xA6BF,
)
LAUNCHES = (0x924C, 0xB31B, 0xA16C, 0xA65F)
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


def prepare_target(out):
    import re
    from arcade import ROOT

    text = (ROOT / "src/enemy_ai.s").read_text()
    text = text[text.index("ai_target_far:") : text.index("ai_approach:")]
    text = (
        text.replace("ai_target_far", "large_target_far")
        .replace("jsr ai_target", "jsr .loword(large_target)")
        .replace("ai_target:", "large_target:")
    )
    text = re.sub(
        r"\bENEMY\+(\$[0-9a-fA-F]+|[0-9]+)",
        lambda m: "z:$%02x" % int(m[1][1:], 16) if m[1].startswith("$") else "z:$%02x" % int(m[1]),
        text,
    )
    text = re.sub(r"(?<= )\$(?:[0-9a-fA-F]{2})(?=\s*$|,)", lambda m: "a:" + m[0], text, flags=re.M)
    (out / "large_target.inc").write_text(".a8\n.i16\n" + text)
