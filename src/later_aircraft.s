; Native controllers for the later-stage aircraft. Prepared paths retain the
; arcade art/motion data; allocation and decisions run as 65816 operations.
.a8
.i16
game_sway_aircraft:
.a16
  sep #$20
  lda $12
  beq @down
  cmp #1
  beq @pause
  dec $11
  bne @up_step
  jsl LARGE_TARGET
  lda $03
  cmp PLAYER+3,y
  bcc @shoot
  lda RANDOM_STATE+1
  pha
  clc
  adc #$55
  sta RANDOM_STATE+1
  pla
  bne @pause_up
@shoot:
  lda STAGE_DIFFICULTY+7
  cmp #9
  bcc @single
  jsr .loword(game_aircraft_triple)
  bra @pause_up
@single:
  jsr .loword(large_plane_shot)
@pause_up:
  stz $13
  jsr .loword(game_sway_pause)
@up_step:
  inc $10
  bra @select
@down:
  dec $11
  bne @down_step
  lda #1
  sta $13
  jsr .loword(game_sway_pause)
@down_step:
  dec $10
  bra @select
@pause:
  dec $11
  bne @select
  lda #12
  sta $11
  stz $12
  dec $13
  bne @select
  lda #2
  sta $12
@select:
  rep #$20
  lda $10
  and #31
  asl
  tax
  lda f:game_sway_quad_paths,x
  jmp .loword(large_ai_selected)
game_sway_pause:
.a8
  lda #3
  sta $11
  lda #1
  sta $12
  rts

game_turning_aircraft:
.a16
  sep #$20
  lda $12
  beq @approach
  cmp #1
  beq @turn
  dec $11
  bne @select
  lda #1
  jsr .loword(game_turn_random)
  lda #255
  sta $11
  bra @select
@approach:
  dec $11
  bne @select
  dec $14
  beq @begin
  lda #1
  sta $14
  jsr .loword(game_turn_random)
  lda #5
  sta $11
  bra @select
@begin:
  lda #1
  sta $12
  lda #32
  sta $11
  stz $14
  bra @select
@turn:
  lda $13
  beq @plus
  lda $10
  dec
  bra @heading
@plus:
  lda $10
  inc
@heading:
  and #31
  sta $10
  dec $11
  bne @maybe_fire
  lda #6
  sta $11
  lda #2
  sta $12
  bra @select
@maybe_fire:
  and #7
  cmp #4
  bne @select
  lda $14
  beq @three
  cmp #3
  beq @three
  lda #4
  bra @chance
@three:
  lda #3
@chance:
  jsr .loword(game_turn_random)
@select:
  rep #$20
  lda $10
  and #31
  asl
  tax
  lda f:game_turning_quad_paths,x
  jmp .loword(large_ai_selected)
game_turn_random:
.a8
  sta a:$d6
  lda RANDOM_STATE+1
  pha
  clc
  adc #$55
  sta RANDOM_STATE+1
  pla
  and #15
  cmp a:$d6
  bcs @done
  jsr .loword(large_plane_shot)
@done:
  rts

game_carrier_giant:
.a16
  sep #$20
  lda $12
  cmp #1
  beq @pause
  dec $11
  bne @moving
  lda #11
  sta $11
  lda $12
  lsr
  sta $13
  pha
  lda #1
  sta $12
  pla
  beq @up_no_fire
  lda $10
  dec
  bra @store
@up_no_fire:
  lda $10
  inc
@store:
  and #31
  sta $10
  bra @select
@moving:
  lda $12
  beq @up
  lda $10
  dec
  bra @fire_heading
@up:
  lda $10
  inc
@fire_heading:
  and #31
  sta $10
  bne @select
  lda $14
  beq @armed
  lda $01
  and #16
  bne @armed
  lda #0
  jsr .loword(game_carrier_child_spawn)
  lda #1
  jsr .loword(game_carrier_child_spawn)
@armed:
  inc $14
  bra @select
@pause:
  dec $11
  bne @select
  lda #12
  sta $11
  stz $12
  dec $13
  beq @select
  lda #2
  sta $12
@select:
  rep #$20
  lda $10
  and #31
  asl
  tax
  lda f:game_carrier_giant_paths,x
  jmp .loword(large_ai_selected)

game_carrier_child_spawn:
.a8
  pha
  phd
  pea $0000
  pld
  jsr .loword(extended_allocate)
  pld
  pla
  bcs :+
  rts
:
  sta a:$d6
  rep #$20
  .repeat 16,I
    lda f:game_carrier_child_template+I*2
    sta a:I*2,x
  .endrepeat
  sep #$20
  lda $03
  sec
  sbc #16
  sta a:3,x
  lda a:$d6
  cmp #1
  beq @right
  lda $02
  sec
  sbc #16
  sta a:2,x
  rts
@right:
  lda $02
  sta a:2,x
  lda #1
  sta a:$10,x
  rep #$20
  lda #$9a49
  sta a:$1e,x
  sep #$20
@done:
  rts
