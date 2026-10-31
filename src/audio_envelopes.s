; Ready DOC register events for a voice or a hardware pair.
; Record: delay in sound ticks (word), register group plus partner offset,
; value. $FF ends. Delay $FFFF waits for this oscillator's completion IRQ.
; No waveform synthesis, pitch calculation, source-song decoding or disk I/O.
; IRQ caller: D=$1E00, DBR=0, A8/X16.
.a8
.i16
AUDIO_STATES = $018300
AUDIO_STARTS = $018400
AUDIO_NEXT_PTR = $018420
AUDIO_NEXT_SIZE = $018440
AUDIO_INDEX = $1ea0
AUDIO_VOICE = $1ea2
AUDIO_DATA = $1ea4
AUDIO_PTR = $e0

; Main caller supplies X=slot and A16=program number (zero means no request).
; Bit 15 selects prepared absolute DOC registers (noncontiguous AM groups).
; A word request is atomic against the sound IRQ.
audio_request:
  php
  sei
  rep #$30
  pha
  txa
  asl
  asl
  asl
  tax
  pla
  sta f:AUDIO_STATES+6,x
  plp
  rtl

audio_init:
  rep #$20
  lda #0
  ldx #254
@clear:
  sta f:AUDIO_STATES,x
  dex
  dex
  bpl @clear
  lda #$ffff
  ldx #30
@clear_starts:
  sta f:AUDIO_STARTS,x
  sta f:AUDIO_NEXT_SIZE,x
  dex
  dex
  bpl @clear_starts
  sep #$20
  rtl

audio_envelopes_tick:
  stz AUDIO_VOICE
  ldx #0
@voice:
  stx AUDIO_INDEX
  rep #$20
  lda f:AUDIO_STATES+6,x
  beq @active16
  pha
  and #$7fff
  sta f:AUDIO_STATES+6,x
  asl
  clc
  adc f:AUDIO_STATES+6,x
  tay
  lda a:audio_programs,y
  sta f:AUDIO_STATES,x
  lda #0
  sta f:AUDIO_STATES+6,x
  sep #$20
  lda a:audio_programs+2,y
  sta f:AUDIO_STATES+2,x
  rep #$20
  pla
  and #$8000
  xba
  sep #$20
  ora #1
  sta f:AUDIO_STATES+3,x
  jsr audio_prime
  bra @check_due
@active16:
  sep #$20
  lda f:AUDIO_STATES+3,x
  beq @next
  rep #$20
  lda f:AUDIO_STATES+4,x
  beq @due16
  cmp #$ffff
  beq @next16
  dec
  sta f:AUDIO_STATES+4,x
  bne @next16
@due16:
  sep #$20
@check_due:
  rep #$20
  lda f:AUDIO_STATES+4,x
  sep #$20
  bne @next
  jsr audio_service
@next:
  rep #$20
@next16:
  ldx AUDIO_INDEX
  txa
  clc
  adc #8
  tax
  sep #$20
  inc AUDIO_VOICE
  cpx #(MUSIC_IRQ_VOICE*8)     ; last enabled oscillator is the sound clock
  bcs :+
  jmp @voice
:
  jsr audio_commit_starts
  rtl

; Prepare every part before starting the notes in this tick. A halt is
; immediate; starts are committed together after pointer/frequency/volume
; setup, so one part does not begin a whole setup transaction before another.
audio_commit_starts:
  ldx #0
@voice:
  lda f:AUDIO_STARTS,x
  bmi @next
  pha
@ready:
  lda f:$e0c03c
  bmi @ready
  txa
  ora #$a0
  sta f:$e0c03e
  pla
  sta f:$e0c03d
  lda #$ff
  sta f:AUDIO_STARTS,x
@next:
  inx
  cpx #MUSIC_IRQ_VOICE
  bne @voice
  rts

; A8 = the oscillator reported by DOC E0, already acknowledged. Hardware
; swap has already handed off. Service only a program waiting for this end.
audio_completed:
  sta AUDIO_VOICE
  rep #$20
  and #31
  tax
  sep #$20
  lda f:AUDIO_NEXT_SIZE,x
  cmp #$ff
  beq @legacy
  ; IE can expose an older pending completion. Hand off only after the
  ; armed one-shot has actually stopped; the next wrap will report again.
  txa
  ora #$a0
  tax
  jsr doc_read
  and #1
  beq @return
  rep #$20
  lda AUDIO_VOICE
  and #31
  tax
  sep #$20
  lda f:AUDIO_NEXT_PTR,x
  pha
  txa
  ora #$80
  tax
  pla
  jsr doc_write
  rep #$20
  lda AUDIO_VOICE
  and #31
  tax
  sep #$20
  lda f:AUDIO_NEXT_SIZE,x
  pha
  lda #$ff
  sta f:AUDIO_NEXT_SIZE,x
  txa
  ora #$c0
  tax
  pla
  jsr doc_write
  rep #$20
  lda AUDIO_VOICE
  and #31
  ora #$a0
  tax
  sep #$20
  lda #0
  jsr doc_write
  rtl
@legacy:
  lda AUDIO_VOICE
  rep #$20
  and #255
  asl
  asl
  asl
  tax
  stx AUDIO_INDEX
  lda f:AUDIO_STATES+4,x
  cmp #$ffff
  sep #$20
  bne @return
  lda f:AUDIO_STATES+3,x
  beq @return
  jsr audio_service
  jsr audio_commit_starts
@return:
  rtl

audio_service:
  ; Keep the pointer in DP and walk the complete ready transaction with Y.
  ; The IRQ already owns the GLU and has saved its mode/pointer. Do not save
  ; P, rewrite the mode, or update a far PC for every individual register.
  rep #$20
  lda f:AUDIO_STATES,x
  sta AUDIO_PTR
  sep #$20
  lda f:AUDIO_STATES+2,x
  sta AUDIO_PTR+2
@mode_ready:
  lda f:$e0c03c
  bmi @mode_ready
  lda DOC_MASTER
  sta f:$e0c03c
  ldy #0
@due:
  lda [AUDIO_PTR],y
  cmp #$ff
  bne :+
  jmp @end
:
  pha
  lda f:AUDIO_STATES+3,x
  bmi @absolute
  pla
  clc
  adc AUDIO_VOICE
  bra @addressed
@absolute:
  pla
@addressed:
  sta AUDIO_DATA
  and #$e0
  cmp #$60
  beq @next_pointer
  cmp #$e0
  beq @arm_next
  lda AUDIO_DATA
  cmp #$a0
  bcs :+
  jmp @ready
:
  cmp #$c0
  bcc :+
  jmp @ready
:
  iny
  lda [AUDIO_PTR],y
  and #1
  bne @halt
  phx
  rep #$20
  lda AUDIO_DATA
  and #31
  tax
  sep #$20
  lda [AUDIO_PTR],y
  sta f:AUDIO_STARTS,x
  plx
  jmp @stored
@next_pointer:
  phx
  rep #$20
  lda AUDIO_DATA
  and #31
  tax
  sep #$20
  iny
  lda [AUDIO_PTR],y
  sta f:AUDIO_NEXT_PTR,x
  plx
  jmp @stored
@arm_next:
  phx
  rep #$20
  lda AUDIO_DATA
  and #31
  tax
  sep #$20
  iny
  lda [AUDIO_PTR],y
  sta f:AUDIO_NEXT_SIZE,x
  lda f:AUDIO_STARTS,x
  bmi @arm_running
  lda #$0a
  sta f:AUDIO_STARTS,x       ; keep the prepared multi-part start synchronized
  plx
  jmp @stored
@arm_running:
  txa
  ora #$a0
  sta AUDIO_DATA
@arm_ready:
  lda f:$e0c03c
  bmi @arm_ready
  lda AUDIO_DATA
  sta f:$e0c03e
  lda #$0a                 ; one-shot + completion IRQ, keep current phase
  sta f:$e0c03d
  plx
  jmp @stored
@halt:
  phx
  rep #$20
  lda AUDIO_DATA
  and #31
  tax
  sep #$20
  lda #$ff
  sta f:AUDIO_STARTS,x
  sta f:AUDIO_NEXT_SIZE,x
  plx
  dey
@ready:
  lda f:$e0c03c
  bmi @ready
  lda AUDIO_DATA
  sta f:$e0c03e
  iny
  lda [AUDIO_PTR],y
  sta f:$e0c03d
@stored:
  iny
  rep #$20
  lda [AUDIO_PTR],y
  iny
  iny
  cmp #0
  beq @again
  sta f:AUDIO_STATES+4,x
  tya
  clc
  adc AUDIO_PTR
  sta f:AUDIO_STATES,x
  sep #$20
  bcc :+
  lda f:AUDIO_STATES+2,x
  inc
  sta f:AUDIO_STATES+2,x
:
  rts
@again:
  sep #$20
  jmp @due
@end:
  lda #0
  sta f:AUDIO_STATES+3,x
  rts

audio_prime:
  rep #$20
  lda f:AUDIO_STATES,x
  sta AUDIO_PTR
  sep #$20
  lda f:AUDIO_STATES+2,x
  sta AUDIO_PTR+2
  ldy #0
  rep #$20
  lda [AUDIO_PTR],y
  sta f:AUDIO_STATES+4,x
  lda f:AUDIO_STATES,x
  clc
  adc #2
  sta f:AUDIO_STATES,x
  sep #$20
  bcc :+
  lda f:AUDIO_STATES+2,x
  inc
  sta f:AUDIO_STATES+2,x
:
  rts
