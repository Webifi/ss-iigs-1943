; Bank-zero bridges for the large objects: the score add and the enemy
; bullets of src/player_live.s and src/enemy_bullets.s, called with JSL from
; the far large-object code.
.a8
.i16
; large_score_far: score_add_owned (SCORE_OWNER, SCORE_AWARD_INDEX).
large_score_far:
  jsr score_add_owned
  rtl

; large_bullet_far: an aimed bullet from the object at LARGE_RECORD, in its
; aim direction, at LARGE_AI_X, LARGE_AI_Y (LA_BULLET).
large_bullet_far:
  a16
  lda LARGE_RECORD
  sta POOL_RECORD
  tax
  a8
  lda a:OBJ_AIM,x
  sta BULLET_ANGLE
  jsr enemy_bullet_spawn_direct ; returns X = the new bullet record
  lda LARGE_AI_X
  sta a:SPR_CROSS,x
  lda LARGE_AI_Y
  sta a:SPR_ALONG,x
  rtl

; game_large_spread_far: a bullet in the direction MEDIUM_SHOT_ANGLE from the
; object at LARGE_RECORD, at LARGE_AI_X, LARGE_AI_Y (LA_SPREAD).
game_large_spread_far:
  a16
  lda LARGE_RECORD
  sta POOL_RECORD
  a8
  lda MEDIUM_SHOT_ANGLE
  sta BULLET_ANGLE
  jsr enemy_bullet_spawn_direct
  lda LARGE_AI_X
  sta a:SPR_CROSS,x
  lda LARGE_AI_Y
  sta a:SPR_ALONG,x
  rtl
