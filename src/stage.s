; Native original-US event selection ($1140-$11A6), original stage data.
; Unsupported handlers are explicit errors until their native ports exist.
.a8
.i16
STAGE_CALLBACK = $11b0
STAGE_BANK = $11b2
STAGE_EVENTS = $11b3

stage_event:
.ifdef CONTINUOUS_GAME
.ifdef AUDIO_FM
  jsl fm_stage_hint
.endif
  jsl game_airboss_tick
.endif
  lda CAMERA_EVENT_READY
  beq @done
  lda CAMERA+$21
  bne @done
.ifndef STAGE_COMPACT
  rep #$20
  ldx CAMERA+$11
  sep #$20
.endif
.ifdef STAGE_ALL_TABLES
  ; Resolve a stage table once per event check. No host bank switch or ROM
  ; execution is needed. $d8-$da is scratch, separate from live object state.
  rep #$20
  lda CAMERA_STAGE
  and #15
  asl
  asl
  tax
  lda f:STAGE_TABLE_POINTERS,x
  sta $d8
  sep #$20
  lda f:STAGE_TABLE_POINTERS+2,x
  sta $da
  ldy CAMERA+$11
  iny
  lda [$d8],y
.else
  lda f:stage_events+1,x
.endif
  cmp CAMERA+$10
  bne @done
.ifdef STAGE_ALL_TABLES
  dey
  lda [$d8],y
  cmp CAMERA+$0f
  beq :+
  bcs @done
:
  iny
  iny
  rep #$20
  lda [$d8],y
.ifdef STAGE_COMPACT
  tax
  lda f:STAGE_DESCRIPTORS,x
.endif
.else
  lda CAMERA+$0f
  cmp f:stage_events,x
  bcc @done
  rep #$20
  lda f:stage_events+2,x
.endif
  sta STAGE_CALLBACK
  sep #$20
.ifdef STAGE_ALL_TABLES
.ifdef STAGE_COMPACT
  lda f:STAGE_DESCRIPTORS+2,x
  sta STAGE_BANK
  lda f:STAGE_DESCRIPTORS+3,x
  sta STAGE_CONTROL_INDEX
.else
  iny
  iny
  lda [$d8],y
  sta STAGE_BANK
  iny
  lda [$d8],y
  sta STAGE_CONTROL_INDEX
.endif
.else
  lda f:stage_events+4,x
  sta STAGE_BANK
.endif
  rep #$20
.ifdef STAGE_ALL_TABLES
  lda CAMERA+$11
.else
  txa
.endif
  clc
.ifdef STAGE_COMPACT
  adc #4
.else
  adc #6
.endif
  sta CAMERA+$11
  sep #$20
  inc STAGE_EVENTS
  jmp stage_dispatch
@done:
  rts

stage_dispatch:
.ifdef CONTINUOUS_GAME
  jsl game_airboss_event
  bcc :+
  rts
:
.endif
.ifdef GAME_TEST_STAGE
  ; Development build only. The real stage initializer owns every state.
  jsl game_test_stage_dispatch
  bcc :+
  rts
:
.endif
.ifdef EXTENDED_STAGE_ENEMIES
  jsl extended_spawn
  bcc :+
  inc COMBAT_SPAWNS
  rts
:
.endif
.ifdef STAGE_ALL_TABLES
  jsl stage_control_fast
  bcc :+
  rts
:
.endif
.ifdef ALL_STAGE_ENEMIES
  jsl simple_spawn
  bcc :+
  inc COMBAT_SPAWNS
  rts
:
  jsl medium_spawn
  bcc :+
  inc COMBAT_SPAWNS
  rts
:
.endif
.ifdef NATIVE_LARGE_OBJECTS
  jsl large_spawn
  bcc :+
  rts
:
.endif
.ifdef BANK6_TURRETS
  lda STAGE_CONTROL_INDEX
  cmp #149
  bcc @not_turret
  cmp #155
  bcs @not_turret
  sec
  sbc #149
  sta TURRET_SPAWN_ID
.ifdef CONTINUOUS_GAME
  lda STAGE_GROUP_INDEX
  sta TURRET_GROUP
  lda STAGE_BOSS_PHASE
  sta TURRET_RETRY
.endif
  jsl turret_spawn
.ifdef CONTINUOUS_GAME
  lda TURRET_GROUP
  sta STAGE_GROUP_INDEX
.endif
  rts
@not_turret:
.endif
  ; The circular wave belongs to bank six, not the bank-zero fighter set.
  lda STAGE_BANK
  cmp #24
  bne @fixed_bank
  rep #$20
  lda STAGE_CALLBACK
  cmp #$9a75
  bne :+
  sep #$20
  lda #7
  jmp stage_fighter
:
.a16
  cmp #$aa5b
  bne :+
  sep #$20
  ; This is the original two-player-only formation.
  lda PLAYER+8
  beq @no_pair
  lda PLAYER+$88
  beq @no_pair
  jsl game_pair_wave
@no_pair:
  stz WAVE_MODIFIER
  rts
:
  sep #$20
@fixed_bank:
  lda STAGE_BANK
  beq :+
  jmp stage_unknown
:
  rep #$20
  lda STAGE_CALLBACK
.ifdef CONTINUOUS_GAME
  cmp #$9b9a
  bne :+
  sep #$20
  jsl game_giant_spawn
  rts
:
.endif
.a16
  cmp #$87cf
  bne :+
  sep #$20
  lda #1
  jmp stage_fighter
:
.a16
  cmp #$87d6
  bne :+
  sep #$20
  lda #2
  jmp stage_fighter
:
.a16
  cmp #$87dd
  bne :+
  sep #$20
  lda #3
  jmp stage_fighter
:
.a16
  cmp #$87e4
  beq stage_four_conditional
  cmp #$87f2
  bne :+
  sep #$20
  lda #4
  jmp stage_fighter
:
.a16
  cmp #$87f9
  beq stage_five_conditional
.a16
  cmp #$8807
  bne :+
  sep #$20
  lda #5
  jmp stage_fighter
:
.a16
  cmp #$9a75
  bne :+
  sep #$20
  lda #7
  jmp stage_fighter
:
.a16
  cmp #$6ee3
  bne :+
  sep #$20
  lda #$f7
  sta WAVE_MODIFIER
  rts
:
.a16
stage_unknown:
  sep #$20
  lda #$e9
  sta f:$050301
  rts
stage_four_conditional:
  sep #$20
  lda #4
  bra stage_both_players
stage_five_conditional:
  sep #$20
  lda #5
stage_both_players:
  ldx PLAYER+8
  txa
  and #255
  beq stage_no_wave
  lda PLAYER+$88
  beq stage_no_wave
  rep #$20
  lda STAGE_CALLBACK
  cmp #$87e4
  sep #$20
  beq stage_four
  lda #5
  jmp stage_fighter
stage_four:
  lda #4
  jmp stage_fighter
stage_no_wave:
  stz WAVE_MODIFIER
  rts
stage_fighter:
.a8
  sta WAVE_GROUP
  jsr wave_spawn
  inc COMBAT_SPAWNS
  rts

.ifdef CONTINUOUS_GAME
; Bank-zero entry for the prepared ground-bullet operation.
game_ground_shot_far:
.a8
  rep #$20
  lda LARGE_RECORD
  sta POOL_RECORD
  sep #$20
  jsr ground_bullet_spawn_direct
  lda LARGE_AI_X
  sta a:2,x
  lda LARGE_AI_Y
  sta a:3,x
  rtl
.endif

.ifdef CONTINUOUS_GAME
airboss_shot_far:
.a8
  lda BULLET_CONTEXT+3
  pha
  lda #1
  sta BULLET_CONTEXT+3
  lda MEDIUM_SHOT_ANGLE
  sta BULLET_CONTEXT
  jsr enemy_bullet_spawn_direct
  lda LARGE_AI_X
  sta a:2,x
  lda LARGE_AI_Y
  sta a:3,x
  pla
  sta BULLET_CONTEXT+3
  rtl
.endif
