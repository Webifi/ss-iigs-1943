; The four-piece ground batteries (large objects; D = the head, large_ai):
; the land quads and the triple battery, and their heavy bullets.
.a16
.i16
LQ_RANDOM = 0                ; TURRET_KIND: fires 1 time in 2 when aligned
LQ_PREDICT = 1               ; TURRET_KIND: aims ahead of the player's stick
LQ_DOUBLE = 2                ; TURRET_KIND: two ground bullets
LQ_FIRE_DELAY = 10           ; TURRET_DELAY after a shot
DOUBLE_FIRE_DELAY = 11
TRIPLE_FIRE_DELAY = 5
HEAVY_MIN_ALONG = 40         ; game_heavy_bullet: no bullet above this along

; game_land_quad: the barrel turns BARREL_STEP toward the player (LQ_PREDICT
; first moves the aim 2 toward the player's stick direction); aligned and
; the delay over, it fires by its kind. The turrets of a destroyed ship die.
game_land_quad:
  lda LARGE_CALLBACK
  ldx #LQ_RANDOM
  cmp #TAIL_LAND_QUAD
  beq @kind
  ldx #LQ_PREDICT
  cmp #TAIL_LAND_QUAD_2
  beq @kind
  ldx #LQ_DOUBLE
@kind:
  stx TURRET_KIND
  a8
  lda STAGE_TURRETS_FALL
  beq @alive
  jmp .loword(game_ground_destroy)
@alive:
  lda TURRET_DELAY
  beq :+
  dec TURRET_DELAY
:
  jsl ai_target_far
  lda TURRET_KIND
  cmp #LQ_PREDICT
  bne @turn
  lda PLAYER+PL_NUMBER,y
  beq @p1
  lda TURRET_INPUT+1
  bra @input
@p1:
  lda TURRET_INPUT
@input:
  eor #$ff                      ; pressed = 1
  and #INPUT_STICK
  a16
  and #255
  tax
  a8
  lda f:turret_input_angles,x
  cmp #NO_ANGLE
  beq @turn
  sec
  sbc OBJ_AIM
  and #DIRECTIONS-1
  beq @turn
  cmp #DIRECTIONS/2
  beq @turn
  bcc @plus
  lda OBJ_AIM
  sec
  sbc #2
  bra @predicted
@plus:
  lda OBJ_AIM
  clc
  adc #2
@predicted:
  and #DIRECTIONS-1
  sta OBJ_AIM
@turn:
  lda OBJ_AIM
  sec
  sbc TURRET_BARREL
  and #DIRECTIONS-1
  beq @aligned
  cmp #1
  beq @aligned
  cmp #DIRECTIONS-1
  beq @aligned
  cmp #DIRECTIONS/2
  bcc @increase
  lda TURRET_BARREL
  sec
  sbc #BARREL_STEP
  bra @angle
@increase:
  lda TURRET_BARREL
  clc
  adc #BARREL_STEP
@angle:
  and #DIRECTIONS-1
  sta TURRET_BARREL
  jmp .loword(@select)
@aligned:
  lda TURRET_DELAY
  bne @select
  lda TURRET_KIND
  cmp #LQ_DOUBLE
  beq @double
  cmp #LQ_PREDICT
  beq @fire
  lda RANDOM_STATE+5            ; random stream 5, step $77: 1 in 2
  pha
  clc
  adc #$77
  sta RANDOM_STATE+5
  pla
  lsr
  bcc @select
@fire:
  ; One turret bullet from the muzzle of the barrel (turret_muzzles).
  lda #LQ_FIRE_DELAY
  sta TURRET_DELAY
  lda TURRET_KIND
  inc
  sta TURRET_FIRE
  lda TURRET_BARREL
  sta TURRET_ANGLE
  a16
  and #DIRECTIONS-1
  tax
  a8
  lda f:turret_muzzles,x
  clc
  adc SPR_CROSS
  sta LARGE_AI_X
  lda f:turret_muzzles+1,x
  clc
  adc SPR_ALONG
  sta LARGE_AI_Y
  bra @select
@double:
  ; Two ground bullets from the two muzzles, at a random speed
  ; (game_double_speeds, random stream 0, step $77).
  lda #DOUBLE_FIRE_DELAY
  sta TURRET_DELAY
  lda TURRET_BARREL
  asl
  sta TURRET_SHOT
  lda RANDOM_STATE
  pha
  clc
  adc #$77
  sta RANDOM_STATE
  pla
  and #7
  a16
  and #255
  tax
  a8
  lda f:game_double_speeds,x
  sta GROUND_SPEED
  jsr .loword(game_double_shot)
  inc TURRET_SHOT
  inc TURRET_SHOT
  jsr .loword(game_double_shot)
@select:
  ; The game_land_quad_paths path of the kind and the barrel.
  a16
  lda TURRET_KIND
  asl
  asl
  asl
  asl
  asl                           ; times DIRECTIONS
  sta a:TURRET_PATH_OFFSET
  lda TURRET_BARREL
  and #DIRECTIONS-1
  clc
  adc a:TURRET_PATH_OFFSET
  tax
  lda f:game_land_quad_paths,x
  jmp .loword(large_ai_selected)

; game_ground_destroy: the turret dies and scores for STAGE_CORE_OWNER.
game_ground_destroy:
.a8
  lda STAGE_CORE_OWNER
  sta OBJ_OWNER
  lda #LA_KILL
  sta LARGE_AI_ACTION
  a16
  lda #0                        ; no next path
  jmp .loword(large_ai_selected)
; game_double_speeds: the straight decisions (GROUND_SPEED) of a double shot.
game_double_speeds:
  .byte 18,14,18,10,10,18,18,14
; game_double_shot: a ground bullet from the muzzle TURRET_SHOT
; (game_double_muzzles: two muzzles of two bytes for each even barrel). JSR.
game_double_shot:
.a8
  lda TURRET_BARREL
  sta GROUND_ANGLE
  a16
  lda TURRET_SHOT
  and #DIRECTIONS*2-1
  tax
  a8
  lda f:game_double_muzzles,x
  clc
  adc SPR_CROSS
  sta LARGE_AI_X
  lda f:game_double_muzzles+1,x
  clc
  adc SPR_ALONG
  sta LARGE_AI_Y
  phd
  pea .loword(ZERO_PAGE)
  pld
  jsl game_ground_shot_far
  pld
  rts

; game_triple_quad: the triple battery: the barrel (0-2) turns one step to
; the player's angle (below 15, below 18, else); aligned, three heavy
; bullets from the three muzzles (right to left, angles low to high).
game_triple_quad:
.a16
  a8
  lda TURRET_DELAY
  beq :+
  dec TURRET_DELAY
:
  lda STAGE_TURRETS_FALL
  beq :+
  jmp .loword(game_ground_destroy)
:
  jsl ai_target_far
  ldx #0
  cmp #15
  bcc @target
  inx
  cmp #18
  bcc @target
  inx
@target:
  stx a:TRIPLE_TARGET
  lda TURRET_BARREL
  cmp a:TRIPLE_TARGET
  beq @aligned
  bcc @increase
  dec TURRET_BARREL
  bra @select
@increase:
  inc TURRET_BARREL
  bra @select
@aligned:
  lda TURRET_DELAY
  bne @select
  lda #TRIPLE_FIRE_DELAY
  sta TURRET_DELAY
  lda #2                        ; shots 2, 1, 0
  sta TURRET_SHOT
@shot:
  ; game_triple_muzzles: three muzzles of two bytes for each barrel.
  a16
  lda TURRET_BARREL
  and #255
  sta a:TRIPLE_MUZZLE_OFFSET
  asl
  clc
  adc a:TRIPLE_MUZZLE_OFFSET
  asl
  sta a:TRIPLE_MUZZLE_OFFSET
  lda TURRET_SHOT
  and #255
  asl
  adc a:TRIPLE_MUZZLE_OFFSET
  tax
  a8
  lda f:game_triple_muzzles,x
  clc
  adc SPR_CROSS
  sta LARGE_AI_X
  lda f:game_triple_muzzles+1,x
  clc
  adc SPR_ALONG
  sta LARGE_AI_Y
  lda TURRET_BARREL
  clc
  adc #6
  sec
  sbc TURRET_SHOT
  sta TURRET_ANGLE
  jsr .loword(game_heavy_bullet)
  dec TURRET_SHOT
  bpl @shot
@select:
  a16
  lda TURRET_BARREL
  and #255
  asl
  tax
  lda f:game_triple_quad_paths,x
  jmp .loword(large_ai_selected)

; game_heavy_bullet: a heavy bullet (game_heavy_bullet_template) on the
; path of TURRET_ANGLE from LARGE_AI_X, LARGE_AI_Y in a free slot among the
; first BULLET_SLOTS, when the battery is on the field. JSR.
game_heavy_bullet:
.a8
  lda SPR_ATTR
  ora 2*SPRITE_SIZE+SPR_ATTR
  and #SPR_ALONG_HIGH
  bne @done
  lda SPR_ALONG
  cmp #HEAVY_MIN_ALONG
  bcc @done
  lda BULLET_SUPPRESS
  bne @done
  lda BULLET_SLOTS
  beq @done
  a16
  and #255
  asl
  asl
  asl
  asl
  asl                           ; times OBJECT_SIZE
  clc
  adc #BULLETS
  sta a:BULLET_SEARCH_END
  ldx #BULLETS
@slot:
  a8
  lda a:OBJ_TYPE,x
  beq @found
  a16
  txa
  clc
  adc #OBJECT_SIZE
  tax
  cpx a:BULLET_SEARCH_END
  bne @slot
  a8
@done:
  rts
@found:
  a16
  .repeat OBJECT_SIZE/2,I
    lda f:game_heavy_bullet_template+I*2
    sta a:I*2,x
  .endrepeat
  phx
  lda TURRET_ANGLE
  and #255
  asl
  tax
  lda f:game_heavy_bullet_paths,x
  plx
  sta a:OBJ_MOTION,x
  a8
  lda LARGE_AI_X
  sta a:SPR_CROSS,x
  lda LARGE_AI_Y
  sta a:SPR_ALONG,x
  lda #SND_TURRET_SHOT
  jsl game_sound_request        ; arcade $3FF3
  rts
.assert DIRECTIONS = 32 .and OBJECT_SIZE = 32, error ; the ASLs above
