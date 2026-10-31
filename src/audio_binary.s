; Expand shared two-state SSG tables once, before sound IRQ installation.
; Input: D=0, A8/X16, $30 source24, X page count, DOC RAM address already
; selected in auto-increment mode. A page is low, high, 32 packed bit bytes.
; No expanded host copy and no playback-time decompression.
.a8
.i16
AUDIO_BINARY_SOURCE = $30
AUDIO_BINARY_LOW = $33
AUDIO_BINARY_HIGH = $34
AUDIO_BINARY_BITS = $35
AUDIO_BINARY_COUNT = $36
AUDIO_BINARY_AM = $37

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
  lda #32
  sta AUDIO_BINARY_COUNT
@packed:
  lda [AUDIO_BINARY_SOURCE],y
  sta AUDIO_BINARY_BITS
  iny
  phx
  ldx #8
@pixel:
  lda f:$e0c03c
  bmi @pixel
  lsr AUDIO_BINARY_BITS
  lda AUDIO_BINARY_LOW
  bcc :+
  lda AUDIO_BINARY_HIGH
:
  sta f:$e0c03d
  dex
  bne @pixel
  plx
  dec AUDIO_BINARY_COUNT
  bne @packed
  dex
  bne @page
  rtl

; Mapping is build-prepared for the selected output law. It changes the
; hardware register convention, never the source's relative amplitude.
audio_binary_level:
  pha
  lda AUDIO_BINARY_AM
  beq @raw
  pla
  phx
  rep #$20
  and #255
  tax
  sep #$20
  lda f:AUDIO_VOLUME_MAP,x
  plx
  rts
@raw:
  pla
  rts
