"""Compile art writers; run native sprite planning, transport and Oak drawing.

The native input is code/color/position records. Every sprite shape and mask
is prepared from original-US art. This component does not yet combine sprite
priority with foreground or plan background restoration.
"""


def swap(v):
    return (v >> 8) | ((v & 255) << 8)


def glyph_descriptor(art, scene=None):
    """Fixed, group-aligned HUD glyph: one mask pair per occupied source row.
    Returns the bytes and words of the record."""
    assert art.size == 8 and art.width in (2, 4, 8)
    occupied = [y for y, row in enumerate(art.masks) if any(row)]
    first, last = (occupied[0], occupied[-1] + 1) if occupied else (0, 0)
    src = art.address + first * art.width
    masks = (bytes((0, row[0] | row[1] << 4)) for row in art.masks[first:last])
    masks = b"".join(masks)
    mask = scene.masks.add([*masks, "native_glyph_done"])
    return ((src("vbbr"), src("vseg")), (src("vptr"), first * 56, last - first, mask))


def record(source, values):
    """Write the bytes and words of a glyph_descriptor record."""
    source.byte(*values[0]).word(*values[1])


def object_packets(pool, scene):
    """Prepared object commands in otherwise unused card SRAM, never VRAM."""
    pointers = {}

    prepared = dict(data=bytes(32768), band_table=None)
    scene.prepared_background = prepared
    from asset_source import Records

    descriptors = Records("object_glyph", "object glyph descriptors (scripts/native_sprites.py)")

    from asset_source import Pool
    from card_link import asset_later

    scene.masks = Pool("glyph_mask", "glyph mask lists (scripts/native_sprites.py)")
    asset_later("glyph_masks", scene.masks.source)
    for key, art in sorted(pool.items.items()):
        art.phase = key[-1]
        values = glyph_descriptor(art, scene)
        pointers[key] = descriptors.pointer(values, lambda source, v=values: record(source, v))
    from card_link import asset

    asset("object_glyphs", descriptors.source)
    scene.compiled_object_programs = 0
    return pointers


def compile_hud(
    out,
    chars,
    offload,
    bank,
    score_start,
    energy=None,
    pool=None,
    scene=None,
    static_pairs=False,
):
    """Fixed glyph positions are build data; only the eight score glyphs vary."""
    from pattern_hud import compile

    variable = (
        set(range(score_start, score_start + 8))
        | set(energy or {})
        | set(getattr(scene, "weapon_characters", {}))
        | set(getattr(scene, "game_characters", {}))
    )
    fixed, stats = compile(chars, variable, pool, scene)
    from asset_source import Source, derived
    from card_link import alias, asset, define

    # One record in banked SRAM: the planner copies it to its stream scratch.
    stream = Source("fixed HUD stream (scripts/native_sprites.py)").section(".desc.state_hud_fixed")
    stream.code(["        .balign 2"]).label("state_hud_fixed")
    for handler, descriptor, offset, _ in fixed:
        stream.word(handler, *descriptor, offset)
    stream.word("hud_fixed_done")
    assert stream.size <= 4096
    asset("state_hud_fixed", stream)
    alias("state_hud_fixed_address", derived("ptr", "state_hud_fixed"))
    alias("state_hud_fixed_bbr", derived("bbr", "state_hud_fixed"))
    define("state_hud_fixed_bytes", stream.size)
    scene.state_hud = []
    for i, (_, _, code, color, flip, x, y) in enumerate(chars):
        if i not in variable:
            continue
        value = (
            getattr(scene, "game_characters", {}).get(i)
            or getattr(scene, "weapon_characters", {}).get(i)
            or ("score", i - score_start, 0)
        )
        scene.state_hud.append(
            (
                "native_glyph",
                offload[(0, code, color, flip, 0)],
                (248 - x) * 56 + y // 4,
                value,
            )
        )
    return dict(
        native_code_bytes=0,
        fixed_positions=len(chars),
        variable_score_glyphs=8,
        variable_energy_glyphs=len(energy or {}),
        layout_cpu="Z180",
        **stats,
    )
