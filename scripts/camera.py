"""Port the original sea/foreground camera, including pan and pauses."""

import struct

from roms import load


def prepare(out):
    regions, _ = load()
    rom = regions["maincpu"]
    pointers = struct.unpack_from("<16H", rom, 0x11C7)
    bank = rom[0x1C000:0x20000]
    end = 0
    for ptr in pointers:
        offset = ptr - 0x8000
        while bank[offset] != 255:
            offset += 3
            assert offset < 1024
        end = max(end, offset + 1)
    text = (
        "camera_pan_pointers:\n  .addr "
        + ",".join(f"camera_pan_data+{ptr - 0x8000}" for ptr in pointers)
        + "\ncamera_pan_data:\n"
    )
    text += (
        "\n".join(
            "  .byte " + ",".join(f"${v:02x}" for v in bank[i : i + 16]) for i in range(0, end, 16)
        )
        + "\n"
    )
    (out / "camera_data.inc").write_text(text)
    return end
