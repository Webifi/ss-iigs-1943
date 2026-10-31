; Configuration has one preallocated disk block. Only the explicit paused
; Save action reaches the firmware; no ProDOS code remains in the game path.
.a16
.i16
settings_check:
  lda a:.loword(settings)
  cmp #$3931
  bne @reset
  lda a:.loword(settings+2)
  cmp #$3334
  bne @reset
  lda a:.loword(settings+4)
  cmp #$454b
  bne @reset
  lda a:.loword(settings+6)
  cmp #$0159
  bne @reset
  jsr .loword(settings_sum)
  cmp a:.loword(settings+510)
  beq @valid
@reset:
  ldx #508
  lda #0
@clear:
  sta a:.loword(settings),x
  dex
  dex
  bpl @clear
  lda #$3931
  sta a:.loword(settings)
  lda #$3334
  sta a:.loword(settings+2)
  lda #$454b
  sta a:.loword(settings+4)
  lda #$0159
  sta a:.loword(settings+6)
  lda #9
  sta a:.loword(settings+10)
  ldx #254
@copy:
  lda a:.loword(menu_default_bindings),x
  sta a:.loword(settings+32),x
  dex
  dex
  bpl @copy
@valid:
  rts
settings_sum:
  lda #$1943
  ldx #0
@word:
  asl
  adc #0
  eor a:.loword(settings),x
  inx
  inx
  cpx #510
  bcc @word
  rts

settings_save:
  jsl J13SettingsStore
  jsr .loword(settings_sum)
  sta a:.loword(settings+510)
  lda f:input_save_driver
  cmp #$c100                  ; reject RAM drivers overwritten by game data
  bcc @error
  sep #$20
  lda #1
  sta f:input_save_command
  jsl input_disk_call
  rep #$20
  bcs @error
  ldx #6
@identity:
  lda f:$000800,x
  cmp a:.loword(settings),x
  bne @error
  dex
  dex
  bpl @identity
  ldx #510
@copy:
  lda a:.loword(settings),x
  sta f:$000800,x
  dex
  dex
  bpl @copy
  sep #$20
  lda #2
  sta f:input_save_command
  jsl input_disk_call
  rep #$20
  bcs @error
  sep #$20
  lda #1
  sta f:input_save_command
  jsl input_disk_call
  rep #$20
  bcs @error
  ldx #510
@verify:
  lda f:$000800,x
  cmp a:.loword(settings),x
  bne @error
  dex
  dex
  bpl @verify
  lda #1
  sta a:.loword(menuMessage)
  rts
@error:
  lda #3
  sta a:.loword(menuMessage)
  rts

; Wolf's firmware-state guard: the game never allocates these E1 ranges,
; but retain their disk-firmware state across every firmware call anyway.
settings_fw_keep:
  php
  rep #$30
  phb
  ldx #0
  ldy #.loword(firmwareState)
  lda #1023
  .byte $54,.bankbyte(firmwareState),$e1
  ldx #$0c00
  ldy #.loword(firmwareState+1024)
  lda #1023
  .byte $54,.bankbyte(firmwareState),$e1
  plb
  plp
  rtl
settings_fw_restore:
  php
  rep #$30
  phb
  ldx #.loword(firmwareState)
  ldy #0
  lda #1023
  .byte $54,$e1,.bankbyte(firmwareState)
  ldx #.loword(firmwareState+1024)
  ldy #$0c00
  lda #1023
  .byte $54,$e1,.bankbyte(firmwareState)
  plb
  plp
  rtl
firmwareState: .res 2048
firmwareZero: .res 256
