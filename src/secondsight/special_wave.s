; Special weapon pictures drawn by helpers that the host sends in a packet:
; the Tsunami wave and the Lightning bolt. A helper runs from the receive
; buffer that got it, so each is assembled for both buffers.

        .include "video.inc"

        .global special_wave_draw_buffer1, special_wave_draw_buffer0
        .global special_bolt_draw_buffer1, special_bolt_draw_buffer0
        .global special_hook_draw, special_hook_water

        .equ WAVE_FIRST_GROUP, 68       ; world group where the wave texture starts
        .equ WAVE_LAST_GROUP, 131
        .equ WAVE_START, 255            ; world row of the first wave row, minus 6 per tick
        .equ BOLT_POSE_1, 13            ; special_timer from which pose 0 shows
        .equ BOLT_POSE_2, 7
; The scratch of the painters. The two painters never run in the same
; picture.
        .section .vars.special_scratch,"aw",@nobits
special_scratch: .ds.b 16
; The wave painter. The tail reuses TW_K1 for the odd-chunk mask and
; TW_ACUR for the row's clean source.
        .equ TW_ACUR, special_scratch + 0  ; the accumulator: the W of view row 0
        .equ TW_W, special_scratch + 2  ; the W of the current block
        .equ TW_DST, special_scratch + 4   ; the screen address of the row
        .equ TW_Y, special_scratch + 6  ; the view row
        .equ TW_LEFT, special_scratch + 7  ; the first group of the span
        .equ TW_CNT, special_scratch + 8   ; the groups of the span
        .equ TW_OFF, special_scratch + 9   ; the texture group of the span
        .equ TW_K1, special_scratch + 10   ; the front width; in the tail, the odd-chunk mask
        .equ TW_D2, special_scratch + 11   ; the tail width
        .equ TW_MF, special_scratch + 12   ; TW_FINISH_BIT, TW_STALE_BIT, bits 0-3 flip mask
        .equ TW_G, special_scratch + 13 ; the g of the block
        .equ TW_PH, special_scratch + 14   ; the chunk phase of the row
        .equ TW_MA, special_scratch + 15   ; the even-chunk mask of the row
; The bolt painter.
        .equ special_world, special_scratch + 0       ; the command SP
        .equ special_row, special_scratch + 2         ; the view row (even)
        .equ special_left, special_scratch + 4        ; the first group of the row
        .equ special_dest, special_scratch + 8        ; the row in the WINDOW_E000 window
        .equ special_fourth, special_scratch + 11     ; not 0: the run has a fourth mask
        .equ special_row_address, special_scratch + 13 ; the screen address of the row
; TW_MF bits.
        .equ TW_FINISH_BIT, 7           ; the tail is damage (timer below TW_FINISH)
        .equ TW_STALE_BIT, 6            ; the clean rows are stale
        .equ TW_FLIP_MASK, 0x0F
; The page state (8 bytes for each page in sea_spare, at IX).
        .equ PAGE_TIMER, 0              ; the timers of the last two pictures, newest first
        .equ PAGE_TIMER_OLD, 1
        .equ PAGE_PASSES, 2             ; the pass counter
        .equ PAGE_CLEAN, 3              ; 0 snapshot due, 1 snapshot taken, 2 stale
        .equ PAGE_BIAS, 4               ; the clean-row bias
        .equ PAGE_STATE_SHIFT, 3        ; 8 bytes for each page
        .equ NEW_TIMER, 0x81            ; PAGE_TIMER of a new attack: above any timer
        .equ TIMER_PIXELS, 6            ; the wave moves 6 pixels a tick
        .equ TEXTURE_ROWS, 8            ; texture rows of WAVE_ROW groups (512 groups)
        .equ CHUNK, 32                  ; groups of a tail chunk
        .equ DAMAGE_QUANTUM, 4          ; the bolt marks damage in 4-group steps
        .equ ROW_TABLE, 32              ; tsunami_rows.inc: the ragged-edge bytes
; A bolt run word: the masks in B, in C the delta to the run (bits 5-0)
; and the length (bits 7-6: one, two, three or four masks).
        .equ RUN_DELTA, 0x3F
        .equ RUN_LENGTH, 0xC0
        .equ RUN_FOURTH, 0x40
        .equ FRINGE, 8                  ; front edge groups of a texture row
        .equ WAVE_ROW, 64               ; groups of a texture row
        .equ FRONT_EDGE, 131            ; the front at g - FRONT_EDGE
        .equ TRAIL_EDGE, 95             ; the trailing edge at g - TRAIL_EDGE
        .equ TW_FINISH, 24              ; from this timer down the tail is damage
        .equ TW_CAP, 12                 ; most timer ticks drawn in one picture

; Tsunami painter. The sea and the camera stand still during the attack, so
; the wave stays painted on each page. Each picture paints the advancing
; front (a ragged foam edge from the 1943ua wave art, then the white body),
; foams again the rows whose sprite damage was just repaired, and returns
; the background behind the wave from the page's clean rows in two passes of
; a random two of every four pixels per row (scripts/special_wave.py).
;
; Geometry at timer T (the 1943ua accumulator, six pixels per tick): row Y
; has W = T*6 + 255 - Y and g = W/4 groups, so g changes every four rows;
; the loops work in those blocks. The front is at g - FRONT_EDGE less a
; ragged offset from the row table at (g + T). The clean rows are the
; game's own repair source but hold stale water under light-water ships: on
; each page's first wave picture the visible background is copied into them
; once. If the ships move after that, the tail is marked as ordinary damage.
;
; Per-page state, 8 bytes per page in sea_spare: the timers of the page's
; last two pictures (newest first), the pass counter, the clean-row state
; (1 snapshot taken, 2 stale) and the clean-row bias.
        .macro special_wave_draw
        push ix
        ld a,(scroll_page_index)
        .rept PAGE_STATE_SHIFT
        add a,a
        .endr
        ld e,a
        ld d,0
        ld hl,sea_spare
        add hl,de
        push hl
        pop ix
        ld a,(special_timer)
        ld b,a
        ld a,(ix+PAGE_TIMER)            ; the last timer of this page
        cp b
        jr nc,tw_same\@
        ld (ix+PAGE_TIMER),NEW_TIMER
        ld (ix+PAGE_TIMER_OLD),NEW_TIMER
        ld (ix+PAGE_CLEAN),0            ; snapshot due
tw_same\@:
        ld a,b
        cp TW_FINISH
        sbc a,a
        and 1 << TW_FINISH_BIT
        ld c,a
        ld a,(ix+PAGE_CLEAN)
        dec a
        jr nz,tw_stale\@
        ld a,(bg_moving_objects)
        or a
        jr z,tw_flags\@
        ld (ix+PAGE_CLEAN),2            ; stale
tw_stale\@:
        bit 1,(ix+PAGE_CLEAN)           ; stale
        jr z,tw_flags\@
        set TW_STALE_BIT,c
tw_flags\@:
        ld a,c
        ld (TW_MF),a
        ld a,(ix+PAGE_TIMER)
        sub TW_CAP
        jr c,tw_timer\@
        cp b
        jr c,tw_timer\@
        ld b,a                          ; the drawn timer
tw_timer\@:
        ld a,b
        ld l,a
        ld h,TIMER_PIXELS
        mlt hl
        ld de,WAVE_START
        add hl,de
        ld (TW_ACUR),hl
        ld a,(ix+PAGE_TIMER)
        call tw_span\@
        add a,FRINGE
        ld (TW_K1),a
        ld a,(ix+PAGE_TIMER_OLD)
        call tw_span\@
        ld (TW_D2),a
        ld a,(ix+PAGE_PASSES)
        inc (ix+PAGE_PASSES)
        rrca
        sbc a,a
        and TW_FLIP_MASK                ; the flip mask
        ld hl,TW_MF
        or (hl)
        ld (hl),a
        ld a,(ix+PAGE_TIMER)
        ld (ix+PAGE_TIMER_OLD),a
        ld (ix+PAGE_TIMER),b
        ld e,OAK_WRITE_SEGMENT
        ld a,0
        call tw_oak\@
        ld a,VGA_WINDOW >> 16
        out0 (SAR0B),a
        ld a,VGA_WINDOW >> 16
        out0 (DAR0B),a
        ld a,(ix+PAGE_CLEAN)
        or a
        jr nz,tw_snapped\@
        ld a,(scroll_page_index)
        add a,bg_anchors & 0xFF
        ld l,a
        ld h,bg_anchors >> 8
        ld a,(hl)
        ld hl,scene_fg_camera
        sub (hl)
        inc a
        ld (ix+PAGE_BIAS),a
        ld e,OAK_READ_SEGMENT
        ld a,0
        call tw_oak\@
        call tw_snapshot\@
        inc (ix+PAGE_CLEAN)             ; snapshot taken
tw_snapped\@:
        ld e,OAK_READ_SEGMENT
        ld a,special_wave__vseg         ; the wave texture
        call tw_oak\@
        ld a,(TW_MF)
        rla
        jr c,tw_front\@
        ld hl,(scroll_old_count)
        ld a,h
        or l
        jr z,tw_front\@
        ld de,scroll_old_rows
tw_dirty\@:
        push hl
        push de
        ld a,(de)                       ; the physical row
        ld hl,scene_ring_start
        sub (hl)
        ld (TW_Y),a
        ld e,a
        ld d,0
        ld hl,(TW_ACUR)
        or a
        sbc hl,de
        call tw_g\@
        jr c,tw_dirty_next\@
        ld c,FRONT_EDGE - TRAIL_EDGE - FRINGE
        call tw_fspan\@
        jr z,tw_dirty_next\@
        ld a,(TW_Y)
        ld l,a
        ld h,row_offset_low >> 8
        ld e,(hl)
        inc h
        ld d,(hl)
        ld hl,(scene_screen_base)
        add hl,de
        ld (TW_DST),hl
        call tw_paint\@
tw_dirty_next\@:
        pop de
        pop hl
        inc de
        dec hl
        ld a,h
        or l
        jr nz,tw_dirty\@
tw_front\@:
        call tw_rows_start\@
tw_front_block\@:
        call tw_block\@
        jr c,tw_front_skip\@
        push bc
        ld c,0
        call tw_fspan\@
        pop bc
        jr z,tw_front_skip\@
        call tw_srcaddr\@
        ex de,hl
        call tw_first\@
tw_front_row\@:
        out0 (SAR0L),e
        out0 (SAR0H),d
        out0 (DAR0L),l
        out0 (DAR0H),h
        call tw_go\@
        push de
        ld de,GROUPS_PER_ROW
        add hl,de
        pop de
        ld a,e
        add a,WAVE_ROW
        ld e,a
        jr nc,tw_texture_next\@
        inc d
tw_texture_next\@:
        inc c
        ld a,c
        and TEXTURE_ROWS - 1
        jr nz,tw_front_wrapped\@
        ld a,d
        sub (TEXTURE_ROWS * WAVE_ROW) >> 8 ; back 512 groups: 8 texture rows
        ld d,a
tw_front_wrapped\@:
        ld a,c
        or a
        jr z,tw_tail\@
        djnz tw_front_row\@
        call tw_store\@
        jp tw_front_block\@
tw_front_skip\@:
        call tw_skip\@
        jr nz,tw_front_block\@
tw_tail\@:
        ld e,OAK_READ_SEGMENT
        ld a,0
        call tw_oak\@
        ld bc,VGA_SEQ_INDEX
        ld a,SEQ_MAP_MASK
        out (c),a
        call tw_rows_start\@
tw_tail_block\@:
        call tw_block\@
        jp c,tw_tail_skip\@
        push bc
        ld a,(TW_G)
        add a,(ix+PAGE_TIMER)
        add a,7                         ; the row byte of the tail edge
        call tw_rowbyte\@
        rlca
        rlca
        and 3                           ; bits 7-6: the ragged tail offset
        ld c,a
        ld a,(TW_G)
        ld l,a
        ld h,0
        ld de,TRAIL_EDGE
        or a
        sbc hl,de
        push hl
        ld e,c
        ld d,0
        or a
        sbc hl,de
        call tw_clip\@
        ld (TW_LEFT),a
        pop hl
        ld a,(TW_D2)
        ld e,a
        add hl,de
        call tw_clip\@
        ld (TW_CNT),a
        pop bc
        ld hl,TW_LEFT
        sub (hl)
        jp c,tw_tail_skip\@
        jp z,tw_tail_skip\@
        ld a,(TW_MF)
        and (1 << TW_FINISH_BIT) | (1 << TW_STALE_BIT)
        jp nz,tw_tail_mark\@
        ld hl,(TW_DST)
        ld a,(TW_Y)
        ld c,a
tw_tail_row\@:
        push hl
        call tw_clean\@
        ld a,c
        call tw_rowbyte\@
        ld d,a
        rrca
        rrca
        rrca
        and CHUNK - 1                   ; the chunk phase
        ld (TW_PH),a
        ld a,(TW_MF)
        xor d
        and TW_FLIP_MASK
        ld (TW_MA),a
        ld de,16                        ; the row byte 16 rows on
        add hl,de
        ld a,(TW_MF)
        xor (hl)
        and TW_FLIP_MASK
        ld (TW_K1),a
        pop hl
        ld a,(TW_LEFT)
        ld (TW_OFF),a
tw_tail_piece\@:
        ld a,(TW_PH)
        ld d,a
        ld a,(TW_OFF)
        sub d
        jr c,tw_first_boundary\@
        and ~(CHUNK - 1) & 0xFF
        add a,CHUNK
        add a,d
        jr tw_boundary\@
tw_first_boundary\@:
        ld a,d
tw_boundary\@:
        ld e,a                          ; the boundary
        sub d
        and CHUNK                       ; the chunk parity
        ld a,(TW_MA)
        jr z,tw_mask_chosen\@
        ld a,(TW_K1)
tw_mask_chosen\@:
        push bc
        ld bc,VGA_SEQ_DATA              ; the map mask
        out (c),a
        pop bc
        ld a,(TW_CNT)
        cp e
        jr nc,tw_piece_end\@
        ld e,a
tw_piece_end\@:
        push hl
        ld a,(TW_OFF)
        ld d,a
        add a,l
        ld l,a
        jr nc,tw_dest_ready\@
        inc h
tw_dest_ready\@:
        out0 (DAR0L),l                  ; destination low
        out0 (DAR0H),h                  ; destination high
        ld hl,(TW_ACUR)
        ld a,d
        add a,l
        ld l,a
        jr nc,tw_source_ready\@
        inc h
tw_source_ready\@:
        out0 (SAR0L),l
        out0 (SAR0H),h                  ; source high
        ld a,e
        sub d
        out0 (BCR0L),a                  ; groups
        ld a,DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        out0 (DSTAT),a
        ld a,e
        ld (TW_OFF),a
        pop hl
        ld a,(TW_CNT)
        cp e
        jr nz,tw_tail_piece\@
        ld de,GROUPS_PER_ROW
        add hl,de
        inc c
        jr z,tw_done\@
        dec b
        jp nz,tw_tail_row\@
        ld a,c
        ld (TW_Y),a
        ld (TW_DST),hl
        jp tw_tail_block\@
tw_tail_mark\@:
        push bc
        ld hl,(TW_LEFT)
        ld d,l                          ; left
        ld e,h                          ; right
        ld a,(TW_MF)
        rla                             ; TW_FINISH_BIT
        jr nc,tw_mark_left\@
        ld d,0
tw_mark_left\@:
        ld a,(TW_Y)
        ld hl,scene_ring_start
        add a,(hl)
        call scroll_mark
        pop bc
tw_tail_skip\@:
        call tw_skip\@
        jp nz,tw_tail_block\@
tw_done\@:
        ld bc,VGA_SEQ_DATA              ; the map mask
        ld a,ALL_PLANES
        out (c),a
        pop ix
        ret
; tw_clean: Out: TW_ACUR the clean-row address of view row C (the page
; twin of the anchored row, PAGE_BIAS). DE, HL changed.
tw_clean\@:
        ld a,(ix+PAGE_BIAS)
        add a,c
        ld l,a
        ld h,row_offset_low >> 8
        ld e,(hl)
        inc h
        ld d,(hl)
        ld hl,scene_ring_start
        cp (hl)
        ld a,d
        jr c,tw_clean_lower\@
        add a,TWIN_DISTANCE >> 8        ; the upper twin
tw_clean_lower\@:
        add a,PAGE_START >> 8
        ld hl,scene_page
        or (hl)
        ld d,a
        ld (TW_ACUR),de
        ret
; tw_snapshot: copy the 256 visible rows into the clean rows (the first
; wave picture of a page).
tw_snapshot\@:
        ld hl,(scene_screen_base)
        ld c,0x00                       ; the first row
tw_snapshot_row\@:
        push hl
        call tw_clean\@
        pop hl
        out0 (SAR0L),l
        out0 (SAR0H),h                  ; source high
        out0 (DAR0L),e                  ; destination low
        out0 (DAR0H),d                  ; destination high
        ld a,GROUPS_PER_ROW
        out0 (BCR0L),a                  ; groups
        ld a,DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        out0 (DSTAT),a
        ld de,GROUPS_PER_ROW
        add hl,de
        inc c
        jr nz,tw_snapshot_row\@
        ret
; tw_span: the groups that the wave moves from timer A to timer B:
; ((A - B) x TIMER_PIXELS + 7) / 4, rounded up. L changed.
tw_span\@:
        sub b
        ld l,a
        add a,a
        add a,l
        add a,a                         ; x TIMER_PIXELS
        add a,7                         ; round up to a group, plus one
        rrca
        rrca
        and 0x3f                        ; / 4
        ret
; tw_block: the rows of the next block (g changes every four rows), up to
; the end of the view; then tw_g. Out: B rows, carry set when g is 256 or
; more (no texture).
tw_block\@:
        ld hl,(TW_W)
        ld a,l
        and 3                           ; the rows left in this g
        inc a
        ld b,a
        ld de,TW_Y
        ld a,(de)
        add a,b
        jr nc,tw_block_rows\@
        ld a,(de)
        neg                             ; rows to the end
        ld b,a
tw_block_rows\@:
        push hl
        ld e,b
        ld d,0
        or a
        sbc hl,de
        ld (TW_W),hl
        pop hl
; tw_g: In: HL the W of the row. Out: TW_G = W / 4; carry set when it is
; 256 or more.
tw_g\@:
        srl h
        rr l
        srl h
        rr l
        ld a,h
        or a
        scf
        ret nz
        ld a,l
        ld (TW_G),a
        or a
        ret
; tw_fspan: the front span of the row block: TW_LEFT, TW_OFF and TW_CNT,
; C groups wider. Out: Z set when it is empty.
tw_fspan\@:
        ld a,(TW_G)
        add a,(ix+PAGE_TIMER)
        call tw_rowbyte\@
        rrca
        rrca
        rrca
        rrca
        and 3                           ; bits 5-4: the ragged front offset
        add a,FRONT_EDGE
        ld e,a
        ld d,0
        ld a,(TW_G)
        ld l,a
        ld h,0
        or a
        sbc hl,de
        bit 7,h
        jr z,tw_fpos\@
        xor a
        ld (TW_LEFT),a
        sub l                           ; texture groups left of the view
        ld (TW_OFF),a
        jr tw_fright\@
tw_fpos\@:
        ld a,l
        ld (TW_LEFT),a
        xor a
        ld (TW_OFF),a
tw_fright\@:
        ld a,(TW_K1)
        add a,c
        ld e,a
        ld d,0
        ld a,(TW_G)
        ld l,a
        ld h,0
        add hl,de
        ld de,FRONT_EDGE
        or a
        sbc hl,de
        call tw_clip\@
        ld e,a
        ld a,(TW_LEFT)
        ld d,a
        ld a,e
        sub d
        jr c,tw_fnone\@
        jr z,tw_fnone\@
        ld e,a
        ld a,(TW_OFF)
        ld d,a
        ld a,WAVE_ROW
        sub d
        jr c,tw_fnone\@
        jr z,tw_fnone\@
        cp e
        jr nc,tw_fcount\@
        ld e,a
tw_fcount\@:
        ld a,e
        ld (TW_CNT),a
        or a
        ret
tw_fnone\@:
        xor a
        ld (TW_CNT),a
        ret
; tw_clip: A = HL clipped to 0..GROUPS_PER_ROW.
tw_clip\@:
        bit 7,h
        jr z,tw_clip_positive\@
        xor a
        ret
tw_clip_positive\@:
        ld a,h
        or a
        ld a,GROUPS_PER_ROW
        ret nz
        ld a,l
        cp GROUPS_PER_ROW + 1
        ret c
        ld a,GROUPS_PER_ROW
        ret
; tw_paint: one DMA move of the front span of row TW_Y.
; tw_go: start the move of TW_CNT groups.
tw_paint\@:
        call tw_srcaddr\@
        out0 (SAR0L),l
        out0 (SAR0H),h                  ; source high
        call tw_first\@
        out0 (DAR0L),l                  ; destination low
        out0 (DAR0H),h                  ; destination high
tw_go\@:
        ld a,(TW_CNT)
        out0 (BCR0L),a                  ; groups
        ld a,DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        out0 (DSTAT),a
        ret
; tw_srcaddr: Out: HL the texture group of TW_OFF in texture row TW_Y mod
; TEXTURE_ROWS (WAVE_ROW groups a row). DE changed.
tw_srcaddr\@:
        ld a,(TW_OFF)
        ld e,a
        ld a,(TW_Y)
        and TEXTURE_ROWS - 1
        rrca
        rrca                            ; row x 64: bits 1-0 to 7-6, bit 2 to 0
        ld l,a
        and 0x01
        ld h,a
        ld a,l
        and 0xc0
        or e
        ld l,a
        ld de,special_wave__group16
        add hl,de
        ret
; tw_first: Out: HL the screen address of TW_LEFT on the row, C TW_Y.
tw_first\@:
        ld hl,(TW_DST)
        ld a,(TW_LEFT)
        add a,l
        ld l,a
        jr nc,tw_first_ready\@
        inc h
tw_first_ready\@:
        ld a,(TW_Y)
        ld c,a
        ret
; tw_store: keep the row C and its address HL (less TW_LEFT) for the next
; block.
tw_store\@:
        ld a,c
        ld (TW_Y),a
        ld a,(TW_LEFT)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld (TW_DST),hl
        ret
; tw_skip: move on B rows. Out: Z set at the end of the view.
tw_skip\@:
        ld a,(TW_Y)
        add a,b
        ld (TW_Y),a
        ld hl,(TW_DST)
        ld de,GROUPS_PER_ROW
tw_skip_row\@:
        add hl,de
        djnz tw_skip_row\@
        ld (TW_DST),hl
        ret
; tw_oak: Oak register E = A.
tw_oak\@:
        ld bc,OAK_INDEX
        out (c),e
        inc c
        out (c),a
        ret
; tw_rows_start: the first block: the accumulator, the screen base, row 0.
tw_rows_start\@:
        ld hl,(TW_ACUR)
        ld (TW_W),hl
        ld hl,(scene_screen_base)
        ld (TW_DST),hl
        xor a
        ld (TW_Y),a
        ret
; tw_rowbyte: A = the byte of the ragged-edge table (tsunami_rows.inc,
; ROW_TABLE bytes) at A mod ROW_TABLE. DE, HL changed.
tw_rowbyte\@:
        and ROW_TABLE - 1
        ld e,a
        ld d,0
        ld hl,tw_rows\@
        add hl,de
        ld a,(hl)
        ret
tw_rows\@:
        .include "tsunami_rows.inc"
        .endm

; Lightning: write the bolt's exact masks from a read-only word table in
; VRAM. SP walks the table, so interrupts must be off; nothing calls or
; pushes between switching SP and restoring it. special_world holds the
; command SP; it shares storage with the wave, which never runs at the same time.
; Alternate BC is the map mask data port.

; Set the planes of the masks in REG (high nibble with ROTATE) to the bolt colours.
        .macro paint reg, rotate=0
        ld a,\reg
        .if \rotate
        .rept 4
        rrca
        .endr
        .endif
        and 0x0F                        ; the planes of the mask
        exx
        out (c),a
        exx
        ld (hl),bolt_light_pen          ; even rows
        ld a,bolt_blue_pen              ; odd rows (the same colour)
        ld (de),a
        inc hl
        inc de
        .endm

; Widen the damage bound pair at (HL) to D..E.
        .macro widen_bound
        ld a,(hl)
        cp d
        jr c,1f
        ld (hl),d
1:      inc l
        ld a,(hl)
        cp e
        jr nc,2f
        ld (hl),e
2:
        .endm

        .macro special_bolt_draw
        exx
        push bc
        push de
        push hl
        exx
        in0 a,(BBR)
        push af
        in0 a,(CBR)
        push af
        ld a,(special_timer)
        cp BOLT_POSE_1
        jp nc,pose0\@
        cp BOLT_POSE_2
        ld a,2
        jp c,pose\@
        ld a,1
        jp pose\@
pose0\@:
        xor a
pose\@:
        ld d,a                          ; pose = read plane
        ld bc,VGA_GC_INDEX
        ld a,GC_READ_MAP
        out (c),a
        inc c
        out (c),d
        oak_set OAK_READ_SEGMENT, bolt_table__vseg
        set_io BBR, bolt_table__vbbr4k
        gc_set GC_MODE, GC_MODE_256
        seq_set SEQ_MAP_MASK, ALL_PLANES
        oak_set OAK_WRITE_SEGMENT, 0
        ld hl,(scene_screen_base)
        ld (special_row_address),hl
        xor a
        ld (special_row),a
        exx
        ld bc,VGA_SEQ_DATA
        exx
        ld (special_world),sp
        ld sp,bolt_table__vptr4k
row\@:
        ld hl,(special_row_address)
        ld a,h
        rrca
        rrca
        rrca
        rrca
        and 0x0F
        add a,VGA_WINDOW_E000
        out0 (CBR),a
        ld a,h
        and 0x0F
        or WINDOW_E000 >> 8
        ld h,a
        ld (special_dest),hl
        ld a,l                          ; DE = the second row of the pair
        add a,GROUPS_PER_ROW
        ld e,a
        ld a,h
        adc a,0
        ld d,a
        pop bc                          ; row header: first group, run count
        ld a,b
        ld (special_left),a
        ld a,c
        exx
        ld d,a
        exx
run\@:
        pop bc                          ; C: length in bits 7-6, delta in bits 5-0
        ld a,c
        and RUN_DELTA
        add a,l
        ld l,a
        jr nc,1f
        inc h
1:      ld a,c
        and RUN_DELTA
        add a,e
        ld e,a
        jr nc,2f
        inc d
2:      paint b
        ld a,c
        and RUN_LENGTH
        jp z,run_done\@
        paint b, 1
        bit 7,c
        jp z,run_done\@
        ld a,c
        and RUN_FOURTH
        ld (special_fourth),a
        pop bc                          ; more masks
        paint c
        ld a,(special_fourth)
        or a
        jp z,run_done\@
        paint c, 1
run_done\@:
        exx
        dec d
        exx
        jp nz,run\@
        ; Mark the drawn groups, aligned to the 4-group damage quantum.
        ld a,(special_dest)
        ld b,a
        ld a,l
        sub b
        add a,DAMAGE_QUANTUM - 1
        and ~(DAMAGE_QUANTUM - 1) & 0xFF
        ld e,a
        ld a,(special_left)
        and ~(DAMAGE_QUANTUM - 1) & 0xFF
        ld d,a
        ld a,(special_row)
        ld b,a
        ld a,(scene_ring_start)
        add a,b
        ld l,a
        ld h,0
        add hl,hl
        ld a,(scroll_current_map+1)
        add a,h
        ld h,a
        widen_bound
        inc l
        jr nz,3f
        ld a,h
        xor 1
        ld h,a
3:      widen_bound
        ld hl,(special_row_address)
        ld de,2 * GROUPS_PER_ROW
        add hl,de
        ld (special_row_address),hl
        ld a,(special_row)
        add a,2
        ld (special_row),a
        jp nz,row\@
        ld sp,(special_world)
        gc_set GC_READ_MAP, 0
        oak_set OAK_READ_SEGMENT, 0
        oak_set OAK_WRITE_SEGMENT, 0
        seq_set SEQ_MAP_MASK, ALL_PLANES
        gc_set GC_MODE, GC_MODE_256 | 1
        pop af
        out0 (CBR),a
        pop af
        out0 (BBR),a
        exx
        pop hl
        pop de
        pop bc
        exx
        ret
        .endm

        .section .text.special_wave_draw_buffer1,"ax",@progbits
special_wave_draw_buffer1:
        special_wave_draw
        .section .text.special_wave_draw_buffer0,"ax",@progbits
special_wave_draw_buffer0:
        special_wave_draw
        .section .text.special_bolt_draw_buffer1,"ax",@progbits
special_bolt_draw_buffer1:
        special_bolt_draw
        .section .text.special_bolt_draw_buffer0,"ax",@progbits
special_bolt_draw_buffer0:
        special_bolt_draw

; The jumps that a special packet writes over stream_arm_next (the helper
; draws) and water_commit (the palette flash). These bytes never load: the
; host sends them, and a cleanup packet restores the original instructions.
        .section .text.special_hooks,"ax",@progbits
special_hook_draw:
        jp special_draw_bridge
special_hook_water:
        jp special_palette_dispatch
