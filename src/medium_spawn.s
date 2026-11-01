; medium_spawn: a stage event starts one medium plane (control indexes
; CONTROL_MEDIUM_FIRST to CONTROL_MEDIUM_END-1). The build chose the tables
; (scripts/medium_enemies.py); the template is copied once, at the spawn.
; Returns carry 0: not a medium spawn; carry 1: handled (spawned, or no free
; slot among the first STAGE_SPAWN_SLOTS). JSL; A8, X16. A, X, Y: changed.
.a8
.i16
medium_spawn:
  lda STAGE_CONTROL_INDEX
  cmp #CONTROL_MEDIUM_FIRST
  bcs :+
  clc
  rtl
:
  cmp #CONTROL_MEDIUM_END
  bcc :+
  clc
  rtl
:
  a16
  and #$7f                      ; the index in the medium tables
  tax
  a8
  lda f:medium_spawn_x,x
  sta SPAWN_CROSS
  lda f:medium_spawn_template,x
  sta SPAWN_TEMPLATE
  stz SPAWN_TEMPLATE+1
  lda STAGE_SPAWN_SLOTS
  bne :+
  sec                           ; no slots for spawns now
  rtl
:
  ; Search the first STAGE_SPAWN_SLOTS records of ENEMY_POOL for a free one.
  a16
  and #255
  asl
  asl
  asl
  asl
  asl                           ; times OBJECT_SIZE
  sta SPAWN_SEARCH_END
  ldx #0
@slot:
  a8
  lda ENEMY_POOL+OBJ_TYPE,x
  beq @found
  a16
  txa
  clc
  adc #OBJECT_SIZE
  tax
  cpx SPAWN_SEARCH_END
  bne @slot
  a8
  sec
  rtl
  ; Copy the template, then place the plane at SPAWN_CROSS.
@found:
  a16
  txy
  ldx SPAWN_TEMPLATE
  .repeat OBJECT_SIZE/2
    lda f:medium_spawn_templates,x
    sta ENEMY_POOL,y
    inx
    inx
    iny
    iny
  .endrepeat
  tya
  sec
  sbc #OBJECT_SIZE              ; Y passed the record: X = the record again
  tax
  a8
  lda SPAWN_CROSS
  sta ENEMY_POOL+SPR_CROSS,x
  sec
  rtl
.assert CONTROL_MEDIUM_FIRST = $80 .and CONTROL_MEDIUM_END <= $100, error
.assert OBJECT_SIZE = 32, error
