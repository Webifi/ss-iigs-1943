; Presentation only. The gameplay owner supplies values after applying rules.
; JSL, M=8/X=16, DBR=0, X -> eight bytes in bank 0:
; stage (0..15), outcome (0 success / nonzero failure), destruction percent,
; bonus text index (0..11), energy percent, charged energy, surplus rounds,
; flags (bit 0: show the arcade retry line). A/X/Y are preserved; C undefined.
; Returns immediately. CAB_RESULT_ACTIVE stays 1 until the presentation ends.
CAB_RESULT_ACTIVE = $152c
CAB_RESULT_PHASE = $152d
CAB_RESULT_TICKS = $152e
CAB_RESULT_DATA = $1530
CAB_RESULT_DIGITS = $1538

cabinet_stage_result:
.a8
.i16
  pha
  phx
  phy
  ldy #0
@copy:
  lda a:0,x
  sta CAB_RESULT_DATA,y
  inx
  iny
  cpy #8
  bne @copy
  lda #1
  sta CAB_RESULT_ACTIVE
  stz CAB_RESULT_PHASE
  rep #$20
  stz CAB_RESULT_TICKS
  lda CAB_RESULT_DATA
  and #15
  asl
  tax
  lda f:cabinet_stage_digits,x
  sta CAB_RESULT_DIGITS
  sep #$20
  lda CAB_RESULT_DATA+2
  ldy #2
  jsr .loword(cabinet_result_number)
  lda CAB_RESULT_DATA+4
  ldy #5
  jsr .loword(cabinet_result_number)
  lda CAB_RESULT_DATA+5
  ldy #8
  jsr .loword(cabinet_result_number)
  lda CAB_RESULT_DATA+6
  sta CAB_RESULT_DIGITS+11
  jsl cabinet_wire_mode
  jsl cabinet_text_select
  ply
  plx
  pla
  rtl

cabinet_result_number:
  rep #$20
  and #255
  tax
  sep #$20
  lda f:cabinet_percent_bcd,x
  sta $d4
  txa
  cmp #200
  bcc :+
  lda #2
  bra @hundreds
:
  cmp #100
  bcc :+
  lda #1
  bra @hundreds
:
  lda #10
@hundreds:
  sta CAB_RESULT_DIGITS,y
  lda $d4
  lsr
  lsr
  lsr
  lsr
  bne @tens
  txa
  cmp #10
  bcs :+
  lda #10
  bra @tens
:
  lda #0
@tens:
  sta CAB_RESULT_DIGITS+1,y
  lda $d4
  and #15
  sta CAB_RESULT_DIGITS+2,y
  rts

cabinet_result_tick:
.a8
  lda CAB_RESULT_ACTIVE
  beq @done
  jsl cabinet_text_tick
  lda CAB_TEXT_DONE
  beq @done
  lda CAB_RESULT_PHASE
  bne @finish
  lda CAB_RESULT_DATA+7
  and #1
  bne @finish
  lda CAB_RESULT_DATA
  cmp #15                     ; Yamato goes directly to the ending
  beq @finish
  jsl game_result_deck
  inc CAB_RESULT_PHASE
  jsl cabinet_statistics_select
@done:
  rtl
@finish:
  stz CAB_RESULT_ACTIVE
  rtl
