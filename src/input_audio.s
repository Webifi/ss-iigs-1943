; The sound mix (the music and effects levels, 0 to MIX_LEVEL_MAX) changes
; only at the settings load and in the pause menu; the players keep their
; ticks, instruments and events. The FM voices get a new register table;
; the SSG voices use AM, so their two-level waves get new amplitudes (the
; oscillator volume does nothing in AM mode).
.include "input_audio.inc"
.a16
.i16
MIX_LEVEL_MAX = 10
MIX_LEVELS = MIX_LEVEL_MAX+1 ; MIX_WAVE_GAINS: a row for each wave amplitude
MIX_CHUNK = 32               ; DOC bytes written with interrupts off
WAVE_LOW = 1                 ; the amplitudes of the packed SSG waves:
WAVE_MID = 128               ; low, middle, else high

; mix_settings: the mix fields: the defaults when not valid, the levels
; limited to MIX_LEVEL_MAX; then mix_apply. JSR.
mix_settings:
  lda a:.loword(settings+SET_MIX_FLAGS)
  and #$ff00
  cmp #MIX_MARK_DEFAULT&$ff00
  beq @valid
  lda #MIX_LEVELS_DEFAULT
  sta a:.loword(settings+SET_MUSIC_LEVEL)
  lda #MIX_MARK_DEFAULT
  sta a:.loword(settings+SET_MIX_FLAGS)
@valid:
  a8
  lda a:.loword(settings+SET_MUSIC_LEVEL)
  cmp #MIX_LEVEL_MAX+1
  bcc :+
  lda #MIX_LEVEL_MAX
  sta a:.loword(settings+SET_MUSIC_LEVEL)
:
  lda a:.loword(settings+SET_EFFECTS_LEVEL)
  cmp #MIX_LEVEL_MAX+1
  bcc :+
  lda #MIX_LEVEL_MAX
  sta a:.loword(settings+SET_EFFECTS_LEVEL)
:
  lda a:.loword(settings+SET_MIX_FLAGS)
  and #MIX_DEMO_SOUND           ; the only flag
  sta a:.loword(settings+SET_MIX_FLAGS)
  a16
  jsr .loword(mix_apply)
  rts

; mix_apply: a new music level: MIX_FM_REGISTERS from its MIX_FM_GAINS row
; (each FM volume is written again at its next visit); a new effects level:
; the shared SSG wave tables again with the MIX_WAVE_GAINS amplitudes. JSR.
mix_apply:
  a8
  lda a:.loword(settings+SET_MUSIC_LEVEL)
  cmp a:.loword(mixMusic)
  beq mix_apply_effects
  sta a:.loword(mixMusic)
  a16
  and #255
  xba                           ; a 256-byte row for each level
  clc
  adc #.loword(MIX_FM_GAINS)
  sta f:mix_fm_gain+1
  a8
  lda #.bankbyte(MIX_FM_GAINS)
  adc #0
  sta f:mix_fm_gain+3
  a16
  ldy #0
mix_apply_register:
  tyx
  a8
  lda f:MIX_FM_ORIGINAL,x
  a16
  and #255
  tax
  a8
mix_fm_gain:
  lda f:0,x                   ; the address is patched
  tyx
  sta f:MIX_FM_REGISTERS,x
  a16
  iny
  cpy #MIX_FM_BYTES
  bcc mix_apply_register
  ; The next visit of each part writes its volumes again on its tick.
  ldx #0
mix_apply_invalidate:
  lda #FM_PRI_UNKNOWN
  sta f:FM_STATES+S_PRIA,x
  sta f:FM_STATES+S_PRIB,x
  txa
  clc
  adc #FM_PART_SIZE
  tax
  cpx #FM_PARTS*FM_PART_SIZE
  bcc mix_apply_invalidate
  a8
mix_apply_effects:
  lda a:.loword(settings+SET_EFFECTS_LEVEL)
  cmp a:.loword(mixEffects)
  bne :+
  jmp .loword(mix_apply_done8)
:
  sta a:.loword(mixEffects)
  a16
  and #255
  clc
  adc #.loword(MIX_WAVE_GAINS)
  sta f:mix_wave_one+1          ; the three loads of mix_sample
  clc
  adc #MIX_LEVELS
  sta f:mix_wave_mid+1
  clc
  adc #MIX_LEVELS
  sta f:mix_wave_high+1
  a16
  stz a:.loword(mixEntry)
mix_apply_table:
  ; Each table of audio_tables (AT_* records), not the AM gate.
  ldx a:.loword(mixEntry)
  a8
  lda f:MIX_SSG_TABLES+AT_AM,x
  bne mix_apply_next            ; the gate keeps its levels
  a16
  lda f:MIX_SSG_TABLES+AT_SOURCE,x
  sta f:mix_read+1
  a8
  lda f:MIX_SSG_TABLES+AT_SOURCE+2,x
  sta f:mix_read+3
  lda f:MIX_SSG_TABLES+AT_PAGE,x
  sta a:.loword(mixDocPage)
  lda f:MIX_SSG_TABLES+AT_PAGES,x
  sta a:.loword(mixPages)
  ldx #0
mix_apply_page:
  jsr .loword(mix_read)
  jsr .loword(mix_sample)
  sta a:.loword(mixLow)
  jsr .loword(mix_read)
  jsr .loword(mix_sample)
  sta a:.loword(mixHigh)
  ldy #0
mix_apply_packed:
  ; A page: the low and high samples, then a bit for each of 256 samples
  ; (as audio_binary_upload).
  jsr .loword(mix_read)
  sta a:.loword(mixBits)
  lda #8
  sta a:.loword(mixBitCount)
mix_apply_pixel:
  lsr a:.loword(mixBits)
  lda a:.loword(mixLow)
  bcc :+
  lda a:.loword(mixHigh)
:
  sta a:mixBuffer&$ffff,y
  iny
  dec a:.loword(mixBitCount)
  bne mix_apply_pixel
  cpy #256
  bcc mix_apply_packed
  phx
  a16
  jsr .loword(mix_upload_page)
  plx
  a8
  inc a:.loword(mixDocPage)
  dec a:.loword(mixPages)
  bne mix_apply_page
mix_apply_next:
  a16
  lda a:.loword(mixEntry)
  clc
  adc #AT_SIZE
  sta a:.loword(mixEntry)
  cmp #MIX_SSG_TABLE_BYTES
  bcs :+
  jmp .loword(mix_apply_table)
:
  bra mix_apply_done
mix_apply_done8:
  a16
mix_apply_done:
  rts

.a8
; mix_read: A = the next byte of the table (the address is patched). JSR.
mix_read:
  lda f:0,x                   ; the address is patched
  inx
  rts
; mix_sample: A = the sample of the amplitude A at the effects level (the
; loads are patched to its MIX_WAVE_GAINS column). The build checks that
; each packed table uses only these three amplitudes. JSR; X kept.
mix_sample:
  cmp #WAVE_LOW
  beq mix_wave_one
  cmp #WAVE_MID
  beq mix_wave_mid
mix_wave_high:
  lda f:MIX_WAVE_GAINS+2*MIX_LEVELS
  rts
mix_wave_one:
  lda f:MIX_WAVE_GAINS
  rts
mix_wave_mid:
  lda f:MIX_WAVE_GAINS+MIX_LEVELS
  rts

; mix_upload_page: write mixBuffer to the DOC page mixDocPage, MIX_CHUNK
; bytes at a time with interrupts off; the GLU mode and address of the main
; loop come back before each interrupt. JSR; A16.
.a16
mix_upload_page:
  ldy #0
@chunk:
  php
  sei
  a8
@ready:
  lda f:SOUNDCTL
  bmi @ready
  and #SOUNDCTL_RAM|SOUNDCTL_INC
  ora f:DOC_MASTER
  sta a:.loword(mixControl)
  lda f:SOUNDADRL
  sta a:.loword(mixAddress)
  lda f:SOUNDADRH
  sta a:.loword(mixAddress+1)
  lda f:DOC_MASTER
  ora #SOUNDCTL_RAM|SOUNDCTL_INC
  sta f:SOUNDCTL
  tya
  sta f:SOUNDADRL
  lda a:.loword(mixDocPage)
  sta f:SOUNDADRH
  ldx #MIX_CHUNK
@byte:
  lda f:SOUNDCTL
  bmi @byte
  lda a:mixBuffer&$ffff,y
  sta f:SOUNDDATA
  iny
  dex
  bne @byte
@restore:
  lda f:SOUNDCTL
  bmi @restore
  lda a:.loword(mixAddress)
  sta f:SOUNDADRL
  lda a:.loword(mixAddress+1)
  sta f:SOUNDADRH
  lda a:.loword(mixControl)
  sta f:SOUNDCTL
  plp
  cpy #256
  bcc @chunk
  rts

; The levels in use, and the work of mix_apply.
mixMusic: .byte MIX_LEVEL_MAX
mixEffects: .byte MIX_LEVEL_MAX
mixDocPage: .byte 0
mixPages: .byte 0
mixLow: .byte 0
mixHigh: .byte 0
mixBits: .byte 0
mixBitCount: .byte 0
mixControl: .byte 0
mixAddress: .word 0
mixEntry: .word 0
mixBuffer: .res 256
