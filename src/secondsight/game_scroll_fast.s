; Sprite visibility test against fully opaque foreground rows.

        .include "sprite_records.inc"
        .include "rows.inc"

        .global game_low_hidden

        .equ LOW_PALETTE_A, 10          ; palettes drawn below the foreground
        .equ LOW_PALETTE_B, 11

        .section .text.game_low_hidden,"ax",@progbits

; game_low_hidden: true when the foreground hides the whole sprite.
; Palettes 10 and 11 are entirely below the foreground (checked from the
; PROMs by the sprite cache). If every screen row of the sprite is fully
; opaque, alignment and horizontal clipping cannot reveal a pixel. Newly
; exposed rows are not ready until after planning: keep those sprites
; (row_cache_cull), and keep every sprite during a camera reseed.
; In: scene_attr, scene_yrec. Out: carry set when the sprite is hidden.
; AF, BC, HL changed.
game_low_hidden:
        ld a,(scene_attr+1)
        and ATTR_PALETTE
        cp LOW_PALETTE_A
        jp z,low_test
        cp LOW_PALETTE_B
        jp nz,low_visible
low_test:
        ld hl,(row_cache_cull)
        ld a,h
        or a
        jp nz,low_visible               ; a reseed: no row is ready
        ld c,l                          ; the rows from the top that are not ready
        ld hl,(scene_yrec+YREC_TOP)
        ld a,h
        or a
        jp nz,low_visible               ; the sprite starts above the screen
        ld a,l
        cp c
        jp c,low_visible                ; the sprite starts in a row that is not ready
        ld a,(scene_fg_camera)
        dec a                           ; the ring row of screen row 255 ...
        sub l                           ; ... minus the top row: the ring row of the top
        ld l,a
        ld h,row_classes >> 8
        ld a,(scene_yrec+YREC_HEIGHT)
        ld b,a
low_row:
        ld a,(hl)
        cp ROW_OPAQUE
        jp nz,low_visible
        dec l                           ; the ring row of the next screen row
        djnz low_row
        scf
        ret
low_visible:
        or a
        ret
