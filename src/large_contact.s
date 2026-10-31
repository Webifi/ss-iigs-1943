; Original-US large-object contacts $5CC4-$5E29. D is the live 128-byte
; object. Return the common transition/sound/owner fields to the game loop.
.a8
.i16
large_shot_contact:
  phd
  rep #$20
  lda LARGE_RECORD
  tcd
  sep #$20
  stz CONTACT_ACTION
  stz CONTACT_SOUND
  stz CONTACT_PLAYER
  jsr .loword(large_contact_center)
  jsr .loword(large_shot_test)
  pld
  rtl

large_shot_test:
  lda $09
  and #2
  beq @done
.ifdef CONTINUOUS_GAME
  ; Ordinary objects use the even-phase list built by the wave pass.
  ; Giants use a different phase and keep their original linear scan.
  lda $08
  cmp #$40
  beq :+
  ldy SHOT_ACTIVE_END
  bne :+
  sty CONTACT_LIMIT
  rts
:
.endif
  lda $01
  ora $41
  and #16
  bne @done
  ldx #0
  ldy #9*32
  lda PLAYER+8
  cmp #2
  beq @p1
  lda PLAYER+$88
  cmp #2
  beq @p2
@done:
  rts
@p2:
  ldx #9*32
  ldy #18*32
  bra @start
@p1:
  lda PLAYER+$88
  cmp #2
  bne @start
  ldy #18*32
@start:
.ifdef CONTINUOUS_GAME
  ; Select the list or linear iterator once. D remains on the live object;
  ; $dc is a bank-zero pointer and $de is the coordinate adjustment.
  jsl large_list_prepare
  bcc @linear_start
  cpy CONTACT_LIMIT
  beq @done
  jsl large_shot_y_cull
  bcs @done
  rep #$20
  lda #.loword(@list_next)
  sta a:$dc
  sep #$20
  lda #8
  sta a:$de
  ldx SHOT_ACTIVE,y
  bra @slot
@linear_start:
  sty CONTACT_LIMIT
  rep #$20
  lda #.loword(@linear_next)
  sta a:$dc
  sep #$20
  stz a:$de
  bra @slot
@next:
  jmp ($00dc)
@list_next:
  iny
  iny
  cpy CONTACT_LIMIT
  beq @done
  ldx SHOT_ACTIVE,y
  bra @slot
@linear_next:
  rep #$20
  txa
  clc
  adc #32
  tax
  sep #$20
  cpx CONTACT_LIMIT
  beq @done
  bra @slot
.else
  sty CONTACT_LIMIT
  bra @slot
@next:
  rep #$20
  txa
  clc
  adc #32
  tax
  sep #$20
  cpx CONTACT_LIMIT
  bne @slot
  rts
.endif
@slot:
  lda SHOTS+8,x
  cmp #2
  bne @next
  ; Ordinary four-piece shots add 8 before the byte subtraction. Moving
  ; that offset to the centre changes the borrow at coordinate wraparound.
  ; Giant objects keep their unadjusted shot and centre coordinates.
 .ifdef CONTINUOUS_GAME
  lda SHOTS+3,x
  clc
  adc a:$de
 .else
  lda $08
  cmp #$40
  beq @giant_y
  lda SHOTS+3,x
  clc
  adc #8
  bra @shot_y
@giant_y:
  lda SHOTS+3,x
@shot_y:
 .endif
  sec
  sbc CONTACT_CENTER_Y
  bcs :+
  eor #255
  inc
:
  sta CONTACT_DELTA
  lda $0d
  clc
  adc SHOTS+7,x
  cmp CONTACT_DELTA
  bcc @next
 .ifdef CONTINUOUS_GAME
  lda SHOTS+2,x
  clc
  adc a:$de
 .else
  lda $08
  cmp #$40
  beq @giant_x
  lda SHOTS+2,x
  clc
  adc #8
  bra @shot_x
@giant_x:
  lda SHOTS+2,x
@shot_x:
 .endif
  sec
  sbc CONTACT_CENTER_X
  bcs :+
  eor #255
  inc
:
  sta CONTACT_DELTA
  lda $0c
  clc
  adc SHOTS+6,x
  cmp CONTACT_DELTA
  bcc @next
  lda $0b
  cmp SHOTS+$0d,x
  bcc @penetrate
  beq @equal
  sec
  sbc SHOTS+$0d,x
  sta $0b
  lda #4
  sta SHOTS+8,x
  lda #$13
  sta CONTACT_SOUND
  rts
@equal:
  lda #4
  sta SHOTS+8,x
  bra @kill
@penetrate:
  lda SHOTS+$0d,x
  sec
  sbc $0b
  sta SHOTS+$0d,x
@kill:
  stz $0b
  lda $08
  cmp #$40
  bne @ordinary_sound
  lda #$0d
  bra @sound_ready
@ordinary_sound:
  lda #$0f
@sound_ready:
  sta CONTACT_SOUND
  lda SHOTS+9,x
  inc
  sta $0e
  sta CONTACT_PLAYER
  lda #1
  sta CONTACT_ACTION
  rts

large_body_contact:
  phd
  rep #$20
  lda LARGE_RECORD
  tcd
  sep #$20
  stz CONTACT_ACTION
  stz CONTACT_SOUND
  stz CONTACT_PLAYER
  jsr .loword(large_contact_center)
  jsr .loword(large_body_test)
  pld
  rtl
large_body_test:
  lda PLAYER+7,x
  beq @miss
  lda PLAYER+3,x
  clc
  adc #8
  sec
  sbc CONTACT_CENTER_Y
  bcs :+
  eor #255
  inc
:
  sta CONTACT_DELTA
  lda $0d
  clc
  adc PLAYER+$11,x
  cmp CONTACT_DELTA
  bcc @miss
  lda CONTACT_CENTER_X
  sec
  sbc PLAYER+$22,x
  bcs :+
  eor #255
  inc
:
  sta CONTACT_DELTA
  lda $0c
  clc
  adc PLAYER+$10,x
  cmp CONTACT_DELTA
  bcc @miss
  lda PLAYER+4,x
  and #1
  beq @damage
  lda PLAYER+4,x
  cmp #1
  bne @lose_wings
  lda #3
  bra @wings
@lose_wings:
  lda #8
@wings:
  sta PLAYER+4,x
  lda #1
  sta PLAYER+$0e,x
  bra @kill
@miss:
  rts
@damage:
  ; Three original RLCA operations rotate, not saturate. Only the third
  ; carry bit requests immediate death; the two earlier carries wrap.
  lda $0b
  asl
  bcc :+
  inc
:
  asl
  bcc :+
  inc
:
  asl
  bcs @death
  sta CONTACT_DELTA
  lda PLAYER+6,x
  sec
  sbc CONTACT_DELTA
  sta PLAYER+6,x
  lda #1
  sta PLAYER+$0e,x
  bcc @death
  lda #6
  bra @sound
@death:
  stz PLAYER+6,x
  lda #4
  sta PLAYER+8,x
  lda #5
@sound:
  sta CONTACT_SOUND
  jsr .loword(player_contact_energy)
@kill:
  stz $0b
  lda PLAYER+5,x
  inc
  sta $0e
  sta CONTACT_PLAYER
  lda #1
  sta CONTACT_ACTION
  rts

CONTACT_LIMIT = $1c76
CONTACT_CENTER_X = $1c78
CONTACT_CENTER_Y = $1c79
large_contact_center:
  lda $08
  cmp #$40
  beq @giant
  lda $22
  sta CONTACT_CENTER_X
  lda $03
  sta CONTACT_CENTER_Y
  rts
@giant:
  lda $42
  sta CONTACT_CENTER_X
  lda $43
  sta CONTACT_CENTER_Y
  rts

.ifdef CONTINUOUS_GAME
.pushseg
.segment "NATIVE"
; D still selects the large record; the ordered list remains in bank zero.
; D selects the four-piece object. The wave list's Y union is valid
; for unshifted shots. If any shot could wrap when adding 8, or the object
; centre could wrap when subtracting 8, fall back to the original scan.
; Carry set only when the clipped intervals are definitely disjoint.
large_shot_y_cull:
  lda SHOT_Y_MAX
  cmp #248
  bcs @maybe
  lda CONTACT_CENTER_Y
  sec
  sbc #8
  bcc @maybe
  clc
  adc $0d
  bcs @maybe
  cmp SHOT_Y_MIN
  bcc @disjoint
  lda CONTACT_CENTER_Y
  sec
  sbc #8
  sec
  sbc $0d
  bcc @maybe
  cmp SHOT_Y_MAX
  bcc @maybe
  beq @maybe
@disjoint:
  sec
  rtl
@maybe:
  lda SHOT_X_MAX
  cmp #248
  bcs @overlap
  lda CONTACT_CENTER_X
  sec
  sbc #8
  bcc @overlap
  clc
  adc $0c
  bcs @overlap
  cmp SHOT_X_MIN
  bcc @disjoint
  lda CONTACT_CENTER_X
  sec
  sbc #8
  sec
  sbc $0c
  bcc @overlap
  cmp SHOT_X_MAX
  bcc @overlap
  beq @overlap
  bra @disjoint
@overlap:
  clc
  rtl

large_list_prepare:
  lda $08
  cmp #$40
  beq @linear
  cpy #9*32
  bne :+
  ldy SHOT_ACTIVE_P2
  bra @end
:
  ldy SHOT_ACTIVE_END
@end:
  sty CONTACT_LIMIT
  cpx #0
  bne :+
  ldy #0
  bra @ready
:
  ldy SHOT_ACTIVE_P2
@ready:
  sec
  rtl
@linear:
  clc
  rtl
.popseg
.endif
