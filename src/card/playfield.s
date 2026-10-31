; Playfield: the card entry, the setup of the renderer and its picture loop.
; Each picture receives the next game state, plans and draws the back
; page, then shows it at a retrace and sets the water palette.

        .include "video.inc"
        .include "mode_table.inc"
        .include "playfield_config.inc"

        .global playfield_setup, update, loading_complete, first_raster_threshold
        .global half_raster_threshold, new_row, row_address, back_row, copy_row
        .global entry_begin, entry_end, entry_staging_call, monitor_timing_ready
        .global rgb_first_raster_threshold, rgb_half_raster_threshold, entry_staging_done
        .global play_world, play_row, play_back_high, play_new_start_row
        .global play_new_row_count, play_back_row_count

        .equ LOADING, 7                 ; cabinet_mode bit: a cabinet upload runs
        .equ TEXT_GROUPS, 0x400         ; the fixed text area before each display page
        .equ BACK_PAGE, 0x80            ; play_back_high of page 1
        .equ TWIN_ROW, 0x38             ; high byte offset of the twin of a row
        .equ RETRACE, 0x08              ; VGA_STATUS: vertical retrace
        .equ PRT_STOP, 0                ; TCR values
        .equ PRT1_RUN, 2
        .equ PRT_BOTH, 3
        .equ CARD_DONE, 0xA5            ; to the IIgs: the renderer returns

        .section .vars.playfield,"aw",@nobits
play_world: .ds.b 2
play_row: .ds.b 1
        .ds.b 1
play_source_low: .ds.b 1
        .ds.b 1
play_row_group: .ds.b 2
play_back_high: .ds.b 1                 ; high byte of the back page: 0 or BACK_PAGE
play_remaining: .ds.b 1
play_time_pointer: .ds.b 2
play_cadence_pointer: .ds.b 2
play_pending_start: .ds.b 2             ; display start of the next picture
play_new_start_row: .ds.b 1
        .ds.b 1
play_camera_records: .ds.b 2
play_new_row_count: .ds.b 1
play_back_row_count: .ds.b 1

; Development timing: PRT1 counts at each phase of the picture.
        .equ TIMES_STAGE, phase_times
        .equ TIMES_COVERAGE, phase_times + 0x18
        .equ TIMES_SERIAL, phase_times + 0x12
        .equ TIMES_END, phase_times + 0x10
        .equ TIMES_STABLE, phase_times + 0x30
        .equ TIMES_STABLE_COVERAGE, phase_times + 0x42
        .equ TIMES_PLAN, phase_times + 0x44
        .equ TIMES_PLANNED, phase_times + 0x46
        .equ TIMES_WORLD, phase_times + 0x48
        .equ TIMES_CAMERA, phase_times + 0x4A
        .equ TIMES_STABLE_PLAN, phase_times + 0x50
        .equ TIMES_STABLE_WATER, phase_times + 0x58
        .equ TIMING_OVERFLOW, TIMES_BASE + 0x2FF

        .section .text.playfield,"ax",@progbits

; Receive the next state and prepare the world before any DMA channel 0.
        .macro before_rows
        call stream_take
        phase_stamp TIMES_STAGE
        ld hl,0
        ld (TIMES_COVERAGE),hl
        phase_stamp TIMES_WORLD
        call game_world_receive
        phase_stamp TIMES_CAMERA
        call state_camera
        .endm

; Plan the state on the card, then draw the packet.
        .macro plan_and_draw
        phase_stamp TIMES_PLAN
        call state_plan
        phase_stamp TIMES_PLANNED
        call scene_next
        .endm

; After the video mode: set up the renderer, then run the picture loop.
playfield_setup:
        vga_aperture 2, 1
        write_mode 1
        set_io CBAR, PLAYFIELD_CBAR     ; the BBR and CBR windows of the renderer
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        set_io BCR0H, 0
        set_io DMODE, DMODE_BURST
        set_io DCNTL, DCNTL_STREAM
        ld hl,CAMERA_START
        ld (play_world),hl

; The state scene before the first picture.
        ld hl,scene_cameras
        ld (play_camera_records),hl
        set_io IAR1L, CARD_HOST         ; packet receive from the IIgs
        set_io IAR1H, 0
        set_io DCNTL, DCNTL_STREAM
        xor a
        ld (play_back_high),a
        ld hl,scroll_origins
        ld de,scroll_origins + 1
        ld bc,79                        ; scroll page state
        ld (hl),0
        ldir
        call game_row_cache_clear
        ld hl,CAMERA_START
        ld (scene_previous),hl
        ld (scene_previous + 2),hl
        ld hl,FOREGROUND_INITIAL
        ld (scene_previous_foreground),hl
; The damage maps of both pages and the spare map start empty: left 56,
; right 0 in each row.
        .irp map,0x5A00,0x5E00,0x7000
        ld hl,\map
        ld b,0
1:      ld (hl),GROUPS_PER_ROW
        inc hl
        ld (hl),0
        inc hl
        djnz 1b
        .endr
        ld hl,0x5E5A                    ; map high bytes of pages 0 and 1
        ld (scroll_damage_pages),hl
; Static cabinet sprites can mark damage before scroll_begin: point them at
; the real map of page 0, never at 0x0000.
        ld a,l
        ld (scroll_current_map + 1),a
        ld a,0x70
        ld (scroll_spare_map),a
        ld de,0xFFFF
        ld (row_cache_tag),de
        ld hl,0xFFFF
        ld (bg_page_foreground),hl
        ld (bg_page_foreground + 2),hl
        xor a
        ld (bg_page_pan),a
        ld (bg_page_pan + 1),a
        ld (bg_pan),a
        ld a,0x40                       ; the first state buffer
        call stream_arm
        before_rows
        plan_and_draw

        start_address INITIAL_DISPLAY_START
        wait_retrace
        call water_commit
        ld a,BACK_PAGE
        ld (play_back_high),a
        ld a,UPDATES
        ld (play_remaining),a
        ld hl,TIMES_BASE
        ld (play_time_pointer),hl
        ld hl,CADENCE_BASE
        ld (play_cadence_pointer),hl
        xor a
        ld (TIMING_OVERFLOW),a
; PRT1 runs free, with no interrupt and no TOUT output.
        set_io TCR, PRT_STOP
        .irp port,TMDR1L,TMDR1H,RLDR1L,RLDR1H
        set_io \port, 0xFF
        .endr
        set_io TCR, PRT1_RUN

update:
        ld hl,(play_cadence_pointer)
        in0 a,(TCR)
        in0 a,(TMDR1L)
        ld (hl),a
        inc hl
        in0 a,(TMDR1H)
        ld (hl),a
        inc hl
        ld hl,CADENCE_BASE
        ld (play_cadence_pointer),hl
        set_io TCR, PRT1_RUN
        .irp port,TMDR0L,TMDR0H,RLDR0L,RLDR0H
        set_io \port, 0xFF
        .endr
        set_io TCR, PRT_BOTH            ; PRT0 times the work of this picture
        before_rows
; A cabinet art upload uses a separate world surface. Do not draw the
; visible page while it runs.
        ld a,(cabinet_mode)
        bit LOADING,a
        jp z,new_rows_loop
        call stream_arm_next
        jp loading_complete
; The new rows of the retained renderer only move its old sea counter;
; scroll_draw makes the pixel rows.
new_rows_loop:
        ld a,(play_new_row_count)
        or a
        jp z,new_rows_done
        ld hl,play_world
        add a,(hl)
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,0
        ld (hl),a
        xor a
        ld (play_new_row_count),a
new_rows_done:
        seq_set SEQ_MAP_MASK, 0x0F
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        oak_set OAK_READ_SEGMENT, 1
        oak_set OAK_WRITE_SEGMENT, 0
        ld a,(play_new_start_row)
        ld (play_row),a
back_rows_loop:
        ld a,(play_back_row_count)
        or a
        jp z,back_rows_done
        call row_address
        call back_row
        ld hl,play_row
        inc (hl)
        ld hl,play_back_row_count
        dec (hl)
        jp back_rows_loop
back_rows_done:
        plan_and_draw
        call sprite_cache_prefetch
        phase_stamp TIMES_END
        ld hl,TIMES_STAGE
        ld de,TIMES_STABLE
        ld bc,18
        ldir
        ld hl,TIMES_PLAN
        ld de,TIMES_STABLE_PLAN
        ld bc,8
        ldir
        ld hl,(TIMES_COVERAGE)
        ld (TIMES_STABLE_COVERAGE),hl
        ld hl,(water_active)
        ld (TIMES_STABLE_WATER),hl
        ld hl,(water_active + 2)
        ld (TIMES_STABLE_WATER + 2),hl
        ld hl,TIMES_SERIAL
        inc (hl)
; Restore the new start row after the address of the catch-up row.
        ld a,(play_new_start_row)
        ld (play_row),a
        call row_address
        ld hl,(play_row_group)
        ld de,TEXT_GROUPS
        add hl,de
        ld a,(play_back_high)
        add a,h
        ld h,a
        ld (play_pending_start),hl
loading_complete:
; Submit the page flip in the second raster, whether the work took less or
; more than one raster. A stop of TDE0 keeps TMDR0 (UM0050). PRT1 runs on
; and records the real cadence of the pictures.
        set_io TCR, PRT1_RUN
        in0 a,(TCR)
        and 0x40                        ; TIF0: PRT0 overflowed
        jp z,timing_in_range
        ld (TIMING_OVERFLOW),a
timing_in_range:
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
        and RETRACE
        jp nz,first_raster_off
first_raster_on:
        ld bc,VGA_STATUS
first_raster_high:
        in a,(c)
        and RETRACE
        jp z,first_raster_high
submit_flip:
        set_io TCR, PRT_BOTH
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
; Time the picture up to the start address; not the wait.
        set_io TCR, PRT1_RUN
        ld hl,(play_time_pointer)
        in0 a,(TCR)
        in0 a,(TMDR0L)
        ld (hl),a
        inc hl
        in0 a,(TMDR0H)
        ld (hl),a
        inc hl
        ld hl,TIMES_BASE
        ld (play_time_pointer),hl
        wait_retrace
        call palette_commit
        ld a,(cabinet_mode)
        bit LOADING,a
        jp nz,flip_not_swapped
        ld a,(play_back_high)
        xor BACK_PAGE
        ld (play_back_high),a
flip_not_swapped:
        ld a,(play_remaining)
        dec a
        ld (play_remaining),a
        jp update
; Unused: the loop above does not end.
        set_io DSTAT, DSTAT_DWE0 | DSTAT_DME ; stop the packet receive
        set_io TCR, PRT_STOP
        set_io CARD_HOST, CARD_DONE
        ret

; PRT0 counts down from 0xFFFF. The entry replaces both values for an
; AppleColor RGB monitor.
first_raster_threshold:
        .word FIRST_RASTER_THRESHOLD
half_raster_threshold:
        .word HALF_RASTER_THRESHOLD

new_row:
        ret                             ; the sea source repeats

; Unused: copy one sea row from the atlas in 8 DMA pieces.
        seq_set SEQ_MAP_MASK, 0x0F
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        oak_set OAK_WRITE_SEGMENT, 1
        ld a,(play_world)
        cpl
        and 63                          ; repeated sea row
        ld (play_row),a
        call row_address
; The source row of each world column is a build table.
        ld a,(play_world)
        and 31
        ld l,a
        ld h,0x32                       ; row table
        ld a,(hl)
        ld (play_source_low),a
; Select one of the two 16 KB map banks and its 16-byte column record.
        ld hl,(play_world)
        ld a,l
        and 0xE0
        ld l,a
        srl h
        rr l
        set_io BBR, SEA_MAP_BBR
        ld a,h
        and SEA_HIGH_MASK
        or SEA_MAP_WINDOW >> 8
        ld h,a
        oak_set OAK_READ_SEGMENT, 2     ; only the data changes for each tile
        ld de,(play_row_group)
        .set piece, 0
        .irp count,4,8,8,8,8,8,8,4
; The DMA also increments its bank byte when a strip ends at 0xAFFFF:
; set the VGA window again for each strip.
        set_io SAR0B, VGA_WINDOW >> 16
        ld a,(hl)                       ; tile address high
        out0 (SAR0H),a
        inc hl
        ld a,(hl)                       ; atlas segment
        out (c),a
        inc hl
        ld a,(play_source_low)
        .if piece == 0
        add a,4                         ; top tile crop
        .endif
        out0 (SAR0L),a
        ld a,e
        out0 (DAR0L),a
        ld a,d
        out0 (DAR0H),a
        set_io BCR0L, \count
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        .if piece < 7
        ld a,e
        add a,\count
        ld e,a
        jp nc,1f
        inc d
1:
        .endif
        .set piece, piece + 1
        .endr
        oak_set OAK_READ_SEGMENT, 1
        ld hl,(play_row_group)
        ld d,h
        ld e,l
        ld a,d
        add a,TWIN_ROW
        ld d,a
        ret

; Out: play_row_group the first group of play_row.
row_address:
        ld a,(play_row)
        ld l,a
        ld h,row_offset_low >> 8
        ld e,(hl)
        inc h
        ld d,(hl)
        ld (play_row_group),de
        ret

; Copy play_row and its twin from the clean page to the back page.
back_row:
        ld hl,(play_row_group)
        ld e,l
        ld a,(play_back_high)
        add a,h
        ld d,a
        call copy_row
        ld a,d
        add a,TWIN_ROW
        ld d,a
        jp copy_row

; DMA one row of groups from HL to DE.
copy_row:
        ld a,l
        out0 (SAR0L),a
        ld a,h
        out0 (SAR0H),a
        ld a,e
        out0 (DAR0L),a
        ld a,d
        out0 (DAR0H),a
        set_io BCR0L, GROUPS_PER_ROW
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        ret

        .section .text.entry_begin,"ax",@progbits

; Card entry from the firmware, before the video mode.
entry_begin:
        set_io CBAR, 0xC8
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
        ld a,0x33                       ; pel panning
        out (c),a
        xor a
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
        set_io CBAR, 0xC2
        set_io BBR, 0x10
        set_io CBR, 0x84
        ret
rgb_first_raster_threshold:
        .word 0xFFFF
rgb_half_raster_threshold:
        .word RGB_HALF_RASTER_THRESHOLD

        .section .text.entry_staging_done,"ax",@progbits

entry_staging_done:
        ret                             ; the reclaimed tables are installed
