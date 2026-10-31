; Ship columns: draw the prepared rectangles of one 32-row map column of
; ship pixels. Each rectangle is copied from the clean twin or from a ship
; alignment. Short rectangles are copied by the CPU, the others by DMA.

        .include "video.inc"
        .include "ship.inc"

        .global ship_dispatch, ship_column_decoded, ship_column_finished
        .global ship_cpu_copy, ship_cpu_source_low, ship_cpu_source_high
        .global ship_column_map
        .global ship_column_choose, ship_column_direct, ship_column_new_record
        .global ship_direct_left_bound, ship_direct_wrap_bound
        .global ship_column_aux_pitch, ship_direct_aux_pitch, ship_direct_clip_pitch
        .global ship_record_aux_mask, ship_negative_pitch
        .global ship_cpu_column, ship_cpu_column_source, ship_cpu_column_target
        .global ship_cpu_positive, ship_cpu_negative
        .global ship_one_fast, ship_cpu_column_rows

        .equ AUXILIARY, 0x80            ; source flag: read the alignment, not the clean twin
        .equ COLUMN_ROWS, 32

        .section .vars.ship_columns,"aw",@nobits
ship_saved_dest: .ds.b 2                ; scroll_dest at the start of the column
ship_saved_row: .ds.b 1                 ; scroll_row at the start of the column
ship_clip_top: .ds.b 1                  ; visible rows: COLUMN_ROWS - row, exclusive top
ship_clip_bottom: .ds.b 1
ship_saved_rows: .ds.b 1                ; ship_row_count at the start of the column
ship_column_mapped: .ds.b 1             ; always 0: ship_cpu_copy restores its windows
ship_head_rows: .ds.b 1                 ; rows clipped above the rectangle

; Rectangle list of the column: count, then 8 bytes for each rectangle.
        .section .vars.ship_rectangles,"aw",@nobits
ship_rectangles: .ds.b 0x1A0

        .section .text.ship_column_draw,"ax",@progbits

; In: A column flags.
ship_dispatch:
        bit 4,a                         ; prepared column
        jp z,combined_ship_source
        call combined_ready_row
        ld a,(hl)
        cp 0xFE                         ; cached header
        jr z,header
        ld a,(scroll_world_row)
        ld l,a
        call combined_mask_root
        call combined_pointer
        ld de,35                        ; water offset
        add hl,de
        call combined_skip_water
header:
        call ship_layout_copy
        call ship_height
        call background_ship_source
        call combined_pointer
        ld a,(bg_pan_phase)
        ld e,a
        add a,a
        add a,e
        ld e,a
        ld d,0
        add hl,de
        call combined_pointer

; Copy the rectangle list from the geometry in video RAM to SRAM.
        push hl
        ld l,(hl)                       ; rectangle count
        ld h,0
        .rept 3
        add hl,hl
        .endr
        inc hl                          ; count byte
        out0 (BCR0L),l
        out0 (BCR0H),h
        pop hl
        ld a,l
        out0 (SAR0L),a
        in0 a,(BBR)
        add a,0x0C                      ; mapped aperture
        .rept 4
        rlca
        .endr
        and 0xF0
        ld d,a
        ld a,h
        and 0x0F
        or d
        out0 (SAR0H),a
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0L, ship_rectangles & 0xFF
        set_io DAR0H, ship_rectangles >> 8
        set_io DAR0B, ship_rectangles >> 16
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        set_io DAR0B, VGA_WINDOW >> 16  ; the rectangle copies write video RAM
        gc_set GC_READ_MAP, 0

        ld a,GROUPS_PER_ROW
        ld (ship_source_step_low+1),a
        xor a
        ld (ship_source_step_high+1),a
        in0 a,(BBR)
        push af
        in0 a,(CBR)
        push af
        call ship_column_map
        ld hl,(scroll_dest)
        ld (ship_saved_dest),hl
        ld a,(scroll_row)
        ld (ship_saved_row),a
        ld a,(ship_row_count)
        ld (ship_saved_rows),a
        ld b,a
        ld a,(scroll_world_row)
        and COLUMN_ROWS - 1
        inc a
        ld (ship_clip_top),a
        sub b
        ld (ship_clip_bottom),a
        ld a,(ship_saved_rows)
        cp COLUMN_ROWS
        ld hl,ship_column_clipped
        jr nz,path_ready
        ld hl,ship_column_complete
path_ready:
        ld (ship_column_clip_path+1),hl
; Zero-phase art starts at left+4, one group later than the conservative
; bound that the shifted phases need. Patch the direct selection and its
; wrap decision once for each column.
        ld a,(bg_pan_phase)
        cp 1
        ld a,3                          ; shifted left bias
        adc a,0                         ; zero phase: one more
        ld (ship_direct_left_bound+1),a
        ld (ship_direct_wrap_bound+1),a
        call ship_column_choose
        or a
        jp nz,ship_column_direct
        ld hl,ship_rectangles
        ld b,(hl)
        inc hl
        ld a,b
        or a
        jp z,ship_column_finished
ship_column_rectangle:
        jp ship_column_new_record

; In: D top, E bottom (exclusive) of the rectangle in column rows.
ship_column_decoded:
ship_column_clip_path:
        jp ship_column_clipped          ; patched: clipped or complete column
ship_column_clipped:
        ld a,(ship_clip_top)
        cp d
        jr nc,top
        ld d,a
top:
        ld a,(ship_clip_bottom)
        cp e
        jr c,bottom
        ld e,a
bottom:
        ld a,d
        sub e
        jr c,empty
        jr z,empty
        ld (ship_row_count),a
        ld a,(ship_clip_top)
        sub d
        ld (ship_head_rows),a
        jr offset_ready
ship_column_complete:
        ld a,d
        sub e
        ld (ship_row_count),a
        ld a,COLUMN_ROWS
        sub d
        ld (ship_head_rows),a
offset_ready:
        push bc                         ; width and x
        ld l,a
        ld h,row_offset_low >> 8
        ld e,(hl)
        inc h
        ld d,(hl)
        ld hl,(ship_saved_dest)
        add hl,de
        ld (scroll_dest),hl
; The source byte stays in the alternate C. No record or stack state is
; read again from RAM around the rectangle copy.
        exx
        ld a,c
        exx
        ld e,a
        ld d,0
        bit 7,e                         ; AUXILIARY
        jr z,clean
        res 7,e
        push de
        ld a,(ship_head_rows)
        ld b,a
        ld a,(scroll_world_row)
        sub b
        ld l,a
        ld a,(bg_pan_phase)
        call ship_alignment_row
        pop de
ship_column_aux_pitch:
        ld a,-SHIP_PITCH & 0xFF         ; patched by ship_alignment_view
        ld (ship_source_step_low+1),a
        ld a,0xFF                       ; alignment rows are read upward
        ld (ship_source_step_high+1),a
        ld a,(ship_alignment_segment)
        jr source
clean:
        push de
        ld de,(bg_clean_bias)
        add hl,de
        pop de
        ld a,(bg_pan_phase)
        or a
        jr z,clean_ready
        ld a,GROUPS_PER_ROW
        ld (ship_source_step_low+1),a
        xor a
        ld (ship_source_step_high+1),a
clean_ready:
        xor a                           ; clean twin segment
source:
        add hl,de
        ld bc,OAK_DATA                  ; read segment
        out (c),a
        pop bc
        call ship_fast_copy
empty:
        exx
        dec b
        jp nz,ship_column_rectangle
        exx
ship_column_finished:
        pop af
        out0 (CBR),a
        pop af
        out0 (BBR),a
        ld hl,ship_cpu_copy
        ld (ship_cpu_dispatch+1),hl
        ld a,4                          ; ordinary minimum height
        ld (ship_cpu_min_height+1),a
        ld a,3                          ; ordinary maximum width
        ld (ship_cpu_max_width+1),a
        ld hl,(ship_saved_dest)
        ld (scroll_dest),hl
        ld a,(ship_saved_row)
        ld (scroll_row),a
        ld a,(ship_saved_rows)
        ld (ship_row_count),a
        call ship_damage_bounds
        jp combined_ship_damage

        .section .text.ship_cpu_copy,"ax",@progbits

; Short rectangles: map the rectangle once, then copy its rows by CPU. A
; column is at most 32 rows, so both positive-pitch apertures stay inside
; 8 KB, and alignment rows stay inside their 1 KB column. The row loop
; changes no bank.
; In: HL source, DE target, B width, C rows.
ship_cpu_copy:
        xor a
        ld (ship_column_mapped),a
; Keep the caller mappings: the column geometry can come from video RAM,
; and the general row path can still hold banked source data.
        in0 a,(BBR)
        push af
        in0 a,(CBR)
        push af
        ld a,d
        .rept 4
        rrca
        .endr
        and 0x0F
        add a,0x92                      ; target CBR
        out0 (CBR),a
        ld a,d
        and 0x0F
        or 0xE0                         ; target aperture
        ld d,a
        ld a,h
        .rept 4
        rrca
        .endr
        and 0x0F
        add a,0x94                      ; source BBR
        out0 (BBR),a
        ld a,h
        and 0x0F
        or 0xC0                         ; source aperture
        ld h,a
        ld a,(ship_source_step_low+1)
        ld (ship_cpu_source_low+1),a
        ld a,(ship_source_step_high+1)
        ld (ship_cpu_source_high+1),a
        ld a,c
        ex af,af'                       ; A' rows
        ld a,(ship_cpu_source_low+1)
        sub b
        ld (ship_cpu_row_source+1),a
        ld a,GROUPS_PER_ROW
        sub b
        ld (ship_cpu_row_target+1),a
        ld a,b
        .irp width,1,2,3,4
        ld ix,ship_cpu_\width
        cp \width
        jp z,selected
        .endr
        ld ix,ship_cpu_5
selected:
        jp (ix)
        .irp width,1,2,3,4,5
ship_cpu_\width:
        .rept \width
        ldi
        .endr
        jp next
        .endr
next:
        ex af,af'
        dec a
        jp z,done
        ex af,af'
        ld a,l
ship_cpu_row_source:
        add a,GROUPS_PER_ROW            ; patched: source pitch - width
        ld l,a
        ld a,h
ship_cpu_source_high:
        adc a,0                         ; patched: source pitch high byte
        ld h,a
        ld a,e
ship_cpu_row_target:
        add a,GROUPS_PER_ROW            ; patched: GROUPS_PER_ROW - width
        ld e,a
        ld a,d
        adc a,0
        ld d,a
        jp (ix)
; The source pitch is the second byte, in the place of an operand.
ship_cpu_source_low:
        .byte 0, GROUPS_PER_ROW
done:
        ld a,(ship_column_mapped)
        or a
        ret nz
        pop af
        out0 (CBR),a
        pop af
        out0 (BBR),a
        ret

        .section .text.ship_column_map,"ax",@progbits

; Map the column target and source once for the whole column, and send
; the short rectangles to ship_cpu_column.
ship_column_map:
        ld hl,(scroll_dest)
        ld a,h
        .rept 4
        rrca
        .endr
        and 0x0F
        add a,0x92                      ; target CBR
        out0 (CBR),a
        ld a,h
        and 0xF0
        ld b,a
        ld a,0xE0                       ; target aperture high
        sub b
        ld (ship_cpu_column_target+1),a
        ld a,(bg_pan_phase)
        or a
        jp z,map_clean
        ld a,(scroll_world_row)
        ld l,a
        ld a,(bg_pan_phase)
        call ship_alignment_row
        jp map_source
map_clean:
        ld hl,(bg_clean_base)
map_source:
        ld a,h
        .rept 4
        rrca
        .endr
        and 0x0F
        add a,0x94                      ; source BBR
        out0 (BBR),a
        ld a,h
        and 0xF0
        ld b,a
        ld a,0xC0                       ; source aperture high
        sub b
        ld (ship_cpu_column_source+1),a
        ld a,GROUPS_PER_ROW
        ld (ship_cpu_source_low+1),a
        xor a
        ld (ship_cpu_source_high+1),a
        ld (ship_cpu_min_height+1),a
        ld a,6                          ; maximum short width
        ld (ship_cpu_max_width+1),a
        ld hl,ship_cpu_column
        ld (ship_cpu_dispatch+1),hl
        ld hl,ship_cpu_positive
        ld a,(bg_pan_phase)
        or a
        jp z,rows_ready
        ld hl,ship_cpu_negative
rows_ready:
        ld (ship_cpu_column_rows+1),hl
        ret

        .section .text.ship_column_direct,"ax",@progbits

; Complete columns use ready addresses; only the edge columns decode the
; clipping. Every source alignment uses ready addresses, also at the
; edges of the view.
; Out: A 1 for the direct path, 0 for the ordinary path.
ship_column_choose:
        ld a,(bg_first_column)
        ld b,a
        ld a,(ship_layout)
ship_direct_left_bound:
        add a,3                         ; patched: maximum shifted left
        sub b
        and 0x3F
        ld b,a
        ld a,(ship_layout + 1)
        inc a
        add a,b
        cp GROUPS_PER_ROW + 1
        jp nc,not_direct
        ld a,(ship_clip_top)
        ld b,a
        ld a,COLUMN_ROWS
        sub b                           ; first visible row
        ld (ship_direct_clip_top+1),a
        ld (ship_direct_head_delta+1),a
        ld l,a
        ld h,row_offset_low >> 8
        ld e,(hl)
        inc h
        ld d,(hl)
        ld b,a
        ld a,(ship_saved_rows)
        add a,b                         ; end of the visible rows
        ld (ship_direct_clip_bottom+1),a
        ld (ship_direct_tail_test+1),a
        ld (ship_direct_tail_trim+1),a
        ld hl,(ship_saved_dest)
        or a
        sbc hl,de
        ld (ship_direct_origin+1),hl
        ld a,(ship_saved_rows)
        cp COLUMN_ROWS
        ld hl,ship_column_direct_peek
        ld de,ship_column_direct_clip
        jp nz,handlers
        ld hl,ship_column_direct_loop
        ld de,ship_column_direct_copy
handlers:
        ld (ship_column_next_record+1),hl
        ex de,hl
        ld (ship_column_direct_clip_path+1),hl
ship_direct_origin:
        ld hl,0                         ; patched: column origin
        ld de,(bg_clean_bias)
        add hl,de
        ld (ship_column_source_base+1),hl
; The world is 64 groups wide. A wrapped ship that is fully visible needs
; the same +64 as the general horizontal clipper, once for the column.
        ld a,(bg_first_column)
        ld b,a
        ld a,(ship_layout)
ship_direct_wrap_bound:
        add a,3                         ; patched: conservative source left
        sub b
        ld a,b                          ; keep the flags
        jp nc,no_wrap
        sub 0x40
no_wrap:
        ld e,a
        ld d,0
        bit 7,e
        jp z,crop_ready
        dec d
crop_ready:
        ld hl,(ship_direct_origin+1)
        or a
        sbc hl,de
        ld (ship_column_target_base+1),hl
        ld a,(bg_pan_phase)
        or a
        jp z,direct_clean
        ld a,(scroll_world_row)
        and 0x100 - COLUMN_ROWS         ; first row of the column
        ld l,a
        ld a,(bg_pan_phase)
        call ship_alignment_row
        ld (ship_column_source_base+1),hl
ship_direct_aux_pitch:
        ld a,-SHIP_PITCH & 0xFF         ; patched by ship_alignment_view
        ld (ship_source_step_low+1),a
        ld a,0xFF
        ld (ship_source_step_high+1),a
        ld a,(ship_alignment_segment)
        jp source_chosen
direct_clean:
        xor a                           ; clean twin segment
source_chosen:
        ld bc,OAK_DATA                  ; read segment
        out (c),a
        ld a,1
        ret
not_direct:
        xor a
        ret

; Decode one record for the ordinary path. The alternate set holds the
; record cursor and count. The main set keeps the width, x and the
; top and bottom for the clipper.
; In: HL record. Out: alternate C source x, D top, E bottom.
ship_column_new_record:
        ld c,(hl)                       ; source low
        inc hl
        inc hl
        ld a,(hl)                       ; target low
        inc hl
        inc hl
        exx
        ld c,a
        exx
        ld a,(hl)                       ; height
        inc hl
        exx
        ld e,a
        exx
        ld a,(hl)                       ; width
        inc hl
        exx
        ld b,a
        exx
        ld a,(hl)                       ; screen top
        inc hl
        exx
        ld d,a
        exx
        ld a,(hl)                       ; plane mask and source kind
        inc hl
        push af
        exx
        push bc
        ld bc,VGA_SEQ_DATA              ; map mask
        out (c),a
        pop bc
        ld l,d
        ld h,row_offset_low >> 8
        ld a,c
        sub (hl)
        ld c,a                          ; world x
        ld a,(hl)
        exx
        ld e,a
        pop af
        or a
        jp m,record_auxiliary
        ld a,c
        sub e
        jp record_source_ready
record_auxiliary:
        ld a,c
ship_record_aux_mask:
        and SHIP_PITCH - 1              ; patched by ship_alignment_view
        or AUXILIARY
record_source_ready:
        ld c,a                          ; source x
        exx
        ld a,COLUMN_ROWS
        sub d
        ld d,a                          ; top
        sub e
        ld e,a                          ; bottom
        jp ship_column_decoded

; Direct path: pop the records from the list with SP.
ship_column_direct:
        ld (ship_column_stack+1),sp
        ld hl,ship_rectangles
        ld b,(hl)
        inc hl
        ld a,b
        or a
        jp z,ship_column_finished
        ld sp,hl
        exx
ship_column_next_record:
        jp ship_column_direct_loop      ; patched: peek or loop
ship_column_direct_peek:
        ld hl,6                         ; start row of the next record
        add hl,sp
        ld a,(hl)
        ex af,af'
ship_column_direct_loop:
        pop hl                          ; source offset
        pop de                          ; target offset
        pop bc                          ; height and width
        pop af                          ; plane mask
        push bc
        ld bc,VGA_SEQ_DATA              ; map mask
        out (c),a
ship_column_source_base:
        ld bc,0                         ; patched
        add hl,bc
        ex de,hl
ship_column_target_base:
        ld bc,0                         ; patched
        add hl,bc
        ex de,hl
        pop bc
ship_column_direct_clip_path:
        jp ship_column_direct_copy      ; patched: copy or clip
ship_column_direct_copy:
        call ship_rectangle_dispatch
direct_next:
        exx
        dec b
        exx
        jp nz,ship_column_next_record
ship_column_stack:
        ld sp,0                         ; patched: caller stack
        jp ship_column_finished

; Clip the rectangle to the visible rows. In: A' start row, C height.
ship_column_direct_clip:
        ex af,af'
ship_direct_clip_bottom:
        cp COLUMN_ROWS                  ; patched: end of the visible rows
        jp nc,direct_next
        push af
        add a,c
ship_direct_tail_test:
        cp COLUMN_ROWS                  ; patched: end of the visible rows
        jp c,tail_ready
ship_direct_tail_trim:
        sub COLUMN_ROWS                 ; patched: end of the visible rows
        neg
        add a,c
        ld c,a
tail_ready:
        pop af
ship_direct_clip_top:
        cp 0                            ; patched: first visible row
        jp nc,ship_column_direct_copy
        neg
ship_direct_head_delta:
        add a,0                         ; patched: first visible row
        cp c
        jp nc,direct_next
        ld (ship_head_rows),a
        neg
        add a,c
        ld c,a
        push bc
        push de
        push hl
        ld a,(ship_head_rows)
        ld l,a
        ld h,row_offset_low >> 8
        ld e,(hl)
        inc h
        ld d,(hl)
        pop hl
        ld a,(ship_source_step_high+1)
        or a
        jp z,head_positive
; Alignment pixels go down 32 groups for each world row. DE keeps the
; target step of GROUPS_PER_ROW for each row.
        ld a,(ship_head_rows)
        ld c,a
ship_direct_clip_pitch:
        ld b,SHIP_PITCH                 ; patched by ship_alignment_view
        mlt bc
        or a
        sbc hl,bc
        jp head_ready
head_positive:
        add hl,de
head_ready:
        pop bc
        ex de,hl
        add hl,bc
        ex de,hl
        pop bc
        jp ship_column_direct_copy

        .section .text.ship_cpu_column,"ax",@progbits

; Short rectangles of a mapped column. In: HL source, DE target, B width,
; C rows.
ship_cpu_column:
        ld a,h
ship_cpu_column_source:
        add a,0                         ; patched: source aperture bias
        ld h,a
        ld a,d
ship_cpu_column_target:
        add a,0                         ; patched: target aperture bias
        ld d,a
        jp ship_one_fast
; Unused. The row loops below keep their earlier addresses.
        .fill 5, 1, 0

; Positive-pitch columns are the usual case. A short compare chain enters
; the unrolled loops, so no jump target is patched for each rectangle.
ship_cpu_positive:
        ld a,c
        ex af,af'                       ; A' rows
        ld a,b
        .irp width,1,2,3,4
        cp \width
        jp z,positive_\width
        .endr
        .irp width,5,1,2,3,4
positive_\width:
        .rept \width
        ldi
        .endr
        ex af,af'
        dec a
        jp z,ship_cpu_column_return
        ex af,af'
        ld bc,GROUPS_PER_ROW - \width
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        jp positive_\width
        .endr
ship_cpu_column_return:
        ret                             ; the caller keeps the mappings

; Alignment rows go upward. The alignment column fits one 4 KB aperture,
; the same as the clean twin, so the caller maps both windows once.
ship_cpu_negative:
        ld a,c
        ex af,af'                       ; A' rows
ship_negative_pitch:
        ld a,-SHIP_PITCH & 0xFF         ; patched by ship_alignment_view
        sub b
        ld (negative_source_step+1),a
        ld a,GROUPS_PER_ROW
        sub b
        ld (negative_target_step+1),a
; Five LDI instructions in a line. The width selects the first one, and
; the loop jump keeps that entry for every row of the rectangle.
        ld a,5
        sub b
        add a,a
        ld c,a
        ld b,0
        push hl
        ld hl,negative_5
        add hl,bc
        ld (negative_again+1),hl
        pop hl
        jp negative_again
negative_5:
        .rept 5
        ldi
        .endr
        ex af,af'
        dec a
        jp z,ship_cpu_column_return
        ex af,af'
negative_source_step:
        ld bc,-SHIP_PITCH & 0xFFFF      ; patched: low byte pitch - width
        add hl,bc
        ex de,hl
negative_target_step:
        ld bc,GROUPS_PER_ROW            ; patched: low byte GROUPS_PER_ROW - width
        add hl,bc
        ex de,hl
negative_again:
        jp negative_5                   ; patched: entry for the width

        .section .text.ship_one_fast,"ax",@progbits

; The frequent one-group ship edge, in the mapped windows.
; In: HL source, DE target, B width, C rows.
ship_one_fast:
        ld a,b
        dec a
        jp nz,ship_cpu_column_rows
        ld a,c
        dec a
        jp nz,one_multi
        ldi
        ret
one_multi:
        ld a,(bg_pan_phase)
        or a
        jp z,ship_cpu_column_rows
        ld a,(ship_negative_pitch+1)
        dec a
        ld (one_negative_step+1),a
        ld a,c
one_negative_row:
        ldi
        dec a
        ret z
one_negative_step:
        ld bc,(-SHIP_PITCH - 1) & 0xFFFF ; patched: low byte -pitch - 1
        add hl,bc
        ex de,hl
        ld bc,GROUPS_PER_ROW - 1
        add hl,bc
        ex de,hl
        jp one_negative_row
ship_cpu_column_rows:
        jp ship_cpu_positive            ; patched: positive or negative rows
