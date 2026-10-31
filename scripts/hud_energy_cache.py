"""Cache two opaque energy bars and skip verified blank HUD groups.

A miss uses the ordinary glyph renderer and snapshots the finished bar from
that back page.  A hit copies only the 64x8 opaque rectangle; transparent
HUD glyphs and both page backgrounds still use the ordinary renderer.
"""

from game_hud import glyphs


def reserve(pool):
    """Each bar is 16 groups x 8 rows = 512 physical bytes. The INC H that
    selects P2 at +256 groups keeps its fast address calculation, so P2
    starts 1024 bytes after P1. Entry clears both bars."""
    return pool.vram.reserve(1536, name="energy_cache")


def prepare(scene):
    # The sentinel replaces only the first of eight consecutive templates.
    for player, color in ((0, 2), (1, 0)):
        expected = list(range(player * 14, player * 14 + 8))
        indices = [
            i
            for i, (_, _, _, v) in enumerate(scene.state_hud)
            if v and v[0] == "game_line" and v[1] in expected
        ]
        assert len(indices) == 8 and indices == list(range(indices[0], indices[0] + 8))
        assert [scene.state_hud[i][3][1] for i in indices] == expected
        positions = [scene.state_hud[i][2] for i in indices]
        assert positions == [240 * 56 + player * 28 + 2 * i for i in range(8)]
        for code, palette in glyphs("game_line", color)[37:46]:
            art = scene.pool.items[(0, code, palette, 0, 0)]
            assert len(art.masks) == 8 and all(row == [15, 15] for row in art.masks)
    # Empty weapon names and the six normal-play message cells can be
    # skipped as a group, but only when their current selectors are blank.
    from weapon_hud import glyphs as weapon_glyphs

    for prefix in ("weapon_name", "p2_weapon_name"):
        ids = [
            i
            for i, (_, _, _, v) in enumerate(scene.state_hud)
            if v and v[0] in {prefix + str(j) for j in range(8)}
        ]
        assert len(ids) == 8 and ids == list(range(ids[0], ids[0] + 8))
        assert [scene.state_hud[i][3][0] for i in ids] == [prefix + str(j) for j in range(8)]
        for j in range(8):
            code, color = weapon_glyphs("weapon_name" + str(j))[0]
            assert not any(any(row) for row in scene.pool.items[(0, code, color, 0, 0)].masks)
    for first in (8, 22):
        ids = [
            i
            for i, (_, _, _, v) in enumerate(scene.state_hud)
            if v and v[0] == "game_line" and v[1] in range(first, first + 6)
        ]
        assert len(ids) == 6 and ids == list(range(ids[0], ids[0] + 6))
        for i in ids:
            kind, index, color = scene.state_hud[i][3]
            code, palette = glyphs(kind, color)[36]
            assert not any(any(row) for row in scene.pool.items[(0, code, palette, 0, 0)].masks)
    for kind in ("score", "score2"):
        ids = [
            i
            for i, (_, _, _, v) in enumerate(scene.state_hud)
            if v and v[0] == kind and v[1] in range(4)
        ]
        assert len(ids) == 4 and ids == list(range(ids[0], ids[0] + 4))
        assert [scene.state_hud[i][3][1] for i in ids] == list(range(4))
        code, color = (0x24, 0)
        assert not any(any(row) for row in scene.pool.items[(0, code, color, 0, 0)].masks)
    cache = scene.energy_cache
    from card_link import alias

    alias("energy_cache_group", cache("group16"))
    alias("energy_cache_segment", cache("vseg"))

    # region bank-code of src/card/memory.toml holds the cache code;
    # scripts/card_layout.py places its two bridges in common SRAM. The
    # planner saves the template cursor before entering; L still holds the
    # marker.
    return []
