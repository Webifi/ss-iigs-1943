; A bounded art transfer appended to the existing frame packet.
; Three short initial death frames are resident; two slots alternate later.
; A slot is not overwritten while either live player's death uses it.
.a16
.i16
ART_NEXT = $11e8
ART_PIECE = $11e9
ART_SOURCE_INDEX = $11ea
ART_OWNERS = $11f0
ART_TRANSFER_COUNT = $11f6
ART_TRANSFER_BYTES = $11f8
ART_STALLS = $11fa
ART_SLOT = $11fc

art_stream_init:
  rep #$20
  lda #$0003
  sta ART_NEXT
  lda #72
  sta ART_SOURCE_INDEX
  lda #$0100
  sta ART_OWNERS
  lda #$ff02
  sta ART_OWNERS+2
  lda #$00ff
  sta ART_OWNERS+4
  stz ART_TRANSFER_COUNT
  stz ART_TRANSFER_BYTES
  stz ART_STALLS
  sep #$20
  rts

art_stream_append:
  rep #$30
  ; Check ready art before rendering either player.
  ldx #0
@ready_player:
  lda PLAYER+8,x
  and #255
  cmp #4
  bne @ready_next
  lda PLAYER+$1d,x
  and #255
  lsr
  beq @ready_next
  dec
  cmp #16
  bcs @ready_next
  sta $b8
  phx
  tax
  lda art_group_family,x
  and #255
  tay
  lda ART_OWNERS,y
  and #255
  sta $ba
  plx
  lda $ba
  cmp $b8
  beq @ready_next
  sep #$20
  lda #$e7
  sta f:$050301
  rep #$20
  rts
@ready_next:
  cpx #128
  beq @prefetch
  ldx #128
  bra @ready_player
@prefetch:
  lda PLAYER+8
  and #255
  cmp #4
  bne @done
  lda ART_NEXT
  and #255
  cmp #16
  bcs @done
  tax
  lda art_group_family,x
  and #255
  sta ART_SLOT
  ldx #0
@in_use:
  lda PLAYER+8,x
  and #255
  cmp #4
  bne @check_next
  lda PLAYER+$1d,x
  and #255
  lsr
  beq @check_next
  dec
  cmp #16
  bcs @check_next
  phx
  tax
  lda art_group_family,x
  and #255
  sta $ba
  plx
  lda $ba
  cmp ART_SLOT
  bne @check_next
  inc ART_STALLS
  rts
@check_next:
  cpx #128
  beq @copy
  ldx #128
  bra @in_use
@copy:
  ldx ART_SOURCE_INDEX
  lda art_piece_sources,x
  sta $b0
  lda art_piece_sources+2,x
  sta $b2
  lda art_piece_sources+4,x
  sta $b4
  clc
  adc ART_TRANSFER_BYTES
  sta ART_TRANSFER_BYTES
  sep #$20
  lda $68
  sta f:$050408
  rep #$20
  ldx $26
  ldy #0
@word:
  lda [$b0],y
  sta a:$0000,x
  inx
  inx
  iny
  iny
  cpy $b4
  bne @word
  stx $26
  lda ART_SOURCE_INDEX
  clc
  adc #6
  sta ART_SOURCE_INDEX
  inc ART_TRANSFER_COUNT
  sep #$20
  lda $68
  sta f:$050409
  inc ART_PIECE
  lda ART_PIECE
  cmp #4
  bne @done8
  ldx ART_SLOT
  lda ART_NEXT
  sta ART_OWNERS,x
  inc ART_NEXT
  stz ART_PIECE
@done8:
  rep #$20
@done:
  rts
