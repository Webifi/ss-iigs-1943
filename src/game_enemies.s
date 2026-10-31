; Original US whole-stage formations and large aircraft. Copies only at spawn.
.a8
.i16
.segment "GAMEFLOW"
.include "stage_aircraft.s"
.include "later_aircraft.s"
.include "later_turrets.s"
.include "air_boss_data.inc"
.include "air_boss.s"
.include "air_boss_enemies.s"
.include "stage_raid.s"
.segment "GAMEPLAY"
game_pair_wave:
  stz WAVE_COUNTS+12
  rep #$20
  lda #8
  sta SIMPLE_LEFT
  stz SIMPLE_SLOT
  ldx #0
@find:
  sep #$20
  lda ENEMY_POOL+8,x
  beq @found
  rep #$20
  txa
  clc
  adc #32
  tax
  cpx #512
  bne @find
  sep #$20
  rtl
@found:
  stx SIMPLE_LIMIT
  rep #$20
  ldy #0
@copy:
  phx
  tyx
  lda f:game_pair_template,x
  plx
  sta ENEMY_POOL,x
  inx
  inx
  iny
  iny
  cpy #32
  bne @copy
  ldx SIMPLE_LIMIT
  sep #$20
  lda WAVE_MODIFIER
  sta ENEMY_POOL+$15,x
  lda SIMPLE_SLOT
  sta ENEMY_POOL+4,x
  clc
  adc #16
  sta SIMPLE_SLOT
  inc WAVE_COUNTS+12
  dec SIMPLE_LEFT
  bne @find
  rtl

game_giant_spawn:
  jsr .loword(giant_allocate)
  bcs :+
  rtl
:
  rep #$20
  stx LARGE_SPAWN_SLOT
  ldy #0
@copy:
  phx
  tyx
  lda f:game_giant_template,x
  plx
  sta LARGE_POOL,x
  inx
  inx
  iny
  iny
  cpy #32
  bne @copy
  ldx LARGE_SPAWN_SLOT
  sep #$20
  lda LARGE_POOL+1,x
  sta LARGE_POOL+$41,x
  sta LARGE_POOL+$101,x
  sta LARGE_POOL+$141,x
  lda LARGE_POOL+3,x
  sec
  sbc #16
  sta LARGE_POOL+$43,x
  sec
  sbc #16
  sta LARGE_POOL+$103,x
  sec
  sbc #16
  sta LARGE_POOL+$143,x
  rtl

; D is the live four-piece record, selected by large_ai.
game_quad_enable:
.a16
  sep #$20
  lda #3
  sta $09
  rep #$20
  lda #$ad8f
  jmp .loword(large_ai_selected)
game_quad_fire:
.a16
  sep #$20
  lda RANDOM_STATE+2
  and #7
  bne game_quad_tick8
  jsr .loword(large_plane_shot)
game_quad_tick8:
  rep #$20
game_quad_tick:
.a16
  sep #$20
  lda $12
  beq @turn
  dec $12
  jmp .loword(@select)
@turn:
  lda $10
  beq @target
  cmp #8
  bne @step
@target:
  jsl LARGE_TARGET
  lda $02
  sec
  sbc PLAYER+2,y
  bcs @right
  eor #255
  inc
  pha
  lda $10
  beq :+
  lda #0
  bra @direction
:
  lda #1
  bra @direction
@right:
  pha
  lda $10
  beq :+
  lda #1
  bra @direction
:
  lda #0
@direction:
  sta $14
  pla
  stz $11
  cmp #180
  bcc :+
  lda #3
  bra @delay
:
  cmp #60
  bcc :+
  lda #2
  bra @delay
:
  lda #0
@delay:
  sta $11
@step:
  lda $10
  pha
  lda $14
  beq @decrease
  pla
  inc
  bra @heading
@decrease:
  pla
  dec
@heading:
  and #15
  sta $10
  beq @zero
  cmp #8
  bne @ordinary
  lda #13
  bra @wait
@zero:
  lda $13
  bne @leave
  inc $13
  lda #13
  bra @wait
@leave:
  lda #255
  bra @wait
@ordinary:
  lda $11
@wait:
  sta $12
@select:
  rep #$20
  lda $10
  and #15
  asl
  tax
  lda f:game_quad_turns,x
  jmp .loword(large_ai_selected)

; Sixteen-piece aircraft phases, bank-zero $9BEE-$9F85.
game_giant_approach:
.a16
  ldx #$9c25
  sep #$20
  lda $03
  cmp #$70
  bne :+
  ldx #$9c44
:
  rep #$20
  txa
  jmp .loword(large_ai_selected)
game_giant_open:
.a16
  ldx #$9c44
  sep #$20
  lda $03
  cmp #$7c
  bne :+
  ldx #$9c63
:
  rep #$20
  txa
  jmp .loword(large_ai_selected)
game_giant_ready:
.a16
  ldx #$9c63
  sep #$20
  lda $03
  cmp #$88
  bne :+
  lda #3
  sta $09
  ldx #$9d8b
:
  rep #$20
  txa
  jmp .loword(large_ai_selected)
game_giant_reopen:
.a16
  sep #$20
  lda #3
  sta $09
  bra game_giant_select
game_giant_tick:
.a16
  sep #$20
  inc $11
  lda $11
  cmp #30
  beq @burst
  cmp #70
  beq @burst
  cmp #100
  beq @burst
  cmp #120
  bne @fire
  stz $11
@burst:
  jsl LARGE_TARGET
  cmp #13
  bcs :+
  lda #12
:
  cmp #20
  bcc :+
  lda #20
:
  sec
  sbc #4
  sta $14
  lda #5
  sta $13
@fire:
  lda $13
  beq game_giant_select
  jsl LARGE_TARGET
  lda $03
  sec
  sbc #32
  sec
  sbc PLAYER+3,y
  bcs :+
  eor #255
  inc
:
  cmp #32
  bcc game_giant_select
  lda PLAYER+2,y
  clc
  adc #16
  sec
  sbc $02
  bcc :+                     ; arcade $9CCB keeps a negative difference
  eor #255
  inc
:
  cmp #32
  bcc game_giant_select
  dec $13
  lda $14
  sta MEDIUM_SHOT_ANGLE
  inc $14
  inc $14
  lda #64
  sta LARGE_AI_ACTION
  lda $02
  sec
  sbc #8
  sta LARGE_AI_X
  lda $03
  sec
  sbc #48
  sta LARGE_AI_Y
game_giant_select:
.a8
  inc $12
  lda $12
  cmp #63
  bne :+
  stz $12
:
  rep #$20
  lda $12
  and #255
  asl
  tax
  lda f:game_giant_turns,x
  jmp .loword(large_ai_selected)
game_giant_hit:
.a16
  sep #$20
  lda $15
  cmp #2
  bne :+
  lda #$5f
  sta $17
:
  dec $15
  bne @survived
  lda #$1a
  sta LARGE_AI_SOUND
  rep #$20
  lda #$6623
  jmp .loword(large_ai_selected)
@survived:
.a8
  lda #8
  sta $0b
  rep #$20
  lda #$9f52
  jmp .loword(large_ai_selected)

; Original $76F7: the bonus plane is available with eight cabinet credits.
game_bonus_spawn:
.a8
  lda GAME_CREDITS
  cmp #8
  bcs :+
  rtl
:
  ldx #0
@find:
  lda ENEMY_POOL+8,x
  beq @copy
  rep #$20
  txa
  clc
  adc #32
  tax
  sep #$20
  cpx #512
  bne @find
  rtl
@copy:
  rep #$20
  ldy #0
@word:
  phx
  tyx
  lda f:game_bonus_template,x
  plx
  sta ENEMY_POOL,x
  inx
  inx
  iny
  iny
  cpy #32
  bne @word
  sep #$20
  rtl
