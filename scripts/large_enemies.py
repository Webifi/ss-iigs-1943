"""Build-only original-US ship templates, native event indices and paths."""

import struct
from roms import load

SPAWNS = {0x8609: (4, 0, 0x2D, 0)}
SPAWNS.update(
    {
        0x8000 + 7 * i: (4, 1, x, p)
        for i, (x, p) in enumerate(
            ((0x49, 3), (0x4F, 0), (0x50, 1), (0x70, 0), (0x70, 2), (0x79, 0), (0xA9, 3), (0xAA, 0))
        )
    }
)


def prepare(out):
    from boss_cores import prepare as cores

    core_roots = cores(out)
    bank = load()[0]["maincpu"][0x20000:0x24000]
    text = []
    for name, k in (("large_spawn_kind", 1), ("large_spawn_x", 2), ("large_spawn_pattern", 3)):
        text += [name + ":", "  .byte " + ",".join(str(SPAWNS[c][k]) for c in sorted(SPAWNS))]
    text += ["large_spawn_templates:"]
    for ptr in (0x8634, 0x8064):
        text += ["  .byte " + ",".join("$%02x" % v for v in bank[ptr - 0x8000 : ptr - 0x8000 + 32])]
    text += [
        "large_turret_paths:",
        "  .word " + ",".join("$%04x" % v for v in struct.unpack_from("<7H", bank, 0xDF)),
    ]
    (out / "large_data.inc").write_text("\n".join(text) + "\n")
    return (
        core_roots
        + [
            (4, p)
            for p in (
                0x8732,
                0x873F,
                0x8749,
                0x876F,
                0x8787,
                0x80FE,
                0x8108,
                0x8112,
                0x811C,
                0x8126,
            )
        ]
        + [(8, 0x5E8A)]
    )
