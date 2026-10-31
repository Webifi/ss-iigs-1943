; More original-US single-piece decisions. Each chooses prepared movement data.
.a8
.i16
formation_extra:
.a8
.ifdef CONTINUOUS_GAME
  jsl airboss_enemy_ai
  bcc :+
  rtl
:
.endif
  rep #$20
  lda ENEMY+10
  and #$70
  beq @zero
.a16
  cmp #$60
  beq @six
@unknown:
  sep #$20
  clc
  rtl
@zero:
.a16
  lda AI_CONTEXT+2
  cmp #$99c9
  bne :+
  sep #$20
  jmp .loword(formation_carrier_child)
:
.a16
.a16
  cmp #$8497
  bne :+
  sep #$20
  jmp .loword(formation_returning)
:
.a16
  cmp #$93d6
  bne :+
  sep #$20
  jmp .loword(formation_interval)
:
.a16
  cmp #$9729
  bne @unknown
  sep #$20
  jmp .loword(formation_crossing)
@six:
.a16
  lda AI_CONTEXT+2
  .macro later_formation id, target
    cmp #id
    bne :+
    sep #$20
    jmp .loword(target)
:
.a16
  .endmacro
  later_formation $a153, formation_sweep
  later_formation $ade8, formation_pair_sweep
  later_formation $a3fe, formation_cross_pattern
  later_formation $a75e, formation_edge_pattern
  later_formation $9e11, formation_fan_wait
  later_formation $9e22, formation_fan_turn
  .delmacro later_formation
.a16
  cmp #$9010
  bne :+
  sep #$20
  jmp .loword(formation_edge_first)
:
.a16
  cmp #$9019
  bne :+
  sep #$20
  jmp .loword(formation_edge_second)
:
.a16
  cmp #$902c
  bne :+
  sep #$20
  jmp .loword(formation_edge_turn)
:
.a16
  cmp #$b48f
  bne :+
  sep #$20
  jmp .loword(formation_strafing)
:
.a16
  cmp #$b4d6
  beq :+
  jmp .loword(@unknown)
:
  sep #$20
  lda #2
  jsr .loword(formation_strafe_fire)
  rep #$20
  lda ENEMY+$12
  and #255
  beq :+
  lda #$b61c
  bra formation_extra_path
:
  lda #$b634
formation_extra_path:
.a16
  sta AI_NEXT
  sep #$20
  sec
  rtl
formation_extra_table:
.a8
.a8
  rep #$20
  and #31
  asl
  clc
  adc $d8
  tax
  lda f:formation_paths,x
  bra formation_extra_path

formation_returning:
.a8
  lda ENEMY+$10
  bne @turn
  lda ENEMY+2
  cmp #$31
  bcc @outside
  cmp #$d0
  bcs @outside
  lda ENEMY+3
  cmp #$31
  bcc @outside
  cmp #$d0
  bcs @outside
  stz ENEMY+$12
  bra @select
@outside:
  lda ENEMY+$12
  bne @select
  lda ENEMY+$11
  cmp #6
  bcs @select
  lda #1
  sta ENEMY+$10
  sta ENEMY+$12
  jsl FORMATION_TARGET
  sec
  sbc ENEMY+$13
  and #31
  cmp #16
  lda #0
  bcc :+
  inc
:
  sta ENEMY+$14
@turn:
  lda ENEMY+$13
  ldx ENEMY+$14
  txa
  and #255
  beq @increase
  lda ENEMY+$13
  dec
  bra @heading
@increase:
  lda ENEMY+$13
  inc
@heading:
  and #31
  sta ENEMY+$13
  jsl FORMATION_TARGET
  cmp ENEMY+$13
  bne @select
  stz ENEMY+$10
  jsr .loword(formation_fire)
  inc ENEMY+$11
@select:
  rep #$20
  lda #4*64
  sta $d8
  sep #$20
  lda ENEMY+$13
  jmp .loword(formation_extra_table)

; $3144's heading update, without changing the caller's $14 field.
formation_turn_only:
.a8
  lda ENEMY+$14
  pha
  jsr .loword(formation_aim_turn)
  pla
  sta ENEMY+$14
  rts
formation_interval:
.a8
  lda ENEMY+$11
  beq @turn
  cmp #3
  bne :+
  jsr .loword(formation_fire)
:
  dec ENEMY+$11
  bra @select
@turn:
  lda ENEMY+$12
  sta ENEMY+$11
  jsr .loword(formation_turn_only)
@select:
  lda #5
  sta FORMATION_TYPE
  jmp .loword(formation_select)

formation_cross_fire:
.a8
  lda RANDOM_STATE+1
  pha
  clc
  adc #$77
  sta RANDOM_STATE+1
  pla
  and #1
  beq :+
  jsr .loword(formation_fire)
:
  rts
formation_crossing:
.a8
  lda ENEMY+$12
  bne @arc
  lda ENEMY+$11
  bne @left
  lda ENEMY+2
  cmp #$90
  bcs @right_start
  jsl FORMATION_TARGET
  lda ENEMY+2
  cmp PLAYER+2,y
  bcc @right_path
@right_start:
  jsr .loword(formation_cross_fire)
  lda #1
  sta ENEMY+$12
@right_path:
  rep #$20
  lda #$985f
  jmp .loword(formation_extra_path)
@left:
.a8
  lda ENEMY+2
  cmp #$60
  bcc @left_start
  jsl FORMATION_TARGET
  lda ENEMY+2
  cmp PLAYER+2,y
  bcs @left_path
@left_start:
  jsr .loword(formation_cross_fire)
  lda #1
  sta ENEMY+$12
@left_path:
  rep #$20
  lda #$98e7
  jmp .loword(formation_extra_path)
@arc:
.a8
  lda ENEMY+$13
  beq @step
  dec ENEMY+$13
  bra @select
@step:
  lda #1
  sta ENEMY+$13
  lda ENEMY+$11
  bne :+
  inc ENEMY+$10
  bra @select
:
  dec ENEMY+$10
@select:
  lda #6
  sta FORMATION_TYPE
  jmp .loword(formation_select)

formation_edge_first:
.a8
  lda RANDOM_STATE+1
  clc
  adc #$42
  sta RANDOM_STATE+1
  and #15
  bne :+
  jsr .loword(formation_fire)
:
  rep #$20
  lda #$90df
  jmp .loword(formation_extra_path)
formation_edge_second:
.a8
  lda RANDOM_STATE
  clc
  adc #$13
  sta RANDOM_STATE
  and #15
  cmp #7
  bcs :+
  jsr .loword(formation_fire)
:
  rep #$20
  lda ENEMY+$12
  and #255
  beq :+
  lda #$915c
  jmp .loword(formation_extra_path)
:
  lda #$90e9
  jmp .loword(formation_extra_path)
formation_edge_turn:
.a8
.a8
  lda ENEMY+$11
  cmp #9
  bcs @select
  inc ENEMY+$11
  jsr .loword(formation_turn_only)
@select:
  lda #7
  sta FORMATION_TYPE
  jmp .loword(formation_select)

formation_strafe_fire:
.a8
  sta FORMATION_ODDS
  lda RANDOM_STATE+1
  clc
  adc #$13
  sta RANDOM_STATE+1
  and #15
  cmp FORMATION_ODDS
  bcs :+
  jsr .loword(formation_fire)
:
  rts
formation_strafing:
.a8
  lda ENEMY+$11
  beq @leaving
  dec ENEMY+$11
  lda ENEMY+$13
  bne :+
  lda #255
  sta ENEMY+$13
  lda #8
  jsr .loword(formation_strafe_fire)
:
  jsl FORMATION_TARGET
  lda PLAYER+3,y
  cmp ENEMY+3
  bcs @leaving
  rep #$20
  lda ENEMY+$12
  and #255
  beq :+
  lda #$b54f
  jmp .loword(formation_extra_path)
:
  lda #$b514
  jmp .loword(formation_extra_path)
@leaving:
.a8
  lda #4
  jsr .loword(formation_strafe_fire)
  rep #$20
  lda ENEMY+$12
  and #255
  beq :+
  lda #$b58a
  jmp .loword(formation_extra_path)
:
  lda #$b5d3
  jmp .loword(formation_extra_path)

.segment "GAMEFLOW"
; Timed formations use native counters and build-prepared heading tables.
formation_sweep:
.a8
  lda #0
  bra formation_sweep_common
formation_pair_sweep:
.a8
  lda #1
formation_sweep_common:
.a8
  sta FORMATION_TYPE
  lda ENEMY+$11
  beq @change
  dec ENEMY+$11
  bra @select
@change:
  rep #$20
  lda ENEMY+$12
  and #255
  tax
  sep #$20
  inc ENEMY+$12
  inc ENEMY+$12
  lda FORMATION_TYPE
  bne @pair
  lda f:game_sweep_sequence,x
  sta ENEMY+$11
  lda f:game_sweep_sequence+1,x
  bra @heading
@pair:
  lda f:game_pair_sweep_sequence,x
  sta ENEMY+$11
  lda f:game_pair_sweep_sequence+1,x
@heading:
  sta ENEMY+$10
@select:
  rep #$20
  lda ENEMY+$10
  and #31
  asl
  tax
  sep #$20
  lda FORMATION_TYPE
  bne @pair_path
  rep #$20
  lda f:game_sweep_paths,x
  jmp .loword(formation_extra_path)
@pair_path:
  rep #$20
  lda f:game_pair_sweep_paths,x
  jmp .loword(formation_extra_path)

formation_cross_pattern:
.a8
  lda #0
  bra formation_delta_pattern
formation_edge_pattern:
.a8
  lda #1
formation_delta_pattern:
.a8
  sta FORMATION_TYPE
  rep #$20
  lda ENEMY+$11
  and #255
  tax
  sep #$20
  inc ENEMY+$11
  lda FORMATION_TYPE
  bne @edge
  lda f:game_cross_deltas,x
  bra @sign
@edge:
  lda f:game_edge_deltas,x
@sign:
  sta $d4
  lda ENEMY+$12
  lsr
  lda $d4
  bcs @add
  eor #255
  inc
@add:
  clc
  adc ENEMY+$10
  and #31
  sta ENEMY+$10
  rep #$20
  and #255
  asl
  tax
  sep #$20
  lda FORMATION_TYPE
  bne @edge_path
  rep #$20
  lda f:game_cross_paths,x
  jmp .loword(formation_extra_path)
@edge_path:
  rep #$20
  lda f:game_edge_paths,x
  jmp .loword(formation_extra_path)

formation_fan_wait:
.a8
  dec ENEMY+$11
  beq @turn
  rep #$20
  lda #$9e99
  jmp .loword(formation_extra_path)
@turn:
  rep #$20
  lda #$9eaa
  jmp .loword(formation_extra_path)
formation_fan_turn:
.a8
  lda ENEMY+$11
  beq @step
  dec ENEMY+$11
  bra @path
@step:
  inc ENEMY+$10
  lda ENEMY+$12
  sta ENEMY+$11
@path:
  rep #$20
  lda ENEMY+$10
  and #255
  asl
  tax
  sep #$20
  lda ENEMY+$13
  lsr
  bcs @right
  rep #$20
  lda f:game_fan_left_paths,x
  jmp .loword(formation_extra_path)
@right:
  rep #$20
  lda f:game_fan_right_paths,x
  jmp .loword(formation_extra_path)

.segment "GAMEPLAY"

.segment "GAMEFLOW"
formation_carrier_child:
.a8
  lda ENEMY+$11
  cmp #64
  bcs @select
  inc ENEMY+$11
  jsr .loword(formation_aim_turn)
@select:
  rep #$20
  lda ENEMY+$10
  and #31
  asl
  tax
  lda f:game_carrier_child_paths,x
  jmp .loword(formation_extra_path)
.segment "GAMEPLAY"
