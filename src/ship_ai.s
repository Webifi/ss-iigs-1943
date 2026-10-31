; Native decisions for bank-four carrier aircraft. Original movement data
; stays build-time data. D may name a live fighter record in the pool build.
.a8
.i16
.ifndef SHIP_TARGET
SHIP_TARGET = ai_target_far
.endif
.ifndef RANDOM_STATE
RANDOM_STATE = $11c8
.endif
ship_ai:
  rep #$20
  lda AI_CONTEXT+2
  .macro dispatch id, dest
    cmp #id
    bne :+
    jmp .loword(dest)
:
  .endmacro
  dispatch $9283, ship_launch_depart
  dispatch $928d, ship_launch_wrap
  dispatch $92f9, ship_launch_wait
  dispatch $9309, ship_launch_enable
  dispatch $933c, ship_launch_track
  dispatch $a1cc, ship_dive_hold
  dispatch $a1e0, ship_dive_delay
  dispatch $a1ef, ship_dive_begin
  dispatch $a218, ship_dive_wait
  dispatch $a233, ship_dive_aim
  dispatch $a267, ship_dive_reaim
  dispatch $a28e, ship_dive_turn_end
  dispatch $a33e, ship_fire_half
  dispatch $a343, ship_fire_eighth
  dispatch $a348, ship_fire_quarter
  dispatch $a6b5, ship_homing_begin
  dispatch $a6bf, ship_homing_track
  .delmacro dispatch
  sep #$20
  clc
  rtl
ship_next:
.a16
  sta AI_NEXT
  sep #$20
  sec
  rtl
ship_launch_depart:
.a16
  sep #$20
  stz ENEMY+9
  rep #$20
  lda #$9411
  bra ship_next
ship_launch_wrap:
.a16
  sep #$20
  lda ENEMY+3
  cmp #$fa
  bcc @sequence
  lda #16
  sta ENEMY+$10
  stz ENEMY+$11
  lda #255
  sta ENEMY+3
  lda RANDOM_STATE+2
  pha
  clc
  adc #$99
  sta RANDOM_STATE+2
  pla
  and #15
  asl
  rep #$20
  and #255
  tax
  sep #$20
  lda f:ship_wrap_positions,x
  sta ENEMY+2
  lda f:ship_wrap_positions+1,x
  sta ENEMY+$11
  rep #$20
  lda #$946e
  bra ship_next
@sequence:
.a8
  lda ENEMY+$11
  beq @new
  dec ENEMY+$11
  lda ENEMY+$10
  jsr .loword(ship_sequence_index)
  bra @pointer
@new:
.a8
  lda ENEMY+$10
  inc ENEMY+$10
  jsr .loword(ship_sequence_index)
  lda f:ship_depart_sequence,x
  sta ENEMY+$11
@pointer:
  rep #$20
  lda f:ship_depart_sequence+1,x
  jmp .loword(ship_next)
ship_sequence_index:
.a8
  rep #$20
  and #255
  sta $d4
  asl
  clc
  adc $d4
  tax
  sep #$20
  rts
ship_launch_wait:
.a16
  sep #$20
  lda ENEMY+$11
  beq @fire
  dec ENEMY+$11
  rep #$20
  lda #$9478
  jmp .loword(ship_next)
@fire:
.a8
  jsr .loword(ship_launch_shot)
  jmp .loword(ship_launch_pointer)
ship_launch_enable:
.a16
  sep #$20
  lda #3
  sta ENEMY+9
  rep #$20
  lda #$9478
  jmp .loword(ship_next)
ship_launch_track:
.a16
  sep #$20
  lda ENEMY+$11
  beq @aim
  dec ENEMY+$11
  bra ship_launch_pointer
@aim:
  lda #1
  sta ENEMY+$11
  lda ENEMY+$13
  cmp #32
  bcs @fire_delay
  inc ENEMY+$13
  jsr .loword(ship_turn)
  bcs ship_launch_pointer
@fire_delay:
  lda ENEMY+$12
  beq @fire
  dec ENEMY+$12
  bra ship_launch_pointer
@fire:
  jsr .loword(ship_launch_shot)
ship_launch_pointer:
.a8
  rep #$20
  lda ENEMY+$10
  and #31
  asl
  tax
  lda f:ship_launch_paths,x
  jmp .loword(ship_next)
ship_launch_shot:
.a8
  lda #30
  sta ENEMY+$12
ship_shot:
  jsl SHIP_TARGET
  lda #1
  sta AI_FIRE
  rts
ship_dive_begin:
.a16
  sep #$20
  lda #3
  sta ENEMY+9
  lda #6
  sta ENEMY+$11
  rep #$20
  lda #$a207
  jmp .loword(ship_next)
ship_dive_wait:
.a16
  sep #$20
  lda ENEMY+$11
  beq @next
  dec ENEMY+$11
  rep #$20
  lda #$a207
  jmp .loword(ship_next)
@next:
.a8
  rep #$20
  lda #$a22d
  jmp .loword(ship_next)
ship_dive_aim:
.a16
  sep #$20
  lda #5
  sta ENEMY+$11
  jsr .loword(ship_turn)
  bra ship_dive_pointer
ship_dive_reaim:
.a16
  sep #$20
  lda ENEMY+$11
  beq @leave
  dec ENEMY+$11
  jsr .loword(ship_turn)
  bra ship_dive_pointer
@leave:
  lda ENEMY+$12
  bne ship_dive_pointer
  lda #10
  sta ENEMY+$11
  lda ENEMY+$10
  cmp #16
  rep #$20
  lda #$a2b5
  bcc :+
  lda #$a2ec
:
  jmp .loword(ship_next)
ship_dive_pointer:
.a8
  rep #$20
  lda ENEMY+$10
  and #31
  asl
  tax
  lda f:ship_dive_paths,x
  jmp .loword(ship_next)
ship_dive_turn_end:
.a16
  sep #$20
  lda ENEMY+$11
  beq @complete
  dec ENEMY+$11
  rep #$20
  lda #$a2db
  jmp .loword(ship_next)
@complete:
.a8
  lda #16
  sta ENEMY+$10
  lda #6
  sta ENEMY+$11
  lda #255
  sta ENEMY+$12
  rep #$20
  lda #$a2af
  jmp .loword(ship_next)
ship_fire_half:
.a16
  sep #$20
  lda #8
  bra ship_random_fire
ship_fire_quarter:
.a16
  sep #$20
  lda #4
  bra ship_random_fire
ship_fire_eighth:
.a16
  sep #$20
  lda #2
ship_random_fire:
.a8
  sta $d4
  lda RANDOM_STATE
  clc
  adc #$13
  sta RANDOM_STATE
  and #15
  cmp $d4
  bcs @continue
  jsr .loword(ship_shot)
@continue:
  rep #$20
  lda AI_CONTEXT+4
  jmp .loword(ship_next)
ship_homing_begin:
.a16
  sep #$20
  lda #3
  sta ENEMY+9
  rep #$20
  lda #$a76e
  jmp .loword(ship_next)
ship_homing_track:
.a16
  sep #$20
  lda ENEMY+$11
  beq @aim
  dec ENEMY+$11
  bra @pointer
@aim:
  lda ENEMY+$12
  sta ENEMY+$11
  lda ENEMY+$13
  cmp #32
  bcs @pointer
  inc ENEMY+$13
  lda RANDOM_STATE
  pha
  clc
  adc #$77
  sta RANDOM_STATE
  pla
  and #15
  bne :+
  jsr .loword(ship_shot)
:
  jsr .loword(ship_turn)
@pointer:
  rep #$20
  lda ENEMY+$10
  and #31
  asl
  tax
  lda f:ship_homing_paths,x
  jmp .loword(ship_next)
; Original $3144 returns through a direction-specific continuation. Carry
; reports a changed direction so the caller preserves those branch effects.
ship_turn:
.a8
  jsl SHIP_TARGET
  cmp ENEMY+$10
  beq @same
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
  sec
  rts
@same:
  clc
  rts

ship_dive_hold:
.a16
  sep #$20
  lda #4
  sta ENEMY+9
  rep #$20
  lda #$a1d6
  jmp .loword(ship_next)
ship_dive_delay:
.a16
  sep #$20
  lda ENEMY+$11
  bne :+
  jmp .loword(ship_dive_begin)
:
  dec ENEMY+$11
  rep #$20
  lda #$a1fd
  jmp .loword(ship_next)
