; Damage marks for the fixed HUD areas, from the prepared bounds list.

        .global state_hud_damage, state_hud_bound

        .section .text.hud_damage,"ax",@progbits

; Mark the screen rows under every prepared HUD bound for repair.
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
        add a,c
        call scroll_mark
        pop hl
        jr state_hud_bound
