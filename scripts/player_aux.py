"""Tables for native wing-plane state and firing poses, original US bank 1."""

from roms import load


def prepare(out):
    regions, _ = load()
    rom = regions["maincpu"]
    base = 0x14000 - 0x8000
    lines = []
    for label, address, count in (
        ("player_wing_explosion", 0x883F, 19),
        ("player_wing_left", 0x895A, 20),
        ("player_wing_right", 0x896E, 20),
    ):
        data = rom[base + address : base + address + count]
        lines += [label + ":", "  .byte " + ",".join(f"${v:02x}" for v in data)]
    (out / "player_aux_data.inc").write_text("\n".join(lines) + "\n")
