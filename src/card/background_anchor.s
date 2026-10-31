; Canonical background rows, indexed by world position and independent of sea
; motion. Each display page keeps an anchor: the world row drawn at its
; physical row 0. Each row also has a twin; the clean twin is the one outside
; the part being scanned out.

        .global background_clean_address, background_ship_source
        .global bg_anchors, bg_old_fg_camera, bg_direct, bg_clean_base, bg_clean_limit
        .global bg_clean_bias, bg_move_count, bg_reverse, bg_signed_delta, bg_move_down
        .global bg_new_start, bg_reuse

        .equ SCREEN_PITCH, 56           ; groups per row
        .equ DISPLAY_RESERVATION, 0x400 ; first group of a display page

        .section .vars.background_anchor,"aw",@nobits
bg_anchors:             .ds.b 4         ; per page: world row at physical row 0
bg_old_fg_camera:       .ds.w 1
bg_direct:              .ds.b 1
bg_clean_base:          .ds.w 1
bg_clean_limit:         .ds.b 1         ; rows left in the clean twin; 0 means 256
bg_clean_bias:          .ds.w 1
bg_move_count:          .ds.b 1
bg_reverse:             .ds.b 1
bg_signed_delta:        .ds.b 1
bg_move_down:           .ds.b 1
bg_new_start:           .ds.b 1
bg_reuse:               .ds.b 1

        .section .text.background_anchor,"ax",@progbits

; In: C page. Out: HL screen address of world row SCROLL_WORLD_ROW in the
; page's clean twin; bg_clean_limit rows remain in that twin.
background_clean_address:
        ld a,c
        add a,bg_anchors & 0xff
        ld l,a
        ld h,bg_anchors >> 8
        ld b,(hl)
        ld a,(scroll_world_row)
        ld e,a
        ld a,b
        sub e
        ld e,a                          ; physical row
        ld a,c
        add a,scroll_origins & 0xff
        ld l,a
        ld h,scroll_origins >> 8
        ld a,(hl)
        sub e
        jp c,upper
        jp z,upper
        ld h,0                          ; lower twin
        jp half
upper:
        xor a
        sub e
        ld h,1                          ; upper twin
half:
        ld (bg_clean_limit),a
        ld l,e
        call state_times56
        ld de,DISPLAY_RESERVATION
        add hl,de
        ld a,c
        rrca
        or h
        ld h,a
        ret

; Ship source rows come from the clean background twin of the page being
; drawn. In: HL column metadata (kept). Out: bg_clean_base, bg_clean_bias, and
; ship_row_count clamped to the rows left in the twin.
background_ship_source:
        push hl
        ld a,(scroll_page_index)
        ld c,a
        call background_clean_address
        ld (bg_clean_base),hl
        ld de,(scroll_dest)
        or a
        sbc hl,de
        ld (bg_clean_bias),hl
        ld a,(ship_row_count)
        ld b,a
        ld a,(bg_clean_limit)
        or a
        jp z,source_done
        cp b
        jp nc,source_done
        ld (ship_row_count),a
source_done:
        pop hl
        ret
