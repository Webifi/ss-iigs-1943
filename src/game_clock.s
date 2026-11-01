; The game clock. GAME_CLOCK counts the DOC timer interrupts (src/music_irq.s).
; GAME_DUE is the GAME_CLOCK time of the next update; each update (two game
; ticks) moves it on by the update length of the display timing: 8 DOC ticks
; at the arcade timing, or a fraction (game_clock_fraction_step) for the
; other timings (src/display_control.s patches game_clock_deadline_step).
; GAME_PICTURE and the packet token advance only when a packet goes.
.a8
.i16
UPDATE_TICKS = 8             ; DOC ticks of one update at the arcade timing
PUMP_TICKS = 2               ; the world decoder runs only with this many ticks to spare
PUMP_BATCH = 8               ; world_inflate_pump: the most tokens of one call
PICTURE_SKIP_MAX = 4         ; updates without a picture before one goes late

; flight_clock_init: start the clock now and apply the display timing
; (flight_loop). A8.
flight_clock_init:
  a16
  stz GAME_PICTURE
  stz GAME_SENT_LOGIC
  lda GAME_CLOCK
  sta GAME_DUE
  a8
  jsl display_boot_apply
  rts

; flight_clock_wait: wait until GAME_DUE, then set the next GAME_DUE.
; While it waits it runs the sound uploads, the input and, with time to
; spare, the world decoder. A late update starts at once: no tick is lost.
; The signed subtraction also handles the 16-bit wrap of the clock. A8.
flight_clock_wait:
  a16
@wait:
  lda GAME_CLOCK
  sec
  sbc GAME_DUE
  bpl @due
  a8
  jsl audio_game_upload
  jsr input_poll
  a16
  lda GAME_DUE
  sec
  sbc GAME_CLOCK
  bmi :+
  cmp #PUMP_TICKS
  bcc :+
  jsl world_inflate_pump
:
  bra @wait
@due:
  lda GAME_DUE
  clc
game_clock_deadline_step:
  ; src/display_control.s patches these three bytes to ADC #ticks or to a
  ; JSR game_clock_fraction_bridge for a fractional update length. No
  ; display check and no division run in each update.
  adc #UPDATE_TICKS
  sta GAME_DUE
  jsl world_inflate_force
  a8
  rts

; flight_picture_ready: decide whether this update sends a picture.
; Returns carry 1 when the card is ready for the next packet token (that
; token is then in STREAM_TOKEN), carry 0 to skip the picture. A8.
flight_picture_ready:
  lda GAME_PICTURE
  and #1                        ; bit 0 selects the card buffer
  clc
  adc #PACKET_TOKEN
  sta STREAM_TOKEN
@wait:
  a16
  lda GAME_CLOCK
  sec
  sbc GAME_DUE
  bmi @check_card_16
  ; The next update is due. Without the rule below, a lasting overload keeps
  ; GAME_DUE behind the clock and no picture ever goes while the game runs.
  ; After PICTURE_SKIP_MAX updates without a picture, send one if the card is
  ; ready, and start the next deadline now. No game logic is lost.
  lda GAME_UPDATES
  sec
  sbc GAME_SENT_LOGIC
  cmp #PICTURE_SKIP_MAX
  bcc @skip_16
  a8
  lda f:SS_HANDSHAKE
  cmp STREAM_TOKEN
  bne @skip
  a16
  lda GAME_CLOCK
  sta GAME_DUE
  a8
  sec
  rts
@skip_16:
  a8
@skip:
  clc
  rts
@check_card_16:
  a8
@check_card:
  lda f:SS_HANDSHAKE
  cmp STREAM_TOKEN
  beq @ready
  ; The card is still busy. Do not wait for it past the next deadline: run
  ; the uploads and the input until then, and skip the picture if it is late.
  jsl audio_game_upload
  jsr input_poll
  bra @wait
@ready:
  sec
  rts

; game_clock_fraction_bridge: the bank-zero target of the patched JSR above;
; the fraction code is far (src/display_game_clock.s). A16.
.a16
game_clock_fraction_bridge:
  jsl game_clock_fraction_step
  rts
