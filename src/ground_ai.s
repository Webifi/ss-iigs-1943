; Native original-US stationary/scrolling gun emplacements. Their seven
; firing policies share the original two-step aiming rule ($3117).
.a8
.i16
GROUND_KILL = $1de0
GROUND_SPEED = $1de1
GROUND_ANGLE = $1de2
GROUND_KIND = $1de4

ground_ai:
  stz GROUND_KILL
  rep #$20
  lda AI_CONTEXT+2
  cmp #$8000
  bcc @unknown
  pha
  lda ENEMY+10
  and #$70
  beq :+
  pla
  bra @unknown
:
  pla
  ; The four-shot ground battery is common in the last-stage fight.
  ; Keep the original kind value and use the full table for all other IDs.
  cmp #$b4ed
  bne :+
  ldx #8
  bra @kind
:
  ldx #0
@find:
  cmp f:ground_callback_ids,x
  beq @kind
  inx
  inx
  cpx #14
  bne @find
@unknown:
  sep #$20
  clc
  rtl
@kind:
  stx GROUND_KIND
  sep #$20
  cpx #2
  beq @alive
  cpx #12
  beq @alive
  lda STAGE_FLAGS+$13
  beq @alive
  lda STAGE_FLAGS+7
  sta ENEMY+$0e
  lda #1
  sta GROUND_KILL
  sec
  rtl
@alive:
  lda ENEMY+$11
  beq :+
  dec ENEMY+$11
:
  jsl GROUND_TARGET
  lda ENEMY+$16
  sec
  sbc ENEMY+$10
  and #31
  beq @aligned
  cmp #1
  beq @aligned
  cmp #31
  beq @aligned
  cmp #16
  bcc @increase
  lda ENEMY+$10
  sec
  sbc #2
  bra @angle
@increase:
  lda ENEMY+$10
  clc
  adc #2
@angle:
  and #31
  sta ENEMY+$10
  jmp .loword(ground_after_aim)
@aligned:
  lda ENEMY+$11
  beq :+
  jmp .loword(ground_after_aim)
:
  ldx GROUND_KIND
  jmp (.loword(ground_fire_vectors),x)
; The lookup uses long addressing, so these immutable words can live in
; the existing bank-zero native reservation without changing their reads.
.pushseg
.segment "NATIVE"
ground_callback_ids:
  .word $ad42,$af09,$b185,$b34e,$b4ed,$b9b0,$bb4c
.popseg
ground_fire_vectors:
  .addr ground_spread,ground_single8,ground_single15,ground_random,ground_triple,ground_chance,ground_random

ground_spread:
.a8
  lda ENEMY+$10
  sta ENEMY+$13
  lda #3
  sta ENEMY+$12
  lda #12
  sta ENEMY+$11
  jmp .loword(ground_after_aim)
ground_single8:
  lda #8
  bra ground_single
ground_single15:
  lda #15
ground_single:
  sta ENEMY+$11
  lda ENEMY+$16
  sta MEDIUM_SHOT_ANGLE
  lda #2
  sta AI_FIRE
  jmp .loword(ground_after_aim)
ground_random:
  lda #8
  sta ENEMY+$11
  ldx #4
  lda GROUND_KIND
  cmp #12
  bne :+
  inx
:
  lda RANDOM_STATE,x
  pha
  clc
  adc #$88
  cpx #4
  beq :+
  sec
  sbc #$11
:
  sta RANDOM_STATE,x
  pla
  and #3
  cpx #4
  beq :+
  ora #4
:
  rep #$20
  and #255
  tax
  sep #$20
  lda f:ground_random_speeds,x
  sta GROUND_SPEED
  lda ENEMY+$10
  sta GROUND_ANGLE
  lda #3
  sta AI_FIRE
  jmp .loword(ground_after_aim)
ground_triple:
  lda #3
  sta ENEMY+$12
  lda ENEMY+$16
  dec
  and #31
  sta ENEMY+$13
  lda #30
  sta ENEMY+$11
  jmp .loword(ground_after_aim)
ground_chance:
  lda #11
  sta ENEMY+$11
  lda RANDOM_STATE+4
  pha
  clc
  adc #$77
  sta RANDOM_STATE+4
  pla
  lsr
  bcc ground_after_aim
  lda ENEMY+$16
  sta MEDIUM_SHOT_ANGLE
  lda #2
  sta AI_FIRE

ground_after_aim:
.a8
  lda GROUND_KIND
  beq @spread
  cmp #8
  bne ground_select
  lda ENEMY+$12
  beq ground_select
  dec ENEMY+$12
  lda ENEMY+$13
  sta MEDIUM_SHOT_ANGLE
  inc
  and #31
  sta ENEMY+$13
  lda #2
  sta AI_FIRE
  bra ground_select
@spread:
  lda ENEMY+$12
  beq ground_select
  rep #$20
  lda ENEMY+$12
  and #255
  tax
  sep #$20
  lda ENEMY+$13
  cpx #3
  beq @spread_angle
  cpx #2
  beq @lower
  clc
  adc #2
  bra @spread_angle
@lower:
  sec
  sbc #2
@spread_angle:
  and #31
  sta GROUND_ANGLE
  lda RANDOM_STATE+1
  pha
  clc
  adc #$77
  sta RANDOM_STATE+1
  pla
  and #7
  rep #$20
  and #255
  tax
  sep #$20
  lda f:ground_spread_speeds,x
  sta GROUND_SPEED
  lda #3
  sta AI_FIRE
  dec ENEMY+$12
ground_select:
.a8
  rep #$20
  lda GROUND_KIND
  asl
  asl
  asl
  asl
  sta $d4
  lda ENEMY+$10
  and #255
  clc
  adc $d4
  tax
  lda f:ground_paths,x
  sta AI_NEXT
  sep #$20
  sec
  rtl

ground_bullet_ai:
.a8
  rep #$20
  lda AI_CONTEXT+2
  cmp #$3eab
  beq @straight
  cmp #$3ec4
  beq @turn
  sep #$20
  clc
  rtl
@straight:
  sep #$20
  lda ENEMY+$10
  beq @turn_path
  dec ENEMY+$10
  rep #$20
  lda ENEMY+$11
  and #255
  tax
  lda f:ground_bullet_paths,x
  bra @selected
@turn:
.a16
  sep #$20
  lda ENEMY+$12
  inc
  cmp #32
  bne :+
  rep #$20
  lda #$4173
  bra @selected
:
.a8
  sta ENEMY+$12
  lda ENEMY+$11
  clc
  adc #2
  and #31
  sta ENEMY+$11
@turn_path:
  rep #$20
  lda ENEMY+$11
  and #255
  tax
  lda f:ground_bullet_turn_paths,x
@selected:
  sta AI_NEXT
  sep #$20
  sec
  rtl
