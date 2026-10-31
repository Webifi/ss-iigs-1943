.include "profile.inc"
; Integrated native input, flight and layered drawing component.
; $68 update, $6c camera. FLIGHT_OBJECTS+0 object list. $1500 old back-page bounds.
.include "flight_draw.inc"
.ifdef CONTINUOUS_GAME
.include "game_clock.inc"
.endif

flight_loop:
  rep #$30
  stz $68
  lda #FLIGHT_INITIAL_CAMERA
  sta $6c
.if FLIGHT_LAYERS
  lda #FLIGHT_FG_INITIAL
  sta $6e
.endif
  ldx #30
@clear:
  stz $1500,x
  dex
  dex
  bpl @clear
  sep #$20
  ; These hi-res pages contain native code and game records, not IIgs video.
  ; Keep text/SHR and all other shadow-control bits as the caller set them.
  lda f:$e0c035
  sta a:$151e                 ; saved for the eventual game-exit path
  ora #$06
  sta f:$e0c035
  stz $41
.ifdef CONTINUOUS_GAME
  rep #$20
  lda #FLIGHT_FG_INITIAL+512
  sta GAME_WORLD_NEXT
  sep #$20
.endif
  jsr input_init
.if FLIGHT_GUN
  rep #$20
  stz $17f2
  ldx #18*32-2
@clear_shots:
  stz SHOTS,x
  dex
  dex
  bpl @clear_shots
  sep #$20
.endif
.if FLIGHT_COMBAT
.if FLIGHT_WAVES
  jsr wave_combat_init
.ifdef NATIVE_STAGE_FLOW
  jsl stage_flow_init
.ifdef CONTINUOUS_GAME
  jsl game_flow_init
  jsl game_world_init
.endif
.endif
.ifdef NATIVE_LARGE_OBJECTS
  jsl large_loop_init
.endif
.ifdef ALL_STAGE_ENEMIES
  lda #16
  sta STAGE_DIFFICULTY+6
.endif
 .if FLIGHT_PLAYER_AUX
  lda #$ff
  sta PLAYER_DIP
  stz PLAYER_SPECIAL_LOCK
  stz PLAYER_EVENT_SOUND
 .endif
.else
  jsr combat_init
.endif
.endif
.ifdef CONTINUOUS_GAME
  jsr flight_clock_init
.endif
@frame:
.ifdef CONTINUOUS_GAME
  jsr flight_clock_wait
.endif
.ifdef STREAM_PROFILE
  lda $68
  sta f:$05040d
.endif
.if FLIGHT_DEATH
  jsr doc_stream_update
.endif
  routine_call input_sample, 0
.ifdef CONTINUOUS_GAME
  jsl cabinet_frame
.endif
.ifdef CPU_REPLAY_INPUT
  ; Diagnostic fixture only: retain native input work, then replay the
  ; sampled controls from a saved failing run so both models see its load.
  ldx $68
  lda f:CPU_REPLAY_INPUT,x
  sta INPUT_P1
.endif
.ifdef WEAPON_FIXTURE_SELECTORS
  ldx $68
  lda f:WEAPON_FIXTURE_SELECTORS,x
 .if FLIGHT_PLAYER_AUX
  cmp PLAYER+$51
  beq :+
  pha
  lda #64
  sta PLAYER+$57
  pla
:
 .endif
  sta PLAYER+$51
  lda INPUT_P1
  and #$ef
  sta INPUT_P1
.endif
.ifdef MEDIUM_FIXTURE
  ; Controlled live coverage after the opening's quiet art jobs.
  lda $68
  cmp #16
  bne :+
  lda #128
  sta STAGE_CONTROL_INDEX
  jsl medium_spawn
  lda #139
  sta STAGE_CONTROL_INDEX
  jsl medium_spawn
:
.endif
.ifdef LARGE_CORE_FIXTURE
  lda $68
  cmp #16
  bne :+
  lda #148
  sta STAGE_CONTROL_INDEX
  jsl large_spawn
:
.endif
.ifdef SHIP_FIXTURE
.if SHIP_FIXTURE < 5
  lda $68
  cmp #32
  bne :+
  lda #SHIP_FIXTURE
  sta SHIP_REQUEST
  lda #120
  sta SHIP_REQUEST+1
  lda #120
  sta SHIP_REQUEST+2
  jsl ship_launch
:
.else
  lda $68
  cmp #56
  bne :+
  lda #0
  sta STAGE_FLAGS+$1c
  rep #$20
  lda #LARGE_POOL
  sta STAGE_FLAGS+$1d
  sep #$20
  lda #2
  jsl ship_finish_begin
:
.endif
.endif
.ifdef PICKUP_FIXTURE_EVENTS
  ldx $68
  lda f:PICKUP_FIXTURE_EVENTS,x
  beq :+
  sta PICKUP_KIND
  lda PLAYER+2
  clc
  adc #8
  sta PICKUP_X
  lda PLAYER+3
  sta PICKUP_Y
  stz RANDOM_STATE+6           ; exercise the original successful laser draw
  jsl pickup_spawn
:
.endif
  lda INPUT_P1
  sta $40
.if FLIGHT_WAVES
  lda $68
  sta f:$050404
.endif
.if FLIGHT_GUN
.if FLIGHT_WAVES
.ifndef CONTINUOUS_GAME
  rep #$20
  lda $68
  sep #$20
  beq @no_initial_tick
.endif
.endif
.ifdef CONTINUOUS_GAME
  jsl cabinet_controls
.endif
  jsr flight_tick
.ifdef CONTINUOUS_GAME
  jsr input_tick
  jsl cabinet_controls
.endif
  jsr flight_tick
.if FLIGHT_WAVES
@no_initial_tick:
  rep #$20
  lda CAMERA
  sta $6c
  lda CAMERA+$0f
  sta $6e
  sep #$20
.endif
.else
  jsr flight_step
  jsr flight_step
.endif
.if FLIGHT_WAVES
  lda $68
  sta f:$050405
.endif
.ifdef CONTINUOUS_GAME
  jsr flight_picture_ready
  bcs :+
  jmp @complete_update
:
.endif
  rep #$30
.ifdef CONTINUOUS_GAME
  lda GAME_PICTURE
.else
  lda $68
.endif
  and #1
  beq @page_zero
  lda #$8000
@page_zero:
  sta $2e
  lda $6c
  eor #$ffff
  inc
  and #255
  sta $2c
.ifdef STATE_ONLY
  sep #$20
  lda $68
  sta f:$050406
  sta f:$050402
  jsr flight_state_packet
.else
.if FLIGHT_GUN
  routine_call flight_objects_restore, 1
.else
  routine_call flight_restore, 2
.endif
.if FLIGHT_LAYERS
  routine_call flight_hud_restore, 3
.endif
  stx $26
.if FLIGHT_LAYERS
  routine_long FG_PLAN, 4
  rep #$30
.if FLIGHT_ART_STREAM
  jsr art_stream_append
.endif
.endif
.if FLIGHT_WAVES
  sep #$20
  lda $68
  sta f:$050406
  rep #$20
.endif
.if FLIGHT_DEATH
  jsr death_player_records
.else
  lda PLAYER
  and #255
  sta FLIGHT_OBJECTS+0
  lda PLAYER+$20
  and #255
  sta FLIGHT_OBJECTS+8
  stz FLIGHT_OBJECTS+2
  stz FLIGHT_OBJECTS+10
  lda PLAYER+2
  and #255
  sec
  sbc #16
  sta FLIGHT_OBJECTS+4
  clc
  adc #16
  sta FLIGHT_OBJECTS+12
  lda PLAYER+3
  and #255
  sta $a0
  lda #240
  sec
  sbc $a0
  sta FLIGHT_OBJECTS+6
  sta FLIGHT_OBJECTS+14
.endif
.if !FLIGHT_GUN
  clc
  adc $2c
  jsr flight_row_group
  sta $a0
  lda FLIGHT_OBJECTS+4
  lsr
  lsr
  clc
  adc $a0
  pha
  lda $68
  and #1
  asl
  tay
  pla
  sta $1504,y
  lda #1
  sta $1500,y
  lda FLIGHT_OBJECTS+4
  and #3
  beq @aligned
  lda #1
@aligned:
  clc
  adc #8
  sta $1508,y
.endif
  lda #FLIGHT_OBJECTS+0
  sta $20
.if !FLIGHT_DEATH
  lda #2
  sta $2a
.endif
.if FLIGHT_GUN
  routine_call flight_shot_records, 5
.if FLIGHT_COMBAT
.if FLIGHT_WAVES
  routine_call wave_records, 6
.else
  jsr combat_records
.endif
.endif
.ifndef COMBINED_BOUNDS
  routine_call flight_bounds_save, 7
.endif
.endif
  sep #$20
  stz $22
  lda $68
  sta f:$050402
  routine_long SPRITE_PLAN, 8
.if FLIGHT_LAYERS
.if FLIGHT_COMBAT
  routine_call score_hud, 9
.if FLIGHT_CONTACT
  routine_call contact_hud, 10
.endif
.endif
  rep #$30
  lda $28
  clc
  adc #$8000
  sta $26
  lda #$1600
  sta $20
  lda #CHAR_COUNT
  sta $2a
  sep #$20
  stz $22
  routine_long CHAR_PLAN, 11
.endif
.endif
  lda $68
  sta f:$050403
.ifdef CONTINUOUS_GAME
  lda GAME_PICTURE
.else
  lda $68
.endif
  and #1
  clc
  adc #$40
  jsr stream_packet
  rep #$20
.ifdef CONTINUOUS_GAME
  inc GAME_PICTURE
  lda $68
  sta GAME_SENT_LOGIC
.endif
.ifndef CONTINUOUS_GAME
  lda $68
  asl
  asl
  asl
  tax
  lda PLAYER+2
  sta f:$050a00,x
  lda PLAYER
  sta f:$050a02,x
.if FLIGHT_GUN
  sep #$20
  lda $17f2
  sta f:$050a03,x
  rep #$20
.endif
  lda $28
  sta f:$050a04,x
  lda INPUT_P1
  sta f:$050a06,x
.if FLIGHT_DEATH
  sep #$20
  lda PLAYER+8
  sta f:$050a07,x
  rep #$20
.endif
.if FLIGHT_COMBAT
  lda ENEMY+2
  sta f:$051200,x
  lda ENEMY
  sta f:$051202,x
  lda ENEMY+8
  sta f:$051204,x
  lda COMBAT_KILLS
  sta f:$051206,x
.endif
.if FLIGHT_WEAPONS
  ldx $68
  sep #$20
  lda PLAYER+$51
  sta f:$051b00,x
.ifdef FLIGHT_QUIET_ART
  lda QUIET_NEXT
  sta f:$051c00,x
.endif
  rep #$20
.endif
.endif
@complete_update:
  rep #$20
  inc $68
  lda $68
  sta f:$050320
.if FLIGHT_COMBAT
.if !FLIGHT_WAVES
  sep #$20
  jsr camera_step
  jsr camera_step
  rep #$20
  lda CAMERA
  sta $6c
  lda CAMERA+$0f
  sta $6e
.endif
.else
  inc $6c
.if FLIGHT_LAYERS
  inc $6e
  inc $6e
.endif
.endif
.ifdef CONTINUOUS_GAME
  sep #$20
  jmp @frame
.endif
  lda $68
  cmp #FLIGHT_UPDATES+1
  sep #$20
  beq @done
  jmp @frame
@done:
  jsr done
  rep #$20
  ldx #126
@save_player:
  lda PLAYER,x
  sta f:$050f00,x
  dex
  dex
  bpl @save_player
.if FLIGHT_GUN
  ldx #18*32-2
@save_shots:
  lda SHOTS,x
  sta f:$050f80,x
  dex
  dex
  bpl @save_shots
.endif
.if FLIGHT_COMBAT
  ldx #30
@save_enemy:
  lda ENEMY,x
  sta f:$0511c0,x
  dex
  dex
  bpl @save_enemy
  lda COMBAT_SPAWNS
  sta f:$0511e0
  lda COMBAT_RETIRED
  sta f:$0511e2
.if FLIGHT_WAVES
  lda STAGE_EVENTS
  sta f:$0511e4
  lda WAVE_FIRE_REQUESTS
  sta f:$0511e6
  ldx #510
@save_pool:
  lda ENEMY_POOL,x
  sta f:$051600,x
  dex
  dex
  bpl @save_pool
.if FLIGHT_BULLETS
  ldx #510
@save_bullets:
  lda BULLETS,x
  sta f:$051800,x
  dex
  dex
  bpl @save_bullets
  lda BULLET_SPAWNS
  sta f:$051a48
  lda BULLET_MAX_ACTIVE
  sta f:$051a4a
  ldx #6
@save_random:
  lda RANDOM_STATE,x
  sta f:$051a40,x
  dex
  dex
  bpl @save_random
.if FLIGHT_CONTACT
  ldx #54
@save_energy:
  lda ENERGY_HUD,x
  sta f:$051a00,x
  dex
  dex
  bpl @save_energy
  lda CONTACT_HITS
  sta f:$051a4c
  lda CONTACT_DEATH_REQUESTS
  sta f:$051a4e
.if FLIGHT_DEATH
  lda PLAYER+8
  sta f:$051a50
  lda PLAYER+$1c
  sta f:$051a52
  ldx #22
@save_death:
  lda DEATH_CONTEXT,x
  sta f:$051a54,x
  dex
  dex
  bpl @save_death
  ldx #10
@save_doc_stream:
  lda DOC_STREAM_ACTIVE,x
  sta f:$051a80,x
  dex
  dex
  bpl @save_doc_stream
.endif
.endif
.endif
.endif
.endif
  sep #$20
.if FLIGHT_DOC
  ldx #$a0
  jsr doc_read
  sta f:$050502
.endif
  rts

.ifndef STATE_ONLY
flight_restore:
  rep #$20
  ldx #$8002
  lda $68
  and #1
  asl
  tay
  lda $1500,y
  beq @done
  lda $1504,y
  sta $a0
  lda $1508,y
  xba
  sta $a2
  ldy #16
@row:
  lda #Z_SCENE_DMA_BE
  sta a:$0000,x
  lda $a0
  xba
  sta a:$0002,x
  lda $a0
  clc
  adc $2e
  xba
  sta a:$0004,x
  lda $a2
  sta a:$0006,x
  txa
  clc
  adc #8
  tax
  lda $a0
  clc
  adc #56
  sta $a0
  dey
  bne @row
@done:
  rts

flight_row_group:
  phx
  asl
  tax
  lda f:FLIGHT_ROW_TABLE,x
  plx
  rts

.if FLIGHT_LAYERS
; Restore the previous HUD marks on this back page before foreground redraw.
; The run geometry comes from the font masks at build time.
flight_hud_restore:
  rep #$30
  lda $68
  and #1
  asl
  tay
  lda $1514,y
  beq @save
  lda $1510,y
  sta $a0
.ifdef COMPACT_HUD_RESTORE
  clc
  adc $2e
  xba
  sta a:$0006,x
  lda #Z_HUD_RESTORE_BE
  sta a:$0000,x
  lda #HUD_RESTORE_BANK_BE
  sta a:$0002,x
  lda #HUD_RESTORE_POINTER_BE
  sta a:$0004,x
  txa
  clc
  adc #8
  tax
.else
  phx
  ldx #0
  lda #HUD_RESTORE_COUNT
  sta $a2
  pla
  tay
@run:
  ; Y is packet output while X addresses the immutable restore-run table.
  lda #Z_SCENE_DMA_BE
  sta a:$0000,y
  lda f:HUD_RESTORE,x
  clc
  adc $a0
  pha
  xba
  sta a:$0002,y
  pla
  clc
  adc $2e
  xba
  sta a:$0004,y
  lda f:HUD_RESTORE+2,x
  sta a:$0006,y
  inx
  inx
  inx
  inx
  tya
  clc
  adc #8
  tay
  dec $a2
  bne @run
  tyx
  lda $68
  and #1
  asl
  tay
.endif
@save:
  phy
  lda $2c
  jsr flight_row_group
  ply
  sta $1510,y
  lda #1
  sta $1514,y
  rts
.endif

.endif

.ifdef CONTINUOUS_GAME
.include "game_clock.s"
.endif
