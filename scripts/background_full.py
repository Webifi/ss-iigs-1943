"""Bulk empty views in an unused tail of the existing world SRAM reservation."""

CODE = 0xC700
BANK = 15


def empty_views(world):
    # Exact 256-row views, including a cloud just beyond either edge.
    # Two separate empty-view intervals must be at least 256 rows apart,
    # so a world page needs just one inclusive low/high range.
    occupied = [world.runs[world.run(row, 0)] != b"\0" for row in range(65536)]
    extended = occupied + occupied[:255]
    prefix = [0]
    for value in extended:
        prefix.append(prefix[-1] + value)
    low = bytearray(256)
    high = bytearray(256)
    for page in range(256):
        rows = [r for r in range(256) if prefix[page * 256 + r + 256] == prefix[page * 256 + r]]
        if rows:
            assert rows == list(range(rows[0], rows[-1] + 1)), ("empty view interval", page)
            low[page] = rows[0]
            high[page] = rows[-1]
        else:
            low[page] = 1
            high[page] = 0
    return bytes(low + high)


def limits_source(scene):
    """build/secondsight/gen/background_empty_limits.s."""
    from secondsight_link import generate

    # Per world page: the first and the last camera row whose view is empty.
    limits = empty_views(scene.game_world)
    lines = [
        '        .section .rodata.background_empty_limits,"a"',
        "        .global background_empty_limits",
        "background_empty_limits:",
    ]
    lines += [
        "        .byte " + ",".join(str(v) for v in limits[i : i + 16])
        for i in range(0, len(limits), 16)
    ]
    generate("background_empty_limits", "\n".join(lines) + "\n")
