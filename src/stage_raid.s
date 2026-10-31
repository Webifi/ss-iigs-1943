; The original thirty-second reinforcement raid after a ship escapes.
; Spawn choices, turn timing and paths are prepared ROM data.
.a8
.i16
game_raid_tick:
  rep #$20
  lda GAME_SEQUENCE_TICKS
  cmp #1800
  sep #$20
  bcc :+
  rtl
:
  lda STAGE_FLAGS+$23
  beq @ready
  dec STAGE_FLAGS+$23
  rtl
@ready:
  jsr .loword(giant_allocate)
  bcs :+
  rtl
:
  lda RANDOM_STATE+7
  pha
  clc
  adc #$77
  sta RANDOM_STATE+7
  pla
  and #3
  asl
  tax
  rep #$20
  lda f:game_raid_spawns,x
  sta STAGE_CALLBACK
  sep #$20
  stz STAGE_BANK
  lda #254
  sta STAGE_CONTROL_INDEX
  jsl extended_spawn
  lda #60
  sta STAGE_FLAGS+$23
  inc STAGE_DAMAGE_THRESHOLD
  rtl

; D selects the sixteen-piece aircraft, as in the other large callbacks.
game_raid_giant:
.a16
  sep #$20
  lda $14
  beq @timer
  cmp #1
  beq @turn_left
  lda $10
  inc
  bra @heading
@turn_left:
  lda $10
  dec
@heading:
  and #31
  sta $10
  bne @timer
  stz $14
  lda #255
  sta $11
  bra @select
@timer:
  dec $11
  bne @select
  rep #$20
  lda $12
  and #255
  tax
  sep #$20
  lda $15
  beq @left_steps
  lda f:game_raid_steps+28,x
  bra @step
@left_steps:
  lda f:game_raid_steps+14,x
@step:
  sta $14
  lda f:game_raid_steps,x
  sta $11
  dec $12
  bmi @lap
  lda $12
  cmp #11
  beq @children
  cmp #5
  bne @select
@children:
  lda RANDOM_STATE+4
  clc
  adc #$55
  sta RANDOM_STATE+4
  and #1
  bne @select
  lda $01
  and #16
  bne @select
  lda #0
  jsr .loword(game_carrier_child_spawn)
  lda #1
  jsr .loword(game_carrier_child_spawn)
  bra @select
@lap:
  dec $13
  beq @depart
  lda #13
  sta $12
  bra @select
@depart:
  lda #255
  sta $11
  lda $15
  beq :+
  lda #1
  bra @mode
:
  lda #2
@mode:
  sta $14
@select:
  rep #$20
  lda $10
  and #31
  asl
  tax
  lda f:game_raid_paths,x
  jmp .loword(large_ai_selected)
