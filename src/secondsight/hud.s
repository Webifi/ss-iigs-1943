; HUD: the two-player score lines, the weapon labels, the boss bars and
; the fixed captions. The state packet carries values; the card selects
; the glyphs (hud.inc), and the HUD templates draw them.

        .include "video.inc"
        .include "stream.inc"
        .include "hud.inc"

        .global game_hud_values, hud_energy_resume, native_hud_pattern
        .global hud_p1_weapon, hud_p2_weapon, hud_p2_score, hud_player_state
        .global hud_loop_selectors, hud_lines, hud_caller_sp, hud_page_base
        .global hud_template_cursor, glyph_return

        .equ SELECTOR, 0x3F             ; a selector without its flags
        .equ COUNT_TENS_CELL, 11        ; the line cells of the continue count
        .equ COUNT_UNITS_CELL, 12
        .equ LOOP_GLYPHS, 4             ; hud_loop_selectors: 0 a space, 1 an R
        .equ BOSS_ROW, 32               ; the screen rows of the boss bars
        .equ BOSS_ROWS, 8
        .equ BOSS_LEFT, 14              ; the groups of the boss bars
        .equ BOSS_RIGHT, 54
        .equ BOSS_BARS, 5               ; bars of 4 cells: left, middle, middle, right
        .equ BAR_CELLS, 4

; The player state from the packet trailer (game_world_receive).
        .equ P2_ENERGY, hud_player_state + STREAM_ENERGY2
        .equ UI_MODES, hud_player_state + STREAM_UI_MODE ; the mode, then the count, of each player
        .equ P2_WEAPON_STATE, hud_player_state + STREAM_WEAPON2

; The template state (secondsight.ld .planner_variables).
        .section .vars.hud_planner,"aw",@nobits
hud_p1_weapon: .ds.b 4                  ; the weapon label, then the two time digits
hud_caller_sp: .ds.b 2                  ; SP of the planner while the HUD templates run
hud_page_base: .ds.b 2                  ; the group of the back page (PAGE_START + page)
hud_template_cursor: .ds.b 2            ; the next HUD template
; native_hud_pattern: the pattern program.
pattern_bank: .ds.b 2                   ; the BBR of the program
pattern_program: .ds.b 2
pattern_destination: .ds.b 2            ; the band address in the WINDOW_E000 window
pattern_source: .ds.b 2
; The selectors: a glyph code (or a flag) for each HUD template
; (secondsight.ld .playfield: zero at load).
        .section .vars.hud,"aw",@nobits
hud_player_state:                       ; the trailer fields up to TRAILER_RESULT
hud_p2_score: .ds.b TRAILER_RESULT - TRAILER_SCORE2
hud_p2_weapon: .ds.b 4
hud_loop_selectors: .ds.b LOOP_GLYPHS
hud_lines: .ds.b 2 * LINE_CELLS + BOSS_CELLS
; The return address of a glyph from the template loop (a one-word stack).
glyph_return: .ds.b 2

        .section .text.game_hud_values,"ax",@progbits

; game_hud_values: make the selectors of both HUD lines, the loop stock and
; the boss bars. AF, BC, DE, HL changed.
game_hud_values:
        ld hl,hud_p2_score
        ld b,LEADING_DIGITS
1:      ld a,(hl)
        or a
        jp nz,lines
        ld (hl),GLYPH_BLANK
        inc hl
        djnz 1b
lines:
        .irp player,0,1
; The energy cells, or the message of the UI mode.
        ld a,(UI_MODES + 2 * \player)
        and UI_MODE_MASK
        or a
        jp nz,message_\player
        .if \player == 0
        ld hl,hud_p1_score + 8
        .else
        ld hl,P2_ENERGY
        .endif
        ld de,hud_lines + \player * LINE_CELLS
        ld b,ENERGY_CELLS
1:      ld a,(hl)
        inc hl
        and 0x0F                        ; the cell value
        add a,GLYPH_ENERGY
        ld (de),a
        inc de
        djnz 1b
        ld a,GLYPH_SPACE
        .rept TEXT_CELLS
        ld (de),a
        inc de
        .endr
        jp line_done_\player
message_\player:
        dec a
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        .rept 3
        add hl,hl
        .endr
        or a
        sbc hl,de                       ; (mode - 1) x LINE_CELLS
        ld de,game_hud_messages
        add hl,de
        ld de,hud_lines + \player * LINE_CELLS
        ld bc,LINE_CELLS
        ldir
; The continue countdown: 10 shows as 1 0.
        ld a,(UI_MODES + 2 * \player)
        and UI_MODE_MASK
        cp UI_CONTINUE
        jp nz,line_done_\player
        ld a,(UI_MODES + 2 * \player + 1)
        cp 10
        jp c,units_\player
        ld a,1                          ; the glyph of digit 1
        ld (hud_lines + \player * LINE_CELLS + COUNT_TENS_CELL),a
        xor a
units_\player:
        ld (hud_lines + \player * LINE_CELLS + COUNT_UNITS_CELL),a
line_done_\player:
        .endr
; Loop stock: up to 4 R glyphs.
        ld a,(scene_effect_flags)
        .rept SPF_LOOPS_SHIFT
        srl a
        .endr
        and SPF_LOOPS >> SPF_LOOPS_SHIFT
        ld b,a
        ld hl,hud_loop_selectors
        ld c,1
loop_glyphs:
        ld a,b
        cp c
        ld a,0                          ; space
        jr c,1f
        ld a,1                          ; R
1:      ld (hl),a
        inc hl
        inc c
        ld a,c
        cp LOOP_GLYPHS + 1
        jr nz,loop_glyphs
; End the HUD list before the boss bars. With no boss the bars cost no
; glyph visit, DMA write or damage row.
        set_io BBR, hud_templates__bbr
        ld hl,0
        ld (hud_boss_template__ptr),hl
        ld a,(UI_MODES)
        and 7 << UI_LIFE_SHIFT          ; the boss life (0-5)
        ret z
        ld hl,native_glyph
        ld (hud_boss_template__ptr),hl
; The bars are repaired on the next use of this page, also on the first
; picture after the boss goes.
        ld a,(scene_ring_start)
        add a,BOSS_ROW
        ld b,BOSS_ROWS
        ld de,(BOSS_LEFT << 8) | BOSS_RIGHT
        call scroll_mark
; The high nibble of the UI byte of player 1 holds 0-5 bars.
        ld a,(UI_MODES)
        .rept UI_LIFE_SHIFT
        rrca
        .endr
        and 7
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de                       ; bars x BOSS_CELLS
        ld de,game_boss_bar_rows
        add hl,de
        ld de,hud_lines + 2 * LINE_CELLS
        ld bc,BOSS_CELLS
        ldir
        ret

; game_boss_bar_rows: the BOSS_CELLS selectors of the boss bars for each
; life: empty bars (0), then full bars (left 1, middle 2, right 3).
game_boss_bar_rows:
        .irp life,0,1,2,3,4,5
        .fill BAR_CELLS * (BOSS_BARS - \life), 1, 0
        .rept \life
        .byte 1, 2, 2, 3
        .endr
        .endr

        .section .text.hud_batch,"ax",@progbits

; The HUD templates (a planner section, after .text.state_plan_c): draw each
; template as an 8 x 8 glyph of its selector (the glyph kernel). The fixed
; captions were drawn by native_hud_pattern. A template: handler (0 ends
; the list; below 256 a group code for the energy cache), an unused word,
; the selector lookup, the screen offset, the address of the selector. A
; lookup entry: the glyph BBR and uniform mask, the glyph descriptor.
        ld hl,rect_2_0_row
        ld (glyph_row_jump+1),hl
        xor a                           ; contiguous source rows
        ld (rect_2_0_source_gap+1),a
        ld (rect_2_1_source_gap+1),a
        ld hl,hud_batch_next
        ld (glyph_return),hl
        ld hl,hud_templates__ptr
        ld (hud_template_cursor),hl
hud_batch_next:
        set_io BBR, hud_templates__bbr
        ld sp,(hud_template_cursor)
        pop hl                          ; handler, or 0 at the end
        ld a,h
        or l
        jr z,hud_batch_done
        ld a,h
        or a
        jr nz,hud_regular_template
        ld (hud_template_cursor),sp
hud_energy_entry_jump:
        jp hud_energy_entry
hud_regular_template:
        pop bc                          ; unused
        pop hl                          ; selector lookup
        pop de                          ; screen offset
        pop bc                          ; address of the selector
        ld (hud_template_cursor),sp
        ld a,(bc)
        and SELECTOR
        add a,a
        add a,a                         ; 4 bytes for each lookup entry
        ld c,a
        ld b,0
        add hl,bc
        ld sp,hl
        pop bc                          ; C glyph BBR, B uniform mask
        pop hl                          ; glyph descriptor
        ld a,h
        or l
        jr z,hud_batch_next             ; an empty glyph
        push hl
        ld a,b
        or a
        ld hl,rect_2_0_row
        jr z,hud_row_selected
        exx
        out (c),a                       ; one mask for all rows
        exx
        ld hl,rect_2_1_row
hud_row_selected:
        ld (glyph_row_jump+1),hl
        pop hl
        ld a,c
        out0 (BBR),a
        ex de,hl
        ld bc,(hud_page_base)
        add hl,bc
        ex de,hl
        ld sp,glyph_return
        jp glyph_mapped_parameters
hud_batch_done:
        ld sp,(hud_caller_sp)
hud_energy_finish_bank:
        set_io BBR, bank_code__load__bbr
hud_energy_finish_call:
        call energy_finish
        set_io BBR, hud_templates__bbr
        ret
; hud_energy_resume: the grouped dispatch (hud_energy_cache.s) returns here,
; so it needs only one small gap. In: carry set when the group is drawn.
hud_energy_resume:
        set_io BBR, hud_templates__bbr
        jr c,hud_batch_next             ; the group is drawn
        ld sp,(hud_template_cursor)
        jr hud_regular_template

        .section .text.weapon_values,"ax",@progbits

; The weapon values (a planner section): copy the weapon state of player 1
; from the packet: the label selector, then the two digits of the time
; from weapon_timer_table (in the HUD template bank).
        ld hl,(scene_raw)
        ld de,STREAM_WEAPON
        add hl,de
        ld a,(hl)
        ld (hud_p1_weapon),a
        inc hl
        ld l,(hl)
        ld h,0
        add hl,hl
weapon_timer_operand:
        ld de,weapon_timer_table
        add hl,de
        set_io BBR, hud_templates__bbr
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(hud_p1_weapon)
        or a
        jr nz,weapon_timer_visible
        ld de,(GLYPH_BLANK << 8) | GLYPH_BLANK ; no weapon: no time
weapon_timer_visible:
        ld (hud_p1_weapon + 2),de

        .section .text.weapon_values_p2,"ax",@progbits

; The same for player 2.
        ld hl,P2_WEAPON_STATE
        ld a,(hl)
        ld (hud_p2_weapon),a
        inc hl
        ld l,(hl)
        ld h,0
        add hl,hl
weapon_timer_operand_p2:
        ld de,weapon_timer_table
        add hl,de
        set_io BBR, hud_templates__bbr
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(hud_p2_weapon)
        or a
        jr nz,weapon_timer_visible_p2
        ld de,(GLYPH_BLANK << 8) | GLYPH_BLANK
weapon_timer_visible_p2:
        ld (hud_p2_weapon + 2),de

        .section .text.native_hud_pattern,"ax",@progbits

; native_hud_pattern: a plan list command for the fixed HUD captions
; (scripts/pattern_hud.py): identical latch patterns are reused. Stack in:
; program BBR, program pointer, physical band base. The program starts
; with the source BBR and segment and the source address of its pattern;
; its stores end with a jump to native_glyph_done.
native_hud_pattern:
        pop bc
        ld a,c
        ld (pattern_bank),a
        out0 (BBR),a
        pop hl
        pop de
        ld (glyph_outer_sp),sp
        ld (pattern_program),hl
        ld hl,(hud_page_base)
        add hl,de
        ex de,hl
        ld hl,(pattern_program)
        ld a,d
        .rept 4
        rrca
        .endr
        and 0x0F
        add a,VGA_WINDOW_E000           ; video RAM CBR: the whole 64-row band
        out0 (CBR),a
        ld a,d
        and 0x0F
        or WINDOW_E000 >> 8             ; CBR window
        ld d,a
        ld (pattern_destination),de
        ld sp,hl
        pop bc
        pop hl
        ld (pattern_source),hl
        ld hl,0
        add hl,sp
        ld (hud_pattern_jump+1),hl      ; the stores after the header
        ld a,c
        out0 (BBR),a
        ld d,b
        ld bc,OAK_INDEX
        ld a,OAK_READ_SEGMENT
        out (c),a
        inc c
        out (c),d
        ld hl,(pattern_source)
        ld a,(hl)                       ; load all four latches once
        ld a,(pattern_bank)
        out0 (BBR),a
        ld hl,(pattern_destination)
hud_pattern_jump:
        jp 0                            ; patched: the pattern stores
