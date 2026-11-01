; Water row families: a packed list of (pointer, repeat count) words expands
; into family_staging, the list of the 32 row program pointers of a strip
; tile (scripts/background_families.py packs the list).

        .include "second_sight.inc"

        .global combined_expand_family, family_staging

        .equ FAMILY_ROWS, 32            ; rows of a strip tile
        .equ REPEAT_SHIFT, 5            ; high byte bits 7-5: the repeat count - 1
        .equ REPEAT_MASK, 0xE0
        .equ PROGRAM_HIGH, 0x1F         ; high byte bits 4-0: the program offset in the window

; One row program pointer for each row of the tile. The list stays in one
; 256-byte page (aligned to its power-of-two size): combined_expand_family
; steps it with INC E.
        .section .vars.family_staging,"aw",@nobits
        .balign 2 * FAMILY_ROWS
family_staging: .ds.b 2 * FAMILY_ROWS

        .section .text.background_families,"ax",@progbits

; combined_expand_family: expand a packed family into family_staging.
; Each packed word: the low byte and bits 4-0 of the high byte give the row
; program offset in the WINDOW_C000 window; bits 7-5 give the rows that
; use it, minus one. The words end when the list is full.
; In: HL the packed family (mapped video RAM record). Out: HL after it.
; AF, BC, DE changed.
combined_expand_family:
        ld de,family_staging
family_word:
        ld c,(hl)                       ; the pointer low byte
        inc hl
        ld a,(hl)
        inc hl
        ld b,a
        and REPEAT_MASK
        .rept 8 - REPEAT_SHIFT
        rlca                            ; bits 7-5 to bits 2-0
        .endr
        inc a
        push hl
        ld l,a                          ; L rows use this program
        ld a,b
        and PROGRAM_HIGH
        or WINDOW_C000 >> 8
        ld h,a                          ; H the pointer high byte
family_repeat:
        ld a,c
        ld (de),a
        inc e
        ld a,h
        ld (de),a
        inc e
        dec l
        jp nz,family_repeat
        pop hl
        ld a,e
        cp (family_staging + 2 * FAMILY_ROWS) & 0xFF
        jp nz,family_word
        ret
