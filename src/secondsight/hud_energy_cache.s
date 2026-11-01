; Energy bar cache: two opaque 64x8 energy bars are cached in VRAM, and HUD
; groups that are blank are skipped. A miss draws the bar with the ordinary
; glyph renderer and snapshots the finished bar from the back page; a hit
; copies only the opaque rectangle. Runs in its own SRAM bank
; (secondsight.ld .bank_code, through BBR).

        .include "video.inc"
        .include "hud.inc"

        .global energy_try, energy_finish, hud_energy_dispatch, hud_energy_entry

; The group codes: the handler word of the first HUD template of a group
; (scripts/state_scene.py tables). 1 and 2: the energy bars of P1 and P2;
; 3 and 4: the weapon names; 5 and 6: the text lines; 7 and 8: the scores.
        .equ GROUP_WEAPON_P1, 3         ; the first group that can be blank
        .equ GROUP_LINE_P1, 5
        .equ GROUP_SCORE_P1, 7
; The HUD templates: 10 bytes each; the planner has read the handler word
; of the current one.
        .equ TEMPLATE_BYTES, 10
        .equ TEMPLATE_REST, TEMPLATE_BYTES - 2
        .equ SKIP_FOUR, TEMPLATE_REST + 3 * TEMPLATE_BYTES  ; the rest of a group of 4 templates
        .equ SKIP_SIX, TEMPLATE_REST + 5 * TEMPLATE_BYTES
        .equ SKIP_EIGHT, TEMPLATE_REST + 7 * TEMPLATE_BYTES
; The selectors (hud_lines: the cells of the text lines).
        .equ SELECTOR, 0x3F             ; selector bits without flags
        .equ LINE_ENERGY_P2, LINE_CELLS ; hud_lines: the first cell of the P2 energy bar
        .equ LINE_TEXT_P1, ENERGY_CELLS ; hud_lines: the text line of P1
        .equ LINE_TEXT_P2, LINE_CELLS + ENERGY_CELLS
        .equ SCORE_TEST_DIGITS, 4       ; a score is blank while these digits are blank
; The bars on the screen and in the cache.
        .equ ENERGY_ROW, 240            ; screen row of the energy bars
        .equ P2_COLUMN, 28              ; group of the second player's bar
        .equ CACHE_PITCH, 16            ; groups of a cache row
        .equ BAR_GROUPS, 16
        .equ BAR_ROWS, 8
        .equ PENDING_P1, 1              ; energy_pending: the P1 bar missed
        .equ PENDING_P2, 2              ; energy_pending: the P2 bar missed

        .section .text.hud_energy_cache,"ax",@progbits

; energy_try: draw a HUD group from the cache, or skip it when it is blank.
; An energy bar hits when its 8 selectors match the cached bar
; (energy_history); then the templates of the group are skipped.
; In: A group code. Out: carry set when the group was drawn from the cache
; or skipped as blank. AF, BC, DE, HL changed.
energy_try:
        cp GROUP_WEAPON_P1
        jp nc,empty_group
        dec a                           ; player 0 or 1
        ld (energy_player),a
        call energy_ptrs
        ld a,(hl)
        cp GLYPH_ENERGY
        jp c,energy_miss
        cp GLYPH_ENERGY_END
        jp nc,energy_miss
        ld b,ENERGY_CELLS
energy_compare:
        ld a,(de)
        cp (hl)
        jp nz,energy_miss
        inc hl
        inc de
        djnz energy_compare
        ; Skip the remaining four words and the next seven ten-byte templates.
        ld hl,(hud_template_cursor)
        ld de,SKIP_EIGHT
        add hl,de
        ld (hud_template_cursor),hl
        call energy_addresses
        call energy_draw
        scf
        ret

; A weapon name is blank with a selector 0; a score or a text line with
; blank glyphs in its cells.
empty_group:
        cp GROUP_SCORE_P1
        jp nc,empty_score
        cp GROUP_LINE_P1
        jp nc,empty_line
        ld hl,hud_p1_weapon
        cp GROUP_WEAPON_P1
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
        cp GROUP_SCORE_P1
        jp z,empty_score_test
        ld hl,hud_p2_score
empty_score_test:
        ld b,SCORE_TEST_DIGITS
empty_score_check:
        ld a,(hl)
        and SELECTOR
        cp GLYPH_BLANK
        jp nz,empty_group_miss
        inc hl
        djnz empty_score_check
        ld de,SKIP_FOUR
        jp empty_advance
empty_line:
        ld hl,hud_lines+LINE_TEXT_P1
        cp GROUP_LINE_P1
        jp z,empty_line_test
        ld hl,hud_lines+LINE_TEXT_P2
empty_line_test:
        ld b,TEXT_CELLS
empty_line_check:
        ld a,(hl)
        and SELECTOR
        cp GLYPH_SPACE
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

; A miss: the bar draws with the glyph renderer; energy_finish takes it.
energy_miss:
        ld a,(energy_player)
        or a
        ld a,PENDING_P1
        jp z,energy_flag
        inc a                           ; PENDING_P2
energy_flag:
        ld b,a
        ld a,(energy_pending)
        or b
        ld (energy_pending),a
        or a                            ; cache miss
        ret

; energy_finish: after the frame, snapshot the bars that missed from the
; back page into the cache, when all their cells are energy glyphs; else
; the history of the bar is cleared. AF, BC, DE, HL changed.
; energy_capture_if_valid: the same for the bar of player A.
energy_finish:
        ld a,(energy_pending)
        or a
        ret z
        ld (energy_work),a
        xor a
        ld (energy_pending),a
        ld a,(energy_work)
        and PENDING_P1
        jp z,energy_finish_p2
        xor a
        call energy_capture_if_valid
energy_finish_p2:
        ld a,(energy_work)
        and PENDING_P2
        ret z
        ld a,1
energy_capture_if_valid:
        ld (energy_player),a
        call energy_ptrs
        push hl
        push de
        ld b,ENERGY_CELLS
energy_validate:
        ld a,(hl)
        cp GLYPH_ENERGY
        jp c,energy_invalid
        cp GLYPH_ENERGY_END
        jp nc,energy_invalid
        inc hl
        djnz energy_validate
        pop de
        pop hl
        ld bc,ENERGY_CELLS
        ldir                            ; the history of the cached bar
        call energy_addresses
        ex de,hl                        ; capture the display into the cache
        jp energy_capture
energy_invalid:
        pop de
        pop hl
        xor a
        ld (de),a
        ret

; energy_ptrs: Out: HL the selectors of energy_player's bar, DE its cache
; history. AF changed.
energy_ptrs:
        ld a,(energy_player)
        or a
        ld hl,hud_lines
        ld de,energy_history_0
        ret z
        ld hl,hud_lines+LINE_ENERGY_P2
        ld de,energy_history_1
        ret

; energy_addresses: Out: HL cache group, DE display group of energy_player's
; bar. AF, BC changed.
energy_addresses:
        ld hl,energy_cache_group
        ld de,(hud_page_base)
        ex de,hl
        ld bc,ENERGY_ROW * GROUPS_PER_ROW
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

; energy_draw: copy the cached bar (HL) to the page (DE).
; energy_capture: copy the bar on the page (HL) into the cache (DE).
; energy_copy: one DMA move of BAR_GROUPS for each of the BAR_ROWS rows;
; the two pitch operands are patched. AF, BC, DE, HL changed.
energy_draw:
        oak_set OAK_READ_SEGMENT, energy_cache_segment
        oak_set OAK_WRITE_SEGMENT, 0
        ld a,CACHE_PITCH
        ld (energy_source_step+1),a
        ld a,GROUPS_PER_ROW
        ld (energy_dest_step+1),a
        jp energy_copy
energy_capture:
        oak_set OAK_READ_SEGMENT, 0
        oak_set OAK_WRITE_SEGMENT, energy_cache_segment
        ld a,GROUPS_PER_ROW
        ld (energy_source_step+1),a
        ld a,CACHE_PITCH
        ld (energy_dest_step+1),a
energy_copy:
        gc_set GC_MODE, GC_MODE_256 | 1
        seq_set SEQ_MAP_MASK, ALL_PLANES
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        set_io BCR0H, 0
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
energy_player:          .byte 0         ; the player of the bar: 0 or 1
energy_pending:         .byte 0         ; PENDING_P1, PENDING_P2: the bars that missed
energy_work:            .byte 0         ; energy_pending while energy_finish runs
energy_history_0:       .fill 8,1,0     ; selectors of the cached P1 bar
energy_history_1:       .fill 8,1,0

; Dispatch bridges in free common SRAM gaps (the allocator places .common
; sections). hud_energy_dispatch: map the bank, then energy_try; the
; planner saves the template cursor before it enters; L still holds the
; group code. hud_energy_entry: the entry from the HUD template loop.
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
