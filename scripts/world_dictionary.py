"""Shared dictionary for the world packet compressor, made from the packets.

The IIgs keeps one 32 KB dictionary and a table of 2,048 dictionary offsets in
memory; every compressed world packet can copy byte runs from the dictionary
(world_packet_lz.py describes the token format). The dictionary is made from
the build's own packets:

1. Count, for each 6-byte sequence, how many packets contain it.
2. Cut every packet into 48-byte segments, every 8 bytes.
3. Repeatedly take the segment whose not yet covered 6-byte sequences are in
   the most packets, until the dictionary is full. Its sequences then count
   as covered.

The offset table holds the 2,048 dictionary offsets used most often by 4- to
11-byte copies; the compressor can then code those copies in 2 bytes, not 3.
"""

import collections
import heapq

SIZE = 32768
SHORTS = 2048
KEY, SEGMENT, STEP = 6, 48, 8


def make(packets):
    """Return (dictionary, short offsets) for these packets."""
    packets = list(dict.fromkeys(packets))
    counts = collections.Counter()
    for p in packets:
        counts.update({p[i : i + KEY] for i in range(len(p) - KEY + 1)})
    segments = [
        p[s : s + SEGMENT] for p in packets for s in range(0, max(1, len(p) - SEGMENT + 1), STEP)
    ]

    def score(segment):
        return sum(counts[k] for k in {segment[i : i + KEY] for i in range(len(segment) - KEY + 1)})

    heap = [(-score(s), i) for i, s in enumerate(segments)]
    heapq.heapify(heap)
    picked = []
    used = 0
    while heap and used + SEGMENT <= SIZE:
        _, i = heapq.heappop(heap)
        value = score(segments[i])
        if heap and value < -heap[0][0]:
            heapq.heappush(heap, (-value, i))
            continue
        picked.append(segments[i])
        used += len(segments[i])
        for k in {segments[i][x : x + KEY] for x in range(len(segments[i]) - KEY + 1)}:
            counts[k] = 0
    dictionary = b"".join(reversed(picked)).ljust(SIZE, b"\0")
    return dictionary, short_offsets(packets, dictionary)


def short_offsets(packets, dictionary):
    """The 2,048 dictionary offsets most used by 4..11-byte copies."""
    import world_packet_lz
    from world_packet_opt import compress

    world_packet_lz.set_dictionary(dictionary, tuple(range(0, SHORTS * 16, 16)))
    used = collections.Counter()
    for p in packets:
        packed = compress(p)
        i = 0
        while packed and i < len(packed):
            op = packed[i]
            i += 1
            if op < 128:
                i += op + 1
            elif op < 192:
                used[world_packet_lz.short_offsets[((op & 7) << 8) | packed[i]]] += 1
                i += 1
            else:
                length = (op & 63) + 3
                ref = int.from_bytes(packed[i : i + 2], "little")
                i += 2
                if not ref & 0x8000 and 4 <= length <= 11:
                    used[ref] += 1
    offsets = [o for o, _ in used.most_common(SHORTS)]
    chosen = set(offsets)
    offsets += [o for o in range(len(dictionary)) if o not in chosen][: SHORTS - len(offsets)]
    return tuple(offsets)
