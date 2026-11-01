; Live initials overlay of the ordinary game and the cabinet damage marks.
; Runs from SRAM through common area 1 (secondsight.ld .bank_code); its
; glyph lists (gen/cabinet_live_lists.s, cab_live_pointers) are read
; through BBR at $C000.

        .include "video.inc"
        .include "cabinet_layouts.inc"
        .include "stream.inc"

        .global cab_live_receive, cab_live_helper, cab_live_damage, cab_live_bounds

; cab_font_flags: the TRAILER_FLAGS byte of the packet.
        .equ FONT_FLAG, 0x01            ; 1: the alternate font (the ending)
        .equ LIVE_FIELDS_BIT, 1         ; 1: the live fields follow the trailer
; The live fields (src/game_world.s): the display fields, then the layout word.
        .equ LIVE_TRAILER_BYTES, TRAILER_LIVE_LAYOUT + 2
        .equ DISPLAY_FIELD_BYTES, TRAILER_LIVE_LAYOUT
        .equ DRAWN, 0x80                ; cab_live_layout: list already drawn
        .equ LIVE_LAYOUT, 0x7F          ; cab_live_layout: the live layout, 1-8
        .equ LIVE_ROW, 232              ; first screen row of the live text
        .equ LIVE_ROWS, 16

        .section .text.cabinet_live,"ax",@progbits

; cab_live_receive: copy the optional live fields from the packet trailer
; at HL into cab_live_values (12 display bytes, then cab_live_layout and a
; 0 byte over cab_alternate_font), or clear cab_live_layout. Then the upload
; list: world_upload_batch. Runs through cab_live_receive_map (cabinet.s).
cab_live_receive:
        ld a,(cab_font_flags)
        bit LIVE_FIELDS_BIT,a
        jp z,receive_none
        ld de,cab_live_values
        ld bc,LIVE_TRAILER_BYTES
        ldir
        ld a,(cab_font_flags)
        and FONT_FLAG                   ; the live fields are taken
        ld (cab_font_flags),a
        jp world_upload_batch
receive_none:
        xor a
        ld (cab_live_layout),a
        jp world_upload_batch

; cab_live_helper: draw the live list of cab_live_layout once (through the
; overlay drawing of cabinet.s), then mark the damage of the cabinet
; pictures. Runs through cab_live_map.
cab_live_helper:
        ld a,(cab_hidden_prepaint)
        or a
        jp nz,cab_live_damage
        ld a,(cab_live_layout)
        or a
        jp z,cab_live_damage
        bit 7,a
        jp nz,cab_live_damage
        or DRAWN
        ld (cab_live_layout),a
        and LIVE_LAYOUT
        dec a
        add a,a                         ; a word for each live layout
        ld l,a
        ld h,0
        ld de,cab_live_pointers
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (cab_overlay_cursor),de
        ld a,bank_code__load__bbr
        ld (cab_overlay_cursor+2),a
        ld hl,cab_live_values
        ld de,cabinet_values+1          ; display fields
        ld bc,DISPLAY_FIELD_BYTES
        ldir
        ld a,FONT_FLAG
        ld (cab_font_flags),a
        xor a
        ld (cab_foreground_filter),a
        ld a,0xFF                       ; all live text
        ld (cab_overlay_count),a
        ; The direct gameplay path skips the ordinary layout setup. Restore the
        ; same Oak write mode and map mask before its first prepared glyph.
        ld a,(cabinet_mode)
        cp LAYOUT_LIVE
        jp nz,live_draw
        gc_set GC_MODE, GC_MODE_256
        seq_set SEQ_MAP_MASK, ALL_PLANES
        oak_set OAK_WRITE_SEGMENT, 0
live_draw:
        jp cabinet_overlay_next

; cab_live_damage: mark for repair the rows that the cabinet picture of
; cabinet_mode covers (gen/cab_damage.s: cab_damage_demo, cab_damage_idle,
; cab_damage_result lists of rows, row, left, right; 0 ends a list), then
; the rows of the live text. Then cab_damage_done (cabinet.s).
cab_live_damage:
        ld a,(cabinet_mode)
        cp PAGE_RANKING_FIRST
        ld hl,cab_damage_demo
        jp c,damage_loop
        cp PAGE_ENDING_FIRST
        ld hl,cab_damage_idle
        jp c,damage_loop
        cp PAGE_ENDING_END
        jp c,damage_extra
        cp LAYOUT_LIVE
        jp z,damage_extra
        ld hl,cab_damage_result
damage_loop:
        ld a,(hl)                       ; rows; 0 ends the list
        or a
        jp z,damage_extra
        ld b,a
        inc hl
        ld a,(scene_ring_start)
        add a,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        call scroll_mark
        pop hl
        jp damage_loop
damage_extra:
        ; Static ending pictures do not use the gameplay damage map.
        ld a,(cabinet_mode)
        cp PAGE_ENDING_FIRST
        jp c,damage_check
        cp PAGE_ENDING_END
        jp c,cab_damage_done
damage_check:
        ld a,(cab_live_layout)
        and LIVE_LAYOUT
        jp z,cab_damage_done
        dec a
        add a,a
        ld l,a
        ld h,0
        ld de,cab_live_bounds
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(scene_ring_start)
        add a,LIVE_ROW
        ld b,LIVE_ROWS
        call scroll_mark
        jp cab_damage_done

; Group bounds (right, left) of live layouts 1-8: layout % 3 selects the
; left field, layout / 3 the right one.
cab_live_bounds:
        .byte 28,0, 28,0, 56,28, 56,0, 56,0, 56,28, 56,0, 56,0
