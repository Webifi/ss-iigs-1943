; Original-US $55B1-$5621 movement with $5E6F/$5E80 camera attachment.
; ENEMY is a 32-byte native record followed by camera dx, dy and retire output.
; Caller owns script stepping, collision, score/drop processing on retirement.
.a8
.i16
.ifndef ENEMY
ENEMY = $1000
.endif
.ifndef ENEMY_CAM_X
ENEMY_CAM_X = ENEMY+32
ENEMY_CAM_Y = ENEMY+33
ENEMY_RETIRED = ENEMY+34
.endif

enemy_motion:
  stz ENEMY_RETIRED
  lda ENEMY+9
  and #4
  beq @x_velocity
  lda ENEMY_CAM_X
  sta ENEMY+$18
  stz ENEMY+$19
@x_velocity:
  rep #$20
  lda ENEMY+$18
  xba
  sta $d0
  lda ENEMY+5
  and #255
  sta $d2
  lda ENEMY+2
  and #255
  xba
  ora $d2
  clc
  adc $d0
  cmp #$f800
  bcc @x_inside
  sep #$20
  jmp enemy_retire
@x_inside:
  sep #$20
  sta ENEMY+5
  xba
  sta ENEMY+2
  lda ENEMY+9
  and #4
  beq @y_velocity
  lda ENEMY_CAM_Y
  sta ENEMY+$1a
  stz ENEMY+$1b
@y_velocity:
  rep #$20
  lda ENEMY+$1a
  xba
  sta $d0
  lda ENEMY+6
  and #255
  sta $d2
  lda ENEMY+3
  and #255
  xba
  ora $d2
  clc
  adc $d0
  sep #$20
  sta ENEMY+6
  xba
  sta ENEMY+3
  bcc @no_carry
  lda ENEMY+$1a
  bmi @wrapped
  bra @toggle
@no_carry:
  lda ENEMY+$1a
  bpl @wrapped
@toggle:
  lda ENEMY+1
  eor #$10
  sta ENEMY+1
@wrapped:
  lda ENEMY+1
  and #$10
  beq @inside
  lda ENEMY+3
  beq @inside
  cmp #$f0
  bcc enemy_retire
@inside:
  dec ENEMY+4
  rts

enemy_retire:
.ifdef ENEMY_SPECIAL_CONTACT
  lda ENEMY+2
  sta ENEMY_RETIRE_X
.endif
  stz ENEMY
  stz ENEMY+8
  stz ENEMY+2
  lda #1
  sta ENEMY_RETIRED
  rts
