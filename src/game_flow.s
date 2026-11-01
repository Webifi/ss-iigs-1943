; The cabinet flow: the coins and credits, the game over, the stage scenes
; (banners, intro, result) and the stage changes and departures.
.a8
.i16
.assert GAME_DIVE_ACTIVE = GAME_BG2_DISABLED+1, error, "dive counter layout"
COIN_SLOTS = 2
CREDITS_MAX = 9
BOSS_RESULT_TICKS = 2100          ; GAME_SEQUENCE_TICKS of the boss result and its raid
CAMERA_ARCADE_SIZE = 34      ; the arcade camera block; CAMERA_STAGE follows it
ENTRY_ALONG = $30            ; the players' along at the start of a stage
DEPART_STEP = 2              ; game_depart_players: the along step of a leaving player
DEPART_END = $f0             ; a leaving player is gone at this along

.assert DIP_B_COIN_B_SHIFT = 3 .and DIP_B_COIN_B = DIP_B_COIN_A<<3, error

; game_flow_init: the power-on cabinet state: the DIP switches of the
; settings, no coins or credits, the difficulty, then the cabinet. JSL.
game_flow_init:
  jsl native_input_dips
  stz GAME_TWO_PLAYERS
  stz GAME_COIN_A
  stz GAME_COIN_B
  stz GAME_CREDITS
  stz GAME_SEQUENCE
  stz GAME_STAGE_EXIT
  a16
  stz GAME_SEQUENCE_TICKS
  a8
  lda #INPUT_NONE
  sta GAME_INPUT_OLD
  jsr .loword(game_difficulty_init)
  jsl cabinet_init
  rtl

; game_flow_tick: one update of the cabinet (cabinet_frame): new coins give
; credits by the coin DIP switches (up to CREDITS_MAX) with SND_COIN; on a
; cabinet page the cabinet runs; when both players are out and done, the
; scores are kept and the title shows. JSL.
game_flow_tick:
  lda INPUT_SYSTEM
  eor #$ff                      ; the system inputs pressed now (active low)
  and GAME_INPUT_OLD
  sta SYSTEM_PRESSED
  lda INPUT_SYSTEM
  sta GAME_INPUT_OLD
  ldx #0
@coins:
  lda SYSTEM_PRESSED
  and #SYSTEM_COIN1
  cpx #0
  beq :+
  lda SYSTEM_PRESSED
  and #SYSTEM_COIN2
:
  ora #0                        ; test A again after the CPX
  beq @coin_next
  lda GAME_DIP_B
  cpx #0
  beq :+
  lsr
  lsr
  lsr                           ; coin slot B: DIP_B_COIN_B_SHIFT
:
  a16
  and #DIP_B_COIN_A             ; and B = 0
  tay
  a8
  inc GAME_COIN_A,x
  lda GAME_COIN_A,x
  phx
  tyx
  cmp f:cabinet_coin_required,x
  plx
  bcc @coin_next
  stz GAME_COIN_A,x
  lda GAME_CREDITS
  cmp #CREDITS_MAX
  bcs @coin_next                ; the arcade gives no sound at the cap
  clc
  phx
  tyx
  adc f:cabinet_coin_awarded,x
  plx
  cmp #CREDITS_MAX+1
  bcc :+
  lda #CREDITS_MAX
:
  sta GAME_CREDITS
  lda #SND_COIN
  jsl game_sound_request
  lda GAME_FLOW
  cmp #CAB_PAGE_FIRST
  bcs @title_preload
  lda CAB_DEMO
  beq @coin_next
@title_preload:
  jsl audio_title_preload_request
@coin_next:
  inx
  cpx #COIN_SLOTS
  bne @coins
@state:
  lda GAME_FLOW
  cmp #CAB_PAGE_FIRST
  bcc @playing
  jmp .loword(cabinet_tick)
@playing:
  lda GAME_OUT
  cmp #OUT_P1|OUT_P2
  bne @done
  lda CAB_LIVE_STATE
  ora CAB_LIVE_STATE+1
  bne @done                   ; each player's initials finish independently
  lda PLAYER+PL_STATE
  ora PLAYER2+PL_STATE
  bne @done
  jsl cabinet_save_scores
  lda #PAGE_TITLE
  jsl cabinet_select
@done:
  rtl

; game_scene_tick: the scene of this update (59.637 Hz): the stage exit (the
; retry, the ending or the result), the departure of the players, then the
; banner task (GAME_SEQUENCE = STAGE_BANNER_TASK): a banner (its text starts
; here; game_banner_tick types it), the intro, or the boss result with its
; raid for BOSS_RESULT_TICKS. JSL.
game_scene_tick:
.a8
  lda CAB_RESULT_ACTIVE
  beq :+
  rtl
:
  lda GAME_STAGE_EXIT
  beq :+
  cmp #EXIT_RETRY
  bne @not_retry
  jsl game_stage_retry
  rtl
@not_retry:
  cmp #EXIT_ENDING
  bne @stage_result
  jsl cabinet_ending
  rtl
@stage_result:
  jsl game_stage_result
  rtl
:
  lda STAGE_PLAYER_REQUEST
  cmp #PS_DIVE
  beq @depart
  cmp #PS_LEAVE
  bne @banner
@depart:
  jsr .loword(game_depart_players)
@banner:
  lda STAGE_BANNER_TASK
  cmp GAME_SEQUENCE
  beq @same
  sta GAME_SEQUENCE
  a16
  stz GAME_SEQUENCE_TICKS
  a8
  stz STAGE_RAID_WAIT
  cmp #SEQ_BANNER
  bne @same
  lda BANNER_LAYOUT
  jsl cabinet_text_select
  rtl
@same:
  lda GAME_SEQUENCE
  cmp #SEQ_INTRO
  beq @intro
  cmp #SEQ_RESULT
  beq @result
  rtl                           ; none, or SEQ_BANNER
@intro:
  jmp .loword(native_intro_tick)
@result:
  jsl game_raid_tick
  a16
  inc GAME_SEQUENCE_TICKS
  lda GAME_SEQUENCE_TICKS
  cmp #BOSS_RESULT_TICKS
  bcc @wait16
  stz CAMERA_BG1_GATE
  a8
  stz STAGE_BANNER_TASK
  stz STAGE_BOSS_HOLD
  rtl
@wait16:
  a8
  rtl

; game_next_stage: the next stage: the stage state, the camera and the
; objects are cleared; the players in the game start at ENTRY_ALONG. After
; the last stage the ending starts. Score, credits, weapon and energy stay.
; JSL.
game_next_stage:
.a8
  jsl special_reset_stage
  stz SPECIAL_TIMER
  jsl native_dive_reset
  stz AIR_BOSS
  stz AIR_LIFE
  stz AIR_RESULT
  stz AIR_PERCENT
  stz GAME_STAGE_EXIT
  inc CAMERA_STAGE
  lda CAMERA_STAGE
  cmp #STAGES
  bcc @next
  jsl cabinet_ending
  rtl
@next:
  a16
  ldx #CAMERA_ARCADE_SIZE-2
@camera:
  stz CAMERA,x
  dex
  dex
  bpl @camera
  lda #DECK_SCROLL
  sta CAMERA_BG1_SCROLL
  ldx #EXTENDED_POOL-ENEMY_POOL-2 ; with BULLETS and LARGE_POOL
@objects:
  stz ENEMY_POOL,x
  dex
  dex
  bpl @objects
  ldx #SHOT_COUNT*SHOT_SIZE-2
@shots:
  stz SHOTS,x
  dex
  dex
  bpl @shots
  ldx #EXTENDED_COUNT*OBJECT_SIZE-2
@extended:
  stz EXTENDED_POOL,x
  dex
  dex
  bpl @extended
  ldx #STAGE_FLAGS_SIZE-2
@flags:
  stz STAGE_FLAGS,x
  dex
  dex
  bpl @flags
  a8
  stz CAMERA_PAN_ON
  stz CAMERA_EVENT_READY
  stz STAGE_BOSS_COUNT
  stz GAME_SEQUENCE
  lda #1
  sta CAMERA_BG2_DIVISOR
  stz GAME_DEPART_MODE
  stz GAME_DEPART_DONE
  ldx #0
@player_entry:
  lda PLAYER+PL_STATE,x
  beq @next_player
  cmp #PS_DEATH
  beq @next_player
  lda #ENTRY_ALONG
  sta PLAYER+SPR_ALONG,x
  sta PLAYER+PL_BODY2+SPR_ALONG,x
  lda #PS_LIVE
  sta PLAYER+PL_STATE,x
  stz PLAYER+PL_WEAPON_GATE,x
@next_player:
  cpx #PLAYER_SIZE
  beq :+
  ldx #PLAYER_SIZE
  bra @player_entry
:
  jsl stage_flow_init
  jsl large_loop_init
  rtl

; game_depart_players: the departure STAGE_PLAYER_REQUEST (A): PS_DIVE puts
; each live player into the dive (one that enters or dies later joins);
; else each player in the game moves along DEPART_STEP each update until
; DEPART_END. When both are done: PS_LEAVE ends the stage (EXIT_RESULT),
; else the players come back to ENTRY_ALONG. A player out or dead does not
; hold the other. JSR.
game_depart_players:
.a8
  cmp #PS_DIVE
  bne @ordinary_departure
  sta GAME_DEPART_MODE
  lda PLAYER+PL_STATE
  cmp #PS_LIVE
  bne @dive_second
  lda PLAYER2+PL_STATE
  beq @dive_first
  cmp #PS_LIVE
  beq @dive_both
  lda STAGE_FINISH
  beq @dive_second
@dive_first:
  lda #PS_DIVE
  sta PLAYER+PL_STATE
@dive_second:
  lda PLAYER2+PL_STATE
  cmp #PS_LIVE
  bne @dive_started
  lda PLAYER+PL_STATE
  beq @dive_second_apply
  lda STAGE_FINISH
  beq @dive_started
@dive_second_apply:
  lda #PS_DIVE
  sta PLAYER2+PL_STATE
  bra @dive_started
@dive_both:
  lda #PS_DIVE
  sta PLAYER+PL_STATE
  sta PLAYER2+PL_STATE
@dive_started:
  rts
@ordinary_departure:
  cmp GAME_DEPART_MODE
  beq :+
  sta GAME_DEPART_MODE
  stz GAME_DEPART_DONE
:
  ldx #0
  lda #1
  sta DEPART_BIT
@player:
  lda GAME_DEPART_DONE
  and DEPART_BIT
  bne @next
  lda PLAYER+PL_STATE,x
  beq @finished
  cmp #PS_DEATH
  beq @finished
  lda GAME_DEPART_MODE
  sta PLAYER+PL_STATE,x
  lda PLAYER+SPR_ALONG,x
  clc
  adc #DEPART_STEP
  sta PLAYER+SPR_ALONG,x
  sta PLAYER+PL_BODY2+SPR_ALONG,x
  cmp #DEPART_END
  bcc @next
@finished:
  lda GAME_DEPART_DONE
  ora DEPART_BIT
  sta GAME_DEPART_DONE
@next:
  cpx #PLAYER_SIZE
  beq @both
  ldx #PLAYER_SIZE
  asl DEPART_BIT
  bra @player
@both:
  lda GAME_DEPART_DONE
  cmp #%11                      ; both players
  bne @done
  lda GAME_DEPART_MODE
  cmp #PS_LEAVE
  bne @return_to_flight
  lda #EXIT_RESULT
  sta GAME_STAGE_EXIT
  rts
@return_to_flight:
  stz STAGE_PLAYER_REQUEST
  stz GAME_DEPART_MODE
  stz CAMERA_BG1_GATE
  stz CAMERA_BG1_GATE+1
  ldx #0
@restore:
  lda PLAYER+PL_STATE,x
  cmp #PS_DIVE
  bne @restore_next
  lda #ENTRY_ALONG
  sta PLAYER+SPR_ALONG,x
  sta PLAYER+PL_BODY2+SPR_ALONG,x
  lda #PS_LIVE
  sta PLAYER+PL_STATE,x
@restore_next:
  cpx #PLAYER_SIZE
  beq @done
  ldx #PLAYER_SIZE
  bra @restore
@done:
  rts

.include "stage_result.s"

; game_present_result: show the stage result (cabinet_stage_result) from
; the result the rules chose already. CAB_RESULT_DATA: the stage, AIR_RESULT,
; AIR_PERCENT, the band (1 for each 10 above 60 percent; 6 more for a
; replay), the refill, RESULT_REMAIN, GAME_CONTINUE_LEVEL, 1 for a retry.
; JSL.
game_present_result:
.a8
  lda CAMERA_STAGE
  sta CAB_RESULT_DATA+CRD_STAGE
  lda AIR_RESULT
  sta CAB_RESULT_DATA+CRD_RESULT
  lda AIR_PERCENT
  sta CAB_RESULT_DATA+CRD_PERCENT
  ldx #0
  lda AIR_RESULT
  bne @band_done
  lda AIR_PERCENT
  sec
  sbc #PASS_BAND_FIRST
  bcc @band_done
@band:
  inx
  sec
  sbc #PASS_BAND_STEP
  bcs @band
@band_done:
  txa
  sta CAB_RESULT_DATA+CRD_BAND
  lda STAGE_BOSS_PHASE
  beq :+
  lda CAB_RESULT_DATA+CRD_BAND
  clc
  adc #REPLAY_BANDS
  sta CAB_RESULT_DATA+CRD_BAND
:
  jsr .loword(game_refill_index)
  lda f:game_refill,x
  sta CAB_RESULT_DATA+CRD_ENERGY
  lda RESULT_REMAIN
  sta CAB_RESULT_DATA+CRD_REFILL
  lda GAME_CONTINUE_LEVEL
  sta CAB_RESULT_DATA+CRD_LEVEL
  stz CAB_RESULT_DATA+CRD_FLAGS
  lda GAME_STAGE_EXIT
  cmp #EXIT_RETRY
  bne :+
  inc CAB_RESULT_DATA+CRD_FLAGS
:
  ldx #CAB_RESULT_DATA
  jsl cabinet_stage_result
  rtl
