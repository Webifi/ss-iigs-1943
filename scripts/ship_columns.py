"""Prepared vertical ship spans using the existing aligned clean-row pixels.

One placement is shared by a 32-row map column. Identical spans continue
vertically even when a neighbouring edge changes. All masks stay exact.
"""

import struct
from ship_alignment import PITCH

STAGING = 0x5C00
STAGING_END = 0x5DA0  # Anchor code follows; damage maps flank this gap.
MAX_RECTANGLES = (STAGING_END - STAGING - 1) // 8


def prepare(world, columns, pitches=None):
    from ship_rows import layout, geometry

    result = {}
    pitches = pitches or {}
    for column in sorted(columns):
        pitch = pitches.get(column, PITCH)
        masks = [0] * 64
        for row in range(32):
            raw = world.runs[world.columns[column][0][row]]
            for first, last, mask in zip(raw[1::3], raw[2::3], raw[3::3]):
                for x in range(first, last):
                    masks[x] |= mask
        placement = layout(masks, pitch)
        if placement is None:
            continue
        # Keep the largest span that fits the existing common command buffer.
        # Ragged boss columns split into prepared half/quarter columns; they
        # never fall back to per-plane copying just because they have edges.
        for height in (32, 16, 8, 4, 2, 1):
            blocks = []
            for first_row in range(0, 32, height):
                last_row = first_row + height
                phases = []
                for phase in range(4):
                    active = {}
                    rectangles = []
                    expected = set()
                    for row in range(first_row, last_row + 1):
                        raw = (
                            geometry(
                                world.runs[world.columns[column][phase][row]], placement, phase
                            )
                            if row < last_row
                            else b"\0"
                        )
                        spans = {
                            (m & 15, s, x, n)
                            for m, s, x, n in zip(raw[1::4], raw[2::4], raw[3::4], raw[4::4])
                        }
                        for span, start in list(active.items()):
                            if span not in spans:
                                rectangles.append((*span, start, row))
                                del active[span]
                        for span in spans:
                            if span not in active:
                                active[span] = row
                            m, s, x, n = span
                            expected.update(
                                (row, s + i, x + i, p)
                                for i in range(n)
                                for p in range(4)
                                if m & (1 << p)
                            )
                    if len(rectangles) > MAX_RECTANGLES:
                        break
                    actual = {
                        (y, s + i, x + i, p)
                        for m, s, x, n, start, end in rectangles
                        for y in range(start, end)
                        for i in range(n)
                        for p in range(4)
                        if m & (1 << p)
                    }
                    assert actual == expected, ("ship rectangle coverage", column, phase, first_row)
                    # Offsets remain relative to the whole 32-row map column.
                    # Native clipping already handles its first and last row.
                    data = bytearray()
                    for mask, source, x, n, start, end in sorted(rectangles):
                        aux = bool(source & 128)
                        if phase == 0:
                            assert (
                                placement[0] + 4 <= x and x + n <= placement[0] + 4 + placement[1]
                            ), ("phase zero ship bound", column, x, n, placement)
                        so = (end - 1) * pitch + (source & 127) if aux else (32 - end) * 56 + source
                        data.extend(
                            struct.pack(
                                "<HHBBBB",
                                so,
                                (32 - end) * 56 + x,
                                end - start,
                                n,
                                32 - end,
                                mask | (128 if aux else 0),
                            )
                        )
                        assert so - ((end - 1) * pitch if aux else (32 - end) * 56) == (
                            source & 127 if aux else source
                        )
                    assert STAGING + 1 + len(data) <= STAGING_END, (
                        "Ship command DMA exceeds background staging"
                    )
                    phases.append(bytes([len(rectangles)]) + data)
                if len(phases) != 4:
                    break
                blocks.append((first_row, last_row, phases))
            if len(blocks) == 32 // height:
                result[column] = (placement, blocks)
                break
    return result


