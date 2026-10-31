; Native original-US $0782/$07C8 allocation and bank-4 core/turret spawns.
; The complete twelve-head pool stays in place. Copies happen only at spawn.
.a8
.i16
LARGE_POOL = $5400
LARGE_SPAWN_SLOT = $1c48
LARGE_SPAWN_KIND = $1c4a

large_spawn:
  lda STAGE_CONTROL_INDEX
  cmp #140
  bcs :+
  clc
  rtl
:
  cmp #149
  bcc :+
  clc
  rtl
:
  sec
  sbc #140
  rep #$20
  and #255
  tax
  sep #$20
  lda f:large_spawn_x,x
  sta $d0
  lda f:large_spawn_pattern,x
  sta $d1
  lda f:large_spawn_kind,x
  sta LARGE_SPAWN_KIND
  beq @core
  jsr .loword(large_allocate_turret)
  bra @allocated
@core:
  jsr .loword(large_allocate_core)
@allocated:
  bcs @found
  sec                         ; recognized event; full pool means no spawn
  rtl
@found:
  rep #$20
  stx LARGE_SPAWN_SLOT
  txy
  lda LARGE_SPAWN_KIND
  and #255
  asl
  asl
  asl
  asl
  asl
  tax
  .repeat 16
    lda f:large_spawn_templates,x
    sta LARGE_POOL,y
    inx
    inx
    iny
    iny
  .endrepeat
  ldx LARGE_SPAWN_SLOT
  sep #$20
  lda LARGE_POOL+1,x
  sta LARGE_POOL+$41,x
  lda LARGE_POOL+3,x
  sec
  sbc #16
  sta LARGE_POOL+$43,x
  lda LARGE_SPAWN_KIND
  beq :+
  lda $d1
  sta LARGE_POOL+$12,x
:
  lda $d0
  sec
  sbc CAMERA+$0e
  sta LARGE_POOL+2,x
  sec
  rtl

large_allocate_core:
  lda LARGE_POOL+$88
  cmp #$40
  beq @second
  ldx #0
  ldy #4*128
  jsr .loword(large_scan_forward)
  bcc @second
  rts
@second:
  lda LARGE_POOL+5*128+8
  cmp #$40
  beq large_allocate_full
  ldx #4*128
  ldy #6*128
  bra large_scan_forward
large_allocate_turret:
  lda LARGE_POOL+5*128+8
  cmp #$40
  beq @third
  ldx #6*128
  ldy #8*128
  jsr .loword(large_scan_forward)
  bcc @third
  rts
@third:
  lda LARGE_POOL+9*128+8
  cmp #$40
  beq @reverse
  ldx #8*128
  ldy #12*128
  jsr .loword(large_scan_forward)
  bcc @reverse
  rts
@reverse:
  ldx #5*128
@back:
  lda LARGE_POOL+8,x
  beq large_allocate_found
  rep #$20
  txa
  sec
  sbc #128
  tax
  sep #$20
  bpl @back
large_allocate_full:
  clc
  rts
large_scan_forward:
  sty $d2
@slot:
  lda LARGE_POOL+8,x
  beq large_allocate_found
  rep #$20
  txa
  clc
  adc #128
  tax
  sep #$20
  cpx $d2
  bne @slot
  clc
  rts
large_allocate_found:
  sec
  rts
