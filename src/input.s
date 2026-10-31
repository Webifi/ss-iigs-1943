; The game consumes native timestamped input. DATA/mouse and the existing
; DOC timer own capture. No renderer hook and no spin waiting for a reply.
.a8
.i16
INPUT_P1 = $1200
INPUT_SYSTEM = $1201
INPUT_P2 = $120b
INPUT_KEYS = native_input_keyHeld
input_init:
  jsl native_input_start
  rts
input_poll:
  lda $68
input_poll_last:
  cmp #$ff
  beq input_poll_done
  sta input_poll_last+1
  jsl native_input_idle
input_poll_done:
  rts
input_sample:
  jsl native_input_sample
  rts
input_tick:
.ifdef CONTINUOUS_GAME
  rep #$20
  lda f:$001e96
  jsl native_input_consume_until
.endif
  rts
input_mouse_center:
  jml native_input_center

; Foreground consumer only. Capture remains on DATA/mouse and DOC interrupts.
input_menu_send:
  php
  phb
  phd
  rep #$30
  lda #0
  tcd
  sep #$20
  pha
  plb
  lda GAME_PICTURE
  and #1
  ora #$40
  jsr stream_packet
  rep #$20
  inc GAME_PICTURE
  pld
  plb
  plp
  rtl

.include "input_disk_bridge.s"

; Firmware handshake routines live in the retained bank-zero startup stub.
mirror_gate_on:
  jsr on
  rtl
mirror_gate_off:
  jsr off
  rtl
mirror_gate_done:
  jsr done
  rtl
