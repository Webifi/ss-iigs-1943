"""Build-proved opaque interiors for moving-layer water repairs.

Metadata and the selector occupy separate planes of one video RAM block. The
selector is copied into the ship's temporary staging buffer for repair;
ship drawing replaces the buffer only after repair finishes.
"""

import numpy as np


def reserve(scene, pool):
    w = scene.game_world
    masks = []
    for row in w.runs:
        bits = 0
        for lo, hi, mask in zip(row[1::3], row[2::3], row[3::3]):
            if mask == 15:
                bits |= ((1 << (hi - lo)) - 1) << lo
        masks.append(bits)
    opaque = np.fromiter((masks[w.run(i, 0)] for i in range(65536)), dtype=np.uint64, count=65536)
    # Repeated doubling intersects precisely 256 consecutive world rows.
    for shift in (1, 2, 4, 8, 16, 32, 64, 128):
        opaque &= np.roll(opaque, -shift)
    cores = []
    for camera, value in enumerate(opaque):
        bits = int(value)
        best = (0, 0)
        x = 0
        while x < 64:
            if not ((bits >> x) & 1):
                x += 1
                continue
            end = x + 1
            while end < 64 and ((bits >> end) & 1):
                end += 1
            if end - x > best[1] - best[0]:
                best = (x, end)
            x = end
        # Cabinet region 26 replaces ROM rows $E800-$EFFF. Exclude any
        # viewport that touches it; the ordinary repair remains available.
        cabinet_view = 0xE701 <= camera <= 0xEFFF
        cores.append(best if not cabinet_view and best[1] - best[0] >= 8 else (0, 0))
    entries = []
    directory = []
    for page in range(256):
        rows = cores[page * 256 : (page + 1) * 256]
        current = [(i, *core) for i, core in enumerate(rows) if i == 0 or core != rows[i - 1]]
        assert len(current) <= 255
        directory.append((len(entries), len(current)))
        entries.extend(current)
    assert len(entries) < 65536
    groups = 256 + len(entries)
    data = bytearray(groups * 4)
    for i, (offset, count) in enumerate(directory):
        data[4 * i : 4 * i + 3] = bytes((offset & 255, offset >> 8, count))
    for i, (start, lo, hi) in enumerate(entries, 256):
        data[4 * i : 4 * i + 3] = bytes((start, lo, hi))
    for camera, expected in enumerate(cores):
        page, low = divmod(camera, 256)
        first, count = directory[page]
        selected = next(
            (entry for entry in reversed(entries[first : first + count]) if entry[0] <= low), None
        )
        assert selected is not None and selected[1:] == expected
        lo, hi = expected
        assert (
            not hi or ((int(opaque[camera]) >> lo) & ((1 << (hi - lo)) - 1)) == (1 << (hi - lo)) - 1
        )
    # Planes 0-2 hold the metadata; plane 3 holds the selector code
    # (src/secondsight/repair_core.s), copied to $5C00 to run, then the title
    # preservation jobs (scripts/hitch_scene.py).
    import secondsight_link
    from asset_source import Source
    from secondsight_link import alias, asset, define

    block = pool.vram.block(groups, 4096, "repair_cores")
    metadata = Source("repair core metadata (scripts/repair_core.py)")
    for plane in range(3):
        metadata.section(f".plane.repair_cores.{plane}.0").data(data[plane::4])
    asset("repair_metadata", metadata)
    # The selector code runs in the ship staging; secondsight.ld checks that
    # plane 3 of the block holds a copy of the whole staging.
    secondsight_link.runs[".plane.repair_cores.3.0"] = "ship_staging__run"
    define("repair_core_groups", groups)
    block("group16"), block("vseg")  # repair_core_pointer
    alias("repair_core_directory", block("vptr4k"))
    print("Repair core VRAM:", groups * 4, "bytes, entries", len(entries), flush=True)


