; HUD repair marks: the rows under the fixed HUD areas of the page get a
; repair mark from the prepared bounds list (gen/hud_bounds.s, from
; scripts/hud_fast.py).

        .global state_hud_damage

        .section .text.hud_damage,"ax",@progbits

; state_hud_damage: mark the page rows under each HUD bound for repair, so
; that the next draw of the page restores the background there.
; state_hud_bound: the same from the bound record at HL.
; Bound record: height (0 ends the list), screen row, left group, right
; group. AF, BC, DE, HL changed.
state_hud_damage:
        ld hl,state_hud_bounds
state_hud_bound:
        ld b,(hl)                       ; height; 0 ends the list
        inc hl
        ld a,b
        or a
        ret z
        ld c,(hl)                       ; screen row
        inc hl
        ld d,(hl)                       ; left
        inc hl
        ld e,(hl)                       ; right
        inc hl
        push hl
        ld a,(scene_ring_start)
        add a,c                         ; the page row of the screen row
        call scroll_mark
        pop hl
        jr state_hud_bound
