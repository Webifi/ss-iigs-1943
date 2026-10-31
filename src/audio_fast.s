; Build-prepared absolute DOC transactions. All mode dispatch, register
; deduplication and safe write order are resolved in the build. No virtual
; registers or per-oscillator program scan on this final snapshot path.
.a8
.i16
FAST_PC = $18480
FAST_WAIT = $18483
FAST_LEFT = $1ee6
FAST_BYTES = $1ee7
FAST_PTR = $e0

audio_fast_init:
  rep #$20
  lda #.loword(AUDIO_FAST_SOURCE)
  sta f:FAST_PC
  sta FAST_PTR
  sep #$20
  lda #^AUDIO_FAST_SOURCE
  sta f:FAST_PC+2
  sta FAST_PTR+2
  ldy #0
  rep #$20
  lda [FAST_PTR],y
  sta f:FAST_WAIT
  sep #$20
  rtl

audio_fast_tick:
  rep #$20
  lda f:FAST_WAIT
  cmp #$ffff
  beq @return
  cmp #0
  beq @due
  dec
  sta f:FAST_WAIT
  bne @return
@due:
  lda f:FAST_PC
  sta FAST_PTR
  sep #$20
  lda f:FAST_PC+2
  sta FAST_PTR+2
  ldy #2
  lda [FAST_PTR],y
  sta FAST_LEFT
  ldy #4
@mode:
  lda f:$e0c03c
  bmi @mode
  lda DOC_MASTER
  ora #$20
  sta f:$e0c03c
@group:
  lda f:$e0c03c
  bmi @group
  lda [FAST_PTR],y
  sta f:$e0c03e
  iny
  lda [FAST_PTR],y
  sta FAST_BYTES
  iny
@write:
  lda f:$e0c03c
  bmi @write
  lda [FAST_PTR],y
  sta f:$e0c03d
  iny
  dec FAST_BYTES
  bne @write
  dec FAST_LEFT
  bne @group
  rep #$20
  lda [FAST_PTR],y
  sta f:FAST_WAIT
  tya
  clc
  adc f:FAST_PC
  sta f:FAST_PC
  sep #$20
  bcc @done
  lda f:FAST_PC+2
  inc
  sta f:FAST_PC+2
@done:
  rtl
@return:
  sep #$20
  rtl
