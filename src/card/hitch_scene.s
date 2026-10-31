; Hitch scene: bridges in always-mapped planner memory that call the scene
; and ship helpers in their banks through common area 1.

        .include "second_sight.inc"
        .include "z180.inc"

        .global hitch_scene_prepare_common, hitch_repair_dispatch_common

        .equ SLIDE_STARTING, 1

        .section .text.hitch_scene_common,"ax",@progbits

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

        .include "vga.inc"

        .global hitch_scene_banked, hitch_d500

        .equ STATE_NONE, 0
        .equ STATE_METADATA, 1          ; coverage of every target row is ready
        .equ STATE_IMAGE, 2             ; the picture is in the hidden twins
        .equ STATE_CONSUMED, 3
        .equ TITLE_MODE, 0x7F           ; cabinet_mode bits of the title screen
        .equ TITLE_ONE_PLAYER, 6
        .equ TITLE_TWO_PLAYERS, 7
        .equ FIRST_TARGET_ROW, 0xD101   ; world rows of the first game view
        .equ LAST_TARGET_ROW, 0xD200
        .equ HIDDEN_TWIN, 0xBC00        ; page 1 hidden twin
        .equ PAGE_DISTANCE, 0x8000
        .equ TWIN_DISTANCE, 0x3800
        .equ VIEW_GROUPS, 56
        .equ JOB_END, 0xFF
        .equ D500_HELPER_PRESENT, 2
        .equ D500_TARGET, 0xD500
        .equ OTHER_BUFFER, 0xC0

        .section .vars.hitch_scene,"aw",@nobits
hitch_ready:            .ds.b 1         ; STATE_*
hitch_row:              .ds.b 1
hitch_d500_state:       .ds.b 1
hitch_twin:             .ds.w 1
hitch_copy_source:      .ds.w 1
hitch_copy_dest:        .ds.w 1

; Copy COUNT groups in video RAM with DMA channel 0, from (SOURCE) to (DEST).
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

; Continue only when VAR holds VALUE.
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

hitch_scene_banked:
        ld a,(hitch_ready)
        cp STATE_CONSUMED
        jp nz,count_ready
        xor a                           ; a consumed image is invalid
        ld (hitch_ready),a
count_ready:
        ld a,(cabinet_mode)
        and TITLE_MODE
        or a
        jp z,hitch_scene_game
        ld a,(cabinet_mode)
        and TITLE_MODE
        cp TITLE_ONE_PLAYER
        jp z,scene_mode
        cp TITLE_TWO_PLAYERS
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
        ld a,VIEW_GROUPS
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
        ld de,HIDDEN_TWIN
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
        ld a,VIEW_GROUPS
        ld (scroll_length),a
        ld a,0x0F
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

; First game start: show the prepared picture when the game opens exactly on
; the prepared view.
hitch_scene_game:
        ld a,(hitch_ready)
        cp STATE_IMAGE
        jp nz,hitch_d500
        ld hl,(scene_fg_camera)
        ld de,FIRST_TARGET_ROW
        or a
        sbc hl,de
        jp nz,game_discard
        require_state scroll_full, 1, game_discard
        require_state scene_ring_start, 255, game_discard
        require_state bg_pan, 0, game_discard
        require_state bg_moving_objects, 0, game_discard
        require_state scroll_pan_slide, 0, game_discard
        require_state scroll_light_water, 0, game_discard
        require_state bg_reuse, 0, game_discard
        require_state sea_active, 0, game_discard
        ld a,(scene_page)
        or a
        ld hl,HIDDEN_TWIN
        jp z,game_hidden
        ld hl,HIDDEN_TWIN - PAGE_DISTANCE
game_hidden:
        ld (hitch_twin),hl
        gc_set GC_MODE, 0x41
        oak_set OAK_WRITE_SEGMENT, 0
        xor a
        ld (scroll_segment),a
        in0 a,(BBR)
        push af
        set_io BBR, hitch_jobs_bank
        gc_set GC_READ_MAP, hitch_jobs_plane
        ld hl,hitch_jobs_pointer
game_job:
        oak_set OAK_READ_SEGMENT, hitch_jobs_segment
        ld a,(hl)
        inc hl
        cp JOB_END
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
        seq_set SEQ_MAP_MASK, 0x0F
        gc_set GC_MODE, 0x41
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        ; The full visible twin, then the wrapped clean twin in two pieces.
        dma_copy hitch_twin, scene_screen_base, VIEW_GROUPS * 256
        ld hl,(scene_screen_base)
        ld de,TWIN_DISTANCE
        add hl,de
        ld (hitch_copy_source),hl
        dma_copy hitch_twin, hitch_copy_source, VIEW_GROUPS
        ld hl,(hitch_twin)
        ld de,VIEW_GROUPS
        add hl,de
        ld (hitch_copy_source),hl
        ld a,(scene_page)
        add a,4                         ; display base high byte
        ld h,a
        ld l,0
        ld (hitch_copy_dest),hl
        dma_copy hitch_copy_source, hitch_copy_dest, VIEW_GROUPS * 255
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

; The host sent a $D500 helper into the opposite receive buffer. Run it only
; on an aligned rebuild of exactly that view; both raw packets are free then.
hitch_d500:
        ld a,(hitch_d500_state)
        cp D500_HELPER_PRESENT
        ret nz
        dec a                           ; staged image
        ld (hitch_d500_state),a
        ld hl,(scene_fg_camera)
        ld de,D500_TARGET
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
        xor OTHER_BUFFER
        ld h,a
        ld l,0
        jp (hl)
