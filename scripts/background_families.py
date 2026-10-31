"""Compact cold row pointers; expand once when a 32-row column enters.

Each word holds a 13-bit offset into the existing SRAM row programs and a
repeat count of one to eight. Drawing still consumes the same ready pointers.
"""

import struct


def pack(pointers):
    values = struct.unpack("<32H", pointers)
    out = bytearray()
    i = 0
    while i < 32:
        j = i + 1
        while j < min(32, i + 8) and values[j] == values[i]:
            j += 1
        offset = values[i] - 0xC000
        assert 0 <= offset < 0x2000
        out.extend(struct.pack("<H", offset | ((j - i - 1) << 13)))
        i = j
    decoded = []
    for (word,) in struct.iter_unpack("<H", out):
        decoded.extend([0xC000 + (word & 0x1FFF)] * ((word >> 13) + 1))
    assert tuple(decoded) == values
    return bytes(out)


