"""US homing/diving fighter data and first-free-slot spawn parameters."""

import struct
from roms import load

SPAWNS = {5 * n + 0x8000: (0, 0x8034, 0x18 + 32 * n) for n in range(7)}
SPAWNS.update(
    {
        p: (0, 0x8E9A, x)
        for p, x in zip((0x8E70, 0x8E75, 0x8E7A, 0x8E7F, 0x8E84), (0x20, 0x50, 0x78, 0xA0, 0xD0))
    }
)
CALLBACKS = (0x8054, 0x80D8, 0x8EBA, 0x8EE8, 0x8F21, 0x8F35, 0x8F60, 0x8F8C, 0x8FBE, 0x90E0)


def prepare(out):
    bank = load()[0]["maincpu"][0x10000:0x14000]
    text = []
    for name, start, size in (
        ("medium_home_paths", 0x8100, 128),
        ("medium_dive_paths", 0x8FB0, 14),
        ("medium_return_paths", 0x9122, 64),
    ):
        data = bank[start - 0x8000 : start - 0x8000 + size]
        text += [
            name + ":",
            "  .word " + ",".join("$%04x" % v for v in struct.unpack("<%dH" % (size // 2), data)),
        ]
    templates = sorted(set(v[1] for v in SPAWNS.values()))
    for name, values in [
        ("medium_spawn_x", [SPAWNS[c][2] for c in sorted(SPAWNS)]),
        ("medium_spawn_template", [templates.index(SPAWNS[c][1]) * 32 for c in sorted(SPAWNS)]),
    ]:
        text += [name + ":", "  .byte " + ",".join(str(v) for v in values)]
    text += ["medium_spawn_templates:"]
    for ptr in templates:
        text += ["  .byte " + ",".join("$%02x" % v for v in bank[ptr - 0x8000 : ptr - 0x8000 + 32])]
    (out / "medium_data.inc").write_text("\n".join(text) + "\n")
    paths = set(struct.unpack_from("<64H", bank, 0x100)) | set(
        struct.unpack_from("<7H", bank, 0xFB0)
    )
    paths.update(struct.unpack_from("<32H", bank, 0x1122))
    paths.update((0x81C4, 0x8219, 0x8FDD, 0x908E, 0x90B7))
    return [(0, p) for p in sorted(paths)]
