; The update packet as the Second Sight receives it (src/packet_layout.inc):
; stream_active_packet points after the size word, and a byte field at
; packet offset N is at N ^ 1 (the PEI sender swaps the bytes of each word).

        .ifndef STREAM_INC
        .equ STREAM_INC, 1

        .include "packet_layout.inc"

; The two receive buffers are secondsight.ld .packet_buffer_0 and ._1:
; DMA channel 1 fills one while the card draws from the other. A buffer is
; named by its high byte; the bits of the high bytes give the handshake
; token (stream_arm) and the other buffer (XOR with stream_other).
        .equ STREAM_BUFFER_SIZE, 0x4000 ; the receive count of channel 1

; Offsets from stream_active_packet.
        .equ STREAM_SEA, PKT_SEA - PKT_SEA
        .equ STREAM_FOREGROUND, PKT_FOREGROUND - PKT_SEA
        .equ STREAM_OBJECT_COUNT, PKT_OBJECT_COUNT - PKT_SEA
        .equ STREAM_SCORE, PKT_SCORE - PKT_SEA
        .equ STREAM_OBJECTS, PKT_OBJECTS - PKT_SEA
        .equ STREAM_TIME, (PKT_TIME ^ 1) - PKT_SEA
        .equ STREAM_WEAPON, (PKT_WEAPON ^ 1) - PKT_SEA

; The trailer fields, from TRAILER_HEADER (hud_player_state holds the first
; ones).
        .equ STREAM_ENERGY2, TRAILER_ENERGY2
        .equ STREAM_UI_MODE, TRAILER_UI_MODE ^ 1
        .equ STREAM_UI_COUNT, TRAILER_UI_COUNT ^ 1
        .equ STREAM_WEAPON2, TRAILER_WEAPON2 ^ 1
        .equ STREAM_TIME2, TRAILER_TIME2 ^ 1
; The trailer fields from TRAILER_RESULT (cabinet_values holds them).
        .equ CABINET_COUNT_HIGH, (TRAILER_COUNT ^ 1) - TRAILER_RESULT
        .equ CABINET_SPECIAL, (TRAILER_SPECIAL ^ 1) - TRAILER_RESULT
        .equ CABINET_FLAGS, (TRAILER_FLAGS ^ 1) - TRAILER_RESULT

; The world trailer header bytes, from the trailer start.
        .equ STREAM_TRAILER_MODE, TRAILER_MODE ^ 1
        .equ STREAM_TRAILER_CROSS, TRAILER_CROSS ^ 1

        .endif
