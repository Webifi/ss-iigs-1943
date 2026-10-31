; Mix changes run only at settings load or in the paused menu. The players
; retain their original ticks, instruments, envelope and frequency events.
; FM uses its existing register lookup. SSG uses AM, so change its two-level
; wave amplitudes; ordinary oscillator volume has no effect in AM mode.
.include "input_audio.inc"
.a16
.i16
mix_settings:
  lda a:.loword(settings+14)
  and #$ff00
  cmp #$a500
  beq @valid
  lda #$0a0a
  sta a:.loword(settings+12)
  lda #$a501
  sta a:.loword(settings+14)
@valid:
  sep #$20
  lda a:.loword(settings+12)
  cmp #11
  bcc :+
  lda #10
  sta a:.loword(settings+12)
:
  lda a:.loword(settings+13)
  cmp #11
  bcc :+
  lda #10
  sta a:.loword(settings+13)
:
  lda a:.loword(settings+14)
  and #1
  sta a:.loword(settings+14)
  rep #$20
  jsr .loword(mix_apply)
  rts

mix_apply:
  sep #$20
  lda a:.loword(settings+12)
  cmp a:.loword(mixMusic)
  beq mix_apply_effects
  sta a:.loword(mixMusic)
  rep #$20
  and #255
  xba
  clc
  adc #.loword(MIX_FM_GAINS)
  sta f:mix_fm_gain+1
  sep #$20
  lda #.bankbyte(MIX_FM_GAINS)
  adc #0
  sta f:mix_fm_gain+3
  rep #$20
  ldy #0
mix_apply_register:
  tyx
  sep #$20
  lda f:MIX_FM_ORIGINAL,x
  rep #$20
  and #255
  tax
  sep #$20
mix_fm_gain:
  lda f:$000000,x
  tyx
  sta f:MIX_FM_REGISTERS,x
  rep #$20
  iny
  cpy #MIX_FM_BYTES
  bcc mix_apply_register
  ; The next normal part visit publishes the new value on its exact tick.
  ldx #0
mix_apply_invalidate:
  lda #$ffff
  sta f:$018628,x
  sta f:$01862a,x
  txa
  clc
  adc #64
  tax
  cpx #384
  bcc mix_apply_invalidate
  sep #$20
mix_apply_effects:
  lda a:.loword(settings+13)
  cmp a:.loword(mixEffects)
  bne :+
  jmp .loword(mix_apply_done8)
:
  sta a:.loword(mixEffects)
  rep #$20
  and #255
  clc
  adc #.loword(MIX_WAVE_GAINS)
  sta f:mix_wave_one+1
  clc
  adc #11
  sta f:mix_wave_mid+1
  clc
  adc #11
  sta f:mix_wave_high+1
  rep #$20
  stz a:.loword(mixEntry)
mix_apply_table:
  ldx a:.loword(mixEntry)
  sep #$20
  lda f:MIX_SSG_TABLES+4,x
  bne mix_apply_next                   ; keep the AM envelope and its diode-law map
  rep #$20
  lda f:MIX_SSG_TABLES,x
  sta f:mix_read+1
  sep #$20
  lda f:MIX_SSG_TABLES+2,x
  sta f:mix_read+3
  lda f:MIX_SSG_TABLES+3,x
  sta a:.loword(mixDocPage)
  lda f:MIX_SSG_TABLES+5,x
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
  rep #$20
  jsr .loword(mix_upload_page)
  plx
  sep #$20
  inc a:.loword(mixDocPage)
  dec a:.loword(mixPages)
  bne mix_apply_page
mix_apply_next:
  rep #$20
  lda a:.loword(mixEntry)
  clc
  adc #6
  sta a:.loword(mixEntry)
  cmp #MIX_SSG_TABLE_BYTES
  bcs :+
  jmp .loword(mix_apply_table)
:
  bra mix_apply_done
mix_apply_done8:
  rep #$20
mix_apply_done:
  rts

.a8
mix_read:
  lda f:$000000,x
  inx
  rts
mix_sample:
  ; Build verifies that every packed, non-envelope page uses only these
  ; three amplitudes. The selected-volume loads preserve the source index.
  cmp #1
  beq mix_wave_one
  cmp #128
  beq mix_wave_mid
mix_wave_high:
  lda f:MIX_WAVE_GAINS+22
  rts
mix_wave_one:
  lda f:MIX_WAVE_GAINS
  rts
mix_wave_mid:
  lda f:MIX_WAVE_GAINS+11
  rts

; At most 32 bytes with IRQs masked. Restore the GLU address and mode before
; allowing the DOC/input IRQ, which itself preserves the caller's GLU state.
.a16
mix_upload_page:
  ldy #0
@chunk:
  php
  sei
  sep #$20
@ready:
  lda f:$e0c03c
  bmi @ready
  and #$60
  ora f:DOC_MASTER
  sta a:.loword(mixControl)
  lda f:$e0c03e
  sta a:.loword(mixAddress)
  lda f:$e0c03f
  sta a:.loword(mixAddress+1)
  lda f:DOC_MASTER
  ora #$60
  sta f:$e0c03c
  tya
  sta f:$e0c03e
  lda a:.loword(mixDocPage)
  sta f:$e0c03f
  ldx #32
@byte:
  lda f:$e0c03c
  bmi @byte
  lda a:mixBuffer&$ffff,y
  sta f:$e0c03d
  iny
  dex
  bne @byte
@restore:
  lda f:$e0c03c
  bmi @restore
  lda a:.loword(mixAddress)
  sta f:$e0c03e
  lda a:.loword(mixAddress+1)
  sta f:$e0c03f
  lda a:.loword(mixControl)
  sta f:$e0c03c
  plp
  cpy #256
  bcc @chunk
  rts

; Called after game_flow_init sets the ordinary DIP defaults.
.a8
mix_demo:
  lda f:settings+14
  and #1
  beq @off
  lda f:GAME_DIP_B
  ora #128
  bra @store
@off:
  lda f:GAME_DIP_B
  and #127
@store:
  sta f:GAME_DIP_B
  rtl

mixMusic: .byte 10
mixEffects: .byte 10
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
