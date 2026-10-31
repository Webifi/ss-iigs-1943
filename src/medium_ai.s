; Native US bank-zero homing and diving fighter decisions. Called with the
; same live record as enemy_ai; the build makes a direct-page pool version.
.a8
.i16
.ifndef MEDIUM_TARGET
MEDIUM_TARGET = ai_target_far
.endif
MEDIUM_RANDOM = $1c70        ; original E00C, supplied by the logic tick

medium_ai:
  rep #$20
  lda AI_CONTEXT+2
  cmp #$8054
  bne :+
  jmp .loword(medium_home)
:
  cmp #$80d8
  bne :+
  jmp .loword(medium_fire)
:
  cmp #$8eba
  bne :+
  jmp .loword(medium_dive)
:
  cmp #$8ee8
  bne :+
  jmp .loword(medium_turn)
:
  cmp #$8f21
  bne :+
  sep #$20
  lda ENEMY+$10
  beq :+
  lda #5
  bra medium_loop_begin
:
  rep #$20
  lda AI_CONTEXT+2
  cmp #$8f35
  bne :+
  sep #$20
  lda ENEMY+$10
  beq medium_loop_short
  lda #6
  bra medium_loop_begin
:
  .a16
  cmp #$8f21
  bne :+
  sep #$20
  bra medium_loop_short
:
  .a16
  cmp #$8f60
  bne :+
  jmp .loword(medium_loop)
:
  cmp #$8f8c
  bne :+
  jmp .loword(medium_hold)
:
  cmp #$90e0
  bne :+
  jmp .loword(medium_return)
:
  cmp #$8fbe
  bne @unknown
  sep #$20
  lda MEDIUM_RANDOM
  bmi medium_continue
  jsl MEDIUM_TARGET
  lda #1
  sta AI_FIRE
  bra medium_continue
@unknown:
  sep #$20
  clc
  rtl

medium_loop_short:
.a8
  lda #4
medium_loop_begin:
  sta ENEMY+$10
  rep #$20
  lda MEDIUM_RANDOM
  and #3
  tax
  sep #$20
  lda f:medium_delays,x
  sta ENEMY+$11
  lda ENEMY+$10
  jmp .loword(medium_select)
medium_continue:
  rep #$20
  lda AI_CONTEXT+4
medium_next:
  sta AI_NEXT
  sep #$20
  sec
  rtl

medium_home:
.a16
  sep #$20
  lda ENEMY+$14
  cmp #1
  beq @pursuit
  cmp #2
  beq @dive
  lda ENEMY+$11
  beq @aim
  dec ENEMY+$11
  rep #$20
  lda #$81c4
  bra medium_next
@aim:
  .a8
  jsl MEDIUM_TARGET
  lda #1
  sta ENEMY+$14
  lda #6
  sta ENEMY+$11
  ldy #0
  bra @angle
@pursuit:
  .a8
  lda ENEMY+$11
  beq @second_aim
  dec ENEMY+$11
  bra @cached
@second_aim:
  .a8
  jsl MEDIUM_TARGET
  lda #2
  sta ENEMY+$14
  lda #8
  sta ENEMY+$11
  ldy #64
@angle:
  .a8
  rep #$20
  lda ENEMY+$16
  and #31
  asl
  sta $d6
  tya
  clc
  adc $d6
  tax
  lda f:medium_home_paths,x
  sta AI_NEXT
  xba
  sta ENEMY+$12
  sep #$20
  sec
  rtl
@dive:
  .a8
  lda ENEMY+$11
  beq @leave
  dec ENEMY+$11
  jsl MEDIUM_TARGET
  lda ENEMY+3
  sec
  sbc PLAYER+3,y
  bcc @leave
  cmp #$28
  bcc @leave
@cached:
  .a8
  rep #$20
  lda ENEMY+$12
  xba
  jmp .loword(medium_next)
@leave:
  .a8
  rep #$20
  lda #$8219
  jmp .loword(medium_next)

medium_fire:
.a16
  sep #$20
  jsl MEDIUM_TARGET
  cmp #8
  bcs :+
  lda #8
:
  cmp #25
  bcc :+
  lda #24
:
  ; The original clamps the bullet angle after storing the raw aim angle.
  sta MEDIUM_SHOT_ANGLE
  lda #2                    ; explicit-angle fire request
  sta AI_FIRE
  jmp .loword(medium_continue)

medium_dive:
.a16
  sep #$20
  jsl MEDIUM_TARGET
  lda PLAYER+3,y
  cmp #$a0
  bcs @hold
  lda #2
  sta ENEMY+$12
  lda #0
  bra medium_select
@hold:
  lda #1
  sta ENEMY+$12
  lda #4
  ldx MEDIUM_RANDOM
  txa
  bpl :+
  lda #10
  bra @delay
:
  lda #4
@delay:
  sta ENEMY+$11
  lda #1
  bra medium_select

medium_turn:
.a16
  sep #$20
  jsl MEDIUM_TARGET
  lda PLAYER+3,y
  clc
  adc #32
  cmp ENEMY+3
  bcs medium_side
  lda #0
  bra medium_select
medium_side:
  stz ENEMY+$10
  lda ENEMY+2
  sec
  sbc PLAYER+2,y
  bcs @left
  eor #255
  inc
  cmp #64
  bcc :+
  inc ENEMY+$10
:
  lda #2
  bra medium_select
@left:
  cmp #64
  bcc :+
  inc ENEMY+$10
:
  lda #3
medium_select:
  rep #$20
  and #255
  asl
  tax
  lda f:medium_dive_paths,x
  jmp .loword(medium_next)

medium_loop:
.a16
  sep #$20
  lda ENEMY+$11
  beq @leave
  dec ENEMY+$11
  lda ENEMY+$10
  bra medium_select
@leave:
  lda #16
  sta ENEMY+$10
  stz ENEMY+$11
  jsl MEDIUM_TARGET
  lda ENEMY+2
  cmp PLAYER+2,y
  rep #$20
  lda #$908e
  bcc :+
  lda #$90b7
:
  jmp .loword(medium_next)

medium_hold:
.a16
  sep #$20
  lda ENEMY+$11
  beq @side
  dec ENEMY+$11
  rep #$20
  lda #$8ff8
  jmp .loword(medium_next)
@side:
  .a8
  jsl MEDIUM_TARGET
  jmp .loword(medium_side)

MEDIUM_SHOT_ANGLE = $1c71
medium_delays:
  .byte $14,$10,$14,$18

; Original $90E0-$911F and $3144: turn one direction step toward the target.
medium_return:
.a16
  sep #$20
  lda ENEMY+$11
  beq @aim
  dec ENEMY+$11
  bra @pointer
@aim:
  lda ENEMY+$12
  sta ENEMY+$11
  jsl MEDIUM_TARGET
  cmp ENEMY+$10
  beq @pointer
  lda ENEMY+$10
  inc
  and #31
  sta $d4
  lda ENEMY+$16
  sec
  sbc $d4
  and #31
  cmp #16
  bcs @decrement
  lda ENEMY+$10
  inc
  bra @store
@decrement:
  lda ENEMY+$10
  dec
@store:
  and #31
  sta ENEMY+$10
@pointer:
  rep #$20
  lda ENEMY+$10
  and #255
  asl
  tax
  lda f:medium_return_paths,x
  jmp .loword(medium_next)
