; The move of an enemy bullet (US arcade $5FFF-$6068 and $61DE-$61E8): as
; enemy_motion, with the bullet limits and no camera follow. D = the record.
.a8
.i16
BULLET_CROSS_END = $f5       ; at this cross the bullet retires
BULLET_ALONG_OUT = $e8       ; with SPR_ALONG_HIGH: along 1..BULLET_ALONG_OUT-1 retires

; bullet_motion: one move; off the field ENEMY_RETIRED = 1. JSR.
bullet_motion:
  stz ENEMY_RETIRED
  clc
  lda z:OBJ_CROSS_FRACTION
  adc z:OBJ_CROSS_DELTA+1
  sta a:MOTION_FRACTION
  lda z:SPR_CROSS
  adc z:OBJ_CROSS_DELTA
  cmp #BULLET_CROSS_END
  bcc @x_inside
  jmp bullet_retire
@x_inside:
  sta z:SPR_CROSS
  lda a:MOTION_FRACTION
  sta z:OBJ_CROSS_FRACTION
  clc
  lda z:OBJ_ALONG_FRACTION
  adc z:OBJ_ALONG_DELTA+1
  sta z:OBJ_ALONG_FRACTION
  lda z:SPR_ALONG
  adc z:OBJ_ALONG_DELTA
  sta z:SPR_ALONG
  bcc @no_carry
  lda z:OBJ_ALONG_DELTA
  bmi @wrapped                  ; a negative move with a carry: no wrap
  bra @toggle
@no_carry:
  lda z:OBJ_ALONG_DELTA
  bpl @wrapped
@toggle:
  lda z:SPR_ATTR
  eor #SPR_ALONG_HIGH
  sta z:SPR_ATTR
@wrapped:
  lda z:SPR_ATTR
  and #SPR_ALONG_HIGH
  beq @inside
  lda z:SPR_ALONG
  beq @inside
  cmp #BULLET_ALONG_OUT
  bcc bullet_retire
@inside:
  dec z:OBJ_DURATION
  rts
; bullet_retire: the bullet goes; ENEMY_RETIRED = 1.
bullet_retire:
  stz z:SPR_CODE
  stz z:OBJ_TYPE
  stz z:SPR_CROSS
  lda #1
  sta ENEMY_RETIRED
  rts
