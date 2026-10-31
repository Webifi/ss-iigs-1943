"""Port the original-US player death animation and its state transitions."""

from roms import load


def prepare(out):
    regions, _ = load()
    frames = regions["maincpu"][0x14000 + 0xC2C : 0x14000 + 0xC4F]
    assert frames[-1] == 255 and len(frames) == 35
    (out / "death_data.inc").write_text(
        "player_death_frames:\n  .byte " + ",".join(f"${v:02x}" for v in frames) + "\n"
    )
    return frames
