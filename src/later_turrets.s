; Remaining four-piece ground batteries. D names the live head.
.a16
.i16
game_land_quad:
  lda LARGE_CALLBACK
  ldx #0
  cmp #$b68d
  beq @kind
  ldx #1
  cmp #$b813
  beq @kind
  ldx #2
@kind:
  stx TURRET_KIND
  sep #$20
  lda STAGE_FLAGS+$13
  beq @alive
  jmp .loword(game_ground_destroy)
@alive:
  lda $11
  beq :+
  dec $11
:
  jsl LARGE_TARGET
  lda TURRET_KIND
  cmp #1
  bne @turn
  lda PLAYER+5,y
  beq @p1
  lda TURRET_INPUT+1
  bra @input
@p1:
  lda TURRET_INPUT
@input:
  eor #255
  and #15
  rep #$20
  and #255
  tax
  sep #$20
  lda f:turret_input_angles,x
  cmp #255
  beq @turn
  sec
  sbc $16
  and #31
  beq @turn
  cmp #16
  beq @turn
  bcc @plus
  lda $16
  sec
  sbc #2
  bra @predicted
@plus:
  lda $16
  clc
  adc #2
@predicted:
  and #31
  sta $16
@turn:
  lda $16
  sec
  sbc $10
  and #31
  beq @aligned
  cmp #1
  beq @aligned
  cmp #31
  beq @aligned
  cmp #16
  bcc @increase
  lda $10
  sec
  sbc #2
  bra @angle
@increase:
  lda $10
  clc
  adc #2
@angle:
  and #31
  sta $10
  jmp .loword(@select)
@aligned:
  lda $11
  bne @select
  lda TURRET_KIND
  cmp #2
  beq @double
  cmp #1
  beq @fire
  lda RANDOM_STATE+5
  pha
  clc
  adc #$77
  sta RANDOM_STATE+5
  pla
  lsr
  bcc @select
@fire:
  lda #10
  sta $11
  lda TURRET_KIND
  inc
  sta TURRET_FIRE
  lda $10
  sta TURRET_ANGLE
  rep #$20
  and #31
  tax
  sep #$20
  lda f:turret_muzzles,x
  clc
  adc $02
  sta LARGE_AI_X
  lda f:turret_muzzles+1,x
  clc
  adc $03
  sta LARGE_AI_Y
  bra @select
@double:
  lda #11
  sta $11
  lda $10
  asl
  sta $12
  lda RANDOM_STATE
  pha
  clc
  adc #$77
  sta RANDOM_STATE
  pla
  and #7
  rep #$20
  and #255
  tax
  sep #$20
  lda f:game_double_speeds,x
  sta GROUND_SPEED
  jsr .loword(game_double_shot)
  inc $12
  inc $12
  jsr .loword(game_double_shot)
@select:
  rep #$20
  lda TURRET_KIND
  asl
  asl
  asl
  asl
  asl
  sta a:$d4
  lda $10
  and #31
  clc
  adc a:$d4
  tax
  lda f:game_land_quad_paths,x
  jmp .loword(large_ai_selected)

game_ground_destroy:
.a8
  lda STAGE_FLAGS+7
  sta $0e
  lda #16
  sta LARGE_AI_ACTION
  rep #$20
  lda #0
  jmp .loword(large_ai_selected)
game_double_speeds:
  .byte 18,14,18,10,10,18,18,14
game_double_shot:
.a8
  lda $10
  sta GROUND_ANGLE
  rep #$20
  lda $12
  and #63
  tax
  sep #$20
  lda f:game_double_muzzles,x
  clc
  adc $02
  sta LARGE_AI_X
  lda f:game_double_muzzles+1,x
  clc
  adc $03
  sta LARGE_AI_Y
  phd
  pea $0000
  pld
  jsl game_ground_shot_far
  pld
  rts

game_triple_quad:
.a16
  sep #$20
  lda $11
  beq :+
  dec $11
:
  lda STAGE_FLAGS+$13
  beq :+
  jmp .loword(game_ground_destroy)
:
  jsl LARGE_TARGET
  ldx #0
  cmp #15
  bcc @target
  inx
  cmp #18
  bcc @target
  inx
@target:
  stx a:$d4
  lda $10
  cmp a:$d4
  beq @aligned
  bcc @increase
  dec $10
  bra @select
@increase:
  inc $10
  bra @select
@aligned:
  lda $11
  bne @select
  lda #5
  sta $11
  lda #2
  sta $12
@shot:
  ; The three muzzles are visited right to left, angles low to high.
  rep #$20
  lda $10
  and #255
  sta a:$d4
  asl
  clc
  adc a:$d4
  asl
  sta a:$d4
  lda $12
  and #255
  asl
  adc a:$d4
  tax
  sep #$20
  lda f:game_triple_muzzles,x
  clc
  adc $02
  sta LARGE_AI_X
  lda f:game_triple_muzzles+1,x
  clc
  adc $03
  sta LARGE_AI_Y
  lda $10
  clc
  adc #6
  sec
  sbc $12
  sta TURRET_ANGLE
  jsr .loword(game_heavy_bullet)
  dec $12
  bpl @shot
@select:
  rep #$20
  lda $10
  and #255
  asl
  tax
  lda f:game_triple_quad_paths,x
  jmp .loword(large_ai_selected)

game_heavy_bullet:
.a8
  lda $01
  ora $41
  and #16
  bne @done
  lda $03
  cmp #40
  bcc @done
  lda BULLET_CONTEXT+1
  bne @done
  lda BULLET_CONTEXT+2
  beq @done
  rep #$20
  and #255
  asl
  asl
  asl
  asl
  asl
  clc
  adc #BULLETS
  sta a:$d0
  ldx #BULLETS
@slot:
  sep #$20
  lda a:8,x
  beq @found
  rep #$20
  txa
  clc
  adc #32
  tax
  cpx a:$d0
  bne @slot
  sep #$20
@done:
  rts
@found:
  rep #$20
  .repeat 16,I
    lda f:game_heavy_bullet_template+I*2
    sta a:I*2,x
  .endrepeat
  phx
  lda TURRET_ANGLE
  and #255
  asl
  tax
  lda f:game_heavy_bullet_paths,x
  plx
  sta a:$1e,x
  sep #$20
  lda LARGE_AI_X
  sta a:2,x
  lda LARGE_AI_Y
  sta a:3,x
  lda #$0c
  sta PLAYER_EVENT_SOUND
  rts
