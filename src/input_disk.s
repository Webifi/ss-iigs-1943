; The settings on the disk: one block that the build keeps for them. Only
; the Save of the pause menu calls the firmware; the game has no ProDOS code.
.a16
.i16

; settings_check: settings with a wrong magic or checksum become the
; defaults (the default bindings, DEAD_ZONE_DEFAULT). JSR.
settings_check:
  lda a:.loword(settings)
  cmp #SETTINGS_MAGIC0
  bne @reset
  lda a:.loword(settings+SET_MAGIC+2)
  cmp #SETTINGS_MAGIC1
  bne @reset
  lda a:.loword(settings+SET_MAGIC+4)
  cmp #SETTINGS_MAGIC2
  bne @reset
  lda a:.loword(settings+SET_MAGIC+6)
  cmp #SETTINGS_MAGIC3
  bne @reset
  jsr .loword(settings_sum)
  cmp a:.loword(settings+SETTINGS_CHECKSUM)
  beq @valid
@reset:
  ldx #SETTINGS_CHECKSUM-2
  lda #0
@clear:
  sta a:.loword(settings),x
  dex
  dex
  bpl @clear
  lda #SETTINGS_MAGIC0
  sta a:.loword(settings)
  lda #SETTINGS_MAGIC1
  sta a:.loword(settings+SET_MAGIC+2)
  lda #SETTINGS_MAGIC2
  sta a:.loword(settings+SET_MAGIC+4)
  lda #SETTINGS_MAGIC3
  sta a:.loword(settings+SET_MAGIC+6)
  lda #DEAD_ZONE_DEFAULT
  sta a:.loword(settings+SET_DEAD_ZONE)
  ldx #SET_DISPLAY_MARK-SET_BINDINGS-2
@copy:
  lda a:.loword(menu_default_bindings),x
  sta a:.loword(settings+SET_BINDINGS+BIND_KEY),x
  dex
  dex
  bpl @copy
@valid:
  rts
; settings_sum: A = the checksum of the settings before SETTINGS_CHECKSUM: a
; rotate left and an EOR for each word, from SETTINGS_SEED. JSR.
settings_sum:
  lda #SETTINGS_SEED
  ldx #0
@word:
  asl
  adc #0
  eor a:.loword(settings),x
  inx
  inx
  cpx #SETTINGS_CHECKSUM
  bcc @word
  rts

; settings_save: write the settings block: the J13 settings, the checksum;
; the block is read first and must hold settings (the magic), then written
; and read back to check. menuMessage: MSG_SAVED or MSG_SAVE_ERROR. JSR.
settings_save:
  jsl J13SettingsStore
  jsr .loword(settings_sum)
  sta a:.loword(settings+SETTINGS_CHECKSUM)
  lda f:input_save_driver
  cmp #SLOT1_ROM              ; reject RAM drivers overwritten by game data
  bcc @error
  a8
  lda #DRV_READ
  sta f:input_save_command
  jsl input_disk_call
  a16
  bcs @error
  ldx #SET_J13-2                ; the magic
@identity:
  lda f:SAVE_BLOCK_BUFFER,x
  cmp a:.loword(settings),x
  bne @error
  dex
  dex
  bpl @identity
  ldx #SETTINGS_SIZE-2
@copy:
  lda a:.loword(settings),x
  sta f:SAVE_BLOCK_BUFFER,x
  dex
  dex
  bpl @copy
  a8
  lda #DRV_WRITE
  sta f:input_save_command
  jsl input_disk_call
  a16
  bcs @error
  a8
  lda #DRV_READ
  sta f:input_save_command
  jsl input_disk_call
  a16
  bcs @error
  ldx #SETTINGS_SIZE-2
@verify:
  lda f:SAVE_BLOCK_BUFFER,x
  cmp a:.loword(settings),x
  bne @error
  dex
  dex
  bpl @verify
  lda #MSG_SAVED
  sta a:.loword(menuMessage)
  rts
@error:
  lda #MSG_SAVE_ERROR
  sta a:.loword(menuMessage)
  rts

; settings_fw_keep, settings_fw_restore: keep the disk firmware work areas
; of bank $E1 (FW_E1_WORK0, FW_E1_WORK1) around a firmware call (as the
; Wolf3D port); the game does not use them. JSL.
settings_fw_keep:
  php
  ax16
  phb
  ldx #.loword(FW_E1_WORK0)
  ldy #.loword(firmwareState)
  lda #FW_E1_WORK_SIZE-1
  mvn #^FW_E1_WORK0,#^firmwareState
  ldx #.loword(FW_E1_WORK1)
  ldy #.loword(firmwareState+FW_E1_WORK_SIZE)
  lda #FW_E1_WORK_SIZE-1
  mvn #^FW_E1_WORK1,#^firmwareState
  plb
  plp
  rtl
settings_fw_restore:
  php
  ax16
  phb
  ldx #.loword(firmwareState)
  ldy #.loword(FW_E1_WORK0)
  lda #FW_E1_WORK_SIZE-1
  mvn #^firmwareState,#^FW_E1_WORK0
  ldx #.loword(firmwareState+FW_E1_WORK_SIZE)
  ldy #.loword(FW_E1_WORK1)
  lda #FW_E1_WORK_SIZE-1
  mvn #^firmwareState,#^FW_E1_WORK1
  plb
  plp
  rtl
; The kept firmware work areas, and the kept zero page of a disk call.
firmwareState: .res 2*::FW_E1_WORK_SIZE
firmwareZero: .res ::ZERO_PAGE_SIZE
.assert SET_MAGIC = 0 .and SET_J13 = 8, error
