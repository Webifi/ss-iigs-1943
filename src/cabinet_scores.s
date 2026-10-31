; Score header: the greatest of the ranking leader and both live scores.
; The eight-byte scratch is unused bank-zero cabinet state ($1570-$1577).
; X is the start of the world trailer; preserve X and Y for its caller.
.a8
.i16
CAB_HIGH_SCORE = $1570

cabinet_highscore_packet:
  phx
  phy
  ldx #7
@initial:
  lda f:CAB_SCORES,x
  sta CAB_HIGH_SCORE,x
  dex
  bpl @initial
  ldx #0
  jsr .loword(cabinet_highscore_compare)
  ldx #128
  jsr .loword(cabinet_highscore_compare)
  ldx #0
  jsr .loword(cabinet_retained_compare)
  ldx #8
  jsr .loword(cabinet_retained_compare)
  ply
  plx
  rep #$20
  .repeat 4,I
    lda CAB_HIGH_SCORE+I*2
    xba
    sta a:38+I*2,x
  .endrepeat
  sep #$20
  rtl

; X selects the player's first byte; scores are most-significant digit first.
cabinet_highscore_compare:
  ldy #0
@compare:
  lda PLAYER+$38,x
  cmp CAB_HIGH_SCORE,y
  bcc @done
  bne @copy
  inx
  iny
  cpy #8
  bcc @compare
@done:
  rts
@copy:
  rep #$20
  txa
  and #$0080
  tax
  sep #$20
  ldy #0
@digit:
  lda PLAYER+$38,x
  sta CAB_HIGH_SCORE,y
  inx
  iny
  cpy #8
  bcc @digit
  rts

; Include the best finished attempt even after continue clears its display.
cabinet_retained_compare:
  ldy #0
@compare:
  lda CAB_ENDING_SCORES,x
  cmp CAB_HIGH_SCORE,y
  bcc @done
  bne @copy
  inx
  iny
  cpy #8
  bcc @compare
@done:
  rts
@copy:
  rep #$20
  txa
  and #$0008
  tax
  sep #$20
  ldy #0
@digit:
  lda CAB_ENDING_SCORES,x
  sta CAB_HIGH_SCORE,y
  inx
  iny
  cpy #8
  bcc @digit
  rts
