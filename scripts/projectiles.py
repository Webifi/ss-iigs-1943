"""Original-US projectile movement and impact animation, translated to 65816."""

from roms import load


def prepare(out):
    regions, roms = load()
    data = regions["maincpu"][0x183F : 0x183F + 257]
    assert data[:7].hex() == "01a501a601a7ff"
    (out / "shot_data.inc").write_text(
        "shot_animation:\n"
        + "\n".join(
            "  .byte " + ",".join(f"${v:02x}" for v in data[i : i + 16])
            for i in range(0, len(data), 16)
        )
        + "\n"
    )
    return roms
