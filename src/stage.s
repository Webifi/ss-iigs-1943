; The stage events (US arcade $1140-$11A6) from the arcade stage data, packed
; by scripts/stage_controls.py: each event has a camera word and a
; descriptor (the arcade callback, its bank and the control index). An event
; runs when the foreground scroll reaches its camera; the handlers of
; stage_dispatch take it. An event that no handler takes does nothing.
.a8
.i16

; Stage event routines of the arcade (STAGE_CALLBACK). Bank 0 unless the
; comment gives a bank.
EVENT_WAVE1 = $87cf
EVENT_WAVE2 = $87d6
EVENT_WAVE3 = $87dd
EVENT_WAVE4_PAIR = $87e4     ; wave 4 with two players, else wave 5
EVENT_WAVE4 = $87f2
EVENT_WAVE5_PAIR = $87f9     ; wave 5 with two players
EVENT_WAVE5 = $8807
EVENT_CIRCLE_WAVE = $9a75    ; bank 0 and bank 6
EVENT_GIANT = $9b9a
EVENT_PAIR_WAVE = $aa5b      ; bank 6: two players only
EVENT_WAVE_DROP = $6ee3      ; fixed: the next wave carries a drop
STAGE_BANK_SIX = 24          ; STAGE_BANK of a bank 6 event

; stage_event: the event check of one update (flight_weapons): the FM
; lookahead hint and the air boss run first; when the camera allows events,
; the next event of the stage runs if its camera word is reached (the same
; high byte, a low byte at or below the scroll). JSR.
stage_event:
  jsl fm_stage_hint
  jsl game_airboss_tick
  lda CAMERA_EVENT_READY
  beq @done
  lda CAMERA_HOLD
  bne @done
  a16
  lda CAMERA_STAGE
  and #STAGES-1
  asl
  asl                           ; times STAGE_POINTER_SIZE
  tax
  lda f:STAGE_TABLE_POINTERS,x
  sta STAGE_POINTER
  a8
  lda f:STAGE_TABLE_POINTERS+2,x
  sta STAGE_POINTER+2
  ldy CAMERA_STAGE_OFFSET
  iny
  lda [STAGE_POINTER],y
  cmp CAMERA_BG1_SCROLL+1
  bne @done
  dey
  lda [STAGE_POINTER],y
  cmp CAMERA_BG1_SCROLL
  beq :+
  bcs @done
:
  iny
  iny
  a16
  lda [STAGE_POINTER],y
  tax
  lda f:STAGE_DESCRIPTORS+SD_CALLBACK,x
  sta STAGE_CALLBACK
  a8
  lda f:STAGE_DESCRIPTORS+SD_BANK,x
  sta STAGE_BANK
  lda f:STAGE_DESCRIPTORS+SD_CONTROL,x
  sta STAGE_CONTROL_INDEX
  a16
  lda CAMERA_STAGE_OFFSET
  clc
  adc #STAGE_EVENT_SIZE
  sta CAMERA_STAGE_OFFSET
  a8
  jmp stage_dispatch
@done:
  rts

; stage_dispatch: the handlers take the event in turn; each returns carry 1
; when it took it. Then the turrets, then the arcade callbacks of the plane
; waves, the giant and the wave drop. JMP from stage_event.
stage_dispatch:
  jsl game_airboss_event
  bcc :+
  rts
:
  jsl extended_spawn
  bcc :+
  rts
:
  jsl stage_control_run
  bcc :+
  rts
:
  jsl simple_spawn
  bcc :+
  rts
:
  jsl medium_spawn
  bcc :+
  rts
:
  jsl large_spawn
  bcc :+
  rts
:
  lda STAGE_CONTROL_INDEX
  cmp #CONTROL_TURRET_FIRST
  bcc @not_turret
  cmp #CONTROL_TURRET_END
  bcs @not_turret
  sec
  sbc #CONTROL_TURRET_FIRST
  sta TURRET_SPAWN_ID
  lda STAGE_GROUP_INDEX
  sta TURRET_GROUP
  lda STAGE_BOSS_PHASE
  sta TURRET_RETRY
  jsl turret_spawn
  lda TURRET_GROUP
  sta STAGE_GROUP_INDEX
  rts
@not_turret:
  ; The circle wave is also in bank 6.
  lda STAGE_BANK
  cmp #STAGE_BANK_SIX
  bne @fixed_bank
  a16
  lda STAGE_CALLBACK
  cmp #EVENT_CIRCLE_WAVE
  bne :+
  a8
  lda #WAVE_CIRCLE
  jmp stage_fighter
:
.a16
  cmp #EVENT_PAIR_WAVE
  bne :+
  a8
  ; The formation of two players only.
  lda PLAYER+PL_STATE
  beq @no_pair
  lda PLAYER2+PL_STATE
  beq @no_pair
  jsl game_pair_wave
@no_pair:
  stz WAVE_MODIFIER
  rts
:
  a8
@fixed_bank:
  lda STAGE_BANK
  beq :+
  jmp stage_unknown
:
  a16
  lda STAGE_CALLBACK
  cmp #EVENT_GIANT
  bne :+
  a8
  jsl game_giant_spawn
  rts
:
.a16
  cmp #EVENT_WAVE1
  bne :+
  a8
  lda #1                        ; WAVE_GROUP
  jmp stage_fighter
:
.a16
  cmp #EVENT_WAVE2
  bne :+
  a8
  lda #2                        ; WAVE_GROUP
  jmp stage_fighter
:
.a16
  cmp #EVENT_WAVE3
  bne :+
  a8
  lda #3                        ; WAVE_GROUP
  jmp stage_fighter
:
.a16
  cmp #EVENT_WAVE4_PAIR
  beq stage_four_conditional
  cmp #EVENT_WAVE4
  bne :+
  a8
  lda #4                        ; WAVE_GROUP
  jmp stage_fighter
:
.a16
  cmp #EVENT_WAVE5_PAIR
  beq stage_five_conditional
.a16
  cmp #EVENT_WAVE5
  bne :+
  a8
  lda #5                        ; WAVE_GROUP
  jmp stage_fighter
:
.a16
  cmp #EVENT_CIRCLE_WAVE
  bne :+
  a8
  lda #WAVE_CIRCLE
  jmp stage_fighter
:
.a16
  cmp #EVENT_WAVE_DROP
  bne :+
  a8
  lda #DROP_WAIT|7              ; PICKUP_KIND 7 with the last plane
  sta WAVE_MODIFIER
  rts
:
.a16
stage_unknown:
  a8
  rts
; stage_four_conditional, stage_five_conditional: wave 4 or 5 of the pair
; events (EVENT_WAVE4_PAIR, EVENT_WAVE5_PAIR): with two players only.
stage_four_conditional:
  a8
  lda #4                        ; WAVE_GROUP
  bra stage_both_players
stage_five_conditional:
  a8
  lda #5                        ; WAVE_GROUP
stage_both_players:
  pha
  lda PLAYER+PL_STATE
  beq @one_player
  lda PLAYER2+PL_STATE
  beq @one_player
  pla
  jmp stage_fighter
@one_player:
  pla
  stz WAVE_MODIFIER
  rts
; stage_fighter: the plane wave A (WAVE_GROUP).
stage_fighter:
.a8
  sta WAVE_GROUP
  jsr wave_spawn
  rts

; game_ground_shot_far: a ground bullet from the large object LARGE_RECORD
; at LARGE_AI_X, LARGE_AI_Y (large_ai). JSL entry in bank 0.
game_ground_shot_far:
.a8
  a16
  lda LARGE_RECORD
  sta POOL_RECORD
  a8
  jsr ground_bullet_spawn_direct
  lda LARGE_AI_X
  sta a:SPR_CROSS,x
  lda LARGE_AI_Y
  sta a:SPR_ALONG,x
  rtl

; airboss_shot_far: an aimed bullet of the air boss at MEDIUM_SHOT_ANGLE from
; LARGE_AI_X, LARGE_AI_Y, at bullet speed 1; BULLET_SPEED is kept. JSL.
airboss_shot_far:
.a8
  lda BULLET_SPEED
  pha
  lda #1
  sta BULLET_SPEED
  lda MEDIUM_SHOT_ANGLE
  sta BULLET_ANGLE
  jsr enemy_bullet_spawn_direct
  lda LARGE_AI_X
  sta a:SPR_CROSS,x
  lda LARGE_AI_Y
  sta a:SPR_ALONG,x
  pla
  sta BULLET_SPEED
  rtl
