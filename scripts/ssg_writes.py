"""Build-time SSG effect lists as resolved DOC register writes.

The native player (src/audio_ssg.s) used to keep per-part state and, on
every due record, rebuild the DOC writes from the record's changed fields
(tone/noise/selector/flags), skipping writes that equal the last written
value. All of that depends only on the effect's own list, which starts from
a fixed state in ssg_start, so it is resolved here instead. A record now
holds its exact writes: a count, then pairs of (register group | 1 for the
even oscillator, value). The player adds the part's odd oscillator number.

Timing is unchanged: records keep the original delays and the start, filler,
repeat and end semantics of the packed list (scripts/ssg_packed.py). Records
chained with a zero delay are merged, which keeps their write order.
"""

import struct
from audio_bank_codec import repeat_records
from ssg_logic import LIST_REPEAT, compact

KIND = 1  # header nibble of a write record


def expand(data):
    """The compact list as the player walks it: (delay, mask, fields) with
    fillers as mask LIST_FILLER and repeats unrolled; ends at the zero mask."""
    p = 0
    out = []
    loop = -1
    left = 0
    while True:
        origin = p
        delay, mask = data[p], data[p + 1]
        p += 2
        if mask == 0:
            return out
        if mask == LIST_REPEAT:
            copies = data[p]
            target = int.from_bytes(data[p + 1 : p + 3], "little")
            p += 3
            if loop != origin:
                loop = origin
                left = copies
            if left:
                left -= 1
                p = target
            else:
                loop = -1
            continue
        fields = [None] * 4
        for i in range(4):
            if mask >> i & 1:
                n = 2 if i < 2 else 1
                fields[i] = int.from_bytes(data[p : p + n], "little")
                p += n
        out.append((delay, mask, fields))


def resolve(records, tone_size, pages):
    """Simulate ssg_record/ssg_logic/ssg_header from the ssg_start state.
    Returns per record the DOC writes as (group | even, value)."""
    gate, noise_page, on_page, square, noise_size, on_size = pages
    s = dict(
        tone=0,
        noise=0,
        sel=0,
        flags=0,
        evenf=0xFFFF,
        oddp=0xFF,
        evenp=0xFF,
        evens=noise_size,
        oddc=3,
        alone=0,
    )
    result = []
    for delay, mask, fields in records:
        w = []

        def out(even, group, value):
            w.append((group | even, value & 255))

        if mask & 1:
            s["tone"] = fields[0]
            out(0, 0x00, s["tone"])
            out(0, 0x20, s["tone"] >> 8)
        if mask & 2:
            s["noise"] = fields[1]
        if not mask & 12:
            if s["alone"]:
                if mask & 1:
                    s["evenf"] = s["tone"]
                    out(1, 0x00, s["evenf"])
                    out(1, 0x20, s["evenf"] >> 8)
            elif mask & 2:
                s["evenf"] = s["noise"]
                out(1, 0x00, s["evenf"])
                out(1, 0x20, s["evenf"] >> 8)
        else:
            if mask & 4:
                s["sel"] = fields[2]
            if mask & 8:
                s["flags"] = fields[3]
            sel, flags = s["sel"], s["flags"]
            temp = int(3 <= sel < 16 and not flags & 1)
            value = s["tone"] if temp else s["noise"]
            if value != s["evenf"]:
                s["evenf"] = value
                out(1, 0x00, value)
                out(1, 0x20, value >> 8)
            page = ((sel + 14) if temp else sel) + gate & 255
            if page != s["oddp"]:
                s["oddp"] = page
                out(0, 0x80, page)
            mode_only = False
            if temp:
                if s["alone"]:
                    mode_only = True
                else:
                    out(1, 0xA0, 3)
                    out(1, 0xA0, 0)
                    epage = ((flags >> 2) & 7) + square & 255
                    size = tone_size
            else:
                if flags & 1:
                    epage, size = noise_page, noise_size
                else:
                    epage, size = on_page, on_size
            if not mode_only:
                if epage != s["evenp"]:
                    s["evenp"] = epage
                    out(1, 0x80, epage)
                if size != s["evens"]:
                    s["evens"] = size
                    out(1, 0xC0, size)
            m = 4 if sel & 15 else 0
            if m != s["oddc"]:
                s["oddc"] = m
                out(0, 0xA0, m)
            s["alone"] = temp
        result.append((delay, mask, w))
    return result


def merged(resolved):
    """Merge zero-delay chains into one record of the first record's delay."""
    out = []
    for delay, mask, w in resolved:
        out.append(["rec", delay, list(w)])
    return out


# Write slots in the player's order; a record's mask selects them.
# bit 0 odd frequency (2 bytes, also kept as the part's tone)
# bit 1 even frequency (2 bytes)
# bit 2 even frequency = the part's tone (no bytes)
# bits 3-7: with one of bits 3, 5, 6, 7 set, its value byte follows; with
# two or more, one byte indexes a shared four-byte entry:
# bit 3 odd wave page   bit 4 even control 3 then 0   bit 5 even wave page
# bit 6 even size       bit 7 odd control
# The header's low nibble is a code: 1..14 index the shared mask table,
# 15 means the mask byte follows.
SIZES = (2, 2, 0, 0, 0, 0, 0, 0)
STATE_BITS = 0xE8
EXPLICIT = 15
# A packed header byte: the delay / DELAY_UNIT in the high nibble (below 15),
# the mask code in the low nibble; code 0: END_HEADER or REPEAT_HEADER.
DELAY_UNIT = 8
END_HEADER = 0x00
REPEAT_HEADER = 0x10


class Tables:
    """Mask codes and four-byte page/size/control states shared by all lists."""

    def __init__(self):
        self.masks = []
        self.states = {}

    def state(self, t):
        if t not in self.states:
            self.states[t] = len(self.states)
        assert len(self.states) <= 256, "SSG state table exceeds one index byte"
        return self.states[t]

    def code(self, mask):
        return self.masks.index(mask) + 1 if mask in self.masks else EXPLICIT


def slots(w, tone, state):
    """One record's writes as (mask, value bytes, tone, state)."""
    mask = 0
    vals = bytearray()
    i = 0
    state = list(state)
    while i < len(w):
        r, v = w[i]
        if r in (0x00, 0x01):
            assert i + 1 < len(w) and w[i + 1][0] == r | 0x20
            f = v | w[i + 1][1] << 8
            i += 2
            if r == 0x00:
                assert not mask
                mask |= 1
                tone = f
                vals += struct.pack("<H", f)
            elif f == tone:
                assert not mask & 0xFE
                mask |= 4
            else:
                assert not mask & 0xFE
                mask |= 2
                vals += struct.pack("<H", f)
            continue
        if (r, v) == (0xA1, 3):
            assert w[i + 1] == (0xA1, 0) and not mask & 0xF0
            mask |= 16
            i += 2
            continue
        bit, field = {0x80: (3, 0), 0x81: (5, 1), 0xC1: (6, 2), 0xA0: (7, 3)}[r]
        assert not mask >> bit
        mask |= 1 << bit
        state[field] = v
        i += 1
    return mask, bytes(vals), tone, tuple(state)


def decode_slots(mask, vals, tone, states):
    """Writes of one record, as the player makes them."""
    w = []
    p = 0
    if mask & 1:
        tone = vals[p] | vals[p + 1] << 8
        w += [(0x00, vals[p]), (0x20, vals[p + 1])]
        p += 2
    if mask & 2:
        w += [(0x01, vals[p]), (0x21, vals[p + 1])]
        p += 2
    if mask & 4:
        w += [(0x01, tone & 255), (0x21, tone >> 8)]
    if mask & 0xF8:
        n = bin(mask & STATE_BITS).count("1")
        if n == 1:
            st = (vals[p],) * 4
            p += 1
        elif n:
            st = states[vals[p]]
            p += 1
        if mask & 8:
            w.append((0x80, st[0]))
        if mask & 16:
            w += [(0xA1, 3), (0xA1, 0)]
        if mask & 32:
            w.append((0x81, st[1]))
        if mask & 64:
            w.append((0xC1, st[2]))
        if mask & 128:
            w.append((0xA0, st[3]))
    return w, tone, p


def unpacked(items, tables, start_state):
    """Records in the codec's unpacked shape (delay, 1, mask, values), for
    repeat_records. The state index replaces the four page/size/control bytes."""
    recs = []
    tone = 0
    state = start_state
    for kind, delay, w in items:
        mask, vals, tone, state = slots(w, tone, state)
        chosen = [v for v, bit in zip(state, (3, 5, 6, 7)) if mask >> bit & 1]
        if len(chosen) == 1:
            vals += bytes(chosen)
        elif chosen:
            # Only the selected fields matter; the others are zero so equal
            # selections share an entry.
            key = tuple(v if mask >> bit & 1 else 0 for v, bit in zip(state, (3, 5, 6, 7)))
            vals += bytes([tables.state(key)])
        recs.append(bytes([delay, KIND, mask]) + vals)
    return recs


def pack(data, tables):
    """Packed list for the player: the header bytes of scripts/ssg_packed.py
    with the mask code in the low nibble."""
    out = bytearray()
    positions = {}
    patches = []
    p = 0
    while True:
        origin = p
        positions[origin] = len(out)
        delay, mask = data[p], data[p + 1]
        p += 2
        if mask == 0:
            out.append(END_HEADER)
            break
        if mask == LIST_REPEAT:
            out.append(REPEAT_HEADER)
            copies = data[p]
            target = int.from_bytes(data[p + 1 : p + 3], "little")
            p += 3
            out.append(copies)
            patches.append((len(out), target))
            out += b"\0\0"
        else:
            assert mask == KIND
            slot = data[p]
            code = tables.code(slot)
            assert delay % DELAY_UNIT == 0 and delay // DELAY_UNIT < 15, delay
            out.append(delay // DELAY_UNIT << 4 | code)
            if code == EXPLICIT:
                out.append(slot)
            n = sum(SIZES[b] for b in range(8) if slot >> b & 1) + bool(slot & STATE_BITS)
            out += data[p + 1 : p + 1 + n]
            p += 1 + n
    for at, target in patches:
        struct.pack_into("<H", out, at, positions[target])
    return bytes(out)


def walk_packed(data, tables):
    """Timeline of the packed list as the player walks it: (tick, writes)."""
    p = t = 0
    out = []
    loop = -1
    left = 0
    tone = 0
    states = sorted(tables.states, key=tables.states.get)
    while True:
        origin = p
        h = data[p]
        p += 1
        if not h & 15:
            if h == END_HEADER:
                return out
            assert h == REPEAT_HEADER
            copies = data[p]
            target = int.from_bytes(data[p + 1 : p + 3], "little")
            p += 3
            if loop != origin:
                loop = origin
                left = copies
            if left:
                left -= 1
                p = target
            else:
                loop = -1
            continue
        d = h >> 4
        d *= DELAY_UNIT
        t += d
        code = h & 15
        if code == EXPLICIT:
            slot = data[p]
            p += 1
        else:
            slot = tables.masks[code - 1]
        w, tone, n = decode_slots(slot, data[p:], tone, states)
        p += n
        out.append((t, w))


def kinds():
    """Per value of mask bits 3-7 (shifted to 0-4): 0 no state byte,
    1 one value byte, 2 an index byte."""
    out = bytearray()
    for r in range(32):
        n = bin((r << 3) & STATE_BITS).count("1")
        out.append(min(n, 2))
    return bytes(out)


def lists(models, pages):
    """Packed lists for every effect part, the shared mask and state tables,
    each list checked against the unrolled simulation of the old player."""
    import collections

    gate, noise_page, on_page, square, noise_size, on_size = pages
    start = (0xFF, 0xFF, noise_size, 3)  # ssg_start's page/size/control
    tables = Tables()
    parts = []
    for m in models:
        items = merged(resolve(expand(compact(m)), m["tone_size"], pages))
        parts.append((items, repeat_records(unpacked(items, tables, start)) + b"\0\0"))
    count = collections.Counter()
    for _, data in parts:
        p = 0
        while True:
            delay, mask = data[p], data[p + 1]
            p += 2
            if mask == 0:
                break
            if mask == LIST_REPEAT:
                p += 3
                continue
            slot = data[p]
            count[slot] += 1
            p += 1 + sum(SIZES[b] for b in range(8) if slot >> b & 1) + bool(slot & STATE_BITS)
    tables.masks = [m for m, _ in count.most_common(EXPLICIT - 1)]
    out = []
    for items, data in parts:
        packed = pack(data, tables)
        t = 0
        expected = []
        for kind, delay, w in items:
            t += delay
            if kind == "rec":
                expected.append((t, [tuple(x) for x in w]))
        assert walk_packed(packed, tables) == expected
        out.append(packed)
    states = bytes(b for t in sorted(tables.states, key=tables.states.get) for b in t)
    return out, bytes(tables.masks), states
