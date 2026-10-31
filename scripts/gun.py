"""Compare native basic-gun calls with original-US before/after state."""

from roms import load


def prepare(out):
    regions, roms = load()
    data = regions["maincpu"][0x14000 + 0x17FA : 0x14000 + 0x1806]
    assert data.hex() == "3f081000080808ff00000100"
    (out / "gun_data.inc").write_text(
        "gun_basic_template:\n  .byte " + ",".join(f"${v:02x}" for v in data) + "\n"
    )
    return roms
