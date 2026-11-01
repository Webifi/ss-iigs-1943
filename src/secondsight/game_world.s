; Receive the world trailer of the update packet: the part of the game
; state that follows the object records (src/game_world.s writes it).

        .include "stream.inc"

        .global game_world_receive

; The trailer fields that the card keeps: hud_player_state takes the player
; 2 and prompt fields, cabinet_values the result, count and flag fields.
        .equ HUD_STATE_BYTES, TRAILER_RESULT - TRAILER_SCORE2
        .equ CABINET_VALUE_BYTES, TRAILER_SIZE - TRAILER_RESULT

        .if STREAM_TRAILER_CROSS != 0 || STREAM_TRAILER_MODE != 1
        .error "game_world_receive reads the cross at trailer+0, the mode at trailer+1"
        .endif

        .section .text.game_world_receive,"ax",@progbits

; game_world_receive: copy the trailer of the active packet into the card
; state, or hand a menu packet to input_menu_receive. Then
; cab_live_receive_map takes the live fields and the upload list.
; In: stream_active_packet. AF, BC, DE, HL changed.
game_world_receive:
        ld hl,(stream_active_packet)
        ld de,STREAM_OBJECT_COUNT
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        add hl,hl                       ; PACKET_RECORD (4) bytes per object
        add hl,hl
        ld de,(stream_active_packet)
        add hl,de
        ld de,STREAM_OBJECTS
        add hl,de                       ; HL the trailer
        ; A menu packet is recognized before it changes any retained state.
        inc hl
        ld a,(hl)                       ; the mode
        cp PACKET_MENU_MODE
        jp z,input_menu_receive
        dec hl
        ld a,(hl)                       ; the camera cross
        ld (bg_pan),a
        inc hl
        ld a,(hl)
        ld (cabinet_mode),a
        inc hl                          ; the fields after TRAILER_HEADER
        ld de,hud_player_state          ; second player and prompt state
        ld bc,HUD_STATE_BYTES
        ldir
        ld de,cabinet_values
        ld bc,CABINET_VALUE_BYTES
        ldir
        ; Only a live initials overlay carries its extra 14-byte trailer. The
        ; descriptor-resident helper clears stale state and finds the upload list.
        jp cab_live_receive_map
