; Energy bar cache: two opaque 64x8 energy bars are cached in VRAM, and HUD
; groups that are blank are skipped. A miss draws the bar with the ordinary
; glyph renderer and snapshots the finished bar from the back page; a hit
; copies only the opaque rectangle. Runs in its own SRAM bank.

        .include "second_sight.inc"
        .include "vga.inc"
        .include "z180.inc"

        .global energy_try, energy_finish, hud_energy_dispatch, hud_energy_entry

        .equ GROUPED_BLANK, 3           ; group codes from the HUD template
        .equ BLANK_LINE, 5
        .equ BLANK_SCORE, 7
        .equ FIRST_ENERGY_GLYPH, 37
        .equ AFTER_ENERGY_GLYPHS, 46
        .equ BLANK_DIGIT, 10
        .equ BLANK_CELL, 36
        .equ SELECTOR, 0x3F             ; selector bits without flags
        .equ SKIP_BAR, 78               ; template bytes after the first bar glyph
        .equ SKIP_FOUR, 38
        .equ SKIP_SIX, 58
        .equ SKIP_EIGHT, 78
        .equ ENERGY_ROW, 240            ; screen row of the energy bars
        .equ P2_COLUMN, 28              ; group of the second player's bar
        .equ VIEW_GROUPS, 56
        .equ CACHE_PITCH, 16
        .equ BAR_GROUPS, 16
        .equ BAR_ROWS, 8

        .section .text.hud_energy_cache,"ax",@progbits

; In: A group code. Out: carry set when the group was drawn from the cache
; or skipped as blank.
energy_try:
        cp GROUPED_BLANK
        jp nc,empty_group
        dec a                           ; player 0 or 1
        ld (energy_player),a
        call energy_ptrs
        ld a,(hl)
        cp FIRST_ENERGY_GLYPH
        jp c,energy_miss
        cp AFTER_ENERGY_GLYPHS
        jp nc,energy_miss
        ld b,8
energy_compare:
        ld a,(de)
        cp (hl)
        jp nz,energy_miss
        inc hl
        inc de
        djnz energy_compare
        ; Skip the remaining four words and the next seven ten-byte templates.
        ld hl,(hud_template_cursor)
        ld de,SKIP_BAR
        add hl,de
        ld (hud_template_cursor),hl
        call energy_addresses
        call energy_draw
        scf
        ret

empty_group:
        cp BLANK_SCORE
        jp nc,empty_score
        cp BLANK_LINE
        jp nc,empty_line
        ld hl,hud_p1_weapon
        cp GROUPED_BLANK
        jp z,empty_weapon_test
        ld hl,hud_p2_weapon
empty_weapon_test:
        ld a,(hl)
        and SELECTOR
        ret nz
        ld de,SKIP_EIGHT
        jp empty_advance
empty_score:
        ld hl,hud_p1_score
        cp BLANK_SCORE
        jp z,empty_score_test
        ld hl,hud_p2_score
empty_score_test:
        ld b,4
empty_score_check:
        ld a,(hl)
        and SELECTOR
        cp BLANK_DIGIT
        jp nz,empty_group_miss
        inc hl
        djnz empty_score_check
        ld de,SKIP_FOUR
        jp empty_advance
empty_line:
        ld hl,hud_lines+8
        cp BLANK_LINE
        jp z,empty_line_test
        ld hl,hud_lines+22
empty_line_test:
        ld b,6
empty_line_check:
        ld a,(hl)
        and SELECTOR
        cp BLANK_CELL
        jp nz,empty_group_miss
        inc hl
        djnz empty_line_check
        ld de,SKIP_SIX
empty_advance:
        ld hl,(hud_template_cursor)
        add hl,de
        ld (hud_template_cursor),hl
        scf
        ret
empty_group_miss:
        or a
        ret

energy_miss:
        ld a,(energy_player)
        or a
        ld a,1
        jp z,energy_flag
        inc a
energy_flag:
        ld b,a
        ld a,(energy_pending)
        or b
        ld (energy_pending),a
        or a                            ; cache miss
        ret

; After the frame: snapshot the bars that missed.
energy_finish:
        ld a,(energy_pending)
        or a
        ret z
        ld (energy_work),a
        xor a
        ld (energy_pending),a
        ld a,(energy_work)
        and 1
        jp z,energy_finish_p2
        xor a
        call energy_capture_if_valid
energy_finish_p2:
        ld a,(energy_work)
        and 2
        ret z
        ld a,1
        jp energy_capture_if_valid
energy_capture_if_valid:
        ld (energy_player),a
        call energy_ptrs
        push hl
        push de
        ld b,8
energy_validate:
        ld a,(hl)
        cp FIRST_ENERGY_GLYPH
        jp c,energy_invalid
        cp AFTER_ENERGY_GLYPHS
        jp nc,energy_invalid
        inc hl
        djnz energy_validate
        pop de
        pop hl
        ld bc,8
        ldir
        call energy_addresses
        ex de,hl                        ; capture the display into the cache
        jp energy_capture
energy_invalid:
        pop de
        pop hl
        xor a
        ld (de),a
        ret

; Out: HL the player's selectors, DE its cache history.
energy_ptrs:
        ld a,(energy_player)
        or a
        ld hl,hud_lines
        ld de,energy_history_0
        jp z,energy_ptrs_ready
        ld hl,hud_lines+14
        ld de,energy_history_1
energy_ptrs_ready:
        ret

; Out: HL cache group, DE display group of the player's bar.
energy_addresses:
        ld hl,energy_cache_group
        ld de,(hud_page_base)
        ex de,hl
        ld bc,ENERGY_ROW * VIEW_GROUPS
        add hl,bc
        ex de,hl
        ld a,(energy_player)
        or a
        ret z
        inc h                           ; the second cache is 256 groups on
        ld a,e
        add a,P2_COLUMN
        ld e,a
        ld a,d
        adc a,0
        ld d,a
        ret

energy_draw:
        oak_set OAK_READ_SEGMENT, energy_cache_segment
        oak_set OAK_WRITE_SEGMENT, 0
        ld a,CACHE_PITCH
        ld (energy_source_step+1),a
        ld a,VIEW_GROUPS
        ld (energy_dest_step+1),a
        jp energy_copy
energy_capture:
        oak_set OAK_READ_SEGMENT, 0
        oak_set OAK_WRITE_SEGMENT, energy_cache_segment
        ld a,VIEW_GROUPS
        ld (energy_source_step+1),a
        ld a,CACHE_PITCH
        ld (energy_dest_step+1),a
energy_copy:
        push hl
        push de
        gc_set GC_MODE, 0x41
        seq_set SEQ_MAP_MASK, 0x0F
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        set_io BCR0H, 0
        pop de
        pop hl
        ld b,BAR_GROUPS
        ld c,BAR_ROWS
energy_copy_row:
        out0 (SAR0L),l
        out0 (SAR0H),h
        out0 (DAR0L),e
        out0 (DAR0H),d
        out0 (BCR0L),b
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        dec c
        jp z,energy_copy_done
        ld a,l
energy_source_step:
        add a,0                         ; patched: source pitch
        ld l,a
        jp nc,energy_source_ready
        inc h
energy_source_ready:
        ld a,e
energy_dest_step:
        add a,0                         ; patched: destination pitch
        ld e,a
        jp nc,energy_copy_row
        inc d
        jp energy_copy_row
energy_copy_done:
        oak_set OAK_WRITE_SEGMENT, 0
        ret

; Cache state, kept in this bank.
energy_player:          .byte 0
energy_pending:         .byte 0         ; bit 0: P1 missed, bit 1: P2 missed
energy_work:            .byte 0
energy_history_0:       .fill 8,1,0     ; selectors of the cached P1 bar
energy_history_1:       .fill 8,1,0

; Dispatch bridges in free common SRAM gaps. The planner saves the template
; cursor before it enters; L still holds the group code.
        .section .common.hud_energy_dispatch,"ax",@progbits
hud_energy_dispatch:
        set_io BBR, bank_code__load__bbr
        ld a,l
        call energy_try
        jp hud_energy_resume

        .section .common.hud_energy_entry,"ax",@progbits
hud_energy_entry:
        ld sp,(hud_caller_sp)
        jp hud_energy_dispatch
