; Native original-US single-piece formations: bank 0 $82D7/$82EF,
; bank 4 $9707/$9ACF/$9EB5, bank 6 $8CDC. Original path tables are build data.
.a8
.i16
.ifndef FORMATION_TARGET
FORMATION_TARGET = ai_target_far
.endif
FORMATION_TYPE = $1db8
FORMATION_ODDS = $1db9
formation_ai:
  jsl formation_extra
  bcc :+
  rtl
:
  rep #$20
  lda ENEMY+10
  and #$70
  beq @bank_zero
  cmp #$40
  beq @bank_four
  cmp #$60
  bne @unknown
  lda AI_CONTEXT+2
  cmp #$8cdc
  bne @unknown
  sep #$20
  lda #3
  sta FORMATION_TYPE
  jmp .loword(formation_bank_six)
@bank_zero:
.a16
  lda AI_CONTEXT+2
  cmp #$82d7
  beq @left
  cmp #$82ef
  bne @unknown
  sep #$20
  jsr .loword(formation_fire)
  rep #$20
  lda #$83b1
  bra @next
@left:
  sep #$20
  jsr .loword(formation_fire)
  rep #$20
  lda #$8342
@next:
  sta AI_NEXT
  sep #$20
  sec
  rtl
@bank_four:
.a16
  lda AI_CONTEXT+2
  cmp #$9707
  beq @spiral
  cmp #$9acf
  beq @second_spiral
  cmp #$9eb5
  beq @pursuit
  cmp #$9f4f
  bne @unknown
  sep #$20
  lda #8
  jsr .loword(formation_random_fire)
  rep #$20
  lda AI_CONTEXT+4
  bra @next
@spiral:
  sep #$20
  stz FORMATION_TYPE
  jmp .loword(formation_spiral)
@second_spiral:
  sep #$20
  lda #1
  sta FORMATION_TYPE
  jmp .loword(formation_spiral)
@pursuit:
  sep #$20
  lda #2
  sta FORMATION_TYPE
  jmp .loword(formation_pursuit)
@unknown:
  sep #$20
  clc
  rtl

formation_select:
.a8
  rep #$20
  lda FORMATION_TYPE
  and #255
  asl
  asl
  asl
  asl
  asl
  asl
  sta $d6
  lda ENEMY+$10
  and #31
  asl
  clc
  adc $d6
  tax
  lda f:formation_paths,x
  sta AI_NEXT
  sep #$20
  sec
  rtl

formation_continue:
  rep #$20
  lda AI_CONTEXT+4
  sta AI_NEXT
  sep #$20
  sec
  rtl

formation_fire:
.a8
  jsl FORMATION_TARGET
  lda #1
  sta AI_FIRE
  rts
formation_random_fire:
  sta FORMATION_ODDS
  lda RANDOM_STATE+2
  pha
  clc
  adc #$55
  sta RANDOM_STATE+2
  pla
  and #15
  cmp FORMATION_ODDS
  bcs @done
  jsr .loword(formation_fire)
@done:
  rts
formation_turn:
  lda ENEMY+$14
  beq @increase
  cmp #1
  bne @done
  lda ENEMY+$10
  dec
  bra @store
@increase:
  lda ENEMY+$10
  inc
@store:
  and #31
  sta ENEMY+$10
@done:
  rts
formation_aim_turn:
  jsl FORMATION_TARGET
  cmp ENEMY+$10
  beq @straight
  sta $d6
  lda ENEMY+$10
  inc
  and #31
  sta $d7
  lda $d6
  sec
  sbc $d7
  and #31
  cmp #16
  lda #0
  bcc @set
  inc
  bra @set
@straight:
  lda #2
@set:
  sta ENEMY+$14
  jmp .loword(formation_turn)

formation_spiral:
  lda ENEMY+$11
  bne :+
  jmp .loword(@search)
:
  cmp #1
  beq @arc
  dec ENEMY+$12
  beq :+
  jmp .loword(formation_select)
:
  lda #1
  sta ENEMY+$12
  lda FORMATION_TYPE
  beq :+
  lda #26
  bra @arc_count
:
  lda #18
@arc_count:
  sta ENEMY+$13
  dec ENEMY+$11
  jmp .loword(formation_select)
@arc:
  dec ENEMY+$12
  beq :+
  jmp .loword(formation_select)
:
  dec ENEMY+$13
  beq @search_begin
  lda #3
  sta ENEMY+$12
  jsr .loword(formation_turn)
  lda FORMATION_TYPE
  bne @second_fire
  lda ENEMY+$10
  cmp #12
  beq @odds_four
  cmp #20
  beq @odds_four
  jmp .loword(formation_select)
@second_fire:
  lda ENEMY+$10
  beq @odds_even
  cmp #28
  beq @odds_four
  cmp #4
  beq @odds_two
  cmp #8
  beq @odds_two
  cmp #12
  beq @odds_two
  jmp .loword(formation_select)
@odds_even:
  lda RANDOM_STATE+2
  pha
  clc
  adc #$55
  sta RANDOM_STATE+2
  pla
  and #1
  bne @selected
  jsr .loword(formation_fire)
  bra @selected
@odds_four:
  lda #4
  bra @random
@odds_two:
  lda #2
@random:
  jsr .loword(formation_random_fire)
@selected:
  jmp .loword(formation_select)
@search_begin:
  lda #1
  sta ENEMY+$13
  lda #17
  sta ENEMY+$12
  dec ENEMY+$11
  bra @selected
@search:
  dec ENEMY+$13
  bne @selected
  lda #3
  sta ENEMY+$13
  dec ENEMY+$12
  beq @restart
  lda ENEMY+$12
  and #1
  bne :+
  lda #2
  jsr .loword(formation_random_fire)
:
  jsr .loword(formation_aim_turn)
  jmp .loword(formation_select)
@restart:
  lda #2
  sta ENEMY+$11
  stz ENEMY+$12
  bra @selected

formation_pursuit:
  lda ENEMY+$11
  beq @coast
  dec ENEMY+$12
  bne @done
  dec ENEMY+$13
  beq @coast_begin
  lda STAGE_DIFFICULTY+7
  cmp #10
  lda #3
  bcs :+
  inc
:
  sta ENEMY+$12
  jsr .loword(formation_aim_turn)
  jmp .loword(formation_select)
@coast_begin:
  lda #255
  sta ENEMY+$12
  stz ENEMY+$11
  bra @done
@coast:
  dec ENEMY+$12
  bne @done
  lda #1
  sta ENEMY+$11
  sta ENEMY+$12
@done:
  jmp .loword(formation_select)

formation_bank_six:
  lda ENEMY+$13
  cmp #12
  bcs @done
  lda ENEMY+$11
  beq @delay
  dec ENEMY+$11
  bra @done
@delay:
  lda ENEMY+$12
  beq @step
  dec ENEMY+$12
  bra @done
@step:
  lda #4
  sta ENEMY+$12
  inc ENEMY+$13
  lda ENEMY+$14
  bne @later_fire
  inc ENEMY+$14
  lda RANDOM_STATE
  clc
  adc #$13
  sta RANDOM_STATE
  and #15
  cmp #7
  bcs @turn
  bra @fire
@later_fire:
  lda RANDOM_STATE+1
  clc
  adc #$42
  sta RANDOM_STATE+1
  and #15
  bne @turn
@fire:
  jsr .loword(formation_fire)
@turn:
  ; $3144 returns one of three continuations. Bank six changes the
  ; heading directly and keeps $14 as the first-shot flag.
  jsl FORMATION_TARGET
  cmp ENEMY+$10
  beq @done
  sta $d6
  lda ENEMY+$10
  inc
  and #31
  sta $d7
  lda $d6
  sec
  sbc $d7
  and #31
  cmp #16
  lda ENEMY+$10
  bcc @increase
  dec
  bra @store
@increase:
  inc
@store:
  and #31
  sta ENEMY+$10
@done:
  jmp .loword(formation_select)
