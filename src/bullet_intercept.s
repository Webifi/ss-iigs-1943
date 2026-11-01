; bullet_intercept: a player shot stops the bullet D (US arcade
; $6079-$6132), before its player contact. A bullet with OF_SHOT is stopped
; by the shots of each live player; another bullet only by the shots of a
; player with the SHOT GUN. Returns carry 1 when a shot stopped it: the shot
; ends or goes on with its damage left, the bullet ends, INTERCEPT_SOUND. JSR.
.a8
.i16

bullet_intercept:
  stz INTERCEPT_SOUND
  ldx #0
  ldy #SHOTS_PER_PLAYER*SHOT_SIZE
  lda PLAYER+PL_STATE
  cmp #PS_LIVE
  beq @p1
  lda PLAYER2+PL_STATE
  cmp #PS_LIVE
  beq :+
  clc
  rts
:
  ldx #SHOTS_PER_PLAYER*SHOT_SIZE
  ldy #SHOT_COUNT*SHOT_SIZE
  bra @eligible
@p1:
  lda PLAYER2+PL_STATE
  cmp #PS_LIVE
  bne @eligible
  ldy #SHOT_COUNT*SHOT_SIZE
@eligible:
  lda z:OBJ_FLAGS
  and #OF_SHOT
  bne @start
  lda PLAYER+PL_WEAPON
  and #WEAPON_SHOTGUN
  beq @p2_weapon
  ldx #0
  ldy #SHOTS_PER_PLAYER*SHOT_SIZE
  lda PLAYER2+PL_WEAPON
  and #WEAPON_SHOTGUN
  beq @start
  ldy #SHOT_COUNT*SHOT_SIZE
  bra @start
@p2_weapon:
  lda PLAYER2+PL_WEAPON
  and #WEAPON_SHOTGUN
  beq @miss
  ldx #SHOTS_PER_PLAYER*SHOT_SIZE
  ldy #SHOT_COUNT*SHOT_SIZE
@start:
  sty a:SHOT_SCAN_END
@shot:
  ; A hit: the distances are within the sums of the radii.
  lda SHOTS+SHOT_STATE,x
  cmp #SHOT_FLYING
  bne @next
  lda SHOTS+SPR_ALONG,x
  sec
  sbc z:SPR_ALONG
  bcs :+
  eor #$ff
  inc
:
  sta a:SHOT_DISTANCE
  lda SHOTS+SHOT_ALONG_RADIUS,x
  clc
  adc z:OBJ_ALONG_RADIUS
  cmp a:SHOT_DISTANCE
  bcc @next
  lda SHOTS+SPR_CROSS,x
  sec
  sbc z:SPR_CROSS
  bcs :+
  eor #$ff
  inc
:
  sta a:SHOT_DISTANCE
  lda SHOTS+SHOT_CROSS_RADIUS,x
  clc
  adc z:OBJ_CROSS_RADIUS
  cmp a:SHOT_DISTANCE
  bcs @hit
@next:
  a16
  txa
  clc
  adc #SHOT_SIZE
  tax
  a8
  cpx a:SHOT_SCAN_END
  bne @shot
@miss:
  clc
  rts
@hit:
  lda z:OBJ_HP
  cmp SHOTS+SHOT_DAMAGE,x
  bcc @penetrates
  lda #SHOT_IMPACT
  sta SHOTS+SHOT_STATE,x
  bra @erase
@penetrates:
  ; The shot goes on with its damage less the old HP.
  sta a:SHOT_DISTANCE
  lda SHOTS+SHOT_DAMAGE,x
  sec
  sbc a:SHOT_DISTANCE
  sta SHOTS+SHOT_DAMAGE,x
@erase:
  stz z:OBJ_HP
  stz z:OBJ_FLAGS
  stz z:OBJ_DURATION
  a16
  lda z:OBJ_PREDECESSOR
  sta z:OBJ_MOTION
  a8
  lda #SND_BULLET_HIT
  sta INTERCEPT_SOUND
  sec
  rts
