; stationary_wave_motion: the move of a small enemy (wave_combat_tick). An
; object that follows a camera that does not move only checks the field;
; others run enemy_motion. JSR.
stationary_wave_motion:
  lda z:OBJ_FLAGS
  and #OF_CAMERA
  beq @ordinary
  lda ENEMY_CAM_X
  ora ENEMY_CAM_Y
  bne @ordinary
  stz ENEMY_RETIRED
  stz z:OBJ_CROSS_DELTA
  stz z:OBJ_CROSS_DELTA+1
  lda z:SPR_CROSS
  cmp #ENEMY_CROSS_END
  bcs @retire
  stz z:OBJ_ALONG_DELTA
  stz z:OBJ_ALONG_DELTA+1
  lda z:SPR_ATTR
  and #SPR_ALONG_HIGH
  beq @inside
  lda z:SPR_ALONG
  beq @inside
  cmp #ENEMY_ALONG_OUT
  bcc @retire
@inside:
  dec z:OBJ_DURATION
  rts
@ordinary:
  jmp enemy_motion
@retire:
  jmp enemy_retire
