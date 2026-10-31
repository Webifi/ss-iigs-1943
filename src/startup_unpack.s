; Startup only. Source $20-$22, output byte count $26. Reuses a 16 KB bank-one
; buffer after each completed upload. Gameplay never calls this routine.
; Literal token: length-1. Match token: $80|(length-3), then 16-bit distance.
.a8
.i16
startup_unpack:
  phb
  lda #1
  pha
  plb
  ldx #0
  ldy #0
@token:
  lda [$20],y
  bmi @match
  iny
  inc
  sta $24
@literal:
  lda [$20],y
  iny
  sta f:$018000,x
  inx
  dec $24
  bne @literal
  bra @next
@match:
  iny
  and #127
  clc
  adc #3
  sta $24
  rep #$20
  lda [$20],y
  sta $28
  iny
  iny
  sty $2c
  txa
  sec
  sbc $28
  tay
  sep #$20
@copy:
  lda a:$8000,y
  sta f:$018000,x
  iny
  inx
  dec $24
  bne @copy
  ldy $2c
@next:
  cpx $26
  bcc @token
  plb
  rts
