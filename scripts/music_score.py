"""Final native score compiler. Runtime never sees the arcade bytecode.

Tokens: top three bits NOTE/OFF/LOOP/END/FREQ/VOL/TABLE; low five bits are
the resolved tick delay (31 escapes to u16). NOTE carries sample, FC16, volume.
FREQ and VOL carry ready DOC values. TABLE changes a captured timbre stage.
LOOP carries repetitions (zero = forever), then a part-relative u16 target.
Finite repeats are flat and use one counter; independent part loops remain
independent. Duplicate part streams share storage, including both IRQ phases.
"""

from collections import defaultdict
import json, math, struct
from audio_config import DOC_RATE

NOTE, OFF, LOOP, END, FREQ, VOL, TABLE = range(7)


def token(kind, delay, body=b""):
    assert 0 <= delay < 65536
    return (
        bytes([(kind << 5) | min(31, delay)])
        + (struct.pack("<H", delay) if delay >= 31 else b"")
        + body
    )


def sample_plan(songs, models=()):
    """The samples of the songs and the binding of each played note to one.
    MODELS: the instrument models of the bank, for their cycles per table."""
    models = {m["source"]["sample"]: m for m in models}
    pitches = defaultdict(set)
    for s in songs:
        for p in s["parts"]:
            for e in p["events"]:
                if e[1] == "on":
                    pitches[e[3]].add(e[2])
    plans = []
    bindings = {}
    for patch, words in sorted(pitches.items()):
        # Two actual played roots, split by pitch range. No synthetic wave is
        # implied: the sound model supplies captured attack/body bytes to these IDs.
        words = sorted(words)
        zones = [words[: (len(words) + 1) // 2], words[(len(words) + 1) // 2 :]]
        for group in zones:
            if not group:
                continue
            hz = lambda w: (1500000 / 36) * (((w & 2047) << ((w >> 11) & 7)) >> 1) / (1 << 21)
            ident = len(plans)
            cycles = models.get(ident, {}).get("cycles_per_table", 1)
            low, high = hz(group[0]) / cycles, hz(group[-1]) / cycles
            T = max(0, math.ceil(math.log2(DOC_RATE / low / 256)))
            assert T <= 7
            R = max(r for r in range(8) if round(high * (1 << (17 + r)) / DOC_RATE) <= 65535)
            plan = dict(
                sample=ident,
                patch=patch,
                root_fnum=group[0],
                played_fnums=group,
                loop_bytes=256 << T,
                loop_resolution=R,
                cycles_per_table=cycles,
                loop_periods_of_nominal=cycles,
                minimum_step=low * (256 << T) / DOC_RATE,
                status="captured waveform model must pass before packaging",
                volume=255,
            )
            plans.append(plan)
            for w in group:
                fc = round(hz(w) / cycles * (1 << (17 + R)) / DOC_RATE)
                assert 0 < fc <= 65535
                bindings[patch, w] = (ident, fc, 255)
    return plans, bindings


def repeat_pack(records):
    """Factor only exact adjacent runs. No runtime original repeat semantics."""
    result = []
    i = 0
    while i < len(records):
        best = None
        for n in range(1, min(96, (len(records) - i) // 2) + 1):
            block = records[i : i + n]
            copies = 1
            while copies < 256 and records[i + copies * n : i + (copies + 1) * n] == block:
                copies += 1
            saving = sum(map(len, block)) * (copies - 1) - 4
            if saving > 0 and (best is None or saving > best[0]):
                best = (saving, n, copies)
        if best:
            _, n, copies = best
            target = sum(len(r) for r in result)
            result += records[i : i + n]
            result.append(token(LOOP, 0, bytes([copies - 1]) + struct.pack("<H", target)))
            i += n * copies
        else:
            result.append(records[i])
            i += 1
    return result


def part_stream(part, bindings, note=None):
    """note(index): optional NOTE body for event `index`; the native player's
    score supplies capture, frequency and prefetch this way."""
    groups = [[], []]
    last = 0
    loop = part["loop"]
    split = False
    sounding = False
    for index, e in enumerate(part["events"]):
        tick, kind, *v = e
        if kind == "patch":
            continue
        if loop and not split and tick >= loop["start_tick"]:
            # A silent wait at loop entry is represented by the first event's delta.
            # The explicit split point cannot be moved through a repeated phrase.
            boundary = loop["start_tick"]
            split = True
            if boundary != last:
                groups[0].append(token(LOOP, boundary - last, b"\x01\xff\xff"))
                last = boundary
        delay = tick - last
        last = tick
        if kind == "on":
            sample, fc, volume = bindings[v[1], v[0]]
            body = (
                note(index)
                if note
                else struct.pack("<BHB", sample | (128 if sounding else 0), fc, volume)
            )
            groups[int(split)].append(token(NOTE, delay, body))
            sounding = True
        else:
            groups[int(split)].append(token(OFF, delay))
            sounding = False
    head = repeat_pack(groups[0])
    body = repeat_pack(groups[1])
    blob = bytearray(b"".join(head))
    start = len(blob)
    # Forward wait sentinel becomes a one-time jump to the following byte.
    at = 0
    while at < len(blob):
        op, d, nxt, args = read_event(blob, at)
        if op == LOOP and args[1] == 65535:
            struct.pack_into("<H", blob, nxt - 2, nxt)
        at = nxt
    # Body's finite-loop targets are relative to body; relocate them.
    body = bytearray(b"".join(body))
    at = 0
    while at < len(body):
        op, d, nxt, args = read_event(body, at)
        if op == LOOP:
            struct.pack_into("<H", body, nxt - 2, args[1] + start)
        at = nxt
    blob += body
    if loop:
        if not split:
            if loop["start_tick"] != last:
                blob += token(
                    LOOP, loop["start_tick"] - last, bytes([1]) + struct.pack("<H", len(blob) + 4)
                )
                last = loop["start_tick"]
            start = len(blob)
        blob += token(LOOP, loop["end_tick"] - last, bytes([0]) + struct.pack("<H", start))
    else:
        blob += token(END, part["end_tick"] - last)
    return bytes(blob)


def read_event(data, pc):
    code = data[pc]
    pc += 1
    kind = code >> 5
    delay = code & 31
    if delay == 31:
        delay = struct.unpack_from("<H", data, pc)[0]
        pc += 2
    if kind == NOTE:
        args = struct.unpack_from("<BHB", data, pc)
        pc += 4
    elif kind == LOOP:
        args = (data[pc], struct.unpack_from("<H", data, pc + 1)[0])
        pc += 3
    elif kind not in (OFF, END):
        raise ValueError(("invalid native score token", kind, pc - 1))
    else:
        args = ()
    return kind, delay, pc, args


def expand(data, horizon):
    """The events of a part stream up to tick HORIZON, with its loops played."""
    pc = 0
    tick = 0
    count = 0
    loop_at = -1
    events = []
    ended = None
    for _ in range(200000):
        origin = pc
        kind, delay, pc, args = read_event(data, pc)
        tick += delay
        if tick > horizon:
            break
        if kind == NOTE:
            events.append((tick, "on", *args))
        elif kind == OFF:
            events.append((tick, "off"))
        elif kind == END:
            ended = tick
            break
        else:
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
        raise ValueError("zero-time or unbounded score")
    return events, ended


def compile_scores(rom, out):
    """The score of all songs (score.bin, score.json) into folder OUT. The
    sound stage reads the note lengths of each sample from it."""
    from music import song

    out.mkdir(parents=True, exist_ok=True)
    songs = [
        dict(song(rom, c, phase=phase), phase=phase) for c in range(32, 51) for phase in (0, 1)
    ]
    plans, bindings = sample_plan(songs)
    pool = bytearray()
    seen = {}
    parts = []
    for s in songs:
        for p in s["parts"]:
            data = part_stream(p, bindings)
            if data not in seen:
                seen[data] = len(pool)
                pool += data
            got, _ = expand(data, p["end_tick"] - 1 if p["loop"] else p["end_tick"])
            expected = []
            sounding = False
            for e in p["events"]:
                if e[1] == "on":
                    sample, fc, volume = bindings[e[3], e[2]]
                    expected.append((e[0], "on", sample | (128 if sounding else 0), fc, volume))
                    sounding = True
                elif e[1] == "off":
                    expected.append((e[0], "off"))
                    sounding = False
            assert got == expected, (s["command"], s["phase"], p["channel"])
            parts.append(
                dict(
                    command=s["command"],
                    phase=s["phase"],
                    channel=p["channel"],
                    priority=s["priority"],
                    offset=seen[data],
                    bytes=len(data),
                    loop=p["loop"],
                    end_tick=p["end_tick"],
                )
            )
    (out / "score.bin").write_bytes(pool)
    result = dict(score_bytes=len(pool), parts=parts, samples=plans)
    (out / "score.json").write_text(json.dumps(result, indent=2) + "\n")
    return result
