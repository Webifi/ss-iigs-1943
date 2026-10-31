; Water row families: a packed list of (pointer, repeat count) words expands
; into the 64-byte staging list of row program pointers.

        .global combined_expand_family

        .equ PROGRAM_PAGE, 0xC0         ; row programs live in the $C000 window
        .equ STAGING_END, 0xA0          ; low byte after the 64-byte staging list

        .section .text.background_families,"ax",@progbits

; In: HL mapped VRAM record.
combined_expand_family:
        ld de,family_staging
family_word:
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld b,a
        and 0xE0                        ; repeat count - 1 in bits 7-5
        rlca
        rlca
        rlca
        inc a
        push hl
        ld l,a
        ld a,b
        and 0x1F
        or PROGRAM_PAGE
        ld h,a
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
        cp STAGING_END
        jp nz,family_word
        ret
