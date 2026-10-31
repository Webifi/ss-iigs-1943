.include "profile.inc"
; Live basic-weapon integration. Other weapon controllers remain separate.
; Dirty bounds are native state, kept independently for the two back pages.
.a8
.i16

flight_tick:
.ifdef CONTINUOUS_GAME
  lda CAB_DEMO
  cmp #2
  beq flight_idle_random             ; freeze the last demo state during its exit
  lda GAME_FLOW
  beq :+
  bra flight_idle_random
:
special_tick_site:
  lda CAB_RESULT_ACTIVE
  beq :+
  bra flight_idle_random
:
  lda PLAYER+8
  ora PLAYER+$88
  bne :+
  jsr game_players_tick
flight_idle_random:
  ; The arcade advances its random state on every cabinet frame, including
  ; attract, reports and waits. Gameplay already advances it below.
.if FLIGHT_BULLETS
  lda GAME_RNG_SKIP
  beq @advance_random
  stz GAME_RNG_SKIP
  rts
@advance_random:
  jsr random_step
.endif
  rts
:
.endif
.if FLIGHT_WAVES
.ifdef NATIVE_STAGE_FLOW
  jsl stage_scroll_tick
.ifdef CONTINUOUS_GAME
  jsl game_scene_tick
.endif
.endif
  routine_call camera_step, 12
  routine_call stage_event, 13
  lda CAMERA+$17
  sta ENEMY_CAM_X
  lda CAMERA+$18
  sta ENEMY_CAM_Y
.if FLIGHT_BULLETS
  lda RANDOM_STATE+3
  sta AI_CONTEXT+1
.ifdef ALL_STAGE_ENEMIES
  lda RANDOM_STATE+4
  sta MEDIUM_RANDOM
.endif
.else
  inc AI_CONTEXT+1
.endif
.endif
.ifdef CONTINUOUS_GAME
  jsr game_players_tick
  jsr projectiles_step
  jmp @done
.endif
.if FLIGHT_DEATH
  lda PLAYER+8
  cmp #4
  bne @normal_player
  jsr player_death
  routine_call projectiles_step, 15
  jmp @done
@normal_player:
.ifdef CONTINUOUS_GAME
  cmp #14
  bcc :+
  jsl native_player_presentation
  jmp @done
:
.endif
  cmp #2
  beq @flying
  routine_call projectiles_step, 15
  jmp @done
@flying:
.endif
 .if FLIGHT_PLAYER_AUX
  jsl player_live_before
 .endif
  routine_call flight_step, 14
.if FLIGHT_PLAYER_AUX
  jsl player_live_after
  lda COMBAT_PHASE
  sta PLAYER_AUX_PHASE
  ldy #0
  jsl player_aux
  lda PLAYER_AUX_SOUND
  beq :+
  sta PLAYER_EVENT_SOUND
:
.endif
  routine_call projectiles_step, 15
.if FLIGHT_PLAYER_AUX
  ldy #0
  jsl weapon_timer
.endif
  lda INPUT_P1
  and #$10
.ifdef ROUTINE_PROFILE
  beq :+
  jmp @released
:
.else
  bne @released
.endif
.if FLIGHT_WEAPONS
  ldy #0
  jsl weapon_change
  ldy #0
  jsl weapon_fire
.else
  routine_call gun_basic, 16
.endif
  lda GUN_SOUND
  beq @done
  rep #$20
  inc $17f2
  sep #$20
.if FLIGHT_DOC
.if FLIGHT_WEAPONS
  lda GUN_SOUND
  jsr doc_play_weapon
.else
  jsr doc_play_gun
.endif
.if FLIGHT_WEAPONS
  lda GUN_SOUND
  jsr doc_weapon_control
.else
  ldx #$a0
  jsr doc_read
.endif
  sta f:$050501
.endif
@done:
.if FLIGHT_PLAYER_AUX
.ifndef CONTINUOUS_GAME
  jsl player_live_palette
.endif
.endif
.if FLIGHT_COMBAT
.if FLIGHT_WAVES
.if FLIGHT_BULLETS
  inc COMBAT_PHASE
  routine_call bullet_tick, 17
.endif
  routine_call wave_combat_tick, 18
.ifdef NATIVE_LARGE_OBJECTS
  jsl large_loop_tick
.endif
.if FLIGHT_BULLETS
  routine_call random_step, 19
.endif
.else
  jsr combat_tick
.endif
.endif
  rts
@released:
  lda #$f8
  sta PLAYER+$54
  stz PLAYER+$56
  stz GUN_SOUND
  jmp @done

.ifndef STATE_ONLY
flight_shot_records:
  rep #$30
  ldx #0
.if FLIGHT_DEATH
  lda $2a
  asl
  asl
  asl
  tay
.else
  ldy #16
.endif
@slot:
  lda SHOTS+8,x
  and #255
  beq @next
  lda SHOTS,x
  and #255
  sta FLIGHT_OBJECTS+0,y
  lda SHOTS+1,x
  and #15
  sta FLIGHT_OBJECTS+2,y
  lda SHOTS+2,x
  and #255
  sec
  sbc #16
  sta FLIGHT_OBJECTS+4,y
  lda SHOTS+3,x
  and #255
  sta $e0
  lda #240
  sec
  sbc $e0
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
  cpx #18*32
  bne @slot
  tya
  lsr
  lsr
  lsr
  sta $2a
  rts

flight_bounds_save:
  rep #$30
  lda $68
  and #1
  asl
  tax
  stz $1518,x
  sta $ec
  lsr
  xba
.if FLIGHT_WAVES
  asl
  asl
.endif
  clc
  adc #FLIGHT_BOUNDS
  tay
  ldx #0
  lda $2a
  sta $ee
@object:
  lda FLIGHT_OBJECTS+4,x
  cmp #224
  bcc @left_positive
  bpl @skip_early
  clc
  adc #16
  bmi @skip_early
  beq @skip_early
  lda #0
@left_positive:
  sta $e8
  lda FLIGHT_OBJECTS+4,x
  clc
  adc #16
  cmp #225
  bcc @right_inside
  lda #224
@right_inside:
  clc
  adc #3
  lsr
  lsr
  sta $e6
  lda $e8
  lsr
  lsr
  sta $e8
  lda $e6
  sec
  sbc $e8
  xba
  sta $e6
  lda FLIGHT_OBJECTS+6,x
  cmp #256
  bcc @top_positive
  bpl @skip_early
  clc
  adc #16
  bmi @skip_early
  beq @skip_early
  lda #0
  bra @top_positive
@skip_early:
  jmp @next
@top_positive:
  sta $ea
  lda FLIGHT_OBJECTS+6,x
  clc
  adc #16
  cmp #257
  bcc @bottom_inside
  lda #256
@bottom_inside:
  sec
  sbc $ea
.ifdef COMPACT_RESTORE
  xba
.endif
  sta $0004,y
  lda $ea
  clc
  adc $2c
  jsr flight_row_group
  clc
  adc $e8
.ifdef COMPACT_RESTORE
  clc
  adc $2e
  xba
  sta $0002,y
  lda $e6
  xba
  asl
  phx
  tax
  lda flight_restore_vectors-2,x
  plx
  sta $0000,y
.else
  sta $0000,y
  lda $e6
  sta $0002,y
.endif
  phx
  ldx $ec
  inc $1518,x
  plx
  tya
  clc
.ifdef COMPACT_RESTORE
  adc #6
.else
  adc #8
.endif
  tay
@next:
  txa
  clc
  adc #8
  tax
  dec $ee
  beq @done
  jmp @object
@done:
  rts

flight_objects_restore:
.ifdef COMPACT_RESTORE
  rep #$30
  lda $68
  and #1
  asl
  tax
  lda $1518,x
  beq @empty
  sta $ee
  txa
  lsr
  xba
.if FLIGHT_WAVES
  asl
  asl
.endif
  clc
  adc #FLIGHT_BOUNDS
  tax
  lda #Z_RESTORE_BEGIN_BE
  sta a:$8002
  ldy #$8004
  phb
  lda $ee
  asl
  clc
  adc $ee
  asl
  dec
  mvn #$00,#$00
  plb
  tyx
  rts
@empty:
  ldx #$8002
  rts
.else
  rep #$30
  lda $68
  and #1
  asl
  tax
  lda $1518,x
  sta $ee
  bne :+
  ldx #$8002
  rts
:
  txa
  lsr
  xba
.if FLIGHT_WAVES
  asl
  asl
.endif
  clc
  adc #FLIGHT_BOUNDS
  tay
  ldx #$8002
@object:
  lda $0000,y
  sta $a0
  clc
  adc $2e
  sta $a4
  lda $0002,y
  xba
  and #255
  sta $a2
  lda $0004,y
  sta $e4
  phx
  lda $a2
  asl
  tax
  lda flight_restore_vectors-2,x
  plx
  sta a:$0000,x
  lda $a0
  and #$f000
  xba
  lsr
  lsr
  lsr
  lsr
  clc
  adc #$94
  xba
  sta $a6
  lda $a4
  and #$f000
  xba
  lsr
  lsr
  lsr
  lsr
  clc
  adc #$92
  ora $a6
  sta a:$0002,x
  lda #$0f01
  sta a:$0004,x
  lda $a0
  and #$0fff
  ora #$c000
  xba
  sta a:$0006,x
  lda $a4
  and #$0fff
  ora #$e000
  xba
  sta a:$0008,x
  lda #56
  sec
  sbc $a2
  xba
  ora $e4
  sta a:$000a,x
  txa
  clc
  adc #12
  tax
  tya
  clc
  adc #8
  tay
  dec $ee
  beq @done
  jmp @object
@done:
  rts

.endif

.endif
