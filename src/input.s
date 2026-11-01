; The game side of the input: thin bank-zero calls into the input code
; (src/input_native.s, the INPUT segment). The keyboard, mouse and joystick
; interrupts and the DOC timer capture timestamped events there; the game
; takes them in update order. Nothing here waits for a device.
.a8
.i16
; The bits of INPUT_P1 and INPUT_P2: 0 = pressed (active low, as the arcade).
INPUT_STICK = $0f            ; bits 0-3: the four stick directions
INPUT_RIGHT = $01
INPUT_LEFT = $02
INPUT_DOWN = $04
INPUT_UP = $08
INPUT_FIRE = $10             ; button 1: fire
INPUT_SPECIAL = $20          ; button 2: the special attack
INPUT_NONE = $ff             ; no stick direction and no button
; The bits of INPUT_SYSTEM: 0 = pressed.
SYSTEM_START1 = $01          ; 1 player start
SYSTEM_START2 = $02          ; 2 players start
SYSTEM_COIN1 = $40           ; coin slot A
SYSTEM_COIN2 = $80           ; coin slot B
SYSTEM_MENU = $10            ; the pause menu (ESC); not an arcade input

; input_init: start the input devices and the event capture (flight_loop).
input_init:
  jsl native_input_start
  rts

; input_poll: give the input code idle time while the game waits for its
; next update (flight_clock_wait). It calls native_input_idle once for each
; new GAME_UPDATES value: the operand of the CMP below keeps the last value.
; A8: changed.
input_poll:
  lda GAME_UPDATES
input_poll_last:
  cmp #$ff                      ; patched: the GAME_UPDATES of the last call
  beq input_poll_done
  sta input_poll_last+1
  jsl native_input_idle
input_poll_done:
  rts

; input_sample: read the devices that have no interrupt (once each update).
input_sample:
  jsl native_input_sample
  rts

; input_tick: apply every captured event up to now (GAME_CLOCK) to
; INPUT_P1 and INPUT_P2. Returns with A8.
input_tick:
  a16
  lda f:GAME_CLOCK
  jsl native_input_consume_until
  rts

; input_mouse_center: the mouse stick returns to the centre (cabinet_start).
input_mouse_center:
  jml native_input_center

; input_menu_send: send the menu picture in PACKET_BUFFER to the card
; (src/menu_mirror_host.s). It uses the next packet token, as the game loop
; does. Called with JSL from any bank and width; it keeps P, DBR and D.
input_menu_send:
  php
  phb
  phd
  ax16
  lda #ZERO_PAGE                ; D = the game page zero
  tcd
  a8
  pha                           ; A is 0: DBR = bank 0
  plb
  lda GAME_PICTURE
  and #1                        ; bit 0 selects the card buffer
  ora #PACKET_TOKEN
  jsr stream_packet
  a16
  inc GAME_PICTURE
  pld
  plb
  plp
  rtl

.include "input_disk_bridge.s"

; The menu (in the MIRROR segment) uses the card handshake of the bank-zero
; startup code (on, off and done in src/game.s) through these far entries.
mirror_gate_on:
  jsr on
  rtl
mirror_gate_off:
  jsr off
  rtl
mirror_gate_done:
  jsr done
  rtl
