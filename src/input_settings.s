; The input settings: one SETTINGS_SIZE image holds all of them (on the
; disk). The compiled binding columns change only at a load or an edit.
.a16
.i16
.include "default_bindings.inc"
LANGSEL_PAL = $10            ; LANGSEL: 50 Hz
PAL_BEAM_PERIOD = 156        ; beamPeriod at 50 Hz
SLOTS = 7                    ; a SNES MAX adapter in slot 1-6, not slot 3

; defaults: the settings at the start: checked, the mix, the J13 settings,
; the beam period of the video standard, the bindings. JSR.
defaults:
  jsr .loword(settings_check)
  jsr .loword(mix_settings)
  jsl J13SettingsLoad
  a8
  lda f:LANGSEL
  and #LANGSEL_PAL
  beq :+
  lda #PAL_BEAM_PERIOD
  sta a:.loword(beamPeriod)
:
  a16
  jsr .loword(compile_bindings)
  rts

; compile_bindings: the binding columns (boundKeys, boundSources,
; boundBits, boundSystem) from the BIND_COUNT records, and the slot of the
; SNES MAX reads (patched in pad_data, pad_latch, pad_clock). JSR.
compile_bindings:
  ldx #0
  ldy #0
@binding:
  lda a:.loword(settings+SET_BINDINGS+BIND_KEY),y
  and #255
  sta a:.loword(boundKeys),x
  lda a:.loword(settings+SET_BINDINGS+BIND_SOURCE),y
  and #255
  sta a:.loword(boundSources),x
  cmp #SOURCE_DEVICE_FIRST
  bcc @keyboard
  sec
  sbc #SOURCE_MOUSE-DEV_MOUSE/16
  asl
  asl
  asl
  asl                           ; (source - 2) * 16
  clc
  adc a:.loword(boundKeys),x
  sta a:.loword(boundKeys),x
@keyboard:
  stz a:.loword(boundBits),x
  stz a:.loword(boundSystem),x
  phy
  lda a:.loword(settings+SET_BINDINGS+BIND_ACTION),y
  and #255
  cmp #BIND_ACTIONS
  bcs @unused
  asl
  tay
  lda a:.loword(actionMask),y
  sta a:.loword(boundBits),x
  lda a:.loword(actionSystem),y
  sta a:.loword(boundSystem),x
  bra @next
@unused:
  lda #$ffff
  sta a:.loword(boundKeys),x
@next:
  ply
  iny
  iny
  iny
  iny                           ; BINDING_SIZE
  inx
  inx
  cpx #BIND_COUNT*2
  bcc @binding
  a8
  lda a:.loword(settings+SET_SNES_SLOT)
  beq @slot_off
  cmp #SLOTS
  bcs @slot_off
  cmp #3
  beq @slot_off
  asl
  asl
  asl
  asl                           ; 16 device bytes a slot
  clc
  adc #.lobyte(SLOT_DEVICE)
  sta f:pad_data+1
  sta f:pad_latch+1
  inc
  sta f:pad_clock+1
  bra @ready
@slot_off:
  stz a:.loword(settings+SET_SNES_SLOT)
@ready:
  a16
  jmp .loword(compile_masks)

; The bits of each BIND_ACTION: the INPUT_P1 bits in the low byte, the
; INPUT_P2 bits in the high byte, and the INPUT_SYSTEM bits. The game sees
; them active low.
actionMask:
  .word INPUT_RIGHT,INPUT_LEFT,INPUT_DOWN,INPUT_UP,INPUT_FIRE,INPUT_SPECIAL
  .word INPUT_RIGHT<<8,INPUT_LEFT<<8,INPUT_DOWN<<8,INPUT_UP<<8,INPUT_FIRE<<8,INPUT_SPECIAL<<8
  .word 0,0,0,0
actionSystem:
  .word 0,0,0,0,0,0,0,0,0,0,0,0
  .word SYSTEM_START1,SYSTEM_START2,SYSTEM_COIN1,SYSTEM_COIN2
.assert *-actionSystem = BIND_ACTIONS*2, error

; settings: the settings image (SET_* layout) with the defaults.
settings:
  .byte "1943KEY",1
  .byte 0,0,DEAD_ZONE_DEFAULT,0 ; SET_J13, SET_SNES_SLOT, SET_DEAD_ZONE
  .res ::SET_DIP_A-::SET_MUSIC_LEVEL,0  ; the mix (mix_settings), the device players
  .byte DIP_A_DEFAULT,DIP_B_DEFAULT,DIP_MARK
  .res ::SET_BINDINGS-::SET_DIP_MARK-1,0
  default_bindings
  .res ::SETTINGS_CHECKSUM-(*-settings),0
  .word 0                       ; the checksum: settings_sum
.assert *-settings = SETTINGS_SIZE, error
.assert SET_MUSIC_LEVEL = 12 .and SET_DIP_B = SET_DIP_A+1 .and SET_DIP_MARK = SET_DIP_A+2, error

; dip_apply: GAME_DIP_A and GAME_DIP_B from the settings (the defaults when
; SET_DIP_MARK is not DIP_MARK: an older SS1943.CONFIG), with the demo sound
; switch from SET_MIX_FLAGS. JSL; the widths kept.
dip_apply:
  php
  a8
  lda f:settings+SET_DIP_MARK
  cmp #DIP_MARK
  beq :+
  lda #DIP_A_DEFAULT
  sta f:settings+SET_DIP_A
  lda #DIP_B_DEFAULT
  sta f:settings+SET_DIP_B
  lda #DIP_MARK
  sta f:settings+SET_DIP_MARK
:
  lda f:settings+SET_DIP_A
  sta f:GAME_DIP_A
  lda f:settings+SET_MIX_FLAGS
  lsr                           ; MIX_DEMO_SOUND into the carry
  lda f:settings+SET_DIP_B
  and #<~DIP_B_DEMO_SOUND
  bcc :+
  ora #DIP_B_DEMO_SOUND
:
  sta f:GAME_DIP_B
  plp
  rtl
.assert MIX_DEMO_SOUND = 1, error
.assert BINDING_SIZE = 4, error ; the INYs above
