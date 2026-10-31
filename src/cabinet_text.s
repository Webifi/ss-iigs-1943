; Prepared lettering segments: target count, preceding delay in arcade frames,
; flags (bit 0 letter cue, bit 1 immediate, bit 7 end-of-line cue).
; Only this presentation state is new; packets reuse CAB_ENDING_TEXT.
CAB_TEXT_PTR = $1548
CAB_TEXT_WAIT = $154c
CAB_TEXT_TARGET = $154e
CAB_TEXT_FLAGS = $154f
CAB_TEXT_DONE = $1550
CAB_TEXT_CLOCK = $155c

cabinet_text_select:
.a8
.i16
  rep #$20
  and #255
  asl
  asl
  tax
  lda f:CABINET_TEXT,x
  sta CAB_TEXT_PTR
  lda f:CABINET_TEXT+2,x
  sta CAB_TEXT_PTR+2
  bra cabinet_text_init

cabinet_statistics_select:
.a8
  lda CAB_RESULT_DATA+3
  asl
  asl
  sta $d4
  lda CAB_RESULT_DATA+5
  bne :+
  inc $d4
:
  lda CAB_RESULT_DATA+6
  beq :+
  inc $d4
  inc $d4
:
  rep #$20
  lda $d4
  and #255
  asl
  asl
  tax
  lda f:CABINET_STAT_TEXT,x
  sta CAB_TEXT_PTR
  lda f:CABINET_STAT_TEXT+2,x
  sta CAB_TEXT_PTR+2
cabinet_text_init:
.a16
  lda CAB_TEXT_PTR
  sta $d4
  lda CAB_TEXT_PTR+2
  sta $d6
  stz CAB_TEXT_WAIT
  stz CAB_TEXT_CLOCK
  sep #$20
  stz CAB_TEXT_DONE
  lda [$d4]
  sta CAB_ENDING_TEXT
  rep #$20
  inc CAB_TEXT_PTR
  sep #$20
  jsr .loword(cabinet_text_segment)
  jmp .loword(cabinet_text_step)

cabinet_text_tick:
.a8
  lda CAB_TEXT_DONE
  bne @done
  rep #$20
  inc CAB_TEXT_CLOCK
  inc CAB_TEXT_CLOCK
  lda CAB_TEXT_WAIT
  sec
  sbc #2                      ; one native update is two arcade frames
  sta CAB_TEXT_WAIT
  sep #$20
  jmp .loword(cabinet_text_step)
@done:
  rtl

cabinet_text_step:
.a8
@again:
  rep #$20
  lda CAB_TEXT_WAIT
  bmi @ready
  beq @ready
  sep #$20
  rtl
@ready:
  sep #$20
  lda CAB_TEXT_TARGET
  cmp #255
  beq @end
  cmp CAB_ENDING_TEXT
  beq @segment
  lda CAB_TEXT_FLAGS
  and #2
  beq @letter
  lda CAB_TEXT_TARGET
  sta CAB_ENDING_TEXT
  bra @segment
@letter:
  inc CAB_ENDING_TEXT
  lda CAB_TEXT_FLAGS
  and #1
  beq :+
  lda #$13
  jsl game_sound_request
:
  rep #$20
  lda CAB_TEXT_WAIT
  clc
  adc #3
  sta CAB_TEXT_WAIT
  sep #$20
  bra @again
@segment:
  jsr .loword(cabinet_text_segment)
  bra @again
@end:
  lda #1
  sta CAB_TEXT_DONE
  rtl

cabinet_text_segment:
.a8
  rep #$20
  lda CAB_TEXT_PTR
  sta $d4
  clc
  adc #4
  sta CAB_TEXT_PTR
  lda CAB_TEXT_PTR+2
  sta $d6
  ldy #1
  lda [$d4],y
  clc
  adc CAB_TEXT_WAIT
  sta CAB_TEXT_WAIT
  sep #$20
  lda [$d4]
  sta CAB_TEXT_TARGET
  ldy #3
  lda [$d4],y
  sta CAB_TEXT_FLAGS
  bpl @done
  lda #$11
  jsl game_sound_request
@done:
  rts
