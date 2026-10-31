"""Prepared post-ending overlays over the unchanged final tableau."""

from arcade_flow import cells


def prepare(final):
    layouts = {74: list(final)}
    over = [cells((0x1F2E,)), cells((0x1F3F,))]
    prompt = [cells((0x2258,)), cells((0x2271,))]
    # Dynamic fields contain already selected cabinet glyph IDs.
    for player, first in enumerate((0x181, 0x341)):
        prompt[player] += [(first + i * 32, -(player * 4 + i + 2), 0) for i in range(4)]
    completed = []
    for player, first in enumerate((0x0A2, 0x282)):
        completed.append(
            [(first + i * 32, -(player * 6 + i + 2), 0) for i in range(3)]
            + [(first + (i + 4) * 32, -(player * 6 + i + 5), 0) for i in range(3)]
        )
    for mask in (1, 2, 3):
        layouts[74 + mask] = list(final) + sum((over[p] for p in range(2) if mask & (1 << p)), [])
        layouts[77 + mask] = list(final) + sum((prompt[p] for p in range(2) if mask & (1 << p)), [])
        layouts[81 + mask] = list(final) + sum(
            (completed[p] for p in range(2) if mask & (1 << p)), []
        )
    layouts[81] = list(final)
    return layouts


def live_layouts():
    """Entry and rank text that can coexist with another player's game."""
    entry = []
    rank = []
    for player, (prompt, first, rank_first) in enumerate(
        ((0x2258, 0x181, 0x0A2), (0x2271, 0x341, 0x282))
    ):
        entry.append(
            cells((prompt,)) + [(first + i * 32, -(player * 6 + i + 2), 0) for i in range(4)]
        )
        rank.append(
            [(rank_first + i * 32, -(player * 6 + i + 2), 0) for i in range(3)]
            + [(rank_first + (i + 4) * 32, -(player * 6 + i + 5), 0) for i in range(3)]
        )
    layouts = {}
    for second in range(3):
        for first in range(3):
            kind = first + 3 * second
            if not kind:
                continue
            layouts[kind] = sum(
                (
                    entry[p] if state == 1 else rank[p]
                    for p, state in enumerate((first, second))
                    if state
                ),
                [],
            )
    return layouts
