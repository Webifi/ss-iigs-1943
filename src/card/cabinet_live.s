; Live initials overlay of the ordinary game and the cabinet damage marks.
; Runs from SRAM through common area 1; its glyph lists are read through
; BBR at $C000.

        .include "vga.inc"

        .global cab_live_receive, cab_live_helper, cab_live_damage, cab_live_bounds

        .equ LIVE_FIELDS, 0x02          ; cab_font_flags: the packet has live fields
        .equ NORMAL_FONT, 0x01
        .equ ALTERNATE_FONT, 1
        .equ LIVE_TRAILER_BYTES, 14
        .equ DISPLAY_FIELD_BYTES, 12
        .equ DRAWN, 0x80                ; cab_live_layout: list already drawn
        .equ MODE_DEMO, 3               ; cabinet_mode values
        .equ MODE_ENDING, 17
        .equ MODE_RESULT, 30
        .equ MODE_LIVE_ONLY, 85
        .equ MODE_PAUSE, 127
        .equ LIVE_ROW, 232              ; first screen row of the live text
        .equ LIVE_ROWS, 16

        .section .text.cabinet_live,"ax",@progbits

; Copy the optional live fields from the packet trailer at HL.
cab_live_receive:
        ld a,(cab_font_flags)
        bit 1,a
        jp z,receive_none
        ld de,cab_live_values
        ld bc,LIVE_TRAILER_BYTES
        ldir
        ld a,(cab_font_flags)
        and NORMAL_FONT
        ld (cab_font_flags),a
        jp world_upload_batch
receive_none:
        xor a
        ld (cab_live_layout),a
        jp world_upload_batch

; Draw the live list once, then mark the damage of the cabinet pictures.
cab_live_helper:
        ld a,(cabinet_mode)
        cp MODE_PAUSE
        jp z,cab_damage_done
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
        and 0x7F
        dec a
        add a,a
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
        ld a,ALTERNATE_FONT
        ld (cab_font_flags),a
        xor a
        ld (cab_foreground_filter),a
        ld a,0xFF                       ; all live text
        ld (cab_overlay_count),a
        ; The direct gameplay path skips the ordinary layout setup. Restore the
        ; same Oak write mode and map mask before its first prepared glyph.
        ld a,(cabinet_mode)
        cp MODE_LIVE_ONLY
        jp nz,live_draw
        gc_set GC_MODE, 0x40
        seq_set SEQ_MAP_MASK, 0x0F
        oak_set OAK_WRITE_SEGMENT, 0
live_draw:
        jp cabinet_overlay_next

cab_live_damage:
        ld a,(cabinet_mode)
        cp MODE_DEMO
        ld hl,cab_damage_demo
        jp c,damage_loop
        cp MODE_ENDING
        ld hl,cab_damage_idle
        jp c,damage_loop
        cp MODE_RESULT
        jp c,damage_extra
        cp MODE_LIVE_ONLY
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
        cp MODE_ENDING
        jp c,damage_check
        cp MODE_RESULT
        jp c,cab_damage_done
damage_check:
        ld a,(cab_live_layout)
        and 0x7F
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
