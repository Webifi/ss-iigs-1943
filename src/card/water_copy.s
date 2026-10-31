; Display-pitch water rows: one DMA repairs a full-width group rectangle.

        .include "z180.inc"

        .global water_row_address, water_rectangle

        .equ VIEW_GROUPS, 56

        .section .text.water_copy,"ax",@progbits

; In: A prepared row index. Out: HL row address in the water pattern. BC kept.
water_row_address:
        ld l,a
        ld h,row_offset_low >> 8
        ld e,(hl)
        inc h
        ld h,(hl)
        ld l,e
        ld a,(water_pattern_base)
        add a,h
        ld h,a
        ret

; In: HL source, DE destination, B width, C height. A full-width rectangle is
; one DMA move; narrower ones go to ship_rectangle_positive.
water_rectangle:
        out0 (SAR0H),h
        ld a,b
        cp VIEW_GROUPS
        jp nz,ship_rectangle_positive
        push hl
        ld l,c
        ld h,row_offset_low >> 8        ; height x 56 is the byte count
        ld a,(hl)
        inc h
        ld h,(hl)
        ld l,a
        out0 (BCR0L),l
        out0 (BCR0H),h
        pop hl
        out0 (SAR0L),l
        out0 (DAR0L),e
        ld a,DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        out0 (DSTAT),a
        ld a,0
        out0 (BCR0H),a
        ret
