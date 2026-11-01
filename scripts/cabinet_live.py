"""Resident ordinary-game initials overlay and cabinet damage dispatcher."""

import struct
from cabinet_post import live_layouts



def records(scene):
    glyphs = scene.cabinet_video["glyphs"]
    result = {}
    for kind, layout in live_layouts().items():
        data = bytearray()
        for index, code, attr in layout:
            y = 248 - (index & 31) * 8
            x = (index >> 5) * 8 - 16
            if 0 <= x < 224:
                glyph = -code - 1 if code < 0 else glyphs[code, attr]
                assert glyph < 256, (kind, code, attr, glyph)
                data += struct.pack("<HB", y * 56 + x // 4 + (0x4000 if code < 0 else 0), glyph)
        result[kind] = bytes(data) + b"\xff\xff\0"
    return result


def install(scene):
    """The overlay helper and its damage lists, in the banked code page
    (.bank_code of secondsight.ld). Run once after cabinet text, then mark normal and
    live damage."""
    from secondsight_link import generate

    # The lists are read through BBR at $C000, $2000 below this code's window.
    lists = records(scene)
    lines = [
        '        .section .rodata.cabinet_live_lists,"a"',
        "        .global cab_live_pointers",
        "cab_live_pointers:",
    ]
    lines += [f"        .word cab_live_list_{kind} - 0x2000" for kind in range(1, 9)]
    for kind in range(1, 9):
        lines.append(f"cab_live_list_{kind}:")
        data = lists[kind]
        lines += [
            "        .byte " + ",".join(f"0x{v:02X}" for v in data[i : i + 16])
            for i in range(0, len(data), 16)
        ]
    generate("cabinet_live_lists", "\n".join(lines) + "\n")
