; Bank-zero bridges only. Controllers run directly on player/enemy records.
.a8
.i16
player_energy_hud_far:
  jsr energy_hud_update
  rtl

flight_body_contacts:
  lda CONTACT_ACTION
  pha                         ; preserve outer caller state, if nested later
  ldx WAVE_SLOT
  lda ENEMY_POOL+9,x
  and #1
  beq @done
  ldx #0
  jsl player_body_contact
  lda CONTACT_ACTION
  bne @action
  ldx #128
  jsl player_body_contact
  lda CONTACT_ACTION
  beq @done
@action:
  pha
  lda CONTACT_SOUND
  beq @effects_done
  cmp #5
  bne :+
  inc CONTACT_DEATH_REQUESTS
  jsr doc_play_player_death
  bra @effects_done
:
  ; All requested effects use the unified dispatcher. Unsupported commands
  ; remain recorded until their original sample/score has been installed.
  sta PLAYER_EVENT_SOUND
@effects_done:
  pla
  pha
  and #4
  beq @retire
  jsr flight_enemy_award
@retire:
  pla
  ldx WAVE_SLOT
  lsr
  bcc @test_retire
  jsr flight_enemy_killed
  bra @done
@test_retire:
  lsr
  bcc @done
  jsr flight_enemy_retire
@done:
  pla
  sta CONTACT_ACTION
  rts

; Common original-US $594E-$5996. Group completion enables the final drop.
flight_enemy_killed:
  inc COMBAT_KILLS
  ldx WAVE_SLOT
  lda ENEMY_POOL+9,x
  and #4
  sta ENEMY_POOL+9,x
  stz ENEMY_POOL+4,x
  rep #$20
  lda ENEMY_POOL+$1c,x
  sta ENEMY_POOL+$1e,x
  lda ENEMY_POOL+7,x
  and #255
  tay
  sep #$20
  beq @last
  lda WAVE_COUNTS,y
  dec
  sta WAVE_COUNTS,y
  bne @award
@last:
  lda ENEMY_POOL+$15,x
  and #15
  sta ENEMY_POOL+$15,x
@award:
 .ifdef EXTENDED_STAGE_ENEMIES
  rep #$20
  lda ENEMY_POOL+$0f,x
  and #255
  tay
  sep #$20
  beq :+
  lda LARGE_TOTAL
  clc
  adc LARGE_GROUPS,y
  sta LARGE_TOTAL
  lda #0
  sta LARGE_GROUPS,y
:
 .endif
  jmp flight_enemy_award

flight_enemy_award:
  ldx WAVE_SLOT
  lda ENEMY_POOL+$0e,x
  beq @done
  sta SCORE_OWNER
  lda ENEMY_POOL+$17,x
  sta SCORE_AWARD_INDEX
  jmp score_add_owned
@done:
  rts

flight_enemy_retire:
  ldx WAVE_SLOT
  lda ENEMY_POOL+2,x
  sta ENEMY_RETIRE_X
  stz ENEMY_POOL,x
  stz ENEMY_POOL+8,x
  stz ENEMY_POOL+2,x
  inc COMBAT_RETIRED
flight_enemy_retired:
  ldx WAVE_SLOT
 .ifdef EXTENDED_STAGE_ENEMIES
  rep #$20
  lda ENEMY_POOL+$0f,x
  and #255
  tay
  sep #$20
  beq :+
  lda LARGE_GROUPS,y
  beq :+
  sec
  sbc ENEMY_POOL+$0b,x
  clc
  adc LARGE_TOTAL
  sta LARGE_TOTAL
:
 .endif
  lda ENEMY_POOL+$15,x
  beq @done
  and #$f0
  bne @done
  lda ENEMY_POOL+$15,x
  sta PICKUP_KIND
  lda ENEMY_RETIRE_X
  sta PICKUP_X
  lda ENEMY_POOL+3,x
  sta PICKUP_Y
  jsl pickup_spawn
@done:
  rts

SCORE_OWNER = $17d2
score_add_owned:
  ldy #7
  lda SCORE_OWNER
  cmp #2
  bne :+
  ldy #135
:
  rep #$20
  lda SCORE_AWARD_INDEX
  and #255
  tax
  sep #$20
  stz $d0
  lda #8
  sta $d2
@digit:
  lda score_awards,x
  clc
  adc $d0
  clc
  adc PLAYER+$38,y
  stz $d0
  cmp #10
  bcc @store
  sec
  sbc #10
  inc $d0
@store:
  sta PLAYER+$38,y
  dex
  dey
  dec $d2
  bne @digit
  rts

.ifdef CONTINUOUS_GAME
; Reset the native pools in their owning bank, then return to cabinet flow.
gameplay_reset_far:
  jsr wave_combat_init
  jsl stage_flow_init
  jsl large_loop_init
  rep #$20
  ldx #18*32-2
@shots:
  stz SHOTS,x
  dex
  dex
  bpl @shots
  sep #$20
  rtl
.endif

.ifdef CONTINUOUS_GAME
; The special-attack controller uses the same score/drop transition as shots.
special_enemy_kill_far:
  jsr flight_enemy_killed
  rtl
.endif
