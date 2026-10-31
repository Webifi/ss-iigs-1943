; Native carrier launches and the five possible destruction fragments.
; Requests are consumed immediately so a later controller cannot overwrite one.
.a8
.i16
SHIP_REQUEST = $1c54           ; kind 1..4, X, Y, random-already-advanced
SHIP_DEST = $1c58
SHIP_TEMPLATE = $1c5a
SHIP_FRAGMENT = $1c5c
ship_launch:
  lda SHIP_REQUEST
  cmp #2
  beq @large
  jsr .loword(ship_allocate_fighter)
  bcs @small_found
  rtl
@small_found:
  rep #$20
  txa
  clc
  adc #ENEMY_POOL
  sta SHIP_DEST
  bra @template
@large:
.a8
  jsr .loword(large_allocate_core)
  bcs :+
  rtl
:
  rep #$20
  txa
  clc
  adc #LARGE_POOL
  sta SHIP_DEST
@template:
.a16
  lda SHIP_REQUEST
  and #255
  dec
  asl
  asl
  asl
  asl
  asl
  sta SHIP_TEMPLATE
  jsr .loword(ship_copy_template)
.a8
  lda SHIP_REQUEST
  cmp #2
  beq @large_position
  lda SHIP_REQUEST+1
  sta a:2,x
  lda SHIP_REQUEST+2
  sta a:3,x
  rtl
@large_position:
  lda SHIP_REQUEST+1
  sec
  sbc #8
  sta a:2,x
  lda SHIP_REQUEST+2
  clc
  adc #8
  sta a:3,x
  sec
  sbc #16
  sta a:$43,x
  lda a:1,x
  sta a:$41,x
  rtl
ship_secondary:
  stz SHIP_REQUEST+3
  bra ship_secondary_start
ship_secondary_ready:
  lda #1
  sta SHIP_REQUEST+3
ship_secondary_start:
  rep #$20
  stz SHIP_FRAGMENT
@fragment:
  lda #4*32
  sta SHIP_TEMPLATE
  sep #$20
  jsr .loword(ship_fragment_spawn)
  rep #$20
  inc SHIP_FRAGMENT
  inc SHIP_FRAGMENT
  lda SHIP_FRAGMENT
  cmp #8
  bne @fragment
  sep #$20
  lda SHIP_REQUEST+3
  bne @advanced
  lda RANDOM_STATE+1
  clc
  adc #$77
  sta RANDOM_STATE+1
@advanced:
  lda RANDOM_STATE+1
  and #15
  bne @done
  rep #$20
  lda #5*32
  sta SHIP_TEMPLATE
  sep #$20
  jsr .loword(ship_fragment_spawn)
@done:
  rtl
ship_fragment_spawn:
.a8
  jsr .loword(ship_allocate_fighter)
  bcc @done
  rep #$20
  txa
  clc
  adc #ENEMY_POOL
  sta SHIP_DEST
  jsr .loword(ship_copy_template)
.a8
  lda SHIP_REQUEST+1
  sta a:2,x
  lda SHIP_REQUEST+2
  sta a:3,x
  rep #$20
  phx
  ldx SHIP_FRAGMENT
  lda f:ship_fragment_paths,x
  plx
  sta a:$1e,x
  sep #$20
@done:
  rts
ship_fragment_paths:
  .word $83cb,$8435,$849f,$8509,$8573
ship_copy_template:
.a16
  ldy SHIP_DEST
  ldx SHIP_TEMPLATE
  .repeat 16
    lda f:ship_launch_templates,x
    sta a:0,y
    inx
    inx
    iny
    iny
  .endrepeat
  ldx SHIP_DEST
  sep #$20
  rts
ship_allocate_fighter:
.a8
  lda STAGE_DIFFICULTY+6
  bne :+
  clc
  rts
:
  rep #$20
  and #255
  asl
  asl
  asl
  asl
  asl
  sta $d2
  ldx #0
@slot:
  sep #$20
  lda ENEMY_POOL+8,x
  beq @found
  rep #$20
  txa
  clc
  adc #32
  tax
  cpx $d2
  bne @slot
  sep #$20
  clc
  rts
@found:
  sec
  rts
