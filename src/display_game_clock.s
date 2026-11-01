; The game update rate: one update each two pictures of the display mode
; that Second Sight runs. The start-up and the menu work out the DOC ticks
; of an update; the sound timer does not change.
.a16
.i16

; game_clock_display_rate: game_clock_step_integer and _fraction = the DOC
; ticks of one update (Q16): the coefficient of the pixel clock (VGA or RGB)
; times the horizontal total times the vertical total, Q32 rounded to Q16.
; At a whole number, game_clock_deadline_step is ADC #integer; else a JSR to
; the fraction step. JSL.
game_clock_display_rate:
  phb
  phk
  plb
  lda f:DISPLAY_MODE+DISPLAY_CLOCK
  and #255
  sta a:.loword(game_rate_v)
  ldx #0
@clock:
  lda f:display_clock_select,x
  and #255
  cmp a:.loword(game_rate_v)
  beq @found
  inx
  cpx #DISPLAY_CLOCKS
  bcc @clock
  ldx #DISPLAY_CLOCK_FALLBACK   ; 40 MHz
@found:
  txa
  asl
  asl                           ; dword entries
  tax
  lda f:DISPLAY_MODE+DISPLAY_PIXEL_CLOCK
  and #255
  cmp #PIXEL_CLOCK_RGB
  bne :+
  txa
  clc
  adc #DISPLAY_CLOCKS*4         ; the RGB coefficients
  tax
:
  lda f:display_rate_coefficients,x
  sta a:.loword(game_rate_add)
  lda f:display_rate_coefficients+2,x
  sta a:.loword(game_rate_add)+2
  stz a:.loword(game_rate_mul)
  stz a:.loword(game_rate_mul)+2
  stz a:.loword(game_rate_mul)+4
  stz a:.loword(game_rate_sum)
  stz a:.loword(game_rate_sum)+2
  stz a:.loword(game_rate_sum)+4
  ; The coefficient times the horizontal total (CRTC 0 + 5 characters).
  lda f:DISPLAY_MODE+DISPLAY_CRTC_00
  and #255
  clc
  adc #5
  tax
@horizontal:
  clc
  lda a:.loword(game_rate_mul)
  adc a:.loword(game_rate_add)
  sta a:.loword(game_rate_mul)
  lda a:.loword(game_rate_mul)+2
  adc a:.loword(game_rate_add)+2
  sta a:.loword(game_rate_mul)+2
  lda a:.loword(game_rate_mul)+4
  adc #0
  sta a:.loword(game_rate_mul)+4
  dex
  bne @horizontal
  ; The vertical total: CRTC 6, bit 8 from CRTC 7 bit 0, bit 9 from CRTC 7
  ; bit 5, + 2 lines.
  lda f:DISPLAY_MODE+DISPLAY_CRTC_07
  and #1
  xba
  sta a:.loword(game_rate_v)
  lda f:DISPLAY_MODE+DISPLAY_CRTC_07
  and #$20
  asl
  asl
  asl
  asl                           ; bit 5 to bit 9
  ora a:.loword(game_rate_v)
  sta a:.loword(game_rate_v)
  lda f:DISPLAY_MODE+DISPLAY_CRTC_06
  and #255
  ora a:.loword(game_rate_v)
  inc
  inc
  sta a:.loword(game_rate_v)
@vertical:
  ; game_rate_sum = game_rate_mul * game_rate_v, by shifts and adds.
  lsr a:.loword(game_rate_v)
  bcc @shift
  clc
  lda a:.loword(game_rate_sum)
  adc a:.loword(game_rate_mul)
  sta a:.loword(game_rate_sum)
  lda a:.loword(game_rate_sum)+2
  adc a:.loword(game_rate_mul)+2
  sta a:.loword(game_rate_sum)+2
  lda a:.loword(game_rate_sum)+4
  adc a:.loword(game_rate_mul)+4
  sta a:.loword(game_rate_sum)+4
@shift:
  asl a:.loword(game_rate_mul)
  rol a:.loword(game_rate_mul)+2
  rol a:.loword(game_rate_mul)+4
  lda a:.loword(game_rate_v)
  bne @vertical
  ; Q32 rounded to Q16 ticks an update; each valid mode fits 48 bits.
  lda a:.loword(game_rate_sum)
  clc
  adc #$8000
  lda a:.loword(game_rate_sum)+2
  adc #0
  sta a:.loword(game_clock_step_fraction)
  lda a:.loword(game_rate_sum)+4
  adc #0
  sta a:.loword(game_clock_step_integer)
  sta f:game_clock_deadline_step+1
  stz a:.loword(game_clock_fraction)
  lda a:.loword(game_clock_step_fraction)
  bne @fractional
  a8
  lda #OPCODE_ADC_IMM           ; the arcade rate: no fraction work
  bra @patch
@fractional:
.a16
  lda #.loword(game_clock_fraction_bridge)
  sta f:game_clock_deadline_step+1
  a8
  lda #OPCODE_JSR
@patch:
  sta f:game_clock_deadline_step
  a16
  plb
  rtl

; game_clock_fraction_step: A = the deadline before; returns the next one:
; the fraction adds up, and its carry is one more DOC tick. JSL.
game_clock_fraction_step:
  pha
  lda f:game_clock_fraction
  clc
  adc f:game_clock_step_fraction
  sta f:game_clock_fraction
  pla
  adc f:game_clock_step_integer
  rtl

; The step and the fraction sum, and the work of game_clock_display_rate.
game_clock_step_integer: .word UPDATE_TICKS
game_clock_step_fraction: .word 0
game_clock_fraction: .word 0
game_rate_add: .res 4
game_rate_mul: .res 6
game_rate_sum: .res 6
game_rate_v: .res 2
