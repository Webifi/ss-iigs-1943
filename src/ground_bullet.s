; ground_bullet_spawn: a ground bullet from the object D (US arcade $3E4D)
; in a free slot among the first BULLET_SLOTS, at the direction GROUND_ANGLE
; (ground_bullet_paths) with GROUND_SPEED straight decisions (ground_ai).
; Returns X = the bullet record, or BULLET_SCRATCH when no bullet comes (off
; the field, BULLET_SUPPRESS, no free slot); the caller may write its place
; to X either way. JSR.
.a8
.i16

ground_bullet_spawn:
  ldx #BULLET_SCRATCH
  lda z:SPR_ATTR
  and #SPR_ALONG_HIGH
  beq :+
  jmp @position
:
  lda BULLET_SUPPRESS
  beq :+
  jmp @position
:
  lda BULLET_SLOTS
  bne :+
  jmp @position
:
  a16
  and #255
  asl
  asl
  asl
  asl
  asl                           ; times OBJECT_SIZE
  clc
  adc #BULLETS
  sta a:BULLET_SEARCH_END
  ldx #BULLETS
@slot:
  a8
  lda a:OBJ_TYPE,x
  beq @found
  a16
  txa
  clc
  adc #OBJECT_SIZE
  tax
  cpx a:BULLET_SEARCH_END
  bne @slot
  ldx #BULLET_SCRATCH
  a8
  jmp @position
@found:
  a16
  .repeat OBJECT_SIZE/2,I
    lda f:ground_bullet_template+I*2
    sta a:I*2,x
  .endrepeat
  phx
  lda GROUND_ANGLE
  and #255
  tax
  lda f:ground_bullet_paths,x
  sec
  sbc #STEP_SIZE                ; the script reads OBJ_MOTION + STEP_SIZE
  plx
  sta a:OBJ_MOTION,x
  a8
  lda GROUND_SPEED
  sta a:GROUND_BULLET_STRAIGHT,x
  lda GROUND_ANGLE
  sta a:GROUND_BULLET_DIRECTION,x
@position:
  lda z:SPR_CROSS
  sta a:SPR_CROSS,x
  lda z:SPR_ALONG
  sta a:SPR_ALONG,x
  rts
