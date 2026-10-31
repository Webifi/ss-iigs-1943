; Native original-US $3F2D-$3F75 and muzzle placement $3DDC-$3E00.
; A failed/full spawn still writes only the original scratch object's XY.
.a8
.i16
turret_bullet_spawn:
  phd
  rep #$20
  lda LARGE_RECORD
  tcd
  sep #$20
  ldx #BULLET_SCRATCH
  lda $01
  ora $41
  and #16
  bne @blocked
  lda $03
  cmp #40
  bcc @blocked
  lda BULLET_CONTEXT+1
  bne @blocked
  lda BULLET_CONTEXT+2
  beq @blocked
  rep #$20
  and #255
  asl
  asl
  asl
  asl
  asl
  clc
  adc #BULLETS
  sta a:$d0
  ldx #BULLETS
@slot:
  sep #$20
  lda a:8,x
  beq @found
  rep #$20
  txa
  clc
  adc #32
  tax
  cpx a:$d0
  bne @slot
  ldx #BULLET_SCRATCH
  sep #$20
@blocked:
  jmp .loword(@position)
@found:
  rep #$20
  stx a:$d2
  .repeat 16,I
    lda f:turret_bullet_template+2*I
    sta a:2*I,x
  .endrepeat
  lda TURRET_ANGLE
  and #31
  tax
  lda f:turret_bullet_paths,x
  ldx a:$d2
  sta a:$1e,x
  sep #$20
  lda TURRET_FIRE
  sta a:$0b,x
  lda #$0c
  sta PLAYER_EVENT_SOUND
@position:
  lda LARGE_AI_X
  sta a:2,x
  lda LARGE_AI_Y
  sta a:3,x
  pld
  rtl
