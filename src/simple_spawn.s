; Template-only original-US stage spawns. Selection and copies are build data.
; Full pool returns immediately, including after a partial multi-spawn.
.a8
.i16
SIMPLE_PLAN = $1db0
SIMPLE_SLOT = $1db2
SIMPLE_LIMIT = $1db4
SIMPLE_LEFT = $1db6
SIMPLE_TEMPLATE = $1dba
SIMPLE_PATCHES = $1dbc
SIMPLE_DEST = $1dbe
SIMPLE_GROUP = $1dc0
simple_spawn:
  lda STAGE_CONTROL_INDEX
  cmp #160
  bcs :+
  clc
  rtl
:
  cmp #160+SIMPLE_SPAWN_COUNT
  bcc :+
  clc
  rtl
:
  sec
  sbc #160
  rep #$20
  and #255
  asl
  tax
  lda f:simple_spawn_plans,x
  sta SIMPLE_PLAN
  tax
  sep #$20
  lda f:$010000,x
  sta SIMPLE_LEFT
  lda STAGE_BANK
  cmp #24
  bne :+
  rep #$20
  lda STAGE_CALLBACK
  cmp #$9972
  sep #$20
  bne :+
  stz WAVE_COUNTS+6
:

  rep #$20
  lda STAGE_CALLBACK
  cmp #$722f
  bne @conditions
  sep #$20
  lda RANDOM_STATE+6          ; arcade $722F reads and updates $E00E
  pha
  clc
  adc #$99
  sta RANDOM_STATE+6
  pla
  and #15
  beq @accepted
  sec
  rtl
@conditions:
.a16
  cmp #$737d
  beq @pair_only
  lda STAGE_BANK
  and #255
  cmp #24
  bne @accepted16
  lda STAGE_CALLBACK
  cmp #$ad7e
  beq @pair_only
  cmp #$9d8a
  beq @pair_only
  cmp #$a377
  bne @accepted16
@pair_only:
  sep #$20
  lda PLAYER+8
  beq @skip_pair
  lda PLAYER+$88
  bne @accepted
@skip_pair:
  stz WAVE_MODIFIER
  sec
  rtl
@accepted16:
  sep #$20
@accepted:
  lda STAGE_BANK
  cmp #16
  bne :+
  rep #$20
  lda STAGE_CALLBACK
  cmp #$8130
  beq @air_pieces
  cmp #$814f
  beq @air_pieces
  cmp #$817c
  sep #$20
  bne :+
@air_pieces:
  sep #$20
  lda #16
  sta AIR_LIFE
:
  ; Template group bytes identify counted formations at build time.
  ldx SIMPLE_PLAN
  rep #$20
  lda f:$010002,x
  tax
  sep #$20
  lda f:$010007,x
  sta SIMPLE_GROUP
  beq @not_wave
  rep #$20
  and #255
  tax
  sep #$20
  stz WAVE_COUNTS,x
@not_wave:
  rep #$20
  inc SIMPLE_PLAN
  sep #$20
@next:
  ldx SIMPLE_PLAN
  lda f:$010000,x
  bne @limit
  lda STAGE_DIFFICULTY+6
  beq @done
@limit:
  rep #$20
  and #255
  asl
  asl
  asl
  asl
  asl
  sta SIMPLE_LIMIT
  ldx #0
@scan:
  sep #$20
  lda ENEMY_POOL+8,x
  beq @found
  rep #$20
  txa
  clc
  adc #32
  tax
  cpx SIMPLE_LIMIT
  bcc @scan
@done:
  sep #$20
  sec
  rtl
@unknown:
  clc
  rtl
@found:
  rep #$20
  stx SIMPLE_DEST
  txy
  ldx SIMPLE_PLAN
  lda f:$010001,x
  sta SIMPLE_TEMPLATE
  sep #$20
  lda f:$010003,x
  sta SIMPLE_PATCHES
  rep #$20
  txa
  clc
  adc #4
  sta SIMPLE_PLAN
  ldx SIMPLE_TEMPLATE
  .repeat 16
    lda f:$010000,x
    sta ENEMY_POOL,y
    inx
    inx
    iny
    iny
  .endrepeat
  sep #$20
  lda SIMPLE_PATCHES
  beq @patched
@patch:
  ldx SIMPLE_PLAN
  rep #$20
  lda f:$010000,x
  and #255
  clc
  adc SIMPLE_DEST
  tay
  sep #$20
  lda f:$010001,x
  sta ENEMY_POOL,y
  rep #$20
  inc SIMPLE_PLAN
  inc SIMPLE_PLAN
  sep #$20
  dec SIMPLE_PATCHES
  bne @patch
@patched:
  ldx SIMPLE_DEST
  lda ENEMY_POOL+7,x
  beq @counted
  lda WAVE_MODIFIER
  sta ENEMY_POOL+$15,x
  lda ENEMY_POOL+7,x
  rep #$20
  and #255
  tax
  sep #$20
  inc WAVE_COUNTS,x
@counted:
  dec SIMPLE_LEFT
  bne :+
  lda SIMPLE_GROUP
  beq @return
  stz WAVE_MODIFIER
@return:
  sec
  rtl
:
  jmp .loword(@next)
