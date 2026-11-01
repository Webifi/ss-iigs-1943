"""Prepare four exact row programs for the common arcade shot sprite.

The generic cached descriptor, clipping and priority paths stay intact. This
selects sparse programs only for wholly visible, ordinary code $0BF sprites.
"""

CODE = 0x0BF


def program(scene, phase):
    """The instructions of the program for PHASE, its masks and its rows."""
    pixels = scene.a.gfx[3][CODE]
    p = [pixels[x * 16 + 15 - y] for y in range(16) for x in range(16)]
    masks = [
        [
            sum(
                bool(0 <= 4 * g + k - phase < 16 and p[16 * y + 4 * g + k - phase]) << k
                for k in range(4)
            )
            for g in range(4 + bool(phase))
        ]
        for y in range(16)
    ]
    occupied = [y for y, row in enumerate(masks) if any(row)]
    first, last = occupied[0], occupied[-1] + 1
    # The phase byte after the first jump makes the same-state ablation a
    # single three-byte jump.
    lines = [
        f"; Sprite 0x{CODE:03X}, phase {phase}.",
        "        jr 1f",
        f"        .byte {phase}",
        "1:",
    ]
    last_mask = None
    for y in range(first, last):
        cursor = 0
        for x, mask in enumerate(masks[y]):
            if not mask:
                continue
            gap = x - cursor
            assert gap <= 2, (phase, y, gap)
            lines += ["        inc hl", "        inc de"] * gap
            if mask != last_mask:
                lines += [f"        ld a,{mask}", "        exx", "        out (c),a", "        exx"]
                last_mask = mask
            lines.append("        ldi")
            cursor = x + 1
        if y + 1 < last:
            # The phase source has four groups per row; the fifth group
            # overlaps the first group of the next row.
            if 4 - cursor == 1:
                lines.append("        inc hl")
            lines += [
                "        ex de,hl",
                f"        ld bc,{56 - cursor}",
                "        add hl,bc",
                "        ex de,hl",
            ]
    lines.append("        jp object_compiled_done")
    return lines, masks, first, last


def install(scene):
    """The four programs and their table, in common SRAM
    (scripts/secondsight_fit.py). The selector is .common.sparse_selector of
    src/secondsight/sprite_cache.s."""
    from asset_source import Source
    from secondsight_link import asset

    source = Source("sparse sprite programs (scripts/sparse_sprite.py)")
    for phase in range(4):
        lines, masks, first, last = program(scene, phase)
        assert (first, last) == (5, 11)
        # Verify the program's intended coverage against every ROM pixel.
        for y in range(16):
            for x in range(16):
                shifted = x + phase
                assert bool(masks[y][shifted // 4] & (1 << (shifted % 4))) == bool(
                    scene.a.gfx[3][CODE][x * 16 + 15 - y]
                )
        source.section(f".common.sparse_program_{phase}", "ax").label(f"sparse_program_{phase}")
        source.code(lines)
    source.section(".common.sparse_phase_table").label("sparse_phase_table")
    source.word(*(f"sparse_program_{phase}" for phase in range(4)))
    asset("sparse_programs", source)
