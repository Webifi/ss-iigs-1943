; Live cabinet controls and continue state. No recorded player state.
.a8
.i16
GAME_BG2_DISABLED = $17fd     ; trailer $7BCE bit 0; no other flags
GAME_DIVE_ACTIVE = $17fe      ; number of players with transient dive pieces
.assert GAME_DIVE_ACTIVE = GAME_BG2_DISABLED+1, error, "dive counter layout"
GAME_FLOW = $1490
GAME_CREDITS = $1491
GAME_INPUT_OLD = $1492
GAME_SECONDS = $1493
GAME_SECOND_WAIT = $1494
GAME_TWO_PLAYERS = $14e2
GAME_DIP_A = $14e3
GAME_DIP_B = $14e4
GAME_COIN_A = $14e5
GAME_COIN_B = $14e6

game_flow_init:
  lda #$f8
  sta GAME_DIP_A
  lda #$ff
  sta GAME_DIP_B
  jsl native_input_demo_sound
  stz GAME_TWO_PLAYERS
  stz GAME_COIN_A
  stz GAME_COIN_B
  stz GAME_CREDITS
  stz GAME_SECONDS
  stz GAME_SEQUENCE
  stz GAME_STAGE_EXIT
  rep #$20
  stz GAME_SEQUENCE_TICKS
  sep #$20
  lda #255
  sta GAME_INPUT_OLD
  jsr .loword(game_difficulty_init)
  jsl cabinet_init
  rtl

game_flow_tick:
  lda INPUT_SYSTEM
  eor #255
  and GAME_INPUT_OLD
  sta $d0
  lda INPUT_SYSTEM
  sta GAME_INPUT_OLD
  ldx #0
@coins:
  lda $d0
  and #$40
  cpx #0
  beq :+
  lda $d0
  and #$80
:
  ora #0
  beq @coin_next
  lda GAME_DIP_B
  cpx #0
  beq :+
  lsr
  lsr
  lsr
:
  rep #$20
  and #7                       ; zero-extend the DIP index; B is caller scratch
  tay
  sep #$20
  inc GAME_COIN_A,x
  lda GAME_COIN_A,x
  phx
  tyx
  cmp f:cabinet_coin_required,x
  plx
  bcc @coin_next
  stz GAME_COIN_A,x
  lda GAME_CREDITS
  cmp #9
  bcs @coin_next               ; the arcade gives no cue at the credit cap
  clc
  phx
  tyx
  adc f:cabinet_coin_awarded,x
  plx
  cmp #10
  bcc :+
  lda #9
:
  sta GAME_CREDITS
  lda #$12
  jsl game_sound_request
  lda GAME_FLOW
  cmp #3
  bcs @title_preload
  lda CAB_DEMO
  beq @coin_next
@title_preload:
  jsl audio_title_preload_request
@coin_next:
  inx
  cpx #2
  bne @coins
@state:
  lda GAME_FLOW
  cmp #3
  bcc @playing
  jmp .loword(cabinet_tick)
@playing:
  lda GAME_OUT
  cmp #3
  bne @done
  lda CAB_LIVE_STATE
  ora CAB_LIVE_STATE+1
  bne @done                   ; each player's initials finish independently
  lda PLAYER+8
  ora PLAYER+$88
  bne @done
  jsl cabinet_save_scores
  lda #4
  jsl cabinet_select
@done:
  rtl

; Native presentation tasks advance in the game's 59.637 Hz logic ticks.
GAME_SEQUENCE = $1496
GAME_SEQUENCE_TICKS = $1498
GAME_STAGE_EXIT = $149a

game_scene_tick:
.a8
  lda CAB_RESULT_ACTIVE
  beq :+
  rtl
:
  lda GAME_STAGE_EXIT
  beq :+
  cmp #3
  bne @not_retry
  jsl game_stage_retry
  rtl
@not_retry:
  cmp #4
  bne @stage_result
  jsl cabinet_ending
  rtl
@stage_result:
  jsl game_stage_result
  rtl
:
  lda STAGE_FLAGS+9
  cmp #8
  beq @depart
  cmp #12
  bne @banner
@depart:
  jsr .loword(game_depart_players)
@banner:
  lda STAGE_BANNER_TASK
  cmp GAME_SEQUENCE
  beq @same
  sta GAME_SEQUENCE
  rep #$20
  stz GAME_SEQUENCE_TICKS
  sep #$20
  stz STAGE_FLAGS+$23
@same:
  lda GAME_SEQUENCE
  bne :+
  rtl
:
  cmp #1
  bne :+
  stz STAGE_BANNER_TASK
  rtl
:
  cmp #4
  beq @intro
  cmp #2
  beq @result
  rep #$20
  inc GAME_SEQUENCE_TICKS
  lda GAME_SEQUENCE_TICKS
  cmp #180
  sep #$20
  bcc @done
  stz STAGE_BANNER_TASK
@done:
  rtl
@intro:
  jmp .loword(native_intro_tick)
@result:
  jsl game_raid_tick
  rep #$20
  inc GAME_SEQUENCE_TICKS
  lda GAME_SEQUENCE_TICKS
  cmp #2100
  bcc @wait16
  stz CAMERA+$15
  sep #$20
  stz STAGE_BANNER_TASK
  stz STAGE_FLAGS+$24
  rtl
@wait16:
  sep #$20
  rtl

; Stage transitions start from native state and the next ROM event table.
; Score, credits, the current weapon and player energy survive the flight.
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
  cmp #16
  bcc @next
  jsl cabinet_ending
  rtl
@next:
  rep #$20
  ldx #32
@camera:
  stz CAMERA,x
  dex
  dex
  bpl @camera
  lda #$d500
  sta CAMERA+$0f
  ldx #$9fe
@objects:
  stz ENEMY_POOL,x
  dex
  dex
  bpl @objects
  ldx #18*32-2
@shots:
  stz SHOTS,x
  dex
  dex
  bpl @shots
  ldx #17*32-2
@extended:
  stz EXTENDED_POOL,x
  dex
  dex
  bpl @extended
  ldx #$3e
@flags:
  stz STAGE_FLAGS,x
  dex
  dex
  bpl @flags
  sep #$20
  stz CAMERA_PAN_ON
  stz CAMERA_EVENT_READY
  stz STAGE_EVENTS
  stz STAGE_BOSS_COUNT
  stz GAME_SEQUENCE
  lda #1
  sta CAMERA+2
  stz GAME_DEPART_MODE
  stz GAME_DEPART_DONE
  ldx #0
@player_entry:
  lda PLAYER+8,x
  beq @next_player
  cmp #4
  beq @next_player
  lda #$30
  sta PLAYER+3,x
  sta PLAYER+$23,x
  lda #2
  sta PLAYER+8,x
  stz PLAYER+$55,x
@next_player:
  cpx #128
  beq :+
  ldx #128
  bra @player_entry
:
  jsl stage_flow_init
  jsl large_loop_init
  rtl

.ifdef GAME_TEST_STAGE
; Off in the normal game. Keep the development-only selector with cold flow
; code, rather than consuming the native renderer/input loop's tight segment.
game_test_stage_dispatch:
.a8
  rep #$20
  lda STAGE_CALLBACK
  cmp #$46da
  sep #$20
  bne @ordinary
  lda CAMERA_STAGE
  bne @ordinary
  jsl game_test_stage_start
  sec
  rtl
@ordinary:
  clc
  rtl

; No saved state and no injected event/camera fields.
game_test_stage_start:
.a8
  lda #GAME_TEST_STAGE-2
  sta CAMERA_STAGE
  jsl game_next_stage
  rtl
.endif

; Both pilots complete departure independently. An out/dead pilot does not
; block the survivor, and the next stage never grants an unpaid revival.
GAME_DEPART_DONE = $149b
GAME_DEPART_MODE = $149c
game_depart_players:
.a8
  cmp #8
  bne @ordinary_departure
  sta GAME_DEPART_MODE
  ; Apply a pending scene request when a player becomes active. A pilot may
  ; still be entering or finishing a death when the request first arrives.
  lda PLAYER+8
  cmp #2
  bne @dive_second
  lda PLAYER+$88
  beq @dive_first
  cmp #2
  beq @dive_both
  lda STAGE_FLAGS+$10
  beq @dive_second
@dive_first:
  lda #8
  sta PLAYER+8
@dive_second:
  lda PLAYER+$88
  cmp #2
  bne @dive_started
  lda PLAYER+8
  beq @dive_second_apply
  lda STAGE_FLAGS+$10
  beq @dive_started
@dive_second_apply:
  lda #8
  sta PLAYER+$88
  bra @dive_started
@dive_both:
  lda #8
  sta PLAYER+8
  sta PLAYER+$88
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
  sta $d4
@player:
  lda GAME_DEPART_DONE
  and $d4
  bne @next
  lda PLAYER+8,x
  beq @finished
  cmp #4
  beq @finished
  lda GAME_DEPART_MODE
  sta PLAYER+8,x
  lda PLAYER+3,x
  clc
  adc #2
  sta PLAYER+3,x
  sta PLAYER+$23,x
  cmp #$f0
  bcc @next
@finished:
  lda GAME_DEPART_DONE
  ora $d4
  sta GAME_DEPART_DONE
@next:
  cpx #128
  beq @both
  ldx #128
  asl $d4
  bra @player
@both:
  lda GAME_DEPART_DONE
  cmp #3
  bne @done
  lda GAME_DEPART_MODE
  cmp #12
  bne @return_to_flight
  lda #1
  sta GAME_STAGE_EXIT
  rts
@return_to_flight:
  stz STAGE_FLAGS+9
  stz GAME_DEPART_MODE
  stz CAMERA+$15
  stz CAMERA+$16
  ldx #0
@restore:
  lda PLAYER+8,x
  cmp #8
  bne @restore_next
  lda #$30
  sta PLAYER+3,x
  sta PLAYER+$23,x
  lda #2
  sta PLAYER+8,x
@restore_next:
  cpx #128
  beq @done
  ldx #128
  bra @restore
@done:
  rts

.include "stage_result.s"

; The rules have already selected the outcome and the awards. Only their
; presentation is deferred; no second gameplay calculation is performed.
game_present_result:
.a8
  lda CAMERA_STAGE
  sta CAB_RESULT_DATA
  lda AIR_RESULT
  sta CAB_RESULT_DATA+1
  lda AIR_PERCENT
  sta CAB_RESULT_DATA+2
  ldx #0
  lda AIR_RESULT
  bne @band_done
  lda AIR_PERCENT
  sec
  sbc #60
  bcc @band_done
@band:
  inx
  sec
  sbc #10
  bcs @band
@band_done:
  txa
  sta CAB_RESULT_DATA+3
  lda STAGE_BOSS_PHASE
  beq :+
  lda CAB_RESULT_DATA+3
  clc
  adc #6
  sta CAB_RESULT_DATA+3
:
  jsr .loword(game_refill_index)
  lda f:game_refill,x
  sta CAB_RESULT_DATA+4
  lda RESULT_REMAIN
  sta CAB_RESULT_DATA+5
  lda GAME_CONTINUE_LEVEL
  sta CAB_RESULT_DATA+6
  stz CAB_RESULT_DATA+7
  lda GAME_STAGE_EXIT
  cmp #3
  bne :+
  inc CAB_RESULT_DATA+7
:
  ldx #CAB_RESULT_DATA
  jsl cabinet_stage_result
  rtl
