"""Tsunami wave art and painter, and the Lightning bolt painter.

Tsunami runs only where the arcade allows it: the light-water ship scenes
($E145, port $1B05). The sea and the camera stand still during the attack,
so the wave is painted onto each display page and kept there
(special_wave_draw, src/secondsight/special_wave.s):
- each picture paints only the advancing front (a ragged foam edge from the
  1943ua wave art, then the white body), and repaints the body on rows whose
  sprite damage was just repaired;
- the background returns behind the wave from the page's clean rows in two
  passes, each a random two of every four pixels per row, so the tail
  dissolves in a diffuse dither.
"""

import random
from collections import Counter
from iigs_payload import HostData
from world_stream import vram_jobs

# Wave texture: 8 rows (screen row & 7) of 64 groups; the first FRINGE groups
# are the front edge, the rest repeat one body group.
FRINGE = 8
WAVE_ROW = 64


def texture(scene):
    a = scene.a
    w = scene.game_world

    def row(y):
        strips = w.column_tiles[w.column_index[y // 32]]
        return b"".join(w.tiles[t][(y % 32) * 16 : (y % 32 + 1) * 16] for t in strips)

    source = {y: row(y) for y in range(0xD800, 0xDC00)}
    assert all(len(r) == 256 for r in source.values())
    # Reuse already displayed colours. Water DAC entries change on every
    # picture, so a wave pixel may never name an animated-water slot. The
    # candidates still include the cloud-flash entries and the bolt slots;
    # that is safe only while Tsunami never sets the cloud flash ($80).
    water = set(a.water_slots)
    fixed = set(range(256)) - water - {15}

    def rgb(i):
        return a.palette[3 * i : 3 * i + 3]

    def distance(i, j):
        return sum((int(x) - int(y)) ** 2 for x, y in zip(rgb(i), rgb(j)))

    def lum(i):
        return sum(rgb(i)) / 3

    def front(r):
        """Each band row: water, a mixed light/blue front, a white core. The
        core and the 4*FRINGE pixels on its light side, outside first."""
        white = [i != 15 and lum(i) > 215 for i in r]
        best = (0, 0, 0)
        x = 0
        while x < 256:
            if not white[x]:
                x += 1
                continue
            end = x
            while end < 256 and white[end]:
                end += 1
            if end - x > best[0]:
                best = (end - x, x, end)
            x = end
        length, start, end = best
        n = 4 * FRINGE
        if length < 64 or start < n or end + n > 256:
            return None

        def light(seg):
            return sum(1 for i in seg if i != 15 and 110 < lum(i) <= 215)

        left, right = r[start - n : start], r[end : end + n]
        edge = left if light(left) >= light(right) else bytes(reversed(right))
        return edge, r[start:end]

    rows = None
    for y in range(0xD800, 0xDC00 - 8):
        found = [front(source[y + k]) for k in range(8)]
        if all(found):
            rows = found
            break
    assert rows, "no wave rows with a complete front and core"
    # The body is one plain white: the most common core colour.
    white = Counter(v for edge, core in rows for v in core).most_common(1)[0][0]
    raw = [edge + bytes([white]) * (4 * (WAVE_ROW - FRINGE)) for edge, core in rows]
    # Transparent front pixels become colour 39, a light-water blue.
    pixels = [bytes(39 if v == 15 else v for v in r) for r in raw]
    remap = {
        i: min(fixed, key=lambda j: distance(i, j)) if i in water else i
        for i in {v for r in pixels for v in r}
    }
    result = b"".join(bytes(remap[v] for v in r) for r in pixels)
    assert len(result) == 2048 and not set(result) & water
    return result, remap


def row_table():
    """Per-row random bytes of the painter. Bits 0-3: the two pixels of each
    four-pixel group that the first tail pass returns (the second returns the
    other two). Bits 4-5: the front edge offset in groups, a smooth random
    walk. Bits 6-7: the tail start offset, random. Bits 3-7 also give chunk
    phases."""
    rnd = random.Random(1943)
    masks = (3, 5, 6, 9, 10, 12)
    out = []
    v = 1
    last = 0
    for _ in range(32):
        m = rnd.choice([x for x in masks if x != last])
        last = m
        v = max(0, min(3, v + rnd.choice((-1, 0, 0, 1))))
        out.append(m | v << 4 | rnd.randrange(4) << 6)
    return bytes(out)


def reserve_bolts(scene, pool):
    # Three compact planes stay resident. Reserve a single 4K-aperture span
    # before D500 and header staging choose their independent free regions.
    planes = bolts(scene)
    data = bytearray(1216 * 4)
    for plane, raw in enumerate(planes):
        data[plane::4] = raw
    pool.runtime(bytes(data), 4096, name="bolt_table")
    from secondsight_link import define

    # Both bolt pens always show one colour, so they share one DAC entry.
    define("bolt_light_pen", scene.a.bolt_slots[0])
    define("bolt_blue_pen", scene.a.bolt_slots[0])


def prepare(scene, pool):
    art, remap = texture(scene)
    ranges = []
    for lo, hi in sorted(scene.hitch_stage_ranges):
        if ranges and ranges[-1][1] == lo:
            ranges[-1][1] = hi
        else:
            ranges.append([lo, hi])
    wave = next(
        (lo // 4 for lo, hi in ranges if hi - lo >= 2048 and ((lo // 4) & 4095) + 512 <= 4096), None
    )
    assert wave is not None, ("no contiguous D500 wave source", ranges)
    scene.special_wave_span = (wave * 4, (wave + 512) * 4)
    scene.special_wave_art = art
    from secondsight_link import alias, generate_include

    generate_include(
        "tsunami_rows",
        "; Generated by scripts/special_wave.py (row_table).\n        .byte "
        + ", ".join(f"0x{v:02X}" for v in row_table())
        + "\n",
    )

    # The wave source shares the stage staging area: label special_wave.
    alias("special_wave", f"hitch_stage_area + 0x{(wave - scene.hitch_stage_area) * 4:X}")
    print("SPECIAL D500 wave", hex(wave * 4), "palette", remap, flush=True)


def bolts(scene):
    w = scene.game_world
    planes = []
    for first in (0xDE00, 0xDD00, 0xDC00):
        table = bytearray()
        for sy in range(0, 256, 2):
            y = first + 255 - sy
            strips = w.column_tiles[w.column_index[y // 32]]
            row = b"".join(w.tiles[t][(y % 32) * 16 : (y % 32 + 1) * 16] for t in strips)[16:240]
            pixels = [v != 15 for v in row]
            spans = []
            x = 0
            while x < 224:
                if not pixels[x]:
                    x += 1
                    continue
                end = x + 1
                while end < 224 and pixels[end]:
                    end += 1
                spans.append((x, end))
                x = end
            spans = sorted(sorted(spans, key=lambda v: -(v[1] - v[0]))[:3])
            groups = {}
            for start, end in spans:
                for x in range(start, end):
                    groups[x // 4] = groups.get(x // 4, 0) | (1 << (x & 3))
            runs = []
            for index in sorted(groups):
                if not runs or index != runs[-1][-1] + 1:
                    runs.append([])
                runs[-1].append(index)
            assert runs, ("empty bolt row", first, sy)
            # Two bytes per row header, then word-aligned runs. A run word
            # packs a six-bit group delta, two-bit length, and two masks.
            # Runs longer than four groups split at the same exact pixels.
            split = [run[i : i + 4] for run in runs for i in range(0, len(run), 4)]
            table.extend((len(split), split[0][0]))
            previous_end = 0
            for run in split:
                delta = run[0] - previous_end
                length = len(run)
                assert 0 <= delta < 56 and 1 <= length <= 4
                mask0 = groups[run[0]]
                mask1 = groups[run[1]] if length >= 2 else 0
                table.extend((delta | ((length - 1) << 6), mask0 | (mask1 << 4)))
                if length >= 3:
                    mask2 = groups[run[2]]
                    mask3 = groups[run[3]] if length >= 4 else 0
                    table.extend((mask2 | (mask3 << 4), 0))
                previous_end = run[-1] + 1
        assert len(table) <= 1216, (first, len(table))
        table.extend(bytes(1216 - len(table)))
        planes.append(bytes(table))
    return planes


def install(scene, host):
    """The host packets of the special wave: its art, and the hook jobs (the
    IIgs link puts in the linked instructions, src/host_jobs.inc)."""
    lo, hi = scene.special_wave_span
    base = lo // 4

    def directory(name, jobs):
        batches = []
        current = bytearray()
        for raw in jobs:
            job = bytearray(raw)
            if len(job) & 1:
                n = int.from_bytes(job[8:10], "little") + 1
                job[8:10] = n.to_bytes(2, "little")
                job.append(0)
            assert len(job) <= 1000
            if len(current) + len(job) > 1000:
                batches.append(bytes(current))
                current.clear()
            current.extend(job)
        if current:
            batches.append(bytes(current))
        out = HostData()
        for data in batches:
            out.word(len(data)).dword(host.blob_at(data))
        out.data(bytes(6))
        host.blob_at(out, name)
        print(
            "SPECIAL",
            name,
            "upload",
            len(batches),
            "packets",
            sum(map(len, batches)),
            "host bytes",
            flush=True,
        )

    directory("SPECIAL_WAVE_LIST", list(vram_jobs(base, scene.special_wave_art)))
    # Attack packets write a jump (src/secondsight/special_wave.s) over the first
    # instruction of stream_arm_next and water_commit; a cleanup packet
    # restores the linked instructions.
    on = HostData().linked_literal("water_commit", "special_hooks", "special_hook_water")
    off = HostData().linked_literal("water_commit", "state_planner", "water_commit")
    off.linked_literal("stream_arm_next", "playfield.code", "stream_arm_next")
    with (scene.build_out / "game_world.inc").open("a") as f:
        for kind, data in (("ON", on), ("OFF", off)):
            host.blob_at(data, f"SPECIAL_HOOK_{kind}_ADDRESS")
            f.write(f"SPECIAL_HOOK_{kind}_LENGTH = {len(data)}\n")


def install_draw(scene, host):
    """The host packets of the four draw helpers (.special_*_helper_N of
    secondsight.ld): the hook jump over stream_arm_next, then the helper,
    packed and padded to an even length (src/host_jobs.inc)."""
    for kind in ("WAVE", "BOLT"):
        for index, buffer in enumerate((1, 0)):
            data = HostData().linked_literal("stream_arm_next", "special_hooks", "special_hook_draw")
            data.linked_job(f"special_{kind.lower()}_helper_{buffer}")
            name = f"SPECIAL_{kind}_HELPER{index}"
            host.blob_at(data, f"{name}_ADDRESS", length=f"{name}_LENGTH")
