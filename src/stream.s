; stream_packet: send the packet in PACKET_BUFFER to the card.
;
; The card reads a packet from its receive buffer when the handshake byte
; shows the token of that buffer. The packet goes as fast as the 65816 can
; write: S points at the card port SS_BURST, and PEI pushes two packet bytes
; from the page that D points at. Four PEIs fill $C0B0-$C0B7 (one burst);
; then S goes back to SS_BURST. Each word of the packet is high byte first,
; so the pushes send the bytes in packet order.
;
; In: A = the token of the card buffer (PACKET_TOKEN or PACKET_TOKEN+1),
; PACKET_LENGTH = the bytes after PACKET_SIZE. A8, X16, DBR = 0, D = 0.
; Out: A8. A, X, Y: changed. A card that does not answer stops the game.
stream_packet:
  sta STREAM_TOKEN
  ; Wait for the card. Keep the sound uploads and the input running while
  ; it draws the last picture.
  ldy #SS_POLLS
@wait:
  phy
  jsl audio_game_upload
  ply
  phy
  jsr input_poll
  ply
  lda f:SS_HANDSHAKE
  cmp STREAM_TOKEN
  beq @ready
  dey
  bne @wait
  jmp failed
@ready:
  php
  sei
  ; The pushes must reach the slot I/O in bank 0, so show the I/O at $C000
  ; (IOLC off). The IRQ vector at $FFEE then is the firmware's; IRQ stays
  ; masked until the RAM mapping is back.
  lda f:SHADOW
  and #<~SHADOW_IOLC
  sta f:SHADOW
  ax16
  tsc
  sta stream_saved_sp
  ; Y = the bytes after the last full page, X = the full pages. The count
  ; includes the 2 bytes of PACKET_SIZE.
  lda PACKET_LENGTH
  clc
  adc #2
  pha
  and #255
  tay
  pla
  xba
  and #255
  tax
  lda #.loword(PACKET_BUFFER)   ; D = the first page of the packet
  tcd
  cpx #0
  bne @page
  jmp @tail
  ; One page: 256 / SS_BURST_SIZE bursts.
@page:
  .repeat 256/SS_BURST_SIZE,I
    lda #.loword(SS_BURST)
    tcs
    pei (I*8)
    pei (I*8+2)
    pei (I*8+4)
    pei (I*8+6)
  .endrepeat
  tdc
  clc
  adc #256                      ; D = the next page
  tcd
  dex
  beq @tail
  jmp @page
  ; The rest: full bursts while SS_BURST_SIZE or more bytes are left.
@tail:
  cpy #SS_BURST_SIZE
  bcc @short_tail
@eight:
  lda #.loword(SS_BURST)
  tcs
  pei (0)
  pei (2)
  pei (4)
  pei (6)
  tdc
  clc
  adc #SS_BURST_SIZE
  tcd
  tya
  sec
  sbc #SS_BURST_SIZE
  tay
  cmp #SS_BURST_SIZE
  bcs @eight
  ; The last bytes go one word at a time through SS_DATA_OUT, from the
  ; address in X. The game stack and D = 0 come back first.
@short_tail:
  lda stream_saved_sp
  tcs
  tdc
  tax
  lda #ZERO_PAGE
  tcd
  cpy #0
  beq @done
@word:
  lda a:0,x                     ; X holds the address of the word
  xba                           ; the high byte first
  sta f:SS_DATA_OUT
  inx
  inx
  dey
  dey
  bne @word
@done:
  ; RAM at $C000-$FFFF again (IOLC on), then the caller's P (and IRQ mask).
  a8
  lda f:SHADOW
  ora #SHADOW_IOLC
  sta f:SHADOW
  plp
  rts
.assert SS_BURST_SIZE = 8, error  ; the four PEIs of each burst above

; The game stack pointer while S points at the card port for the pushes.
stream_saved_sp: .res 2
