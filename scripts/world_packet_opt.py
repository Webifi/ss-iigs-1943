"""Optimal parse for the world packet format of scripts/world_packet_lz.py.

Same tokens and decoder: literal runs (op 0..127, 1..128 bytes), short
dictionary matches (2 bytes, length 4..11, one of the 2,048 short offsets),
long matches (3 bytes, length 3..66) into the shared dictionary or back into
the packet. Dynamic programming picks the cheapest token sequence instead of
the greedy longest match."""

import collections
import world_packet_lz as lz

MAXLONG = 66


def compress(data, dict_candidates=512):
    n = len(data)
    INF = 1 << 30
    cost = [INF] * (n + 1)
    cost[n] = 0
    choice = [None] * (n + 1)
    # matches[i]: list of (length, ref, short_ok)
    local = collections.defaultdict(list)
    for i in range(n - 2):
        local[data[i : i + 3]].append(i)
    for i in range(n - 1, -1, -1):
        best = INF
        pick = None
        # literal runs
        for k in range(1, min(128, n - i) + 1):
            c = 1 + k + cost[i + k]
            if c < best:
                best = c
                pick = ("lit", k)
        if i + 3 <= n:
            key = data[i : i + 3]
            for p in lz.index.get(key, ())[-dict_candidates:]:
                m = 3
                limit = min(MAXLONG, n - i, len(lz.D) - p)
                while m < limit and lz.D[p + m] == data[i + m]:
                    m += 1
                short = p in lz.short_index
                for L in range(3, m + 1):
                    c = (2 if short and 4 <= L <= 11 else 3) + cost[i + L]
                    if c < best:
                        best = c
                        pick = ("dict", L, p)
            for p in local.get(key, ()):
                if p >= i:
                    break
                m = 3
                limit = min(MAXLONG, n - i)
                while m < limit and data[p + m] == data[i + m]:
                    m += 1
                for L in range(3, m + 1):
                    c = 3 + cost[i + L]
                    if c < best:
                        best = c
                        pick = ("local", L, i - p)
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
                if p in lz.short_index and 4 <= L <= 11:
                    idx = lz.short_index[p]
                    out += bytes((0x80 | ((L - 4) << 3) | (idx >> 8), idx & 255))
                else:
                    out += bytes((0xC0 | (L - 3), p & 255, p >> 8))
            else:
                ref = 0x8000 | pick[2]
                out += bytes((0xC0 | (L - 3), ref & 255, ref >> 8))
            i += L
    assert lz.decompress(bytes(out)) == data
    return bytes(out)
