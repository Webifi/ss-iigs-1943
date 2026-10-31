; Receive the per-update game state that follows the object records.

        .global game_world_receive

        .equ OBJECT_COUNT, 6            ; packet offset of the object count
        .equ STATE_HEADER, 26           ; packet bytes before the object records
        .equ NATIVE_MENU, 127           ; second trailer byte of a menu packet
        .equ HUD_STATE_BYTES, 22
        .equ CABINET_VALUE_BYTES, 16

        .section .text.game_world_receive,"ax",@progbits

game_world_receive:
        ld hl,(stream_active_packet)
        ld de,OBJECT_COUNT
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        add hl,hl                       ; four bytes per object
        add hl,hl
        ld de,(stream_active_packet)
        add hl,de
        ld de,STATE_HEADER
        add hl,de
        ; A menu packet is recognized before it changes any retained state.
        inc hl
        ld a,(hl)
        cp NATIVE_MENU
        jp z,input_menu_receive
        dec hl
        ld a,(hl)
        ld (bg_pan),a
        inc hl
        ld a,(hl)
        ld (cabinet_mode),a
        inc hl
        ld de,hud_player_state          ; second player and prompt state
        ld bc,HUD_STATE_BYTES
        ldir
        ld de,cabinet_values
        ld bc,CABINET_VALUE_BYTES
        ldir
        ; Only a live initials overlay carries its extra 14-byte trailer. The
        ; descriptor-resident helper clears stale state and finds the upload list.
        jp cab_live_receive_map
