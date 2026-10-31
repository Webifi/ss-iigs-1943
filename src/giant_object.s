; Native sixteen-piece object controller, original fixed $6207-$6426.
; The active head sits 128 bytes into a 512-byte reservation. No record copies.
.a8
.i16
GIANT_BASE = $1c64
GIANT_WORD = $1c66
GIANT_SCRIPT = $1c68
.macro giant_store row, col, field
  sta a:0+((row)/2)*256+((row) .mod 2)*64+((col)/2)*128+((col) .mod 2)*32+(field),x
.endmacro
giant_object_tick:
  phd
  rep #$20
  lda #0
  tcd
  lda LARGE_RECORD
  sec
  sbc #128
  sta GIANT_BASE
  tax
  stz LARGE_CALLBACK
  sep #$20
  stz LARGE_KIND
  lda LARGE_MODE
  bne @move
  jsr .loword(giant_object_script)
  lda LARGE_KIND
  bne @done
@move:
  jsr .loword(giant_object_motion)
@done:
  pld
  rtl

giant_object_script:
.a8
  lda a:$84,x
  beq @advance
  rts
@advance:
  rep #$20
  lda a:$8a,x
  and #$70
  asl
  asl
  sta LARGE_BANK
  lda a:$9e,x
  clc
  adc #7
  sta LARGE_SOURCE
@record:
  lda LARGE_SOURCE
  xba
  and #255
  cmp #$80
  bcs @banked
  ora #512
  bra @page
@banked:
  and #63
  ora LARGE_BANK
@page:
  sta GIANT_WORD
  asl
  clc
  adc GIANT_WORD
  tax
  lda LARGE_SOURCE
  and #255
  clc
  adc f:enemy_script_pages,x
  sta f:large_object_read+1
  sep #$20
  lda f:enemy_script_pages+2,x
  adc #0
  sta f:large_object_read+3
  ldx #0
  jsr .loword(large_object_read)
  bne :+
  rep #$20
  ldx #1
  jsr .loword(large_object_read)
  sta LARGE_CALLBACK
  sep #$20
  lda #2
  sta LARGE_KIND
  rts
:
  cmp #255
  bne :+
  rep #$20
  ldx #1
  jsr .loword(large_object_read)
  sta LARGE_SOURCE
  ldx GIANT_BASE
  sta a:$9e,x
  jmp .loword(@record)
:
.a8
  cmp #254
  bne :+
  ldx GIANT_BASE
  jmp .loword(giant_object_retire)
:
  ldx #0
@read:
  jsr .loword(large_object_read)
  sta GIANT_SCRIPT,x
  inx
  cpx #7
  bne @read
  ldx GIANT_BASE
  rep #$20
  lda LARGE_SOURCE
  sta a:$9e,x
  lda GIANT_SCRIPT+3
  xba
  sta a:$98,x
  lda GIANT_SCRIPT+5
  xba
  sta a:$9a,x
  sep #$20
  lda GIANT_SCRIPT
  sta a:$84,x
  lda GIANT_SCRIPT+1
  .repeat 4,R
    .repeat 4,C
      giant_store R,C,0
      .if C<3
        inc
      .endif
    .endrepeat
    .if R<3
      clc
      adc #5
    .endif
  .endrepeat
  .repeat 4,R
    lda a:0+(R/2)*256+(R .mod 2)*64+129,x
    and #16
    ora GIANT_SCRIPT+2
    .repeat 4,C
      giant_store R,C,1
    .endrepeat
  .endrepeat
  rts

giant_object_motion:
.a8
  ldx GIANT_BASE
  lda a:$89,x
  and #4
  beq @x
  lda LARGE_CAM_X
  sta a:$98,x
  stz a:$99,x
@x:
  rep #$20
  lda a:$98,x
  xba
  sta GIANT_WORD
  lda a:$82,x
  and #255
  xba
  sta LARGE_SOURCE
  lda a:$85,x
  and #255
  ora LARGE_SOURCE
  clc
  adc GIANT_WORD
  sep #$20
  sta a:$85,x
  xba
  .repeat 4,R
    giant_store R,2,2
  .endrepeat
  clc
  adc #16
  .repeat 4,R
    giant_store R,3,2
  .endrepeat
  sec
  sbc #48
  .repeat 4,R
    giant_store R,0,2
  .endrepeat
  clc
  adc #16
  .repeat 4,R
    giant_store R,1,2
  .endrepeat
  lda a:$89,x
  and #4
  beq @y
  lda LARGE_CAM_Y
  sta a:$9a,x
  stz a:$9b,x
@y:
  rep #$20
  lda a:$9a,x
  xba
  sta GIANT_WORD
  lda a:$83,x
  and #255
  xba
  sta LARGE_SOURCE
  lda a:$86,x
  and #255
  ora LARGE_SOURCE
  clc
  adc GIANT_WORD
  sep #$20
  sta a:$86,x
  xba
  .repeat 4,C
    giant_store 0,C,3
  .endrepeat
  bcc @no_carry
  lda a:$9a,x
  bmi @inside
  bra @toggle
@no_carry:
  lda a:$9a,x
  bpl @inside
@toggle:
  lda a:$81,x
  eor #16
  .repeat 4,C
    giant_store 0,C,1
  .endrepeat
@inside:
  lda a:$81,x
  and #16
  beq @rows
  lda a:$83,x
  cmp #$31
  bcc @rows
  cmp #$ef
  bcs @rows
  jmp .loword(giant_object_retire)
@rows:
  rep #$20
  lda a:$81,x
  and #16
  asl
  asl
  asl
  asl
  sta GIANT_WORD
  lda a:$83,x
  and #255
  ora GIANT_WORD
  sta GIANT_WORD
  .repeat 3,I
    .a16
    lda GIANT_WORD
    sec
    sbc #(I+1)*16
    sep #$20
    .repeat 4,C
      giant_store I+1,C,3
    .endrepeat
    xba
    beq :+
    lda a:0+((I+1)/2)*256+((I+1) .mod 2)*64+129,x
    ora #16
    bra :++
:
    lda a:0+((I+1)/2)*256+((I+1) .mod 2)*64+129,x
    and #$ef
:
    .repeat 4,C
      giant_store I+1,C,1
    .endrepeat
    rep #$20
  .endrepeat
  sep #$20
  dec a:$84,x
  rts

giant_object_retire:
.a8
  stz a:$88,x
  lda #0
  .repeat 4,R
    .repeat 4,C
      giant_store R,C,2
    .endrepeat
  .endrepeat
  lda #1
  sta LARGE_KIND
  rts
.delmacro giant_store
