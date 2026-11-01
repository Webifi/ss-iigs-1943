; enemy_bullet_spawn: an aimed bullet from the object D (US arcade
; $38B2-$38FF) in a free slot among the first BULLET_SLOTS, on the
; bullet_pointers path of BULLET_SPEED and BULLET_ANGLE. Returns X = the
; bullet record, or BULLET_SCRATCH when no bullet comes; the caller may
; write its place to X either way. JSR.
.a8
.i16

enemy_bullet_spawn:
  ldx #BULLET_SCRATCH
  lda z:SPR_ATTR
  and #SPR_ALONG_HIGH
  bne @position
  lda BULLET_SUPPRESS
  bne @position
  a16
  lda BULLET_SLOTS
  and #255
  beq @no_slots
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
@no_slots:
  ldx #BULLET_SCRATCH
  a8
  bra @position
@found:
.a8
  a16
  stx a:BULLET_RECORD
  ldy #0
@copy:
  lda bullet_template,y
  sta a:0,x
  inx
  inx
  iny
  iny
  cpy #OBJECT_SIZE
  bne @copy
  ; Y = (BULLET_SPEED * DIRECTIONS + BULLET_ANGLE) * 2.
  lda BULLET_SPEED
  and #255
  asl
  asl
  asl
  asl
  asl                           ; times DIRECTIONS
  sta a:BULLET_SEARCH_END
  lda BULLET_ANGLE
  and #255
  clc
  adc a:BULLET_SEARCH_END
  asl
  tay
  lda bullet_pointers,y
  ldx a:BULLET_RECORD
  sta a:OBJ_MOTION,x
  a8
@position:
  lda z:SPR_CROSS
  sta a:SPR_CROSS,x
  lda z:SPR_ALONG
  sta a:SPR_ALONG,x
  rts
.assert OBJECT_SIZE = 32 .and DIRECTIONS = 32, error ; the ASLs above
