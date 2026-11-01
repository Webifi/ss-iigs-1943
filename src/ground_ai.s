; The ground guns (US arcade bank 0): seven kinds of fire, one aim rule: the
; barrel turns BARREL_STEP toward the player each decision ($3117) and the
; gun fires when the barrel is within one step and the delay is over. Also
; the ground bullets that turn in a spiral. D = the object record.
.a8
.i16
BARREL_STEP = 2              ; the barrel stays even: 16 directions
GROUND_BULLET_TURN_LIMIT = 32 ; ground_bullet_ai: the spiral ends after this many turns

; The family bytes of the object record for the guns.
GROUND_BARREL = $10          ; the barrel direction, 0-31
GROUND_DELAY = $11           ; decisions left before the next shot
GROUND_BURST = $12           ; burst shots left
GROUND_BURST_DIRECTION = $13 ; the direction of the next burst shot
; The family bytes of the object record for the ground bullets.
GROUND_BULLET_STRAIGHT = $10 ; straight moves left
GROUND_BULLET_DIRECTION = $11
GROUND_BULLET_TURNS = $12

; Bank-0 motion code tails of the guns (AI_TAIL), in GK_* order.
TAIL_GUN_SPREAD = $ad42
TAIL_GUN_SINGLE8 = $af09
TAIL_GUN_SINGLE15 = $b185
TAIL_GUN_RANDOM = $b34e
TAIL_GUN_TRIPLE = $b4ed      ; the four-shot battery
TAIL_GUN_CHANCE = $b9b0
TAIL_GUN_RANDOM2 = $bb4c
GK_SPREAD = 0
GK_SINGLE8 = 2
GK_SINGLE15 = 4
GK_RANDOM = 6
GK_TRIPLE = 8
GK_CHANCE = 10
GK_RANDOM2 = 12
; Fixed-bank tails and motion of the ground bullets.
TAIL_GROUND_BULLET_STRAIGHT = $3eab
TAIL_GROUND_BULLET_TURN = $3ec4
MOTION_GROUND_BULLET_END = $4173

; ground_ai: the decision of AI_TAIL for a ground gun (enemy_ai): returns
; carry 1 with AI_NEXT and AI_FIRE (GROUND_KILL when the ship turrets fall),
; or carry 0 for another tail. JSL.
ground_ai:
  stz GROUND_KILL
  a16
  lda AI_TAIL
  cmp #ARCADE_BANK_WINDOW
  bcc @unknown
  pha
  lda z:OBJ_VARIANT
  and #OBJ_BANK_BITS          ; bank 0
  beq :+
  pla
  bra @unknown
:
  pla
  ; The four-shot ground battery is common in the last-stage fight.
  ; Keep the original kind value and use the full table for all other IDs.
  cmp #TAIL_GUN_TRIPLE
  bne :+
  ldx #GK_TRIPLE
  bra @kind
:
  ldx #0
@find:
  cmp f:ground_callback_ids,x
  beq @kind
  inx
  inx
  cpx #ground_callback_ids_end-ground_callback_ids
  bne @find
@unknown:
  a8
  clc
  rtl
@kind:
  ; The turrets of a destroyed ship die and score for STAGE_CORE_OWNER;
  ; GK_SINGLE8 and GK_RANDOM2 guns stay.
  stx GROUND_KIND
  a8
  cpx #GK_SINGLE8
  beq @alive
  cpx #GK_RANDOM2
  beq @alive
  lda STAGE_TURRETS_FALL
  beq @alive
  lda STAGE_CORE_OWNER
  sta z:OBJ_OWNER
  lda #1
  sta GROUND_KILL
  sec
  rtl
@alive:
  lda z:GROUND_DELAY
  beq :+
  dec z:GROUND_DELAY
:
  jsl ai_target_far
  lda z:OBJ_AIM
  sec
  sbc z:GROUND_BARREL
  and #DIRECTIONS-1
  beq @aligned
  cmp #1
  beq @aligned
  cmp #DIRECTIONS-1
  beq @aligned
  cmp #DIRECTIONS/2
  bcc @increase
  lda z:GROUND_BARREL
  sec
  sbc #BARREL_STEP
  bra @angle
@increase:
  lda z:GROUND_BARREL
  clc
  adc #BARREL_STEP
@angle:
  and #DIRECTIONS-1
  sta z:GROUND_BARREL
  jmp .loword(ground_after_aim)
@aligned:
  lda z:GROUND_DELAY
  beq :+
  jmp .loword(ground_after_aim)
:
  ldx GROUND_KIND
  jmp (.loword(ground_fire_vectors),x)
; ground_callback_ids: the tails of the GK_* kinds, in order (long reads, so
; the words are in the NATIVE segment).
.pushseg
.segment "NATIVE"
ground_callback_ids:
  .word TAIL_GUN_SPREAD,TAIL_GUN_SINGLE8,TAIL_GUN_SINGLE15,TAIL_GUN_RANDOM
  .word TAIL_GUN_TRIPLE,TAIL_GUN_CHANCE,TAIL_GUN_RANDOM2
ground_callback_ids_end:
.popseg
; ground_fire_vectors: the fire of each GK_* kind.
ground_fire_vectors:
  .addr ground_spread,ground_single8,ground_single15,ground_random,ground_triple,ground_chance,ground_random

; ground_spread: a burst of three ground bullets at the barrel and 2 to each
; side (ground_after_aim); delay 12.
ground_spread:
.a8
  lda z:GROUND_BARREL
  sta z:GROUND_BURST_DIRECTION
  lda #3
  sta z:GROUND_BURST
  lda #12
  sta z:GROUND_DELAY
  jmp .loword(ground_after_aim)
; ground_single8, ground_single15: one bullet at the player; delay 8 or 15.
ground_single8:
  lda #8
  bra ground_single
ground_single15:
  lda #15
ground_single:
  sta z:GROUND_DELAY
  lda z:OBJ_AIM
  sta MEDIUM_SHOT_ANGLE
  lda #AIF_ANGLE
  sta AI_FIRE
  jmp .loword(ground_after_aim)
; ground_random: a ground bullet at the barrel at a random speed
; (ground_random_speeds: entries 0-3 from random stream 4, step $88; for
; GK_RANDOM2 entries 4-7 from stream 5, step $77); delay 8.
ground_random:
  lda #8
  sta z:GROUND_DELAY
  ldx #4                        ; random stream 4
  lda GROUND_KIND
  cmp #GK_RANDOM2
  bne :+
  inx                           ; random stream 5
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
  a16
  and #255
  tax
  a8
  lda f:ground_random_speeds,x
  sta GROUND_SPEED
  lda z:GROUND_BARREL
  sta GROUND_ANGLE
  lda #AIF_GROUND
  sta AI_FIRE
  jmp .loword(ground_after_aim)
; ground_triple: the battery: three bullets one direction apart, from the
; aim - 1 (ground_after_aim); delay 30.
ground_triple:
  lda #3
  sta z:GROUND_BURST
  lda z:OBJ_AIM
  dec
  and #DIRECTIONS-1
  sta z:GROUND_BURST_DIRECTION
  lda #30
  sta z:GROUND_DELAY
  jmp .loword(ground_after_aim)
; ground_chance: a bullet at the player 1 time in 2 (random stream 4, step
; $77); delay 11.
ground_chance:
  lda #11
  sta z:GROUND_DELAY
  lda RANDOM_STATE+4
  pha
  clc
  adc #$77
  sta RANDOM_STATE+4
  pla
  lsr
  bcc ground_after_aim
  lda z:OBJ_AIM
  sta MEDIUM_SHOT_ANGLE
  lda #AIF_ANGLE
  sta AI_FIRE

; ground_after_aim: the next shot of a burst, then the path of the barrel.
ground_after_aim:
.a8
  lda GROUND_KIND
  beq @spread                   ; GK_SPREAD
  cmp #GK_TRIPLE
  bne ground_select
  lda z:GROUND_BURST
  beq ground_select
  dec z:GROUND_BURST
  lda z:GROUND_BURST_DIRECTION
  sta MEDIUM_SHOT_ANGLE
  inc
  and #DIRECTIONS-1
  sta z:GROUND_BURST_DIRECTION
  lda #AIF_ANGLE
  sta AI_FIRE
  bra ground_select
@spread:
  ; Shot 3 at the barrel, shot 2 at - BARREL_STEP, shot 1 at + BARREL_STEP,
  ; at a random speed (ground_spread_speeds, random stream 1, step $77).
  lda z:GROUND_BURST
  beq ground_select
  a16
  lda z:GROUND_BURST
  and #255
  tax
  a8
  lda z:GROUND_BURST_DIRECTION
  cpx #3
  beq @spread_angle
  cpx #2
  beq @lower
  clc
  adc #BARREL_STEP
  bra @spread_angle
@lower:
  sec
  sbc #BARREL_STEP
@spread_angle:
  and #DIRECTIONS-1
  sta GROUND_ANGLE
  lda RANDOM_STATE+1
  pha
  clc
  adc #$77
  sta RANDOM_STATE+1
  pla
  and #7
  a16
  and #255
  tax
  a8
  lda f:ground_spread_speeds,x
  sta GROUND_SPEED
  lda #AIF_GROUND
  sta AI_FIRE
  dec z:GROUND_BURST
; ground_select: AI_NEXT = the ground_paths path of the kind and the barrel
; (16 words a kind; the barrel is even); carry 1.
ground_select:
.a8
  a16
  lda GROUND_KIND
  asl
  asl
  asl
  asl                           ; GK_* (word index) * 16 = the kind's 32 bytes
  sta a:GROUND_PATH_OFFSET
  lda z:GROUND_BARREL
  and #255
  clc
  adc a:GROUND_PATH_OFFSET
  tax
  lda f:ground_paths,x
  sta AI_NEXT
  a8
  sec
  rtl

; ground_bullet_ai: the spiral ground bullet (bullet_tick): straight for
; GROUND_BULLET_STRAIGHT decisions, then turns of 2 directions up to
; GROUND_BULLET_TURN_LIMIT; then it ends. Returns carry 1 with AI_NEXT, or
; carry 0 for another tail. JSL.
ground_bullet_ai:
.a8
  a16
  lda AI_TAIL
  cmp #TAIL_GROUND_BULLET_STRAIGHT
  beq @straight
  cmp #TAIL_GROUND_BULLET_TURN
  beq @turn
  a8
  clc
  rtl
@straight:
  a8
  lda z:GROUND_BULLET_STRAIGHT
  beq @turn_path
  dec z:GROUND_BULLET_STRAIGHT
  a16
  lda z:GROUND_BULLET_DIRECTION
  and #255
  tax
  lda f:ground_bullet_paths,x
  bra @selected
@turn:
.a16
  a8
  lda z:GROUND_BULLET_TURNS
  inc
  cmp #GROUND_BULLET_TURN_LIMIT
  bne :+
  a16
  lda #MOTION_GROUND_BULLET_END
  bra @selected
:
.a8
  sta z:GROUND_BULLET_TURNS
  lda z:GROUND_BULLET_DIRECTION
  clc
  adc #2
  and #DIRECTIONS-1
  sta z:GROUND_BULLET_DIRECTION
@turn_path:
  a16
  lda z:GROUND_BULLET_DIRECTION
  and #255
  tax
  lda f:ground_bullet_turn_paths,x
@selected:
  sta AI_NEXT
  a8
  sec
  rtl
