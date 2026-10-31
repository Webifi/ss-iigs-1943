"""Final bank storage: exact native control repeats and binary DOC tables.

Only two-state SSG pages use bit packing. They expand once during startup,
straight to DOC RAM. FM snapshots stay byte-addressable during gameplay.
"""

import struct


def repeat_records(records):
    out = bytearray()
    i = 0
    while i < len(records):
        best = None
        for n in range(1, min(96, (len(records) - i) // 2) + 1):
            block = records[i : i + n]
            copies = 1
            while copies < 256 and records[i + copies * n : i + (copies + 1) * n] == block:
                copies += 1
            saving = sum(map(len, block)) * (copies - 1) - 5
            if saving > 0 and (best is None or saving > best[0]):
                best = (saving, n, copies)
        if best:
            _, n, copies = best
            target = len(out)
            out += b"".join(records[i : i + n])
            out += bytes((0, 128, copies - 1)) + struct.pack("<H", target)
            i += n * copies
        else:
            out += records[i]
            i += 1
    return bytes(out)


def wave_encode(raw, binary=False):
    """A two-level 256-byte page packs to its two levels and 32 bit bytes."""
    if not binary:
        return 0, raw
    assert len(raw) % 256 == 0
    out = bytearray()
    for start in range(0, len(raw), 256):
        page = raw[start : start + 256]
        levels = sorted(set(page))
        if len(levels) > 2:
            return 0, raw
        low, high = levels[0], levels[-1]
        out += bytes((low, high))
        out += bytes(sum((page[i + j] == high) << j for j in range(8)) for i in range(0, 256, 8))
    assert wave_decode(1, out) == raw
    return 1, bytes(out)


def wave_decode(kind, data):
    if kind == 0:
        return bytes(data)
    assert kind == 1 and len(data) % 34 == 0
    return bytes(
        data[p + 1] if data[p + 2 + i // 8] >> (i & 7) & 1 else data[p]
        for p in range(0, len(data), 34)
        for i in range(256)
    )
