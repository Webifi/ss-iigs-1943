; audio_doc_write: write A to the DOC register X, with interrupts off. The
; GLU control (SOUNDCTL) gets DOC_MASTER: register mode and the volume. JSR;
; A8, X16; A, X kept.
.a8
.i16
audio_doc_write:
  php
  sei
  pha
@busy:
  lda f:SOUNDCTL
  bmi @busy
  lda DOC_MASTER
  sta f:SOUNDCTL
  txa
  sta f:SOUNDADRL
  pla
  sta f:SOUNDDATA
  plp
  rts

