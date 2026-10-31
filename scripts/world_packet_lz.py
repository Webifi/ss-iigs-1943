"""Compact exact world packets with a shared dictionary and byte tokens."""

import collections, struct

D = d = b""
SHORT = b""
short_offsets = ()
short_index = {}
index = {}


def set_dictionary(dictionary, offsets):
    """Use this dictionary and short-offset table (world_dictionary.make)."""
    global D, d, SHORT, short_offsets, short_index, index
    D = d = bytes(dictionary)
    short_offsets = tuple(offsets)
    SHORT = struct.pack("<%dH" % len(short_offsets), *short_offsets)
    short_index = {v: i for i, v in enumerate(short_offsets)}
    index = collections.defaultdict(list)
    for i in range(len(d) - 2):
        index[d[i : i + 3]].append(i)


def decompress(src):
    out = bytearray()
    i = 0
    while i < len(src):
        op = src[i]
        i += 1
        if op < 128:
            n = op + 1
            out.extend(src[i : i + n])
            i += n
            continue
        if op < 192:
            n = ((op & 63) >> 3) + 4
            idx = ((op & 7) << 8) | src[i]
            i += 1
            ref = short_offsets[idx]
        else:
            n = (op & 63) + 3
            ref = int.from_bytes(src[i : i + 2], "little")
            i += 2
        if ref & 0x8000:
            distance = ref & 0x7FFF
            for _ in range(n):
                out.append(out[-distance])
        else:
            out.extend(D[ref : ref + n])
    return bytes(out)
