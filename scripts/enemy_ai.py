"""Native player-targeted fighter decisions and script continuation callbacks."""

from roms import load


def prepare(out):
    regions, _ = load()
    program = regions["maincpu"]
    data = program[0x28000 + 0x1B0A : 0x28000 + 0x1B6A]
    assert len(data) == 96
    text = ""
    for label, values in (("ai_pattern_table", data), ("ai_angles", program[0x5B7:0x5F7])):
        text += (
            label
            + ":\n"
            + "\n".join(
                "  .byte " + ",".join(f"${v:02x}" for v in values[i : i + 16])
                for i in range(0, len(values), 16)
            )
            + "\n"
        )
    thresholds = bytes(base * (2 * i + 1) for base in range(32) for i in range(4))
    # Exhaustively check the compact native lookup against all old entries.
    for dy in range(256):
        for dx in range(256):
            base = max(dx, dy) // 8
            minor = min(dx, dy)
            ratio = next((i for i in range(4) if base * (2 * i + 1) >= minor), 4)
            assert ratio == next(
                (i for i, v in enumerate(thresholds[base * 4 : base * 4 + 4]) if v >= minor), 4
            )
    text += (
        "ai_thresholds:\n"
        + "\n".join(
            "  .byte " + ",".join(str(v) for v in thresholds[i : i + 16]) for i in range(0, 128, 16)
        )
        + "\n"
    )

    def install(host):
        (out / "enemy_ai_data.inc").write_text(text)

    return install
