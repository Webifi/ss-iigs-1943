"""Staged $D500 renderer: compact host assets, temporary free VRAM."""

from iigs_payload import HostData


def blocks_source(blocks, buffer, output):
    """build/secondsight/gen/hitch_stage_blocks_bufferN.s: the blocks of the draw
    helper that runs in packet buffer BUFFER (.hitch_stage_draw_N of
    secondsight.ld). OUTPUT is the symbol of the high byte of the buffer
    that receives the expanded data."""
    from secondsight_link import generate

    suffix = f"buffer{buffer}"
    # Each block: a world decompression header that expands into OUTPUT
    # (with the CBR of the game),
    # the fragment count, and per fragment its BBR, read segment, logical
    # source and byte count.
    lines = [
        f'        .section .rodata.hitch_stage_blocks_{suffix},"a"',
        f"hitch_stage_blocks_{suffix}:",
    ]
    from asset_source import PAGE, WINDOW_C000, vga_window_bbr

    for raw, n, frags in blocks:
        header = (4, "game_cbr", 0, 0, 0, output, raw & 255, raw >> 8, n & 255, n >> 8)
        lines.append("        .byte " + ",".join(v if isinstance(v, str) else f"0x{v:02X}" for v in header))
        lines.append(f"        .byte {len(frags)}")
        for group, count in frags:
            ptr = WINDOW_C000 + (group & (PAGE - 1))
            lines.append(f"        .byte 0x{vga_window_bbr(group):02X},0x{group >> 16:02X}")
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
    """The host packets of the stage scene: the stage art, and the helper
    code (the IIgs link puts in the linked helpers, src/host_jobs.inc)."""
    from asset_source import PAGE, WINDOW_E000, vga_window_cbr
    from world_stream import card_job, packet

    # The currently inactive packet buffer receives the helper, before the
    # current packet's state planner runs. The helper overwrites only raw
    # packet scratch after planning and before the next receive is armed.
    for buffer in (1, 0):
        blocks_source(scene.hitch_stage_blocks, buffer, f"packet_buffer_{1 - buffer}__high")

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
                        vga_window_cbr(ptr),
                        1 << plane,
                        ptr >> 16,
                        WINDOW_E000 + (ptr & (PAGE - 1)),
                        data[off : off + n],
                    )
                )
            )
    # The state job: one byte, 12 bytes with its header (even).
    jobs.append(card_job("hitch_d500_state", b"\x01"))
    batches = []
    batch = HostData()
    for job in jobs:
        if len(batch) + len(job) > 320:
            batches.append(batch)
            batch = HostData()
        batch += job
    if len(batch):
        batches.append(batch)
    directory = HostData()
    for data in batches:
        assert len(data) <= 320
        directory.word(len(data)).dword(host.blob_at(data))
    directory.data(bytes(6))
    host.blob_at(directory, "D500_STAGE_LIST")
    for i, buffer in enumerate((1, 0)):
        helper = HostData().linked_job(f"hitch_stage_draw_{buffer}") + card_job("hitch_d500_state", b"\x02")
        host.blob_at(helper, f"D500_HELPER{i}_ADDRESS", length=f"D500_HELPER{i}_LENGTH")
    print("D500 stage host jobs", len(jobs), flush=True)
