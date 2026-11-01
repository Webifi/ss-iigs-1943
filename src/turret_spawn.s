; turret_spawn: a stage event starts a ship turret (bank 6, control indexes
; CONTROL_TURRET_FIRST to CONTROL_TURRET_END-1; src/stage.s sets
; TURRET_SPAWN_ID). Each turret is a boss part with its own ledger slot
; (TURRET_GROUP), as the arcade's group helper at $30B8-$3116. In the boss
; replay (TURRET_RETRY) a destroyed turret stays away. JSL; A8, X16.
.a8
.i16

turret_spawn:
  a16
  lda TURRET_SPAWN_ID
  and #255
  tax
  a8
  lda f:turret_spawn_x,x
  sta TURRET_SPAWN_X
  lda f:turret_spawn_kind,x
  a16
  and #255
  asl
  asl
  asl
  asl
  asl                           ; times OBJECT_SIZE: the template
  sta TURRET_TEMPLATE
  a8
  jsr .loword(large_allocate_turret)
  bcs :+
  rtl                           ; no free slot
:
  stx TURRET_DEST
  inc TURRET_GROUP
  a16
  lda TURRET_GROUP
  and #255
  tay
  a8
  lda TURRET_RETRY
  beq @copy
  lda LARGE_GROUPS,y
  bne @copy
  rtl
@copy:
  a16
  txy
  ldx TURRET_TEMPLATE
  .repeat OBJECT_SIZE/2
    lda f:turret_spawn_templates,x
    sta LARGE_POOL,y
    inx
    inx
    iny
    iny
  .endrepeat
  ; The ledger slot keeps the HP; LARGE_THRESHOLD grows by it.
  lda TURRET_GROUP
  and #255
  tay
  ldx TURRET_DEST
  a8
  sta LARGE_POOL+OBJ_LEDGER,x
  lda LARGE_POOL+OBJ_HP,x
  sta LARGE_GROUPS,y
  clc
  adc LARGE_THRESHOLD
  sta LARGE_THRESHOLD
  ; The upper piece, and the cross relative to the camera.
  lda LARGE_POOL+SPR_ATTR,x
  sta LARGE_POOL+2*SPRITE_SIZE+SPR_ATTR,x
  lda LARGE_POOL+SPR_ALONG,x
  sec
  sbc #PIECE_RISE
  sta LARGE_POOL+2*SPRITE_SIZE+SPR_ALONG,x
  lda TURRET_SPAWN_X
  sec
  sbc CAMERA_CROSS
  sta LARGE_POOL+SPR_CROSS,x
  rtl
.assert OBJECT_SIZE = 32, error
