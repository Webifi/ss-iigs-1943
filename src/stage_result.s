; The stage result: the outcome of the ship or the air boss, the retry, the
; energy refill and the score awards. The tables are build data.
.a8
.i16
DIFFICULTY_ENTRY_SIZE = 4    ; game_difficulty: bullets, speed, spawns, air pass
TALLY_TICKS = 2              ; updates of each refill step
REFILL_ENTRY_SIZE = 3        ; game_refill: ENERGY_MAX, the refill, the refill of a replay
PASS_BAND_FIRST = 60         ; the award band: 1 for each 10 above 60 percent
PASS_BAND_STEP = 10
REPLAY_BANDS = 6             ; a replay uses the bands after these
AWARD_100 = 23               ; score_awards: 100 points
AWARD_40000 = 40             ; score_awards: two times 20000 points
RETRY_SEA = $1000            ; CAMERA_BG2_SCROLL of a retry
RETRY_ALONG = $10            ; the players start the retry here
DECK_ALONG_P2 = $40          ; the deck place of player 2 (player 1: DOCK_ALONG)

; game_difficulty_init: the difficulty of the DIP switches: STAGE_DIP_LEVEL
; and its game_difficulty entry. JSR.
game_difficulty_init:
  lda GAME_DIP_A
  eor #$ff
  and #DIP_A_LEVEL
  sta STAGE_DIP_LEVEL
  asl
  asl                           ; times DIFFICULTY_ENTRY_SIZE
  a16
  and #255
  tax
  a8
  lda f:game_difficulty,x
  sta STAGE_BULLET_BASE
  sta STAGE_BULLET_SLOTS
  lda f:game_difficulty+1,x
  sta STAGE_SPEED_BASE
  lda f:game_difficulty+2,x
  sta STAGE_SPAWN_SLOTS
  lda f:game_difficulty+3,x
  sta STAGE_AIR_PASS
  rts

; game_stage_result: the end of a stage (game_scene_tick, EXIT_RESULT):
; the outcome (the ship result, except on the air boss stages); a failed
; first pass or last stage is a retry; the last stage goes to the ending;
; else the refill tally starts (EXIT_REFILL), with the awards of a pass.
; JSL.
game_stage_result:
  lda GAME_STAGE_EXIT
  cmp #EXIT_REFILL
  bne @begin
  jmp .loword(game_refill_tick)
@begin:
  lda CAMERA_STAGE
  cmp #AIR_STAGE_1
  beq @outcome
  cmp #AIR_STAGE_2
  beq @outcome
  cmp #AIR_STAGE_3
  beq @outcome
  jsr .loword(game_ship_result)
@outcome:
  jsr .loword(game_result_clear)
  lda AIR_RESULT
  cmp #AR_RETRY
  bne @award
  lda CAMERA_STAGE
  cmp #LAST_STAGE
  beq @retry
  lda STAGE_BOSS_PHASE
  bne @award
@retry:
  stz RESULT_REMAIN
  lda #EXIT_RETRY
  sta GAME_STAGE_EXIT
  jsl game_present_result
  rtl
@award:
  lda CAMERA_STAGE
  cmp #LAST_STAGE
  bne :+
  stz RESULT_REMAIN
  lda #EXIT_ENDING
  sta GAME_STAGE_EXIT
  jsl game_present_result
  rtl
:
  lda #EXIT_REFILL
  sta GAME_STAGE_EXIT
  stz RESULT_REMAIN
  a16
  lda #TALLY_TICKS
  sta RESULT_TICKS
  a8
  jsr .loword(game_refill_index)
  lda f:game_refill,x
  sta ENERGY_MAX
  lda AIR_RESULT
  bne @done
  inx
  lda STAGE_BOSS_PHASE
  beq :+
  inx
:
  lda f:game_refill,x
  sta RESULT_REMAIN
  ldx #0
  lda AIR_PERCENT
  sec
  sbc #PASS_BAND_FIRST
  bcc @points
@band:
  inx
  sec
  sbc #PASS_BAND_STEP
  bcs @band
@points:
  lda STAGE_BOSS_PHASE
  beq :+
  txa
  clc
  adc #REPLAY_BANDS
  tax
:
  lda f:game_result_awards,x
  jsr .loword(game_award_both)
@done:
  jsl game_present_result
  rtl

; game_result_deck: when the refill page starts after the outcome, the
; players stand docked on the carrier deck; their controls are off
; (PS_LEAVE) while the bonus counts. JSL.
game_result_deck:
.a8
.i16
  phx
  a16
  lda #DECK_SCROLL
  sta CAMERA_BG1_SCROLL
  stz CAMERA_BG2_SCROLL
  a8
  ldx #0
@deck:
  lda PLAYER+PL_STATE,x
  beq @next_player
  cmp #PS_DEATH
  beq @next_player
  lda #PS_LEAVE
  sta PLAYER+PL_STATE,x
  lda #DOCKED_CODE
  sta PLAYER,x
  inc
  sta PLAYER+PL_BODY2+SPR_CODE,x
  stz PLAYER+SPR_ATTR,x
  stz PLAYER+PL_BODY2+SPR_ATTR,x
  lda #DOCK_CROSS
  sta PLAYER+SPR_CROSS,x
  lda #DOCK_CROSS+BODY2_CROSS
  sta PLAYER+PL_BODY2+SPR_CROSS,x
  lda #DOCK_ALONG
  cpx #0
  beq :+
  lda #DECK_ALONG_P2
:
  sta PLAYER+SPR_ALONG,x
  sta PLAYER+PL_BODY2+SPR_ALONG,x
@next_player:
  cpx #PLAYER_SIZE
  beq @done
  ldx #PLAYER_SIZE
  bra @deck
@done:
  plx
  rtl

; game_ship_result: AIR_PERCENT of a ship stage: 100 when the core is down,
; else the damage of the boss parts (LARGE_TOTAL of LARGE_THRESHOLD, by
; game_damage_percent); below STAGE_AIR_PASS it fails (AR_RETRY, or
; AR_FAILED when the result repeats). JSR.
game_ship_result:
  stz AIR_RESULT                ; AR_PASS
  lda STAGE_CORE_DOWN
  bne @complete
  lda LARGE_TOTAL
  beq @percent
  cmp LARGE_THRESHOLD
  bcc @ratio
@complete:
  lda #100
  bra @percent
@ratio:
  ; QUOTIENT = LARGE_TOTAL * 256 / LARGE_THRESHOLD (8 bits).
  a16
  and #255
  sta DIVIDEND
  lda LARGE_THRESHOLD
  and #255
  sta DIVISOR
  stz QUOTIENT
  ldx #8
@divide:
  asl DIVIDEND
  lda DIVIDEND
  cmp DIVISOR
  bcc :+
  sbc DIVISOR
  sta DIVIDEND
:
  rol QUOTIENT
  dex
  bne @divide
  ldx QUOTIENT
  a8
  lda f:game_damage_percent,x
@percent:
  sta AIR_PERCENT
  cmp STAGE_AIR_PASS
  bcs @done
  lda #AR_RETRY
  sta AIR_RESULT
  lda STAGE_RESULT_REPEAT
  beq @done
  lda #AR_FAILED
  sta AIR_RESULT
@done:
  rts

; game_refill_index: X = the game_refill entry of the stage. JSR.
game_refill_index:
  a16
  lda CAMERA_STAGE
  and #STAGES-1
  sta REFILL_STAGE
  asl
  adc REFILL_STAGE              ; times REFILL_ENTRY_SIZE
  tax
  a8
  rts

; game_refill_tick: one update of the refill (EXIT_REFILL): every
; TALLY_TICKS one more energy to each player in the game (up to ENERGY_MAX),
; or 100 points for a full one, with SND_TALLY, RESULT_REMAIN times. Then
; the continue awards, GAME_CONTINUE_LEVEL again, and the next stage. JSL.
game_refill_tick:
  a16
  dec RESULT_TICKS
  a8
  beq :+
  rtl
:
  lda #TALLY_TICKS
  sta RESULT_TICKS
  lda RESULT_REMAIN
  beq @finished
  dec RESULT_REMAIN
  jsr .loword(game_refill_index)
  lda f:game_refill,x
  sta REFILL_ENERGY
  ldx #0
@player:
  lda PLAYER+PL_STATE,x
  beq @next
  cmp #PS_DEATH
  beq @next
  lda PLAYER+PL_ENERGY,x
  cmp REFILL_ENERGY
  bcs @points
  inc PLAYER+PL_ENERGY,x
  phx
  jsl player_energy_hud_far
  plx
  bra @next
@points:
  lda #1                        ; SCORE_OWNER: the player number
  cpx #0
  beq :+
  inc
:
  sta SCORE_OWNER
  lda #AWARD_100
  sta SCORE_AWARD_INDEX
  phx
  jsl large_score_far
  plx
@next:
  cpx #PLAYER_SIZE
  beq @sound
  ldx #PLAYER_SIZE
  bra @player
@sound:
  lda #SND_TALLY
  jsl game_sound_request
  rtl
@finished:
  a16
  lda GAME_CONTINUE_LEVEL
  and #255
  tax
  a8
  lda f:game_continue_awards,x
  jsr .loword(game_award_both)
  lda GAME_CONTINUE_LEVEL
  cmp #CONTINUE_LEVEL_MAX
  bne :+
  lda #AWARD_40000
  jsr .loword(game_award_both)
:
  lda #CONTINUE_START
  sta GAME_CONTINUE_LEVEL
  jsl special_sync_shadow
  lda PLAYER+PL_STATE
  beq @count
  lda PLAYER2+PL_STATE
  beq @count
  lda #CONTINUE_LEVEL_MAX       ; two players
  sta GAME_CONTINUE_LEVEL
  jsl special_sync_shadow
@count:
  jsl game_next_stage
  rtl

; game_award_both: the award A (score_awards) to each player in the game. JSR.
game_award_both:
  sta SCORE_AWARD_INDEX
  lda #1
  sta SCORE_OWNER
  lda PLAYER+PL_STATE
  beq :+
  jsl large_score_far
:
  lda #2
  sta SCORE_OWNER
  lda PLAYER2+PL_STATE
  beq :+
  jsl large_score_far
:
  rts

; game_result_clear: no objects, shots, boss or ship finish. JSR.
game_result_clear:
  a16
  ldx #POOLS_END-ENEMY_POOL-2
@enemies:
  stz ENEMY_POOL,x
  dex
  dex
  bpl @enemies
  ldx #SHOT_COUNT*SHOT_SIZE-2
@shots:
  stz SHOTS,x
  dex
  dex
  bpl @shots
  a8
  stz STAGE_BOSS_COUNT
  stz SHIP_FINISH_ACTIVE
  rts

; game_stage_retry: the stage again (EXIT_RETRY): its retry event
; (game_retry_events), the scroll stage * $800, the players enter again at
; RETRY_ALONG, SND_RESULT_MUSIC. JSL.
game_stage_retry:
  a16
  lda CAMERA_STAGE
  and #STAGES-1
  asl
  tax
  lda f:game_retry_events,x
  sta CAMERA_STAGE_OFFSET
  txa
  xba
  asl
  asl                           ; stage * 2 * 256 * 4
  sta CAMERA_BG1_SCROLL
  lda #RETRY_SEA
  sta CAMERA_BG2_SCROLL
  stz CAMERA_BG2_GATE
  stz CAMERA_BG1_GATE
  a8
  stz CAMERA_BG2_DIVISOR
  stz CAMERA_BG1_DIVISOR
  stz GAME_STAGE_EXIT
  stz STAGE_PLAYER_REQUEST
  stz GAME_DEPART_MODE
  stz STAGE_BANNER_TASK
  stz GAME_SEQUENCE
  ldx #0
@player:
  lda PLAYER+PL_STATE,x
  beq @next
  cmp #PS_DEATH
  beq @next
  lda #PS_RESPAWN
  sta PLAYER+PL_STATE,x
  lda #RETRY_ALONG
  sta PLAYER+SPR_ALONG,x
  sta PLAYER+PL_BODY2+SPR_ALONG,x
  stz PLAYER+PL_WEAPON_GATE,x
@next:
  cpx #PLAYER_SIZE
  beq @done
  ldx #PLAYER_SIZE
  bra @player
@done:
  lda #SND_RESULT_MUSIC
  jsl game_sound_request
  rtl
