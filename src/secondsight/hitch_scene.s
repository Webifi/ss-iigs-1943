; Hitch scene: bridges in always-mapped planner memory that call the scene
; and ship helpers in their banks through common area 1, and the banked
; scene helper.

        .include "video.inc"
        .include "stream.inc"
        .include "cabinet_layouts.inc"
        .include "hitch.inc"

        .global hitch_scene_prepare_common, hitch_repair_dispatch_common

        .equ SLIDE_STARTING, 1          ; scroll_pan_slide: a ship slide starts

        .section .text.hitch_scene_common,"ax",@progbits

; hitch_scene_prepare_common: run hitch_scene_banked with CBR on the banked
; code page, then put CBR back.
; hitch_repair_dispatch_common: the stage repairs (combined_stage_repairs);
; when a ship slide starts, hitch_ship_banked marks the old ship first.
hitch_scene_prepare_common:
        in0 a,(CBR)
        push af
        ld a,bank_code__load__cbr
        out0 (CBR),a
        call hitch_scene_banked
        pop af
        out0 (CBR),a
        ret

hitch_repair_dispatch_common:
        ld a,(scroll_pan_slide)
        cp SLIDE_STARTING
        jp nz,combined_stage_repairs
        in0 a,(CBR)
        push af
        ld a,bank_code__load__cbr
        out0 (CBR),a
        call hitch_ship_banked
        pop af
        out0 (CBR),a
        jp combined_stage_repairs

; ---------------------------------------------------------------------------
; Banked scene helper: prepares the title picture in the hidden twins while
; the attract mode runs, then hands it to the first game start.

        .global hitch_scene_banked, hitch_d500
        .global hitch_ready, hitch_d500_state, hitch_twin, hitch_copy_source, hitch_copy_dest

        .equ FIRST_TARGET_ROW, 0xD101   ; world rows of the first game view
        .equ LAST_TARGET_ROW, 0xD200
        .equ HITCH_JOBS_END, 0xFF       ; the row byte that ends the hitch jobs
        .equ HITCH_JOBS_PLANE, 3        ; scripts/hitch_scene.py: plane 3 of repair_cores
        .equ FIRST_RING_ROW, 255        ; scene_ring_start of the first game view

; hitch_ready and hitch_row start at 0 (the load record writes them).
        .section .data.hitch_scene,"aw",@progbits
hitch_ready:            .byte 0         ; STATE_*
hitch_row:              .byte 0         ; the next row of the coverage or the picture
        .section .vars.hitch_scene,"aw",@nobits
hitch_d500_state:       .ds.b 1         ; D500_HELPER_PRESENT, D500_STAGED, 0 none
hitch_twin:             .ds.w 1         ; the hidden twin of the shown page
hitch_copy_source:      .ds.w 1         ; dma_copy addresses
hitch_copy_dest:        .ds.w 1

; dma_copy: copy COUNT groups in video RAM with DMA channel 0, from the
; address in SOURCE to the address in DEST.
        .macro dma_copy source, dest, count
        ld hl,(\source)
        ld a,l
        out0 (SAR0L),a
        ld a,h
        out0 (SAR0H),a
        ld hl,(\dest)
        ld a,l
        out0 (DAR0L),a
        ld a,h
        out0 (DAR0H),a
        set_io BCR0L, (\count) & 0xFF
        set_io BCR0H, (\count) >> 8
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        .endm

; require_state: continue only when VAR holds VALUE, else jump to OTHERWISE.
; require_state_ret: the same, else return.
        .macro require_state var, value, otherwise
        ld a,(\var)
        cp \value
        jp nz,\otherwise
        .endm

        .macro require_state_ret var, value
        ld a,(\var)
        cp \value
        ret nz
        .endm

        .section .text.hitch_scene_banked,"ax",@progbits

; hitch_scene_banked: on the title pages with credits, prepare the first
; game view in small steps (the coverage of each row, then the picture in
; the hidden twins of page 1); in the game, hitch_scene_game shows it.
; AF, BC, DE, HL changed.
hitch_scene_banked:
        ld a,(hitch_ready)
        cp STATE_CONSUMED
        jp nz,count_ready
        xor a                           ; a consumed image is invalid
        ld (hitch_ready),a
count_ready:
        ld a,(cabinet_mode)
        and LAYOUT_PAGE_MASK
        or a
        jp z,hitch_scene_game
        ld a,(cabinet_mode)
        and LAYOUT_PAGE_MASK
        cp PAGE_COIN_ONE
        jp z,scene_mode
        cp PAGE_COIN_TWO
        jp z,scene_mode
        xor a                           ; reset the prepared title
        ld (hitch_ready),a
        ld (hitch_row),a
        jp hitch_d500

; Prepare in small steps while the frame has time left.
scene_mode:
        ld a,(hitch_ready)
        cp STATE_IMAGE
        ret z
        call prefetch_time
        ret nz                          ; busy frame
        .irp var, bg_pan, scroll_light_water, water_pattern_base, water_pattern_segment, bg_moving_objects, bg_reuse, sea_active, scroll_left, scroll_right
        ld a,(\var)
        push af
        .endr
        xor a                           ; plain stage water, no overlays
        .irp var, bg_pan, scroll_light_water, bg_moving_objects, bg_reuse, sea_active, scroll_left
        ld (\var),a
        .endr
        ld a,GROUPS_PER_ROW
        ld (scroll_right),a
        ld a,normal_water_high
        ld (water_pattern_base),a
        ld a,normal_water_segment
        ld (water_pattern_segment),a
        set_io BCR0H, 0
        ld a,(hitch_ready)
        or a
        jp nz,draw_begin
        call combined_coverage_begin
coverage_row:
        ld a,(hitch_row)
        ld e,a
        ld d,0
        ld hl,FIRST_TARGET_ROW
        add hl,de
        ld (rows_world_row),hl
        call hitch_scene_coverage_call
        ld a,(hitch_row)
        inc a
        ld (hitch_row),a
        jp nz,coverage_more
        ld a,STATE_METADATA
        ld (hitch_ready),a
        jp scene_restore
coverage_more:
        call prefetch_time
        jp z,coverage_row
        jp scene_restore
draw_begin:
        ld hl,0xFFFF                    ; invalidate the drawing column
        ld (scroll_column_key),hl
draw_row:
        ld a,(hitch_row)
        ld e,a
        ld d,0
        ld hl,LAST_TARGET_ROW
        or a
        sbc hl,de
        ld (scroll_world_row),hl
        ld a,(hitch_row)
        ld l,a
        ld h,0
        call state_times56
        ld de,UPPER_TWIN_1
        add hl,de
        ld (scroll_dest),hl
        call hitch_scene_compose_call
        ld hl,(scroll_dest)
        ld (scroll_src),hl
        ld de,PAGE_DISTANCE
        or a
        sbc hl,de
        ld (scroll_dest),hl
        xor a
        ld (scroll_segment),a
        ld (scroll_x),a
        ld a,GROUPS_PER_ROW
        ld (scroll_length),a
        ld a,ALL_PLANES
        ld (scroll_mask),a
        call combined_dma
        ld a,(hitch_row)
        inc a
        ld (hitch_row),a
        jp nz,draw_more
        ld a,STATE_IMAGE
        ld (hitch_ready),a
        jp scene_restore
draw_more:
        call prefetch_time
        jp z,draw_row
scene_restore:
        .irp var, scroll_right, scroll_left, sea_active, bg_reuse, bg_moving_objects, water_pattern_segment, water_pattern_base, scroll_light_water, bg_pan
        pop af
        ld (\var),a
        .endr
        ld a,(bg_pan)
        call game_set_pan
        ret

; hitch_scene_game: at the first game start, show the prepared picture when
; the game opens exactly on the prepared view: the hitch jobs copy the
; changed pieces of the page into the hidden twin, then DMA copies the twin
; over the page. Else the picture is discarded.
hitch_scene_game:
        ld a,(hitch_ready)
        cp STATE_IMAGE
        jp nz,hitch_d500
        ld hl,(scene_fg_camera)
        ld de,FIRST_TARGET_ROW
        or a
        sbc hl,de
        jp nz,game_discard
        require_state scroll_full, 1, game_discard ; a full rebuild
        require_state scene_ring_start, FIRST_RING_ROW, game_discard
        require_state bg_pan, 0, game_discard
        require_state bg_moving_objects, 0, game_discard
        require_state scroll_pan_slide, 0, game_discard
        require_state scroll_light_water, 0, game_discard
        require_state bg_reuse, 0, game_discard
        require_state sea_active, 0, game_discard
        ld a,(scene_page)
        or a
        ld hl,UPPER_TWIN_1
        jp z,game_hidden
        ld hl,UPPER_TWIN_0
game_hidden:
        ld (hitch_twin),hl
        gc_set GC_MODE, GC_MODE_256 | 1
        oak_set OAK_WRITE_SEGMENT, 0
        xor a
        ld (scroll_segment),a
        in0 a,(BBR)
        push af
        set_io BBR, hitch_jobs_bank
        gc_set GC_READ_MAP, HITCH_JOBS_PLANE
        ld hl,hitch_jobs_pointer
; A hitch job: row, left group, groups, map mask.
game_job:
        oak_set OAK_READ_SEGMENT, hitch_jobs_segment
        ld a,(hl)
        inc hl
        cp HITCH_JOBS_END
        jp z,game_bulk
        ld e,a                          ; row
        ld a,(hl)
        inc hl
        ld (scroll_x),a
        ld a,(hl)
        inc hl
        ld (scroll_length),a
        ld a,(hl)
        inc hl
        ld (scroll_mask),a
        push hl
        ld l,e
        ld h,0
        call state_times56
        push hl
        ld de,(scene_screen_base)
        add hl,de
        ld a,(scroll_x)
        ld e,a
        ld d,0
        add hl,de
        ld (scroll_src),hl
        pop hl
        ld de,(hitch_twin)
        add hl,de
        ld (scroll_dest),hl
        call combined_dma
        pop hl
        jp game_job
game_bulk:
        pop af
        out0 (BBR),a
        gc_set GC_READ_MAP, 0
        oak_set OAK_READ_SEGMENT, 0
        oak_set OAK_WRITE_SEGMENT, 0
        seq_set SEQ_MAP_MASK, ALL_PLANES
        gc_set GC_MODE, GC_MODE_256 | 1
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        ; The full visible twin, then the wrapped clean twin in two pieces.
        dma_copy hitch_twin, scene_screen_base, PAGE_GROUPS
        ld hl,(scene_screen_base)
        ld de,TWIN_DISTANCE
        add hl,de
        ld (hitch_copy_source),hl
        dma_copy hitch_twin, hitch_copy_source, GROUPS_PER_ROW
        ld hl,(hitch_twin)
        ld de,GROUPS_PER_ROW
        add hl,de
        ld (hitch_copy_source),hl
        ld a,(scene_page)
        add a,PAGE_START >> 8           ; display base high byte
        ld h,a
        ld l,0
        ld (hitch_copy_dest),hl
        dma_copy hitch_copy_source, hitch_copy_dest, PAGE_GROUPS - GROUPS_PER_ROW
        set_io BCR0H, 0
        ld hl,FIRST_TARGET_ROW
        ld (scroll_world_row),hl
        ld a,STATE_CONSUMED
        ld (hitch_ready),a
        ret
game_discard:
        xor a
        ld (hitch_ready),a
        jp hitch_d500

; hitch_d500: the host sent a $D500 helper (hitch_stage.s) into the other
; receive buffer. Run it only on an aligned rebuild of exactly that view;
; both raw packets are free then.
hitch_d500:
        ld a,(hitch_d500_state)
        cp D500_HELPER_PRESENT
        ret nz
        dec a                           ; D500_STAGED
        ld (hitch_d500_state),a
        ld hl,(scene_fg_camera)
        ld de,D500_VIEW
        or a
        sbc hl,de
        ret nz
        require_state_ret scroll_full, 1
        require_state_ret scene_ring_start, 0
        require_state_ret bg_pan, 0
        require_state_ret bg_moving_objects, 0
        require_state_ret scroll_light_water, 0
        require_state_ret bg_reuse, 0
        require_state_ret sea_active, 0
        ld a,(stream_receive+1)
        xor stream_other
        ld h,a
        ld l,0
        jp (hl)
