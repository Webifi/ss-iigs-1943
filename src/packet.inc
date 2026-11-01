; The update packet that flight_state_packet_far (src/state_packet.s) writes
; to PACKET_BUFFER and stream_packet sends to the card. The layout and the
; byte order: src/packet_layout.inc (the card reads the same file).
.include "packet_layout.inc"
; The handshake token of a packet: PACKET_TOKEN for the card buffer at $4000,
; PACKET_TOKEN+1 for the buffer at $8000. Bit 0 of GAME_PICTURE selects it.
PACKET_TOKEN        = secondsight_READY_TOKEN
PACKET_SIZE         = PACKET_BUFFER+PKT_SIZE
PACKET_SEA          = PACKET_BUFFER+PKT_SEA
PACKET_FOREGROUND   = PACKET_BUFFER+PKT_FOREGROUND
PACKET_PICTURE      = PACKET_BUFFER+PKT_PICTURE
PACKET_OBJECTS_COUNT = PACKET_BUFFER+PKT_OBJECT_COUNT
PACKET_SCORE        = PACKET_BUFFER+PKT_SCORE
PACKET_ENERGY       = PACKET_BUFFER+PKT_ENERGY
PACKET_TIME         = PACKET_BUFFER+PKT_TIME
PACKET_WEAPON       = PACKET_BUFFER+PKT_WEAPON
PACKET_OBJECTS      = PACKET_BUFFER+PKT_OBJECTS
