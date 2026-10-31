.include "profile.inc"
; Multiple native enemies use the original sixteen-slot fighter pool.
.a8
.i16
WAVE_SLOT = $11b4
WAVE_FIRE_REQUESTS = $11b6
COMBAT_HAS_SHOTS = $1139

wave_combat_init:
  jsr combat_init
  rep #$20
  ldx #510
@clear:
  stz ENEMY_POOL,x
  dex
  dex
  bpl @clear
 .ifdef EXTENDED_STAGE_ENEMIES
  ldx #17*32-2
@extended_clear:
  stz EXTENDED_POOL,x
  dex
  dex
  bpl @extended_clear
  stz STAGE_GROUP_INDEX
 .endif
  stz WAVE_SLOT
  stz WAVE_FIRE_REQUESTS
  stz STAGE_CALLBACK
  stz STAGE_BANK
  ldx #126
@second_player:
  stz PLAYER+$80,x
  dex
  dex
  bpl @second_player
  sep #$20
  stz WAVE_MODIFIER
  stz AI_CONTEXT
  stz AI_CONTEXT+1
.if FLIGHT_BULLETS
  jsr bullet_init
.if FLIGHT_CONTACT
  jsr contact_init
.if FLIGHT_DEATH
  jsr death_loop_init
.endif
.endif
.endif
  rts

wave_combat_tick:
.if !FLIGHT_BULLETS
  inc COMBAT_PHASE
.endif
  stz COMBAT_HAS_SHOTS
  lda COMBAT_PHASE
  and #1
  beq :+
  jmp @start_slots
:
.ifdef CONTINUOUS_GAME
  ldy #0
  ; Slot order is also first-hit order. Empty slots need no index arithmetic
  ; or accumulator-width changes. Keep the P2 boundary even when P1 is empty.
  .repeat 9,I
    lda SHOTS+I*32+8
    cmp #2
    bne :+
    rep #$20
    lda #I*32
    sta SHOT_ACTIVE,y
    iny
    iny
    sep #$20
:
  .endrepeat
  sty SHOT_ACTIVE_P2
  .repeat 9,I
    lda SHOTS+(I+9)*32+8
    cmp #2
    bne :+
    rep #$20
    lda #(I+9)*32
    sta SHOT_ACTIVE,y
    iny
    iny
    sep #$20
:
  .endrepeat
  sty SHOT_ACTIVE_END
  cpy #0
  beq @start_slots
  jsr shot_prepare_y_bounds
  inc COMBAT_HAS_SHOTS
.else
  ldx #18*32-32
@shot_present:
  lda SHOTS+8,x
  cmp #2
  beq @have_shots
  rep #$20
  txa
  sec
  sbc #32
  tax
  sep #$20
  bpl @shot_present
  bra @start_slots
@have_shots:
  inc COMBAT_HAS_SHOTS
.endif
@start_slots:
  rep #$20
  stz WAVE_SLOT
.ifdef POOL_MOTION
  stz $ec                     ; final scratch record needs refreshing
.endif
@slot:
  ldx WAVE_SLOT
  sep #$20
  lda ENEMY_POOL+8,x
  bne @active
  jmp @next
@active:
.ifdef POOL_MOTION
  lda ENEMY_POOL+4,x
  beq @copied
  lda COMBAT_PHASE
  and #1
  bne @direct
  lda COMBAT_HAS_SHOTS
  beq @direct
  lda ENEMY_POOL+9,x
  and #2
  bne @copied
@direct:
  ; A continuing movement record with no collision work this tick can be
  ; updated where it lives. Script/AI/collision ticks retain the full path.
  stx $ee
  inc $ec
  stz ENEMY_SCRIPT_KIND
  rep #$20
  stz ENEMY_CALLBACK
  sep #$20
  routine_call enemy_motion_pool, 22
  lda ENEMY_RETIRED
  beq :+
  inc COMBAT_RETIRED
:
  jmp @next
@copied:
  stz $ec
.endif
  rep #$20
  .repeat 16,I
    lda ENEMY_POOL+I*2,x
    sta ENEMY+I*2
  .endrepeat
  sep #$20
@script:
  routine_call enemy_script, 20
  lda ENEMY_SCRIPT_KIND
  bne :+
  jmp @move
:
  cmp #1
  bne :+
  jmp @retired
:
  rep #$20
  lda ENEMY_CALLBACK
  sta AI_CONTEXT+2
  lda $d2
  clc
  adc #3
  sta AI_CONTEXT+4
  sep #$20
  routine_call enemy_ai, 21
 .ifdef EXTENDED_STAGE_ENEMIES
  lda GROUND_KILL
  beq :+
  jsr flight_enemy_killed
  jmp @save
:
 .endif
 .if FLIGHT_PLAYER_AUX
  lda ENEMY+8
  bne :+
  jmp @retired
:
 .endif
  lda AI_FIRE
  beq @no_fire
  inc WAVE_FIRE_REQUESTS
 .ifdef EXTENDED_STAGE_ENEMIES
  cmp #3
  bne :+
  jsr ground_bullet_spawn
  bra @bullet_spawned
:
 .endif
.if FLIGHT_BULLETS
.ifdef ALL_STAGE_ENEMIES
  lda AI_FIRE
  cmp #2
  bne :+
  lda MEDIUM_SHOT_ANGLE
  bra @bullet_angle
:
.endif
  lda ENEMY+$16
.ifdef ALL_STAGE_ENEMIES
@bullet_angle:
.endif
  sta BULLET_CONTEXT
  jsr enemy_bullet_spawn
 .ifdef EXTENDED_STAGE_ENEMIES
@bullet_spawned:
 .endif
  cpx #BULLET_SCRATCH
  beq @no_fire
  inc BULLET_SPAWNS
.endif
@no_fire:
  rep #$20
  lda AI_NEXT
  sec
  sbc #7
  sta ENEMY+$1e
  sep #$20
  jmp @script
@move:
  routine_call enemy_motion, 22
  lda ENEMY_RETIRED
.ifdef ROUTINE_PROFILE
  beq :+
  jmp @retired
:
.else
  bne @retired
.endif
  lda COMBAT_PHASE
  and #1
.ifdef ROUTINE_PROFILE
  beq :+
  jmp @save
:
.else
  bne @save
.endif
  lda ENEMY+9
  and #3
.ifdef ROUTINE_PROFILE
  bne :+
  jmp @save
:
.else
  beq @save
.endif
  lda ENEMY+1
  and #16
.ifdef ROUTINE_PROFILE
  beq :+
  jmp @save
:
.else
  bne @save
.endif
 .if FLIGHT_PLAYER_AUX
  lda ENEMY+9
  and #2
  beq @body_contact
 .endif
  lda COMBAT_HAS_SHOTS
 .if FLIGHT_PLAYER_AUX
  beq @body_contact
 .else
  beq @save
 .endif
  routine_call enemy_shot_collision, 23
  lda ENEMY_HIT_SOUND
  beq @no_sound
  routine_call doc_play_hit, 27
@no_sound:
 .if FLIGHT_PLAYER_AUX
  lda ENEMY_HIT_SOUND
  cmp #$13
  beq @save
 .endif
  lda ENEMY_KILLED
 .if FLIGHT_PLAYER_AUX
  beq @body_contact
  cmp #2
  bne :+
  jsr flight_enemy_retire
  bra @save
:
  jsr flight_enemy_killed
  bra @save
 .else
  beq @save
  inc COMBAT_KILLS
  lda ENEMY+$17
  sta SCORE_AWARD_INDEX
  routine_call score_add, 26
  lda ENEMY+9
  and #4
  sta ENEMY+9
  stz ENEMY+4
  rep #$20
  lda ENEMY+$1c
  sta ENEMY+$1e
  sep #$20
  bra @save
 .endif
 .if FLIGHT_PLAYER_AUX
@body_contact:
  jsr flight_body_contacts
  bra @save
 .endif
@retired:
  inc COMBAT_RETIRED
 .if FLIGHT_PLAYER_AUX
  jsr flight_enemy_retired
 .endif
@save:
  rep #$20
  ldx WAVE_SLOT
  .repeat 16,I
    lda ENEMY+I*2
    sta ENEMY_POOL+I*2,x
  .endrepeat
@next:
.a8
  rep #$20
  lda WAVE_SLOT
  clc
  adc #32
  sta WAVE_SLOT
 .ifdef EXTENDED_STAGE_ENEMIES
  cmp #512
  bne :+
  lda #EXTENDED_POOL-ENEMY_POOL
  sta WAVE_SLOT
:
  cmp #EXTENDED_POOL-ENEMY_POOL+17*32
 .else
  cmp #512
 .endif
  beq @done
  sep #$20
  jmp @slot
@done:
.ifdef POOL_MOTION
  lda $ec
  beq :+
  ldx $ee
  .repeat 16,I
    lda ENEMY_POOL+I*2,x
    sta ENEMY+I*2
  .endrepeat
:
.endif
  sep #$20
  rts

.ifdef CONTINUOUS_GAME
; Construct a conservative union of vertical player-shot bounds once per
; even collision pass. Shots can be consumed later; retaining their bounds
; only allows extra collision checks.
shot_prepare_y_bounds:
  lda #255
  sta SHOT_Y_MIN
  sta SHOT_X_MIN
  stz SHOT_Y_MAX
  stz SHOT_X_MAX
  ldy #0
@next:
  cpy SHOT_ACTIVE_END
  beq @done
  ldx SHOT_ACTIVE,y
  lda SHOTS+3,x
  sec
  sbc SHOTS+7,x
  bcs :+
  lda #0
:
  cmp SHOT_Y_MIN
  bcs :+
  sta SHOT_Y_MIN
:
  lda SHOTS+3,x
  clc
  adc SHOTS+7,x
  bcc :+
  lda #255
:
  cmp SHOT_Y_MAX
  bcc :+
  sta SHOT_Y_MAX
:
  lda SHOTS+2,x
  sec
  sbc SHOTS+6,x
  bcs :+
  lda #0
:
  cmp SHOT_X_MIN
  bcs :+
  sta SHOT_X_MIN
:
  lda SHOTS+2,x
  clc
  adc SHOTS+6,x
  bcc :+
  lda #255
:
  cmp SHOT_X_MAX
  bcc :+
  sta SHOT_X_MAX
:
  iny
  iny
  bra @next
@done:
  rts
.endif

wave_records:
  rep #$30
  ldx #0
  ldy #0
@count:
  lda ENEMY_POOL+8,x
  and #255
  beq @count_next
  iny
@count_next:
  txa
  clc
  adc #32
  tax
  cpx #512*(1+FLIGHT_BULLETS)
  bne @count
  sty $e4
  tya
  asl
  asl
  asl
  sta $e6
  lda $2a
  asl
  asl
  asl
  tax
  clc
  adc $e6
  tay
  ; Shift player/projectile records once, preserving native draw order.
@shift:
  dex
  dex
  dey
  dey
  lda FLIGHT_OBJECTS,x
  sta FLIGHT_OBJECTS,y
  cpx #0
  bne @shift
  lda $2a
  clc
  adc $e4
  sta $2a
  ldx #0
  ldy #0
@slot:
  lda ENEMY_POOL+8,x
  and #255
  beq @next
  lda ENEMY_POOL+1,x
  and #$e0
  asl
  asl
  asl
  sta $e0
  lda ENEMY_POOL,x
  and #255
  ora $e0
  sta FLIGHT_OBJECTS,y
  lda ENEMY_POOL+1,x
  and #15
  sta FLIGHT_OBJECTS+2,y
  lda ENEMY_POOL+2,x
  and #255
  sec
  sbc #16
  sta FLIGHT_OBJECTS+4,y
  lda ENEMY_POOL+1,x
  and #16
  asl
  asl
  asl
  asl
  clc
  adc #240
  sta $e0
  lda ENEMY_POOL+3,x
  and #255
  sta $e2
  lda $e0
  sec
  sbc $e2
  sta FLIGHT_OBJECTS+6,y
  tya
  clc
  adc #8
  tay
@next:
  txa
  clc
  adc #32
  tax
  cpx #512*(1+FLIGHT_BULLETS)
  beq @done
  jmp @slot
@done:
  rts
