"""Staged $D500 renderer: compact host assets, temporary free VRAM."""

from harness import HostData


def blocks_source(blocks, origin, output_base):
    """build/card/gen/hitch_stage_blocks_ORIGIN.s: the blocks of the draw
    helper that runs at ORIGIN (region hitch-stage-draw-ORIGIN)."""
    from card_link import generate

    suffix = f"{origin:04x}"
    # Each block: a world decompression header that expands into OUTPUT_BASE,
    # the fragment count, and per fragment its BBR, read segment, logical
    # source and byte count.
    lines = [
        f'        .section .rodata.hitch_stage_blocks_{suffix},"a"',
        f"hitch_stage_blocks_{suffix}:",
    ]
    for raw, n, frags in blocks:
        header = (4, 0x84, 0, 0, 0, output_base >> 8, raw & 255, raw >> 8, n & 255, n >> 8)
        lines.append("        .byte " + ",".join(f"0x{v:02X}" for v in header))
        lines.append(f"        .byte {len(frags)}")
        for group, count in frags:
            ptr = 0xC000 + (group & 4095)
            lines.append(
                f"        .byte 0x{0x94 + ((group & 65535) >> 12):02X},0x{group >> 16:02X}"
            )
            lines.append(f"        .word 0x{ptr:04X},{count}")
    lines.append("        .byte 0")
    lines.insert(1, f"        .global hitch_stage_blocks_{suffix}")
    generate(f"hitch_stage_blocks_{suffix}", "\n".join(lines) + "\n")


def optimal_pack(data):
    """Minimize the existing bounded LZ format; no runtime codec changes."""
    from collections import defaultdict, deque
    from startup_pack import unpack

    data = bytes(data)
    chains = defaultdict(lambda: deque(maxlen=256))
    matches = []
    for i in range(len(data)):
        best = distance = 0
        for j in reversed(chains.get(data[i : i + 3], ())):
            n = 3
            limit = min(130, len(data) - i)
            while n < limit and data[j + n] == data[i + n]:
                n += 1
            if n > best:
                best, distance = n, i - j
            if n == limit:
                break
        matches.append((best, distance))
        chains[data[i : i + 3]].append(i)
    size = len(data)
    cost = [0] * (size + 1)
    choice = [None] * size
    for i in range(size - 1, -1, -1):
        best = 1 << 30
        selected = None
        for n in range(1, min(128, size - i) + 1):
            v = 1 + n + cost[i + n]
            if v < best:
                best, selected = v, (False, n, 0)
        length, distance = matches[i]
        for n in range(3, length + 1):
            v = 3 + cost[i + n]
            if v < best:
                best, selected = v, (True, n, distance)
        cost[i] = best
        choice[i] = selected
    out = bytearray()
    i = 0
    while i < size:
        match, n, distance = choice[i]
        if match:
            out.append(128 + n - 3)
            out.extend(distance.to_bytes(2, "little"))
        else:
            out.append(n - 1)
            out.extend(data[i : i + n])
        i += n
    assert unpack(out) == data
    return bytes(out)


def prepare(scene, pool):
    from game_water import stage
    from startup_pack import pack

    w = scene.game_world
    water, _ = stage(scene.a)
    rows = []
    for y in range(256):
        world = 0xD5FF - y
        strips = w.column_tiles[w.column_index[world >> 5]]
        row = b"".join(w.tiles[t][(world & 31) * 16 : (world & 31) * 16 + 16] for t in strips)[
            16:240
        ]
        assert len(row) == 224
        occupied = [i for i in range(56) if any(v != 15 for v in row[i * 4 : i * 4 + 4])]
        if not occupied:
            rows.append(b"\0\0")
            continue
        first, last = occupied[0], occupied[-1] + 1
        assert occupied == list(range(first, last)), (y, occupied)
        pixels = bytes(
            row[x] if row[x] != 15 else water[(world % 30) * 256 + x]
            for x in range(first * 4, last * 4)
        )
        rows.append(bytes((first, last - first)) + pixels)
    rawblocks = []
    cur = bytearray()
    for row in rows:
        nxt = cur + row
        if cur and (len(nxt) > 1792 or len(pack(nxt)) > 756):
            rawblocks.append(bytes(cur))
            cur = bytearray(row)
        else:
            cur = nxt
    if cur:
        rawblocks.append(bytes(cur))
    encoded = [optimal_pack(b) for b in rawblocks]
    assert all(len(raw) <= 1792 and len(enc) <= 756 for raw, enc in zip(rawblocks, encoded))
    # One run-time staging area inside one 4096-group window: the host sends
    # the blocks when the stage scene starts, so nothing loads it at boot.
    sizes = [(len(enc) + 3) // 4 for enc in encoded]
    area = pool.runtime(sum(sizes) * 4, 4096, load=False, name="hitch_stage_area")
    scene.hitch_stage_area = area
    blocks = []
    payloads = []
    for raw, enc, groups in zip(rawblocks, encoded, sizes):
        wire = enc.ljust(groups * 4, b"\0")
        frags = [(area, groups)]
        area += groups
        for plane in range(4):
            off = plane * groups
            for group, n in frags:
                payloads.append((group, plane, wire[off : off + n]))
                off += n
            assert off == (plane + 1) * groups
        blocks.append((len(raw), len(enc), frags))
    scene.hitch_stage_blocks = blocks
    scene.hitch_stage_payloads = payloads
    scene.hitch_stage_ranges = sorted(
        {(g * 4, (g + n) * 4) for _, _, frags in blocks for g, n in frags}
    )
    print("D500 staging VRAM:", sum(sizes) * 4, "bytes, blocks", len(blocks), flush=True)


def install(scene, host):
    """The host packets of the stage scene, after the final link (they hold
    the helper code)."""
    from card_link import after_link

    # The currently inactive packet buffer receives the helper, before the
    # current packet's state planner runs. The helper overwrites only raw
    # packet scratch after planning and before the next receive is armed.
    blocks_source(scene.hitch_stage_blocks, 0x8000, 0x4000)
    blocks_source(scene.hitch_stage_blocks, 0x4000, 0x8000)
    after_link(lambda: _install(scene, host))


def _install(scene, host):
    from card_link import region_image
    from world_stream import packet, sram_jobs
    import struct

    def even(job):
        job = bytearray(job)
        if len(job) & 1:
            n = int.from_bytes(job[8:10], "little") + 1
            job[8:10] = n.to_bytes(2, "little")
            job.append(0)
        assert not len(job) & 1
        return bytes(job)

    jobs = []
    for group, plane, data in scene.hitch_stage_payloads:
        for off in range(0, len(data), 128):
            ptr = group + off
            n = min(128, len(data) - off)
            jobs.append(
                even(
                    packet(
                        1,
                        0x92 + ((ptr & 65535) >> 12),
                        1 << plane,
                        ptr >> 16,
                        0xE000 + (ptr & 4095),
                        data[off : off + n],
                    )
                )
            )
    jobs.extend(even(j) for j in sram_jobs(0x7BF9, b"\x01"))
    batches = []
    batch = bytearray()
    for job in jobs:
        if len(batch) + len(job) > 320:
            batches.append(bytes(batch))
            batch.clear()
        batch.extend(job)
    if batch:
        batches.append(bytes(batch))
    jobs = batches
    directory = HostData()
    for data in jobs:
        assert len(data) <= 320
        directory.word(len(data)).dword(host.blob_at(data))
    directory.data(bytes(6))
    host.blob_at(directory, "D500_STAGE_LIST")
    descriptors = []
    helpers = [region_image(f"hitch-stage-draw-{dest:04x}") for dest in (0x8000, 0x4000)]
    for dest, code in zip((0x8000, 0x4000), helpers):
        items = list(sram_jobs(dest, code))
        assert len(items) == 1
        data = even(items[0]) + b"".join(even(j) for j in sram_jobs(0x7BF9, b"\x02"))
        descriptors.append((len(data), host.blob_at(data, f"D500_HELPER{len(descriptors)}_ADDRESS")))
    p = scene.build_out / "game_world.inc"
    with p.open("a") as f:
        f.write(f"D500_STAGE_COUNT = {len(jobs)}\n")
        for i, (length, _) in enumerate(descriptors):
            f.write(f"D500_HELPER{i}_LENGTH = {length}\n")
    print(
        "D500 stage host jobs",
        len(jobs),
        "helper bytes",
        [len(code) for code in helpers],
        "packed helper bytes",
        [x[0] for x in descriptors],
        flush=True,
    )
