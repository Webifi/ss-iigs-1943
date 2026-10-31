; Sprite visibility test against fully opaque foreground rows.

        .global game_low_hidden

        .equ LOW_PALETTE_A, 10          ; palettes drawn below the foreground
        .equ LOW_PALETTE_B, 11
        .equ ROW_OPAQUE, 2              ; row class: all 256 pixels opaque
        .equ YREC_HEIGHT, 6

        .section .text.game_low_hidden,"ax",@progbits

; Palettes 10 and 11 are entirely below the foreground (checked from the
; PROMs by the sprite cache). If every screen row of the sprite is fully
; opaque, alignment and horizontal clipping cannot reveal a pixel. Newly
; exposed rows are not ready until after planning: keep those sprites, and
; keep every sprite during a camera reseed.
; Out: carry set when the sprite is hidden.
game_low_hidden:
        ld a,(scene_attr+1)
        and 0x0F
        cp LOW_PALETTE_A
        jp z,low_test
        cp LOW_PALETTE_B
        jp nz,low_visible
low_test:
        ld hl,(row_cache_cull)
        ld a,h
        or a
        jp nz,low_visible
        ld c,l
        ld hl,(scene_yrec)
        ld a,h
        or a
        jp nz,low_visible
        ld a,l
        cp c
        jp c,low_visible
        ld a,(scene_fg_camera)
        dec a                           ; plus 255
        sub l
        ld l,a
        ld h,row_classes >> 8
        ld a,(scene_yrec+YREC_HEIGHT)
        ld b,a
low_row:
        ld a,(hl)
        cp ROW_OPAQUE
        jp nz,low_visible
        dec l
        djnz low_row
        scf
        ret
low_visible:
        or a
        ret
