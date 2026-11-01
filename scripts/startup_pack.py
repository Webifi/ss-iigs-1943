"""Bounded LZ blocks: the startup records (src/boot_unpack.s unpacks them)
and the world upload jobs (src/secondsight/world_rows.s).

A low token stores 1..128 literal bytes. A high token stores a 3..130 byte
copy followed by its 16-bit backward distance. Blocks are at most 16 KB.

"startup_pack.py IN OUT" writes the packed form of file IN to OUT (the
Makefile packs the linked helpers with it).
"""

import sys
from collections import defaultdict, deque
from functools import lru_cache
from heapq import heappop, heappush
from pathlib import Path

LITERALS = 128  # the longest literal run
COPY = 130  # the longest copy
CANDIDATES = 256  # the most recent earlier places of a 3-byte sequence that a copy tries


def _equal(data, a, b, lo, hi):
    """The length of the equal start of data[a:] and data[b:], at most HI.
    The first LO bytes are equal."""
    if data[a + lo : a + hi] == data[b + lo : b + hi]:
        return hi
    while hi - lo > 1:  # equal for LO bytes, not for HI bytes
        mid = (lo + hi) // 2
        if data[a + lo : a + mid] == data[b + lo : b + mid]:
            lo = mid
        else:
            hi = mid
    return lo


def _parse(data, limit):
    """(n, packed): the longest start data[:n] that packs into at most
    LIMIT bytes (all of DATA when LIMIT is None), in its smallest packed
    form. f[j] is the fewest bytes that pack data[:j]: a literal run of k
    bytes costs 1 + k, a copy costs 3. The parse is a build-time choice;
    the token format stays the same."""
    n = len(data)
    f = [0] * (n + 1)
    last = [None] * (n + 1)  # the token that ends at j: (start, distance); distance 0 = literals
    chains = defaultdict(lambda: deque(maxlen=CANDIDATES))
    # The best literal run that ends at j starts at the m in j-128..j-1 with
    # the smallest f[m] - m. The window keeps those values in increasing order.
    runs = deque()
    copies = []  # heap of (f[s] + 3, s, the end of the longest copy from s, its distance)
    fit = 0  # the longest start that fits LIMIT
    for j in range(1, n + 1):
        value = f[j - 1] - (j - 1)
        while runs and runs[-1][0] >= value:
            runs.pop()
        runs.append((value, j - 1))
        if runs[0][1] < j - LITERALS:
            runs.popleft()
        # The longest copy from s = j - 3, the newest place whose copies (3
        # bytes or more) can end at j. A longer copy is also equal at the
        # byte after the best length and in the bytes between the 3-byte key
        # and it.
        s = j - 3
        if s >= 0:
            chain = chains[data[s : s + 3]]
            longest = min(COPY, n - s)
            best = 2
            distance = 0
            for old in reversed(chain):
                if data[old + best] != data[s + best] or data[old + 3 : old + best] != data[s + 3 : s + best]:
                    continue
                best, distance = _equal(data, old, s, best + 1, longest), s - old
                if best == longest:
                    break
            if distance:
                heappush(copies, (f[s] + 3, s, s + best, distance))
            chain.append(s)
        while copies and copies[0][2] < j:
            heappop(copies)  # its longest copy ends before j
        f[j] = runs[0][0] + 1 + j
        last[j] = runs[0][1], 0
        if copies and copies[0][0] < f[j]:
            f[j], start, _, distance = copies[0]
            last[j] = start, distance
        # f never falls as j grows (the last token of data[:j + 1] made one
        # byte shorter packs data[:j] in as few bytes), so no longer start fits.
        if limit is not None and f[j] > limit:
            break
        fit = j
    tokens = []
    j = fit
    while j:
        start, distance = last[j]
        tokens.append((start, j, distance))
        j = start
    out = bytearray()
    for start, end, distance in reversed(tokens):
        if distance:
            out.append(128 + end - start - 3)
            out.extend(distance.to_bytes(2, "little"))
        else:
            out.append(end - start - 1)
            out.extend(data[start:end])
    return fit, bytes(out)


def pack(data):
    """The packed form of DATA."""
    return _packed(bytes(data), None)[1]


def pack_prefix(data, limit):
    """(n, packed): the longest start data[:n] whose packed form has at most
    LIMIT bytes, and that form."""
    return _packed(bytes(data), limit)


@lru_cache(maxsize=512)
def _packed(data, limit):
    assert len(data) <= 16384
    n, result = _parse(data, limit)
    assert unpack(result) == data[:n] and (n == len(data) if limit is None else len(result) <= limit)
    return n, result


def unpack(data):
    out = bytearray()
    i = 0
    while i < len(data):
        header = data[i]
        i += 1
        if header & 128:
            n = (header & 127) + 3
            distance = int.from_bytes(data[i : i + 2], "little")
            i += 2
            assert 0 < distance <= len(out)
            for _ in range(n):
                out.append(out[-distance])
        else:
            n = header + 1
            out.extend(data[i : i + n])
            i += n
    return bytes(out)


if __name__ == "__main__":
    Path(sys.argv[2]).write_bytes(pack(Path(sys.argv[1]).read_bytes()))
