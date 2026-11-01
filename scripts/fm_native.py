"""Native data for the FM part engine (src/fm_voice.s).

Records, shared tables and a score whose NOTE tokens already name the capture
and its DOC frequency. The IIgs does no pitch arithmetic, no capture choice
and no curve fitting; it steps the same integers as scripts/fm_voice.py.
"""

import json, math, struct
from collections import Counter
from iigs_payload import HostData
from fm_voice import native_model, Curve, REGISTER, WEIGHT, BOOST, SILENT, VISIT, hold_volumes
from music_score import read_event, NOTE, LOOP, END, OFF, SHARED, DELAY_LONG

from sound_files import BANK
RECORD_HEAD = 33
REGISTER_LOW = 64
# Incoming $2E page alternatives covering every checked $29 current-note set.
# Stable pages for the 76 capture IDs, from an offline placement search;
# checked against every actual plan below.
FM_STABLE_PAGES = (
    0xA0,
    0x80,
    0xC5,
    0x87,
    0x9C,
    0xA2,
    0xCC,
    0x7E,
    0x8A,
    0xE4,
    0x75,
    0x7C,
    0x94,
    0xA0,
    0xB0,
    0xCC,
    0xC6,
    0xA8,
    0x8A,
    0x6C,
    0xCE,
    0xB8,
    0x7F,
    0x78,
    0xCC,
    0x9E,
    0xB5,
    0xAC,
    0x82,
    0x6C,
    0x8E,
    0xE4,
    0x9C,
    0xB4,
    0x95,
    0xB4,
    0xE4,
    0x84,
    0x7E,
    0x6C,
    0xE4,
    0x90,
    0x6C,
    0xD2,
    0xC6,
    0xCC,
    0x92,
    0xC0,
    0x7C,
    0xBC,
    0x76,
    0xEA,
    0xE4,
    0x90,
    0x8A,
    0x84,
    0xD1,
    0x8A,
    0x82,
    0x6C,
    0xE6,
    0xDE,
    0x72,
    0xE4,
    0xD8,
    0xA8,
    0x72,
    0xF0,
    0xC2,
    0x84,
    0xBC,
    0x7E,
    0xB9,
    0xA2,
    0x6C,
    0x73,
)
FM_BOSS_PAGES = {
    16: 0xCD,
    17: 0x86,
    18: 0x98,
    19: 0xBB,
    20: 0xC1,
    21: 0x9E,
    22: 0x92,
    23: 0xD8,
    32: 0xF0,
    35: 0xB0,
    53: 0xDE,
    56: 0xAA,
    58: 0xEA,
    59: 0xC7,
    60: 0xD5,
    61: 0xB8,
    62: 0x80,
    63: 0xD3,
    64: 0x6C,
    67: 0x78,
}
FM_STAGE30_PAGES = {
    35: 0xB0,
    36: 0xB8,
    37: 0xC4,
    38: 0x92,
    39: 0xD0,
    44: 0xAA,
    45: 0x98,
    46: 0xA4,
    47: 0xEA,
    64: 0x6C,
    67: 0x78,
}


def hz(word):
    return (1500000 / 36) * (((word & 2047) << ((word >> 11) & 7)) >> 1) / (1 << 21)


FM_ENDING_PAGES = {
    24: 0xB8,
    25: 0x86,
    26: 0x80,
    27: 0xEA,
    32: 0xB8,
    35: 0x72,
    36: 0xDC,
    37: 0xD0,
    38: 0xCA,
    39: 0x7A,
    44: 0xA6,
    45: 0x86,
    46: 0x99,
    47: 0xC4,
    56: 0x9F,
    58: 0x93,
    59: 0x6C,
    64: 0xAC,
    65: 0xE8,
    66: 0xD0,
    67: 0xF0,
}


def models():
    """FM captures in a fixed order, with their tables and native data."""
    import numpy as np
    from audio_preview import layout

    rows = [
        m
        for m in json.loads((BANK / "models.json").read_text())
        if m["source"]["kind"] == "instrument"
    ]
    out = []
    for m in sorted(rows, key=lambda m: m["name"]):
        w = dict(np.load(BANK / (m["name"] + ".npz")))
        data, places = layout(w)
        out.append(dict(model=m, native=native_model(m, w), places=places, data=data))
    return out


def attack_entries(n):
    """Per attack tick t: the scan key and the note's state when it starts
    there (hold curve stepped t times, stage, fade), so a note start reads
    one entry instead of stepping."""
    curve = Curve(*n["envelope"])
    stages = n["stages"]
    out = b""
    assert len(n["attack"]) - 1 <= n["hold"]
    for t, v in enumerate(n["attack"]):
        if t:
            curve.step()
        cur = max((i for i, s in enumerate(stages) if s["tick"] <= t), default=0)
        alpha = (t - stages[cur]["tick"]) * stages[cur]["step"] if cur + 1 < len(stages) else 0
        left = curve.left
        assert (
            0 <= alpha < 65536
            and 0 <= curve.level < 65536
            and (left > 0) == (curve.index < len(curve.points))
        )
        out += struct.pack("<HHBBBH", v, curve.level, curve.index, left, cur, alpha)
    return out


def record(item, table_source, packed=False, hold_ticks=None):
    """One capture's native record. Offsets are from the record start. With
    hold_ticks (the longest hold its notes play), the record ends with the
    held-note volume table up to the last EG time a hold visit can reach."""
    n = item["native"]
    places = item["places"]
    data = item["data"]
    stages = b"".join(
        struct.pack("<HBBhH", s["tick"], places[s["table"]] >> 8, s["boost"], s["att"], s["step"])
        for s in n["stages"]
    )
    env = b"".join(struct.pack("<BBhH", t, 0, slope, goal) for t, slope, goal in n["envelope"][1])
    attack = attack_entries(n)
    heads = b""
    points = b""
    after = RECORD_HEAD + len(stages) + len(env) + len(attack) + 8 * len(n["releases"])
    for r in n["releases"]:
        heads += struct.pack(
            "<HBBHH", r["start"], len(r["points"]), 0, r["length"], after + len(points)
        )
        points += b"".join(
            struct.pack("<BBhH", t, 0, slope, goal) for t, slope, goal in r["points"]
        )
    holds = b"".join(struct.pack("<HB", h, i) for h, i in n["holds"])
    offsets = [
        RECORD_HEAD,
        RECORD_HEAD + len(stages),
        RECORD_HEAD + len(stages) + len(env),
        RECORD_HEAD + len(stages) + len(env) + len(attack),
        after + len(points),
    ]
    assert (
        len(n["stages"]) < 256
        and len(n["envelope"][1]) < 256
        and len(n["attack"]) < 256
        and len(n["releases"]) < 256
        and len(n["holds"]) < 256
    )
    assert all(b["tick"] - a["tick"] >= 2 for a, b in zip(n["stages"], n["stages"][1:])), (
        "one stage change a tick"
    )
    assert n["holds"] and all(
        t >= 1 for t, _, _ in n["envelope"][1] + [p for r in n["releases"] for p in r["points"]]
    )
    assert all(0 <= h < 0x8000 for h, _ in n["holds"]) and all(
        a[0] < b[0] for a, b in zip(n["holds"], n["holds"][1:])
    ), "FM hold search requires increasing nonnegative times"
    assert (
        0
        <= min(s["att"] for s in n["stages"]) - max(s["boost"] for s in n["stages"]) + REGISTER_LOW
    ), "register table offset"
    assert n["every"] == VISIT, "fm_voice_tick visits each part every VISIT ticks"
    head = struct.pack(
        "<BBHhHBBBBH",
        n["size"],
        len(n["stages"]),
        n["hold"],
        n["peak_att"],
        n["every"],
        len(n["envelope"][1]),
        len(n["attack"]),
        len(n["releases"]),
        len(n["holds"]),
        len(data) | (0x8000 if packed else 0),
    )
    body = stages + env + attack + heads + points + holds
    taboff = length = 0
    volumes = b""
    if hold_ticks is not None:
        length = min(max(n["hold"], n["stages"][-1]["tick"]), len(n["attack"]) - 1 + hold_ticks)
        taboff = RECORD_HEAD + len(body)
        volumes = hold_volumes(n, length)
    # Key-off search start per 16 EG ticks up to the table end: the nearest
    # hold (first of equals) at the bucket's first tick, a lower bound for
    # every tick in it, so the forward scan finds the same hold.
    nearest = lambda et: min(range(len(n["holds"])), key=lambda i: (abs(n["holds"][i][0] - et), i))
    buckets = bytes(nearest(16 * b) for b in range(length // 16 + 1))
    bucketoff = RECORD_HEAD + len(body) + len(volumes)
    assert bucketoff + len(buckets) <= 65536 and max(buckets) < 128
    tail = b"".join(struct.pack("<H", o) for o in offsets) + struct.pack("<HHH", taboff, length, bucketoff)
    assert len(head) + 3 + len(tail) == RECORD_HEAD
    return HostData().data(head).faraddr(table_source).data(tail + body + volumes + buckets)


def hold_lengths(pool, parts, dictionary):
    """Per capture, the longest a note holds before its key-off, the next
    note or the end (a key-off on the start tick does not act), over every
    part played through its loop twice."""
    out = {}
    for part in parts:
        data = pool[part["offset"] : part["offset"] + part["bytes"]]
        horizon = part["end_tick"] + 2 * (part["loop"]["end_tick"] if part["loop"] else 0)
        pc = 0
        tick = 0
        count = 0
        loop_at = -1
        held = None
        for _ in range(400000):
            origin = pc
            kind, delay, pc, args = read_native_event(data, pc, dictionary)
            tick += delay
            if tick > horizon:
                tick = horizon
                break
            if kind == NOTE and not args[0] & 128:
                held = (args[0] & 127, tick)
            elif kind == OFF and held and tick > held[1]:
                out[held[0]] = max(out.get(held[0], 0), tick - held[1])
                held = None
            elif kind == END:
                break
            elif kind == LOOP:
                n, target = args
                if n == 0:
                    pc = target
                    count = 0
                    loop_at = -1
                elif loop_at != origin:
                    count = n - 1
                    loop_at = origin
                    pc = target
                elif count:
                    count -= 1
                    pc = target
                else:
                    loop_at = -1
        if held:
            out[held[0]] = max(out.get(held[0], 0), tick - held[1])
    return out


def pack_capture(data):
    """Four independently selected delta/raw blocks per 64-byte upload."""
    assert len(data) % 64 == 0
    result = bytearray()
    prev = 128
    for off in range(0, len(data), 64):
        flags = 0
        blocks = []
        for block in range(4):
            raw = data[off + 16 * block : off + 16 * (block + 1)]
            deltas = []
            for value in raw:
                deltas.append(((value - prev + 128) & 255) - 128)
                prev = value
            if all(-8 <= d <= 7 for d in deltas):
                flags |= 1 << block
                blocks.append(
                    bytes((deltas[i] + 8) | ((deltas[i + 1] + 8) << 4) for i in range(0, 16, 2))
                )
            else:
                blocks.append(raw)
        result.append(flags)
        result.extend(b"".join(blocks))
    # Reconstruct every byte before making the packed data available to the player.
    out = bytearray()
    pos = 0
    prev = 128
    while len(out) < len(data):
        flags = result[pos]
        pos += 1
        for block in range(4):
            if flags >> block & 1:
                for value in result[pos : pos + 8]:
                    for nibble in (value & 15, value >> 4):
                        prev = (prev + nibble - 8) & 255
                        out.append(prev)
                pos += 8
            else:
                raw = result[pos : pos + 16]
                out.extend(raw)
                prev = raw[-1]
                pos += 16
    assert pos == len(result) and out == data
    return bytes(result)


def native_score(items):
    """Native score from the decoded songs. Each NOTE body is the capture
    (bit 7 tie), its DOC frequency word, and the next different capture
    this part plays (the prefetch; $ff none). Bodies differ wherever play
    differs, so the repeat packer merges only notes that are truly the same."""
    from music import song
    from music_score import sample_plan, part_stream
    from roms import load
    from audio_config import DOC_RATE

    rom = load()[0]["audiocpu"][:32768]
    songs = [
        dict(song(rom, c, phase=phase), phase=phase) for c in range(32, 51) for phase in (0, 1)
    ]
    plans, bindings = sample_plan(songs, [it["model"] for it in items])
    plans = {p["sample"]: p for p in plans}
    index = {
        (it["model"]["source"]["sample"], it["model"]["source"]["capture_kind"]): i
        for i, it in enumerate(items)
    }

    def capture(sample, fc):
        p = plans[sample]
        f = fc * DOC_RATE / (1 << (17 + p["loop_resolution"])) * p.get("cycles_per_table", 1)
        return f, min(
            ("root", "high"),
            key=lambda k: abs(
                math.log2(f / hz(items[index[sample, k]]["model"]["source"]["fnum"]))
            ),
        )

    pool = bytearray()
    seen = {}
    parts = []
    for sg in songs:
        for part in sg["parts"]:
            events = part["events"]
            notes = []
            sounding = False
            current = None
            for i, e in enumerate(events):
                if e[1] == "on":
                    sample, fc, _ = bindings[e[3], e[2]]
                    f, kind = capture(sample, fc)
                    if not sounding:
                        current = index[sample, kind]
                    m = items[current]["model"]
                    notes.append(
                        dict(
                            index=i,
                            capture=current,
                            tie=sounding,
                            word=max(
                                1, min(65535, round(m["frequency"] * f / hz(m["source"]["fnum"])))
                            ),
                        )
                    )
                    sounding = True
                elif e[1] == "off":
                    sounding = False
            starts = [n for n in notes if not n["tie"]]
            loop = part["loop"]
            body = [n for n in starts if loop and events[n["index"]][0] >= loop["start_tick"]]
            prefetch = {}
            for k, n in enumerate(starts):
                ahead = starts[k + 1 :] + (body if loop else [])
                nxt = next((a["capture"] for a in ahead if a["capture"] != n["capture"]), 0xFF)
                prefetch[n["index"]] = nxt
            bodies = {
                n["index"]: struct.pack(
                    "<BHB",
                    n["capture"] | (128 if n["tie"] else 0),
                    n["word"],
                    prefetch.get(n["index"], 0xFF),
                )
                for n in notes
            }
            data = part_stream(part, bindings, note=lambda i: bodies[i])
            if data not in seen:
                seen[data] = len(pool)
                pool += data
            parts.append(
                dict(
                    command=sg["command"],
                    phase=sg["phase"],
                    channel=part["channel"],
                    priority=sg["priority"],
                    offset=seen[data],
                    bytes=len(data),
                    loop=loop,
                    end_tick=part["end_tick"],
                )
            )
    pool, dictionary = pack_notes(bytes(pool), parts)
    assert len(pool) <= 65536, len(pool)
    misses, first, lead = check_prefetch(pool, parts, items, dictionary)
    return pool, dict(
        parts=parts,
        misses=misses,
        first=first,
        shortest_lead=lead,
        bytes=len(pool),
        dictionary=dictionary,
    )


def pack_notes(pool, parts):
    """Share frequent four-byte native note bodies, preserving every loop."""
    streams = {
        (p["offset"], p["bytes"]): pool[p["offset"] : p["offset"] + p["bytes"]] for p in parts
    }
    counts = Counter()
    for data in streams.values():
        at = 0
        while at < len(data):
            kind, _, nxt, _ = read_event(data, at)
            if kind == NOTE:
                counts[data[nxt - 4 : nxt]] += 1
            at = nxt
    dictionary = [body for body, count in counts.most_common(256) if count * 3 > 4]
    index = {body: i for i, body in enumerate(dictionary)}
    packed = bytearray()
    locations = {}
    for key, data in streams.items():
        new = bytearray()
        positions = {}
        loops = []
        at = 0
        while at < len(data):
            positions[at] = len(new)
            kind, _, nxt, args = read_event(data, at)
            if kind == NOTE and data[nxt - 4 : nxt] in index:
                new.extend(
                    bytes([data[at] | SHARED << 5])
                    + data[at + 1 : nxt - 4]
                    + bytes([index[data[nxt - 4 : nxt]]])
                )
            else:
                new.extend(data[at:nxt])
                if kind == LOOP:
                    loops.append((len(new) - 2, args[1]))
            at = nxt
        positions[len(data)] = len(new)
        for patch, target in loops:
            struct.pack_into("<H", new, patch, positions[target])
        # Check every event and relocated loop destination, including events
        # beyond the first playthrough and all independently compiled phases.
        at = 0
        dictionary_bytes = b"".join(dictionary)
        while at < len(data):
            kind, delay, nxt, args = read_event(data, at)
            nk, nd, nn, na = read_native_event(new, positions[at], dictionary_bytes)
            if kind == LOOP:
                args = (args[0], positions[args[1]])
            assert (kind, delay, args, positions[nxt]) == (nk, nd, na, nn)
            at = nxt
        locations[key] = (len(packed), len(new))
        packed.extend(new)
    for p in parts:
        p["offset"], p["bytes"] = locations[p["offset"], p["bytes"]]
    return bytes(packed), b"".join(dictionary)


def read_native_event(data, pc, dictionary):
    if data[pc] >> 5 != SHARED:
        return read_event(data, pc)
    delay = data[pc] & DELAY_LONG
    pc += 1
    if delay == DELAY_LONG:
        delay = struct.unpack_from("<H", data, pc)[0]
        pc += 2
    ident = data[pc]
    pc += 1
    return NOTE, delay, pc, struct.unpack_from("<BHB", dictionary, ident * 4)


def check_prefetch(pool, parts, items, dictionary=b""):
    """Play every part's native stream through the two-buffer policy: a note
    plays from the buffer holding its capture, then loads its prefetch into
    the other buffer. Returns the notes that would find their capture
    missing, each part's first capture and the shortest (ticks, bytes)
    warning any upload gets."""

    misses = []
    first = {}
    lead = None
    for part in parts:
        data = pool[part["offset"] : part["offset"] + part["bytes"]]
        horizon = part["end_tick"] + 2 * (part["loop"]["end_tick"] if part["loop"] else 0)
        pc = 0
        tick = 0
        count = 0
        loop_at = -1
        buffers = None
        playing = 0
        pending = None
        for _ in range(400000):
            origin = pc
            kind, delay, pc, args = read_native_event(data, pc, dictionary)
            tick += delay
            if tick > horizon:
                break
            if kind == NOTE and not args[0] & 128:
                c = args[0] & 127
                if buffers is None:
                    first[part["command"], part["phase"], part["channel"]] = c
                    buffers = [c, None]
                if c in buffers:
                    playing = buffers.index(c)
                if pending and pending[0] == c:
                    w = (tick - pending[1], len(items[c]["data"]))
                    lead = w if lead is None or w[0] * lead[1] < lead[0] * w[1] else lead
                pending = None
                n = args[2]
                if n != 0xFF and n not in buffers:
                    buffers[1 - playing] = n
                    pending = (n, tick)
            elif kind == END:
                break
            elif kind == LOOP:
                n, target = args
                if n == 0:
                    pc = target
                    count = 0
                    loop_at = -1
                elif loop_at != origin:
                    count = n - 1
                    loop_at = origin
                    pc = target
                elif count:
                    count -= 1
                    pc = target
                else:
                    loop_at = -1
    return misses, first, lead


def cache_plan(pool, info, items, base):
    """One permanent DOC location per capture used by a song/phase.

    Initial captures load first, then other captures in order of first use.
    A later note never evicts an earlier capture. All locations stay within
    the six existing FM double-buffer reservations.
    """
    plans = []
    for command in range(32, 51):
        for phase in (0, 1):
            parts = [p for p in info["parts"] if p["command"] == command and p["phase"] == phase]
            events = []
            for part in parts:
                data = pool[part["offset"] : part["offset"] + part["bytes"]]
                horizon = part["end_tick"] + 2 * (part["loop"]["end_tick"] if part["loop"] else 0)
                pc = tick = count = 0
                loop_at = -1
                for _ in range(400000):
                    origin = pc
                    kind, delay, pc, args = read_native_event(data, pc, info["dictionary"])
                    tick += delay
                    if tick > horizon:
                        break
                    if kind == NOTE and not args[0] & 128:
                        events.append((tick, part["channel"], args[0]))
                    if kind == END:
                        break
                    if kind == LOOP:
                        n, target = args
                        if n == 0:
                            pc = target
                            count = 0
                            loop_at = -1
                        elif loop_at != origin:
                            count = n - 1
                            loop_at = origin
                            pc = target
                        elif count:
                            count -= 1
                            pc = target
                        else:
                            loop_at = -1
                else:
                    raise ValueError("score loop exceeds cache planning horizon")
            initial = []
            for ch in range(6):
                cap = info["first"].get((command, phase, ch), 0xFF)
                if cap != 0xFF and cap not in initial:
                    initial.append(cap)
            order = list(initial)
            for tick, ch, cap in sorted(events):
                if cap not in order:
                    order.append(cap)
            # Sharing removes repeated startup uploads. Use that byte budget
            # to preload imminent captures without enlarging startup traffic.
            budget = sum(
                len(items[info["first"][command, phase, ch]]["data"])
                for ch in range(6)
                if (command, phase, ch) in info["first"]
            )
            used = sum(len(items[cap]["data"]) for cap in initial)
            initial_count = len(initial)
            while (
                initial_count < len(order)
                and used + len(items[order[initial_count]]["data"]) <= budget
            ):
                used += len(items[order[initial_count]]["data"])
                initial_count += 1
            if command == 0x29:
                # The five first captures are preloaded before the boss cue;
                # later captures retain their first-use background order.
                initial_count = len(initial)
            assert len(order) <= 16, (command, phase, len(order))  # runtime directory is 34 bytes
            # The DOC masks its pointer by the waveform size. Verify both
            # the global placement and its bounds against this exact song.
            assert base == 0x6C00 and len(items) == len(FM_STABLE_PAGES)
            where = {
                cap: (
                    FM_BOSS_PAGES[cap]
                    if command == 0x29
                    else FM_STAGE30_PAGES[cap]
                    if command == 0x30
                    else FM_ENDING_PAGES[cap]
                    if command in (0x28, 0x2F)
                    else FM_STABLE_PAGES[cap]
                )
                * 256
                for cap in order
            }
            spans = []
            for cap in order:
                at = where[cap]
                length = 2048 if command == 0x30 and cap in (35, 67) else len(items[cap]["data"])
                alignment = 256 << ((items[cap]["native"]["size"] >> 3) & 7)
                assert at % alignment == 0 and base <= at and at + length <= base + 36864
                spans.append((at, at + length, cap))
            spans.sort()
            assert all(a[1] <= b[0] for a, b in zip(spans, spans[1:])), (command, phase, spans)
            desc = bytearray((len(order), initial_count))
            for cap in order:
                desc.extend((cap, where[cap] >> 8))
            plans.append(bytes(desc))
    return plans


def assets(host):
    """Place every native FM asset with host.blob_at. Returns the assembler
    equates (audio_data.inc lines) and a receipt. All song tables are read
    with long addressing, so they may sit in any bank."""
    items = models()
    pool, info = native_score(items)
    assert not info["misses"], info["misses"][:5]
    # For each song, inspect the model's tightest ticks-per-byte warning.
    # If it is under 17 ticks, leave that song's captures raw.
    tight = set()
    for command in range(32, 51):
        parts_for_song = [p for p in info["parts"] if p["command"] == command]
        _, _, lead = check_prefetch(pool, parts_for_song, items, info["dictionary"])
        if lead and lead[0] < 17:
            tight.add(command)
    # In a crowded 2P game the opening track missed an upload deadline even
    # though its isolated score-model warning was longer. Keep it raw too.
    tight.add(0x20)
    raw_captures = set()
    for part in info["parts"]:
        if part["command"] not in tight:
            continue
        data = pool[part["offset"] : part["offset"] + part["bytes"]]
        at = 0
        while at < len(data):
            kind, _, at, args = read_native_event(data, at, info["dictionary"])
            if kind == NOTE:
                raw_captures.add(args[0] & 127)
                if args[2] != 255:
                    raw_captures.add(args[2])
    # Never slow an initial song gate with decoding. The shared-cache plan
    # is bounded by the raw baseline's per-part first-upload byte budget.
    fit = json.loads((BANK / "fit.json").read_text())
    base = next(r["start"] for r in fit["doc_regions"] if r["name"].startswith("FM part 0"))
    gate_plans = cache_plan(pool, info, items, base)
    for plan in gate_plans:
        raw_captures.update(plan[2 : 2 + 2 * plan[1] : 2])
    encoded = [pack_capture(it["data"]) for it in items]
    # The packed captures, from an offline search.
    chosen = {1, 2, 12, 13, 17, 25, 26, 27, 37, 40, 42, 46, 50, 54, 55, 69, 70}
    packed = [
        i in chosen and len(v) + 64 <= len(it["data"])
        for i, (it, v) in enumerate(zip(items, encoded))
    ]
    assert sum(packed) == len(chosen)
    # The capture blobs, read with long addressing: the host fitter puts
    # each one where there is room. Source pointers keep the identity of each
    # capture.
    blobs = [v if use else it["data"] for it, v, use in zip(items, encoded, packed)]
    sources = [host.blob_at(data) for data in blobs]
    holds = hold_lengths(pool, info["parts"], info["dictionary"])
    records = [
        host.blob_at(record(it, src, use, holds.get(i)))
        for i, (it, src, use) in enumerate(zip(items, sources, packed))
    ]
    host.blob_at(HostData().faraddr(*records), "fm_records")
    t = tables()
    for k in ("register", "pair", "boost"):
        host.blob_at(t[k], f"fm_{k}_table")

    host.blob_at(pool, "MUSIC_SCORE")
    host.blob_at(info["dictionary"], "music_note_dictionary")
    parts = {(p["command"], p["phase"], p["channel"]): p for p in info["parts"]}
    fit = json.loads((BANK / "fit.json").read_text())
    base = next(r["start"] for r in fit["doc_regions"] if r["name"].startswith("FM part 0"))
    assert base % 256 == 0
    entries = []
    offsets = []
    priorities = []
    first = []
    for c in range(32, 51):
        priorities.append(parts[c, 0, 0]["priority"] * 2)
        for phase in (0, 1):
            entries.append(len(offsets) * 2)
            offsets.extend(parts[c, phase, ch]["offset"] for ch in range(6))
            first.extend(info["first"].get((c, phase, ch), 0xFF) for ch in range(6))
    cache = cache_plan(pool, info, items, base)
    # Phases often share a layout; store each identical directory just once.
    directories = {}
    for plan in cache:
        if plan not in directories:
            directories[plan] = host.blob_at(plan)
    host.blob_at(HostData().faraddr(*(directories[plan] for plan in cache)), "fm_cache_plans")
    # Stage 3/9/14 music precedes a $2A boss camera. The urgent capture
    # 67 has a stable page disjoint from every other capture of $22/$24.
    for command in (0x22, 0x24):
        oldcaps = set(cache[(command - 32) * 2][2::2])
        lo = FM_STABLE_PAGES[67] * 256
        hi = lo + len(items[67]["data"])
        assert FM_STABLE_PAGES[67] == 0xF0
        for c in oldcaps:
            other = FM_STABLE_PAGES[c] * 256
            assert c == 67 or hi <= other or lo >= other + len(items[c]["data"])
    import stage_controls

    stage_tables, _ = stage_controls.event_tables()
    # fm_stage_hint: the lookahead windows before the boss cues, from 129
    # event records before the record after the cue up to it. They count
    # 6-byte arcade records, but CAMERA_STAGE_OFFSET counts the 4-byte packed
    # records (stage_controls.install): the windows start late.
    hints = []
    for name, stage, callback in (
        ("CAMERA3", 2, 0x690A),
        ("CAMERA9", 8, 0x6924),
        ("CAMERA14", 13, 0x693E),
        ("RESULT6", 5, 0x6A11),
        ("RESULT11", 10, 0x6A11),
    ):
        data = stage_tables[stage]
        at = next(
            o
            for o in range(0, len(data) - 5, 6)
            if int.from_bytes(data[o + 2 : o + 4], "little") == callback
        )
        hints += [
            f"FM_HINT_{name}_STAGE = {stage}",
            f"FM_HINT_{name}_FIRST = {at + 6 - 129 * 6}",
            f"FM_HINT_{name}_END = {at + 6}",
        ]
    # Quiet-time boss $29 preloads must be disjoint from every capture in
    # the outgoing stage-$30 song; no live or future old voice is evicted.
    old = set(cache[(0x30 - 32) * 2][2::2])
    target = cache[(0x29 - 32) * 2]
    first = list(target[2 : 2 + target[1] * 2 : 2])
    first = [c for c in first if c in {info["first"].get((0x29, 0, ch), 255) for ch in range(6)}]
    old30plan = cache[(0x30 - 32) * 2]
    old30pos = dict(zip(old30plan[2::2], old30plan[3::2]))
    targetpos = dict(zip(target[2::2], target[3::2]))
    safe = []
    for cap in first:
        lo = targetpos[cap] * 256
        hi = lo + len(items[cap]["data"])
        if all(
            (cap == other and lo == old30pos[other] * 256)
            or hi <= old30pos[other] * 256
            or lo
            >= old30pos[other] * 256 + (2048 if other in (35, 67) else len(items[other]["data"]))
            for other in old
        ):
            safe.append(cap)
    assert len(safe) == 5, (safe, old)
    host.blob_at(bytes(v for cap in safe for v in (cap, targetpos[cap])), "fm_preload_boss")

    # Three-phase placement: old $2F + both initial gates; full $28 +
    # initial $2E gate; then $2E + imminent $28. All fit without overlap.
    ending_old = set(cache[(0x2F - 32) * 2][2::2])
    ending_first = {info["first"].get((0x28, 0, ch), 255) for ch in range(6)} - {255}
    cue = cache[(0x2E - 32) * 2]
    cue_first = set(cue[2 : 2 + 2 * cue[1] : 2])
    post_keep = {26, 36, 37, 44, 46, 47, 64, 67}
    phases = (
        ending_old | ending_first | cue_first,
        set(cache[(0x28 - 32) * 2][2::2]) | cue_first,
        post_keep | set(cue[2::2]),
    )
    for phase in phases:
        spans = []
        for cap in phase:
            at = FM_ENDING_PAGES[cap] * 256
            length = 2048 if cap == 35 else len(items[cap]["data"])
            align = 256 << ((items[cap]["native"]["size"] >> 3) & 7)
            assert at % align == 0 and base <= at and at + length <= base + 36864
            spans.append((at, at + length, cap))
        spans.sort()
        assert all(a[1] <= b[0] for a, b in zip(spans, spans[1:])), spans
    # First $28 captures first, then missing $2E gate captures.
    ending = sorted(ending_first) + sorted(cue_first - ending_first)
    host.blob_at(bytes(v for cap in ending for v in (cap, FM_ENDING_PAGES[cap])), "fm_preload_ending")
    # When $2E interrupts stage song $30, retain the whole outgoing song.
    # Allocate the incoming distinct captures in the old song's actual gaps.
    oldplan = cache[(0x30 - 32) * 2]
    oldpos = {cap: page * 256 for cap, page in zip(oldplan[2::2], oldplan[3::2])}
    incoming = cache[(0x2E - 32) * 2]
    assert incoming == cache[(0x2E - 32) * 2 + 1]
    incaps = set(incoming[2::2])
    free = [(base, base + 36864)]
    for cap, at in sorted(oldpos.items(), key=lambda row: row[1]):
        end = at + (2048 if cap in (35, 67) else len(items[cap]["data"]))
        remaining = []
        for lo, hi in free:
            if end <= lo or at >= hi:
                remaining.append((lo, hi))
            else:
                if lo < at:
                    remaining.append((lo, at))
                if end < hi:
                    remaining.append((end, hi))
        free = remaining
    alt = {cap: oldpos[cap] for cap in incaps & oldpos.keys()}

    def alignment(cap):
        return 256 << ((items[cap]["native"]["size"] >> 3) & 7)

    for cap in sorted(
        incaps - oldpos.keys(), key=lambda cap: (-alignment(cap), -len(items[cap]["data"]), cap)
    ):
        n = len(items[cap]["data"])
        align = alignment(cap)
        for j, (lo, hi) in enumerate(free):
            at = (lo + align - 1) & -align
            end = at + n
            if end <= hi:
                free[j : j + 1] = ([]) + ([(end, hi)])
                alt[cap] = at
                break
        else:
            raise ValueError(("FM alternative $30/$2E does not fit", cap))
    alt_desc = bytearray(incoming[:2])
    for cap in incoming[2::2]:
        alt_desc.extend((cap, alt[cap] >> 8))
    host.blob_at(bytes(alt_desc), "fm_alt_30_2e")
    # $2A and $2E together occupy 35,840 bytes. This exact aligned layout
    # keeps every $2A global page fixed while placing the whole incoming $2E.
    old2 = cache[(0x2A - 32) * 2]
    old2pos = dict(zip(old2[2::2], old2[3::2]))
    alt2 = {
        16: 0xC6,
        18: 0x8A,
        19: 0x6C,
        32: 0x9C,
        35: 0xB4,
        44: 0xD2,
        52: 0xE4,
        53: 0x90,
        55: 0x84,
        56: 0xC0,
        58: 0x7E,
        59: 0xCC,
        64: 0xD8,
        65: 0xA8,
        66: 0x72,
        67: 0xF0,
    }
    assert all(alt2[c] == page for c, page in old2pos.items()), old2pos
    spans = []
    for cap, page in alt2.items():
        at = page * 256
        n = len(items[cap]["data"])
        align = 256 << ((items[cap]["native"]["size"] >> 3) & 7)
        assert at % align == 0 and base <= at and at + n <= base + 36864
        spans.append((at, at + n, cap))
    spans.sort()
    assert all(a[1] <= b[0] for a, b in zip(spans, spans[1:])), spans
    assert set(alt2) == set(old2[2::2]) | set(incoming[2::2])
    alt2_desc = bytearray(incoming[:2])
    for cap in incoming[2::2]:
        alt2_desc.extend((cap, alt2[cap]))
    host.blob_at(bytes(alt2_desc), "fm_alt_2a_2e")

    # The current postgame queues $28 followed by $2E. Retain its
    # first captures and the imminent next captures at their existing pages.
    post28 = {c: FM_ENDING_PAGES[c] for c in {26, 35, 36, 37, 44, 46, 47, 56, 58, 59, 64, 65, 67}}
    assert post28[37] == 0xD0  # IRQ in-flight exception uses this exact page.
    old28 = cache[(0x28 - 32) * 2]
    old28pos = dict(zip(old28[2::2], old28[3::2]))
    keep28 = {26, 36, 37, 44, 46, 47, 64, 67}
    assert all(post28[c] == old28pos[c] for c in keep28)
    assert set(post28) == keep28 | set(incoming[2::2])
    ranges = []
    for c, page in post28.items():
        at = page * 256
        size = 2048 if c == 35 else len(items[c]["data"])
        align = 256 << ((items[c]["native"]["size"] >> 3) & 7)
        assert at % align == 0 and base <= at and at + size <= base + 36864
        ranges.append((at, at + size, c))
    ranges.sort()
    assert all(a[1] <= b[0] for a, b in zip(ranges, ranges[1:])), ranges
    postdesc = bytearray(incoming[:2])
    for c in incoming[2::2]:
        postdesc.extend((c, post28[c]))
    host.blob_at(bytes(postdesc), "fm_post28_2e")
    post28_restore = [c for c in old28[2::2] if c in keep28]
    assert set(post28_restore) == keep28
    host.blob_at(bytes(v for c in post28_restore for v in (c, old28pos[c])), "fm_restore_post28")

    # The $29/$2E layout. Capture 44 overwrites old $29 cap 23; capture 65
    # shares the shortened $2E cap 67 after its last use.
    bossold = cache[(0x29 - 32) * 2]
    oldpos = dict(zip(bossold[2::2], bossold[3::2]))
    assert all(FM_BOSS_PAGES[c] == page for c, page in oldpos.items())
    boss2e = {c: FM_BOSS_PAGES[c] for c in incoming[2::2] if c not in (44, 65)}
    boss2e.update({44: FM_BOSS_PAGES[23], 65: FM_BOSS_PAGES[67]})
    assert set(boss2e) == set(incoming[2::2])
    spans = []
    for cap, page in boss2e.items():
        at = page * 256
        length = 2048 if cap in (35, 67) else len(items[cap]["data"])
        alignment = 256 << ((items[cap]["native"]["size"] >> 3) & 7)
        assert at % alignment == 0 and base <= at and at + length <= base + 36864
        spans.append((at, at + length, cap))
    spans.sort()
    assert all(
        a[1] <= b[0] or {a[2], b[2]} == {65, 67}
        for i, a in enumerate(spans)
        for b in spans[i + 1 :]
    )
    for cap, page in oldpos.items():
        lo = page * 256
        hi = lo + len(items[cap]["data"])
        for at, end, c in spans:
            assert hi <= at or end <= lo or (cap == 23 and c == 44), (cap, c, hex(lo), hex(at))
    bossdesc = bytearray(incoming[:2])
    for c in incoming[2::2]:
        bossdesc.extend((c, boss2e[c]))
    host.blob_at(bytes(bossdesc), "fm_boss2e")
    boss_gate = list(incoming[2 : 2 + 2 * incoming[1] : 2])
    assert 44 not in boss_gate and 65 not in boss_gate
    host.blob_at(bytes(v for c in boss_gate for v in (c, boss2e[c])), "fm_preload_boss2e")
    boss_restore = [c for c in bossold[2::2] if c != 23]
    host.blob_at(bytes(v for c in boss_restore for v in (c, oldpos[c])), "fm_restore_boss")

    # Check the time-sharing lifetime directly from both compiled $2E
    # phases, including tied notes: 67 occurs only on part 3 and is replaced
    # by a fresh 44 at 768; 65 first occurs at 1296.
    for phase in (0, 1):
        allnotes = []
        for part in (p for p in info["parts"] if p["command"] == 0x2E and p["phase"] == phase):
            data = pool[part["offset"] : part["offset"] + part["bytes"]]
            pc = tick = count = 0
            loop_at = -1
            for _ in range(400000):
                origin = pc
                kind, delay, pc, args = read_native_event(data, pc, info["dictionary"])
                tick += delay
                if tick > 1296:
                    break
                if kind == NOTE:
                    allnotes.append((tick, part["channel"], args[0] & 127, bool(args[0] & 128)))
                if kind == LOOP:
                    n, target = args
                    if loop_at != origin:
                        count = n - 1
                        loop_at = origin
                        pc = target
                    elif count:
                        count -= 1
                        pc = target
                    else:
                        loop_at = -1
            else:
                raise ValueError(("2E lifetime horizon", phase, part["channel"]))
        assert all(ch == 3 and t <= 576 for t, ch, c, _ in allnotes if c == 67)
        assert (768, 3, 44, False) in allnotes
        assert min(t for t, ch, c, _ in allnotes if c == 65) == 1296
    host.blob_at(bytes(((i & 15) - 8) & 255 for i in range(256)), "fm_delta_low")
    host.blob_at(bytes(((i >> 4) - 8) & 255 for i in range(256)), "fm_delta_high")
    host.blob_at(bytes(priorities), "music_priority")
    host.blob_at(struct.pack("<4H", 0, 192, 384, 576), "music_slot_offsets")
    host.blob_at(struct.pack(f"<{len(entries)}H", *entries), "music_entries")
    host.blob_at(struct.pack(f"<{len(offsets)}H", *offsets), "music_part_offsets")
    host.blob_at(bytes(first), "fm_first_captures")
    # The score tokens (music_score.py) for src/music_player.s.
    tokens = (("NOTE", NOTE), ("OFF", OFF), ("LOOP", LOOP), ("END", END), ("SHARED", SHARED))
    lines = [
        *(f"SCORE_{name} = ${kind << 5:02x}" for name, kind in tokens),
        f"SCORE_DELAY_LONG = {DELAY_LONG}",
        f"MUSIC_SONGS = {len(entries) // 2}",
        f"FM_VISIT = {VISIT}",
        f"FM_PAGE_CAP37 = ${post28[37]:02x}",
        f"FM_PAGE_CAP67 = ${FM_STABLE_PAGES[67]:02x}",
        *hints,
        f"FM_BASE_PAGE = ${base >> 8:02x}",
        f"FM_BOSS_RESTORE_PAGE = ${FM_BOSS_PAGES[23]:02x}",
        f"FM_POST28_RESTORE_COUNT = {len(post28_restore)}",
        f"FM_BOSS_RESTORE_COUNT = {len(boss_restore)}",
        f"FM_BOSS_GATE_COUNT = {len(boss_gate)}",
        f"FM_PRELOAD_COUNT = {len(safe)}",
        f"FM_ENDING_PRELOAD_COUNT = {len(ending)}",
    ]
    receipt = dict(
        captures=len(items),
        table_bytes=sum(len(it["data"]) for it in items),
        record_bytes=sum(len(record(it, 0)) for it in items),
        score_bytes=len(pool),
        packed_table_bytes=sum(
            len(v) if use else len(it["data"]) for it, v, use in zip(items, encoded, packed)
        ),
        packed_captures=sum(packed),
        fm_base=base,
        prefetch_misses=len(info["misses"]),
        shortest_upload_warning=info["shortest_lead"],
    )
    return lines, receipt


def tables():
    """Register table indexed by level + 64 for levels -64..1022; the pair
    table gives WEIGHT[256-a], WEIGHT[a] per fade step a; one pad byte
    each for the 16-bit reads."""
    assert REGISTER[SILENT] == 0
    register = bytes([REGISTER[0]] * REGISTER_LOW + REGISTER[:SILENT] + [0])
    pair = b"".join(struct.pack("<HH", WEIGHT[256 - a], WEIGHT[a]) for a in range(256))
    return dict(register=register, pair=pair, boost=bytes(v for row in BOOST for v in row) + b"\0")
