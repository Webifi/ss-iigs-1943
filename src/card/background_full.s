; Full background views in SRAM bank 15: proved-empty views, copies between
; the twins and the other page, and the banked helper calls.

        .include "video.inc"

        .global background_plan_full, background_blank_materialize, background_prepare_view
        .global background_bank_call, background_bank_jump, background_reuse_overlap
        .global background_empty_plan, background_empty_select, background_empty_masks
        .global background_empty_view, background_empty_copy, background_overlap_view
        .global background_overlap_limit, water_pattern_source

        .equ BACKGROUND_BANK, 15
        .equ D500_VIEW, 0xD500
        .equ CODE_CBR, 9                ; CBR with this bank's code in common area 1
        .equ GAME_CBR, 0x84
        .equ COMMON_ALIAS, 0x2000
        .equ TWIN_DISTANCE, 0x3800
        .equ DISPLAY_RESERVATION, 0x400
        .equ UPPER_VISIBLE, 0x3C00
        .equ VIEW_ROWS, 256
        .equ BOUNDED_ROWS, 129
        .equ MAX_CHUNK, 128
        .equ STATE_CONSUMED, 3          ; hitch_ready: the prepared image was shown
        .equ STAGE_PERIOD, 30
        .equ LIGHT_PERIOD, 128

        .section .text.background_calls,"ax",@progbits

; Common entries for the banked background helpers.
background_plan_full:
        ld hl,background_empty_plan
        jp background_bank_call
background_blank_materialize:
        ld hl,background_empty_masks
        jp background_bank_call
background_prepare_view:
        ld hl,background_empty_view
        jp background_bank_call
background_bank_call:
        in0 a,(BBR)
        push af
        set_io BBR, BACKGROUND_BANK
        call background_bank_jump
        pop bc                          ; POP BC and LD A,B keep the helper's carry
        ld a,b
        out0 (BBR),a
        ret
background_bank_jump:
        jp (hl)

; A cheap frame-level test that saves 256 failed row probes when the other
; page shows a camera position that does not overlap this one.
background_reuse_overlap:
        ld a,(scroll_page_index)
        xor 1
        add a,a
        add a,scroll_cameras & 0xFF
        ld l,a
        ld h,scroll_cameras >> 8
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(scene_fg_camera)
        or a
        sbc hl,de
        inc h                           ; -256..255 becomes high byte 0 or 1
        ld a,h
        cp 2
        sbc a,a
        ld (bg_reuse),a
        ret

        .section .text.background_full,"ax",@progbits

; Called only for a full 256-row rebuild. Out: carry set when the begin
; command was replaced by bulk empty metadata.
background_empty_plan:
        ; The full $D500 view uses the ROM-proved occupancy shortcut.
        ld hl,(scene_fg_camera)
        ld de,D500_VIEW
        or a
        sbc hl,de
        jp nz,not_d500
        in0 a,(CBR)
        push af
        set_io CBR, CODE_CBR
        call sea_occupancy_d500_install+COMMON_ALIAS
        pop af
        out0 (CBR),a
not_d500:
        call background_empty_select
        or a
        ret z
        ld hl,(scene_out)               ; replace the queued begin handler
        dec hl
        ld de,background_blank_materialize
        ld (hl),d
        dec hl
        ld (hl),e
        scf
        ret

; Out: A and bg_blank_view 1 when the camera view is proved empty.
background_empty_select:
        ld hl,(scene_fg_camera)
        ld b,l
        ld l,h
        ld h,background_empty_limits >> 8
        ld a,b
        cp (hl)                         ; first allowed row
        ld a,0
        jp c,empty_selected
        inc h
        ld a,(hl)                       ; last allowed row
        cp b
        ld a,0
        jp c,empty_selected
        inc a
empty_selected:
        ld (bg_blank_view),a
        ret

; Empty rows never consult cloud roots or run records: zero coverage and
; full-water bounds are all that the drawing paths read.
background_empty_masks:
        phase_stamp phase_times+0x04
        call combined_coverage_begin
        .irp table, row_classes, water_left_bounds
        ld hl,\table
        ld de,\table+1
        ld bc,255
        ld (hl),0
        ldir
        .endr
        ld hl,water_right_bounds
        ld de,water_right_bounds+1
        ld bc,255
        ld (hl),GROUPS_PER_ROW
        ldir
        ; One sea-occupancy byte per world row: a clear view occupies nothing.
        set_io CBR, CODE_CBR
        ld hl,sea_occupancy_map+COMMON_ALIAS
        ld de,sea_occupancy_map+COMMON_ALIAS+1
        ld bc,255
        ld (hl),0
        ldir
        set_io CBR, GAME_CBR
        seq_set SEQ_MAP_MASK, 0x0F
        gc_set GC_MODE, 0x40
        oak_set OAK_WRITE_SEGMENT, game_coverage__vseg
        dma_groups row_classes, game_coverage__dma, 2048, 1, symbols=1
        set_io DMODE, DMODE_BURST
        set_io BCR0H, 0
        set_io SAR0B, VGA_WINDOW >> 16
        gc_set GC_MODE, 0x41
        oak_set OAK_WRITE_SEGMENT, 0
        ; Empty rows also have an empty ready command, so a later camera or
        ; ship change cannot see stale alignment records in those slots.
        .irp bank, 14, 15, 16, 17
        set_io CBR, \bank
        ld hl,0xE000
        ld b,64
1:      ld (hl),0                       ; no water spans
        inc l
        ld (hl),0                       ; no ship spans
        ld a,l
        add a,63
        ld l,a
        jr nc,2f
        inc h
2:      djnz 1b
        .endr
        set_io CBR, GAME_CBR
        ret

; Out: carry set when the whole view is ready; else scroll_left_count rows
; from scroll_row still need composing.
background_empty_view:
        ld a,(hitch_ready)              ; the hitch helper filled both twins
        cp STATE_CONSUMED
        jp nz,not_prepainted
        ld hl,0
        ld (scroll_left_count),hl
        scf
        ret
not_prepainted:
        call background_empty_select
        ld hl,VIEW_ROWS
        ld (scroll_left_count),hl
        xor a
        ld (scroll_row),a
        ld a,(bg_blank_view)
        or a
        jp z,background_overlap_view
        call background_water_view
        ; Split the canonical copy only at the end of the 512-row ring.
        oak_set OAK_READ_SEGMENT, 0
        ld a,(scene_ring_start)
        neg                             ; rows below the ring end
        jp z,whole_twin
        ld l,a
        ld h,0
        call state_times56
        ld b,h
        ld c,l
        ld hl,(scene_screen_base)
        ld de,TWIN_DISTANCE
        add hl,de
        ex de,hl
        ld hl,(scene_screen_base)
        call background_empty_copy
        ld a,(scene_ring_start)
        ld l,a
        ld h,0
        call state_times56
        ld b,h
        ld c,l
        ld hl,UPPER_VISIBLE
        ld a,(scene_page)
        or h
        ld h,a
        ld de,DISPLAY_RESERVATION
        ld a,(scene_page)
        or d
        ld d,a
        jp copy_last
whole_twin:
        ld bc,TWIN_DISTANCE
        ld hl,(scene_screen_base)
        ld de,TWIN_DISTANCE
        add hl,de
        ex de,hl
        ld hl,(scene_screen_base)
copy_last:
        call background_empty_copy
        set_io BCR0H, 0
        scf
        ret

; DMA BC groups from HL to DE in video RAM.
background_empty_copy:
        out0 (SAR0L),l
        out0 (SAR0H),h
        out0 (DAR0L),e
        out0 (DAR0H),d
        out0 (BCR0L),c
        out0 (BCR0H),b
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        ret

; Copy the rows that the other page already shows. Only stage-water views
; can share rows across page cameras; light-water phase and moving overlays
; keep their complete path. Out: carry set when the whole view was copied;
; else scroll_left_count new rows from scroll_row still need composing.
background_overlap_view:
        ld a,(bg_moving_objects)
        ld b,a
        ld a,(scroll_light_water)
        or b
        ret nz
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
        ld a,(hl)
        or a
        ret nz
        ld a,c
        add a,a
        add a,scroll_cameras & 0xFF
        ld l,a
        ld h,scroll_cameras >> 8
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(scene_fg_camera)
        or a
        sbc hl,de
        xor a                           ; new rows at the top
        ld (scroll_x),a
        bit 7,h
        jp z,overlap_forward
        ld a,l                          ; first new bottom row
        ld (scroll_x),a
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
        jp overlap_count
overlap_forward:
        ld a,l                          ; first reused row
        ld (scroll_row),a
overlap_count:
        ld a,h
        or a
        jp nz,overlap_reject
        ld a,l
        cp BOUNDED_ROWS
        jp nc,overlap_reject
        ld (scroll_length),a
        ex de,hl
        ld hl,VIEW_ROWS
        or a
        sbc hl,de
        ld (scroll_left_count),hl
        oak_set OAK_READ_SEGMENT, 0
        seq_set SEQ_MAP_MASK, 0x0F
overlap_chunk:
        call combined_position
        ld hl,(scroll_left_count)
        ld a,MAX_CHUNK
        bit 0,h
        jp nz,overlap_capacity
        cp l
        jp c,overlap_capacity
        ld a,l
overlap_capacity:
        ld (scroll_n),a
        ld a,(scroll_page_index)
        xor 1
        ld c,a
        call background_clean_address
        ld (scroll_src),hl
        call background_overlap_limit
        ld a,(scroll_page_index)
        ld c,a
        call background_clean_address
        ld (scroll_ptr),hl
        call background_overlap_limit
        ld a,(scroll_n)
        ld l,a
        ld h,0
        call state_times56
        ld b,h
        ld c,l
        ld hl,(scroll_src)
        ld de,(scroll_dest)
        call background_empty_copy
        ld hl,(scroll_dest)
        ld de,(scroll_ptr)
        call background_empty_copy
        ld a,(scroll_n)
        ld e,a
        ld d,0
        ld a,(scroll_row)
        add a,e
        ld (scroll_row),a
        ld hl,(scroll_left_count)
        or a
        sbc hl,de
        ld (scroll_left_count),hl
        ld a,h
        or l
        jp nz,overlap_chunk
        set_io BCR0H, 0
        ld a,(scroll_x)
        ld (scroll_row),a
        ld a,(scroll_length)
        ld l,a
        ld h,0
        ld (scroll_left_count),hl
        or a
        ret nz                          ; compose the uncovered rows
        scf
        ret
overlap_reject:
        xor a
        ld (scroll_row),a
        ret

; Limit scroll_n to the rows left in the clean twin.
background_overlap_limit:
        ld a,(bg_clean_limit)
        or a
        ret z                           ; 0 means 256
        ld b,a
        ld a,(scroll_n)
        cp b
        ret c
        ld a,b
        ld (scroll_n),a
        ret

; Map the water pattern for the row at scroll_world_row. Out: HL its address.
water_pattern_source:
        ld a,(water_pattern_segment)
        ld d,a
        ld bc,OAK_INDEX
        ld a,OAK_READ_SEGMENT
        out (c),a
        inc c
        out (c),d
        ld a,(scroll_light_water)
        or a
        jp nz,water_light
        ld hl,(scroll_world_row)
        call water_mod30
        ld e,a
        ld a,STAGE_PERIOD - 1
        sub e
        jp water_address
water_light:
        ld a,(scroll_world_row)
        ld b,a
        ld a,(scroll_relative)
        add a,b
        cpl
        and LIGHT_PERIOD - 1
water_address:
        ld c,a
        jp water_row_address
