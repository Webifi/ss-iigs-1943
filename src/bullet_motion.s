; Original-US enemy bullet motion, $5FFF-$6068 and $61DE-$61E8.
; Same fixed-point representation as enemies, with the bullet-specific limits.
.a8
.i16
.ifndef ENEMY
ENEMY = $1100
.endif
.ifndef ENEMY_RETIRED
ENEMY_RETIRED = $1132
.endif

bullet_motion:
  stz ENEMY_RETIRED
  clc
  lda ENEMY+5
  adc ENEMY+$19
  sta $d2
  lda ENEMY+2
  adc ENEMY+$18
  cmp #$f5
  bcc @x_inside
  jmp bullet_retire
@x_inside:
  sta ENEMY+2
  lda $d2
  sta ENEMY+5
  clc
  lda ENEMY+6
  adc ENEMY+$1b
  sta ENEMY+6
  lda ENEMY+3
  adc ENEMY+$1a
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
  cmp #$e8
  bcc bullet_retire
@inside:
  dec ENEMY+4
  rts
bullet_retire:
  stz ENEMY
  stz ENEMY+8
  stz ENEMY+2
  lda #1
  sta ENEMY_RETIRED
  rts
