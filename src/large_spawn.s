; Large objects: the stage event spawns of boss cores and turrets (bank 4,
; control indexes CONTROL_LARGE_FIRST to CONTROL_LARGE_END-1), and the slot
; allocation of the arcade ($0782 and $07C8).
; LARGE_POOL has LARGE_COUNT slots of LARGE_SIZE (four sprite records). The
; cores use slots 0-3, then 4-5; the turrets 6-7, then 8-11, then 5 down to 0.
; A giant takes the four slots from slot 4n; its head (GIANT_HEAD) is slot
; 4n+1. The template is copied once, at the spawn.
.a8
.i16

; large_spawn: returns carry 0: not a large spawn; carry 1: handled (a full
; pool spawns nothing). JSL; A, X, Y: changed.
large_spawn:
  lda STAGE_CONTROL_INDEX
  cmp #CONTROL_LARGE_FIRST
  bcs :+
  clc
  rtl
:
  cmp #CONTROL_LARGE_END
  bcc :+
  clc
  rtl
:
  sec
  sbc #CONTROL_LARGE_FIRST
  a16
  and #255
  tax
  a8
  lda f:large_spawn_x,x
  sta LARGE_SPAWN_CROSS
  lda f:large_spawn_pattern,x
  sta LARGE_SPAWN_FIRE
  lda f:large_spawn_kind,x
  sta LARGE_SPAWN_KIND          ; 0 a core, else a turret
  beq @core
  jsr .loword(large_allocate_turret)
  bra @allocated
@core:
  jsr .loword(large_allocate_core)
@allocated:
  bcs @found
  sec
  rtl
  ; Copy the template of the kind (one record), then the upper piece.
@found:
  a16
  stx LARGE_SPAWN_SLOT
  txy
  lda LARGE_SPAWN_KIND
  and #255
  asl
  asl
  asl
  asl
  asl                           ; times OBJECT_SIZE
  tax
  .repeat OBJECT_SIZE/2
    lda f:large_spawn_templates,x
    sta LARGE_POOL,y
    inx
    inx
    iny
    iny
  .endrepeat
  ldx LARGE_SPAWN_SLOT
  a8
  lda LARGE_POOL+SPR_ATTR,x
  sta LARGE_POOL+2*SPRITE_SIZE+SPR_ATTR,x
  lda LARGE_POOL+SPR_ALONG,x
  sec
  sbc #PIECE_RISE
  sta LARGE_POOL+2*SPRITE_SIZE+SPR_ALONG,x
  lda LARGE_SPAWN_KIND
  beq :+
  lda LARGE_SPAWN_FIRE          ; a turret: its fire pattern
  sta LARGE_POOL+CORE_TURRET_FIRE,x
:
  lda LARGE_SPAWN_CROSS
  sec
  sbc CAMERA_CROSS              ; the event cross is relative to the camera
  sta LARGE_POOL+SPR_CROSS,x
  sec
  rtl

; large_allocate_core: a free core slot. Returns carry 1 and X = its offset
; in LARGE_POOL, or carry 0. A slot range with a giant in it is skipped.
large_allocate_core:
  lda LARGE_POOL+GIANT_HEAD+OBJ_TYPE
  cmp #OT_GIANT
  beq @second
  ldx #0
  ldy #4*LARGE_SIZE
  jsr .loword(large_scan_forward)
  bcc @second
  rts
@second:
  lda LARGE_POOL+4*LARGE_SIZE+GIANT_HEAD+OBJ_TYPE
  cmp #OT_GIANT
  beq large_allocate_full
  ldx #4*LARGE_SIZE
  ldy #6*LARGE_SIZE
  bra large_scan_forward
; large_allocate_turret: a free turret slot, as large_allocate_core.
large_allocate_turret:
  lda LARGE_POOL+4*LARGE_SIZE+GIANT_HEAD+OBJ_TYPE
  cmp #OT_GIANT
  beq @third
  ldx #6*LARGE_SIZE
  ldy #8*LARGE_SIZE
  jsr .loword(large_scan_forward)
  bcc @third
  rts
@third:
  lda LARGE_POOL+8*LARGE_SIZE+GIANT_HEAD+OBJ_TYPE
  cmp #OT_GIANT
  beq @reverse
  ldx #8*LARGE_SIZE
  ldy #12*LARGE_SIZE
  jsr .loword(large_scan_forward)
  bcc @reverse
  rts
@reverse:
  ldx #5*LARGE_SIZE
@back:
  lda LARGE_POOL+OBJ_TYPE,x
  beq large_allocate_found
  a16
  txa
  sec
  sbc #LARGE_SIZE
  tax
  a8
  bpl @back
large_allocate_full:
  clc
  rts
; large_scan_forward: the first free slot from X up to (not including) Y.
large_scan_forward:
  sty LARGE_SCAN_END
@slot:
  lda LARGE_POOL+OBJ_TYPE,x
  beq large_allocate_found
  a16
  txa
  clc
  adc #LARGE_SIZE
  tax
  a8
  cpx LARGE_SCAN_END
  bne @slot
  clc
  rts
large_allocate_found:
  sec
  rts
.assert GIANT_HEAD = LARGE_SIZE, error  ; the head of a giant is its second slot
.assert OBJECT_SIZE = 32, error
