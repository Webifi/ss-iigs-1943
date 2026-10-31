; Combined rows: pan setup, prepared-data pointers, the coverage and
; ready-row cache of each new world row, and the world column descriptors.

        .include "video.inc"

        .global game_set_pan, combined_pan_masks, game_row_cache_clear, combined_coverage_begin
        .global combined_pointer, combined_cloud_root, combined_mask_root, combined_root
        .global game_mask_pair, game_mask_dispatch, game_coverage_row, combined_coverage_row_key
        .global combined_coverage_row_tag, combined_coverage_new_row, combined_cache_plain_ship
        .global combined_cache_ship_size, combined_coverage_spill, combined_coverage_cache
        .global combined_coverage_kind, combined_coverage_gap, combined_coverage_plane
        .global combined_coverage_column, combined_coverage_column_key
        .global combined_descriptor_select, combined_descriptor_prepare, combined_descriptor_side1
        .global combined_descriptor_low, combined_descriptor_high, combined_descriptor_side0
        .global combined_descriptor_prepared

        .equ BORDER, 16                 ; pan offset of the first visible pixel
        .equ VRAM_BBR, 0x94             ; BBR of video RAM group window 0 at $C000
        .equ VRAM_CBR, 0x92             ; CBR of video RAM group window 0 at $E000
        .equ GAME_CBR, 0x84
        .equ READY_ROW_CBR, 14          ; CBR of the ready-row commands of world row 0
        .equ COLUMN_MAP_BANK, 10        ; BBR of the world column map
        .equ SPAN_CAPACITY, 0x16        ; water spans a cached ready row can hold
        .equ ROW_CAPACITY, 0x41         ; bytes of a cached ready row, plus one
        .equ ALIGNED_ROW, 0xFF
        .equ SPILL, 0xFF
        .equ ROW_ROOTS, 99              ; the cloud root and 32 row roots of a column

; World column descriptors (in step with the world layout of the build).
        .equ SIDE1_LOW_DESCRIPTORS, 0xC400
        .equ SIDE1_HIGH_DESCRIPTORS, 0xC902
        .equ SIDE1_SPLIT, 0xFE          ; low byte of the first high-table column (high byte 1)
        .equ SIDE1_BANK, 15
        .equ SIDE0_DESCRIPTORS, 0xD800
        .equ SIDE0_BANK, 7

        .section .text.combined_rows_helpers,"ax",@progbits

; In: A pan. Sets the first visible column and the pan phase, and when the pan
; changed, the lane masks and crops of the pan and ship copies.
game_set_pan:
        push af
        add a,BORDER
        srl a
        srl a
        ld (bg_first_column),a
        ld (ship_fast_crop+1),a
        pop af
        and 3
        ld (bg_pan_phase),a
        ; Plane routing and coarse offsets change with the pan, not with each run.
        ld a,(bg_pan)
        ld b,a
        ld a,(scroll_pan_applied)
        cp b
        ret z
        ld a,b
        ld (scroll_pan_applied),a
        ld a,(bg_pan_phase)
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,combined_pan_masks
        add hl,de
        .irp plane, 0, 1, 2, 3
        ld a,(hl)
        inc hl
        ld (combined_pan_mask_\plane+1),a
        ld (combined_ship_mask_\plane+1),a
        ld a,(bg_pan_phase)
        cp \plane + 1                   ; this lane starts one group later
        ccf
        ld a,(bg_first_column)
        adc a,0
        ld (combined_pan_bias_\plane+1),a
        ld (combined_ship_bias_\plane+1),a
        .endr
        ret
; Per pan phase: the plane that each of the four lanes writes.
combined_pan_masks:
        .byte 1, 2, 4, 8
        .byte 8, 1, 2, 4
        .byte 4, 8, 1, 2
        .byte 2, 4, 8, 1
game_row_cache_clear:
        ret
; Uploads and drawing share the column staging area. Reuse is confined to
; one consecutive materialization pass, never across a region load.
combined_coverage_begin:
        ld hl,0xFFFF
        ld (combined_coverage_column_key+1),hl
        ld a,0xFF
        ld (combined_coverage_row_tag+1),a
        ret

; Map a prepared record. In: HL a 3-byte pointer: group address (2), then
; segment in bits 1-0 and plane in bits 3-2. Out: HL its CPU address.
combined_pointer:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        ld l,a
        and 3
        ld bc,OAK_INDEX
        ld h,a
        ld a,OAK_READ_SEGMENT
        out (c),a
        inc c
        out (c),h
        ld a,l
        rrca
        rrca
        and 3
        ld h,a
        ld bc,VGA_GC_INDEX
        ld a,GC_READ_MAP
        out (c),a
        inc c
        out (c),h
        ld a,d
        .rept 4
        rrca
        .endr
        and 0x0F
        add a,VRAM_BBR
        out0 (BBR),a
        ld a,d
        and 0x0F
        or 0xC0
        ld h,a
        ld l,e
        ret

; In: L world row. Out: HL the 3-byte root of its cloud column or mask row.
combined_cloud_root:
        .rept 5
        srl l
        .endr
        ld de,cloud_roots
        jp combined_root
combined_mask_root:
        ld de,mask_roots
combined_root:
        ld h,0
        ld c,l
        ld b,h
        add hl,hl
        add hl,bc
        add hl,de
        ret

        .section .text.combined_rows_coverage,"ax",@progbits

; Two mask bytes of a sprite row, wrapping within the 32-byte row.
game_mask_pair:
        ld c,(hl)
        ld a,l
        inc a
        xor l
        and 0x1F
        xor l
        ld l,a
game_mask_dispatch:
        jp sprite_mask_shift_0          ; patched: the mask shift

; Build the coverage and the cached ready row of world row rows_world_row.
game_coverage_row:
        phase_stamp phase_times+0x14
        call combined_coverage_column
        ld a,(rows_world_row)
        and 0x1F
        ld e,a
        add a,a
        add a,e
        add a,3                         ; the row roots follow the cloud root
        ld l,a
        ld h,world_upload_buffer >> 8   ; staged column roots
        ld de,row_roots+3
        ld bc,3
        ldir
        ld a,(rows_world_row)
        ld l,a
        call combined_mask_root
        ex de,hl
        ld hl,row_roots+3
        ld bc,3
        ldir
        ld hl,(row_roots+3)
combined_coverage_row_key:
        ld de,0xFFFF                    ; patched: previous row address
        or a
        sbc hl,de
        jp nz,combined_coverage_new_row
        ld a,(row_roots+5)
combined_coverage_row_tag:
        cp 0xFF                         ; patched: previous row plane and segment
        jp z,combined_coverage_cache
combined_coverage_new_row:
        ld hl,(row_roots+3)
        ld (combined_coverage_row_key+1),hl
        ld a,(row_roots+5)
        ld (combined_coverage_row_tag+1),a
        ld hl,row_roots+3
        call combined_pointer
        ld a,(hl)
        ld (combined_coverage_kind+1),a
        inc hl
        ld de,bg_coverage_buffer+64
        ld bc,32
        ldir
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ex de,hl
        ld (combined_coverage_gap+1),hl ; the exact water gap
        ex de,hl
        ld a,(hl)
        cp SPAN_CAPACITY
        jp nc,combined_coverage_spill
        push hl
        ld e,a
        add a,a
        add a,e
        inc a
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        cp ALIGNED_ROW
        jp nz,combined_cache_plain_ship
        pop bc                          ; discard the water pointer
        call ship_cache_ready
        jp combined_coverage_cache
combined_cache_plain_ship:
        and 0x7F                        ; ship bytes
combined_cache_ship_size:
        add a,e                         ; water bytes
        inc a
        pop hl
        cp ROW_CAPACITY
        jp nc,combined_coverage_spill
        ld (ship_ready_bytes),a
        ld c,a
        ld b,0
        ld de,ship_span_buffer
        ldir
        jp combined_coverage_cache
combined_coverage_spill:
        ld a,1
        ld (ship_ready_bytes),a
        ld a,SPILL
        ld (ship_span_buffer),a
combined_coverage_cache:
        ld c,0                          ; build mode
        call sea_occupancy_access
        ld a,(rows_world_row)
        ld l,a
        ld h,row_classes >> 8
combined_coverage_kind:
        ld d,0                          ; patched: the row kind
        ld (hl),d
combined_coverage_gap:
        ld de,0                         ; patched: the water gap
        ld h,water_left_bounds >> 8
        ld (hl),e
        inc h
        ld (hl),d
        gc_set GC_MODE, 0x40
        oak_set OAK_WRITE_SEGMENT, game_coverage__vseg
        ld a,(rows_world_row)
        and 0x3F
        ld l,a
        ld h,0
        .rept 5
        add hl,hl
        .endr
        ld de,game_coverage__group16
        add hl,de
        ld a,h
        .rept 4
        rrca
        .endr
        and 0x0F
        add a,VRAM_CBR
        out0 (CBR),a
        ld a,h
        and 0x0F
        or 0xE0
        ld d,a
        ld e,l
        ld a,(rows_world_row)
        rlca
        rlca
        and 3                           ; plane
        ld b,a
        inc b
        xor a
        scf
combined_coverage_plane:
        rla
        djnz combined_coverage_plane
        exx
        out (c),a
        exx
        ld hl,bg_coverage_buffer+64
        ld bc,32
        ldir
        ld a,(rows_world_row)
        ld b,a
        rlca
        rlca
        and 3
        add a,READY_ROW_CBR
        out0 (CBR),a
        ld a,b
        and 0x3F
        ld l,a
        ld h,0
        .rept 6
        add hl,hl
        .endr
        ld a,h
        or 0xE0
        ld d,a
        ld e,l
        ld hl,ship_span_buffer
        ld a,(ship_ready_bytes)
        ld c,a
        ld b,0
        ldir
        set_io CBR, GAME_CBR
        gc_set GC_MODE, 0x41
        gc_set GC_READ_MAP, 0
        oak_set OAK_WRITE_SEGMENT, 0
        phase_stamp phase_times+0x16
        ld hl,(phase_times+0x14)        ; add this row's time to the total
        ld de,(phase_times+0x16)
        or a
        sbc hl,de
        ld de,(phase_times+0x18)
        add hl,de
        ld (phase_times+0x18),hl
        ld a,(bg_pan)
        jp game_set_pan

        .section .text.combined_rows_column,"ax",@progbits

; Fetch a column's roots once for its consecutive incoming world rows.
combined_coverage_column:
        ld hl,(rows_world_row)
        ld a,l
        and 0xE0
        ld l,a
        push hl
combined_coverage_column_key:
        ld de,0xFFFF                    ; patched: previous column
        or a
        sbc hl,de
        pop hl
        ret z
        ld (combined_coverage_column_key+1),hl
        .rept 4
        srl h
        rr l
        .endr
        ld a,h
        or 0xC0
        ld h,a
        set_io BBR, COLUMN_MAP_BANK
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        add hl,hl
        add hl,hl
        call combined_descriptor_select
        call combined_pointer
        ld de,world_upload_buffer       ; column roots staging
        ld bc,ROW_ROOTS
        ldir
        ld a,(rows_world_row)
        ld l,a
        call combined_cloud_root
        ex de,hl
        ld hl,world_upload_buffer       ; the staged cloud root
        ld bc,3
        ldir
        ret

        .section .text.combined_descriptor_select,"ax",@progbits

; In: HL column index x 4. Out: HL the column descriptor, mapped through BBR.
combined_descriptor_select:
        ld (descriptor_pointer),hl
        ld hl,combined_descriptor_prepare
        call background_bank_call
        ld hl,(descriptor_pointer)
        ld a,(descriptor_bank)
        out0 (BBR),a
        ret

        .section .text.combined_descriptor_prepare,"ax",@progbits

; The region side is a property of each world address, boss aliases included.
combined_descriptor_prepare:
        ld hl,(descriptor_pointer)
        ld a,(rows_world_row+1)
        cp 0x80                         ; high sea
        jp c,combined_descriptor_side1
        cp 0xE0                         ; boss ranges
        jp c,combined_descriptor_side0
        cp 0xE8                         ; cabinet range
        jp c,combined_descriptor_side1
        cp 0xF0                         ; last boss
        jp c,combined_descriptor_side0
; The side 1 table stores three bytes per column in two SRAM fragments.
combined_descriptor_side1:
        srl h
        rr l
        ld b,h
        ld c,l
        srl h
        rr l
        add hl,bc
        ld a,h
        or a
        jp z,combined_descriptor_low
        cp 1
        jp nz,combined_descriptor_high
        ld a,l
        cp SIDE1_SPLIT
        jp nc,combined_descriptor_high
combined_descriptor_low:
        ld de,SIDE1_LOW_DESCRIPTORS
        add hl,de
        ld a,SIDE1_BANK
        jp combined_descriptor_prepared
combined_descriptor_high:
        ld de,SIDE1_HIGH_DESCRIPTORS
        add hl,de
        ld a,SIDE1_BANK
        jp combined_descriptor_prepared
combined_descriptor_side0:
        ld de,SIDE0_DESCRIPTORS
        add hl,de
        ld a,SIDE0_BANK
combined_descriptor_prepared:
        ld (descriptor_pointer),hl
        ld (descriptor_bank),a
        ret
