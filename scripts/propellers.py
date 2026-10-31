"""Propeller animation by a palette-entry swap.

The arcade spins a plane's propellers by flipping the sprite between the two
palettes of a pair, which differ only in pens 7 and 8 (the propeller greys).
The game shows every second arcade frame, so those flips mostly land on one
colour. Instead, propeller art draws pens 7 and 8 with two private DAC
entries (game_palette), and the card swaps their greys every picture
(palette_commit, src/card/water.s). A video RAM table holds the pair mask
of every code (game_art); a cache miss of propeller art reads a propeller
row of the pair table (cache_propeller_rows, src/card/sprite_cache.s).

The (code, pair) keys come from the ROM:
- the players: every code below 0x100 in pairs 0 and 1 (player 1 and
  player 2), whose palette the game flips on all four player sprites,
  except codes that the movement scripts draw (enemy objects);
- the movement scripts that the game runs (scripts/enemy_script.py): a
  record followed by the same code in another palette (some planes swap
  between the paint schemes of two pairs every tick), or a code drawn in
  both palettes of a pair, for every piece of the object;
- every pair of movement records anywhere in the program ROM with such a
  flip between palettes of PAIRS, for the four pieces of an object.
Only art that has pens 7 or 8 and a pair in PAIRS takes part.
"""

PAIRS = (0, 1, 2, 3, 5, 6)
# The two DAC entries, in the even palette's order (pen 7 light, pen 8 dark).
# All planes share the greys of pairs 2, 3 and 6; the arcade's players use
# 210/112 and pair 5 uses 157/98.
GREYS = (174, 98)
QUAD = (0, 1, 8, 9)


def rom_keys(program, script_codes):
    """The keys of every flipping record pair in the program ROM, and of the
    players. SCRIPT_CODES: the codes that the movement scripts draw."""
    keys = {(code, pair) for code in range(0x100) if code not in script_codes for pair in (0, 1)}
    for i in range(len(program) - 14):
        if program[i] in (0, 254, 255) or program[i + 7] in (0, 254, 255):
            continue
        code, attr, after = program[i + 1], program[i + 2], program[i + 9]
        pairs = {(attr & 15) >> 1, (after & 15) >> 1}
        if program[i + 8] == code and (attr ^ after) & 0xEF and not (attr ^ after) & 0xE0:
            if attr & 15 != after & 15 and pairs <= set(PAIRS):
                code += (attr & 224) << 3
                keys.update((code + offset, pair) for offset in QUAD for pair in pairs)
    return keys


def table(keys, tiles):
    """{code: pairs} of the propeller art among KEYS."""
    codes = {}
    for code, pair in keys:
        if code < len(tiles) and pair in PAIRS and {7, 8} & set(tiles[code]):
            codes.setdefault(code, set()).add(pair)
    return {code: frozenset(pairs) for code, pairs in codes.items()}


def masks(codes):
    """The pair mask of every ROM code: bit P set when the code's art in
    pair P is propeller art."""
    table = bytearray(2048)
    for code, pairs in codes.items():
        table[code] = sum(1 << pair for pair in pairs)
    return bytes(table)
