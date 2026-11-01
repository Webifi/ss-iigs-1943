; The typed cabinet texts: CAB_ENDING_TEXT counts the letters that show (the
; packet carries it); the build (arcade_flow.py) makes the segments.
; A text segment: TS_SIZE bytes.
TS_TARGET = 0                ; the letter count at its end; TEXT_END ends the text
TS_DELAY = 1                 ; 2 bytes: arcade frames before it
TS_FLAGS = 3                 ; TF_* bits
TS_SIZE = 4
TEXT_END = 255
TF_LETTER_SOUND = $01        ; each letter sounds (SND_ENEMY_HIT)
TF_AT_ONCE = $02             ; all its letters show at once
TF_LINE_SOUND = $80          ; the segment sounds (SND_TEXT_SEGMENT)
LETTER_FRAMES = 3            ; arcade frames of each letter
UPDATE_FRAMES = UPDATE_TICKS/FRAME_TICKS ; arcade frames of one update

; cabinet_text_select: type the cabinet text A (CABINET_TEXT). JSL.
cabinet_text_select:
.a8
.i16
  a16
  and #255
  asl
  asl                           ; dword entries
  tax
  lda f:CABINET_TEXT,x
  sta CAB_TEXT_PTR
  lda f:CABINET_TEXT+2,x
  sta CAB_TEXT_PTR+2
  bra cabinet_text_init

; cabinet_statistics_select: type the statistics text of the result: four
; for each band: + 1 without a refill, + 2 with a continue level. JSL.
cabinet_statistics_select:
.a8
  lda CAB_RESULT_DATA+CRD_BAND
  asl
  asl
  sta STAT_TEXT
  lda CAB_RESULT_DATA+CRD_REFILL
  bne :+
  inc STAT_TEXT
:
  lda CAB_RESULT_DATA+CRD_LEVEL
  beq :+
  inc STAT_TEXT
  inc STAT_TEXT
:
  a16
  lda STAT_TEXT
  and #255
  asl
  asl
  tax
  lda f:CABINET_STAT_TEXT,x
  sta CAB_TEXT_PTR
  lda f:CABINET_STAT_TEXT+2,x
  sta CAB_TEXT_PTR+2
; cabinet_text_init: the text at CAB_TEXT_PTR (its first byte: the first
; letter count) starts.
cabinet_text_init:
.a16
  lda CAB_TEXT_PTR
  sta TEXT_SEGMENT
  lda CAB_TEXT_PTR+2
  sta TEXT_SEGMENT+2
  stz CAB_TEXT_WAIT
  stz CAB_TEXT_CLOCK
  a8
  stz CAB_TEXT_DONE
  lda [TEXT_SEGMENT]
  sta CAB_ENDING_TEXT
  a16
  inc CAB_TEXT_PTR
  a8
  jsr .loword(cabinet_text_segment)
  jmp .loword(cabinet_text_step)

; cabinet_text_tick: one update of the typing. JSL.
cabinet_text_tick:
.a8
  lda CAB_TEXT_DONE
  bne @done
  a16
  inc CAB_TEXT_CLOCK
  inc CAB_TEXT_CLOCK            ; UPDATE_FRAMES
  lda CAB_TEXT_WAIT
  sec
  sbc #UPDATE_FRAMES
  sta CAB_TEXT_WAIT
  a8
  jmp .loword(cabinet_text_step)
@done:
  rtl

; cabinet_text_step: when the wait is over, the next letter (or all the
; letters of a TF_AT_ONCE segment), or the next segment; TEXT_END: done.
cabinet_text_step:
.a8
@again:
  a16
  lda CAB_TEXT_WAIT
  bmi @ready
  beq @ready
  a8
  rtl
@ready:
  a8
  lda CAB_TEXT_TARGET
  cmp #TEXT_END
  beq @end
  cmp CAB_ENDING_TEXT
  beq @segment
  lda CAB_TEXT_FLAGS
  and #TF_AT_ONCE
  beq @letter
  lda CAB_TEXT_TARGET
  sta CAB_ENDING_TEXT
  bra @segment
@letter:
  inc CAB_ENDING_TEXT
  lda CAB_TEXT_FLAGS
  and #TF_LETTER_SOUND
  beq :+
  lda #SND_ENEMY_HIT
  jsl game_sound_request
:
  a16
  lda CAB_TEXT_WAIT
  clc
  adc #LETTER_FRAMES
  sta CAB_TEXT_WAIT
  a8
  bra @again
@segment:
  jsr .loword(cabinet_text_segment)
  bra @again
@end:
  lda #1
  sta CAB_TEXT_DONE
  rtl

; cabinet_text_segment: read the next segment: its delay adds to the wait;
; its target and flags; TF_LINE_SOUND sounds. JSR.
cabinet_text_segment:
.a8
  a16
  lda CAB_TEXT_PTR
  sta TEXT_SEGMENT
  clc
  adc #TS_SIZE
  sta CAB_TEXT_PTR
  lda CAB_TEXT_PTR+2
  sta TEXT_SEGMENT+2
  ldy #TS_DELAY
  lda [TEXT_SEGMENT],y
  clc
  adc CAB_TEXT_WAIT
  sta CAB_TEXT_WAIT
  a8
  lda [TEXT_SEGMENT]            ; TS_TARGET
  sta CAB_TEXT_TARGET
  ldy #TS_FLAGS
  lda [TEXT_SEGMENT],y
  sta CAB_TEXT_FLAGS
  bpl @done                     ; TF_LINE_SOUND
  lda #SND_TEXT_SEGMENT
  jsl game_sound_request
@done:
  rts
.assert TF_LINE_SOUND = $80 .and TS_TARGET = 0 .and UPDATE_FRAMES = 2, error
