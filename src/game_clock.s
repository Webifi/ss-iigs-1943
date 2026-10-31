.a8
.i16
flight_clock_init:
  rep #$20
  stz GAME_PICTURE
  stz GAME_SKIPPED
  stz GAME_SENT_LOGIC
  lda GAME_CLOCK
  sta GAME_DUE
  sta GAME_CLOCK_ORIGIN
  sep #$20
 .ifdef CONTINUOUS_GAME
  jsl display_boot_apply
 .endif
  rts

flight_clock_wait:
  ; Signed subtraction also handles the 16-bit timer wrapping. No elapsed
  ; ticks are discarded: if late, the next logic update starts immediately.
  rep #$20
@wait:
  lda GAME_CLOCK
  sec
  sbc GAME_DUE
  bpl @due
  sep #$20
  jsl audio_game_upload
  jsr input_poll
  rep #$20
.ifdef WORLD_LZ
  lda GAME_DUE
  sec
  sbc GAME_CLOCK
  bmi :+
  cmp #3
  bcc :+
  jsl world_inflate_pump
:
.endif
  bra @wait
@due:
  lda GAME_DUE
  clc
game_clock_deadline_step:
  ; Selected timing patches this to ADC #ticks or JSR for a fractional
  ; deadline. No per-update display-mode check or division.
  adc #8
  sta GAME_DUE
.ifdef WORLD_LZ
  jsl world_inflate_force
.endif
  sep #$20
  rts

flight_picture_ready:
  lda GAME_PICTURE
  and #1
  clc
  adc #$40
  sta $60
@wait:
  rep #$20
  lda GAME_CLOCK
  sec
  sbc GAME_DUE
  bmi @check_card_16
  ; Sustained overload can otherwise leave GAME_DUE permanently behind the
  ; clock, suppressing every picture while logic continues. Once four logic
  ; updates have elapsed since a picture, send one if the card is ready and
  ; rebase the next deadline to now. Game logic is never discarded.
  lda $68
  sec
  sbc GAME_SENT_LOGIC
  cmp #4
  bcc @skip_16
  sep #$20
  lda f:$e0c0b8
  cmp $60
  bne @skip
  rep #$20
  lda GAME_CLOCK
  sta GAME_DUE
  sep #$20
  sec
  rts
@skip_16:
  sep #$20
@skip:
  rep #$20
  inc GAME_SKIPPED
  sep #$20
  clc
  rts
@check_card_16:
  sep #$20
@check_card:
  lda f:$e0c0b8
  cmp $60
  beq @ready
  ; A late card does not own the CPU. Service uploads/input only until the
  ; next logic deadline, then return to logic without building a stale packet.
  jsl audio_game_upload
  jsr input_poll
  bra @wait
@ready:
  sec
  rts

.ifdef CONTINUOUS_GAME
.a16
; Same-bank entry for the three-byte ADC/JSR patch site above.
game_clock_fraction_bridge:
  jsl game_clock_fraction_step
  rts
.endif
