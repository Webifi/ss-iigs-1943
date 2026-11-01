; The HUD selectors: hud.s writes the glyph code of each HUD cell; the HUD
; templates (scripts/state_scene.py) draw them.

        .ifndef HUD_INC
        .equ HUD_INC, 1

; hud_lines: the line of each player (the energy bar, then the text), then
; the boss bars.
        .equ LINE_CELLS, 14             ; the cells of each player's line
        .equ ENERGY_CELLS, 8            ; the energy bar at the start of a line
        .equ TEXT_CELLS, 6              ; the text after the energy bar
        .equ BOSS_CELLS, 20             ; the boss bars, after the two lines
        .equ LEADING_DIGITS, 7          ; score digits that can be blank (the last shows 0)
; Glyph codes.
        .equ GLYPH_BLANK, 0x0A          ; a score digit with no glyph
        .equ GLYPH_SPACE, 0x24          ; a line cell with no glyph
        .equ GLYPH_ENERGY, 0x25         ; + the cell value 0-8: an energy cell
        .equ GLYPH_ENERGY_END, GLYPH_ENERGY + 9

        .endif
