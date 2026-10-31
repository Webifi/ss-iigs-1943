; Native 65816 sprite-list planner. The input is a 4 KB object-state table,
; with the original US field layout. No arcade opcode is executed here.
; Input: M=8, X=16, $20..22 input pointer, X=output offset in bank $05.
; Output: A (16-bit) count, X=end. Eight bytes per record:
; code word, color word, upright left signed word, upright top signed word.
; Records retain the arcade's back-to-front order. Per-pen priority is art data.

plan_objects:
  phb
.ifdef OBJECT_OUTPUT_BANK
  lda #OBJECT_OUTPUT_BANK
.else
  lda #5
.endif
  pha
  plb
  rep #$20
  stz $30
  stz $32
  stz $34
  stz $36
  stz $38
  sep #$20
  ldy #$0fe0
@slot:
  lda [$20],y
  sta $30
  iny
  lda [$20],y
  sta $32
  iny
  lda [$20],y
  sta $34
  iny
  lda [$20],y
  sta $36
  ; Original visible Y is [16,240), with 16-pixel objects clipped at edges.
  lda $34
  beq @next
  cmp #240
  bcs @next
  lda $32
  and #$10
  beq @visible
  lda $36
  cmp #241
  bcc @next
@visible:
  rep #$20
  lda $32
  and #$00e0
  asl
  asl
  asl
  ora $30
  sta a:$0000,x
  lda $32
  and #15
  sta a:$0002,x
  lda $34
  sec
  sbc #16
  sta a:$0004,x
  lda $32
  and #$0010
  asl
  asl
  asl
  asl
  clc
  adc #240
  sec
  sbc $36
  sta a:$0006,x
  txa
  clc
  adc #8
  tax
  inc $38
  sep #$20
@next:
  ; Y is slot + 3. The signed result ends after the slot at zero.
  rep #$20
  tya
  sec
  sbc #35
  tay
  sep #$20
  bpl @slot
  rep #$20
  lda $38
  plb
  rts
