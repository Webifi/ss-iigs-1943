; Playfield: the card entry, the setup of the renderer and its picture loop.
; Each picture receives the next game state, plans and draws the back
; page, then shows it at a retrace and sets the water palette.

        .include "video.inc"
        .include "stream.inc"
        .include "cabinet_layouts.inc"
        .include "mode_table.inc"
        .include "playfield_config.inc"

        .global playfield_setup, update, loading_complete, first_raster_threshold
        .global half_raster_threshold, row_address
        .global entry_begin, entry_end, entry_staging_call, monitor_timing_ready
        .global rgb_first_raster_threshold, rgb_half_raster_threshold, entry_staging_done
        .global play_row, play_back_high, play_new_start_row

        .equ LOADING, LAYOUT_LOADING_BIT ; cabinet_mode bit: a cabinet upload runs
        .equ BACK_PAGE, PAGE_DISTANCE >> 8 ; play_back_high of page 1
        .equ ENTRY_CBAR, 0xC8           ; the entry: bank area from $8000, common area 1 from $C000

        .section .vars.playfield,"aw",@nobits
play_row: .ds.b 1                       ; the ring row of row_address
play_row_group: .ds.b 2                 ; the first group of play_row
play_back_high: .ds.b 1                 ; high byte of the back page: 0 or BACK_PAGE
play_pending_start: .ds.b 2             ; display start of the next picture
play_new_start_row: .ds.b 1             ; the ring start row of the next picture

; row_offset_low, then 256 bytes on its high bytes: row x GROUPS_PER_ROW
; for each row 0-255. The code indexes it with L and steps with INC H.
        .global row_offset_low
        .section .data.row_offsets,"aw",@progbits
        .balign 256
row_offset_low:
        .set row, 0
        .rept PAGE_ROWS
        .byte (row * GROUPS_PER_ROW) & 0xFF
        .set row, row + 1
        .endr
        .set row, 0
        .rept PAGE_ROWS
        .byte (row * GROUPS_PER_ROW) >> 8
        .set row, row + 1
        .endr

        .section .text.playfield,"ax",@progbits

; before_rows: receive the next state and prepare the world before any DMA
; channel 0 work.
        .macro before_rows
        call stream_take
        call game_world_receive
        call state_camera
        .endm

; plan_and_draw: plan the state on the card, then draw the commands.
        .macro plan_and_draw
        call state_plan
        call scene_next
        .endm

; playfield_setup: after the video mode, set up the renderer and draw the
; first picture, then run the picture loop (update).
playfield_setup:
        vga_aperture 2, 1
        write_mode 1
        set_io CBAR, PLAYFIELD_CBAR     ; the BBR and CBR windows of the renderer
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        set_io BCR0H, 0
        set_io DMODE, DMODE_BURST
        set_io DCNTL, DCNTL_STREAM
        set_io IAR1L, CARD_HOST         ; packet receive from the IIgs
        set_io IAR1H, 0
        set_io DCNTL, DCNTL_STREAM
        xor a
        ld (play_back_high),a
        ld hl,scroll_origins
        ld de,scroll_origins + 1
        ld bc,SCROLL_PAGE_STATE - 1     ; clear the scroll page state
        ld (hl),0
        ldir
        ld hl,FOREGROUND_INITIAL
        ld (scene_previous_foreground),hl
; The damage maps of both pages and the spare map start empty: left 56,
; right 0 in each row.
        .irp map,damage_map_0,damage_map_1,damage_map_2
        ld hl,\map
        ld b,0
1:      ld (hl),GROUPS_PER_ROW
        inc hl
        ld (hl),0
        inc hl
        djnz 1b
        .endr
        ld h,damage_map_1 >> 8          ; map high bytes of pages 0 and 1
        ld l,damage_map_0 >> 8
        ld (scroll_damage_pages),hl
; Static cabinet sprites can mark damage before scroll_begin: point them at
; the real map of page 0, never at 0x0000.
        ld a,l
        ld (scroll_current_map + 1),a
        ld a,damage_map_2 >> 8
        ld (scroll_spare_map),a
        xor a
        ld (bg_pan),a
        ld a,packet_buffer_0__run >> 8  ; the first state buffer
        call stream_arm
        before_rows
        plan_and_draw

        start_address INITIAL_DISPLAY_START
        wait_retrace
        call water_commit
        ld a,BACK_PAGE
        ld (play_back_high),a

; update: the picture loop: receive, plan and draw the back page, then
; show it at the retrace of the second raster.
update:
        set_io TCR, 0                   ; stop timer 0
        .irp port,TMDR0L,TMDR0H,RLDR0L,RLDR0H
        set_io \port, 0xFF              ; count down from 0xFFFF
        .endr
        set_io TCR, TCR_TDE0            ; PRT0 times the work of this picture
        before_rows
; A cabinet art upload uses a separate world surface. Do not draw the
; visible page while it runs.
        ld a,(cabinet_mode)
        bit LOADING,a
        jp z,draw_picture
        call stream_arm_next
        jp loading_complete
; The DMA banks, all planes and the Oak segments for the drawing.
draw_picture:
        seq_set SEQ_MAP_MASK, ALL_PLANES
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        oak_set OAK_READ_SEGMENT, 1
        oak_set OAK_WRITE_SEGMENT, 0
        plan_and_draw
        call sprite_cache_prefetch
; Restore the new start row after the address of the catch-up row.
        ld a,(play_new_start_row)
        ld (play_row),a
        call row_address
        ld hl,(play_row_group)
        ld de,PAGE_START
        add hl,de
        ld a,(play_back_high)
        add a,h
        ld h,a
        ld (play_pending_start),hl
loading_complete:
; Submit the page flip in the second raster, whether the work took less or
; more than one raster. A stop of TDE0 keeps TMDR0 (UM0050); reading TCR
; first latches a consistent count.
        set_io TCR, 0                   ; stop timer 0
        in0 a,(TCR)
        in0 a,(TMDR0L)
        ld e,a
        in0 a,(TMDR0H)
        ld d,a
        ld hl,(first_raster_threshold)
        or a
        sbc hl,de
        jp nc,submit_flip               ; already in the second raster
; A picture starts just after a retrace edge. The work can end in the next
; retrace while the timer is still below one raster; a wait for low, then
; high, would then miss the edge. Only a very short picture can still be
; in the first retrace: half a raster tells the two apart.
        ld hl,(half_raster_threshold)
        or a
        sbc hl,de
        jp nc,first_raster_on
        ld bc,VGA_STATUS
first_raster_off:
        in a,(c)
        and STATUS_RETRACE
        jp nz,first_raster_off
first_raster_on:
        ld bc,VGA_STATUS
first_raster_high:
        in a,(c)
        and STATUS_RETRACE
        jp z,first_raster_high
submit_flip:
; A cabinet upload draws no back page: keep the shown page until the
; next one is ready.
        ld a,(cabinet_mode)
        bit LOADING,a
        jp nz,flip_held
        ld hl,(play_pending_start)
        ld bc,VGA_CRTC_INDEX
        ld a,CRTC_START_HIGH
        out (c),a
        inc c
        ld a,h
        out (c),a
        dec c
        ld a,CRTC_START_LOW
        out (c),a
        inc c
        ld a,l
        out (c),a
        dec c
flip_held:
        wait_retrace
        call palette_commit
        ld a,(cabinet_mode)
        bit LOADING,a
        jp nz,flip_not_swapped
        ld a,(play_back_high)
        xor BACK_PAGE
        ld (play_back_high),a
flip_not_swapped:
        jp update

; first_raster_threshold, half_raster_threshold: the PRT0 counts after one
; raster and after half a raster (PRT0 counts down from 0xFFFF). The entry
; replaces both values for an AppleColor RGB monitor.
first_raster_threshold:
        .word FIRST_RASTER_THRESHOLD
half_raster_threshold:
        .word HALF_RASTER_THRESHOLD

; row_address: Out: play_row_group the first group of play_row
; (row_offset_low: row x GROUPS_PER_ROW). AF, DE, HL changed.
row_address:
        ld a,(play_row)
        ld l,a
        ld h,row_offset_low >> 8
        ld e,(hl)
        inc h
        ld d,(hl)
        ld (play_row_group),de
        ret

        .section .text.entry_begin,"ax",@progbits

; entry_begin: the card entry from the firmware, before the video mode
; (secondsight.ld .entry: the mode table and the staging follow).
entry_begin:
        set_io CBAR, ENTRY_CBAR
        ld a,i                          ; IFF2 to P/V
        push af
        di

        .section .text.entry_end,"ax",@progbits

; After the video mode: the text mode used pel panning 8. The renderer
; takes over from that blank screen; no firmware graphics mode is needed.
entry_end:
        ld bc,VGA_STATUS                ; reset the attribute flip-flop
        in a,(c)
        ld bc,VGA_ATTR
        ld a,ATTR_PAS | ATTR_PANNING
        out (c),a
        xor a                           ; pel panning 0
        out (c),a
; The first mode write is already correct for the cable. Install the
; selected data into the table of the renderer, which applies it again
; after the startup DMA.
        ld hl,entry_mode_data
        ld de,playfield_mode_data
        ld bc,MODE_TABLE_BYTES
        ldir
        ld bc,MONITOR_SENSE
        in a,(c)
        and SENSE_VGA
        jp nz,monitor_timing_ready
        ld hl,(rgb_first_raster_threshold)
        ld (first_raster_threshold),hl
        ld hl,(rgb_half_raster_threshold)
        ld (half_raster_threshold),hl
monitor_timing_ready:
        vga_aperture
        dma_groups state_planner__load__phys, state_planner__run, state_planner__size, 0, 0, symbols=1
entry_staging_call:
        call entry_staging              ; install the reclaimed SRAM
        call playfield_mode
        gc_set GC_READ_MAP, 0
        pop af
        jp po,irq_done                  ; interrupts were off
        ei
irq_done:
        set_io CBAR, game_cbar          ; the MMU that the IIgs gave the entry
        set_io BBR, game_bbr
        set_io CBR, game_cbr
        ret
; The RGB thresholds: 0xFFFF: the work always ends in the second raster.
rgb_first_raster_threshold:
        .word 0xFFFF
rgb_half_raster_threshold:
        .word RGB_HALF_RASTER_THRESHOLD

        .global entry_staging, entry_stage_base
        .equ entry_stage_base, PAGE_START ; the first staging group (secondsight.ld)

        .section .text.entry_staging,"ax",@progbits

; entry_staging: copy the SRAM ranges that the firmware uses until the entry
; (staged_N), then the runtime block, into place from plane 0 of their
; staging groups entry_stage_N (secondsight.ld). The boot clear of the sprite
; cache follows; it ends at entry_staging_done.
entry_staging:
        gc_set GC_READ_MAP, 0
        oak_set OAK_READ_SEGMENT, 0     ; the staging groups are in segment 0
        .irp n, 0, 1, 2, 3, 4, 5, 6
        dma_groups VGA_WINDOW + entry_stage_\n, staged_\n\()__start__phys, staged_\n\()__size, 0, 0, symbols=1
        .endr
        dma_groups VGA_WINDOW + entry_stage_7, entry_runtime__run, entry_runtime__size, 0, 0, symbols=1

        .section .text.entry_staging_done,"ax",@progbits

; entry_staging_done: the end of the entry staging.
entry_staging_done:
        ret                             ; the reclaimed tables are installed
