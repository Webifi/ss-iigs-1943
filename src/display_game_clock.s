; Game updates follow half the actual programmed refresh. Menu/startup only
; calculates the period; sound oscillator frequencies and IRQ stay unchanged.
.a16
.i16
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
  cpx #5
  bcc @clock
  ldx #3                     ; validated mode fallback: 40 MHz
@found:
  txa
  asl
  asl
  tax
  lda f:DISPLAY_MODE+1
  and #255
  cmp #$a9
  bne :+
  txa
  clc
  adc #20
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
  ; Coefficient * horizontal characters, bounded by 260 menu-only additions.
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
  ; Decode actual vertical total, including both VGA overflow bits.
  lda f:DISPLAY_MODE+DISPLAY_CRTC_07
  and #1
  xba
  sta a:.loword(game_rate_v)
  lda f:DISPLAY_MODE+DISPLAY_CRTC_07
  and #$20
  asl
  asl
  asl
  asl
  ora a:.loword(game_rate_v)
  sta a:.loword(game_rate_v)
  lda f:DISPLAY_MODE+DISPLAY_CRTC_06
  and #255
  ora a:.loword(game_rate_v)
  inc
  inc
  sta a:.loword(game_rate_v)
@vertical:
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
  ; Round Q32 to Q16 ticks/update. The entire validated range fits 48 bits.
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
  sep #$20
  lda #$69                    ; ADC #integer, zero extra work at exact arcade rate
  bra @patch
@fractional:
.a16
  lda #.loword(game_clock_fraction_bridge)
  sta f:game_clock_deadline_step+1
  sep #$20
  lda #$20                    ; JSR bridge replaces ADC immediate
@patch:
  sta f:game_clock_deadline_step
  rep #$20
  plb
  rtl

game_clock_fraction_step:
  ; Incoming A is the previous deadline. Carry from fraction addition is
  ; the extra DOC tick; STA/PLA preserve it. No per-update rate arithmetic.
  pha
  lda f:game_clock_fraction
  clc
  adc f:game_clock_step_fraction
  sta f:game_clock_fraction
  pla
  adc f:game_clock_step_integer
  rtl

game_clock_step_integer: .word 8
game_clock_step_fraction: .word 0
game_clock_fraction: .word 0
game_rate_add: .res 4
game_rate_mul: .res 6
game_rate_sum: .res 6
game_rate_v: .res 2
