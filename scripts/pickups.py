"""Original-US pickup initialization data and reachable movement records."""

from roms import load

DROP_TEMPLATES = (0x6EFD, 0x7024, 0x6FEA, 0x7073, 0x7180, 0x71DF, 0x7121, 0x724B)
CHANGE_TEMPLATES = (0x70C2, 0x6EFD, 0x7121, 0x6EFD, 0x71DF, 0x6EFD, 0x7180, 0x6EFD) * 3 + (0x7024,)


def prepare(out):
    rom = load()[0]["maincpu"]
    text = []
    roots = []
    for label, addresses in (
        ("pickup_templates", DROP_TEMPLATES),
        ("pickup_change_templates", CHANGE_TEMPLATES),
    ):
        data = b"".join(rom[a : a + 32] for a in addresses)
        text += [label + ":"] + [
            "  .byte " + ",".join(str(v) for v in data[i : i + 16]) for i in range(0, len(data), 16)
        ]
        for a in addresses:
            roots.extend(
                (0, int.from_bytes(rom[a + p : a + p + 2], "little") + 7) for p in (28, 30)
            )
    text += ["pickup_laser_positions:", "  .byte " + ",".join(str(v) for v in rom[0x72A3:0x72C3])]
    roots += [(0, 0x72FE)]
    (out / "pickup_data.inc").write_text("\n".join(text) + "\n")
    return roots
