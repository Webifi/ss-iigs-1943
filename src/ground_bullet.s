; Original $3E4D allocation. The speed and angle were chosen by ground_ai.
.a8
.i16
ground_bullet_spawn:
  ldx #BULLET_SCRATCH
  lda ENEMY+1
  and #16
  beq :+
  jmp @position
:
  lda BULLET_CONTEXT+1
  beq :+
  jmp @position
:
  lda BULLET_CONTEXT+2
  bne :+
  jmp @position
:
  rep #$20
  and #255
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
  lda a:8,x
  beq @found
  rep #$20
  txa
  clc
  adc #32
  tax
  cpx $d0
  bne @slot
  ldx #BULLET_SCRATCH
  sep #$20
  jmp @position
@found:
  rep #$20
  .repeat 16,I
    lda f:ground_bullet_template+I*2
    sta a:I*2,x
  .endrepeat
  phx
  lda GROUND_ANGLE
  and #255
  tax
  lda f:ground_bullet_paths,x
  sec
  sbc #7
  plx
  sta a:$1e,x
  sep #$20
  lda GROUND_SPEED
  sta a:$10,x
  lda GROUND_ANGLE
  sta a:$11,x
@position:
  lda ENEMY+2
  sta a:2,x
  lda ENEMY+3
  sta a:3,x
  rts
