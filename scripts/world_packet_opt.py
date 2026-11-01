"""Optimal parse for the world packet format of scripts/world_packet_lz.py.

Same tokens and decoder: literal runs (op 0..127, 1..128 bytes), short
dictionary matches (2 bytes, length 4..11, one of the 2,048 short offsets),
long matches (3 bytes, length 3..66) into the shared dictionary or back into
the packet. Dynamic programming picks the cheapest token sequence instead of
the greedy longest match."""

import collections
import os
from concurrent.futures import ProcessPoolExecutor

import world_packet_lz as lz

MAXLONG = 66


def compress(data, dict_candidates=512):
    n = len(data)
    D = lz.D
    size = len(D)
    short_index = lz.short_index
    cost = [0] * (n + 1)
    choice = [None] * (n + 1)
    local = collections.defaultdict(list)
    for i in range(n - 2):
        local[data[i : i + 3]].append(i)
    # The best literal run at i ends at the j in i+1..i+128 with the smallest
    # cost[j] + j (the first such j on equal costs). The window keeps those
    # values in increasing order.
    window = collections.deque()
    for i in range(n - 1, -1, -1):
        value = cost[i + 1] + i + 1
        while window and window[-1][0] >= value:
            window.pop()
        window.append((value, i + 1))
        if window[0][1] > i + 128:
            window.popleft()
        best = 1 - i + window[0][0]
        pick = ("lit", window[0][1] - i)
        if i + 3 <= n:
            # The matches are tried in a fixed order and a match is taken
            # only when it costs less, so equal costs keep the first choice.
            # LOW3 and LOW2 are the lowest costs that any long or short
            # match at i can have: when the best choice is not above them,
            # no further match can be taken.
            key = data[i : i + 3]
            longest = min(MAXLONG, n - i)
            low3 = 3 + min(cost[i + 3 : i + longest + 1])
            low2 = 2 + min(cost[i + 4 : i + min(11, longest) + 1]) if longest >= 4 else low3
            low = min(low2, low3)
            three = 3 + cost[i + 3]  # any 3-byte match
            next_byte = data[i + 3] if longest > 3 else -1
            for p in lz.index.get(key, ())[-dict_candidates:]:
                if best <= low:
                    break
                short = p in short_index
                if not short and low3 >= best:
                    continue
                limit = longest if p + longest <= size else size - p
                if limit == 3 or D[p + 3] != next_byte:
                    if three < best:
                        best = three
                        pick = ("dict", 3, p)
                    continue
                m = 4
                while m < limit and D[p + m] == data[i + m]:
                    m += 1
                if short:
                    parts = ((3, 3, 3), (2, 4, m if m < 11 else 11), (3, 12, m))
                else:
                    parts = ((3, 3, m),)
                for add, first, last in parts:  # (token bytes, lengths)
                    if first > last:
                        continue
                    span = cost[i + first : i + last + 1]
                    low_span = min(span)
                    if add + low_span < best:
                        best = add + low_span
                        pick = ("dict", first + span.index(low_span), p)
            if low3 < best:
                for p in local.get(key, ()):
                    if p >= i or best <= low3:
                        break
                    if longest == 3 or data[p + 3] != next_byte:
                        if three < best:
                            best = three
                            pick = ("local", 3, i - p)
                        continue
                    m = 4
                    while m < longest and data[p + m] == data[i + m]:
                        m += 1
                    span = cost[i + 3 : i + m + 1]
                    low_span = min(span)
                    if 3 + low_span < best:
                        best = 3 + low_span
                        pick = ("local", 3 + span.index(low_span), i - p)
        cost[i] = best
        choice[i] = pick
    out = bytearray()
    i = 0
    while i < n:
        pick = choice[i]
        if pick[0] == "lit":
            k = pick[1]
            out.append(k - 1)
            out += data[i : i + k]
            i += k
        else:
            L = pick[1]
            if pick[0] == "dict":
                p = pick[2]
                if p in short_index and 4 <= L <= 11:
                    idx = short_index[p]
                    out += bytes((0x80 | ((L - 4) << 3) | (idx >> 8), idx & 255))
                else:
                    out += bytes((0xC0 | (L - 3), p & 255, p >> 8))
            else:
                ref = 0x8000 | pick[2]
                out += bytes((0xC0 | (L - 3), ref & 255, ref >> 8))
            i += L
    assert lz.decompress(bytes(out)) == data
    return bytes(out)


def compress_all(packets):
    """compress() of each packet, on all processor cores. Each worker uses
    the dictionary that world_packet_lz.set_dictionary set here."""
    with ProcessPoolExecutor(
        os.cpu_count(), initializer=lz.set_dictionary, initargs=(lz.D, lz.short_offsets)
    ) as workers:
        return list(workers.map(compress, packets, chunksize=16))
