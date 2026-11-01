"""Reuse identical four-pixel latch patterns across the fixed HUD."""

from collections import defaultdict


def compile(chars, variable, pool, scene):
    """The fixed HUD as programs of latch pattern stores, in banked SRAM
    records. Returns (handler, (BBR, pointer), offset, None) per program."""
    from asset_source import Records
    from secondsight_link import asset

    programs = Records("hud_pattern", "fixed HUD pattern programs (scripts/pattern_hud.py)")
    groups = []
    candidates = set()
    for i, cmd in enumerate(chars):
        if i in variable:
            continue
        art = pool.get(cmd)
        top = 248 - cmd[5]
        left = cmd[6] // 4
        for y, row in enumerate(art.masks):
            for x, mask in enumerate(row):
                if not mask:
                    continue
                values = tuple(art.pixels[(y * 2 + x) * 4 : (y * 2 + x + 1) * 4])
                opaque = [values[p] for p in range(4) if mask & (1 << p)]
                candidates.add(tuple(values[p] if mask & (1 << p) else opaque[0] for p in range(4)))
                candidates.update((v,) * 4 for v in opaque)
                groups.append(((top + y) // 64, ((top + y) % 64) * 56 + left + x, mask, values))
    # Transparent lanes are don't-care bits, so one latch pattern can serve
    # many differently shaped groups without modifying a transparent pixel.
    pending = set(range(len(groups)))
    batches = []
    matches = {
        v: {
            i
            for i, g in enumerate(groups)
            if all(not (g[2] & (1 << p)) or g[3][p] == v[p] for p in range(4))
        }
        for v in candidates
    }
    extra = 0
    while pending:
        pattern = max(sorted(matches), key=lambda v: len(matches[v] & pending))
        members = matches[pattern] & pending
        assert members
        pending -= members
        by_band = defaultdict(list)
        address = pool.allocate(bytes(pattern))
        extra += 4
        for i in members:
            band, offset, mask, _ = groups[i]
            by_band[band].append((offset, mask))
        for band, stores in sorted(by_band.items()):
            lines = [
                f"        .byte {address('vbbr')}, {address('vseg')}",
                f"        .word {address('vptr')}",
            ]
            cursor = 0
            last_mask = None
            for offset, mask in sorted(stores, key=lambda v: (v[1], v[0])):
                gap = offset - cursor
                if gap == 1:
                    lines.append("        inc hl")
                elif gap:
                    lines += [f"        ld de,0x{gap & 65535:04X}", "        add hl,de"]
                if mask != last_mask:
                    lines += [f"        ld a,{mask}", "        exx", "        out (c),a", "        exx"]
                    last_mask = mask
                lines.append("        ld (hl),a")
                cursor = offset
            lines.append("        jp native_glyph_done")
            pointer = programs.pointer(tuple(lines), lambda source, lines=lines: source.code(lines))
            batches.append(("native_hud_pattern", pointer, band * 64 * 56, None))
    asset("hud_patterns", programs.source)
    return batches, dict(
        patterns=len({v for v in candidates if matches[v]}),
        groups=len(groups),
        extra_vram_bytes=extra,
        draw_commands=len(batches),
    )


