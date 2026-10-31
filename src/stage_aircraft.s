; Native four-piece aircraft controllers. Tables contain prepared movement
; data; the arcade program is used only to specify behavior.
.a8
.i16
game_open_aircraft:
.a16
  sep #$20
  dec $11
  bne @select
  lda $12
  bne @closing
  lda $10
  inc
  cmp #4
  bne @phase
  lda #255
  sta $12
  lda #2
  bra @phase
@closing:
  lda $10
  dec
  cmp #255
  bne @phase
  stz $12
  lda #1
@phase:
  sta $10
  rep #$20
  and #255
  tax
  sep #$20
  lda f:game_open_delays,x
  sta $11
  lda $10
  beq @shoot
  cmp #3
  bne @select
@shoot:
  jsr .loword(game_aircraft_triple)
@select:
  rep #$20
  lda $10
  and #255
  sta a:$d4
  asl
  adc a:$d4
  tax
  sep #$20
  lda f:game_open_paths,x
  sta $09
  rep #$20
  lda f:game_open_paths+1,x
  jmp .loword(large_ai_selected)

game_weave_pause:
.a16
  sep #$20
  lda $12
  cmp #12
  beq @reverse
  inc $12
  bra game_weave_select
@reverse:
  lda $11
  eor #255
  sta $11
  stz $12
  bra game_weave_step
game_weave_aircraft:
.a16
  sep #$20
game_weave_step:
  lda $11
  bne @decrease
  inc $10
  bra @shoot
@decrease:
  dec $10
@shoot:
  lda $10
  cmp #3
  bne game_weave_select
  lda $03
  cmp #$60
  bcc game_weave_select
  jsr .loword(game_aircraft_triple)
game_weave_select:
.a8
  rep #$20
  lda $10
  and #255
  asl
  tax
  lda f:game_weave_paths,x
  jmp .loword(large_ai_selected)

; All three shots are allocated in arcade order: target, +2, -2.
; The existing bullet bridge owns bank-zero scratch and preserves D.
game_aircraft_triple:
.a8
  jsl LARGE_TARGET
  lda $02
  clc
  adc #8
  sta LARGE_AI_X
  lda $03
  sec
  sbc #8
  sta LARGE_AI_Y
  lda $16
  sta MEDIUM_SHOT_ANGLE
  phd
  pea $0000
  pld
  jsl game_large_spread_far
  pld
  lda $16
  clc
  adc #2
  and #31
  sta MEDIUM_SHOT_ANGLE
  phd
  pea $0000
  pld
  jsl game_large_spread_far
  pld
  lda $16
  sec
  sbc #2
  and #31
  sta MEDIUM_SHOT_ANGLE
  phd
  pea $0000
  pld
  jsl game_large_spread_far
  pld
  rts

game_fall_wait:
.a16
  sep #$20
  dec $10
  beq @fall
  dec $11
  bne @wait
  lda #2
  jsr .loword(game_fall_random_shot)
@wait:
  rep #$20
  lda #$af6b
  jmp .loword(large_ai_selected)
@fall:
  rep #$20
  lda #$af7c
  jmp .loword(large_ai_selected)
game_fall_fire:
.a16
  sep #$20
  lda #10
  jsr .loword(game_fall_random_shot)
  lda #16
  sta $11
  rep #$20
  lda #$af9b
  jmp .loword(large_ai_selected)
game_fall_enable:
.a16
  sep #$20
  lda #3
  sta $09
  bra game_fall_path
game_fall_tail:
.a16
  sep #$20
  dec $11
  bne game_fall_path
  lda #4
  jsr .loword(game_fall_random_shot)
game_fall_path:
.a8
  rep #$20
  lda #$afba
  jmp .loword(large_ai_selected)
game_fall_random_shot:
.a8
  sta a:$d4
  lda RANDOM_STATE
  pha
  clc
  adc #$55
  sta RANDOM_STATE
  pla
  and #15
  cmp a:$d4
  bcs @done
  jsr .loword(large_plane_shot)
  lda $03
  sta LARGE_AI_Y
@done:
  rts

game_large_burst:
.a16
  sep #$20
  lda $0e
  stz $0e
  cmp #2
  beq @two
  rep #$20
  lda #$5f33
  bra @next
@two:
  rep #$20
  lda #$5f74
@next:
  jmp .loword(large_ai_selected)

game_large_burst_loop:
.a16
  lda LARGE_CALLBACK
  cmp #$5f67
  beq @one
  lda #$5f74
  bra @path
@one:
  lda #$5f33
@path:
  tax
  sep #$20
  lda STAGE_FLAGS+$12
  rep #$20
  beq :+
  ldx #$5ee1
:
  txa
  jmp .loword(large_ai_selected)
game_carrier_destroy:
.a16
  sep #$20
  lda STAGE_FLAGS+$24
  beq :+
  inc LARGE_TOTAL
:
  lda #$1a
  sta LARGE_AI_SOUND
  rep #$20
  lda #$6623
  jmp .loword(large_ai_selected)
