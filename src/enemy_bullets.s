; Original US aimed bullet creation ($38B2-$38FF), followed by caller XY.
.a8
.i16
.ifndef ENEMY
ENEMY = $1100
.endif
BULLETS = $5200
BULLET_SCRATCH = $1d40
BULLET_CONTEXT = $11c0

enemy_bullet_spawn:
  ldx #BULLET_SCRATCH
  lda ENEMY+1
  and #16
  bne @position
  lda BULLET_CONTEXT+1
  bne @position
  rep #$20
  lda BULLET_CONTEXT+2
  and #255
  beq @no_slots
  asl
  asl
  asl
  asl
  asl
  clc
  adc #BULLETS
  sta $d0
  ldx #BULLETS
@slot:
  sep #$20
  lda a:$0008,x
  beq @found
  rep #$20
  txa
  clc
  adc #32
  tax
  cpx $d0
  bne @slot
@no_slots:
  ldx #BULLET_SCRATCH
  sep #$20
  bra @position
@found:
.a8
  rep #$20
  stx $d2
  ldy #0
@copy:
  lda bullet_template,y
  sta a:$0000,x
  inx
  inx
  iny
  iny
  cpy #32
  bne @copy
  lda BULLET_CONTEXT+3
  and #255
  asl
  asl
  asl
  asl
  asl
  sta $d0
  lda BULLET_CONTEXT
  and #255
  clc
  adc $d0
  asl
  tay
  lda bullet_pointers,y
  ldx $d2
  sta a:$001e,x
  sep #$20
@position:
  lda ENEMY+2
  sta a:$0002,x
  lda ENEMY+3
  sta a:$0003,x
  rts
