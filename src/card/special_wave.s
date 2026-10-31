; Special weapon pictures drawn by helpers that the host sends in a packet:
; the Tsunami wave and the Lightning bolt. A helper runs from the receive
; buffer that got it, so each is assembled for both buffers.

        .include "second_sight.inc"
        .include "vga.inc"
        .include "z180.inc"

        .global special_wave_draw_8000, special_wave_draw_4000
        .global special_bolt_draw_8000, special_bolt_draw_4000

        .equ VIEW_GROUPS, 56
        .equ WAVE_FIRST_GROUP, 68       ; world group where the wave texture starts
        .equ WAVE_LAST_GROUP, 131
        .equ WAVE_START, 255            ; world row of the first wave row, minus 6 per tick
        .equ VRAM_CBR, 0x92
        .equ VRAM_APERTURE, 0xE0
        .equ BOLT_POSE_1, 13            ; special_timer from which pose 0 shows
        .equ BOLT_POSE_2, 7
; Wave painter scratch in the command window (-F). The tail reuses
; TW_K1 for the odd-chunk mask and TW_ACUR for the row's clean source.
        .equ TW_ACUR, 0x3470
        .equ TW_W, 0x3472
        .equ TW_DST, 0x3474
        .equ TW_Y, 0x3476
        .equ TW_LEFT, 0x3477
        .equ TW_CNT, 0x3478
        .equ TW_OFF, 0x3479
        .equ TW_K1, 0x347A
        .equ TW_D2, 0x347B
        .equ TW_MF, 0x347C              ; bit 7 finish, bit 6 stale, bits 0-3 flip mask
        .equ TW_G, 0x347D
        .equ TW_PH, 0x347E
        .equ TW_MA, 0x347F
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
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0x00
        ld hl,sea_spare
        add hl,de
        push hl
        pop ix
        ld a,(special_timer)
        ld b,a
        ld a,(ix+0)                     ; ld a,(ix+0) last timer
        cp b
        jr nc,tw_same\@
        ld (ix+0),0x81
        ld (ix+1),0x81
        ld (ix+3),0x00                  ; ld (ix+3),0 snapshot due
tw_same\@:
        ld a,b
        cp TW_FINISH
        sbc a,a
        and 0x80
        ld c,a
        ld a,(ix+3)
        dec a
        jr nz,tw_stale\@
        ld a,(bg_moving_objects)
        or a
        jr z,tw_flags\@
        ld (ix+3),0x02
tw_stale\@:
        bit 1,(ix+3)
        jr z,tw_flags\@
        set 6,c
tw_flags\@:
        ld a,c
        ld (TW_MF),a
        ld a,(ix+0)
        sub TW_CAP
        jr c,tw_timer\@
        cp b
        jr c,tw_timer\@
        ld b,a                          ; ld b,a,drawn timer
tw_timer\@:
        ld a,b
        ld l,a
        ld h,0x06
        mlt hl
        ld de,WAVE_START
        add hl,de
        ld (TW_ACUR),hl
        ld a,(ix+0)
        call tw_span\@
        add a,FRINGE
        ld (TW_K1),a
        ld a,(ix+1)
        call tw_span\@
        ld (TW_D2),a
        ld a,(ix+2)                     ; ld a,(ix+2) pass counter
        inc (ix+2)
        rrca
        sbc a,a
        and 0x0f                        ; and flip mask
        ld hl,TW_MF
        or (hl)
        ld (hl),a
        ld a,(ix+0)
        ld (ix+1),a
        ld (ix+0),b
        ld e,0x24
        ld a,0x00
        call tw_oak\@
        ld a,0x0a
        out0 (0x22),a
        ld a,0x0a
        out0 (0x25),a
        ld a,(ix+3)
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
        ld (ix+4),a
        ld e,0x23
        ld a,0x00
        call tw_oak\@
        call tw_snapshot\@
        inc (ix+3)
tw_snapped\@:
        ld e,0x23
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
        ld a,(de)                       ; ld a,(de) physical row
        ld hl,scene_ring_start
        sub (hl)
        ld (TW_Y),a
        ld e,a
        ld d,0x00
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
        ld c,0x00
        call tw_fspan\@
        pop bc
        jr z,tw_front_skip\@
        call tw_srcaddr\@
        ex de,hl
        call tw_first\@
tw_front_row\@:
        out0 (0x20),e                   ; out0 DMA address,r
        out0 (0x21),d                   ; out0 DMA address,r
        out0 (0x23),l                   ; out0 DMA address,r
        out0 (0x24),h                   ; out0 DMA address,r
        call tw_go\@
        push de
        ld de,VIEW_GROUPS
        add hl,de
        pop de
        ld a,e
        add a,WAVE_ROW
        ld e,a
        jr nc,tw_at_149\@
        inc d
tw_at_149\@:
        inc c
        ld a,c
        and 0x07
        jr nz,tw_front_wrapped\@
        ld a,d
        sub 0x02                        ; sub 512 high
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
        ld e,0x23
        ld a,0x00
        call tw_oak\@
        ld bc,0x03c4                    ; ld bc,sequencer index
        ld a,0x02                       ; ld a,map mask
        out (c),a
        call tw_rows_start\@
tw_tail_block\@:
        call tw_block\@
        jp c,tw_tail_skip\@
        push bc
        ld a,(TW_G)
        add a,(ix+0)                    ; add a,(ix+0) timer
        add a,0x07
        call tw_rowbyte\@
        rlca
        rlca
        and 0x03
        ld c,a
        ld a,(TW_G)
        ld l,a
        ld h,0x00
        ld de,TRAIL_EDGE
        or a
        sbc hl,de
        push hl
        ld e,c
        ld d,0x00
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
        and 0xc0                        ; and finish or stale
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
        and 0x1f                        ; and 31,chunk phase
        ld (TW_PH),a
        ld a,(TW_MF)
        xor d
        and 0x0f
        ld (TW_MA),a
        ld de,0x0010                    ; ld de,16 rows on
        add hl,de
        ld a,(TW_MF)
        xor (hl)
        and 0x0f
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
        and 0xe0
        add a,0x20
        add a,d
        jr tw_boundary\@
tw_first_boundary\@:
        ld a,d
tw_boundary\@:
        ld e,a                          ; ld e,a,boundary
        sub d
        and 0x20                        ; and 32,chunk parity
        ld a,(TW_MA)
        jr z,tw_at_217\@
        ld a,(TW_K1)
tw_at_217\@:
        push bc
        ld bc,0x03c5                    ; ld bc,map mask data
        out (c),a
        pop bc
        ld a,(TW_CNT)
        cp e
        jr nc,tw_at_225\@
        ld e,a
tw_at_225\@:
        push hl
        ld a,(TW_OFF)
        ld d,a
        add a,l
        ld l,a
        jr nc,tw_at_22f\@
        inc h
tw_at_22f\@:
        out0 (0x23),l                   ; out0 destination low
        out0 (0x24),h                   ; out0 destination high
        ld hl,(TW_ACUR)
        ld a,d
        add a,l
        ld l,a
        jr nc,tw_at_23e\@
        inc h
tw_at_23e\@:
        out0 (0x20),l
        out0 (0x21),h                   ; out0 source high
        ld a,e
        sub d
        out0 (0x26),a                   ; groups
        ld a,0x61
        out0 (0x30),a
        ld a,e
        ld (TW_OFF),a
        pop hl
        ld a,(TW_CNT)
        cp e
        jr nz,tw_tail_piece\@
        ld de,VIEW_GROUPS
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
        ld d,l                          ; ld d,l,left
        ld e,h                          ; ld e,h,right
        ld a,(TW_MF)
        rla
        jr nc,tw_at_27c\@
        ld d,0x00
tw_at_27c\@:
        ld a,(TW_Y)
        ld hl,scene_ring_start
        add a,(hl)
        call scroll_mark
        pop bc
tw_tail_skip\@:
        call tw_skip\@
        jp nz,tw_tail_block\@
tw_done\@:
        ld bc,0x03c5                    ; ld bc,map mask data
        ld a,0x0f                       ; ld a,all planes
        out (c),a
        pop ix
        ret
tw_clean\@:
        ld a,(ix+4)                     ; ld a,(ix+4) bias
        add a,c
        ld l,a
        ld h,row_offset_low >> 8
        ld e,(hl)
        inc h
        ld d,(hl)
        ld hl,scene_ring_start
        cp (hl)
        ld a,d
        jr c,tw_at_2aa\@
        add a,0x38                      ; add a,upper half
tw_at_2aa\@:
        add a,0x04                      ; add a,display reservation
        ld hl,scene_page
        or (hl)
        ld d,a
        ld (TW_ACUR),de
        ret
tw_snapshot\@:
        ld hl,(scene_screen_base)
        ld c,0x00                       ; ld c,first row
tw_snapshot_row\@:
        push hl
        call tw_clean\@
        pop hl
        out0 (0x20),l
        out0 (0x21),h                   ; out0 source high
        out0 (0x23),e                   ; out0 destination low
        out0 (0x24),d                   ; out0 destination high
        ld a,0x38                       ; ld a,row groups
        out0 (0x26),a                   ; groups
        ld a,0x61
        out0 (0x30),a
        ld de,VIEW_GROUPS
        add hl,de
        inc c
        jr nz,tw_snapshot_row\@
        ret
tw_span\@:
        sub b
        ld l,a
        add a,a
        add a,l
        add a,a
        add a,0x07
        rrca
        rrca
        and 0x3f
        ret
tw_block\@:
        ld hl,(TW_W)
        ld a,l
        and 0x03
        inc a
        ld b,a
        ld de,TW_Y
        ld a,(de)
        add a,b
        jr nc,tw_block_rows\@
        ld a,(de)
        neg                             ; neg rows to the end
        ld b,a
tw_block_rows\@:
        push hl
        ld e,b
        ld d,0x00
        or a
        sbc hl,de
        ld (TW_W),hl
        pop hl
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
tw_fspan\@:
        ld a,(TW_G)
        add a,(ix+0)                    ; add a,(ix+0) timer
        call tw_rowbyte\@
        rrca
        rrca
        rrca
        rrca
        and 0x03
        add a,FRONT_EDGE
        ld e,a
        ld d,0x00
        ld a,(TW_G)
        ld l,a
        ld h,0x00
        or a
        sbc hl,de
        bit 7,h
        jr z,tw_fpos\@
        xor a
        ld (TW_LEFT),a
        sub l                           ; sub l,texture groups left of the view
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
        ld d,0x00
        ld a,(TW_G)
        ld l,a
        ld h,0x00
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
tw_clip\@:
        bit 7,h
        jr z,tw_clip_positive\@
        xor a
        ret
tw_clip_positive\@:
        ld a,h
        or a
        ld a,0x38
        ret nz
        ld a,l
        cp 0x39
        ret c
        ld a,0x38
        ret
tw_paint\@:
        call tw_srcaddr\@
        out0 (0x20),l
        out0 (0x21),h                   ; out0 source high
        call tw_first\@
        out0 (0x23),l                   ; out0 destination low
        out0 (0x24),h                   ; out0 destination high
tw_go\@:
        ld a,(TW_CNT)
        out0 (0x26),a                   ; groups
        ld a,0x61
        out0 (0x30),a
        ret
tw_srcaddr\@:
        ld a,(TW_OFF)
        ld e,a
        ld a,(TW_Y)
        and 0x07
        rrca
        rrca
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
tw_first\@:
        ld hl,(TW_DST)
        ld a,(TW_LEFT)
        add a,l
        ld l,a
        jr nc,tw_at_3de\@
        inc h
tw_at_3de\@:
        ld a,(TW_Y)
        ld c,a
        ret
tw_store\@:
        ld a,c
        ld (TW_Y),a
        ld a,(TW_LEFT)
        ld e,a
        ld d,0x00
        or a
        sbc hl,de
        ld (TW_DST),hl
        ret
tw_skip\@:
        ld a,(TW_Y)
        add a,b
        ld (TW_Y),a
        ld hl,(TW_DST)
        ld de,VIEW_GROUPS
tw_at_401\@:
        add hl,de
        djnz tw_at_401\@
        ld (TW_DST),hl
        ret
tw_oak\@:
        ld bc,0x03de                    ; ld bc,Oak index
        out (c),e
        inc c
        out (c),a
        ret
tw_rows_start\@:
        ld hl,(TW_ACUR)
        ld (TW_W),hl
        ld hl,(scene_screen_base)
        ld (TW_DST),hl
        xor a
        ld (TW_Y),a
        ret
tw_rowbyte\@:
        and 0x1f
        ld e,a
        ld d,0x00
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
        and 0x0F
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
        gc_set GC_MODE, 0x40
        seq_set SEQ_MAP_MASK, 0x0F
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
        add a,VRAM_CBR
        out0 (CBR),a
        ld a,h
        and 0x0F
        or VRAM_APERTURE
        ld h,a
        ld (special_dest),hl
        ld a,l                          ; DE = the second row of the pair
        add a,VIEW_GROUPS
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
        and 0x3F
        add a,l
        ld l,a
        jr nc,1f
        inc h
1:      ld a,c
        and 0x3F
        add a,e
        ld e,a
        jr nc,2f
        inc d
2:      paint b
        ld a,c
        and 0xC0
        jp z,run_done\@
        paint b, 1
        bit 7,c
        jp z,run_done\@
        ld a,c
        and 0x40
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
        add a,3
        and 0xFC
        ld e,a
        ld a,(special_left)
        and 0xFC
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
        ld de,2 * VIEW_GROUPS
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
        seq_set SEQ_MAP_MASK, 0x0F
        gc_set GC_MODE, 0x41
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

        .section .text.special_wave_draw_8000,"ax",@progbits
special_wave_draw_8000:
        special_wave_draw
        .section .text.special_wave_draw_4000,"ax",@progbits
special_wave_draw_4000:
        special_wave_draw
        .section .text.special_bolt_draw_8000,"ax",@progbits
special_bolt_draw_8000:
        special_bolt_draw
        .section .text.special_bolt_draw_4000,"ax",@progbits
special_bolt_draw_4000:
        special_bolt_draw
