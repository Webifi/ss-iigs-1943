; The move of a small enemy (US arcade $55B1-$5621, with the camera follow
; of $5E6F/$5E80). D = the object record. The caller runs the script, the
; contacts, and the score and the drop of a retired object.
.a8
.i16
ENEMY_CROSS_END = $f8        ; at this cross the object retires
ENEMY_ALONG_OUT = $f0        ; with SPR_ALONG_HIGH: along 1..ENEMY_ALONG_OUT-1 retires

; enemy_motion: move by the 8.8 moves (or by the camera move ENEMY_CAM_X/Y,
; with OF_CAMERA); a carry in the move direction toggles SPR_ALONG_HIGH. Off
; the field the object retires: ENEMY_RETIRED = 1. JSR.
enemy_motion:
  stz ENEMY_RETIRED
  lda z:OBJ_FLAGS
  and #OF_CAMERA
  beq @x_velocity
  lda ENEMY_CAM_X
  sta z:OBJ_CROSS_DELTA
  stz z:OBJ_CROSS_DELTA+1
@x_velocity:
  clc
  lda z:OBJ_CROSS_FRACTION
  adc z:OBJ_CROSS_DELTA+1
  sta a:MOTION_FRACTION
  lda z:SPR_CROSS
  adc z:OBJ_CROSS_DELTA
  cmp #ENEMY_CROSS_END
  bcc @x_inside
  jmp enemy_retire
@x_inside:
  sta z:SPR_CROSS
  lda a:MOTION_FRACTION
  sta z:OBJ_CROSS_FRACTION
  lda z:OBJ_FLAGS
  and #OF_CAMERA
  beq @y_velocity
  lda ENEMY_CAM_Y
  sta z:OBJ_ALONG_DELTA
  stz z:OBJ_ALONG_DELTA+1
@y_velocity:
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
  cmp #ENEMY_ALONG_OUT
  bcc enemy_retire
@inside:
  dec z:OBJ_DURATION
  rts

; enemy_retire: the object leaves the field: ENEMY_RETIRE_X keeps its cross
; for the drop; ENEMY_RETIRED = 1.
enemy_retire:
  lda z:SPR_CROSS
  sta ENEMY_RETIRE_X
  stz z:SPR_CODE
  stz z:OBJ_TYPE
  stz z:SPR_CROSS
  lda #1
  sta ENEMY_RETIRED
  rts
