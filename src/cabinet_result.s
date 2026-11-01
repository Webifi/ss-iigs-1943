; The stage result report: only its presentation; the rules chose the
; values. CAB_RESULT_ACTIVE stays 1 until the report ends.
DIGIT_BLANK = 10             ; CAB_RESULT_DIGITS: no digit
; CAB_RESULT_DIGITS: 0-1 the stage, then three digits each from 2: the
; percent, from 5: the energy, from 8: the refill; 11 the level.

; cabinet_stage_result: show the result of the CRD_SIZE bytes at X in bank 0
; (CRD_* layout). JSL; A8, X16; A, X, Y kept.
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
  cpy #CRD_SIZE
  bne @copy
  lda #1
  sta CAB_RESULT_ACTIVE
  stz CAB_RESULT_PHASE
  a16
  lda CAB_RESULT_DATA+CRD_STAGE
  and #STAGES-1
  asl
  tax
  lda f:cabinet_stage_digits,x
  sta CAB_RESULT_DIGITS
  a8
  lda CAB_RESULT_DATA+CRD_PERCENT
  ldy #2
  jsr .loword(cabinet_result_number)
  lda CAB_RESULT_DATA+CRD_ENERGY
  ldy #5
  jsr .loword(cabinet_result_number)
  lda CAB_RESULT_DATA+CRD_REFILL
  ldy #8
  jsr .loword(cabinet_result_number)
  lda CAB_RESULT_DATA+CRD_LEVEL
  sta CAB_RESULT_DIGITS+11
  jsl cabinet_wire_mode
  jsl cabinet_text_select
  ply
  plx
  pla
  rtl

; cabinet_result_number: the three digits of A (0-255) at CAB_RESULT_DIGITS
; + Y; leading zeros are DIGIT_BLANK. JSR.
cabinet_result_number:
  a16
  and #255
  tax
  a8
  lda f:cabinet_percent_bcd,x
  sta RESULT_BCD                ; the tens and ones in BCD
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
  lda #DIGIT_BLANK
@hundreds:
  sta CAB_RESULT_DIGITS,y
  lda RESULT_BCD
  lsr
  lsr
  lsr
  lsr
  bne @tens
  txa
  cmp #10
  bcs :+
  lda #DIGIT_BLANK
  bra @tens
:
  lda #0
@tens:
  sta CAB_RESULT_DIGITS+1,y
  lda RESULT_BCD
  and #15
  sta CAB_RESULT_DIGITS+2,y
  rts

; cabinet_result_tick: one update of the report (cabinet_frame): the text
; types; then, except after a retry or the last stage, the deck and the
; statistics page; then the report ends. JSL.
cabinet_result_tick:
.a8
  lda CAB_RESULT_ACTIVE
  beq @done
  jsl cabinet_text_tick
  lda CAB_TEXT_DONE
  beq @done
  lda CAB_RESULT_PHASE
  bne @finish
  lda CAB_RESULT_DATA+CRD_FLAGS
  and #1
  bne @finish
  lda CAB_RESULT_DATA+CRD_STAGE
  cmp #LAST_STAGE               ; the Yamato: the ending comes next
  beq @finish
  jsl game_result_deck
  inc CAB_RESULT_PHASE
  jsl cabinet_statistics_select
@done:
  rtl
@finish:
  stz CAB_RESULT_ACTIVE
  rtl
