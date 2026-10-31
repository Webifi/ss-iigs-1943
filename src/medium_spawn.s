; Build-selected native spawn index. This copies a template only at spawn.
.a8
.i16
medium_spawn:
  lda STAGE_CONTROL_INDEX
  cmp #128
  bcs :+
  clc
  rtl
:
  cmp #140
  bcc :+
  clc
  rtl
:
  rep #$20
  and #127
  tax
  sep #$20
  lda f:medium_spawn_x,x
  sta $d0
  lda f:medium_spawn_template,x
  sta $d2
  stz $d3
  lda STAGE_DIFFICULTY+6
  bne :+
  sec
  rtl
:
  rep #$20
  and #255
  asl
  asl
  asl
  asl
  asl
  sta $d4
  ldx #0
@slot:
  sep #$20
  lda ENEMY_POOL+8,x
  beq @found
  rep #$20
  txa
  clc
  adc #32
  tax
  cpx $d4
  bne @slot
  sep #$20
  sec
  rtl
@found:
  rep #$20
  txy
  ldx $d2
  .repeat 16
    lda f:medium_spawn_templates,x
    sta ENEMY_POOL,y
    inx
    inx
    iny
    iny
  .endrepeat
  tya
  sec
  sbc #32
  tax
  sep #$20
  lda $d0
  sta ENEMY_POOL+2,x
  sec
  rtl
