; Bank-six aiming turrets, original US $804B/$81C7/$8343/$84B7.
; D is the live four-piece head. Native target math is shared with fighters.
.a16
.i16
TURRET_KIND = $1c90
TURRET_INPUT = $1c92          ; original E250/E251, active-low P1/P2
TURRET_FIRE = $1c94           ; explicit request: speed class 1 or 2
TURRET_ANGLE = $1c95
ship_aiming_turret:
  lda LARGE_CALLBACK
  ldx #0
  cmp #$804b
  beq @kind
  ldx #1
  cmp #$81c7
  beq @kind
  ldx #2
  cmp #$8343
  beq @kind
  ldx #3
@kind:
  stx TURRET_KIND
  sep #$20
  stz TURRET_FIRE
  lda STAGE_FLAGS+$13
  beq @alive
  lda STAGE_FLAGS+7
  sta $0e
  lda #16
  sta LARGE_AI_ACTION
  rep #$20
  lda #0
  jmp .loword(large_ai_selected)
@alive:
.a8
  lda $11
  beq :+
  dec $11
:
  jsl LARGE_TARGET
  lda TURRET_KIND
  cmp #3
  bne @turn
  ; Predict the player's held direction, matching original $3166-$31AB.
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
  bcc @predict_plus
  lda $16
  sec
  sbc #2
  bra @predict_store
@predict_plus:
  lda $16
  clc
  adc #2
@predict_store:
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
  bra @select
@aligned:
  lda $11
  bne @select
  lda TURRET_KIND
  cmp #3
  beq @fire
  lda RANDOM_STATE
  pha
  clc
  adc #$77
  sta RANDOM_STATE
  pla
  lsr
  bcc @select
@fire:
  lda #9
  ldx TURRET_KIND
  bne :+
  lda #7
:
  sta $11
  lda #2
  cpx #0
  bne :+
  dec
:
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
  lda f:turret_aim_paths,x
  jmp .loword(large_ai_selected)
