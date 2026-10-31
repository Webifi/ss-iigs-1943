"""Build native moving-boss motion records and collision/art data."""

import struct
from game_enemies import read


def prepare(out):
    seen = set()
    pending = [0xA783, 0xA7AF, 0xA86C]
    loops = {0xA755: (11, 0xA788, 0xA7A4), 0xA76C: (7, 0xA7B4, 0xA85C)}
    records = {}
    while pending:
        address = pending.pop()
        if address in seen:
            continue
        seen.add(address)
        d = read(0, address, 5)
        if d[0] == 0:
            count, repeat, end = loops[int.from_bytes(d[1:3], "little")]
            records[address] = (count, 2, repeat, end, 0)
            pending.extend((repeat, end))
        elif d[0] == 254:
            records[address] = (0, 3, 0, 0, 0)
        else:
            dx, dy = struct.unpack("<HH", d[1:])
            records[address] = (d[0], 0, dx, dy, address + 5)
            pending.append(address + 5)
    text = [
        '.segment "GAMEPLAY"',
        "air_motion_starts:",
        "  .addr air_motion_a783,air_motion_a7af,air_motion_a86c",
    ]
    for address, (ticks, kind, a, b, nxt) in sorted(records.items()):
        values = [
            f".loword(air_motion_{a:04x})" if kind in (1, 2) else str(a),
            f".loword(air_motion_{b:04x})" if kind == 2 else str(b),
            f".loword(air_motion_{nxt:04x})" if kind == 0 else "0",
        ]
        text += [
            f"air_motion_{address:04x}:",
            f"  .byte {ticks},{kind}",
            "  .word " + ",".join(values),
        ]
    for name, bank, address, size in (
        ("air_core_template", 0, 0xAA74, 32),
        ("air_piece_templates", 4, 0x8266, 96),
        ("air_gun_paths", 0, 0xBD36, 32),
    ):
        text += [name + ":", "  .byte " + ",".join(map(str, read(bank, address, size)))]
    text += ["air_fan_offsets:", "  .byte 0,2,4,254,252", '.segment "GAMEFLOW"']
    (out / "air_boss_data.inc").write_text("\n".join(text) + "\n")
    roots = [(0, p) for p in (0xABA2, 0xABAC, 0xABAF)]
    roots.extend((0, p) for p in struct.unpack("<16H", read(0, 0xBD36, 32)))
    roots.extend((4, p) for p in (0x8206, 0x82E6, 0x82FE, 0x8316))
    return roots
