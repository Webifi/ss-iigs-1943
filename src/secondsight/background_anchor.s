; Background anchors: the canonical background rows, indexed by world
; position and independent of sea motion. Each display page keeps an anchor: the world row drawn at its
; physical row 0. Each row also has a twin; the clean twin is the one outside
; the part being scanned out.

        .global background_clean_address, background_ship_source
        .global bg_anchors, bg_old_fg_camera, bg_direct, bg_clean_base, bg_clean_limit
        .global bg_clean_bias, bg_move_count, bg_reverse, bg_signed_delta, bg_move_down
        .global bg_new_start, bg_reuse, scroll_relative

        .include "video.inc"


; The background camera state of the page that the card draws. The
; motion code (background_motion.s, combined_scroll.s) sets most of it
; (secondsight.ld .playfield: zero at load). An 8-bit page index reads
; bg_anchors: it stays in one 256-byte page.
        .section .vars.background_anchor,"aw",@nobits
        .balign 2
bg_anchors:             .ds.b 2         ; per page (scroll_page_index): world row at physical row 0
scroll_relative:        .ds.w 1         ; sea camera - foreground camera (water_camera)
bg_old_fg_camera:       .ds.w 1         ; the foreground camera of the last picture of this page
bg_direct:              .ds.b 1         ; 1: the anchor did not move; rows repair from the static source
bg_clean_base:          .ds.w 1         ; screen address of scroll_world_row in the clean twin
bg_clean_limit:         .ds.b 1         ; rows left in the clean twin; 0 means 256
bg_clean_bias:          .ds.w 1         ; bg_clean_base - scroll_dest: clean source to destination
bg_move_count:          .ds.b 1         ; rows that a wrap moves between the twins
bg_reverse:             .ds.b 1         ; 0xFF: the camera moves down the map (rows enter at the bottom)
bg_signed_delta:        .ds.b 1         ; the camera move in rows, signed
bg_move_down:           .ds.b 1         ; not 0: a wrap copies the lower twin over the upper one
bg_new_start:           .ds.b 1         ; the first new row of a reverse move, else 0
bg_reuse:               .ds.b 1         ; 0xFF: the other page shows a camera within 256 rows of this one

        .section .text.background_anchor,"ax",@progbits

; background_clean_address: where world row scroll_world_row is in the
; clean twin of page C. The physical row is the anchor minus the world row;
; the rows below the scan origin of the page (scroll_origins) are in the
; lower twin, the others in the upper twin.
; In: C page (0 or 1). Out: HL the screen address; A and bg_clean_limit the
; rows left in that twin (0: 256). B, DE changed.
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
        ld b,PAGE_START >> 8            ; lower twin
        jp half
upper:
        xor a
        sub e
        ld b,(PAGE_START + PAGE_ROWS * GROUPS_PER_ROW) >> 8 ; upper twin: PAGE_ROWS rows further on
        .if (PAGE_START | PAGE_ROWS * GROUPS_PER_ROW) & 0xFF
        .error "background_clean_address adds PAGE_START and the twin as whole pages"
        .endif
half:
        ld (bg_clean_limit),a
        ld l,e
        call state_times56
        ld a,h
        add a,b                         ; + PAGE_START and the twin (whole pages)
        ld h,a
        ld a,c
        rrca                            ; page 1: bit 7 of the high byte (PAGE_DISTANCE)
        or h
        ld h,a
        ret

; background_ship_source: the ship source rows come from the clean
; background twin of the page that the card draws.
; In: HL column metadata (kept). Out: bg_clean_base, bg_clean_bias, and
; ship_row_count clamped to the rows left in the twin. AF, BC, DE changed.
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
