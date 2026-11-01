"""Prepared cloud rows and silhouettes for the single scrolling background.

All addresses, strip boundaries, plane masks and lengths are build data.
Two quiet-loaded sections share the existing strip residency schedule.
"""

import struct

from asset_source import WINDOW_C000

BLOCK = 16384


class Arena:
    def __init__(self, addresses, last_prefix=0):
        self.addresses = addresses
        self.blocks = [bytearray(BLOCK) for _ in addresses]
        self.used = 0
        self.shared = {}
        self.last_prefix = last_prefix

    def put(self, data):
        data = bytes(data)
        if data in self.shared:
            return self.shared[data]
        if self.used % 4096 + len(data) > 4096:
            self.used = (self.used + 4095) & ~4095
        block, off = divmod(self.used, BLOCK)
        plane, pos = divmod(off, 4096)
        assert block < len(self.blocks), ("prepared section capacity", self.used, len(data))
        self.blocks[block][plane + pos * 4 : plane + (pos + len(data)) * 4 : 4] = data
        address = self.addresses[block] + pos
        ptr = struct.pack("<HB", address & 65535, (address >> 16) | (plane << 2))
        self.used += len(data)
        self.shared[data] = ptr
        return ptr

    def ranges(self):
        for block in range(len(self.blocks)):
            for plane in range(4):
                start = (
                    max(0, min(4096, self.last_prefix - plane * 4096))
                    if block == len(self.blocks) - 1
                    else 0
                )
                end = max(0, min(4096, self.used - block * BLOCK - plane * 4096))
                if end > start:
                    yield block, plane, start, end

    def install(self, pool, shared=None):
        from world_stream import replace

        for block, (address, data) in enumerate(zip(self.addresses, self.blocks)):
            replace(pool, address * 4, data)


class SharedArena:
    """Pack records into disjoint plane intervals without touching neighbors."""

    def __init__(self, addresses, extents):
        self.addresses = addresses
        self.blocks = [bytearray(BLOCK) for _ in addresses]
        for i, (block, plane, start, end) in enumerate(extents):
            assert 0 <= block < len(addresses) and 0 <= plane < 4 and 0 <= start < end <= 4096
            assert all(
                block != b or plane != p or end <= s or start >= e for b, p, s, e in extents[:i]
            )
        self.extents = [list(e) + [e[2]] for e in extents]
        self.shared = {}
        self.used = 0

    def put(self, data):
        data = bytes(data)
        if data in self.shared:
            return self.shared[data]
        for block, plane, start, end, nextpos in self.extents:
            if nextpos + len(data) > end:
                continue
            self.blocks[block][plane + nextpos * 4 : plane + (nextpos + len(data)) * 4 : 4] = data
            address = self.addresses[block] + nextpos
            ptr = struct.pack("<HB", address & 65535, (address >> 16) | (plane << 2))
            for extent in self.extents:
                if extent[:4] == [block, plane, start, end]:
                    extent[4] += len(data)
                    break
            self.used += len(data)
            self.shared[data] = ptr
            return ptr
        raise AssertionError(("shared section capacity", len(data), self.used))

    def ranges(self):
        for block, plane, start, end, nextpos in self.extents:
            if nextpos > start:
                yield block, plane, start, nextpos

    def unused(self):
        return [
            (block, plane, nextpos, end)
            for block, plane, start, end, nextpos in self.extents
            if nextpos < end
        ]

    def install(self, pool, shared=None):
        for block, address in enumerate(self.addresses):
            for _, plane, start, end in (r for r in self.ranges() if r[0] == block):
                pool.replace_plane(address + start, plane, self.blocks[block][plane + start * 4 : plane + end * 4 : 4])


def prepare(scene, pool, cols, prepared):
    from world_stream import INTRO, replace

    w = scene.game_world
    from ship_rows import prepare as prepare_ships

    prepare_ships(scene, pool, cols)
    # background_cache_delta retains the empty coverage ring on the stage-one
    # $9Fxx -> $00xx jump. Check all possible rows in its two 32-camera
    # windows, including prepared ship metadata, before enabling the shortcut.
    empty_columns = {
        w.column_index[x >> 5]
        for lo, hi in ((0x9F00, 0xA11E), (0, 0x011E))
        for x in range(lo, hi + 1, 32)
    }
    assert empty_columns == {0}
    assert all(w.runs[w.columns[0][0][row]] == bytes([0]) for row in range(32))
    assert 0 not in scene.ship_column_programs
    assert all(
        not any(col == 0 for col, row in records)
        for records in scene.ship_row_layouts_by_region.values()
    )
    # The live water and ship seed occupy only the beginning of this reservation.
    water_tail = 0x41E00 + len(scene.ship_seed_data)
    assert 0x41E00 <= water_tail <= 0x44000
    if water_tail < 0x44000:
        pool.free.append([water_tail, 0x44000])
    # Complete rows are never retained as cloud source images.
    # Slot zero shares only the unused tail of the immutable strip-family pointers.
    # The cabinet's contiguous 64KB surface remains separate.
    scene.combined_slots = [[pool.runtime(BLOCK, 4096) for _ in range(3)]]
    cabinet_base = scene.ship_geometry_surface
    scene.combined_slots.append([cabinet_base + i * 4096 for i in range(4)])
    pool.runtime(8192, 4096, name="game_coverage")
    assert len(w.columns) <= 426, ("side 1 descriptor capacity", len(w.columns))
    scene.game_column_descriptors = [bytearray(2048), bytearray(len(w.columns) * 3)]
    scene.world_intro_tiles = prepared[INTRO][2]
    scene.world_initial_chunks = tuple(scene.world_routes[0][:2])
    scene.combined_arenas = {}
    scene.world_columns = {}
    # Whole-game strip silhouettes share 490 ready row programs (region
    # .row_programs of secondsight.ld). The card reads them through
    # the bank window at WINDOW_C000 with the BBR of the column families.
    # Shape families are immutable; a column names pixels and a family.
    from background_families import pack as pack_family

    shapes = Arena([pool.runtime(BLOCK)])
    row_programs = {}
    program = bytearray()
    family = {}
    for tile, pixels in enumerate(w.tiles):
        pointers = bytearray()
        for row in range(32):
            masks = [
                sum((pixels[row * 16 + g * 4 + p] != 15) << p for p in range(4)) for g in range(4)
            ]
            commands = bytearray()
            g = 0
            while g < 4:
                end = g + 1
                while end < 4 and masks[end] == masks[g]:
                    end += 1
                if masks[g]:
                    commands.extend((masks[g], g, end - g))
                g = end
            data = bytes([len(commands) // 3]) + commands
            if data not in row_programs:
                row_programs[data] = WINDOW_C000 + len(program)
                program.extend(data)
            pointers.extend(struct.pack("<H", row_programs[data]))
        family[tile] = shapes.put(pack_family(pointers))
    scene.combined_row_programs = bytes(program)
    for addr, data in zip(shapes.addresses, shapes.blocks):
        replace(pool, addr * 4, data)
    scene.combined_shared_arena = shapes
    scene.combined_shared_tail = ((shapes.used % BLOCK) + 127) & ~127
    scene.combined_slots[0].append(shapes.addresses[-1])
    addresses = scene.combined_slots[0]
    prefix = scene.combined_shared_tail
    intro_extents = [
        (3, p, max(0, prefix - p * 4096), 4096) for p in range(4) if prefix < (p + 1) * 4096
    ]
    # The permanent intro uses the shape tail first, then only as much of
    # the last section block as it needs. Other sections use all leftovers.
    intro_extents.extend((2, p, 0, 4096) for p in reversed(range(4)))
    intro_arena = SharedArena(addresses, intro_extents)
    print("Shared strip programs", len(program), "family pointers", shapes.used, flush=True)

    def section(region, addresses):
        ship_layouts = scene.ship_row_layouts_by_region[region]
        if region == INTRO:
            arena = intro_arena
        elif addresses == scene.combined_slots[0]:
            extents = [(b, p, 0, 4096) for b in range(2) for p in range(4)]
            extents.extend(intro_arena.unused())
            arena = SharedArena(addresses, extents)
        else:
            # The fourth block is the matching side-1 ship geometry.
            assert addresses == scene.combined_slots[1]
            arena = Arena(addresses[:3])
        desc = {}
        for col in cols[region]:
            if region != INTRO and col in cols[INTRO]:
                continue
            column = b"".join(
                scene.world_tile_addresses[scene.world_colors[tile]].to_bytes(3, "little")
                + family[tile]
                for tile in w.column_tiles[col]
            )
            cloud = arena.put(column)
            roots = bytearray(cloud)
            for row in range(32):
                ready = w.prepared_runs[w.columns[col][0][row]]
                decoded = []
                last = 0
                for end, mask in zip(ready[3::2], ready[4::2]):
                    decoded.extend([mask] * (end - last))
                    last = end
                coverage = bytes(decoded[p] | (decoded[p + 1] << 4) for p in range(0, 64, 2))
                kind = 0 if not any(decoded) else 2 if all(m == 15 for m in decoded) else 1
                if (col, row) in ship_layouts:
                    kind |= 8
                # A prepared ship column only where this section holds its
                # geometry: a section with a full geometry block keeps some
                # columns on the per-plane path (scripts/ship_rows.py).
                if col in scene.ship_column_programs and (col, row) in ship_layouts:
                    kind |= 16
                # Water commands are already cropped, inverted and split to the
                # source pattern boundary. Runtime only intersects damage.
                # mask = the planes where the foreground is transparent (pixel
                # 15), so water lands only there. Both water patterns are 56
                # groups wide and x < 56: the 64-group split never happens.
                water = bytearray()
                g = 4
                while g < 60:
                    mask = decoded[g] ^ 15
                    end = g + 1
                    while end < 60 and decoded[end] ^ 15 == mask:
                        end += 1
                    if mask:
                        x = g - 4
                        while x < end - 4:
                            n = min(end - 4 - x, 64 - (x & 63))
                            water.extend((mask, x, n))
                            x += n
                    g = end
                gaps = []
                for x in range(56):
                    if decoded[x + 4] == 0:
                        if gaps and gaps[-1][1] == x:
                            gaps[-1][1] = x + 1
                        else:
                            gaps.append([x, x + 1])
                gap = max(gaps, key=lambda pair: pair[1] - pair[0], default=(0, 0))
                # Adjacent mask changes retain the DMA addresses. A source
                # repeat boundary still needs an address reload (never at
                # present: see the 56-group note above).
                last = -1
                for i in range(0, len(water), 3):
                    x, n = water[i + 1 : i + 3]
                    if x == last and x % 64:
                        water[i + 2] |= 128
                    last = x + n
                # For a sideways ship, merge opaque groups separately in
                # each plane. Mask changes in another plane do not split it.
                ship = bytearray()
                for plane in range(4):
                    spans = bytearray()
                    g = 4
                    while g < 60:
                        end = g + 1
                        opaque = bool(decoded[g] & (1 << plane))
                        while end < 60 and bool(decoded[end] & (1 << plane)) == opaque:
                            end += 1
                        if opaque:
                            spans.extend((g - 4, end - g))
                        g = end
                    ship.extend((len(spans) // 2,))
                    ship.extend(spans)
                outside = any(decoded[:4]) + any(decoded[60:])
                if outside or region in (INTRO, 26) or 18 <= region <= 21 or len(ship) >= 128:
                    ship.clear()
                    ship_count = 128
                elif not any(decoded):
                    ship.clear()
                    ship_count = 0
                else:
                    ship_count = len(ship)
                if (col, row) in ship_layouts:
                    ship_count = 255
                    ship = ship_layouts[col, row]
                roots.extend(
                    arena.put(
                        bytes([kind])
                        + coverage
                        + bytes(gap)
                        + bytes([len(water) // 3])
                        + water
                        + bytes([ship_count])
                        + ship
                    )
                )
            desc[col] = arena.put(roots) + bytes(1)
        print("Prepared background section", region, "bytes", arena.used, flush=True)
        return arena, desc

    intro, desc = section(INTRO, addresses)
    for col, data in desc.items():
        scene.game_column_descriptors[0][col * 4 : col * 4 + 4] = data
        scene.game_column_descriptors[1][col * 3 : col * 3 + 3] = data[:3]
    intro.install(pool)
    for region in prepared:
        if region == INTRO:
            continue
        side = scene.world_region_side[region]
        arena, desc = section(region, scene.combined_slots[side])
        scene.combined_arenas[region] = (arena, desc)
        scene.world_columns[region, side] = (0, b"", desc)
    unique = {data for arena, _ in scene.combined_arenas.values() for data in arena.shared}
    print("Shared metadata records", len(unique), "bytes", sum(map(len, unique)), flush=True)
    for region in scene.world_initial_chunks:
        arena, desc = scene.combined_arenas[region]
        arena.install(pool, scene.combined_shared_arena.blocks[-1])
        for col, data in desc.items():
            side = scene.world_region_side[region]
            stride = 4 if side == 0 else 3
            scene.game_column_descriptors[side][col * stride : col * stride + stride] = data[
                :stride
            ]
    from world_rows import initial as initialize_shared_rows

    initialize_shared_rows(scene, pool, scene.world_initial_chunks)
    scene.cabinet_surface = scene.combined_slots[1][0]
    assert scene.combined_slots[1][:4] == [scene.cabinet_surface + i * 4096 for i in range(4)]
    from game_sea import prepare as sea_features

    sea_features(scene, pool)
    from arcade_flow import prepare as cabinet

    cabinet(scene, pool)
    return dict(initial=scene.foreground_initial, last=65535, pan=0)


def jobs(scene, region):
    from asset_source import SRAM
    from secondsight_link import fixed
    from world_stream import SIDE1_LOW_BYTES, PlaneUpload, sram_jobs

    arena, desc = scene.combined_arenas[region]
    for block, p, start, end in arena.ranges():
        raw = bytes(arena.blocks[block][p::4])
        yield PlaneUpload(arena.addresses[block], p * 4096 + start, raw[start:end], 4096)
    # The descriptor tables (src/secondsight/fixed.ld), as physical SRAM.
    side0, low, high = (fixed(f"{name}__load") - SRAM for name in ("world_side0", "world_side1_low", "world_side1_high"))
    for column, data in sorted(desc.items()):
        side = scene.world_region_side[region]
        offset = column * 3
        address = (
            side0 + column * 4
            if side == 0
            else low + offset
            if offset < SIDE1_LOW_BYTES
            else high + offset - SIDE1_LOW_BYTES
        )
        yield from sram_jobs(address, data if side == 0 else data[:3])
