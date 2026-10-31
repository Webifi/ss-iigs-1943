"""Integer FM part engine: the reference for the native 65816 player.

Every level is an attenuation in YM units (0.09375 dB, 0..1023). Per tick the
engine adds fixed-point slopes and reads tables; no multiply or divide runs
per tick. The page renders through this engine, so it plays what the IIgs
plays. Native records and tables come from `native_model` and `TABLES`.
"""

import math
from audio_config import KNEE

TICK = 6e6 / (384 * 262) * 4
UNIT = 0.09375
SILENT = 1023
CAP = 1000
FRACTION = 6
ATTACK_LIMIT = 64
# Each part is visited every 8th sound tick (30 Hz, half the video frame
# rate) and its crossfade levels recomputed each visit. In listening
# comparisons of all songs and effects this sounds the same as once per frame.
VISIT = 8
WEIGHT_VISITS = 1


def _register(att):
    linear = 255 * 10 ** (-att * UNIT / 20)
    return min(range(256), key=lambda d: abs(KNEE[d] - linear)) if att < SILENT else 0


# Shared native tables: attenuation to knee-board volume register, crossfade
# weight to attenuation, and the crossfade compensation shape.
REGISTER = [_register(a) for a in range(SILENT + 1)]
LINEAR = [round(255 * 10 ** (-a * UNIT / 20)) if a < SILENT else 0 for a in range(SILENT + 1)]
WEIGHT = [SILENT] + [round(-20 * math.log10(i / 256) / UNIT) for i in range(1, 257)]
SHAPE = [round(256 * 4 * (i / 256) * (1 - i / 256)) for i in range(257)]
# Crossfade boost by stage boost (0..31) and alpha>>10 (64 steps): one read.
BOOST = [[(b * SHAPE[q * 4]) >> 8 for q in range(64)] for b in range(32)]


def _cut(envelope, ticks):
    """The hold curve ends at the hold tick: the last point is cut to the
    level it reaches there, so stepping past the hold changes nothing."""
    level, points = envelope
    out = []
    for t, slope, goal in points:
        if ticks <= 0:
            break
        if t > ticks:
            t, goal = ticks, level + ticks * slope
        assert 0 <= goal < 65536
        out.append((t, slope, goal))
        level = goal
        ticks -= t
    return envelope[0], out


def _points(segments, scale=4):
    """(ticks, target) points in 0.375 dB steps to (ticks, slope, target) in
    fixed-point YM units; the engine re-seats the exact target each point."""
    # Levels stop at CAP so a rounded slope never leaves 16 bits.
    start = min(CAP, segments[0][1] * scale) << FRACTION
    level = start
    out = []
    for ticks, target in segments[1:]:
        goal = min(CAP, target * scale) << FRACTION
        out.append((ticks, round((goal - level) / ticks), goal))
        level = goal
    return start, out


class Curve:
    """Stepping state for one segment list."""

    def __init__(self, start, points, length=None):
        self.level = start
        self.points = points
        self.index = 0
        self.left = points[0][0]
        self.length = length
        self.age = 0

    def value(self):
        return min(SILENT, self.level >> FRACTION)

    def step(self):
        self.age += 1
        if self.index < len(self.points):
            ticks, slope, goal = self.points[self.index]
            self.level += slope
            self.left -= 1
            if self.left == 0:
                self.level = goal
                self.index += 1
                if self.index < len(self.points):
                    self.left = self.points[self.index][0]


def native_model(model, waves):
    """Runtime record for one capture: stage tables, levels and curves."""
    peak = model["envelope_peak"]
    body = model["body_peak"]
    schedule = model["snapshot_schedule"]
    stages = []
    for i, ((tick, table), scale) in enumerate(zip(schedule, model["snapshot_scales"])):
        att = round(-20 * math.log10(max(1e-12, peak * scale / body)) / UNIT)
        if i + 1 < len(schedule):
            span = schedule[i + 1][0] - tick
            a = scale * model["snapshot_rms"][i]
            b = model["snapshot_scales"][i + 1] * model["snapshot_rms"][i + 1]
            mix = math.sqrt(
                (0.5 * a) ** 2 + (0.5 * b) ** 2 + 2 * 0.25 * a * b * model["snapshot_rho"][i]
            )
            boost = round(20 * math.log10(min(2.0, (0.5 * a + 0.5 * b) / max(1e-12, mix))) / UNIT)
            stages.append(
                dict(tick=tick, table=table, att=att, step=round(65536 / span), boost=boost)
            )
        else:
            stages.append(dict(tick=tick, table=table, att=att, step=0, boost=0))
    envelope = _cut(_points(model["envelope_segments"]), model["hold_tick"])
    # Attack table: hold-curve attenuation from tick 0 to its first minimum.
    curve = Curve(*envelope)
    attack = [curve.value()]
    for _ in range(min(model["hold_tick"], ATTACK_LIMIT)):
        curve.step()
        attack.append(curve.value())
    peak_tick = attack.index(min(attack))
    releases = []
    for i, curve in enumerate(model["release_segments"]):
        start, points = _points(curve)
        releases.append(dict(start=start, points=points, length=len(waves[f"fall_{i:02d}"])))
    holds = sorted((int(h), i) for h, i in model["release_holds"].items())
    return dict(
        stages=stages,
        envelope=envelope,
        attack=attack[: peak_tick + 1],
        peak_att=round(-20 * math.log10(peak) / UNIT),
        hold=model["hold_tick"],
        releases=releases,
        holds=holds,
        size=model["frequency_size"],
        every=VISIT,
    )


class Part:
    """One FM part: two DOC oscillators, snapshot crossfade, EG and release.

    A part is visited every `every` ticks (the native player's schedule).
    A visit runs the ticks since the last one in order and then writes the
    volumes; writes made by those ticks (stage change, release end) happen
    at the visit. A note start writes at once."""

    def __init__(self, emit, table=REGISTER, phase=0):
        # The native init writes 0 to every frequency, size and table register.
        self.emit = emit
        self.note = None
        self.table = table
        self.held = {(v, r): 0 for v in (0, 1) for r in (0, 1, 4, 6)}
        self.phase = phase

    def write(self, t, voice, register, value):
        self.emit(t, voice, register, value)

    def put(self, t, voice, register, value):
        """Frequency, size and table registers keep their value while a voice
        is halted; write one only when it changes (each DOC write is slow)."""
        if self.held.get((voice, register)) != value:
            self.write(t, voice, register, value)
            self.held[voice, register] = value

    def start(self, t, native, places, fc, previous_level):
        n = dict(
            native=native,
            places=places,
            eg=Curve(*native["envelope"]),
            release=None,
            off_att=0,
            tick=0,
            prior=[None, None],
            last=t,
            visits=0,
        )
        n["begin"] = 0
        stages = native["stages"]
        n["current"] = max((i for i, s in enumerate(stages) if s["tick"] <= n["begin"]), default=0)
        cur = n["current"]
        n["alpha"] = (
            ((n["begin"] - stages[cur]["tick"]) * stages[cur]["step"])
            if cur + 1 < len(stages)
            else 0
        )
        for v in (0, 1):
            table = stages[min(cur + ((v - cur) & 1), len(stages) - 1)]["table"]
            # Both voices are already halted: by the previous note's stop, its
            # release end, or the song start.
            for r, d in ((0, fc & 255), (1, fc >> 8), (6, native["size"]), (4, places[table] >> 8)):
                self.put(t, v, r, d)
        self.write(t, 0, 5, 4)
        self.write(t, 1, 5, 0)
        n["sync"] = True
        self.note = n
        n["w"] = self.weights()
        self.volumes(t)

    def weights(self):
        """Per-voice level attenuation from the stage crossfade."""
        n = self.note
        stages = n["native"]["stages"]
        cur = n["current"]
        att = [SILENT, SILENT]
        if cur + 1 < len(stages):
            alpha = n["alpha"] >> 8
            boost = BOOST[stages[cur]["boost"]][n["alpha"] >> 10]
            att[cur & 1] = stages[cur]["att"] + WEIGHT[256 - alpha] - boost
            att[1 - (cur & 1)] = stages[cur + 1]["att"] + WEIGHT[alpha] - boost
        else:
            att[cur & 1] = stages[cur]["att"]
        return att

    def volumes(self, t):
        n = self.note
        base = n["eg"].value()
        for v, w in enumerate(n["w"]):
            value = self.table[max(0, min(SILENT, base + w))] if base < SILENT and w < SILENT else 0
            if value != n["prior"][v]:
                self.write(t, v, 2, value)
                n["prior"][v] = value

    def step(self, t, off):
        """One sound tick; its writes are stamped t."""
        n = self.note
        n["tick"] += 1
        et = n["tick"] + n["begin"]
        stages = n["native"]["stages"]
        if et <= n["native"]["hold"]:
            n["eg"].step()
        # Stages are at least two ticks apart: at most one change a tick,
        # and it falls exactly on the stage tick, so the fade restarts at 0.
        if n["current"] + 1 < len(stages) and stages[n["current"] + 1]["tick"] <= et:
            n["current"] += 1
            cur = n["current"]
            n["alpha"] = 0
            if cur + 1 < len(stages):
                target = (cur + 1) & 1
                self.write(t, target, 2, 0)
                self.put(t, target, 4, n["places"][stages[cur + 1]["table"]] >> 8)
                n["prior"][target] = 0
            return "move"
        elif n["current"] + 1 < len(stages):
            n["alpha"] = min(65535, n["alpha"] + stages[n["current"]]["step"])


def hold_volumes(native, length):
    """Volume registers of a held note at EG time 0..length, as bytes (voice
    A, voice B) per time: what a visit writes depends only on that time, so
    the native player reads them instead of stepping (scripts/fm_native.py)."""
    p = Part(lambda *a: None)
    p.start(0, native, {s["table"]: 0 for s in native["stages"]}, 0, SILENT)
    n = p.note
    out = bytearray()
    for et in range(length + 1):
        if et:
            p.step(0, False)
        base = n["eg"].value()
        w = p.weights()
        v = [
            p.table[max(0, min(SILENT, base + x))] if base < SILENT and x < SILENT else 0 for x in w
        ]
        a = n["current"] & 1
        out += bytes((v[a], v[1 - a]))
    return bytes(out)
