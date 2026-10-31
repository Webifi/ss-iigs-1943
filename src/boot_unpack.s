; Boot DATA blocks: source $00:0800, destination $01:8000, $26 output length.
; MVN copies forward, including overlapping matches; interrupts are masked.
.a8
.i16
startup_unpack:
  phb
  ldx #$0800
  ldy #$8000
  rep #$20
  lda $26
  clc
  adc #$8000
  sta $26
  sep #$20
@token:
  lda f:$000000,x
  bmi @match
  inx
  rep #$20
  and #$00ff
  mvn #$00,#$01
  sep #$20
  bra @next
@match:
  inx
  and #$7f
  clc
  adc #2
  rep #$20
  and #$00ff
  sta $24
  lda f:$000000,x
  sta $28
  inx
  inx
  phx
  tya
  sec
  sbc $28
  tax
  lda $24
  mvn #$01,#$01
  plx
  sep #$20
@next:
  cpy $26
  bcc @token
  plb
  rts
