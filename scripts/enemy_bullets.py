"""Native aimed bullet creation from the original-US fighter callback."""

import struct

from roms import load


def prepare(out):
    regions, _ = load()
    p = regions["maincpu"]
    roots = struct.unpack_from("<5H", p, 0x3920)
    pointers = [v for base in roots for v in struct.unpack_from("<32H", p, base)]
    text = (
        "bullet_template:\n  .byte "
        + ",".join(f"${v:02x}" for v in p[0x3900:0x3920])
        + "\nbullet_pointers:\n"
    )
    text += (
        "\n".join(
            "  .word " + ",".join(f"${v:04x}" for v in pointers[i : i + 8])
            for i in range(0, len(pointers), 8)
        )
        + "\n"
    )
    (out / "bullet_data.inc").write_text(text)
    return pointers
