; The player shots against a small enemy (US arcade $5632-$56F6). The
; caller checked the update, the flags and the field. ENEMY_KILLED asks the
; caller for the death, the score and the drop.
.a8
.i16
PICKUP_NUDGE = 4             ; a shot pushes a pickup this far along
HP_ENDLESS = $ff             ; OBJ_HP of a pickup that shots do not end
; The shot bounds (shot_prepare_y_bounds) must not overlap the air boss state.
.assert SHOT_X_MAX < AIR_BOSS, error, "shot bounds overlap air-boss state"

; enemy_shot_collision: the first listed flying shot of a live player that
; touches the object D hits it: the shot ends (SHOT_IMPACT) or goes on with
; its damage left, the object loses HP; ENEMY_HIT_SOUND, ENEMY_KILLED. A
; pickup goes to enemy_pickup_shot. JSR.
enemy_shot_collision:
  stz ENEMY_KILLED
  stz ENEMY_HIT_SOUND
  ; The box of all shots can only let through more tests, never miss a hit.
  lda z:SPR_ALONG
  clc
  adc z:OBJ_ALONG_RADIUS
  bcs :+
  cmp SHOT_Y_MIN
  bcs :+
  rts
:
  lda z:SPR_ALONG
  sec
  sbc z:OBJ_ALONG_RADIUS
  bcc :+
  cmp SHOT_Y_MAX
  bcc :+
  beq :+
  rts
:
  ; A carry on an edge skips that test, as the byte wrap of the hit rules.
  lda z:SPR_CROSS
  clc
  adc z:OBJ_CROSS_RADIUS
  bcs :+
  cmp SHOT_X_MIN
  bcs :+
  rts
:
  lda z:SPR_CROSS
  sec
  sbc z:OBJ_CROSS_RADIUS
  bcc :+
  cmp SHOT_X_MAX
  bcc :+
  beq :+
  rts
:
  ; The shot list of the live players: player 1 from 0, player 2 from
  ; SHOT_ACTIVE_P2.
  ldx #0
  ldy #SHOTS_PER_PLAYER*SHOT_SIZE
  lda PLAYER+PL_STATE
  cmp #PS_LIVE
  beq @p1
  lda PLAYER2+PL_STATE
  cmp #PS_LIVE
  beq @p2
  rts
@p2:
  ldx #SHOTS_PER_PLAYER*SHOT_SIZE
  ldy #SHOT_COUNT*SHOT_SIZE
  bra @start
@p1:
  lda PLAYER2+PL_STATE
  cmp #PS_LIVE
  bne @start
  ldy #SHOT_COUNT*SHOT_SIZE
@start:
  cpy #SHOTS_PER_PLAYER*SHOT_SIZE
  bne :+
  ldy SHOT_ACTIVE_P2
  bra @list_end
:
  ldy SHOT_ACTIVE_END
@list_end:
  sty a:SHOT_SCAN_END
  cpx #0
  bne :+
  ldy #0
  bra @list_start
:
  ldy SHOT_ACTIVE_P2
@list_start:
  cpy a:SHOT_SCAN_END
  bne @slot
  rts
@slot:
  ; A hit: the distances are within the sums of the radii.
  ldx SHOT_ACTIVE,y
  lda SHOTS+SHOT_STATE,x
  cmp #SHOT_FLYING
  bne @next
  lda SHOTS+SPR_ALONG,x
  sec
  sbc z:SPR_ALONG
  bcs @y_abs
  eor #$ff
  inc
@y_abs:
  sta a:SHOT_DISTANCE
  lda SHOTS+SHOT_ALONG_RADIUS,x
  clc
  adc z:OBJ_ALONG_RADIUS
  cmp a:SHOT_DISTANCE
  bcc @next
  lda SHOTS+SPR_CROSS,x
  sec
  sbc z:SPR_CROSS
  bcs @x_abs
  eor #$ff
  inc
@x_abs:
  sta a:SHOT_DISTANCE
  lda SHOTS+SHOT_CROSS_RADIUS,x
  clc
  adc z:OBJ_CROSS_RADIUS
  cmp a:SHOT_DISTANCE
  bcc @next
  lda z:OBJ_VARIANT
  and #OBJ_PICKUP_BITS
  bne enemy_pickup_shot
  ; More HP than damage: the shot ends. Less: the shot goes on with the
  ; damage left. The same: both end.
  lda z:OBJ_HP
  cmp SHOTS+SHOT_DAMAGE,x
  bcc @penetrate
  beq @equal
  sec
  sbc SHOTS+SHOT_DAMAGE,x
  sta z:OBJ_HP
  lda #SHOT_IMPACT
  sta SHOTS+SHOT_STATE,x
  lda #SND_ENEMY_HIT
  sta ENEMY_HIT_SOUND
  rts
@equal:
  lda #SHOT_IMPACT
  sta SHOTS+SHOT_STATE,x
  bra @killed
@penetrate:
  lda SHOTS+SHOT_DAMAGE,x
  sec
  sbc z:OBJ_HP
  sta SHOTS+SHOT_DAMAGE,x
@killed:
  stz z:OBJ_HP
  lda #SND_ENEMY_KILL
  sta ENEMY_HIT_SOUND
  lda SHOTS+SHOT_OWNER,x
  inc
  sta z:OBJ_OWNER               ; the player number + 1
  lda #EK_KILLED
  sta ENEMY_KILLED
  rts
@next:
  iny
  iny
  cpy a:SHOT_SCAN_END
  beq @done
  jmp @slot
@done:
  rts

; enemy_pickup_shot: a shot hits a pickup (US arcade $5922-$594D): the shot
; ends, the pickup moves PICKUP_NUDGE along (past the field it goes:
; EK_RETIRE), and loses one HP; at 0 it ends (EK_KILLED); only PV_SCORE
; scores for the player.
enemy_pickup_shot:
  lda #SHOT_IMPACT
  sta SHOTS+SHOT_STATE,x
  lda z:SPR_ALONG
  clc
  adc #PICKUP_NUDGE
  bcs @retire
  sta z:SPR_ALONG
  lda z:OBJ_HP
  cmp #HP_ENDLESS
  beq @done
  dec z:OBJ_HP
  bne @done
  stz z:OBJ_OWNER
  lda z:OBJ_VARIANT
  and #OBJ_PICKUP_BITS
  cmp #PV_SCORE
  bne @killed
  lda SHOTS+SHOT_OWNER,x
  inc
  sta z:OBJ_OWNER
@killed:
  lda #EK_KILLED
  sta ENEMY_KILLED
@done:
  rts
@retire:
  lda #EK_RETIRE
  sta ENEMY_KILLED
  rts
