; Ship rows: copy prepared ship rows from the clean twin or an alignment.

        .include "video.inc"

        .global ship_linear_run, ship_linear_adjacent, ship_linear_copy
        .global ship_reuse_other_page, ship_reuse_address

        .equ VIEW_GROUPS, 56
        .equ ADJACENT, 0x80             ; run flag: source and destination follow the last run
        .equ AUXILIARY, 0x80            ; source flag: read the alignment, not the clean twin

        .section .text.ship_linear,"ax",@progbits

; One DMA per prepared run. In: HL run list, B runs, alternate BC free.
ship_linear_run:
        ld a,(hl)
        inc hl
        ld c,a
        and 0x0F                        ; planes
        exx
        ld bc,VGA_SEQ_DATA
        out (c),a
        exx
        bit 7,c
        jp nz,ship_linear_adjacent
        ld a,(hl)
        inc hl
        exx
        ld e,a
        ld d,0
        and AUXILIARY
        jp z,linear_clean
        res 7,e
        ld hl,(ship_fast_aux_base+1)
        ld a,(ship_alignment_segment)
        jp linear_source
linear_clean:
        ld hl,(ship_fast_clean_base+1)
        xor a                           ; display segment
linear_source:
        ld bc,OAK_DATA                  ; read segment (index still selected)
        out (c),a
        add hl,de
        ld a,l
        out0 (SAR0L),a
        ld a,h
        out0 (SAR0H),a
        exx
        ld a,(hl)                       ; destination group
        inc hl
        exx
        ld c,a
        ld a,(bg_first_column)
        ld b,a
        ld a,c
        sub b
        and 0x3F
        ld e,a
        ld d,0
        ld hl,(scroll_dest)
        add hl,de
        ld a,l
        out0 (DAR0L),a
        ld a,h
        out0 (DAR0H),a
        exx
        jp ship_linear_copy
ship_linear_adjacent:
        inc hl                          ; retained source
        inc hl                          ; retained destination
ship_linear_copy:
        ld a,(hl)
        inc hl
        out0 (BCR0L),a
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        dec b
        jp nz,ship_linear_run
        jp combined_ship_damage

        .section .text.ship_reuse,"ax",@progbits

; Copy the row from the other page when it holds the same clean row.
; Out: carry set when the row is ready.
ship_reuse_other_page:
        call ship_reuse_address
        ret nc
        xor a
        ld (scroll_segment),a
        ld (scroll_x),a
        ld a,VIEW_GROUPS
        ld (scroll_length),a
        ld a,0x0F
        ld (scroll_mask),a
        call combined_dma
        scf
        ret

; Out: carry set and scroll_src the clean row of the other page when it
; holds world row scroll_world_row with the same water family.
ship_reuse_address:
        ld a,(bg_moving_objects)
        or a
        jp nz,reuse_family
        ld a,(scroll_light_water)
        or a
        ret nz
reuse_family:
        ld a,(scroll_page_index)
        xor 1
        ld c,a
        add a,scroll_valid & 0xFF
        ld l,a
        ld h,scroll_valid >> 8
        ld a,(hl)
        or a
        ret z
        ld a,c
        add a,water_page_family & 0xFF
        ld l,a
        ld h,water_page_family >> 8
        ld b,(hl)
        ld a,(scroll_light_water)
        cp b
        jp nz,reuse_invalid
        ld a,c
        add a,a
        add a,scroll_cameras & 0xFF
        ld l,a
        ld h,scroll_cameras >> 8
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(scroll_world_row)
        or a
        sbc hl,de
        ld a,h
        or a
        ret nz
        call background_clean_address
        ld (scroll_src),hl
        scf
        ret
reuse_invalid:
        or a
        ret

; ---------------------------------------------------------------------------
; Ship rows: layout, seeds of the alignments, damage bounds and the fast copies.

        .global ship_row_layout, ship_layout_ready, ship_layout_copy, ship_row_seed, ship_seed_phase
        .global ship_seed_lane, ship_seed_unsigned, ship_seed_mask, ship_seed_piece, ship_seed_aux_base
        .global ship_seed_clean, ship_seed_clean_base, ship_seed_target, ship_seed_source_base, ship_cache_ready
        .global ship_cache_spill, ship_cache_column, ship_row_cached, ship_row_draw, ship_draw_record
        .global ship_draw_phase_offset, ship_draw_phase_ready, ship_draw_bases_ready, ship_damage_bounds, ship_draw_general
        .global ship_damage_right, ship_damage_both_edges, ship_damage_empty, ship_damage_ready, ship_fast_run
        .global ship_row_aux_pitch, ship_fast_aux_base, ship_fast_clean, ship_fast_clean_base, ship_fast_source_ready
        .global ship_fast_copy, ship_fast_crop, ship_fast_clip_right, ship_fast_one_piece, ship_fast_copy_ready
        .global ship_rectangle_dispatch, ship_cpu_min_height, ship_cpu_max_width, ship_cpu_dispatch, ship_rectangle_row
        .global ship_rectangle_negative, ship_source_step_low, ship_source_step_high, ship_rectangle_positive, ship_rectangle_source_same
        .global ship_height, ship_height_prepared, ship_height_ring, ship_height_ready

        .equ ALIGNMENT_PITCH, 32        ; groups per row of a ship alignment
        .equ WORLD_GROUPS, 64

        .section .text.ship_rows,"ax",@progbits

ship_row_layout:
        call combined_ready_row
        ld a,(hl)
        cp 0xFE                         ; cached ship or spill
        jp c,ship_layout_ready
        ld a,(scroll_world_row)
        ld l,a
        call combined_mask_root
        call combined_pointer
        ld de,35                        ; water offset
        add hl,de
ship_layout_ready:
        call combined_skip_water
        cp 0xFF                         ; aligned row
        ret nz
ship_layout_copy:
        inc hl
        ld de,ship_layout
        ld bc,2                         ; left and width
        ldir
        xor a
        ret
ship_row_seed:
        call ship_row_layout
        ret nz
        ld de,4                         ; seed pointer offset
        add hl,de
        call combined_pointer
        ld c,(hl)
        inc hl
        ld b,0
        ld de,family_staging                    ; seed staging
        ldir
        ld hl,(scroll_dest)
        ld (ship_clean_row),hl
        ld (ship_seed_clean_base+1),hl  ; clean seed base
        gc_set GC_MODE, 0x40
        oak_set OAK_READ_SEGMENT, 0
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        ld bc,VGA_GC_INDEX              ; read-map index
        ld a,4                          ; read map
        out (c),a
        ld bc,OAK_INDEX                 ; write-segment index
        ld a,0x24                       ; write segment
        out (c),a
        ld hl,family_staging                    ; first seed phase
        ld a,1                          ; phase one
        ld (ship_phase),a
ship_seed_phase:
        ld (ship_seed_pointer),hl
        ld a,(scroll_world_row)
        ld l,a
        ld a,(ship_phase)
        call ship_alignment_row
        ld (ship_seed_aux_base+1),hl    ; aux seed base
        xor a
        ld (ship_lane),a
ship_seed_lane:
        ld a,(ship_lane)
        ld b,a
        ld a,(ship_phase)
        add a,b                         ; lane
        ld e,a
        and 3                           ; read plane
        ld bc,VGA_GC_DATA               ; read map data
        out (c),a
        ld a,e
        and 4                           ; source carry
        rrca
        rrca
        ld b,a
        ld a,(ship_layout)
        add a,b                         ; source carry
        dec a
        ld e,a
        ld d,0
        bit 7,e                         ; negative offset
        jp z,ship_seed_unsigned
        dec d
ship_seed_unsigned:
        ld hl,(ship_clean_row)
        add hl,de
        ld (ship_seed_source_base+1),hl ; source seed base
        ld a,(ship_lane)
        ld b,a
        inc b
        xor a
        scf
ship_seed_mask:
        rla
        djnz ship_seed_mask             ; lane mask
        ld bc,VGA_SEQ_DATA              ; map mask
        out (c),a
        ld hl,(ship_seed_pointer)
        ld b,(hl)
        inc hl
ship_seed_piece:
        ld a,(hl)
        inc hl
        exx
        ld e,a
        ld d,0
        and 0x80                        ; auxiliary
        jp z,ship_seed_clean
        res 7,e                         ; auxiliary tag
ship_seed_aux_base:
        ld hl,0                         ; auxiliary row
        ld a,(ship_alignment_segment)
        jp ship_seed_target
ship_seed_clean:
ship_seed_clean_base:
        ld hl,0                         ; clean row
        xor a                           ; clean segment
ship_seed_target:
        ld bc,OAK_DATA                  ; write segment data
        out (c),a
        add hl,de
        ld a,l                          ; prepared destination
        out0 (DAR0L),a                  ; seed target
        ld a,h                          ; prepared destination
        out0 (DAR0H),a                  ; seed target
        exx
        ld a,(hl)
        inc hl
        exx
        ld e,a
        ld d,0
ship_seed_source_base:
        ld hl,0                         ; source row
        add hl,de
        ld a,l                          ; prepared source
        out0 (SAR0L),a                  ; seed source
        ld a,h                          ; prepared source
        out0 (SAR0H),a                  ; seed source
        exx
        ld a,(hl)
        inc hl
        out0 (BCR0L),a                  ; prepared length
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        dec b
        jp nz,ship_seed_piece
        ld (ship_seed_next),hl
        ld a,(ship_lane)
        inc a
        ld (ship_lane),a
        cp 4                            ; four planes
        jp nz,ship_seed_lane
        ld hl,(ship_seed_next)
        ld a,(ship_phase)
        inc a
        ld (ship_phase),a
        cp 4                            ; all phases
        jp nz,ship_seed_phase
        oak_set OAK_WRITE_SEGMENT, 0
        gc_set GC_READ_MAP, 0
        gc_set GC_MODE, 0x41
        ret
ship_cache_ready:
        inc hl
        ld de,ship_span_buffer+1                    ; layout staging
        ld bc,3                         ; layout size
        ldir
        ld a,(ship_span_buffer+3)
        bit 7,a                         ; column program
        jp nz,ship_cache_column
        call combined_pointer
        ld a,(hl)
        cp 0x3D                         ; cached record capacity
        jp nc,ship_cache_spill
        ld c,a
        ld b,0
        add a,4                         ; cache prefix
        ld (ship_ready_bytes),a
        ld a,0xFE                       ; ship cache marker
        ld (ship_span_buffer),a         ; (row staging) a
        ld de,ship_span_buffer+4                    ; ready ship data
        ldir
        ret
ship_cache_spill:
        ld a,1                          ; one byte
        ld (ship_ready_bytes),a
        ld a,0xFF                       ; spill marker
        ld (ship_span_buffer),a         ; (row staging) a
        ret
ship_cache_column:
        ld bc,3                         ; column directory pointer
        ldir
        ld a,7                          ; column header size
        ld (ship_ready_bytes),a
        ld a,0xFE                       ; cached marker
        ld (ship_span_buffer),a         ; (row staging) a
        ret
ship_row_cached:
        call ship_layout_copy
        call ship_height
        call background_ship_source
        jp ship_draw_record
ship_row_draw:
        call ship_layout_copy
        call ship_height
        call background_ship_source
        call combined_pointer
        ld c,(hl)
        ld b,0
        ld de,ship_span_buffer                    ; geometry staging
        ldir
        ld hl,ship_span_buffer                    ; geometry staging
        gc_set GC_READ_MAP, 0
ship_draw_record:
        push hl
        ld a,(bg_pan_phase)
        ld e,a
        ld d,0
        or a
        jp nz,ship_draw_phase_offset
        ld e,4                          ; first phase
        jp ship_draw_phase_ready
ship_draw_phase_offset:
        add hl,de
        ld e,(hl)
ship_draw_phase_ready:
        pop hl
        add hl,de
        ld a,(hl)
        ld (scroll_n),a
        inc hl
        push hl                         ; command stream
        ld hl,(bg_clean_base)
        ld (ship_fast_clean_base+1),hl  ; clean source base
        ld a,(bg_pan_phase)
        or a                            ; alignment phase
        jp z,ship_draw_bases_ready
        ld a,(scroll_world_row)
        ld l,a
        ld a,(bg_pan_phase)
        call ship_alignment_row
        ld (ship_fast_aux_base+1),hl    ; auxiliary source base
ship_draw_bases_ready:
        call ship_damage_bounds
        pop hl                          ; command stream
        ld a,(scroll_n)
        ld b,a
        ld a,(ship_linear_mode)
        or a
        jp nz,ship_linear_run
        jp ship_fast_run
ship_damage_bounds:
        xor a                           ; ordinary clipped path
        ld (ship_linear_mode),a
        ld a,(bg_first_column)
        ld b,a
        ld a,(ship_layout)
        add a,3                         ; shifted left edge
        sub b                           ; crop
        and 0x3F                        ; wrapped start
        ld e,a
        ld a,(ship_layout+1)
        inc a                           ; width
        add a,e                         ; start
        ld d,a
        cp 0x39                         ; interior end
        jp nc,ship_draw_general
        ld a,(ship_row_count)
        cp 1                            ; one row
        jp nz,ship_draw_general
        ld (ship_linear_mode),a
ship_draw_general:
        ld a,e
        cp VIEW_GROUPS                         ; right clipping
        jp c,ship_damage_right
        ld a,d
        sub WORLD_GROUPS                        ; wrapped row
        jp c,ship_damage_empty
        jp z,ship_damage_empty
        ld d,a
        ld e,0                          ; clipped left
        jp ship_damage_ready
ship_damage_right:
        ld a,d
        cp 0x41                         ; wrapped tail
        jp nc,ship_damage_both_edges
        cp 0x39                         ; viewport end
        jp c,ship_damage_ready
        ld d,VIEW_GROUPS                       ; right edge
        jp ship_damage_ready
ship_damage_both_edges:
        ld de,VIEW_GROUPS << 8                  ; whole conservative span
        jp ship_damage_ready
ship_damage_empty:
        ld de,VIEW_GROUPS                        ; empty span
ship_damage_ready:
        ld (ship_damage_span),de
        ret
ship_fast_run:
        ld a,(hl)
        inc hl
        and 0x0F                        ; plane mask
        exx
        ld bc,VGA_SEQ_DATA              ; map mask
        out (c),a
        exx
        ld a,(hl)
        inc hl
        exx
        ld e,a
        ld d,0
        and 0x80                        ; auxiliary flag
        jp z,ship_fast_clean
        res 7,e                         ; auxiliary flag
ship_row_aux_pitch:
        ld a,256 - ALIGNMENT_PITCH                ; negative auxiliary pitch
        ld (ship_source_step_low+1),a   ; source row low step
        ld a,0xFF                       ; negative pitch high
        ld (ship_source_step_high+1),a  ; source row high step
ship_fast_aux_base:
        ld hl,0                         ; auxiliary row
        ld a,(ship_alignment_segment)
        jp ship_fast_source_ready
ship_fast_clean:
        ld a,VIEW_GROUPS                       ; clean row pitch
        ld (ship_source_step_low+1),a   ; source row low step
        xor a
        ld (ship_source_step_high+1),a  ; source row high step
ship_fast_clean_base:
        ld hl,0                         ; clean row
        xor a                           ; display segment
ship_fast_source_ready:
        add hl,de
        ld bc,OAK_DATA                  ; read segment data
        out (c),a
        exx
        ld a,(hl)
        inc hl
        exx
        ld c,a
        exx
        ld a,(hl)
        inc hl
        exx
        ld b,a
        call ship_fast_copy
        exx
        dec b
        jp nz,ship_fast_run
        jp combined_ship_damage
ship_fast_copy:
        ld a,c
ship_fast_crop:
        sub 4                           ; crop
        and 0x3F                        ; wrap
        ld c,a
        cp VIEW_GROUPS                         ; viewport
        jp c,ship_fast_clip_right
        ld a,WORLD_GROUPS                       ; world width
        sub c                           ; left clipping
        ld e,a
        add hl,de
        ld a,b
        sub e                           ; clipped groups
        ret c
        ret z
        ld b,a
        ld c,0
ship_fast_clip_right:
        ld a,b
        add a,c                         ; start
        cp 0x41                         ; wrapped end
        jp c,ship_fast_one_piece
        push bc
        push hl
        ld a,VIEW_GROUPS                       ; right edge
        sub c                           ; start
        ld b,a
        call ship_fast_copy_ready
        pop hl
        pop bc
        ld a,WORLD_GROUPS                       ; world width
        sub c                           ; start
        ld e,a
        ld d,0
        add hl,de
        ld a,b
        sub e                           ; first section
        ld b,a
        ld c,0                          ; left edge
        jp ship_fast_copy_ready
ship_fast_one_piece:
        ld a,VIEW_GROUPS                       ; viewport
        sub c                           ; start
        cp b                            ; span length
        jp nc,ship_fast_copy_ready
        ld b,a
ship_fast_copy_ready:
        push hl
        ld hl,(scroll_dest)
        ld e,c
        ld d,0
        add hl,de
        ex de,hl
        pop hl
        ld a,(ship_row_count)
        ld c,a
ship_rectangle_dispatch:
        ld a,c                          ; height
ship_cpu_min_height:
        cp 4                            ; amortized mapping
        jp c,ship_rectangle_row
        ld a,b
ship_cpu_max_width:
        cp 3                            ; short latch span
ship_cpu_dispatch:
        jp c,ship_cpu_copy
ship_rectangle_row:
        out0 (SAR0H),h                  ; first source high
        out0 (DAR0H),d                  ; first target high
        ld a,(ship_source_step_high+1)  ; source pitch sign
        or a                            ; source sign
        jp z,ship_rectangle_positive
ship_rectangle_negative:
        out0 (SAR0H),h                  ; source high
        out0 (BCR0L),b                  ; width
        out0 (SAR0L),l                  ; source low
        out0 (DAR0L),e                  ; target low
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        dec c
        ret z
        ld a,l
ship_source_step_low:
        add a,256 - ALIGNMENT_PITCH               ; source pitch
        ld l,a
        ld a,h
ship_source_step_high:
        adc a,0xFF                      ; source carry
        ld h,a
        ld a,e
        add a,VIEW_GROUPS                      ; destination pitch
        ld e,a
        jp nc,ship_rectangle_negative
        inc d
        out0 (DAR0H),d                  ; changed target high
        jp ship_rectangle_negative
ship_rectangle_positive:
        out0 (BCR0L),b                  ; width
        out0 (SAR0L),l                  ; source low
        out0 (DAR0L),e                  ; target low
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        dec c
        ret z
        ld a,l
        add a,VIEW_GROUPS                      ; source pitch
        ld l,a
        jp nc,ship_rectangle_source_same
        inc h
        out0 (SAR0H),h                  ; changed source high
ship_rectangle_source_same:
        ld a,e
        add a,VIEW_GROUPS                      ; destination pitch
        ld e,a
        jp nc,ship_rectangle_positive
        inc d
        out0 (DAR0H),d                  ; changed target high
        jp ship_rectangle_positive
ship_height:
        ld a,(hl)
        bit 7,a                         ; complete column
        jp z,ship_height_prepared
        and 0x1F                        ; prepared subcolumn mask
        ld b,a
        ld a,(scroll_world_row)
        and b                           ; row within subcolumn
        inc a                           ; exclusive top
ship_height_prepared:
        ld b,a
        inc hl
        push hl
        ld a,(scroll_row)
        neg                             ; remaining visible rows
        jp z,ship_height_ring
        cp b                            ; prepared height
        jp nc,ship_height_ring
        ld b,a
ship_height_ring:
        ld a,(scene_ring_start)
        ld c,a
        ld a,(scroll_row)
        add a,c                         ; physical origin
        neg                             ; rows to twin boundary
        jp z,ship_height_ready
        cp b                            ; prepared height
        jp nc,ship_height_ready
        ld b,a
ship_height_ready:
        ld a,b
        ld (ship_row_count),a
        pop hl
        ret

        .global combined_new_full

        .section .text.ship_rows_tail,"ax",@progbits

; Cold entry in the unused tail of the ship code; ordinary rows stay in the
; scrolling loop.
combined_new_full:
        call background_prepare_view
        jp c,combined_repairs
        jp combined_new_row
