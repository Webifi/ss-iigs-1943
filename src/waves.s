; Original US bank 0 $880B-$88D5, rewritten for the IIgs.
; Three fighters use the first free slots. A full pool returns immediately,
; retaining the original modifier and any already-created fighters.
.a8
.i16
ENEMY_POOL = $5000
WAVE_MODIFIER = $1180
WAVE_GROUP = $1181
WAVE_COUNTS = $1188

wave_spawn:
  lda WAVE_GROUP
  cmp #7
  bne :+
  jmp wave_circle
:
  lda WAVE_MODIFIER
  beq @ordinary
  rep #$20
  lda WAVE_GROUP
  and #255
  tax
  sep #$20
  stz WAVE_COUNTS,x
@ordinary:
  rep #$20
  lda WAVE_GROUP
  and #255
  dec
  asl
  sta $d0
  asl
  clc
  adc $d0
  sta $d0
  lda #3
  sta $d2
  ldx #0
@find:
  sep #$20
  lda ENEMY_POOL+8,x
  beq @found
  rep #$20
  txa
  clc
  adc #32
  tax
  cpx #512
  bne @find
  sep #$20
  rts
@found:
.a8
  rep #$20
  stx $d4
  ldy #0
@copy:
  lda wave_template,y
  sta ENEMY_POOL,x
  inx
  inx
  iny
  iny
  cpy #32
  bne @copy
  ldx $d4
  ldy $d0
  sep #$20
  lda wave_positions,y
  sta ENEMY_POOL+2,x
  lda wave_positions+1,y
  sta ENEMY_POOL+4,x
  lda WAVE_GROUP
  sta ENEMY_POOL+7,x
  lda WAVE_MODIFIER
  beq @next
  sta ENEMY_POOL+$15,x
  rep #$20
  lda #$8b78
  sta ENEMY_POOL+$1e,x
  lda WAVE_GROUP
  and #255
  tay
  sep #$20
  lda WAVE_COUNTS,y
  inc
  sta WAVE_COUNTS,y
@next:
  rep #$20
  inc $d0
  inc $d0
  dec $d2
  bne @find
  sep #$20
  stz WAVE_MODIFIER
  rts

wave_circle:
  stz WAVE_COUNTS+7
  rep #$20
  stz $d0
  lda #8
  sta $d2
  ldx #0
@find:
  sep #$20
  lda ENEMY_POOL+8,x
  beq @found
  rep #$20
  txa
  clc
  adc #32
  tax
  cpx #512
  bne @find
  bra @done
@found:
.a8
  rep #$20
  stx $d4
  ldy #0
@copy:
  lda wave_circle_template,y
  sta ENEMY_POOL,x
  inx
  inx
  iny
  iny
  cpy #32
  bne @copy
  ldx $d4
  sep #$20
  lda $d0
  sta ENEMY_POOL+4,x
  clc
  adc #16
  sta $d0
  lda WAVE_MODIFIER
  sta ENEMY_POOL+$15,x
  inc WAVE_COUNTS+7
  rep #$20
  dec $d2
  bne @find
@done:
  sep #$20
  stz WAVE_MODIFIER
  rts
