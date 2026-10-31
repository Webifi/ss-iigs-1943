"""Native first-free-slot fighter wave initializer, compared with original US."""

from roms import load


def prepare(out):
    regions, _ = load()
    bank = regions["maincpu"][0x10000:0x14000]
    six = regions["maincpu"][0x28000:0x2C000]
    text = ""
    for label, values in (
        ("wave_template", bank[0x8F4:0x914]),
        ("wave_positions", bank[0x8D6:0x8F4]),
        ("wave_circle_template", six[0x1AB1:0x1AD1]),
    ):
        text += (
            label
            + ":\n"
            + "\n".join(
                "  .byte " + ",".join(f"${v:02x}" for v in values[i : i + 16])
                for i in range(0, len(values), 16)
            )
            + "\n"
        )
    (out / "wave_data.inc").write_text(text)
