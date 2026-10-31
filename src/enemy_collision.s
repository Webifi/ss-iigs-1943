; Original-US ordinary enemy/player-shot hit test and damage $5632-$56F6.
; Caller already checked the collision phase, flags and ordinary enemy type.
; ENEMY_KILLED requests the separately owned death/score/drop transition.
.a8
.i16
.ifndef ENEMY
ENEMY = $1100
.endif
.ifndef PLAYER
PLAYER = $1000
.endif
.ifndef SHOTS
SHOTS = $1800
.endif
ENEMY_KILLED = $17f6
ENEMY_HIT_SOUND = $17f7
.ifdef CONTINUOUS_GAME
SHOT_ACTIVE = $1b80            ; eighteen slot offsets, stable for this tick
SHOT_ACTIVE_END = $1ba4
SHOT_ACTIVE_P2 = $1ba6
SHOT_Y_MIN = $1ba8
SHOT_Y_MAX = $1ba9
; Recomputed only on the even-phase shot-list pass; the air-boss state
; begins at $1bb0 and sound's queue ends before the list at $1b80.
SHOT_X_MIN = $1baa
SHOT_X_MAX = $1bab
.assert SHOT_X_MAX < $1bb0, error, "shot bounds overlap air-boss state"
.endif

enemy_shot_collision:
  stz ENEMY_KILLED
  stz ENEMY_HIT_SOUND
.ifdef CONTINUOUS_GAME
  ; The clipped union may admit false positives, but cannot exclude a hit.
  lda ENEMY+3
  clc
  adc ENEMY+$0d
  bcs :+
  cmp SHOT_Y_MIN
  bcs :+
  rts
:
  lda ENEMY+3
  sec
  sbc ENEMY+$0d
  bcc :+
  cmp SHOT_Y_MAX
  bcc :+
  beq :+
  rts
:
  ; As with Y, saturating the union only adds false positives. Carry on
  ; either edge disables that rejection, preserving byte-wrap hit rules.
  lda ENEMY+2
  clc
  adc ENEMY+$0c
  bcs :+
  cmp SHOT_X_MIN
  bcs :+
  rts
:
  lda ENEMY+2
  sec
  sbc ENEMY+$0c
  bcc :+
  cmp SHOT_X_MAX
  bcc :+
  beq :+
  rts
:
.endif
  ldx #0
  ldy #9*32
  lda PLAYER+8
  cmp #2
  beq @p1
  lda PLAYER+$88
  cmp #2
  beq @p2
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
  cpy #9*32
  bne :+
  ldy SHOT_ACTIVE_P2
  bra @list_end
:
  ldy SHOT_ACTIVE_END
@list_end:
  sty $dc
  cpx #0
  bne :+
  ldy #0
  bra @list_start
:
  ldy SHOT_ACTIVE_P2
@list_start:
  cpy $dc
  bne @slot
  rts
.else
  sty $dc
.endif
@slot:
.ifdef CONTINUOUS_GAME
  ldx SHOT_ACTIVE,y
.endif
  lda SHOTS+8,x
  cmp #2
  bne @next
  lda SHOTS+3,x
  sec
  sbc ENEMY+3
  bcs @y_abs
  eor #255
  inc
@y_abs:
  sta $de
  lda SHOTS+7,x
  clc
  adc ENEMY+$0d
  cmp $de
  bcc @next
  lda SHOTS+2,x
  sec
  sbc ENEMY+2
  bcs @x_abs
  eor #255
  inc
@x_abs:
  sta $de
  lda SHOTS+6,x
  clc
  adc ENEMY+$0c
  cmp $de
  bcc @next
 .ifdef ENEMY_SPECIAL_CONTACT
  lda ENEMY+$0a
  and #15
  bne enemy_pickup_shot
 .endif
  lda ENEMY+$0b
  cmp SHOTS+$0d,x
  bcc @penetrate
  beq @equal
  sec
  sbc SHOTS+$0d,x
  sta ENEMY+$0b
  lda #4
  sta SHOTS+8,x
  lda #$13
  sta ENEMY_HIT_SOUND
  rts
@equal:
  lda #4
  sta SHOTS+8,x
  bra @killed
@penetrate:
  lda SHOTS+$0d,x
  sec
  sbc ENEMY+$0b
  sta SHOTS+$0d,x
@killed:
  stz ENEMY+$0b
  lda #$0e
  sta ENEMY_HIT_SOUND
  lda SHOTS+9,x
  inc
  sta ENEMY+$0e
  lda #1
  sta ENEMY_KILLED
  rts
@next:
.ifdef CONTINUOUS_GAME
  iny
  iny
  cpy $dc
.else
  rep #$20
  txa
  clc
  adc #32
  tax
  sep #$20
  cpx $dc
.endif
  beq @done
  jmp @slot
@done:
  rts

.ifdef ENEMY_SPECIAL_CONTACT
; US $5922-$594D: nudge the item, consume this shot, then test its HP.
enemy_pickup_shot:
  lda #4
  sta SHOTS+8,x
  lda ENEMY+3
  clc
  adc #4
  bcs @retire
  sta ENEMY+3
  lda ENEMY+$0b
  cmp #255
  beq @done
  dec ENEMY+$0b
  bne @done
  stz ENEMY+$0e
  lda ENEMY+$0a
  and #15
  cmp #2
  bne @killed
  lda SHOTS+9,x
  inc
  sta ENEMY+$0e
@killed:
  lda #1
  sta ENEMY_KILLED
@done:
  rts
@retire:
  lda #2
  sta ENEMY_KILLED
  rts
.endif
