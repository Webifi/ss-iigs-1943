"""Build the complete ROM world into shared, scheduled card-upload packets.

Packets contain prepared final pixels and row commands. They are assets, not
recorded game states. Runtime selects a spatial cache and expands packets.
"""

from harness import HostData
import struct
import os
from collections import defaultdict
from startup_pack import pack
from stage_controls import event_tables, CONTROLS, FLOW_CONTROLS

# Whole map sections stay resident through their busy waves. One upcoming
# section shares the other slot; the intro is permanent in each command tail.
REGIONS = (
    [(i * 2048, i * 2048 + 2047) for i in range(18)]
    + [(i * 4096, i * 4096 + 4095) for i in range(9, 13)]
    + [(0xD000, 0xD7FF), (0xE000, 0xE7FF), (0xF000, 0xF7FF), (0xF800, 0xFFFF)]
)
CABINET = 26
REGIONS.append((0xE800, 0xEFFF))
INTRO = 22
COMMAND_PLANE = 5632
COMMAND_TAIL = 1600
COLUMN_PLANE = 6144
COLUMN_BYTES = COLUMN_PLANE * 4
# Each moving boss follows a short sea stretch. Keep their combined art in
# one residency unit, loaded during the earlier carrier/land quiet interval.
# The largest union is 236 strips; stage 16 already reserves 367 slots.
BOSS_RESIDENT_WITH = {24: 2, 23: 8, 25: 13}


def resident_ranges(c):
    return [
        (REGIONS[n][0], min(65535, REGIONS[n][1] + (0 if n == INTRO else 255)))
        for n in (c, *[b for b, a in BOSS_RESIDENT_WITH.items() if a == c])
    ]


def routes():
    tables, meta = event_tables()
    result = []

    def region(w):
        c = next(i for i, (lo, hi) in enumerate(REGIONS) if lo <= w <= hi)
        return BOSS_RESIDENT_WITH.get(c, c)

    for stage, table in enumerate(tables):
        sequence = []
        for off in range(0, meta[stage]["first_end_offset"] + 1, 6):
            _, callback, _, _ = struct.unpack_from("<HHBB", table, off)
            control = (CONTROLS | FLOW_CONTROLS).get(callback)
            if control is None:
                continue
            kind, n = control
            address = (
                0x9000 + n * 4096
                if kind == "land_camera"
                else n * 2048
                if kind == "ship_camera"
                else [0xF100, 0xE100, 0xF900][n]
                if kind == "boss_camera"
                else None
            )
            if address is not None:
                r = region(address)
                if not sequence or sequence[-1] != r:
                    sequence.append(r)
        result.append(sequence)
    return result


def prepare(scene, pool, initial):
    from foreground_cache import ForegroundCache
    from game_background import World

    scene.foreground_initial = initial
    scene.foreground_last = 65535
    scene.foreground_pan = 0
    scene.foreground_primary = False
    scene.banded_foreground = False
    scene.foreground_phases = (0, 1, 2, 3)
    scene.foreground_source = ForegroundCache(scene.a, pool, initial, allocate=False)
    scene.foreground_scratch = 0  # combined paths never read the retired scratch row
    world = World(scene.a)
    # Split horizontally only: two prepared 16x32 strips per tile. Sharing
    # identical strips reduces residency without per-pixel drawing work.
    strips = {}
    tile_strips = []
    for tile in world.tiles:
        tile_strips.append(
            [
                strips.setdefault(
                    b"".join(tile[y * 32 + x : y * 32 + x + 16] for y in range(32)), len(strips)
                )
                for x in (0, 16)
            ]
        )
    world.tiles = list(strips)
    world.column_tiles = [
        [b for tile in row for b in tile_strips[tile]] for row in world.column_tiles
    ]
    scene.game_world = world
    route = routes()
    side_map = {}
    for sequence in route:
        for i, c in enumerate(sequence):
            assert side_map.setdefault(c, i & 1) == i & 1
    side_map[CABINET] = 0
    scene.world_region_side = side_map
    units = sorted({c for sequence in route for c in sequence} | {INTRO, CABINET})
    # A viewport includes the following 255 rows at the end of a section.
    prepared = {c: world.region(resident_ranges(c)) for c in units}
    cols = {
        c: sorted(
            {
                world.column_index[n]
                for lo, hi in resident_ranges(c)
                for n in range(lo // 32, hi // 32 + 1)
            }
        )
        for c in units
    }
    intro_commands, intro_offsets, intro_tiles = prepared[INTRO]
    # The immutable intro shares the tails of the two command source slots.
    direct = bytearray(COMMAND_TAIL * 2)
    intro_offsets = {}
    at = 0
    for i in sorted({world.run(w, p) for w in range(0xD000, 0xD800) for p in range(4)}):
        row = world.packed_runs[i]
        if at < COMMAND_TAIL and at + len(row) > COMMAND_TAIL:
            at = COMMAND_TAIL
        assert at + len(row) <= len(direct), ("intro commands", at, len(row))
        intro_offsets[i] = (
            (0x6000 + COMMAND_PLANE - COMMAND_TAIL)
            + (at % COMMAND_TAIL)
            + (0x8000 if at >= COMMAND_TAIL else 0)
        )
        direct[at : at + len(row)] = row
        at += len(row)
    pairs = {(a, b) for sequence in route for a, b in zip(sequence, sequence[1:])}
    graph = defaultdict(set)
    for a, b in pairs | {(c, c) for c in units}:
        ids = set(prepared[a][2]) | set(prepared[b][2]) | set(intro_tiles)
        for tile in ids:
            graph[tile].update(ids - {tile})
    colors = {}
    remaining = set(graph)
    while remaining:
        node = max(
            remaining,
            key=lambda n: (len({colors[k] for k in graph[n] if k in colors}), len(graph[n]), -n),
        )
        used = {colors[k] for k in graph[node] if k in colors}
        color = 0
        while color in used:
            color += 1
        colors[node] = color
        remaining.remove(node)
    scene.world_slots = max(colors.values()) + 1
    print("World region tile slots:", scene.world_slots, flush=True)
    scene.world_routes = route
    scene.world_prepared = prepared
    scene.world_colors = colors
    import os

    scene.shared_world_rows = os.getenv("SS1943_ROW_SHARING", "1") != "0"
    if scene.shared_world_rows:
        from world_rows import prepare as prepare_shared_rows

        prepare_shared_rows(scene, pool, world, prepared, pairs, units)
    from combined_world import prepare as prepare_combined

    return prepare_combined(scene, pool, cols, prepared)


def replace(pool, address, data):
    pool.replace(address, data)


def packet(kind, bank, plane, segment, dest, data):
    """One <=256-byte expansion. The receiver never changes live art ownership."""
    data = bytes(data)
    assert 0 < len(data) <= 256
    packed = pack(data)
    return (
        struct.pack("<BBBBHHH", kind, bank, plane, segment, dest, len(data), len(packed)) + packed
    )


def vram_jobs(address, data):
    for plane in range(4):
        raw = bytes(data[plane::4])
        for off in range(0, len(raw), 256):
            ptr = address + off
            yield packet(
                1,
                0x92 + ((ptr & 65535) >> 12),
                1 << plane,
                ptr >> 16,
                0xE000 + (ptr & 4095),
                raw[off : off + 256],
            )


def sram_jobs(address, data):
    off = 0
    while off < len(data):
        p = address + off
        n = min(len(data) - off, 4096 - (p & 4095))
        packed = pack(data[off : off + n])
        bank, dest = (0, p) if p < 0xC000 else (((p >> 12) - 14) & 255, 0xE000 + (p & 4095))
        yield struct.pack("<BBBBHHH", 4, bank, 0, 0, dest, n, len(packed)) + packed
        off += n


def card_job(label, data, offset=0, literal=False):
    """One SRAM job to card label LABEL + OFFSET, a record in one 4 KB page.
    Its header waits for the card link. LITERAL sends DATA as one literal
    run, so the host can fill it in the packet."""
    from card_link import Late, symbol

    packed = bytes((len(data) - 1,)) + bytes(data) if literal else pack(data)

    def header():
        p = symbol(label) - 0x100000 + offset
        assert (p & 4095) + len(data) <= 4096, (label, hex(p), len(data))
        bank, dest = (0, p) if p < 0xC000 else (((p >> 12) - 14) & 255, 0xE000 + (p & 4095))
        return struct.pack("<BBBBHHH", 4, bank, 0, 0, dest, len(data), len(packed)) + packed

    return Late(10 + len(packed), header)


def plane_jobs(base, offset, data, plane_size):
    """Quiet-time metadata upload to its final packed VRAM plane."""
    done = 0
    while done < len(data):
        plane, off = divmod(offset + done, plane_size)
        ptr = base + off
        n = min(len(data) - done, plane_size - off, 4096 - (ptr & 4095))
        encoded = pack(data[done : done + n])
        while len(encoded) > 980:
            n = (n + 1) // 2
            encoded = pack(data[done : done + n])
        yield (
            struct.pack(
                "<BBBBHHH",
                5,
                0x92 + ((ptr & 65535) >> 12),
                plane,
                ptr >> 16,
                0xE000 + (ptr & 4095),
                n,
                len(encoded),
            )
            + encoded
        )
        done += n


def install(out, host, scene):
    world = scene.game_world
    # Scores occupy $01B300-$01B34F. Slots are initialized at $01B400;
    # keep their full generated extent and fill only the other fragments.
    slots_end = 0x400 + scene.world_slots * 2
    assert slots_end <= 0x1000, "world slots exceed bank-one scratch page"
    host.production_b_world = bytearray(0x1000)
    host.production_b_holes = [[0, 0x300], [0x350, 0x400], [slots_end, 0x1000]]
    host.production_b_allocations = []
    host.upload(0x116000, struct.pack("<2048H", *world.column_index))
    for i, (lo, hi) in enumerate(REGIONS):
        region = BOSS_RESIDENT_WITH.get(i, i)
        side = scene.world_region_side.get(region, 0)
        for page in range(lo >> 8, (hi >> 8) + 1):
            selected = int(page < 0x80 or 0xE0 <= page < 0xE8 or page >= 0xF0)
            assert side == selected, (
                "world descriptor side map",
                hex(page),
                region,
                side,
                selected,
            )
    # Each resident section owns its own column descriptors. The lookup
    # selects the matching table from the world row's region.
    host.upload(0x114800, scene.game_column_descriptors[0])
    host.upload(0x11B400, scene.game_column_descriptors[1][:510])
    host.upload(0x11BB00, scene.game_column_descriptors[1][510:])
    host.upload(0x118000, scene.combined_row_programs)
    from game_sea import install as install_sea

    install_sea(host, scene)
    shared = {}
    lists = {}
    largest = 0
    lz = os.getenv("SS1943_WORLD_LZ", "1") != "0"
    plan = {}
    for c in sorted({c for c, side in scene.world_columns}):
        for side in (scene.world_region_side[c],):
            commands, _, tiles = scene.world_prepared[c]
            entries = []
            base, payload, descriptors = scene.world_columns[c, side]
            from combined_world import jobs

            metadata = list(jobs(scene, c))
            from ship_rows import jobs as ship_jobs

            metadata.extend(ship_jobs(scene, c))
            batch = bytearray()
            for job in metadata:
                if len(batch) + len(job) > 1024:
                    entries.append((65535, 0, False, bytes(batch) + b"\0"))
                    batch.clear()
                batch.extend(job)
            if batch:
                entries.append((65535, 0, False, bytes(batch) + b"\0"))
            if scene.shared_world_rows:
                from world_rows import tile_packets

                for tile in tiles:
                    if tile in scene.world_intro_tiles:
                        continue
                    jobs = tile_packets(scene, tile)
                    entries.append((65535, 0, False, b"".join(jobs) + b"\0"))
            plan[c, side] = entries
    if lz:
        import world_packet_lz
        from world_dictionary import make

        world_packet_lz.set_dictionary(
            *make(
                [
                    job.ljust((len(job) + 1) & ~1, b"\0")
                    for entries in plan.values()
                    for *_, job in entries
                ]
            )
        )
        from world_packet_lz import D, SHORT, decompress
        from world_packet_opt import compress

        host.blob_at(D, "WORLD_LZ_DICT")
        host.blob_at(SHORT, "WORLD_LZ_SHORT")

    def blob(data):
        key = bytes(data)
        if key not in shared:
            shared[key] = host.production_world_blob_at(data)
        return shared[key]

    for (c, side), entries in plan.items():
        encoded = HostData()
        for slot, tile, last, job in entries:
            job = job.ljust((len(job) + 1) & ~1, b"\0")
            assert len(job) <= 1026, ("world packet exceeds receive reservation", len(job))
            wire_length = len(job)
            stored = job
            if lz:
                packed = compress(job)
                if packed is not None:
                    assert decompress(packed) == job
                    stored = packed
                    wire_length |= 0x8000
            addr = blob(stored)
            encoded.word(slot, tile, wire_length).faraddr(addr).byte(0)
        encoded.data(b"\xfe\xff" + bytes(8))
        lists[c, side] = blob(encoded)
        largest = max(largest, sum(len(e[3]) for e in entries))
    directory = [0] * 64
    for (c, side), p in lists.items():
        directory[c * 2 + side] = p
    nexts = bytearray([255] * (16 * 32 * 2))
    for stage, sequence in enumerate(scene.world_routes):
        for pos, c in enumerate(sequence):
            batch = sequence[pos : pos + 2]
            nexts[(stage * 32 + c) * 2 : (stage * 32 + c) * 2 + len(batch)] = bytes(batch)
        nexts[(stage * 32 + INTRO) * 2 : (stage * 32 + INTRO) * 2 + 2] = bytes(sequence[:2])
    by_high = bytearray([255] * 256)
    for i, (lo, hi) in enumerate(REGIONS):
        by_high[lo >> 8 : (hi >> 8) + 1] = bytes([BOSS_RESIDENT_WITH.get(i, i)]) * (
            (hi - lo + 1) // 256
        )
    initial = bytearray(b"\xff\xff" * scene.world_slots)
    for c in (*scene.world_initial_chunks, INTRO):
        for tile in scene.world_prepared[c][2]:
            struct.pack_into("<H", initial, scene.world_colors[tile] * 2, tile)
    print("World host assets", sum(map(len, shared)), "compressed blobs", len(shared), flush=True)
    host.blob_at(initial, "WORLD_INITIAL_SLOTS")
    (out / "game_world.inc").write_text(
        f"GAME_WORLD_NEXT = $1480\nWORLD_CABINET_ID = {CABINET}\nWORLD_DEMO_ID = 20\nWORLD_INTRO_ID = {INTRO}\nWORLD_DIRECTORY = {blob(HostData().dword(*directory)).label}\nWORLD_ROUTES = {blob(bytes(nexts)).label}\nWORLD_REGION_MAP = {blob(bytes(by_high)).label}\nWORLD_REGION_SIDE = {blob(bytes(scene.world_region_side.get(c, 255) for c in range(32))).label}\nWORLD_INITIAL_TAGS = {blob(bytes(scene.world_initial_chunks)).label}\nWORLD_SLOT_COUNT = {scene.world_slots}\n"
    )
    if lz:
        ceilings = bytes((REGIONS[i][1] >> 8) if i < len(REGIONS) else 0 for i in range(32))
        host.blob_at(ceilings, "WORLD_REGION_CEILING")
        with (out / "game_world.inc").open("a") as f:
            f.write("WORLD_LZ = 1\n")
    from arcade_flow import install as install_cabinet

    cabinet_bytes = install_cabinet(out, host, scene)
    return dict(
        foreground_writer_banks=[],
        foreground_card_bytes=32768 + 6144,
        foreground_mask_bytes=8192,
        foreground_tile_variants=scene.world_slots,
        world_asset_bytes=sum(len(x) for x in shared) + (len(D) + len(SHORT)),
        cabinet_bytes=cabinet_bytes,
        world_regions=len(lists),
        largest_world_transfer=largest,
    )


