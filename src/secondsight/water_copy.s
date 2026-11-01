; Water pattern rows and rectangle copies. The water pattern has the
; display pitch (GROUPS_PER_ROW groups a row), so one DMA move repairs a
; rectangle of full rows.

        .include "video.inc"

        .global water_row_address, water_rectangle

        .section .text.water_copy,"ax",@progbits

; water_row_address: the CPU address of a row of the water pattern.
; In: A the pattern row. Out: HL the address (row_offset_low gives
; row x GROUPS_PER_ROW, water_pattern_base the high byte of the pattern).
; BC kept; A and DE changed.
water_row_address:
        ld l,a
        ld h,row_offset_low >> 8
        ld e,(hl)
        inc h                           ; the high bytes follow the low bytes
        ld h,(hl)
        ld l,e
        ld a,(water_pattern_base)
        add a,h
        ld h,a
        ret

; water_rectangle: copy a rectangle of the water pattern to the page.
; In: HL source, DE destination, B width in groups, C height in rows; the
; caller has set DAR0H. A rectangle of full rows is one DMA move of
; C x GROUPS_PER_ROW groups; a narrower one goes to ship_rectangle_positive
; (ship_rows.s), which moves one row at a time.
water_rectangle:
        out0 (SAR0H),h
        ld a,b
        cp GROUPS_PER_ROW
        jp nz,ship_rectangle_positive
        push hl
        ld l,c
        ld h,row_offset_low >> 8        ; height x GROUPS_PER_ROW: the group count
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
        out0 (DSTAT),a                  ; the burst stops the CPU until the move ends
        ld a,0
        out0 (BCR0H),a                  ; the other DMA commands set only BCR0L
        ret
