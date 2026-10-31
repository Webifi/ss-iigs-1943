"""Read the continuous game's immutable HUD templates without staging them."""


def uniform_descriptor(art, scene):
    """An invariant plane mask needs one OUT for the whole glyph, not per group."""
    rows = [row for row in art.masks if any(row)]
    first = next(i for i, row in enumerate(art.masks) if any(row))
    last = max(i for i, row in enumerate(art.masks) if any(row)) + 1
    mask = rows[0][0]
    if not mask or any(m != mask for row in art.masks[first:last] for m in row):
        return None
    src = art.address + first * 2
    done = scene.masks.add(["native_glyph_done"])
    values = ((src("vbbr"), src("vseg")), (src("vptr"), first * 56, last - first, done))
    if not hasattr(scene, "hud_uniform_descriptors"):
        from asset_source import Records

        scene.hud_uniform_descriptors = Records(
            "hud_uniform", "uniform HUD glyph descriptors (scripts/hud_fast.py)"
        )
    bank, ptr = scene.hud_uniform_descriptors.pointer(
        values, lambda source: source.byte(*values[0]).word(*values[1])
    )
    return f"{bank} + 0x{mask << 8:X}", ptr


def damage_spans(scene, pool, chars, energy):
    """Union every possible HUD glyph, then combine equal adjacent row bounds.

    The boss bars have their own conditional damage marking. These bounds
    cover both normal HUD bands, including death and continue messages.
    """
    from game_hud import glyphs
    from weapon_hud import glyphs as weapons

    bounds = [[56, 0] for _ in range(256)]
    for i, cmd in enumerate(chars):
        top, left = 248 - cmd[5], cmd[6] // 4
        if top == 32:
            continue  # optional boss bars
        assert top < 16 or top >= 240, (i, cmd)
        variable = scene.game_characters.get(i) or scene.weapon_characters.get(i)
        if variable:
            kind, _, color = variable
            choices = (
                weapons(kind[3:] if kind.startswith("p2_") else kind)
                if "weapon" in kind
                else glyphs(kind, color)
            )
        elif cmd[5] == 240 and cmd[6] < 64:
            choices = [(n, 0) for n in range(10)]
        else:
            choices = [(cmd[2], cmd[3])]
        for code, color in choices:
            art = pool.items[(0, code, color, cmd[4], 0)]
            for y, row in enumerate(art.masks):
                xs = [left + x for x, m in enumerate(row) if m]
                if xs:
                    bounds[top + y][0] = min(bounds[top + y][0], min(xs))
                    bounds[top + y][1] = max(bounds[top + y][1], max(xs) + 1)
    spans = []
    for y, (left, right) in enumerate(bounds):
        if left >= right:
            continue
        if spans and spans[-1][0] + spans[-1][1] == y and spans[-1][2:] == [left, right]:
            spans[-1][1] += 1
        else:
            spans.append([y, 1, left, right])
    scene.hud_damage_groups = sum(n * (r - l) for _, n, l, r in spans)
    return spans


def bounds_source(scene):
    """build/card/gen/hud_bounds.s: the row spans of the HUD."""
    from card_link import generate

    lines = [
        '        .section .rodata.hud_bounds,"a"',
        "        .global state_hud_bounds",
        "state_hud_bounds:",
    ]
    lines += [f"        .byte {n},{top},{left},{right}" for top, n, left, right in scene.hud_spans]
    lines.append("        .byte 0")
    generate("hud_bounds", "\n".join(lines) + "\n")


