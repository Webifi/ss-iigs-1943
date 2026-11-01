; audio_binary_upload: expand X packed pages of a shared SSG table into DOC
; RAM (audio_bank_init, before the sound interrupt). The GLU must address
; DOC RAM with auto-increment. A packed page: the low level, the high level,
; then BINARY_BYTES bytes of bits, bit 0 first: each bit gives one sample,
; 0 the low level and 1 the high level. With AUDIO_BINARY_AM the levels go
; through AUDIO_VOLUME_MAP. In: AUDIO_BINARY_SOURCE. JSL; A8, X16; D = 0.
.a8
.i16
BINARY_BYTES = 32            ; 256 samples of one bit

audio_binary_upload:
  ldy #0
@page:
  lda [AUDIO_BINARY_SOURCE],y
  jsr .loword(audio_binary_level)
  sta AUDIO_BINARY_LOW
  iny
  lda [AUDIO_BINARY_SOURCE],y
  jsr .loword(audio_binary_level)
  sta AUDIO_BINARY_HIGH
  iny
  lda #BINARY_BYTES
  sta AUDIO_BINARY_COUNT
@packed:
  lda [AUDIO_BINARY_SOURCE],y
  sta AUDIO_BINARY_BITS
  iny
  phx
  ldx #8
@pixel:
  lda f:SOUNDCTL
  bmi @pixel
  lsr AUDIO_BINARY_BITS
  lda AUDIO_BINARY_LOW
  bcc :+
  lda AUDIO_BINARY_HIGH
:
  sta f:SOUNDDATA
  dex
  bne @pixel
  plx
  dec AUDIO_BINARY_COUNT
  bne @packed
  dex
  bne @page
  rtl

; audio_binary_level: A = the DOC value of the level A. An AM table (the
; gate) gives DOC volumes: the build's AUDIO_VOLUME_MAP sets the output law;
; it keeps the relative amplitudes. Other tables give samples as they are.
; JSR; X kept.
audio_binary_level:
  pha
  lda AUDIO_BINARY_AM
  beq @raw
  pla
  phx
  a16
  and #255
  tax
  a8
  lda f:AUDIO_VOLUME_MAP,x
  plx
  rts
@raw:
  pla
  rts
