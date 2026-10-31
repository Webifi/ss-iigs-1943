; Native foreground producer. $26 output, $2c sea start, $2e display page,
; $6e foreground camera, $68 update. Scratch $a8..cf, X is output cursor.
; Prepared spatial row data and pixels are long-addressed in IIgs fast RAM.
foreground_plan:
  rep #$30
  ldx $26
  lda $68
  beq @rows
  lda $6e
  clc
  adc #254
  sta $b0
  jsr fg_upload
  inc $b0
  jsr fg_upload
@rows:
  lda #Z_FG_DRAW_BE
  sta a:$0000,x
  lda $6e
  clc
  adc #.loword(255-FG_INITIAL)
  sta $b0
  asl
  clc
  adc $b0
  adc #$0500
  xba
  sta a:$0002,x
  lda $2c
  asl
  phx
  tax
  lda f:fg_rows56,x
  plx
  clc
  adc $2e
  xba
  sta a:$0004,x
  txa
  clc
  adc #6
  sta $26
  sep #$20
  rtl

fg_upload:
  rep #$20
  lda $b0
  sec
  sbc #FG_INITIAL
  asl
  asl
  phx
  tax
  lda f:fg_pixel_pointers,x
  sta $b4
  lda f:fg_pixel_pointers+2,x
  sta $b6
  plx
  lda #Z_FG_ROW_BE
  sta a:$0000,x
  lda $b0
  and #255
  asl
  asl
  asl
  asl
  asl
  asl
  xba
  sta a:$0002,x
.ifdef FG_VRAM_ROWS
  lda $b4
  xba
  sta a:$0004,x
  lda $b6
  xba
  sta a:$0006,x
  txa
  clc
  adc #8
  tax
  rts
.else
  inx
  inx
  inx
  inx
  ; Source rows are already in wire byte order. Copy them without a
  ; per-word address/count loop. The patched byte is the source bank only.
  ; Each 256-byte row is kept within one source bank by the build.
  phb
  txa
  tay
  sep #$20
  lda $b6
  sta f:fg_move+2
  rep #$20
  ldx $b4
  lda #255
fg_move:
  mvn #$00,#$00
  tyx
  plb
  rts
.endif

fg_rows56:
  .repeat 256,I
    .word I*56
  .endrepeat
