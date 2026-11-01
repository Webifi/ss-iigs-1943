"""Prepared ship geometry over canonical rows and three shared alignments."""

import struct
from ship_alignment import PITCH


def seed_commands(placement):
    """Three ready placement lists, shared by the four source planes."""
    left, width = placement
    n = width + 1
    targets = [list(range(128, 128 + n)) for _ in range(3)]
    data = bytearray([0])
    for target in targets:
        runs = []
        first = 0
        while first < n:
            end = first + 1
            while end < n and target[end] == target[first] + end - first:
                end += 1
            runs.extend((target[first], first, end - first))
            first = end
        data.extend((len(runs) // 3, *runs))
        # Each prepared byte covers exactly the intended group in every
        # plane; no source/destination layout is reconstructed in play.
        expanded = [
            t + i for t, off, count in zip(runs[::3], runs[1::3], runs[2::3]) for i in range(count)
        ]
        assert expanded == target
    data[0] = len(data) - 1
    return bytes(data)


def pan_ranges():
    from stage_controls import event_tables
    from roms import load

    rom = load()[0]["maincpu"]
    tables, meta = event_tables()
    pointers = struct.unpack_from("<16H", rom, 0x11C7)
    ranges = []
    for stage, (data, m) in enumerate(zip(tables, meta)):
        starts = [
            struct.unpack_from("<H", data, i)[0]
            for i in range(0, m["first_end_offset"] + 1, 6)
            if data[i + 2 : i + 4] == b"\x05\x6a"
        ]
        if not starts:
            continue
        pos = 0x1C000 + pointers[stage] - 0x8000
        advance = 0
        while rom[pos] != 255:
            duration, dx, hold = rom[pos : pos + 3]
            if not hold:
                advance += duration
            pos += 3
        ranges.extend((start, min(65535, start + advance + 255)) for start in starts)
    return ranges


def eligible_columns(world):
    return {world.column_index[w >> 5] for lo, hi in pan_ranges() for w in range(lo, hi + 1)}


def layout(masks, pitch=PITCH):
    occupied = [i for i, m in enumerate(masks) if m]
    if not occupied or occupied[0] < 4 or occupied[-1] >= 60:
        return None
    left = occupied[0] - 4
    width = occupied[-1] - occupied[0] + 1
    if width >= pitch:
        return None
    n = width + 1
    assert n <= pitch
    return left, width


def geometry(row, placement, phase):
    """Final mask, source offset, placement and count; no runtime layout math."""
    left, width = placement
    parts = []

    def source(x):
        offset = x - left - 3
        if phase == 0:
            return x - 4
        return 128 + offset

    for i in range(1, len(row), 3):
        first, end, mask = row[i : i + 3]
        while first < end:
            start = source(first)
            last = first + 1
            while last < end and source(last) == start + last - first:
                last += 1
            parts.extend((mask, start, first, last - first))
            first = last
    for i in range(4, len(parts), 4):
        if (
            parts[i - 3] + parts[i - 1] == parts[i + 1]
            and parts[i - 2] + parts[i - 1] == parts[i + 2]
            and (parts[i - 3] & 128) == (parts[i + 1] & 128)
        ):
            parts[i] |= 128  # Single-row interior copy can retain DMA addresses.
    return bytes([len(parts) // 4]) + bytes(parts)


def prepare(scene, pool, cols):
    from combined_world import BLOCK, SharedArena
    from world_stream import INTRO, replace

    world = scene.game_world
    columns = eligible_columns(world)
    from ship_alignment import boss_columns

    wide = boss_columns(world)
    assert not columns.intersection(wide)
    columns |= wide
    # Light-water ships move against the sea in every picture, not only in
    # the camera pan ranges, and a ship row without prepared geometry takes
    # the slow per-plane path (combined_ship_commands). So each side-1
    # section also prepares all its other ship columns (extra). Only side-1
    # sections hold geometry: a column that a side-0 section or the intro
    # also uses stays out.
    side0 = set()
    for region in cols:
        if region == INTRO or scene.world_region_side.get(region) != 1:
            side0 |= set(cols[region])
    extra = set()
    for region in cols:
        if region != INTRO and scene.world_region_side.get(region) == 1:
            extra |= {
                c
                for c in set(cols[region]) - side0 - columns
                if any(world.runs[world.columns[c][0][row]][0] for row in range(32))
            }
    pitches = {col: 64 for col in wide}
    from ship_columns import prepare as prepare_columns

    column_programs = prepare_columns(world, columns | extra, pitches)
    from ship_alignment import prepare as prepare_alignments

    prepare_alignments(scene, pool)
    # Geometry exists only for side-1 world sections. Their prepared row
    # metadata fits in the first three quarters of the cabinet surface, so
    # the fourth quarter (16 KB) holds the geometry of the loaded section.
    # With all ship columns prepared, a section needs up to about 22 KB, so
    # an own 8 KB area (2 KB in each plane) from free VRAM holds the rest.
    scene.ship_geometry_surface = pool.runtime(4 * BLOCK, 4096)
    addresses = [scene.ship_geometry_surface + 3 * 4096, pool.runtime(4 * 2048, 2048)]
    extents = [(0, p, 0, 4096) for p in range(4)] + [(1, p, 0, 2048) for p in range(4)]
    # Seed placement lists are permanent in the existing stage-water tail.
    seed_data = bytearray(8704)
    seed_used = [0] * 4
    seed_pointers = {}

    def seed_pointer(placement):
        data = seed_commands(placement)
        if data not in seed_pointers:
            plane = min(range(4), key=seed_used.__getitem__)
            off = seed_used[plane]
            assert off + len(data) <= 2176
            seed_data[plane + off * 4 : plane + (off + len(data)) * 4 : 4] = data
            seed_used[plane] += len(data)
            seed_pointers[data] = struct.pack("<HB", 0x0780 + off, 1 | (plane << 2))
        return seed_pointers[data]

    for column in sorted(columns):
        if column in column_programs:
            seed_pointer(column_programs[column][0])
        else:
            for row in range(32):
                masks = [0] * 64
                raw = world.runs[world.columns[column][0][row]]
                for first, last, mask in zip(raw[1::3], raw[2::3], raw[3::3]):
                    masks[first:last] = [mask] * (last - first)
                placement = layout(masks, pitches.get(column, PITCH))
                if placement is not None:
                    seed_pointer(placement)
    def region_geometry(region_columns):
        """The geometry block (arena) and the row records of the ship
        columns REGION_COLUMNS of one section."""
        arena = SharedArena(addresses, extents)
        records = {}
        for column in sorted(region_columns):
            if column in column_programs:
                placement, blocks = column_programs[column]
                for first, last, phases in blocks:
                    directory = arena.put(b"".join(arena.put(part) for part in phases))
                    for row in range(first, last):
                        records[column, row] = (
                            bytes(placement)
                            + bytes([0x80 | (last - first - 1)])
                            + directory
                            + seed_pointer(placement)
                        )
                continue
            for row in range(32):
                raw = world.runs[world.columns[column][0][row]]
                masks = [0] * 64
                for i in range(1, len(raw), 3):
                    first, last, mask = raw[i : i + 3]
                    masks[first:last] = [mask] * (last - first)
                placement = layout(masks, pitches.get(column, PITCH))
                if placement is None:
                    continue
                parts = [
                    geometry(world.runs[world.columns[column][p][row]], placement, p)
                    for p in range(4)
                ]
                offsets = []
                pos = 4
                for part in parts:
                    offsets.append(pos)
                    pos += len(part)
                payload = bytes([pos, *offsets[1:]]) + b"".join(parts)
                records[column, row] = (
                    bytes(placement) + b"\x01" + arena.put(payload) + seed_pointer(placement)
                )
        for column in sorted(region_columns):
            if column in column_programs:
                continue
            for row in range(1, 32):
                current = records.get((column, row))
                previous = records.get((column, row - 1))
                if (
                    current
                    and previous
                    and current[:2] + current[3:] == previous[:2] + previous[3:]
                ):
                    records[column, row] = current[:2] + bytes([previous[2] + 1]) + current[3:]
        return arena, records

    arenas = {}
    layouts = {}
    all_records = {}
    for region in sorted(cols):
        arena, records = region_geometry((columns | extra).intersection(cols[region]))
        arenas[region] = arena
        layouts[region] = records
        all_records.update(records)
        if region == INTRO or scene.world_region_side.get(region) == 0:
            assert not arena.used, ("ship geometry shares the side-1 lifetime", region)
    for sequence in scene.world_routes:
        assert sum(bool(arenas[region].used) for region in sequence) <= 1, (
            "ship geometry residency",
            sequence,
        )
    initial = scene.world_routes[0][1]
    initial_arena = arenas[initial]
    # The geometry of the first section is in the startup VRAM image. The
    # own area is smaller than a block, so it gets only its used ranges.
    replace(pool, addresses[0] * 4, initial_arena.blocks[0])
    for block, plane, start, end in initial_arena.ranges():
        if block:
            raw = initial_arena.blocks[block][plane + start * 4 : plane + end * 4 : 4]
            pool.replace_plane(addresses[block] + start, plane, bytes(raw))
    scene.ship_row_layouts_by_region = layouts
    scene.ship_column_programs = column_programs
    scene.ship_row_geometry_bytes = max(a.used for a in arenas.values())
    scene.ship_seed_data = bytes(seed_data[: max(seed_used) * 4])
    scene.ship_geometry_arenas = arenas
    print(
        "Aligned ship rows",
        len(all_records),
        "max region geometry bytes",
        scene.ship_row_geometry_bytes,
        "VRAM shared with cabinet surface",
        BLOCK,
        "own",
        4 * 2048,
        flush=True,
    )


def jobs(scene, region):
    from world_stream import PlaneUpload

    arena = scene.ship_geometry_arenas[region]
    for block, plane, start, end in arena.ranges():
        raw = bytes(arena.blocks[block][plane::4])
        yield PlaneUpload(arena.addresses[block], plane * 4096 + start, raw[start:end], 4096)


