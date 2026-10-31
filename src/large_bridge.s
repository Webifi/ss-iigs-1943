; Bank-zero bridge into the existing native score implementation.
.a8
.i16
large_score_far:
  jsr score_add_owned
  rtl

.ifdef SHIP_ENEMIES
large_bullet_far:
  rep #$20
  lda LARGE_RECORD
  sta POOL_RECORD
  tax
  sep #$20
  lda a:$16,x
  sta BULLET_CONTEXT
  jsr enemy_bullet_spawn_direct
  lda LARGE_AI_X
  sta a:2,x
  lda LARGE_AI_Y
  sta a:3,x
  cpx #BULLET_SCRATCH
  beq :+
  inc BULLET_SPAWNS
:
  rtl
.endif

.ifdef CONTINUOUS_GAME
game_large_spread_far:
  rep #$20
  lda LARGE_RECORD
  sta POOL_RECORD
  sep #$20
  lda MEDIUM_SHOT_ANGLE
  sta BULLET_CONTEXT
  jsr enemy_bullet_spawn_direct
  lda LARGE_AI_X
  sta a:2,x
  lda LARGE_AI_Y
  sta a:3,x
  cpx #BULLET_SCRATCH
  beq :+
  inc BULLET_SPAWNS
:
  rtl
.endif
