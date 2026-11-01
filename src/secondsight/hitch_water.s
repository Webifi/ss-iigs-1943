; Hitch water: batch complete water rows when a ship slide starts
; (scroll_pan_slide = 1) or the ring wraps. The final placement
; (scroll_pan_slide = 2) gets no refresh. Runs from SRAM through common
; area 1 (secondsight.ld .bank_code).

        .include "video.inc"
        .include "water.inc"

        .global hitch_water_banked, hitch_ship_banked

        .equ STATIC_CROP, 4             ; first visible group without panning

        .section .vars.hitch_water,"aw",@nobits
hitch_marked_view: .ds.b 1              ; 1: hitch_ship_banked marked the whole view
hitch_pattern_row: .ds.b 1              ; the water pattern row of the next chunk
hitch_pattern_period: .ds.b 1           ; STAGE_PERIOD or LIGHT_PERIOD

        .section .text.hitch_water,"ax",@progbits

; hitch_water_banked: with moving overlays, replace each whole visible row
; with water before the ship pass: DMA copies of the water pattern, one
; chunk for each pass through the pattern. Static and anchored refreshes
; keep the silhouette-aware path.
; Out: carry set when the full refresh is done. AF, BC, DE, HL changed.
hitch_water_banked:
        ld a,(bg_moving_objects)
        or a
        ret z
        ld a,(sea_active)               ; set only inside combined_sea
        or a
        ret nz
        ld a,(scroll_light_water)
        or a
        jp nz,light
        ld hl,(scene_fg_camera)
        ld de,PAGE_ROWS - 1             ; last world row of the view
        add hl,de
        call water_mod30
        ld b,a
        ld a,STAGE_PERIOD - 1
        sub b
        ld b,STAGE_PERIOD
        jp start
light:
        ld a,(scroll_sea_camera)
        neg
        and LIGHT_PERIOD - 1
        ld b,LIGHT_PERIOD
start:
        ld (hitch_pattern_row),a
        ld a,b
        ld (hitch_pattern_period),a
        ld hl,PAGE_ROWS
        ld (scroll_left_count),hl       ; rows left to draw
        ld hl,(scene_screen_base)
        ld (scroll_dest),hl
        gc_set GC_MODE, GC_MODE_256 | 1
        seq_set SEQ_MAP_MASK, ALL_PLANES
        oak_set OAK_WRITE_SEGMENT, 0
        ld a,(water_pattern_segment)
        ld d,a
        ld bc,OAK_INDEX
        ld a,OAK_READ_SEGMENT
        out (c),a
        inc c
        out (c),d
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
; hitch_chunk: one DMA copy from the pattern row hitch_pattern_row to the
; end of the pattern, or to the end of the view.
hitch_chunk:
        ld a,(hitch_pattern_row)
        call water_row_address
        push hl
; B = rows left in the pattern, or the rows left to draw if fewer.
        ld a,(hitch_pattern_row)
        ld b,a
        ld a,(hitch_pattern_period)
        sub b
        ld b,a
        ld hl,(scroll_left_count)
        ld a,h
        or a
        jp nz,count
        ld a,l
        cp b
        jp nc,count
        ld b,a
count:
        ld e,b
        ld d,0
        or a
        sbc hl,de
        ld (scroll_left_count),hl
; Copy B rows of water from the pattern (on the stack) to scroll_dest.
        ld l,b
        ld h,0
        call state_times56
        push hl
        out0 (BCR0L),l
        out0 (BCR0H),h
        ld de,(scroll_dest)
        pop hl
        add hl,de
        ld (scroll_dest),hl
        pop hl
        ld a,l
        out0 (SAR0L),a
        ld a,h
        out0 (SAR0H),a
        ld a,e
        out0 (DAR0L),a
        ld a,d
        out0 (DAR0H),a
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        xor a                           ; the next chunk starts at pattern row 0
        ld (hitch_pattern_row),a
        ld hl,(scroll_left_count)
        ld a,h
        or l
        jp nz,hitch_chunk
        set_io BCR0H, 0
        scf
        ret

; hitch_ship_banked: mark the old, unpanned ship for repair before its
; first moving frame is drawn: each foreground row of the old map adds its
; ship bounds to the damage, then scroll_old_rows lists the marked rows
; again. If a row has no ship layout, the full water refresh stays.
; AF, BC, DE, HL changed.
hitch_ship_banked:
        ld a,(scroll_wrap)
        or a
        ret nz
        ld a,(sea_active)               ; set only inside combined_sea
        or a
        ret nz
        ld a,(bg_moving_objects)
        or a
        ret z
        in0 a,(BBR)
        push af
        ld a,(bg_first_column)
        push af
        ld hl,(scroll_current_map)
        push hl
        ld a,(scroll_old_map)
        ld (scroll_current_map+1),a
        ld a,STATIC_CROP
        ld (bg_first_column),a
        xor a
        ld (scroll_row),a
mark_row:
        call combined_position
        ld a,1
        ld (ship_row_count),a
        ld a,(scroll_world_row)
        ld l,a
        ld h,row_classes >> 8
        ld a,(hl)
        or a
        jp z,mark_next                  ; no foreground in this row
        call ship_row_layout
        jp nz,mark_failure
        call ship_height
        call ship_damage_bounds
        call combined_ship_damage
mark_next:
        ld a,(ship_row_count)
        ld b,a
        ld a,(scroll_row)
        add a,b
        ld (scroll_row),a
        jp nc,mark_row
        ld a,1                          ; the whole view is marked
        jp mark_restore
mark_failure:
        xor a                           ; keep the full refresh
mark_restore:
        ld (hitch_marked_view),a
        pop hl
        ld (scroll_current_map),hl
        pop af
        ld (bg_first_column),a
        pop af
        out0 (BBR),a
        ld a,(hitch_marked_view)
        or a
        ret z
        ; Rebuild the sorted old-damage list after adding the ship bounds.
        ld a,(scroll_old_map)
        ld h,a                          ; the old damage map: left, right of each row
        ld l,1                          ; first right bound
        ld de,scroll_old_rows
        ld b,0
list_row:
        ld a,(hl)
        or a
        jp z,list_next
        ld a,b
        ld (de),a
        inc de
list_next:
        inc hl
        inc hl
        inc b
        jp nz,list_row
        ex de,hl
        ld de,scroll_old_rows
        or a
        sbc hl,de
        ld (scroll_old_count),hl
        xor a                           ; no full water refresh
        ld (scroll_pan_slide),a
        ret
