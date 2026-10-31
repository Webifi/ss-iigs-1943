"""Original decimal score addition on the native IIgs."""

from roms import load


def prepare(out):
    regions, _ = load()
    data = regions["maincpu"][0x2397:0x2497]
    (out / "score_data.inc").write_text(
        "score_awards:\n"
        + "\n".join(
            "  .byte " + ",".join(f"${v:02x}" for v in data[i : i + 16]) for i in range(0, 256, 16)
        )
        + "\n"
    )
