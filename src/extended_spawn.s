; extended_spawn: a stage event (CONTROL_EXTENDED) starts ground objects,
; boss cores, turrets or giants that stay for a while. The build folded each
; arcade spawn routine into a plan of records (scripts/extended_spawns.py):
; the pool kind (EX_*), flags (EXF_*) and a template. Small ones use the
; seventeen extra slots first, in the arcade's $0715 order.
; Returns carry 0: no plan for this event; carry 1: handled. JSL; A8, X16.
.a8
.i16
; The plans and the templates are in one bank: extended_spawn_plans gives
; offsets in it.
EXTENDED_DATA_BANK = .bankbyte(extended_spawn_plans) << 16
DIFFICULTY_CLEAR = 9         ; EXF_DIFFICULTY: from this DIP level, OBJ_FAMILY+2 is 0

extended_spawn:
  lda STAGE_CONTROL_INDEX
  cmp #CONTROL_EXTENDED
  beq :+
  clc
  rtl
:
  ; Find the plan of this event: its bank and its routine (STAGE_CALLBACK).
  ldx #0
@find:
  lda f:extended_spawn_banks,x
  cmp STAGE_BANK
  bne @next_id
  a16
  phx
  txa
  asl
  tax
  lda f:extended_spawn_ids,x
  cmp STAGE_CALLBACK
  beq @found
  plx
  a8
@next_id:
  inx
  cpx #EXTENDED_SPAWN_COUNT
  bne @find
  clc
  rtl
@found:
  lda f:extended_spawn_plans,x
  sta EXTENDED_PLAN
  plx
  ldx EXTENDED_PLAN
  a8
  lda f:EXTENDED_DATA_BANK,x
  sta EXTENDED_LEFT             ; the record count
  a16
  inc EXTENDED_PLAN
  a8
  ; One record: take a record of its pool (EX_KIND); a full pool ends the plan.
@record:
  ldx EXTENDED_PLAN
  lda f:EXTENDED_DATA_BANK+EX_FLAGS,x
  sta EXTENDED_FLAGS
  a16
  lda f:EXTENDED_DATA_BANK+EX_TEMPLATE,x
  sta EXTENDED_TEMPLATE
  a8
  lda f:EXTENDED_DATA_BANK+EX_KIND,x
  beq @small                    ; EX_SMALL
  cmp #EX_GIANT
  bne :+
  jsr .loword(giant_allocate)
  bra @large
:
  cmp #EX_CORE
  bne @turret
  jsr .loword(large_allocate_core)
  bra @large
@turret:
  jsr .loword(large_allocate_turret)
@large:
  bcs :+
  jmp .loword(@done)
:
  a16
  txa
  clc
  adc #LARGE_POOL               ; X is the offset in LARGE_POOL
  bra @destination
.a8
@small:
  jsr .loword(extended_allocate)
  bcs :+
  jmp .loword(@done)
:
  a16
  txa
@destination:
  sta EXTENDED_DEST
  ; EXF_GROUP: a boss part with a damage ledger slot (STAGE_GROUP_INDEX). In
  ; the boss replay a part whose ledger slot is empty (destroyed) stays away.
  a8
  lda EXTENDED_FLAGS
  and #EXF_GROUP
  beq @copy
  inc STAGE_GROUP_INDEX
  lda STAGE_GROUP_INDEX
  a16
  and #255
  tay
  a8
  lda STAGE_BOSS_PHASE
  beq @copy
  lda LARGE_GROUPS,y
  bne :+
  jmp .loword(@advance)
:
@copy:
  a16
  ldx EXTENDED_TEMPLATE
  ldy EXTENDED_DEST
  .repeat OBJECT_SIZE/2
    lda f:EXTENDED_DATA_BANK,x
    sta a:0,y                   ; Y holds the record address
    inx
    inx
    iny
    iny
  .endrepeat
  ldx EXTENDED_DEST
  a8
  ; A boss part: its ledger slot keeps its HP; LARGE_THRESHOLD grows by it.
  lda EXTENDED_FLAGS
  and #EXF_GROUP
  beq @position
  a16
  lda STAGE_GROUP_INDEX
  and #255
  tay
  a8
  sta a:OBJ_LEDGER,x
  lda a:OBJ_HP,x
  sta LARGE_GROUPS,y
  clc
  adc LARGE_THRESHOLD
  sta LARGE_THRESHOLD
@position:
  ; EXF_RELATIVE: the template cross is relative to the camera.
  lda EXTENDED_FLAGS
  and #EXF_RELATIVE
  beq @quad
  lda a:SPR_CROSS,x
  sec
  sbc CAMERA_CROSS
  sta a:SPR_CROSS,x
@quad:
  ; EXF_QUAD: the upper piece (record 2) above the head; EXF_CLEAR: records
  ; 1-3 take the head's colour and show nothing yet.
  lda EXTENDED_FLAGS
  and #EXF_QUAD
  beq @difficulty
  lda a:SPR_ATTR,x
  sta a:2*SPRITE_SIZE+SPR_ATTR,x
  lda a:SPR_ALONG,x
  sec
  sbc #PIECE_RISE
  sta a:2*SPRITE_SIZE+SPR_ALONG,x
  lda EXTENDED_FLAGS
  and #EXF_CLEAR
  beq @difficulty
  lda a:SPR_ATTR,x
  sta a:SPRITE_SIZE+SPR_ATTR,x
  sta a:3*SPRITE_SIZE+SPR_ATTR,x
  stz a:SPRITE_SIZE+SPR_CODE,x
  stz a:2*SPRITE_SIZE+SPR_CODE,x
  stz a:3*SPRITE_SIZE+SPR_CODE,x
@difficulty:
  ; A giant: records 8 and 10 take the head's colour, each PIECE_RISE above
  ; the last.
  lda a:OBJ_TYPE,x
  cmp #OT_GIANT
  bne :+
  lda a:SPR_ATTR,x
  sta a:8*SPRITE_SIZE+SPR_ATTR,x
  sta a:10*SPRITE_SIZE+SPR_ATTR,x
  lda a:2*SPRITE_SIZE+SPR_ALONG,x
  sec
  sbc #PIECE_RISE
  sta a:8*SPRITE_SIZE+SPR_ALONG,x
  sec
  sbc #PIECE_RISE
  sta a:10*SPRITE_SIZE+SPR_ALONG,x
:
  ; EXF_DIFFICULTY: from DIP level DIFFICULTY_CLEAR on, family byte 2 is 0.
  lda EXTENDED_FLAGS
  and #EXF_DIFFICULTY
  bne :+
  jmp .loword(@advance)
:
  lda STAGE_DIP_LEVEL
  cmp #DIFFICULTY_CLEAR
  bcc @advance
  stz a:OBJ_FAMILY+2,x
@advance:
  a16
  lda EXTENDED_PLAN
  clc
  adc #EX_RECORD_SIZE
  sta EXTENDED_PLAN
  a8
  dec EXTENDED_LEFT
  beq @done
  jmp .loword(@record)
@done:
  sec
  rtl

; extended_allocate: a free small-object record: the first free one of
; EXTENDED_POOL, else the last free one of ENEMY_POOL. Returns carry 1 and
; X = its address, or carry 0 when both pools are full.
extended_allocate:
  ldx #EXTENDED_POOL
@forward:
  lda a:OBJ_TYPE,x
  beq @found
  a16
  txa
  clc
  adc #OBJECT_SIZE
  tax
  a8
  cpx #EXTENDED_POOL+EXTENDED_COUNT*OBJECT_SIZE
  bne @forward
  ldx #ENEMY_POOL+(ENEMY_COUNT-1)*OBJECT_SIZE
@reverse:
  lda a:OBJ_TYPE,x
  beq @found
  a16
  txa
  sec
  sbc #OBJECT_SIZE
  tax
  a8
  cpx #ENEMY_POOL
  bcs @reverse
  clc
  rts
@found:
  sec
  rts
.assert EX_SMALL = 0, error     ; @record tests it with BEQ
