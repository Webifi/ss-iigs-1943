"""Native bank-six aiming turret data, original US tables and spawn templates."""

import struct
from roms import load

SPAWNS = {
    0x8000: (0, 0x2D),
    0x8177: (1, 0x30),
    0x817C: (1, 0x70),
    0x82F3: (2, 0x9A),
    0x82F8: (2, 0x65),
    0x846F: (3, 0x80),
}


def prepare(out):
    p = load()[0]["maincpu"]
    bank = p[0x28000:0x2C000]
    paths = []
    for address in (0x80B7, 0x8233, 0x83AF, 0x8516):
        paths.extend(struct.unpack_from("<16H", bank, address - 0x8000))
    text = ["turret_aim_paths:", "  .word " + ",".join("$%04x" % v for v in paths)]
    for name, values in [
        ("turret_input_angles", p[0x323D:0x324D]),
        ("turret_muzzles", p[0x3E21:0x3E41]),
        ("turret_bullet_template", p[0x3F76:0x3F96]),
    ]:
        text += [name + ":", "  .byte " + ",".join("$%02x" % v for v in values)]
    bullets = struct.unpack_from("<16H", p, 0x3F96)
    text += [
        "turret_bullet_paths:",
        "  .word " + ",".join("$%04x" % v for v in bullets),
        "turret_spawn_templates:",
    ]
    for at in (0x802B, 0x81A7, 0x8323, 0x8497):
        text += ["  .byte " + ",".join("$%02x" % v for v in bank[at - 0x8000 : at - 0x8000 + 32])]
    for name, k in (("turret_spawn_kind", 0), ("turret_spawn_x", 1)):
        text += [name + ":", "  .byte " + ",".join(str(SPAWNS[c][k]) for c in sorted(SPAWNS))]
    (out / "turret_data.inc").write_text("\n".join(text) + "\n")
    return [(6, v) for v in paths] + [(8, v + 7) for v in bullets]
