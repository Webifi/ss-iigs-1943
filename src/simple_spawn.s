; simple_spawn: a stage event starts one or more objects from templates
; (control indexes CONTROL_SIMPLE_FIRST to CONTROL_SIMPLE_END-1). The build
; turned each arcade spawn routine into a plan (scripts/simple_spawns.py):
; for each record a template, the slot limit and a few byte patches. A full
; pool ends the plan, also after some of its records.
; Returns carry 0: not a simple spawn; carry 1: handled. JSL; A8, X16.
.a8
.i16
; The plans and the templates are in one bank: simple_spawn_plans gives
; offsets in it.
SIMPLE_DATA_BANK = .bankbyte(simple_spawn_plans) << 16
; Stage event routines (STAGE_CALLBACK) with extra rules here.
EVENT_COUNTED_SIX = $9972    ; bank 6: wave counter WC_SIX counts this formation
EVENT_RANDOM_RAID = $722f    ; fixed: spawns once in 16
EVENT_PAIR_RAID = $737d      ; fixed: two players only
EVENT_PAIR_SIX_A = $ad7e     ; bank 6: two players only
EVENT_PAIR_SIX_B = $9d8a     ; bank 6: two players only
EVENT_PAIR_SIX_C = $a377     ; bank 6: two players only
EVENT_AIR_PIECES_A = $8130   ; bank 4: the air boss pieces
EVENT_AIR_PIECES_B = $814f   ; bank 4
EVENT_AIR_PIECES_C = $817c   ; bank 4
STAGE_BANK_FOUR = 16         ; STAGE_BANK of a bank 4 event
AIR_PIECES_LIFE = 16         ; AIR_LIFE when the air boss pieces start

simple_spawn:
  lda STAGE_CONTROL_INDEX
  cmp #CONTROL_SIMPLE_FIRST
  bcs :+
  clc
  rtl
:
  cmp #CONTROL_SIMPLE_END
  bcc :+
  clc
  rtl
:
  ; SIMPLE_PLAN = the plan; SIMPLE_LEFT = its record count.
  sec
  sbc #CONTROL_SIMPLE_FIRST
  a16
  and #255
  asl
  tax
  lda f:simple_spawn_plans,x
  sta SIMPLE_PLAN
  tax
  a8
  lda f:SIMPLE_DATA_BANK,x
  sta SIMPLE_LEFT
  ; The counted bank-6 formation starts its wave counter from 0.
  lda STAGE_BANK
  cmp #STAGE_BANK_SIX
  bne :+
  a16
  lda STAGE_CALLBACK
  cmp #EVENT_COUNTED_SIX
  a8
  bne :+
  stz WAVE_COUNTS+WC_SIX
:
  ; The random raid spawns once in 16 (arcade $722F reads and updates $E00E:
  ; random stream 6, step $99).
  a16
  lda STAGE_CALLBACK
  cmp #EVENT_RANDOM_RAID
  bne @conditions
  a8
  lda RANDOM_STATE+6
  pha
  clc
  adc #$99
  sta RANDOM_STATE+6
  pla
  and #15
  beq @accepted
  sec
  rtl
  ; The two-player events spawn only when both players are in the field.
@conditions:
.a16
  cmp #EVENT_PAIR_RAID
  beq @pair_only
  lda STAGE_BANK
  and #255
  cmp #STAGE_BANK_SIX
  bne @accepted16
  lda STAGE_CALLBACK
  cmp #EVENT_PAIR_SIX_A
  beq @pair_only
  cmp #EVENT_PAIR_SIX_B
  beq @pair_only
  cmp #EVENT_PAIR_SIX_C
  bne @accepted16
@pair_only:
  a8
  lda PLAYER+PL_STATE
  beq @skip_pair
  lda PLAYER2+PL_STATE
  bne @accepted
@skip_pair:
  stz WAVE_MODIFIER
  sec
  rtl
@accepted16:
  a8
@accepted:
  ; The air boss pieces start the shared life of the pieces.
  lda STAGE_BANK
  cmp #STAGE_BANK_FOUR
  bne :+
  a16
  lda STAGE_CALLBACK
  cmp #EVENT_AIR_PIECES_A
  beq @air_pieces
  cmp #EVENT_AIR_PIECES_B
  beq @air_pieces
  cmp #EVENT_AIR_PIECES_C
  a8
  bne :+
@air_pieces:
  a8
  lda #AIR_PIECES_LIFE
  sta AIR_LIFE
:
  ; The wave counter of the first template marks a counted formation:
  ; SIMPLE_GROUP = it, and that counter starts from 0.
  ldx SIMPLE_PLAN
  a16
  lda f:SIMPLE_DATA_BANK+1+SP_TEMPLATE,x
  tax
  a8
  lda f:SIMPLE_DATA_BANK+OBJ_WAVE_COUNTER,x
  sta SIMPLE_GROUP
  beq @not_wave
  a16
  and #255
  tax
  a8
  stz WAVE_COUNTS,x
@not_wave:
  a16
  inc SIMPLE_PLAN               ; past the record count: the first record
  a8
  ; One record: find a free slot among the first SP_CAPACITY records (0:
  ; STAGE_SPAWN_SLOTS); no slot ends the plan.
@next:
  ldx SIMPLE_PLAN
  lda f:SIMPLE_DATA_BANK+SP_CAPACITY,x
  bne @limit
  lda STAGE_SPAWN_SLOTS
  beq @done
@limit:
  a16
  and #255
  asl                           ; times OBJECT_SIZE
  asl
  asl
  asl
  asl
  sta SIMPLE_LIMIT
  ldx #0
@scan:
  a8
  lda ENEMY_POOL+OBJ_TYPE,x
  beq @found
  a16
  txa
  clc
  adc #OBJECT_SIZE
  tax
  cpx SIMPLE_LIMIT
  bcc @scan
@done:
  a8
  sec
  rtl
  ; Copy the template into the free record at SIMPLE_DEST.
@found:
  a16
  stx SIMPLE_DEST
  txy
  ldx SIMPLE_PLAN
  lda f:SIMPLE_DATA_BANK+SP_TEMPLATE,x
  sta SIMPLE_TEMPLATE
  a8
  lda f:SIMPLE_DATA_BANK+SP_PATCH_COUNT,x
  sta SIMPLE_PATCHES
  a16
  txa
  clc
  adc #SP_RECORD_SIZE
  sta SIMPLE_PLAN
  ldx SIMPLE_TEMPLATE
  .repeat OBJECT_SIZE/2
    lda f:SIMPLE_DATA_BANK,x
    sta ENEMY_POOL,y
    inx
    inx
    iny
    iny
  .endrepeat
  ; Each patch writes one byte of the new record.
  a8
  lda SIMPLE_PATCHES
  beq @patched
@patch:
  ldx SIMPLE_PLAN
  a16
  lda f:SIMPLE_DATA_BANK,x      ; the offset in the record
  and #255
  clc
  adc SIMPLE_DEST
  tay
  a8
  lda f:SIMPLE_DATA_BANK+1,x    ; the value
  sta ENEMY_POOL,y
  a16
  inc SIMPLE_PLAN
  inc SIMPLE_PLAN               ; SP_PATCH_SIZE
  a8
  dec SIMPLE_PATCHES
  bne @patch
  ; A counted plane takes the wave's drop (WAVE_MODIFIER) and counts itself.
@patched:
  ldx SIMPLE_DEST
  lda ENEMY_POOL+OBJ_WAVE_COUNTER,x
  beq @counted
  lda WAVE_MODIFIER
  sta ENEMY_POOL+OBJ_DROP,x
  lda ENEMY_POOL+OBJ_WAVE_COUNTER,x
  a16
  and #255
  tax
  a8
  inc WAVE_COUNTS,x
@counted:
  dec SIMPLE_LEFT
  bne :+
  lda SIMPLE_GROUP
  beq @return
  stz WAVE_MODIFIER             ; the formation has its drop now
@return:
  sec
  rtl
:
  jmp .loword(@next)
.assert SP_RECORD_SIZE = SP_PATCH_COUNT+1 .and SP_PATCH_SIZE = 2, error
