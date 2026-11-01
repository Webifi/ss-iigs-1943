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

; packet_copy: copy a record of the host data (a world, stage or cabinet
; job) into the packet, each word with its two bytes exchanged, because the
; packet holds words high byte first. DBR points at the record and D at the
; packet, so a word costs one load, one XBA and one direct-page store.
; Whole passes of packet_copy_words come first; the last, shorter pass
; enters it at the copy of its highest word.
; In: A = the bytes (an odd count ends with a whole word), X = the packet
; place, Y = the record, packet_copy_bank = the bank of the record. A16,
; X16. JSL. Out: X = the end in the packet. A, Y: changed.
PACKET_COPY_PASS = 32           ; the words of one pass of packet_copy_words
PACKET_COPY_BYTES = 6           ; LDA abs,X + XBA + STA dp: one copy in packet_copy_words
.a16
.i16
packet_copy:
  phb
  phd
  phy                           ; the record
  inc
  lsr                           ; A = the words
  pha
  asl
  phx
  clc
  adc 1,s
  sta f:packet_copy_end
  pla
  tcd                           ; D = the packet place
  pla
  tay                           ; Y = the words
  and #PACKET_COPY_PASS-1
  beq :+                        ; whole passes only
  eor #$ffff
  sec
  adc #PACKET_COPY_PASS         ; the copies that the last pass skips
  sta f:packet_copy_entry
  asl
  adc f:packet_copy_entry
  asl                           ; times PACKET_COPY_BYTES
  adc #.loword(packet_copy_words)
:
  sta f:packet_copy_entry       ; 0: no shorter pass
  tya
  .repeat 5
  lsr                           ; / PACKET_COPY_PASS
  .endrepeat
  tay                           ; Y = the whole passes
  plx                           ; X = the record
  a8
  lda f:packet_copy_bank
  pha
  plb                           ; DBR = the bank of the record
  a16
  tya
  beq @last
@pass:
  jsr packet_copy_words
  txa
  clc
  adc #PACKET_COPY_PASS*2
  tax
  tdc
  clc
  adc #PACKET_COPY_PASS*2
  tcd
  dey
  bne @pass
@last:
  lda f:packet_copy_entry
  beq @done
  per @done-1                   ; the return of the shorter pass
  jmp (packet_copy_entry)       ; the pointer is in bank 0
@done:
  lda f:packet_copy_end
  tax
  pld
  plb
  rtl
.assert PACKET_COPY_PASS = 1 << 5, error  ; the five LSRs above

; packet_copy_words: PACKET_COPY_PASS words from DBR:X to D, the highest
; first. JSR.
packet_copy_words:
  .repeat PACKET_COPY_PASS, I
  lda a:2*(PACKET_COPY_PASS-1-I),x
  xba
  sta z:2*(PACKET_COPY_PASS-1-I)
  .endrepeat
  rts
.assert * - packet_copy_words = PACKET_COPY_PASS*PACKET_COPY_BYTES+1, error

packet_copy_bank: .res 1        ; the bank of the record (its caller sets it)
packet_copy_entry: .res 2       ; packet_copy: where the shorter pass starts
packet_copy_end: .res 2         ; packet_copy: the end in the packet
