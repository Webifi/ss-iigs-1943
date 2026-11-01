"""Lossless native palette sharing."""


# Sprite (palette, pen) entries that no sprite draws: pen 14 of palettes 10
# and 11 (colour $C5) is in no tile drawn in those palettes. game_build
# checks this against every drawn sprite key; its DAC entry is free.
UNDRAWN_SPRITE_PENS = {(10, 14), (11, 14)}


def sprite_colours(a):
    """The colours of every sprite palette pen that can be drawn."""
    return {
        v
        for i, v in enumerate(a.colors[3])
        if i % 16 and (i // 16, i % 16) not in UNDRAWN_SPRITE_PENS
    }


def world_usage(a):
    from world_stream import routes, resident_ranges, INTRO, CABINET

    base = (
        {v for i, v in enumerate(a.colors[0]) if i % 4}
        | sprite_colours(a)
        | {0}
    )

    def colors(layer, columns):
        result = set()
        for column in columns:
            for x in range(8):
                at = (32768 if layer == 2 else 0) + column * 16 + x * 2
                code, attr = a.maps[at : at + 2]
                code += (attr & 1) * 256 if layer == 1 else 0
                for pen in set(a.gfx[layer][code % len(a.gfx[layer])]):
                    value = a.colors[layer][((attr >> 2) & 15) * 16 + pen]
                    if not (layer == 1 and value == 15):
                        result.add(value)
        return result

    # Include every cell of every native stage's ROM-derived world region,
    # every sea bank (including light water), and both cabinet map regions.
    # Characters and sprites conservatively include all palettes and pens.
    sea = colors(2, [c for bank in (0, 1, 3, 4, 5) for c in range(bank * 128, (bank + 1) * 128)])
    usages = []
    for stage, route in enumerate(routes()):
        columns = {
            c
            for region in route + [INTRO, CABINET]
            for lo, hi in resident_ranges(region)
            for c in range(lo // 32, hi // 32 + 1)
        }
        usages.append((stage + 1, base | sea | colors(1, columns)))
    return usages


def merge(a):
    original = a.palette
    tables = a.colors
    rgb = [original[i * 3 : i * 3 + 3] for i in range(256)]
    displayed = [
        {v for i, v in enumerate(tables[0]) if i % 4},
        set(tables[1]) - {15},
        set(tables[2]),
        sprite_colours(a),
    ]
    # Preserve one original index per RGB, including index zero for clears.
    # Fifteen remains exclusively the foreground transparency sentinel.
    canonical = {rgb[0]: 0}
    for index in sorted(set.union(*displayed)):
        if index != 15:
            canonical.setdefault(rgb[index], index)
    palette = bytearray(original)
    for color, index in canonical.items():
        palette[index * 3 : index * 3 + 3] = color
    converted = []
    for layer, table in enumerate(tables):
        target = bytes(
            15
            if layer == 1 and value == 15
            else canonical[rgb[value]]
            if value in displayed[layer]
            else 0
            for value in table
        )
        changed = 0
        for pen, (before, after) in enumerate(zip(table, target)):
            visible = (
                pen % 4 != 0
                if layer == 0
                else before != 15
                if layer == 1
                else pen % 16 != 0 and (pen // 16, pen % 16) not in UNDRAWN_SPRITE_PENS
                if layer == 3
                else True
            )
            if visible:
                changed += rgb[before] != palette[after * 3 : after * 3 + 3]
                assert after != 15
            elif layer == 1:
                assert after == 15
        assert changed == 0
        converted.append(target)
    usages = world_usage(a)
    active = set.union(*(values for _, values in usages))
    occupied = {canonical[rgb[v]] for v in active} | {15}
    free = sorted(set(range(256)) - occupied)
    assert len(free) >= 120, (len(canonical), len(free))
    slots = free[:120]
    # Pick a contiguous triple for light water without losing any of the
    # existing contiguous 30-entry stage runs.
    contiguous = lambda x: [
        all(x[k * 30 + i] == x[k * 30] + i for i in range(30)) for k in range(4)
    ]
    before = contiguous(slots)
    for first in slots:
        triple = [first, first + 1, first + 2]
        if not all(x in slots for x in triple):
            continue
        candidate = triple + [x for x in slots if x not in triple]
        if contiguous(candidate) == before:
            slots = candidate
            break
    else:
        raise AssertionError("no contiguous light-water DAC slots without changing stage runs")
    # free = indices no stage uses. 120 water slots (light water takes a
    # contiguous triple of them), 1 bolt slot and 2 propeller slots (pens
    # 7/8 of propeller art; the card swaps their greys every picture,
    # scripts/propellers.py); the rest stays free.
    # Colours used only by the ending's sea bank 2 are not counted by
    # world_usage, so they can become water slots; arcade_flow restores them
    # for the ending tableau.
    a.water_slots = slots
    assert len(free) >= 123
    a.bolt_slots = free[120:121]
    for i in a.bolt_slots:
        palette[i * 3 : i * 3 + 3] = bytes((0, 188, 241))
    from propellers import GREYS

    a.prop_slots = free[121:123]
    assert a.prop_slots == list(range(a.prop_slots[0], a.prop_slots[0] + 2))
    for i, grey in zip(a.prop_slots, GREYS):
        palette[i * 3 : i * 3 + 3] = bytes((grey,) * 3)
    for stage, values in usages:
        assert not {canonical[rgb[v]] for v in values} & set(a.water_slots)
        assert all(
            rgb[v] == palette[canonical[rgb[v]] * 3 : canonical[rgb[v]] * 3 + 3] for v in values
        )
    a.palette = bytes(palette)
    a.colors = converted
    print("Native palette", len(canonical), "RGB colours;", len(free), "free entries", flush=True)
