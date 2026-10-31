; Enemy state and the combat phase. Without FLIGHT_WAVES, combat_tick inserts
; two original-data enemies.
.a8
.i16
ENEMY = $1100
ENEMY_CAM_X = $1130
ENEMY_CAM_Y = $1131
ENEMY_RETIRED = $1132
COMBAT_PHASE = $1133
COMBAT_LAST_SPAWN = $1134
COMBAT_SPAWNS = $1136
COMBAT_KILLS = $1137
COMBAT_RETIRED = $1138

combat_init:
  rep #$20
  ldx #$3e
@clear:
  stz ENEMY,x
  dex
  dex
  bpl @clear
  sep #$20
  lda #$ff
  sta COMBAT_LAST_SPAWN
  rts

.if !FLIGHT_WAVES
combat_tick:
  inc COMBAT_PHASE
  lda $68
  cmp #74
  beq @spawn
  cmp #109
  bne @update
@spawn:
  cmp COMBAT_LAST_SPAWN
  beq @update
  sta COMBAT_LAST_SPAWN
  inc COMBAT_SPAWNS
  rep #$20
  ldx #30
@template:
  lda combat_enemy_template,x
  sta ENEMY,x
  dex
  dex
  bpl @template
  sep #$20
  lda PLAYER+2
  clc
  adc #8
  sta ENEMY+2
  lda PLAYER+3
  clc
  adc #24
  sta ENEMY+3
@update:
  lda ENEMY+8
  bne @active
  rts
@active:
  jsr enemy_script
  lda ENEMY_SCRIPT_KIND
  beq @move
  cmp #1
  beq @retired
  rep #$20
  lda ENEMY_CALLBACK
  cmp #$5a3e
  beq @explosion
  sep #$20
  lda #$ed
  sta f:$050301
  rts
@explosion:
.a16
  lda #$5a53-7
  sta ENEMY+$1e
  sep #$20
  stz ENEMY+$0e
  jsr enemy_script
@move:
  jsr enemy_motion
  lda ENEMY_RETIRED
  bne @retired
  lda COMBAT_PHASE
  and #1
  bne @done
  lda ENEMY+9
  and #2
  beq @done
  lda ENEMY+1
  and #16
  bne @done
  jsr enemy_shot_collision
  lda ENEMY_HIT_SOUND
  beq @no_sound
  jsr doc_play_hit
@no_sound:
  lda ENEMY_KILLED
  beq @done
  inc COMBAT_KILLS
  lda ENEMY+$17
  sta SCORE_AWARD_INDEX
  jsr score_add
  ; Enter the original death script. Fleet totals, score and drops are separate.
  lda ENEMY+9
  and #4
  sta ENEMY+9
  stz ENEMY+4
  rep #$20
  lda ENEMY+$1c
  sta ENEMY+$1e
  sep #$20
@done:
  rts
@retired:
  inc COMBAT_RETIRED
  rts

combat_records:
  rep #$30
  lda ENEMY+8
  and #255
  beq @done
  lda $2a
  asl
  asl
  asl
  tax
@shift:
  dex
  dex
  lda FLIGHT_OBJECTS+0,x
  sta FLIGHT_OBJECTS+8,x
  cpx #0
  bne @shift
  lda ENEMY+1
  and #$e0
  asl
  asl
  asl
  sta $e0
  lda ENEMY
  and #255
  ora $e0
  sta FLIGHT_OBJECTS+0
  lda ENEMY+1
  and #15
  sta FLIGHT_OBJECTS+2
  lda ENEMY+2
  and #255
  sec
  sbc #16
  sta FLIGHT_OBJECTS+4
  lda ENEMY+1
  and #16
  asl
  asl
  asl
  asl
  clc
  adc #240
  sta $e0
  lda ENEMY+3
  and #255
  sta $e2
  lda $e0
  sec
  sbc $e2
  sta FLIGHT_OBJECTS+6
  inc $2a
@done:
  rts

.endif
