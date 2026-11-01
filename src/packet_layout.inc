; The update packet: the IIgs (src/state_packet.s, src/game_world.s) writes
; it, the Second Sight (src/secondsight/stream.s, src/secondsight/include/stream.inc)
; receives it. Both assemblers (ca65 and GNU as) read this file, so it has
; only decimal NAME = value lines.
;
; The IIgs stores each word high byte first; the PEI sender sends the low
; byte of each word first. On the Second Sight a word is little-endian, and
; a byte field at offset N is at offset N ^ 1.

; The packet header: offsets from the start of the packet.
PKT_SIZE            = 0         ; the bytes after this word
PKT_SEA             = 2         ; SEA_CAMERA
PKT_FOREGROUND      = 4         ; FG_CAMERA
PKT_PICTURE         = 6         ; GAME_PICTURE
PKT_OBJECT_COUNT    = 8         ; the object records that follow
PKT_SCORE           = 10        ; P1 PL_SCORE
PKT_ENERGY          = 18        ; the P1 energy gauge
PKT_TIME            = 26        ; PL_WEAPON_TIME, or the game seconds
PKT_WEAPON          = 27        ; PL_WEAPON, or PACKET_PAGE_WEAPON + GAME_FLOW
PKT_OBJECTS         = 28        ; the object records
PACKET_AREA         = 1792      ; the packet bytes that the card receive area takes
PACKET_PAGE_WEAPON  = 16        ; PKT_WEAPON on a cabinet page: this + GAME_FLOW

; An object record.
PACKET_CODE         = 0         ; the sprite code word
PACKET_POSITION     = 2         ; the cross and along coordinates
PACKET_RECORD       = 4

; The world trailer after the object records (game_world_append): its
; header, then the fields at TRAILER_HEADER + field.
TRAILER_MODE        = 0         ; the cabinet wire mode, then CAB_PACKET_MODE
TRAILER_CROSS       = 1         ; CAMERA_CROSS
TRAILER_HEADER      = 2
PACKET_MENU_MODE    = 127       ; TRAILER_MODE of the menu packet (scripts/menu_mirror.py)
TRAILER_SCORE2      = 0         ; P2 PL_SCORE
TRAILER_ENERGY2     = 8         ; the P2 energy gauge
TRAILER_UI_COUNT    = 16        ; PLAYER_UI_COUNT of P1
TRAILER_UI_MODE     = 17        ; AIR_LIFE in bits 4-7, PLAYER_UI_MODE of P1
TRAILER_UI_COUNT2   = 18
TRAILER_UI_MODE2    = 19
TRAILER_TIME2       = 20        ; P2 PL_WEAPON_TIME
TRAILER_WEAPON2     = 21        ; P2 PL_WEAPON
TRAILER_RESULT      = 22        ; CAB_RESULT_DIGITS, the first digit
TRAILER_CREDITS     = 23        ; GAME_CREDITS
TRAILER_RESULT_REST = 24        ; the other result digits, in byte pairs
TRAILER_COUNT       = 34        ; SPECIAL_TIMER
TRAILER_FLAGS       = 36        ; bit 0 the ending, bit 1 the live fields follow
TRAILER_SPECIAL     = 37        ; SPECIAL_FLAGS and the SPF_* flash bits
TRAILER_TEXT        = 38        ; CAB_ENDING_TEXT: the typed letters of the layout
TRAILER_SIZE        = 40        ; then the live fields, if any
TRAILER_LIVE_LAYOUT = 12        ; in the live fields: CAB_LIVE_LAYOUT
; TRAILER_UI_MODE: the UI mode in bits 0-3, AIR_LIFE (the boss bars) above.
UI_MODE_MASK        = 15
UI_LIFE_SHIFT       = 4
UI_INSERT_COIN      = 1         ; the ROM message INSERT COIN
UI_PUSH_BUTTON      = 2         ; PUSH BUTTON
UI_CONTINUE         = 3         ; CONTINUE and PLAYER_UI_COUNT
UI_GAME_OVER        = 4         ; GAME OVER
UI_BLANK            = 5         ; no message

; The TRAILER_SPECIAL bits (the Second Sight: scene_effect_flags).
SPF_BG2_OFF         = 1         ; GAME_BG2_DISABLED: the sea layer is off
SPF_CYAN            = 2         ; the sea flashes cyan
SPF_LOOPS_SHIFT     = 2         ; bits 2-4: SPECIAL_LOOPS, the loops for the HUD
SPF_LOOPS           = 7 << SPF_LOOPS_SHIFT
SPF_OVERLAY         = 32        ; a special helper is in the packet
SPF_DARK            = 64        ; the sea flashes dark (Tsunami)
SPF_CLOUDS          = 128       ; the clouds are lit (Lightning)
