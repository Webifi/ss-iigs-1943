; Three shared alignments of the visible ship rows, indexed by world row.
; Each holds 256 rows x 32 groups for ships, or 128 x 64 for the short, wide
; plane bosses. Both display pages share the same prepared pixels.

        .global ship_alignment_row, ship_alignment_mask, ship_alignment_pitch
        .global ship_alignment_view, ship_alignment_segment

        .include "ship.inc"

        .equ AIRCRAFT_SECTIONS, 0xE0    ; foreground camera high byte of the boss sections

        .section .vars.ship_alignment,"aw",@nobits
ship_alignment_segment: .ds.b 1

        .section .text.ship_alignment,"ax",@progbits

; In: A phase 1-3, L world row. Out: HL group address, A Oak segment.
ship_alignment_row:
        push hl
        dec a
        ld e,a
        add a,a
        add a,e
        ld e,a
        ld d,0
        ld hl,ship_alignment_bases
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        ld (ship_alignment_segment),a
        pop hl
        push af
        ld a,l
ship_alignment_mask:
        and SHIP_ROW_MASK               ; patched by ship_alignment_view
        ld l,a
        pop af
ship_alignment_pitch:
        ld h,SHIP_PITCH                 ; patched by ship_alignment_view
        mlt hl
        add hl,de
        ret

        .section .text.ship_alignment_view,"ax",@progbits

; Set the alignment shape for the current view: ships, or the aircraft
; bosses at the top sections of the map.
ship_alignment_view:
        ld hl,(SHIP_ROW_MASK << 8) | SHIP_PITCH
        ld a,(scene_fg_camera+1)
        cp AIRCRAFT_SECTIONS
        jp c,selected
        ld hl,(AIRCRAFT_ROW_MASK << 8) | AIRCRAFT_PITCH
selected:
        ld a,h
        ld (ship_alignment_mask+1),a
        ld a,l
        ld (ship_alignment_pitch+1),a
        ld (ship_direct_clip_pitch+1),a
        dec a
        ld (ship_record_aux_mask+1),a
        inc a
        neg                             ; rows are read upward
        ld (ship_row_aux_pitch+1),a
        ld (ship_column_aux_pitch+1),a
        ld (ship_direct_aux_pitch+1),a
        ld (ship_negative_pitch+1),a
        ret
