; Bank-zero player and enemy outcomes: the body contacts of a small object
; with both players, the death, retirement and score of a small object, and
; the score add. The routines work on the records in place.
.a8
.i16

; player_energy_hud_far: JSL entry of energy_hud_update (src/bullet_contact.s).
player_energy_hud_far:
  jsr energy_hud_update
  rtl

; flight_body_contacts: the small object in WAVE_SLOT touches P1, else P2;
; then act on the result: the sound, the score, the death or the retirement
; of the object (wave_combat_tick, D = 0).
flight_body_contacts:
  ldx WAVE_SLOT
  lda ENEMY_POOL+OBJ_FLAGS,x
  and #OF_CONTACT
  beq @done
  ldx #0
  jsl player_body_contact
  lda CONTACT_ACTION
  bne @action
  ldx #PLAYER_SIZE
  jsl player_body_contact
  lda CONTACT_ACTION
  beq @done
@action:
  pha
  lda CONTACT_SOUND              ; arcade $5793 and $57F5-$5911
  beq @effects_done
  jsl game_sound_request
@effects_done:
  pla
  pha
  and #CONTACT_SCORE
  beq @retire
  jsr flight_enemy_award
@retire:
  pla
  ldx WAVE_SLOT
  lsr                           ; carry = CONTACT_KILL
  bcc @test_retire
  jsr flight_enemy_killed
  rts
@test_retire:
  lsr                           ; carry = CONTACT_RETIRE
  bcc @done
  jsr flight_enemy_retire
@done:
  rts
.assert CONTACT_KILL = 1 .and CONTACT_RETIRE = 2, error

; flight_enemy_killed: the small object in WAVE_SLOT dies (arcade $594E-$5996):
; only its camera flag stays, it runs its death script (OBJ_PREDECESSOR), its
; wave counter goes down (the last plane of a wave frees the wave's drop),
; a boss part adds its ledger value to LARGE_TOTAL, and the owner scores.
flight_enemy_killed:
  ldx WAVE_SLOT
  lda ENEMY_POOL+OBJ_FLAGS,x
  and #OF_CAMERA
  sta ENEMY_POOL+OBJ_FLAGS,x
  stz ENEMY_POOL+OBJ_DURATION,x
  a16
  lda ENEMY_POOL+OBJ_PREDECESSOR,x
  sta ENEMY_POOL+OBJ_MOTION,x
  lda ENEMY_POOL+OBJ_WAVE_COUNTER,x
  and #255
  tay
  a8
  beq @last                     ; no wave counter
  lda WAVE_COUNTS,y
  dec
  sta WAVE_COUNTS,y
  bne @award
@last:
  lda ENEMY_POOL+OBJ_DROP,x     ; the drop may come now
  and #<~DROP_WAIT
  sta ENEMY_POOL+OBJ_DROP,x
@award:
  a16
  lda ENEMY_POOL+OBJ_LEDGER,x
  and #255
  tay
  a8
  beq :+
  lda LARGE_TOTAL
  clc
  adc LARGE_GROUPS,y
  sta LARGE_TOTAL
  lda #0
  sta LARGE_GROUPS,y
:
  jmp flight_enemy_award

; flight_enemy_award: OBJ_OWNER of the object in WAVE_SLOT gets its score.
flight_enemy_award:
  ldx WAVE_SLOT
  lda ENEMY_POOL+OBJ_OWNER,x
  beq @done
  sta SCORE_OWNER
  lda ENEMY_POOL+OBJ_SCORE,x
  sta SCORE_AWARD_INDEX
  jmp score_add_owned
@done:
  rts

; flight_enemy_retire: the object in WAVE_SLOT leaves without a death (a
; collected pickup). flight_enemy_retired: the rest of the retirement for an
; object that has gone already: the boss ledger gets its HP, and its drop
; (OBJ_DROP 1-8, without DROP_WAIT) appears where it was.
flight_enemy_retire:
  ldx WAVE_SLOT
  lda ENEMY_POOL+SPR_CROSS,x
  sta ENEMY_RETIRE_X
  stz ENEMY_POOL+SPR_CODE,x
  stz ENEMY_POOL+OBJ_TYPE,x
  stz ENEMY_POOL+SPR_CROSS,x
flight_enemy_retired:
  ldx WAVE_SLOT
  a16
  lda ENEMY_POOL+OBJ_LEDGER,x
  and #255
  tay
  a8
  beq :+
  lda LARGE_GROUPS,y
  beq :+
  sec
  sbc ENEMY_POOL+OBJ_HP,x
  clc
  adc LARGE_TOTAL
  sta LARGE_TOTAL
:
  lda ENEMY_POOL+OBJ_DROP,x
  beq @done
  and #DROP_WAIT                ; not the last plane yet: no drop
  bne @done
  lda ENEMY_POOL+OBJ_DROP,x
  sta PICKUP_KIND
  lda ENEMY_RETIRE_X
  sta PICKUP_X
  lda ENEMY_POOL+SPR_ALONG,x
  sta PICKUP_Y
  jsl pickup_spawn
@done:
  rts

; score_add_owned: add the score_awards value that ends at SCORE_AWARD_INDEX
; to the score of player SCORE_OWNER (1 or 2). Both are SCORE_DIGITS
; unpacked decimal digits, the most significant first; the add starts at the
; last digit. A, X, Y: changed.
score_add_owned:
  ldy #SCORE_DIGITS-1           ; the last digit of P1
  lda SCORE_OWNER
  cmp #2
  bne :+
  ldy #PLAYER_SIZE+SCORE_DIGITS-1       ; the last digit of P2
:
  a16
  lda SCORE_AWARD_INDEX
  and #255
  tax
  a8
  stz SCORE_CARRY
  lda #SCORE_DIGITS
  sta SCORE_ADD_LEFT
@digit:
  lda score_awards,x
  clc
  adc SCORE_CARRY
  clc
  adc PLAYER+PL_SCORE,y
  stz SCORE_CARRY
  cmp #10                       ; a decimal digit
  bcc @store
  sec
  sbc #10
  inc SCORE_CARRY
@store:
  sta PLAYER+PL_SCORE,y
  dex
  dey
  dec SCORE_ADD_LEFT
  bne @digit
  rts

; gameplay_reset_far: clear the pools, the stage controls, the large objects
; and the shots for a new scene (cabinet flow). JSL.
gameplay_reset_far:
  jsr wave_combat_init
  jsl stage_flow_init
  jsl large_loop_init
  a16
  ldx #SHOT_COUNT*SHOT_SIZE-2
@shots:
  stz SHOTS,x
  dex
  dex
  bpl @shots
  a8
  rtl

; special_enemy_kill_far: JSL entry of flight_enemy_killed for the special
; attack (src/special_loop.s).
special_enemy_kill_far:
  jsr flight_enemy_killed
  rtl
