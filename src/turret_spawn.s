; Original bank-six four-piece spawns, shared group helper $30B8-$3116.
.a8
.i16
TURRET_SPAWN_ID = $1c96
TURRET_GROUP = $1c98         ; original E560
TURRET_RETRY = $1c99         ; original E551
TURRET_DEST = $1c9a
TURRET_SPAWN_X = $1c9c
TURRET_TEMPLATE = $1c9e

turret_spawn:
  rep #$20
  lda TURRET_SPAWN_ID
  and #255
  tax
  sep #$20
  lda f:turret_spawn_x,x
  sta TURRET_SPAWN_X
  lda f:turret_spawn_kind,x
  rep #$20
  and #255
  asl
  asl
  asl
  asl
  asl
  sta TURRET_TEMPLATE
  sep #$20
  jsr .loword(large_allocate_turret)
  bcs :+
  rtl
:
  stx TURRET_DEST
  inc TURRET_GROUP
  rep #$20
  lda TURRET_GROUP
  and #255
  tay
  sep #$20
  lda TURRET_RETRY
  beq @copy
  lda LARGE_GROUPS,y
  bne @copy
  rtl
@copy:
  rep #$20
  txy
  ldx TURRET_TEMPLATE
  .repeat 16
    lda f:turret_spawn_templates,x
    sta LARGE_POOL,y
    inx
    inx
    iny
    iny
  .endrepeat
  lda TURRET_GROUP
  and #255
  tay
  ldx TURRET_DEST
  sep #$20
  sta LARGE_POOL+$0f,x
  lda LARGE_POOL+$0b,x
  sta LARGE_GROUPS,y
  clc
  adc LARGE_THRESHOLD
  sta LARGE_THRESHOLD
  lda LARGE_POOL+1,x
  sta LARGE_POOL+$41,x
  lda LARGE_POOL+3,x
  sec
  sbc #16
  sta LARGE_POOL+$43,x
  lda TURRET_SPAWN_X
  sec
  sbc CAMERA+$0e
  sta LARGE_POOL+2,x
  rtl
