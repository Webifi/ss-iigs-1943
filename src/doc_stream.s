; Full-rate long one-shot. The attack never changes, so retrigger is immediate.
; A hardware voice pair swaps automatically. Each retired voice gets at most 2 KB per update.
; The final block changes to one-shot mode and cannot restart stale tail data.
.a8
.i16
DOC_STREAM_ACTIVE = $17e0
DOC_STREAM_VOICE = $17e1
DOC_STREAM_NEXT = $17e2
DOC_STREAM_CONTROL = $17e4
DOC_STREAM_REFILLS = $17e6
DOC_STREAM_UNDERRUNS = $17e8

doc_stream_init:
  stz DOC_STREAM_ACTIVE
  rep #$20
  stz DOC_STREAM_REFILLS
  stz DOC_STREAM_UNDERRUNS
  sep #$20
@ready:
  lda f:$e0c03c
  bmi @ready
  lda DOC_MASTER
  ora #$60
  sta f:$e0c03c
  lda #0
  sta f:$e0c03e
  lda #DOC_STREAM_ATTACK_PAGE
  sta f:$e0c03f
  ldx #0
@attack:
  lda f:$e0c03c
  bmi @attack
  lda f:DOC_STREAM_ATTACK,x
  sta f:$e0c03d
  inx
  cpx #DOC_STREAM_ATTACK_BYTES
  bne @attack
  .repeat 2,I
    ldx #DOC_STREAM_FIRST_VOICE+I
    lda #0
    jsr doc_write
    ldx #$20+DOC_STREAM_FIRST_VOICE+I
    lda #2
    jsr doc_write
    ldx #$40+DOC_STREAM_FIRST_VOICE+I
    lda #DOC_STREAM_VOLUME
    jsr doc_write
  .endrepeat
  rts

doc_play_player_death:
  ldx #$a0+DOC_STREAM_FIRST_VOICE+0
  lda #3
  jsr doc_write
  ldx #$a0+DOC_STREAM_FIRST_VOICE+1
  lda #3
  jsr doc_write
  ; Pointer and size writes take longer than one complete DOC scan.
  ldx #$80+DOC_STREAM_FIRST_VOICE+0
  lda #DOC_STREAM_ATTACK_PAGE
  jsr doc_write
  ldx #$80+DOC_STREAM_FIRST_VOICE+1
  lda #DOC_STREAM_ATTACK_SECOND
  jsr doc_write
  ldx #$c0+DOC_STREAM_FIRST_VOICE+0
  lda #DOC_STREAM_ATTACK_SIZE
  jsr doc_write
  ldx #$c0+DOC_STREAM_FIRST_VOICE+1
  lda #DOC_STREAM_ATTACK_SIZE
  jsr doc_write
  ldx #$a0+DOC_STREAM_FIRST_VOICE+1
  lda #7
  jsr doc_write
  ldx #$a0+DOC_STREAM_FIRST_VOICE+0
  lda #6
  jsr doc_write
  rep #$20
  stz DOC_STREAM_NEXT
  sep #$20
  lda #DOC_STREAM_FIRST_VOICE
  sta DOC_STREAM_VOICE
  lda #1
  sta DOC_STREAM_ACTIVE
  rts

doc_stream_update:
  lda DOC_STREAM_ACTIVE
  bne @active
  rts
@active:
  cmp #2
  bne @refill
  ldx #$a0+DOC_STREAM_FIRST_VOICE+0
  jsr doc_read
  and #1
  beq @waiting
  ldx #$a0+DOC_STREAM_FIRST_VOICE+1
  jsr doc_read
  and #1
  beq @waiting
  stz DOC_STREAM_ACTIVE
@waiting:
  rts
@refill:
  rep #$20
  lda DOC_STREAM_VOICE
  and #255
  ora #$a0
  tax
  sep #$20
  jsr doc_read
  and #1
  bne @retired
  rts
@retired:
  txa
  eor #1
  tax
  jsr doc_read
  and #1
  beq @running
  inc DOC_STREAM_UNDERRUNS
  lda #$e5
  sta f:$050301
  rts
@running:
  rep #$20
  ldx DOC_STREAM_NEXT
  lda doc_stream_blocks,x
  .repeat 16,I
    sta .ident(.sprintf("doc_stream_load_%d", I))+1
    inc
  .endrepeat
  sep #$20
  lda doc_stream_blocks+2,x
  .repeat 16,I
    sta .ident(.sprintf("doc_stream_load_%d", I))+3
  .endrepeat
  lda doc_stream_blocks+3,x
  sta DOC_STREAM_CONTROL
  lda DOC_STREAM_VOICE
  and #1
  asl
  asl
  asl
  ora #DOC_STREAM_TAIL_PAGE
  pha
  rep #$20
  lda DOC_STREAM_VOICE
  and #255
  ora #$80
  tax
  sep #$20
  pla
  pha
  jsr doc_write
  txa
  clc
  adc #$40
  tax
  lda #$1b
  jsr doc_write
@ready:
  lda f:$e0c03c
  bmi @ready
  lda DOC_MASTER
  ora #$60
  sta f:$e0c03c
  lda #0
  sta f:$e0c03e
  pla
  sta f:$e0c03f
  ldx #0
doc_stream_refill_byte:
  .repeat 16,I
    .ident(.sprintf("doc_stream_wait_%d", I)):
    lda f:$e0c03c
    bmi .ident(.sprintf("doc_stream_wait_%d", I))
    .ident(.sprintf("doc_stream_load_%d", I)):
    lda f:$000000,x
    sta f:$e0c03d
  .endrepeat
  rep #$20
  txa
  clc
  adc #16
  tax
  sep #$20
  cpx #2048
  beq doc_stream_refill_done
  jmp doc_stream_refill_byte
doc_stream_refill_done:
  rep #$20
  lda DOC_STREAM_NEXT
  clc
  adc #4
  sta DOC_STREAM_NEXT
  inc DOC_STREAM_REFILLS
  lda DOC_STREAM_VOICE
  and #255
  ora #$a0
  tax
  sep #$20
  lda DOC_STREAM_CONTROL
  jsr doc_write
  cmp #3
  bne @more
  lda #2
  sta DOC_STREAM_ACTIVE
@more:
  lda DOC_STREAM_VOICE
  eor #1
  sta DOC_STREAM_VOICE
  rts

