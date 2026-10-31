; Native enemy callback decisions. No arcade code is executed.
; AI_CONTEXT: target preference, random byte, callback ID, continuation,
; selected script pointer, fire request, sound request (10 bytes).
.a8
.i16
.ifndef ENEMY
ENEMY = $1100
.endif
.ifndef PLAYER
PLAYER = $1000
.endif
AI_CONTEXT = $1170
AI_NEXT = AI_CONTEXT+6
AI_FIRE = AI_CONTEXT+8
AI_SOUND = AI_CONTEXT+9

enemy_ai:
  stz AI_FIRE
  stz AI_SOUND
 .ifdef EXTENDED_STAGE_ENEMIES
  jsl ground_ai
  bcc :+
  rts
:
 .endif
  rep #$20
  stz AI_NEXT
 .ifdef FORMATION_ENEMIES
  jsl formation_ai
  bcc :+
  rts
:
  rep #$20
 .endif
 .ifdef SHIP_ENEMIES
  lda AI_CONTEXT+2
  cmp #$8000
  bcc :+
  lda ENEMY+10
  and #$70
  cmp #$40
  bne :+
  jsl ship_ai
  bcc ai_unknown_ship
  rts
ai_unknown_ship:
  sep #$20
  lda #$ec
  sta f:$050301
  rts
:
 .endif
 .a16
  lda AI_CONTEXT+2
 .ifdef ENEMY_SPECIAL_CONTACT
  cmp #$768d
  bne :+
  sep #$20
  jsl pickup_change
  rts
:
 .a16
  cmp #$726b
  bne :+
  sep #$20
  jsl pickup_laser
  rts
:
 .a16
  cmp #$729d
  bne :+
  lda #$72fe
  sta AI_NEXT
  sep #$20
  rts
:
 .a16
 .endif
.ifdef CONTINUOUS_GAME
  cmp #$49b5
  bne :+
  lda ENEMY+$1e
  clc
  adc #10
  sta AI_NEXT
  sep #$20
  lda #$0f
  sta AI_SOUND
  rts
:
.endif
  .a16
  cmp #$8914
  bne :+
  jmp ai_approach
:
  cmp #$893f
  bne :+
  jmp ai_low_turn
:
  cmp #$899a
  bne :+
  jmp ai_near_turn
:
  cmp #$89b7
  bne :+
  jmp ai_left_count
:
  cmp #$89c1
  bne :+
  jmp ai_left_loop
:
  cmp #$8a07
  bne :+
  jmp ai_right_count
:
  cmp #$8a11
  bne :+
  jmp ai_right_loop
:
  cmp #$5a3e
  bne :+
  jmp ai_explosion
:
  cmp #$9ad1
  bne :+
  jmp ai_pattern
:
.ifdef CONTINUOUS_GAME
  cmp #$5ac8
  bne :+
  sep #$20
  lda ENEMY+$0e
  stz ENEMY+$0e
  cmp #2
  beq @burst_two
  rep #$20
  lda #$5add
  bra @burst_path
@burst_two:
  rep #$20
  lda #$5b25
@burst_path:
  sta AI_NEXT
  sep #$20
  rts
:
.a16
  cmp #$6faa
  bne :+
  sep #$20
  lda #1
  sta ENEMY+9
  lda #2
  sta ENEMY+10
  lda #$67
  sta ENEMY+$17
  rep #$20
  lda #$6fbc
  bra @burst_path
:
.a16
  cmp #$735b
  bne :+
  sep #$20
  lda #$0b
  sta ENEMY+10
  lda #$6f
  sta ENEMY+$17
  lda #5
  sta ENEMY+9
  rep #$20
  lda #$736d
  bra @burst_path
:
.a16
  cmp #$7573
  bne :+
  sep #$20
  lda #$0c
  sta ENEMY+10
  lda #$5f
  sta ENEMY+$17
  lda #5
  sta ENEMY+9
  rep #$20
  lda #$7585
  jmp @burst_path
:
.a16
  cmp #$75eb
  bne :+
  sep #$20
  lda #$0d
  sta ENEMY+10
  lda #$67
  sta ENEMY+$17
  lda #1
  sta ENEMY+9
  rep #$20
  lda #$75fd
  jmp @burst_path
:
.a16
  cmp #$7675
  bne :+
  sep #$20
  lda #5
  sta ENEMY+9
  lda #$4f
  sta ENEMY+$17
  rep #$20
  lda #$7683
  sta AI_NEXT
  sep #$20
  rts
:
.a16
  cmp #$aac5
  bne :+
  jmp ai_pair_pattern
:
.endif
  cmp #$8a57
  bne ai_sound_dispatch
  sep #$20
  lda AI_CONTEXT+1
  and #1
  sta AI_FIRE
  beq :+
  jsr ai_target
:
  rep #$20
  bra ai_continue
ai_sound_dispatch:
.a16
  cmp #$49b5
  bne ai_unknown
  sep #$20
  lda #$0f
  sta AI_SOUND
  rep #$20
ai_continue:
  lda AI_CONTEXT+4
  sta AI_NEXT
  sep #$20
  rts
ai_unknown:
.a16
 .ifdef ALL_STAGE_ENEMIES
  jsl medium_ai
  bcc :+
  rts
:
 .endif
  sep #$20
  lda #$ec
  sta f:$050301
  rts

; Select P1/P2 as $051B-$054B. The helper also stores the original aim angle.
ai_target_far:
  jsr ai_target
  rtl
ai_target:
  ldy #0
  lda PLAYER+8
  beq @second
  lda PLAYER+$88
  beq @done
  lda PLAYER+3
  sec
  sbc PLAYER+$83
  bcc @negative
  cmp #32
  bcs @done
  bra @preference
@negative:
  eor #255
  inc
  cmp #32
  bcs @second
@preference:
  lda AI_CONTEXT
  beq @done
@second:
  ldy #128
@done:
  stz $d0
  lda PLAYER+2,y
  sec
  sbc ENEMY+2
  bcs @x_positive
  eor #255
  inc
  pha
  lda #32
  sta $d0
  pla
@x_positive:
  sta $d2
  lda PLAYER+3,y
  sec
  sbc ENEMY+3
  bcs @y_positive
  eor #255
  inc
  pha
  lda $d0
  ora #24
  sta $d0
  pla
@y_positive:
  sta $d3
  cmp $d2
  bcs @major_y
  sta $d4
  lda $d0
  eor #8
  sta $d0
  lda $d2
  bra @ratio_index
@major_y:
  lda $d2
  sta $d4
  lda $d3
@ratio_index:
  lsr
  and #$7c                    ; floor(major/8) * four thresholds
  rep #$20
  and #255
  tax
  sep #$20
  lda $d4
  cmp f:ai_thresholds,x
  bcc @ratio_zero
  beq @ratio_zero
  cmp f:ai_thresholds+1,x
  bcc @ratio_one
  beq @ratio_one
  cmp f:ai_thresholds+2,x
  bcc @ratio_two
  beq @ratio_two
  cmp f:ai_thresholds+3,x
  bcc @ratio_three
  beq @ratio_three
  lda #4
  bra @ratio_ready
@ratio_zero:
  lda #0
  bra @ratio_ready
@ratio_one:
  lda #1
  bra @ratio_ready
@ratio_two:
  lda #2
  bra @ratio_ready
@ratio_three:
  lda #3
@ratio_ready:
  eor $d0
  rep #$20
  and #255
  tax
  sep #$20
  lda ai_angles,x
  sta ENEMY+$16
  rts

ai_approach:
.a16
  sep #$20
  jsr ai_target
  ldx #0
  lda PLAYER+3,y
  cmp #$a0
  bcc ai_pair
  ldx #4
  bra ai_pair

ai_low_turn:
.a16
  sep #$20
  ldx #4
  lda ENEMY+3
  cmp #$40
  bcs ai_pair
  bra ai_choose_side

ai_near_turn:
.a16
  sep #$20
  jsr ai_target
  ldx #0
  lda PLAYER+3,y
  clc
  adc #$28
  cmp ENEMY+3
  bcc ai_pair

ai_choose_side:
  jsr ai_target
  lda PLAYER+2,y
  cmp ENEMY+2
  bcs @right
  ldx #8
  lda ENEMY+2
  sec
  sbc #$20
  cmp PLAYER+2,y
  bcc ai_pair
  lda #1
  sta ENEMY+$11
  bra ai_pair
@right:
  ldx #12
  lda ENEMY+2
  clc
  adc #$20
  cmp PLAYER+2,y
  bcs ai_pair
  lda #1
  sta ENEMY+$11
ai_pair:
  lda ENEMY+$15
  beq @ordinary
  inx
  inx
@ordinary:
  rep #$20
  lda ai_destinations,x
  sta AI_NEXT
  sep #$20
  rts

ai_left_count:
.a16
  sep #$20
  lda ENEMY+$12
  beq @leave
  dec ENEMY+$12
  bra ai_left_loop8
@leave:
  ldx #24
  bra ai_flag_choice
ai_left_loop:
.a16
  sep #$20
ai_left_loop8:
  ldx #16
  bra ai_flag_choice

ai_right_count:
.a16
  sep #$20
  lda ENEMY+$12
  beq @leave
  dec ENEMY+$12
  bra ai_right_loop8
@leave:
  ldx #40
  bra ai_flag_choice
ai_right_loop:
.a16
  sep #$20
ai_right_loop8:
  ldx #32
ai_flag_choice:
  lda ENEMY+$11
  beq @ready
  inx
  inx
  inx
  inx
@ready:
  jmp ai_pair

ai_explosion:
.a16
  sep #$20
  lda ENEMY+$0e
  stz ENEMY+$0e
  cmp #2
  beq @second
  rep #$20
  lda #$5a53
  bra @store
@second:
.a8
  rep #$20
  lda #$5a8c
@store:
  sta AI_NEXT
  sep #$20
  rts

ai_pattern:
.a16
  sep #$20
  dec ENEMY+$11
  bne @same
  lda ENEMY+$10
  inc
  and #31
  sta ENEMY+$10
  jsr ai_pattern_index
  lda ai_pattern_table,x
  sta ENEMY+$11
  bra @pointer
@same:
  jsr ai_pattern_index
@pointer:
  rep #$20
  lda ai_pattern_table+1,x
  sta AI_NEXT
  sep #$20
  rts
ai_pattern_index:
  rep #$20
  lda ENEMY+$10
  and #255
  sta $d0
  asl
  clc
  adc $d0
  tax
  sep #$20
  rts

.ifdef CONTINUOUS_GAME
ai_pair_pattern:
.a16
  sep #$20
  dec ENEMY+$11
  bne @same
  lda ENEMY+$10
  inc
  and #31
  sta ENEMY+$10
  jsr ai_pattern_index
  lda f:game_pair_turns,x
  sta ENEMY+$11
  bra @pointer
@same:
  jsr ai_pattern_index
@pointer:
  rep #$20
  lda f:game_pair_turns+1,x
  sta AI_NEXT
  sep #$20
  rts
.endif

ai_destinations:
  .word $8a92,$8b93,$8a81,$8b82,$8b0a,$8c12,$8aa3,$8ba4
  .word $8b67,$8c6f,$8b56,$8c5e,$8d3a,$8e32,$8cfc,$8df4
  .word $8af9,$8c01,$8ae8,$8bf0,$8cbe,$8db6,$8c80,$8d78
