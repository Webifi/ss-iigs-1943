; Native script-data decoder for original US $5567-$55AE and $59CB-$59D8.
; The build copies reachable movement data, never executable Z80 code.
; A callback is returned as an ID for a native handler, never executed as code.
.a8
.i16
.ifndef ENEMY
ENEMY = $1000
.endif
ENEMY_SCRIPT_KIND = ENEMY+32
ENEMY_CALLBACK = ENEMY+34

enemy_script:
  stz ENEMY_SCRIPT_KIND
  stz ENEMY_CALLBACK
  stz ENEMY_CALLBACK+1
  lda ENEMY+4
  beq @advance
  rts
@advance:
  rep #$20
  lda ENEMY+$0a
  and #$70
  asl
  asl
  sta $d4
  lda ENEMY+$1e
  clc
  adc #7
  sta $d2
@record:
  lda $d2
  xba
  and #255
  cmp #$80
  bcs @banked
  ora #512
  bra @page
@banked:
  and #63
  ora $d4
@page:
  sta $dc
  asl
  clc
  adc $dc
  tax
  lda $d2
  and #255
  clc
  adc f:enemy_script_pages,x
  sta $d8
  sep #$20
  lda f:enemy_script_pages+2,x
  adc #0
  sta $da
  lda [$d8]
  beq @callback
  cmp #$ff
  beq @jump
  cmp #$fe
  beq @retire
  sta ENEMY+4
  rep #$20
  lda $d2
  sta ENEMY+$1e
  lda ENEMY
  and #$1000
  sta $dc
  ldy #1
  lda [$d8],y
  ora $dc
  sta ENEMY
  iny
  iny
  lda [$d8],y
  xba
  sta ENEMY+$18
  iny
  iny
  lda [$d8],y
  xba
  sta ENEMY+$1a
  sep #$20
  rts
@jump:
  rep #$20
  ldy #1
  lda [$d8],y
  sta ENEMY+$1e
  sta $d2
  jmp @record
@callback:
.a8
  lda #2
  sta ENEMY_SCRIPT_KIND
  rep #$20
  ldy #1
  lda [$d8],y
  sta ENEMY_CALLBACK
  sep #$20
  rts
@retire:
.ifdef ENEMY_SPECIAL_CONTACT
  lda ENEMY+2
  sta ENEMY_RETIRE_X
.endif
  stz ENEMY
  stz ENEMY+8
  stz ENEMY+2
  lda #1
  sta ENEMY_SCRIPT_KIND
  rts
