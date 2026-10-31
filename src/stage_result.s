; Native stage outcome, retry and awards. The tables are prepared at build time.
.a8
.i16
RESULT_TICKS = $149d
RESULT_REMAIN = $149f

game_difficulty_init:
  lda GAME_DIP_A
  eor #255
  and #15
  sta STAGE_DIFFICULTY+7
  asl
  asl
  rep #$20
  and #255
  tax
  sep #$20
  lda f:game_difficulty,x
  sta STAGE_DIFFICULTY
  sta STAGE_DIFFICULTY+4
  lda f:game_difficulty+1,x
  sta STAGE_DIFFICULTY+1
  lda f:game_difficulty+2,x
  sta STAGE_DIFFICULTY+2
  sta STAGE_DIFFICULTY+6
  lda f:game_difficulty+3,x
  sta STAGE_DIFFICULTY+3
  rts

game_stage_result:
  lda GAME_STAGE_EXIT
  cmp #2
  bne @begin
  jmp .loword(game_refill_tick)
@begin:
  lda CAMERA_STAGE
  cmp #2
  beq @outcome
  cmp #8
  beq @outcome
  cmp #13
  beq @outcome
  jsr .loword(game_ship_result)
@outcome:
  jsr .loword(game_result_clear)
  lda AIR_RESULT
  cmp #1
  bne @award
  lda CAMERA_STAGE
  cmp #15
  beq @retry
  lda STAGE_BOSS_PHASE
  bne @award
@retry:
  stz RESULT_REMAIN
  lda #3
  sta GAME_STAGE_EXIT
  jsl game_present_result
  rtl
@award:
  lda CAMERA_STAGE
  cmp #15
  bne :+
  stz RESULT_REMAIN
  lda #4
  sta GAME_STAGE_EXIT
  jsl game_present_result
  rtl
:
  lda #2
  sta GAME_STAGE_EXIT
  stz RESULT_REMAIN
  rep #$20
  lda #2
  sta RESULT_TICKS
  sep #$20
  jsr .loword(game_refill_index)
  lda f:game_refill,x
  sta CONTACT_CONTEXT
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
  sbc #60
  bcc @points
@band:
  inx
  sec
  sbc #10
  bcs @band
@points:
  lda STAGE_BOSS_PHASE
  beq :+
  txa
  clc
  adc #6
  tax
:
  lda f:game_result_awards,x
  jsr .loword(game_award_both)
@done:
  jsl game_present_result
  rtl

; The outcome belongs over the completed stage. Change to the carrier only
; when the outcome has finished and the statistics/refill page begins.
game_result_deck:
.a8
.i16
  phx
  rep #$20
  lda #$d500
  sta CAMERA+$0f
  stz CAMERA
  sep #$20
  ldx #0
@deck:
  lda PLAYER+8,x
  beq @next_player
  cmp #4
  beq @next_player
  lda #12                    ; lock controls while the deck bonus counts
  sta PLAYER+8,x
  lda #$4a
  sta PLAYER,x
  inc
  sta PLAYER+$20,x
  stz PLAYER+1,x
  stz PLAYER+$21,x
  lda #$68
  sta PLAYER+2,x
  lda #$78
  sta PLAYER+$22,x
  lda #$50
  cpx #0
  beq :+
  lda #$40
:
  sta PLAYER+3,x
  sta PLAYER+$23,x
@next_player:
  cpx #128
  beq @done
  ldx #128
  bra @deck
@done:
  plx
  rtl

game_ship_result:
  stz AIR_RESULT
  lda STAGE_FLAGS+$12
  bne @complete
  lda LARGE_TOTAL
  beq @percent
  cmp LARGE_THRESHOLD
  bcc @ratio
@complete:
  lda #100
  bra @percent
@ratio:
  rep #$20
  and #255
  sta $d8
  lda LARGE_THRESHOLD
  and #255
  sta $da
  stz $d4
  ldx #8
@divide:
  asl $d8
  lda $d8
  cmp $da
  bcc :+
  sbc $da
  sta $d8
:
  rol $d4
  dex
  bne @divide
  ldx $d4
  sep #$20
  lda f:game_damage_percent,x
@percent:
  sta AIR_PERCENT
  cmp STAGE_DIFFICULTY+3
  bcs @done
  lda #1
  sta AIR_RESULT
  lda STAGE_FLAGS+$25
  beq @done
  lda #3
  sta AIR_RESULT
@done:
  rts

game_refill_index:
  rep #$20
  lda CAMERA_STAGE
  and #15
  sta $d4
  asl
  adc $d4
  tax
  sep #$20
  rts

game_refill_tick:
  rep #$20
  dec RESULT_TICKS
  sep #$20
  beq :+
  rtl
:
  lda #2
  sta RESULT_TICKS
  lda RESULT_REMAIN
  beq @finished
  dec RESULT_REMAIN
  jsr .loword(game_refill_index)
  lda f:game_refill,x
  sta $d6
  ldx #0
@player:
  lda PLAYER+8,x
  beq @next
  cmp #4
  beq @next
  lda PLAYER+6,x
  cmp $d6
  bcs @points
  inc PLAYER+6,x
  phx
  jsl player_energy_hud_far
  plx
  bra @next
@points:
  lda #1
  cpx #0
  beq :+
  inc
:
  sta SCORE_OWNER
  lda #23                    ; existing 100-point digit vector
  sta SCORE_AWARD_INDEX
  phx
  jsl large_score_far
  plx
@next:
  cpx #128
  beq @sound
  ldx #128
  bra @player
@sound:
  lda #$0b
  jsl game_sound_request
  rtl
@finished:
  rep #$20
  lda GAME_CONTINUE_LEVEL
  and #255
  tax
  sep #$20
  lda f:game_continue_awards,x
  jsr .loword(game_award_both)
  lda GAME_CONTINUE_LEVEL
  cmp #4
  bne :+
  lda #40                    ; 40000 = two existing 20000-point vectors
  jsr .loword(game_award_both)
:
  lda #2
  sta GAME_CONTINUE_LEVEL
  jsl special_sync_shadow
  lda PLAYER+8
  beq @count
  lda PLAYER+$88
  beq @count
  lda #4
  sta GAME_CONTINUE_LEVEL
  jsl special_sync_shadow
@count:
  jsl game_next_stage
  rtl

game_award_both:
  sta SCORE_AWARD_INDEX
  lda #1
  sta SCORE_OWNER
  lda PLAYER+8
  beq :+
  jsl large_score_far
:
  lda #2
  sta SCORE_OWNER
  lda PLAYER+$88
  beq :+
  jsl large_score_far
:
  rts

game_result_clear:
  rep #$20
  ldx #$c1e
@enemies:
  stz ENEMY_POOL,x
  dex
  dex
  bpl @enemies
  ldx #18*32-2
@shots:
  stz SHOTS,x
  dex
  dex
  bpl @shots
  sep #$20
  stz STAGE_BOSS_COUNT
  stz SHIP_FINISH_ACTIVE
  rts

game_stage_retry:
  rep #$20
  lda CAMERA_STAGE
  and #15
  asl
  tax
  lda f:game_retry_events,x
  sta CAMERA+$11
  txa
  xba
  asl
  asl
  sta CAMERA+$0f
  lda #$1000
  sta CAMERA
  stz CAMERA+4
  stz CAMERA+$15
  sep #$20
  stz CAMERA+2
  stz CAMERA+$13
  stz GAME_STAGE_EXIT
  stz STAGE_FLAGS+9
  stz STAGE_FLAGS+11
  stz GAME_DEPART_MODE
  stz STAGE_BANNER_TASK
  stz GAME_SEQUENCE
  ldx #0
@player:
  lda PLAYER+8,x
  beq @next
  cmp #4
  beq @next
  lda #6
  sta PLAYER+8,x
  lda #$10
  sta PLAYER+3,x
  sta PLAYER+$23,x
  stz PLAYER+$55,x
@next:
  cpx #128
  beq @done
  ldx #128
  bra @player
@done:
  lda #$2d
  jsl game_sound_request
  rtl
