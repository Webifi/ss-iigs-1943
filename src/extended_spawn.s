; Native persistent ground/large enemy spawns. Templates and arguments are
; folded in the build. The extra seventeen slots preserve original $0715 order.
.a8
.i16
EXTENDED_POOL = $5a00
STAGE_GROUP_INDEX = $1b50
STAGE_GROUP_REPLAY = $1b51
EXTENDED_PLAN = $1dd0
EXTENDED_DEST = $1dd2
EXTENDED_FLAGS = $1dd4
EXTENDED_LEFT = $1dd5
EXTENDED_TEMPLATE = $1dd6
extended_spawn:
  lda STAGE_CONTROL_INDEX
  cmp #254
  beq :+
  clc
  rtl
:
  ldx #0
@find:
  lda f:extended_spawn_banks,x
  cmp STAGE_BANK
  bne @next_id
  rep #$20
  phx
  txa
  asl
  tax
  lda f:extended_spawn_ids,x
  cmp STAGE_CALLBACK
  beq @found
  plx
  sep #$20
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
  sep #$20
  lda f:$010000,x
  sta EXTENDED_LEFT
  rep #$20
  inc EXTENDED_PLAN
  sep #$20
@record:
  ldx EXTENDED_PLAN
  lda f:$010001,x
  sta EXTENDED_FLAGS
  rep #$20
  lda f:$010002,x
  sta EXTENDED_TEMPLATE
  sep #$20
  lda f:$010000,x
  beq @small
.ifdef NATIVE_LARGE_OBJECTS
  cmp #3
  bne :+
  jsr .loword(giant_allocate)
  bra @large
:
  cmp #1
  bne @turret
  jsr .loword(large_allocate_core)
  bra @large
@turret:
  jsr .loword(large_allocate_turret)
@large:
  bcs :+
  jmp .loword(@done)
:
  rep #$20
  txa
  clc
  adc #LARGE_POOL
  bra @destination
.else
  lda #$e8
  sta f:$050301
  bra @done
.endif
@small:
  jsr .loword(extended_allocate)
  bcs :+
  jmp .loword(@done)
:
  rep #$20
  txa
@destination:
  sta EXTENDED_DEST
  sep #$20
  lda EXTENDED_FLAGS
  and #2
  beq @copy
  inc STAGE_GROUP_INDEX
  lda STAGE_GROUP_INDEX
  rep #$20
  and #255
  tay
  sep #$20
.ifdef CONTINUOUS_GAME
  lda STAGE_BOSS_PHASE
.else
  lda STAGE_GROUP_REPLAY
.endif
  beq @copy
  lda LARGE_GROUPS,y
  bne :+
  jmp .loword(@advance)
:
@copy:
  rep #$20
  ldx EXTENDED_TEMPLATE
  ldy EXTENDED_DEST
  .repeat 16
    lda f:$010000,x
    sta a:0,y
    inx
    inx
    iny
    iny
  .endrepeat
  ldx EXTENDED_DEST
  sep #$20
  lda EXTENDED_FLAGS
  and #2
  beq @position
  rep #$20
  lda STAGE_GROUP_INDEX
  and #255
  tay
  sep #$20
  sta a:$0f,x
  lda a:$0b,x
  sta LARGE_GROUPS,y
  clc
  adc LARGE_THRESHOLD
  sta LARGE_THRESHOLD
@position:
  lda EXTENDED_FLAGS
  and #1
  beq @quad
  lda a:2,x
  sec
  sbc CAMERA+$0e
  sta a:2,x
@quad:
  lda EXTENDED_FLAGS
  and #4
  beq @difficulty
  lda a:1,x
  sta a:$41,x
  lda a:3,x
  sec
  sbc #16
  sta a:$43,x
  lda EXTENDED_FLAGS
  and #8
  beq @difficulty
  lda a:1,x
  sta a:$21,x
  sta a:$61,x
  stz a:$20,x
  stz a:$40,x
  stz a:$60,x
@difficulty:
  lda a:8,x
  cmp #$40
  bne :+
  lda a:1,x
  sta a:$101,x
  sta a:$141,x
  lda a:$43,x
  sec
  sbc #16
  sta a:$103,x
  sec
  sbc #16
  sta a:$143,x
:
  lda EXTENDED_FLAGS
  and #16
  bne :+
  jmp .loword(@advance)
:
  lda STAGE_DIFFICULTY+7
  cmp #9
  bcc @advance
  stz a:$12,x
@advance:
  rep #$20
  lda EXTENDED_PLAN
  clc
  adc #4
  sta EXTENDED_PLAN
  sep #$20
  dec EXTENDED_LEFT
  beq @done
  jmp .loword(@record)
@done:
  sec
  rtl

extended_allocate:
  ldx #EXTENDED_POOL
@forward:
  lda a:8,x
  beq @found
  rep #$20
  txa
  clc
  adc #32
  tax
  sep #$20
  cpx #EXTENDED_POOL+17*32
  bne @forward
  ldx #ENEMY_POOL+15*32
@reverse:
  lda a:8,x
  beq @found
  rep #$20
  txa
  sec
  sbc #32
  tax
  sep #$20
  cpx #ENEMY_POOL
  bcs @reverse
  clc
  rts
@found:
  sec
  rts
