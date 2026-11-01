; Combined rows: pan setup, prepared-data pointers, the coverage and
; ready-row cache of each new world row, and the world column descriptors.

        .include "video.inc"
        .include "rows.inc"
        .include "ready.inc"

        .global game_set_pan, combined_pan_masks, combined_coverage_begin
        .global combined_pointer, combined_cloud_root, combined_mask_root, combined_root
        .global game_mask_pair, game_mask_dispatch, game_coverage_row, combined_coverage_row_key
        .global combined_coverage_row_tag, combined_coverage_new_row, combined_cache_plain_ship
        .global combined_cache_ship_size, combined_coverage_spill, combined_coverage_cache
        .global combined_coverage_kind, combined_coverage_gap, combined_coverage_plane
        .global combined_coverage_column, combined_coverage_column_key
        .global combined_descriptor_select, combined_descriptor_prepare, combined_descriptor_side1
        .global combined_descriptor_low, combined_descriptor_high, combined_descriptor_side0
        .global combined_descriptor_prepared

        .global rows_world_row, descriptor_pointer, descriptor_bank
        .global bg_coverage_row, scroll_pan_applied, bg_pan, bg_first_column, bg_pan_phase

        .equ BORDER, 16                 ; pan offset of the first visible pixel
        .equ VRAM_BBR, VGA_WINDOW_C000  ; BBR of video RAM group window 0 at WINDOW_C000
        .equ ROOT_BYTES, 3              ; a root: group address, segment and plane
        .equ ROW_ROOTS, ROOT_BYTES * (1 + COLUMN_ROWS) ; the cloud root and the row roots of a column
        .equ POINTER_PLANE_SHIFT, 2     ; combined_pointer: the read plane in bits 3-2
; The world regions (rows_world_row high byte): side 0 or side 1 descriptors.
        .equ HIGH_SEA, 0x80             ; from here side 0, below side 1
        .equ BOSS_RANGES, 0xE0          ; side 1 from here
        .equ CABINET_RANGE, 0xE8        ; side 0 from here
        .equ LAST_BOSS, 0xF0            ; side 1 from here
; The side 1 descriptors: two fragments (secondsight.ld .world_side1_low
; and -high); the first holds SIDE1_LOW_BYTES (scripts/world_stream.py).
        .equ SIDE1_LOW_BYTES, 510

; The world row of the planner (secondsight.ld .planner_variables).
        .section .vars.rows_world_row,"aw",@nobits
rows_world_row: .ds.b 2                 ; the world row that game_coverage_row prepares
; The pan and the current row (secondsight.ld .row_variables).
        .section .vars.combined_rows,"aw",@nobits
bg_pan: .ds.b 1                         ; the camera cross of the packet: the pan
bg_first_column: .ds.b 1                ; the first visible group of the pan
bg_pan_phase: .ds.b 1                   ; the pan within a group (0-3)
current_row_root: .ds.b ROOT_BYTES      ; the root of the current row
descriptor_pointer: .ds.b 2             ; combined_descriptor_select: the descriptor
descriptor_bank: .ds.b 1                ; and its BBR
bg_coverage_row: .ds.b COVERAGE_BYTES   ; the coverage nibbles of the current row
; The roots of the rows (game_coverage_row) and of the columns
; (combined_coverage_column) that the card prepared: ROOT_BYTES each.
        .global mask_roots, cloud_roots
        .section .vars.mask_roots,"aw",@nobits
mask_roots: .ds.b ROOT_BYTES * PAGE_ROWS ; for each ring row
        .section .vars.cloud_roots,"aw",@nobits
cloud_roots: .ds.b ROOT_BYTES * (PAGE_ROWS / COLUMN_ROWS) ; for each column of the ring

; The row class of each ring row (rows.inc). The code indexes it with L.
        .global row_classes, water_left_bounds, water_right_bounds
        .section .vars.row_classes,"aw",@nobits
        .balign 256
row_classes: .ds.b PAGE_ROWS
; The water gap of each ring row: the first open group, then (one page on)
; the group after the last open group.
        .section .vars.water_bounds,"aw",@nobits
        .balign 256
water_left_bounds: .ds.b PAGE_ROWS
water_right_bounds: .ds.b PAGE_ROWS
        .section .data.scroll_pan_applied,"aw",@progbits
scroll_pan_applied: .byte 0xFF          ; the pan of the masks and crops; 0xFF: none yet

        .section .text.combined_rows_helpers,"ax",@progbits

; game_set_pan: In: A pan. Sets the first visible column and the pan phase,
; and when the pan changed, the lane masks and crops of the pan and ship
; copies. AF, B, HL, DE changed.
game_set_pan:
        push af
        add a,BORDER
        srl a
        srl a
        ld (bg_first_column),a
        ld (ship_fast_crop+1),a
        pop af
        and 3                           ; four pixels a group
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
; combined_pan_masks: per pan phase, the plane that each of the four lanes
; writes.
combined_pan_masks:
        .byte 1, 2, 4, 8
        .byte 8, 1, 2, 4
        .byte 4, 8, 1, 2
        .byte 2, 4, 8, 1
; combined_coverage_begin: forget the cached column and row (a plan list
; command). Uploads and drawing share the column staging area. Reuse is
; confined to one consecutive materialization pass, never across a region
; load. AF, HL changed.
combined_coverage_begin:
        ld hl,0xFFFF
        ld (combined_coverage_column_key+1),hl
        ld a,0xFF
        ld (combined_coverage_row_tag+1),a
        ret

; combined_pointer: map a prepared record. In: HL a 3-byte pointer: group
; address (2), then segment in bits 1-0 and plane in bits 3-2. Out: HL its
; CPU address in the WINDOW_C000 window. AF, BC, DE changed.
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
        or WINDOW_C000 >> 8
        ld h,a
        ld l,e
        ret

; combined_cloud_root: In: L world row. Out: HL the 3-byte root of its
; cloud column (cloud_roots: one for each 32-row column).
; combined_mask_root: the same for its mask row (mask_roots: one each row).
; combined_root: HL = DE + 3 x L. BC changed.
combined_cloud_root:
        .rept 5
        srl l                           ; / COLUMN_ROWS
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

; game_mask_pair: two mask bytes of a sprite row, wrapping within the
; 32-byte row; game_mask_dispatch jumps to the patched mask shift.
game_mask_pair:
        ld c,(hl)
        ld a,l
        inc a
        xor l
        and 0x1F                        ; keep the row bits of L
        xor l
        ld l,a
game_mask_dispatch:
        jp sprite_mask_shift_0          ; patched: the mask shift

; game_coverage_row: build the coverage, the row class, the water bounds,
; the occupancy and the cached ready row of world row rows_world_row, from
; its row record (the root of the column, staged at world_upload_buffer).
; AF, BC, DE, HL changed.
game_coverage_row:
        call combined_coverage_column
        ld a,(rows_world_row)
        and COLUMN_ROWS - 1
        ld e,a
        add a,a
        add a,e
        add a,ROOT_BYTES                ; the row roots follow the cloud root
        ld l,a
        ld h,world_upload_buffer >> 8   ; staged column roots
        ld de,current_row_root
        ld bc,ROOT_BYTES
        ldir
        ld a,(rows_world_row)
        ld l,a
        call combined_mask_root
        ex de,hl
        ld hl,current_row_root
        ld bc,ROOT_BYTES
        ldir
        ld hl,(current_row_root)
combined_coverage_row_key:
        ld de,0xFFFF                    ; patched: previous row address
        or a
        sbc hl,de
        jp nz,combined_coverage_new_row
        ld a,(current_row_root+2)
combined_coverage_row_tag:
        cp 0xFF                         ; patched: previous row plane and segment
        jp z,combined_coverage_cache
; The row record (ready.inc).
combined_coverage_new_row:
        ld hl,(current_row_root)
        ld (combined_coverage_row_key+1),hl
        ld a,(current_row_root+2)
        ld (combined_coverage_row_tag+1),a
        ld hl,current_row_root
        call combined_pointer
        ld a,(hl)
        ld (combined_coverage_kind+1),a
        inc hl
        ld de,bg_coverage_row
        ld bc,COVERAGE_BYTES
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
        cp SHIP_ALIGNED
        jp nz,combined_cache_plain_ship
        pop bc                          ; discard the water pointer
        call ship_cache_ready
        jp combined_coverage_cache
combined_cache_plain_ship:
        and SHIP_BYTES
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
        ld a,READY_SPILL
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
        gc_set GC_MODE, GC_MODE_256
        oak_set OAK_WRITE_SEGMENT, game_coverage__vseg
; game_coverage: the coverage of world row R in plane R / 64, at group
; (R mod 64) x COVERAGE_BYTES.
        ld a,(rows_world_row)
        and 0x3F
        ld l,a
        ld h,0
        .rept 5
        add hl,hl                       ; x COVERAGE_BYTES
        .endr
        ld de,game_coverage__group16
        add hl,de
        ld a,h
        .rept 4
        rrca
        .endr
        and 0x0F
        add a,VGA_WINDOW_E000
        out0 (CBR),a
        ld a,h
        and 0x0F
        or WINDOW_E000 >> 8
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
        ld hl,bg_coverage_row
        ld bc,COVERAGE_BYTES
        ldir
; The ready row: 64 rows of READY_ROW_BYTES in each 4 KB page.
        ld a,(rows_world_row)
        ld b,a
        rlca
        rlca
        and 3
        add a,ready_rows__cbr
        out0 (CBR),a
        ld a,b
        and 0x3F
        ld l,a
        ld h,0
        .rept 6
        add hl,hl                       ; x READY_ROW_BYTES
        .endr
        ld a,h
        or WINDOW_E000 >> 8
        ld d,a
        ld e,l
        ld hl,ship_span_buffer
        ld a,(ship_ready_bytes)
        ld c,a
        ld b,0
        ldir
        set_io CBR, game_cbr
        gc_set GC_MODE, GC_MODE_256 | 1
        gc_set GC_READ_MAP, 0
        oak_set OAK_WRITE_SEGMENT, 0
        ld a,(bg_pan)
        jp game_set_pan

        .section .text.combined_rows_column,"ax",@progbits

; combined_coverage_column: fetch a column's roots once for its
; consecutive incoming world rows: the column map gives the column of the
; world row, the descriptor its roots, staged at world_upload_buffer.
; AF, BC, DE, HL changed.
combined_coverage_column:
        ld hl,(rows_world_row)
        ld a,l
        and ~(COLUMN_ROWS - 1) & 0xFF   ; the first row of the column
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
        srl h                           ; / COLUMN_ROWS x 2: the map entry
        rr l
        .endr
        ld a,h
        or WINDOW_C000 >> 8             ; world_column_map starts a 4 KB page
        ld h,a
        set_io BBR, world_column_map__bbr
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
        ld bc,ROOT_BYTES
        ldir
        ret

        .section .text.combined_descriptor_select,"ax",@progbits

; combined_descriptor_select: In: HL column index x 4. Out: HL the column
; descriptor, mapped through BBR. The banked combined_descriptor_prepare
; picks the table. AF changed.
combined_descriptor_select:
        ld (descriptor_pointer),hl
        ld hl,combined_descriptor_prepare
        call background_bank_call
        ld hl,(descriptor_pointer)
        ld a,(descriptor_bank)
        out0 (BBR),a
        ret

        .section .text.combined_descriptor_prepare,"ax",@progbits

; combined_descriptor_prepare: the region side is a property of each world
; address, boss aliases included (scripts/world_stream.py checks the same
; ranges). Out: descriptor_pointer, descriptor_bank. AF, BC, DE, HL changed.
combined_descriptor_prepare:
        ld hl,(descriptor_pointer)
        ld a,(rows_world_row+1)
        cp HIGH_SEA
        jp c,combined_descriptor_side1
        cp BOSS_RANGES
        jp c,combined_descriptor_side0
        cp CABINET_RANGE
        jp c,combined_descriptor_side1
        cp LAST_BOSS
        jp c,combined_descriptor_side0
; The side 1 table stores three bytes per column in two SRAM fragments.
combined_descriptor_side1:
        srl h
        rr l
        ld b,h
        ld c,l
        srl h
        rr l
        add hl,bc                       ; HL the column x 3
        ld a,h
        or a
        jp z,combined_descriptor_low
        cp SIDE1_LOW_BYTES >> 8
        jp nz,combined_descriptor_high
        ld a,l
        cp SIDE1_LOW_BYTES & 0xFF
        jp nc,combined_descriptor_high
combined_descriptor_low:
        ld de,world_side1_low__ptr
        add hl,de
        ld a,world_side1_low__bbr
        jp combined_descriptor_prepared
combined_descriptor_high:
        ld de,world_side1_high__ptr - SIDE1_LOW_BYTES
        add hl,de
        ld a,world_side1_high__bbr
        jp combined_descriptor_prepared
combined_descriptor_side0:
        ld de,world_side0__ptr
        add hl,de
        ld a,world_side0__bbr
combined_descriptor_prepared:
        ld (descriptor_pointer),hl
        ld (descriptor_bank),a
        ret
