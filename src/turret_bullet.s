; turret_bullet_spawn: a bullet from the ship turret at LARGE_RECORD at the
; muzzle LARGE_AI_X/Y (US arcade $3F2D-$3F75 and $3DDC-$3E00). The bullet
; takes the first free record of the BULLET_SLOTS records of BULLETS; its
; speed class (TURRET_FIRE) is kept in OBJ_HP. A turret off the field, near
; the bottom, or a full pool writes the muzzle into BULLET_SCRATCH only, as
; the arcade does. JSL; A8, X16.
.a8
.i16
TURRET_FIRE_ALONG = 40       ; below this along the turret does not fire

turret_bullet_spawn:
  phd
  a16
  lda LARGE_RECORD
  tcd
  a8
  ldx #BULLET_SCRATCH
  lda SPR_ATTR
  ora 2*SPRITE_SIZE+SPR_ATTR
  and #SPR_ALONG_HIGH
  bne @blocked
  lda SPR_ALONG
  cmp #TURRET_FIRE_ALONG
  bcc @blocked
  lda BULLET_SUPPRESS
  bne @blocked
  lda BULLET_SLOTS
  beq @blocked
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
@blocked:
  jmp .loword(@position)
@found:
  ; Copy the template, then the motion of the barrel direction.
  a16
  stx a:BULLET_RECORD
  .repeat OBJECT_SIZE/2,I
    lda f:turret_bullet_template+2*I
    sta a:2*I,x
  .endrepeat
  lda TURRET_ANGLE
  and #31
  tax
  lda f:turret_bullet_paths,x
  ldx a:BULLET_RECORD
  sta a:OBJ_MOTION,x
  a8
  lda TURRET_FIRE
  sta a:OBJ_HP,x
  lda #SND_TURRET_SHOT
  jsl game_sound_request        ; arcade $3F70
@position:
  lda LARGE_AI_X
  sta a:SPR_CROSS,x
  lda LARGE_AI_Y
  sta a:SPR_ALONG,x
  pld
  rtl
