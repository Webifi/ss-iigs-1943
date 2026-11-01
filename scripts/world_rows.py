"""Region-resident exact 16-pixel row sharing."""

import struct
from world_stream import INTRO, replace

# src/secondsight/world_rows.s: the row addresses of a scatter job in the upload buffer.
BUFFER_ROW_ADDRESSES = 0x80


def prepare(scene, pool, world, prepared, pairs, units):
    strips = world.tiles
    sets = {c: set(prepared[c][2]) for c in units}
    row_ids = {}
    for a, b in sorted(pairs | {(c, c) for c in units}):
        for t in sets[a] | sets[b] | sets[INTRO]:
            for y in range(32):
                row_ids.setdefault(strips[t][y * 16 : (y + 1) * 16], len(row_ids))
    pixels = b"".join(row_ids)
    # Give each distinct row a slot so that the rows of any region pair (and
    # the intro) never share one. Rows in the most groups go first, each to
    # the lowest free slot. This reaches the minimum: the size of the largest
    # group.
    groups = [
        {
            row_ids[strips[t][y * 16 : (y + 1) * 16]]
            for t in sets[a] | sets[b] | sets[INTRO]
            for y in range(32)
        }
        for a, b in sorted(pairs | {(c, c) for c in units})
    ]
    member = [[] for _ in row_ids]
    for g, ids in enumerate(groups):
        for i in ids:
            member[i].append(g)
    taken = [set() for _ in groups]
    slots = [0] * len(row_ids)
    for i in sorted(range(len(row_ids)), key=lambda i: -len(member[i])):
        busy = set().union(*(taken[g] for g in member[i]))
        slot = 0
        while slot in busy:
            slot += 1
        slots[i] = slot
        for g in member[i]:
            taken[g].add(slot)
    colors = tuple(slots)
    assert max(colors) + 1 == max(map(len, groups))
    scene.row_pixels = [pixels[i : i + 16] for i in range(0, len(pixels), 16)]
    scene.row_colors = colors
    scene.row_sets = {
        c: {row_ids[strips[t][y * 16 : (y + 1) * 16]] for t in sets[c] for y in range(32)}
        for c in units
    }
    scene.tile_row_ids = {
        t: [row_ids[strips[t][y * 16 : (y + 1) * 16]] for y in range(32)]
        for t in set().union(*sets.values())
    }
    # Sea tiles enforce their own source-bias guard in game_sea.prepare.
    # A permanently allocated blank prefix is not read by this row cache.
    n = (max(colors) + 1) * 16
    scene.row_pixel_base = pool.runtime(n, name="row_pixels")
    assert (scene.row_pixel_base >> 16) == ((scene.row_pixel_base + n // 4 - 1) >> 16)
    scene.row_table_stride = ((scene.world_slots + 3) // 4) * 64
    scene.row_table_base = pool.runtime(scene.row_table_stride * 4, name="row_table")
    scene.world_tile_addresses = [
        (scene.row_table_base + (slot // 4) * 64) | ((slot % 4) << 18)
        for slot in range(scene.world_slots)
    ]
    print(
        "Shared pixel rows",
        len(row_ids),
        "slots",
        max(colors) + 1,
        "pixels",
        n,
        "pointers",
        scene.row_table_stride * 4,
        flush=True,
    )


def table_data(scene, tile):
    return b"".join(
        struct.pack("<H", (scene.row_pixel_base + scene.row_colors[i] * 4) & 65535)
        for i in scene.tile_row_ids[tile]
    )


def initial(scene, pool, regions):
    ids = set()
    tiles = set()
    for c in (*regions, INTRO):
        ids.update(scene.row_sets[c])
        tiles.update(scene.world_prepared[c][2])
    for i in ids:
        replace(pool, (scene.row_pixel_base + scene.row_colors[i] * 4) * 4, scene.row_pixels[i])
    packed = bytearray(scene.row_table_stride * 4)
    for tile in tiles:
        slot = scene.world_colors[tile]
        data = table_data(scene, tile)
        off = (slot // 4) * 64
        plane = slot % 4
        packed[plane + off * 4 : plane + (off + 64) * 4 : 4] = data
    replace(pool, scene.row_table_base * 4, packed)


def tile_packets(scene, tile):
    from startup_pack import pack

    addresses = table_data(scene, tile)
    pixels = scene.game_world.tiles[tile]
    # Equal rows share one physical destination. Keep the complete table for
    # the renderer, but upload each destination only once per strip.
    seen = set()
    rows = []
    for row, row_id in enumerate(scene.tile_row_ids[tile]):
        if row_id not in seen:
            seen.add(row_id)
            rows.append(row)
    assert rows and len(rows) <= 32
    distinct = b"".join(addresses[2 * row : 2 * row + 2] for row in rows)
    palette = bytes(sorted(set(pixels))).ljust(16, b"\0")
    assert len(palette) == 16
    indices = {v: i for i, v in enumerate(palette)}
    from secondsight_link import fixed
    from world_stream import sram_jobs

    # The upload buffer starts the scratch page (src/secondsight/fixed.ld), in
    # common SRAM: its logical address is its physical one.
    yield from sram_jobs(fixed("scratch__run") + BUFFER_ROW_ADDRESSES, addresses + distinct)
    slot = scene.world_colors[tile]
    table_address = scene.row_table_base + (slot // 4) * 64
    for plane in range(4):
        raw = b"".join(pixels[row * 16 + plane : row * 16 + 16 : 4] for row in rows)
        pens = bytes(indices[raw[i]] | (indices[raw[i + 1]] << 4) for i in range(0, len(raw), 2))
        compressed = pack(pens)
        yield (
            struct.pack(
                "<BBBBHHH",
                7 if plane == 0 else 8,
                (1 << (slot % 4)) if plane == 0 else 0,
                1 << plane,
                scene.row_pixel_base >> 16,
                table_address & 65535,
                len(pens),
                len(compressed),
            )
            + (palette if plane == 0 else b"")
            + compressed
        )


