; HUD: the two-player score lines, the weapon labels, the boss bars and
; the fixed captions. The state packet carries values; the card selects
; the glyphs.

        .include "video.inc"

        .global game_hud_values, game_boss_bar_rows
        .global hud_batch_next, hud_energy_entry_jump, hud_regular_template
        .global hud_row_selected, hud_batch_done, hud_energy_finish_bank
        .global hud_energy_finish_call, hud_energy_resume
        .global weapon_timer_operand, weapon_timer_visible
        .global weapon_timer_operand_p2, weapon_timer_visible_p2
        .global native_hud_pattern, hud_pattern_jump

        .equ BLANK, 0x0A                ; digit selector: no glyph
        .equ SPACE, 0x24
        .equ ENERGY_GLYPHS, 0x25
        .equ LINE_CELLS, 14
        .equ BOSS_CELLS, 20

; Player 2 HUD values from the packet: score digits, energy cells, UI mode
; and value of each player.
        .equ P2_ENERGY, hud_p2_score + 8
        .equ UI_MODES, hud_p2_score + 16
        .equ P2_WEAPON_STATE, hud_p2_score + 20

        .section .text.game_hud_values,"ax",@progbits

; Make the selectors of both HUD lines, the loop stock and the boss bars.
game_hud_values:
        ld hl,hud_p2_score
        ld b,7                          ; leading digits
1:      ld a,(hl)
        or a
        jp nz,lines
        ld (hl),BLANK
        inc hl
        djnz 1b
lines:
        .irp player,0,1
; The energy cells, or the message of the UI mode.
        ld a,(UI_MODES + 2 * \player)
        and 0x0F
        or a
        jp nz,message_\player
        .if \player == 0
        ld hl,hud_p1_score + 8
        .else
        ld hl,P2_ENERGY
        .endif
        ld de,hud_lines + \player * LINE_CELLS
        ld b,8
1:      ld a,(hl)
        inc hl
        and 0x0F
        add a,ENERGY_GLYPHS
        ld (de),a
        inc de
        djnz 1b
        ld a,SPACE
        .rept 6
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
        sbc hl,de                       ; mode x 14
        ld de,game_hud_messages
        add hl,de
        ld de,hud_lines + \player * LINE_CELLS
        ld bc,LINE_CELLS
        ldir
; The continue countdown: 10 shows as 1 0.
        ld a,(UI_MODES + 2 * \player)
        and 0x0F
        cp 3                            ; countdown
        jp nz,line_done_\player
        ld a,(UI_MODES + 2 * \player + 1)
        cp 10
        jp c,units_\player
        ld a,1
        ld (hud_lines + \player * LINE_CELLS + 11),a
        xor a
units_\player:
        ld (hud_lines + \player * LINE_CELLS + 12),a
line_done_\player:
        .endr
; Loop stock: up to 4 R glyphs.
        ld a,(scene_effect_flags)
        srl a
        srl a
        and 7
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
        cp 5
        jr nz,loop_glyphs
; End the HUD list before the boss bars. With no boss the bars cost no
; glyph visit, DMA write or damage row.
        set_io BBR, hud_templates__bbr
        ld hl,0
        ld (hud_boss_template),hl
        ld a,(UI_MODES)
        and 0x70                        ; boss life
        ret z
        ld hl,native_glyph
        ld (hud_boss_template),hl
; The bars are repaired on the next use of this page, also on the first
; picture after the boss goes.
        ld a,(scene_ring_start)
        add a,32                        ; boss row
        ld b,8
        ld de,(14 << 8) | 54            ; left and right group
        call scroll_mark
; The high nibble of the UI byte of player 1 holds 0-5 bars.
        ld a,(UI_MODES)
        .rept 4
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
        add hl,de                       ; bars x 20
        ld de,game_boss_bar_rows
        add hl,de
        ld de,hud_lines + 2 * LINE_CELLS
        ld bc,BOSS_CELLS
        ldir
        ret

; Selectors of the five boss bars for each life: empty, then full bars.
game_boss_bar_rows:
        .irp life,0,1,2,3,4,5
        .fill 4 * (5 - \life), 1, 0
        .rept \life
        .byte 1, 2, 2, 3
        .endr
        .endr

        .section .text.hud_batch,"ax",@progbits

; Draw the resident HUD templates: all are 8 x 8 glyphs with a variable
; selector. The fixed captions were drawn by native_hud_pattern.
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
        and 0x3F
        add a,a
        add a,a
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
; The grouped dispatch returns here, so it needs only one small gap.
hud_energy_resume:
        set_io BBR, hud_templates__bbr
        jr c,hud_batch_next             ; the group is drawn
        ld sp,(hud_template_cursor)
        jr hud_regular_template

        .section .text.weapon_values,"ax",@progbits

; Copy the weapon state of player 1 from the packet: the label selector,
; then the two digits of the time from the build table in bank 9.
        ld hl,(scene_raw)
        ld de,24                        ; weapon state
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
        ld de,(BLANK << 8) | BLANK
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
        ld de,(BLANK << 8) | BLANK
weapon_timer_visible_p2:
        ld (hud_p2_weapon + 2),de

        .section .text.native_hud_pattern,"ax",@progbits

; Fixed HUD captions: identical latch patterns are reused. Stack in:
; program BBR, program pointer, physical band base. The program starts
; with the source BBR and segment and the source address of its pattern.
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
        add a,0x92                      ; video RAM CBR: the whole 64-row band
        out0 (CBR),a
        ld a,d
        and 0x0F
        or 0xE0                         ; CBR window
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
