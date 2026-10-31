; A fixed 512-byte image is the complete persisted input configuration.
; Compiled binding columns are rebuilt only on an edit/load, never per tick.
.a16
.i16
defaults:
  jsr .loword(settings_check)
  jsr .loword(mix_settings)
  jsl J13SettingsLoad
  sep #$20
  lda f:$e0c02b
  and #16
  beq :+
  lda #156
  sta a:.loword(beamPeriod)
:
  rep #$20
  jsr .loword(compile_bindings)
  rts

compile_bindings:
  ldx #0
  ldy #0
@binding:
  lda a:.loword(settings+32),y
  and #255
  sta a:.loword(boundKeys),x
  lda a:.loword(settings+33),y
  and #255
  sta a:.loword(boundSources),x
  cmp #4
  bcc @keyboard
  sec
  sbc #2
  asl
  asl
  asl
  asl
  clc
  adc a:.loword(boundKeys),x
  sta a:.loword(boundKeys),x
@keyboard:
  stz a:.loword(boundBits),x
  stz a:.loword(boundSystem),x
  phy
  lda a:.loword(settings+34),y
  and #255
  cmp #16
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
  iny
  inx
  inx
  cpx #BIND_COUNT*2
  bcc @binding
  sep #$20
  lda a:.loword(settings+9)
  beq @slot_off
  cmp #7
  bcs @slot_off
  cmp #3
  beq @slot_off
  asl
  asl
  asl
  asl
  clc
  adc #$80
  sta f:pad_data+1
  sta f:pad_latch+1
  inc
  sta f:pad_clock+1
  bra @ready
@slot_off:
  stz a:.loword(settings+9)
@ready:
  rep #$20
  jsr .loword(compile_masks)
  rts

; Arcade player bits: right/left/down/up, gun, special. System bits are
; P1/P2 start, coins A/B and pause; the consumers see active-low bytes.
actionMask:
  .word 1,2,4,8,16,32,256,512,1024,2048,4096,8192,0,0,0,0,0
actionSystem:
  .word 0,0,0,0,0,0,0,0,0,0,0,0,1,2,64,128,16

settings:
  .byte "1943KEY",1
  .byte 0,0,9,0                 ; explicit J13 flag, SNES MAX slot, mouse dead zone
  .res 20,0
  .include "input_defaults.inc"
  .res 510-(*-settings),0
  .word 0
