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
  ; The shots from X to Y in record order: player 1's records (X = 0), then
  ; player 2's (to Y = SHOT_COUNT * SHOT_SIZE). Y stays (bullet_loop).
  cpx #0
  bne @player2
  jsr .loword(intercept_player1)
  bcs @hit
  cpy #SHOT_COUNT*SHOT_SIZE
  bne @miss
@player2:
  jsr .loword(intercept_player2)
  bcs @hit
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

; intercept_player1, intercept_player2: the flying shots of one player, in
; record order, through intercept_shot. Carry set: the shot X hits. A test
; of a shot that does not fly costs one load and one compare. JSR; Y kept.
intercept_player1:
  .repeat SHOTS_PER_PLAYER,I
    lda SHOTS+I*SHOT_SIZE+SHOT_STATE
    cmp #SHOT_FLYING
    bne :+
    ldx #I*SHOT_SIZE
    jsr .loword(intercept_shot)
    bcc :+
    rts
:
  .endrepeat
  clc
  rts
intercept_player2:
  .repeat SHOTS_PER_PLAYER,I
    lda SHOTS+(SHOTS_PER_PLAYER+I)*SHOT_SIZE+SHOT_STATE
    cmp #SHOT_FLYING
    bne :+
    ldx #(SHOTS_PER_PLAYER+I)*SHOT_SIZE
    jsr .loword(intercept_shot)
    bcc :+
    rts
:
  .endrepeat
  clc
  rts
.assert SHOT_COUNT = 2*SHOTS_PER_PLAYER, error

; intercept_shot: carry set when the shot X lies within the sums of the
; radii of the bullet D, on both axes. JSR.
intercept_shot:
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
  bcc @miss                     ; carry clear
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
  cmp a:SHOT_DISTANCE           ; carry set: within
@miss:
  rts
