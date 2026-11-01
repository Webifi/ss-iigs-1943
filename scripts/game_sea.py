"""ROM sea features as compact tiles, below the shared cloud silhouette.

- Build: every non-plain-water cell of sea banks 0/1/3/4/5 becomes a stored
  32x32 tile of ROM palette indices (deduplicated, also row-reversed), and a
  directory of 7-byte draw commands per sea column. A command is one band of
  tile rows and the screen groups that hold land in those rows (sea_bands):
  the open water around an island is not drawn, so the animated water under
  it stays.
- Run time: combined_sea runs every picture and draws all visible bands at
  the sea camera position (FG + RELATIVE), either as whole rectangles or
  through each row's masked water runs (combined_water with this tile as the
  source), then marks the rows as damage for water repair.
- The water left inside a band (sea palette 11 pens 11-13 = colours 39/26/2)
  and foam (pen 10 = colour 48) are fixed colours that flash with the clouds
  (game_water cloud table). Sea palettes 12-14 pen 0 are inland details.
"""


DIRECTORY = 0x19600
# The directory has one 2-byte entry per sea map column. Only columns below
# 1024 are ever read (features are in banks 3-5, columns 384-767; the view
# reaches 8 columns past a band), so it holds 1024 entries and the second
# 2 KB, physical $19E00-$1A5FF, is free for sea data. The cloud flash table
# (game_water.py cloud_palette) is at its start (.sea_directory of
# secondsight.ld); the command records follow it and may run on to $1B000.
DIRECTORY_COLUMNS = 1024
SEA_SPARE = (0x19E00, 0x1A600)
SEA_RECORDS = SEA_SPARE[0] + 96
RECORDS_END = 0x1B000
# Island water pens: sea palette 11 pens 11-13.
WATER_PALETTE, WATER_PENS = 11, (11, 12, 13)
# Estimated card cycles of one band, one band row and one copied group.
BAND_COST, ROW_COST, GROUP_COST = 900, 500, 20


def sea_bands(tile, color, flip, tile_x):
    """Split one tile into bands (first row, rows, left, right) that cover
    every screen group holding a pixel other than island water, at the
    least estimated drawing cost. Rows are display rows of the tile."""

    def pen(x, y):
        return tile[(31 - x if flip & 2 else x) * 32 + (y if flip & 1 else 31 - y)]

    spans = []
    for y in range(32):
        land = [
            g
            for g in range(8)
            if color != WATER_PALETTE
            or any(pen(x, y) not in WATER_PENS for x in range(4 * g, 4 * g + 4))
        ]
        left = max(0, tile_x * 8 - 4 + land[0]) if land else 0
        right = min(56, tile_x * 8 - 4 + land[-1] + 1) if land else 0
        spans.append((left, right) if left < right else None)
    cost = [0] + [None] * 32
    choice = [None] * 33
    for end in range(1, 33):
        for start in range(end):
            rows = [s for s in spans[start:end] if s]
            if rows:
                left = min(s[0] for s in rows)
                right = max(s[1] for s in rows)
                total = (
                    cost[start]
                    + BAND_COST
                    + (end - start) * (ROW_COST + GROUP_COST * (right - left))
                )
            else:
                left = right = None
                total = cost[start]
            if cost[end] is None or total < cost[end]:
                cost[end] = total
                choice[end] = (start, left, right)
    bands = []
    end = 32
    while end:
        start, left, right = choice[end]
        if left is not None:
            bands.append((start, end - start, left, right))
        end = start
    return bands[::-1]


def prepare(scene, pool):
    from asset_source import derived

    a = scene.a
    water = {(18, 3), (19, 3), (22, 3), (23, 3)} | {(i, 0) for i in range(8)}
    # Native stage controls select these four sea banks. Stage retry uses
    # $1000. Include every cell in each bank, not observed capture ranges.
    banks = (0, 1, 3, 4, 5)
    # Each column's commands: a count, then seven bytes per band. Bytes are
    # numbers or symbols of the tile addresses.
    directory = [0] * DIRECTORY_COLUMNS
    records = [0]
    shared = {(0,): 0}
    art = {}
    pixels_seen = {}
    band_cache = {}
    for bank in banks:
        for col in range(bank * 128, (bank + 1) * 128):
            commands = []
            for tile_x in range(8):
                code, attr = a.maps[0x8000 + col * 16 + tile_x * 2 : 0x8002 + col * 16 + tile_x * 2]
                key = (code, (attr >> 2) & 15, attr >> 6)
                if key[:2] in water:
                    continue
                tile = a.gfx[2][code % len(a.gfx[2])]
                color = key[1]
                flip = key[2]
                if (key, tile_x) not in band_cache:
                    band_cache[key, tile_x] = sea_bands(tile, color, flip, tile_x)
                bands = band_cache[key, tile_x]
                if key not in art:
                    pixels = bytes(
                        a.colors[2][
                            color * 16
                            + tile[(31 - x if flip & 2 else x) * 32 + (y if flip & 1 else 31 - y)]
                        ]
                        for y in range(32)
                        for x in range(32)
                    )
                    reverse = b"".join(pixels[y * 32 : (y + 1) * 32] for y in range(31, -1, -1))
                    if reverse in pixels_seen:
                        art[key] = (pixels_seen[reverse], True)
                    else:
                        # A tile's source is biased left by up to 52 groups.
                        # Keep it out of the start of a 64K-group segment,
                        # where that bias would select the preceding segment.
                        address = pool.vram.add(pixels, pool.cpu_window, keep=52)
                        pixels_seen[pixels] = address
                        art[key] = (address, False)
                # Adding screen X at draw time gives the exact source group.
                address, reversed_rows = art[key]
                base = address - (tile_x * 8 - 4)
                for first, rows, left, right in bands:
                    commands += (
                        base("gb0"),
                        base("gb1"),
                        f"{base('vseg')} + {128 if reversed_rows else 0}",
                        left,
                        right,
                        first,
                        rows,
                    )
            if bank in (0, 1):
                assert not commands, ("plain water bank has a feature", bank, col)
            # combined_sea copies a column's commands to $3400 with one LDIR.
            assert len(commands) <= 252, ("sea column commands exceed one copy", col, len(commands))
            data = (len(commands) // 7, *commands)
            if data not in shared:
                shared[data] = len(records)
                records.extend(data)
            assert col < DIRECTORY_COLUMNS or not commands, (
                "sea feature beyond the directory",
                col,
            )
            # Logical address of the record through sea_sram.
            if col < DIRECTORY_COLUMNS:
                directory[col] = derived("low16", f"sea_records + {shared[data]} - 0x110000")
    assert SEA_RECORDS + len(records) <= RECORDS_END, (
        "sea records exceed renderer SRAM",
        len(records),
    )
    assert DIRECTORY + 2 * len(directory) == SEA_SPARE[0]
    # The directory and the records: .sea_directory of secondsight.ld.
    from asset_source import Source
    from secondsight_link import asset

    source = Source("sea feature commands (scripts/game_sea.py)")
    source.section(".rodata.sea_directory").label("sea_directory").word(*directory)
    source.section(".rodata.sea_records").label("sea_records").byte(*records)
    asset("sea_records", source)
    scene.sea_directory_bytes = SEA_RECORDS - DIRECTORY + len(records)
    from game_water import prepare as water_patterns

    light, _ = water_patterns(a, 0x1000, 128)
    # The card selects a pattern row by its high group byte: 256-group aligned.
    scene.light_water_patterns = [pool.vram.add(light, pool.cpu_window, name="light_water", align=1024)]
    normal, _ = water_patterns(a)
    # Cabinet and gameplay share 30 cropped rows in display order.
    packed = b"".join(normal[w * 256 : w * 256 + 224] for w in range(29, -1, -1))
    assert len(packed) == 30 * 224
    assert all(
        packed[(29 - w) * 224 + x] == normal[w * 256 + x] for w in range(30) for x in range(224)
    )
    scene.normal_water_pattern = pool.vram.add(packed, pool.cpu_window, name="normal_water", align=1024)
    scene.sea_art_bytes = len(pixels_seen) * 1024
    print(
        "Full-stage sea tiles",
        len(art),
        "VRAM",
        scene.sea_art_bytes,
        "SRAM",
        scene.sea_directory_bytes,
        flush=True,
    )


def check_occupancy(scene):
    """The banked occupancy code (src/secondsight/sea.s) tests one eight-group
    interval of the $D500 view."""
    # For the exact $D500 view the ROM's other seven eight-group
    # intervals are never fully opaque. Prove that before omitting them.
    w = scene.game_world
    for row in range(0xD500, 0xD600):
        col = w.column_index[row >> 5]
        ready = w.prepared_runs[w.columns[col][0][row & 31]]
        decoded = []
        last = 0
        for end, mask in zip(ready[3::2], ready[4::2]):
            decoded.extend([mask] * (end - last))
            last = end
        assert len(decoded) == 64
        packed = bytes(decoded[i] | (decoded[i + 1] << 4) for i in range(0, 64, 2))
        assert all(
            not all(x == 255 for x in packed[4 * i : 4 * i + 4]) for i in range(8) if i != 4
        ), hex(row)


