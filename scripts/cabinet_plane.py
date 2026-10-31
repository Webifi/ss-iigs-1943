"""Eight ROM P-38 poses, prepared for bounded latch copies over palette water.

The existing cabinet surface holds their short row spans and ready copy lists.
It is borrowed only during cabinet presentations; no permanent VRAM is added.
"""

import struct


def prepare(scene):
    from foreground_cache import ForegroundCache
    from game_water import stage

    fg = ForegroundCache(scene.a, None, 0, allocate=False)
    water, _ = stage(scene.a)
    pixels = bytearray(65536)
    art = bytearray()
    commands = bytearray()
    directory = []
    shared = {}
    for frame in range(8):
        directory.append(scene.cabinet_surface + 8192 + len(commands))
        for y in range(256):
            row = fg.row(0xE800 + frame * 256 + 255 - y, 0)[16:240]
            groups = [g for g in range(56) if any(v != 15 for v in row[g * 4 : g * 4 + 4])]
            if not groups:
                continue
            lo, hi = groups[0], groups[-1] + 1
            span = bytes(
                row[x] if row[x] != 15 else water[((255 - y) % 30) * 256 + x]
                for x in range(lo * 4, hi * 4)
            )
            if span not in shared:
                shared[span] = len(art) // 4
                art += span
            commands += struct.pack(
                "<HHB", (scene.cabinet_surface + shared[span]) & 65535, y * 56 + lo, hi - lo
            )
        commands += bytes(5)
    assert len(art) <= 32768 and len(commands) <= 8192, (len(art), len(commands))
    pixels[: len(art)] = art
    pixels[32768 : 32768 + len(commands) * 4 : 4] = commands
    scene.cabinet_plane_directory = directory
    scene.cabinet_plane_bytes = (len(art), len(commands))
    print(
        f"Cabinet P-38: {len(art)} pixel bytes + {len(commands)} command bytes in borrowed surface",
        flush=True,
    )
    return bytes(pixels)


