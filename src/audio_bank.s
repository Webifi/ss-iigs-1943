; audio_bank_init: the sound bank start-up (audio_game_init, before the sound
; interrupt). It expands the shared SSG tables (audio_tables, made by
; scripts/audio_bank_install.py) into DOC RAM, writes the audio_registers
; pairs (each SSG oscillator pair halted and silent), and clears the SSG
; effect state. JSL; A8, X16; D = 0.
.a8
.i16
audio_bank_init:
  ldx #0
@table:
  phx
  a16
  lda f:audio_tables+AT_SOURCE,x
  sta AUDIO_BINARY_SOURCE
  a8
  lda f:audio_tables+AT_SOURCE+2,x
  sta AUDIO_BINARY_SOURCE+2
  lda f:audio_tables+AT_AM,x
  sta AUDIO_BINARY_AM
  ; The GLU writes DOC RAM from the table's page on, one byte after another.
@ready:
  lda f:SOUNDCTL
  bmi @ready
  lda DOC_MASTER
  ora #SOUNDCTL_RAM|SOUNDCTL_INC
  sta f:SOUNDCTL
  lda #0
  sta f:SOUNDADRL
  lda f:audio_tables+AT_PAGE,x
  sta f:SOUNDADRH
  lda f:audio_tables+AT_PAGES,x
  a16
  and #255
  tax
  a8
  jsl audio_binary_upload
  rep #P_M8|P_CARRY             ; A 16 bits; clear carry
  pla
  adc #AT_SIZE
  tax
  a8
  cpx #AUDIO_TABLE_BYTES
  bne @table
@register_mode:
  lda f:SOUNDCTL
  bmi @register_mode
  lda DOC_MASTER
  sta f:SOUNDCTL
  ; The register and value pairs.
  ldx #0
@registers:
  lda f:SOUNDCTL
  bmi @registers
  lda f:audio_registers,x
  sta f:SOUNDADRL
  inx
  lda f:audio_registers,x
  sta f:SOUNDDATA
  inx
  cpx #AUDIO_REGISTER_BYTES
  bne @registers
  a16
  ldx #SSG_PARTS*SSG_PART_SIZE-2
  lda #0
@clear:
  sta f:SSG_STATES,x
  dex
  dex
  bpl @clear
  a8
  stz MUSIC_PAGE+SSG_PENDING
  stz MUSIC_PAGE+SSG_ACTIVE
  stz MUSIC_PAGE+SSG_NEXT
  stz MUSIC_PAGE+SSG_TIME
  rtl
