; Decimal digit addition from original-US $0379-$0392, enemy awards at $2397.
.a8
.i16
.ifndef PLAYER
PLAYER = $1000
.endif
SCORE_AWARD_INDEX = $1168

score_add:
  rep #$20
  lda SCORE_AWARD_INDEX
  and #255
  tax
  sep #$20
  stz $d0
  ldy #7
@digit:
  lda score_awards,x
  clc
  adc $d0
  clc
  adc PLAYER+$38,y
  stz $d0
  cmp #10
  bcc @store
  sec
  sbc #10
  inc $d0
@store:
  sta PLAYER+$38,y
  dex
  dey
  bpl @digit
  rts

score_hud:
  rep #$20
  ldx #SCORE_CHAR_OFFSET
  ldy #0
  stz $d0
@digit:
  lda PLAYER+$38,y
  and #255
  bne @nonzero
  cpy #7
  beq @store
  lda $d0
  bne @zero
  lda #$24
  bra @store
@nonzero:
  pha
  lda #1
  sta $d0
  pla
  bra @store
@zero:
  lda #0
@store:
  sta $1600,x
  txa
  clc
  adc #8
  tax
  iny
  cpy #8
  bne @digit
  sep #$20
  rts
