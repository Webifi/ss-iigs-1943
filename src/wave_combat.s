; The small enemies: each update runs the motion script, the decisions, the
; shots and the contacts of each object in ENEMY_POOL, then EXTENDED_POOL.
.a8
.i16

; wave_combat_init: a new game: the enemy pools, the stage event state and
; the second player record are cleared; the bullets, the contacts and the
; deaths start again. JSR.
wave_combat_init:
  jsr combat_init
  a16
  ldx #ENEMY_COUNT*OBJECT_SIZE-2
@clear:
  stz ENEMY_POOL,x
  dex
  dex
  bpl @clear
  ldx #EXTENDED_COUNT*OBJECT_SIZE-2
@extended_clear:
  stz EXTENDED_POOL,x
  dex
  dex
  bpl @extended_clear
  stz STAGE_GROUP_INDEX
  stz WAVE_SLOT
  stz STAGE_CALLBACK
  stz STAGE_BANK
  ldx #PLAYER_SIZE-2
@second_player:
  stz PLAYER2,x
  dex
  dex
  bpl @second_player
  a8
  stz WAVE_MODIFIER
  stz AI_PREFERENCE
  stz AI_RANDOM
  jsr bullet_init
  jsr contact_init
  jsr death_loop_init
  rts

; wave_combat_tick: one update of the small enemies (flight_weapons). On
; even COMBAT_PHASE updates the flying player shots are listed first
; (SHOT_ACTIVE: player 1, then from SHOT_ACTIVE_P2 player 2) with their
; bounds; each object then runs its script, its decision tail, its shot and
; its contacts. JSR; D = 0 after it.
wave_combat_tick:
  stz COMBAT_HAS_SHOTS
  lda COMBAT_PHASE
  and #1
  beq :+
  jmp @start_slots              ; odd update: no shot contacts
:
  ldy #0
  ; The list order is also the order of the first hit. The player 2 list
  ; starts at SHOT_ACTIVE_P2 also when player 1 has no shot.
  .repeat SHOT_COUNT/2,I
    lda SHOTS+I*SHOT_SIZE+SHOT_STATE
    cmp #SHOT_FLYING
    bne :+
    a16
    lda #I*SHOT_SIZE
    sta SHOT_ACTIVE,y
    iny
    iny
    a8
:
  .endrepeat
  sty SHOT_ACTIVE_P2
  .repeat SHOT_COUNT/2,I
    lda SHOTS+(I+SHOT_COUNT/2)*SHOT_SIZE+SHOT_STATE
    cmp #SHOT_FLYING
    bne :+
    a16
    lda #(I+SHOT_COUNT/2)*SHOT_SIZE
    sta SHOT_ACTIVE,y
    iny
    iny
    a8
:
  .endrepeat
  sty SHOT_ACTIVE_END
  cpy #0
  beq @start_slots
  jsr shot_prepare_y_bounds
  inc COMBAT_HAS_SHOTS
@start_slots:
  ; Each slot with an object runs wave_object; an empty slot costs one test.
  a8
  .repeat ENEMY_COUNT,I
    lda ENEMY_POOL+I*OBJECT_SIZE+OBJ_TYPE
    beq :+
    ldx #I*OBJECT_SIZE
    jsr wave_object
:
  .endrepeat
  .repeat EXTENDED_COUNT,I
    lda EXTENDED_POOL+I*OBJECT_SIZE+OBJ_TYPE
    beq :+
    ldx #EXTENDED_POOL-ENEMY_POOL+I*OBJECT_SIZE
    jsr wave_object
:
  .endrepeat
  a16
  ; D still identifies the last live record; zero means no record selected.
  ; On an empty pass leave X at the last slot, as the original loop did.
  tdc
  beq :+
  tax
  lda #0
  tcd
  a8
  rts
:
  ldx #EXTENDED_POOL-ENEMY_POOL+(EXTENDED_COUNT-1)*OBJECT_SIZE
  a8
  rts

; wave_object: the small object at the slot X: its script, its decision
; tail, its shot and its contacts. D = the object record (POOL_RECORD) while
; it runs, and after it. JSR; A8.
wave_object:
  stx WAVE_SLOT
  a16
  txa
  clc
  adc #ENEMY_POOL
  sta POOL_RECORD
  tcd
  a8
@script:
  ; The motion step ends: the next step, or a decision tail.
  lda z:OBJ_DURATION
  bne @move
@script_decode:
  jsr enemy_script
  lda ENEMY_SCRIPT_KIND
  bne :+
  jmp @move                     ; SCRIPT_MOVE
:
  cmp #SCRIPT_RETIRE
  bne :+
  jmp @retired
:
  a16
  lda ENEMY_CALLBACK
  sta AI_TAIL
  lda a:SCRIPT_STEP
  clc
  adc #STEP_TAIL_SIZE         ; the step after the code tail
  sta AI_CONTINUE
  a8
  jsr enemy_ai
  ; The decision: a ground kill, a retirement, a shot; then the next step.
  lda GROUND_KILL
  beq :+
  phd
  pea .loword(ZERO_PAGE)
  pld
  jsr flight_enemy_killed
  pld
  jmp @save
:
  lda z:OBJ_TYPE
  bne :+
  jmp @retired
:
  lda AI_FIRE
  beq @no_fire
  cmp #AIF_GROUND
  bne :+
  jsr ground_bullet_spawn
  bra @no_fire
:
  lda AI_FIRE
  cmp #AIF_ANGLE
  bne :+
  lda MEDIUM_SHOT_ANGLE
  bra @bullet_angle
:
  lda z:OBJ_AIM                 ; AIF_AIMED
@bullet_angle:
  sta BULLET_ANGLE
  jsr enemy_bullet_spawn
@no_fire:
  a16
  lda AI_NEXT
  sec
  sbc #STEP_SIZE                ; the script reads OBJ_MOTION + STEP_SIZE
  sta z:OBJ_MOTION
  a8
  jmp @script
@move:
  ; The move, then on even updates the contacts of an object on the field.
  jsr stationary_wave_motion
  lda ENEMY_RETIRED
  bne @retired
  lda COMBAT_PHASE
  and #1
  bne @save
  lda z:OBJ_FLAGS
  and #OF_CONTACT|OF_SHOT
  beq @save
  lda z:SPR_ATTR
  and #SPR_ALONG_HIGH
  bne @save
  lda z:OBJ_FLAGS
  and #OF_SHOT
  beq @body_contact
  lda COMBAT_HAS_SHOTS
  beq @body_contact
  jsr enemy_shot_collision
  lda ENEMY_HIT_SOUND
  beq @no_sound
  jsl game_sound_request
@no_sound:
  lda ENEMY_HIT_SOUND
  cmp #SND_ENEMY_HIT
  beq @save                     ; hit, not killed
  lda ENEMY_KILLED
  beq @body_contact
  cmp #EK_RETIRE
  bne :+
  phd
  pea .loword(ZERO_PAGE)
  pld
  jsr flight_enemy_retire
  pld
  bra @save
:
  phd
  pea .loword(ZERO_PAGE)
  pld
  jsr flight_enemy_killed
  pld
  bra @save
@body_contact:
  lda z:OBJ_FLAGS
  and #OF_CONTACT
  beq @save
  phd
  pea .loword(ZERO_PAGE)
  pld
  jsr flight_body_contacts
  pld
  bra @save
@retired:
  phd
  pea .loword(ZERO_PAGE)
  pld
  jsr flight_enemy_retired
  pld
@save:
.a8
  rts

; shot_prepare_y_bounds: SHOT_X/Y_MIN/MAX = the box around all listed shots
; and their radii, once for each even update. A shot can end later in the
; update; its bounds stay, which only allows more contact tests. JSR.
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
  lda SHOTS+SPR_ALONG,x
  sec
  sbc SHOTS+SHOT_ALONG_RADIUS,x
  bcs :+
  lda #0
:
  cmp SHOT_Y_MIN
  bcs :+
  sta SHOT_Y_MIN
:
  lda SHOTS+SPR_ALONG,x
  clc
  adc SHOTS+SHOT_ALONG_RADIUS,x
  bcc :+
  lda #255
:
  cmp SHOT_Y_MAX
  bcc :+
  sta SHOT_Y_MAX
:
  lda SHOTS+SPR_CROSS,x
  sec
  sbc SHOTS+SHOT_CROSS_RADIUS,x
  bcs :+
  lda #0
:
  cmp SHOT_X_MIN
  bcs :+
  sta SHOT_X_MIN
:
  lda SHOTS+SPR_CROSS,x
  clc
  adc SHOTS+SHOT_CROSS_RADIUS,x
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
.assert SPR_ALONG_HIGH = 16 .and SHOT_STATE = 8 .and SHOT_SIZE = 32, error
