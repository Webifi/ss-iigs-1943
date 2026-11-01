; Sea features: draw the stored 32 x 32 tiles of the ROM sea banks 3-5 at
; the sea camera position, below the cloud silhouette. Each tile is drawn
; in bands of rows. A band row is copied as one rectangle where the cloud
; gap table leaves it open, else through the masked water runs of the row
; with the tile as the source. Each drawn row is marked as damage.

        .include "video.inc"
        .include "rows.inc"
        .include "water.inc"
        .include "stream.inc"

        .global combined_sea, sea_active, sea_source, sea_segment, sea_spare
        .global sea_row_reverse, sea_rectangle_reverse, sea_source_pitch, sea_source_carry
        .global sea_sram, sea_next_position

; sea_sram maps SEA_SRAM + HL at WINDOW_C000; the directory and the
; command records (scripts/game_sea.py) are SEA_SRAM offsets: with
; SEA_SRAM 0x10000, the low 16 bits of a load address (LABEL__low16). A
; secondsight.ld check keeps the sea data in that 64 KB bank.
        .equ SEA_SRAM, 0x10000
        .equ DIRECTORY_COLUMNS, 1024    ; sea_directory: one word for each sea map column
        .equ VIEW_COLUMNS, 9            ; tile columns that the view can touch
        .equ TILE_ROWS, 32
        .equ TILE_ROW_SHIFT, 5          ; log2 TILE_ROWS
        .equ TILE_PITCH, 8              ; groups per tile row
        .equ BAND_BYTES, 7              ; a band command
        .equ MAX_BAND_BYTES, 252        ; the commands of a column (scripts/game_sea.py)
        .equ FIRST_FEATURE_BANK, 0x30   ; the first sea bank with features (SEA_BANK bits)
        .equ SEA_ROW_HIGH, 0x0F         ; the row bits of the camera high byte in a bank
        .equ SEGMENT_MASK, 0x7F         ; band segment byte: bit 7 the rows are reversed
        .equ OCCUPANCY_TEST, 1          ; sea_occupancy_access mode

; The sea state (secondsight.ld .playfield: zero at load).
        .section .vars.sea_features,"aw",@nobits
sea_active: .ds.b 1                     ; 1 while combined_sea draws
sea_source: .ds.b 2                     ; tile row for combined_water
sea_segment: .ds.b 1                    ; Oak segment of the tile
sea_map_column: .ds.b 2                 ; the sea map column of the tile column
sea_tile_top: .ds.b 2                   ; signed view row of the tile top
sea_columns_left: .ds.b 1               ; tile columns left to draw
sea_band: .ds.b 2                       ; next band command
sea_bands_left: .ds.b 1                 ; bands left in this column
sea_rows_left: .ds.b 1                  ; rows left in this band
sea_tile_base: .ds.b 2                  ; tile address in its segment

; The band commands of the current column (secondsight.ld .scratch).
        .section .vars.sea_bands,"aw",@nobits
sea_bands: .ds.b MAX_BAND_BYTES

        .section .text.combined_sea,"ax",@progbits

; combined_sea: draw the sea features of the visible tile columns (the
; sea_directory command records), unless the sea layer is off or the sea
; bank has no features. AF, BC, DE, HL changed.
combined_sea:
        ld a,(scene_effect_flags)
        rrca                            ; bit 0: SPF_BG2_OFF
        ret c
        ld a,(scroll_sea_camera + 1)
        and SEA_BANK
        cp FIRST_FEATURE_BANK
        ret c
; The sea position follows the palette water clock, in the bank that the
; stage selected. Its wrap at row 0xF00 is the wrap of the native camera.
        ld hl,(scene_fg_camera)
        ld de,(scroll_relative)
        add hl,de
        ld a,h
        and SEA_ROW_HIGH
        cp SEA_ROW_HIGH                 ; end of the sea band
        jr c,camera_low
        xor a
camera_low:
        ld b,a
        ld a,(scroll_sea_camera + 1)
        and SEA_BANK
        or b
        ld h,a
        ld a,l
        and TILE_ROWS - 1
        add a,-TILE_ROWS & 0xFF         ; top of the first tile
        ld e,a
        ld d,0
        ld (sea_tile_top),de
        .rept TILE_ROW_SHIFT
        srl h
        rr l
        .endr
        ld (sea_map_column),hl
        ld a,VIEW_COLUMNS
        ld (sea_columns_left),a
; The water runs keep their source operands: both pattern widths are 63
; (water_camera) and a run starts below 56, so `and 63` keeps it.
        ld a,1
        ld (sea_active),a
column:
        ld hl,(sea_map_column)
        ld a,h
        and (DIRECTORY_COLUMNS >> 8) - 1
        ld h,a
        add hl,hl
        ld de,sea_directory__low16
        add hl,de
        call sea_sram
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        or e
        jp z,next_column
        ex de,hl
        call sea_sram
        ld a,(hl)
        or a
        jp z,next_column
        ld (sea_bands_left),a
        inc hl
        ld c,a
        .rept 3
        add a,a
        .endr
        sub c                           ; BAND_BYTES for each band
        ld c,a
        ld b,0
        ld de,sea_bands
        ldir
        ld hl,sea_bands
        ld (sea_band),hl

; Band command: tile address, segment (bit 7: rows reversed), left and right
; screen groups, first row, row count.
band:
        ld hl,(sea_band)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (sea_tile_base),de
        ld a,(hl)
        inc hl
        ld b,a
        and SEGMENT_MASK
        ld (sea_segment),a
        ld a,b
        rlca
        sbc a,a
        ld b,a
        and TILE_ROWS - 1
; Most neighbor tiles have the same orientation. Keep the patched operands
; when it does not change.
        ld c,a
        ld a,(sea_row_reverse+1)
        cp c
        ld a,c
        jr z,orientation_ready
        ld (sea_row_reverse+1),a
        ld (sea_rectangle_reverse+1),a
        ld a,b
        and 0xF0
        add a,TILE_PITCH                ; or -TILE_PITCH for reversed rows
        ld (sea_source_pitch+1),a
        ld a,b
        ld (sea_source_carry+1),a
orientation_ready:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (scroll_left),de
        ld e,(hl)                       ; first row of the band
        inc hl
        ld b,(hl)                       ; rows of the band
        inc hl
        ld (sea_band),hl
; The band top is sea_tile_top + first row. sea_tile_top stays the tile
; top for the source row. The view is rows 0-255.
        ld d,0
        ld hl,(sea_tile_top)
        add hl,de
        ld a,h
        or a
        jr nz,clip_top
        ld a,l
        ld (scroll_row),a
        add a,b
        jr nc,rows_ready
        ld a,l
        neg                             ; rows to the bottom of the view
        ld b,a
        jr rows_ready
clip_top:
        inc h                           ; below the view if not -1
        jr nz,band_done
        xor a
        ld (scroll_row),a
        ld a,l
        add a,b
        jr nc,band_done
        ld b,a
; At a 32-row boundary the ninth tile is fully above the view and has no
; visible rows. An 8-bit loop that starts at 0 draws 256 rows from beyond
; the tile.
rows_ready:
        ld a,b
        or a
        jr z,band_done
        ld (sea_rows_left),a
        call combined_position
        call sea_clear_band
        jr c,band_done
        jr row_positioned               ; the failed rectangle check keeps the first row position
row:
        call sea_next_position
row_positioned:
        ld a,(bg_pan)
        or a
        jr nz,row_visible
        ld a,(scroll_world_row)
        ld l,a
        ld h,row_classes >> 8
        ld a,(hl)
        and ROW_OPAQUE_VIEW
        jr nz,next_row
; The banked map skips the rows that the foreground covers fully.
        ld a,(bg_moving_objects)
        or a
        jr nz,row_visible
        ld c,OCCUPANCY_TEST
        call sea_occupancy_access
        jr z,row_mark
row_visible:
        ld a,(sea_tile_top)
        ld b,a
        ld a,(scroll_row)
        sub b
sea_row_reverse:
        xor 0                           ; patched: TILE_ROWS - 1 for reversed rows
        ld l,a
        ld h,0
        .rept 3
        add hl,hl
        .endr
        ld de,(sea_tile_base)
        add hl,de
        ld (sea_source),hl
        call combined_water
row_mark:
        ld a,(scroll_left)
        ld d,a
        ld a,(scroll_right)
        ld e,a
        ld a,(scroll_row)
        ld b,a
        ld a,(scene_ring_start)
        add a,b
        ld b,1
        call scroll_mark
next_row:
        ld a,(scroll_row)
        inc a
        ld (scroll_row),a
        ld a,(sea_rows_left)
        dec a
        ld (sea_rows_left),a
        jr nz,row
band_done:
        ld a,(sea_bands_left)
        dec a
        ld (sea_bands_left),a
        jp nz,band
next_column:
        ld hl,(sea_tile_top)
        ld de,-TILE_ROWS & 0xFFFF
        add hl,de
        ld (sea_tile_top),hl
        ld hl,(sea_map_column)
        inc hl
        ld (sea_map_column),hl
        ld a,(sea_columns_left)
        dec a
        ld (sea_columns_left),a
        jp nz,column
        xor a
        ld (sea_active),a
        ret
; sea_spare: without these bytes the allocator moves the HUD dispatch to
; 0xB7F0 and a sparse sprite blob into the firmware ranges. The first 16
; bytes hold the Tsunami painter's state of each page (special_wave_draw,
; special_wave.s).
sea_spare:
        .fill 34, 1, 0

; sea_clear_band: copy the visible rows of the band as one rectangle in all
; planes, if the cloud gap table (water_left_bounds, water_right_bounds)
; leaves the band open in each row. Out: carry set when the band is drawn.
; AF, BC, DE, HL changed.
sea_clear_band:
; With bg_pan set the whole band is copied without the cloud mask. This is
; correct only if no pan happens over islands under clouds (not checked).
        ld a,(bg_pan)
        or a
        jr nz,rectangle
        ld a,(scroll_left)
        ld d,a
        ld a,(scroll_right)
        ld e,a
        ld a,(scroll_world_row)
        ld l,a
        ld h,water_left_bounds >> 8
        ld a,(sea_rows_left)
        ld b,a
gap_check:
        ld a,d
        cp (hl)
        jr c,gap_failed
        inc h                           ; water_right_bounds
        ld a,(hl)
        cp e
        jr c,gap_failed
        dec h
        dec l
        djnz gap_check
        jr rectangle
gap_failed:
        or a
        ret
rectangle:
        ld a,(scroll_left)
        ld d,a
        ld a,(scroll_right)
        ld e,a
        ld a,(scroll_row)
        ld b,a
        ld a,(scene_ring_start)
        add a,b
        ld c,a
        ld a,(sea_rows_left)
        ld b,a
        ld a,c
        call scroll_mark
        ld a,(sea_segment)
        ld d,a
        ld bc,OAK_INDEX
        ld a,OAK_READ_SEGMENT
        out (c),a
        inc c
        out (c),d
        seq_set SEQ_MAP_MASK, ALL_PLANES
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        ld a,(sea_tile_top)
        ld b,a
        ld a,(scroll_row)
        sub b
sea_rectangle_reverse:
        xor 0                           ; patched: TILE_ROWS - 1 for reversed rows
        ld l,a
        ld h,0
        .rept 3
        add hl,hl
        .endr
        ld de,(sea_tile_base)
        add hl,de
        ld a,(scroll_left)
        ld e,a
        ld d,0
        add hl,de
        push hl
        ld hl,(scroll_dest)
        add hl,de
        ex de,hl
        pop hl
        ld a,(scroll_left)
        ld b,a
        ld a,(scroll_right)
        sub b
        ld c,a                          ; groups
        ld a,(sea_rows_left)
        ld b,a
rectangle_row:
        out0 (SAR0L),l
        out0 (SAR0H),h
        out0 (DAR0L),e
        out0 (DAR0H),d
        out0 (BCR0L),c
        set_io DSTAT, DSTAT_DE0 | DSTAT_DME
        ld a,l
sea_source_pitch:
        add a,TILE_PITCH                ; patched: -TILE_PITCH for reversed rows
        ld l,a
        ld a,h
sea_source_carry:
        adc a,0                         ; patched: 0xFF for reversed rows
        ld h,a
        ld a,e
        add a,GROUPS_PER_ROW
        ld e,a
        ld a,d
        adc a,0
        ld d,a
        dec b
        jr nz,rectangle_row
        scf
        ret

        .section .text.sea_helpers,"ax",@progbits

; sea_sram: map SRAM SEA_SRAM + HL at WINDOW_C000 through BBR. Out: HL the
; logical address. AF changed.
sea_sram:
        ld a,h
        .rept 4
        rrca
        .endr
        and 0x0F
        add a,(SEA_SRAM - WINDOW_C000) >> 12 ; BBR of SRAM SEA_SRAM at WINDOW_C000
        out0 (BBR),a
        ld a,h
        and 0x0F
        or WINDOW_C000 >> 8
        ld h,a
        ret

; sea_next_position: move to the next sea row: the world row goes down by
; one, the screen address goes down one row. DE, HL changed.
sea_next_position:
        ld hl,(scroll_world_row)
        dec hl
        ld (scroll_world_row),hl
        ld hl,(scroll_dest)
        ld de,GROUPS_PER_ROW
        add hl,de
        ld (scroll_dest),hl
        ret
