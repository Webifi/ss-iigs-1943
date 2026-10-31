; Native command packet at bank 0 $8000, with byte-swapped words for PEI.
; $28 = payload bytes, A = DMA1 ready token ($40/$41). No IRQ is installed.
; M=8/X=16, DBR=DP=0. Interrupts are already disabled by the game entry.
stream_packet:
  sta $60
.ifdef STREAM_PROFILE
  lda $68
  sta f:$05040a
.endif
  ldy #$ffff
@wait:
.ifdef AUDIO_GAME
  phy
  jsl audio_game_upload
  ply
.endif
.ifdef STREAM_POLL_INPUT
  phy
  jsr input_poll
  ply
.endif
  lda f:$e0c0b8
  cmp $60
  beq @ready
  dey
  bne @wait
  jmp failed
@ready:
.ifdef AUDIO_GAME
  php
  sei
  ; Stack writes must reach slot I/O in bank zero. The raw IRQ vector
  ; uses RAM at $FFEE, so restore its mapping before unmasking interrupts.
  lda f:$e0c035
  and #$bf
  sta f:$e0c035
.endif
.ifdef STREAM_PROFILE
  lda $68
  sta f:$05040b
.endif
  rep #$30
  tsc
  sta f:$050310
  lda $28
  clc
  adc #2
  pha
  and #255
  tay
  pla
  xba
  and #255
  tax
  lda #$8000
  tcd
  cpx #0
  bne @page
  jmp @tail
@page:
  .repeat 32,I
    lda #$c0b7
    tcs
    pei (I*8)
    pei (I*8+2)
    pei (I*8+4)
    pei (I*8+6)
  .endrepeat
  tdc
  clc
  adc #256
  tcd
  dex
  beq @tail
  jmp @page
@tail:
  ; Use the same eight-byte event burst for the remainder. Previously up to
  ; 254 bytes took the scalar word path just because they crossed a page.
  cpy #8
  bcc @short_tail
@eight:
  lda #$c0b7
  tcs
  pei (0)
  pei (2)
  pei (4)
  pei (6)
  tdc
  clc
  adc #8
  tcd
  tya
  sec
  sbc #8
  tay
  cmp #8
  bcs @eight
@short_tail:
  lda f:$050310
  tcs
  tdc
  tax
  lda #0
  tcd
  cpy #0
  beq @done
@word:
  lda a:$0000,x
  xba
  sta f:$e0c0b1
  inx
  inx
  dey
  dey
  bne @word
@done:
  sep #$20
.ifdef AUDIO_GAME
  lda f:$e0c035
  ora #$40
  sta f:$e0c035
  plp
.endif
.ifdef STREAM_PROFILE
  lda $68
  sta f:$05040c
.endif
  rts
