; The disk bridge: one block read or write through the ProDOS block driver
; while the game runs (the settings save, src/input_native.s).
;
; The block driver needs bank-zero code, D = 0, the emulation stack and the
; firmware's RAM. The game uses that RAM for its world data, so the bridge
; swaps the firmware images back in, calls the driver, then swaps the game
; data back. It keeps every byte of the game page zero, the native stack,
; the IRQ setting and the sound GLU mapping.
; The driver and the unit come from the ProDOS device table at boot
; (Apple Technical Note ProDOS 8 #20); input_native.s sets input_save_*.
.a8
.i16
SP_BLOCK_PARAMETERS = 3         ; the parameter count of SmartPort READ/WRITE BLOCK

; input_disk_call: run the command in input_save_command on input_save_block,
; with the buffer SAVE_BLOCK_BUFFER. Called with JSL, any width.
; Returns: carry = the driver's error flag, A = its error code (A8).
; X, Y, D, DBR and P (except carry) are kept.
input_disk_call:
  php
  sei
  ax16
  phx
  phy
  phb
  phd
  ; The caller's P is 8 bytes up the stack (P, X, Y, DBR, D were pushed).
  ; The swap touches only private world and firmware buffers, so IRQ may run
  ; during it if the caller allowed IRQ. IRQ is masked again before the
  ; firmware state changes.
  a8
  lda 8,s
  and #P_IRQ_OFF
  sta f:input_save_interrupt_mask
  bne :+
  cli
:
  ax16
  jsr input_disk_swap_lc        ; the firmware's language card and $C000 RAM back
  sei
  jsl native_settings_fw_restore
  ; Keep the game page zero; the driver uses page zero freely.
  ldx #ZERO_PAGE_SIZE-2
@keep:
  lda f:ZERO_PAGE,x
  sta f:native_settings_zero,x
  dex
  dex
  bpl @keep
  lda #ZERO_PAGE                ; D = page zero, DBR = bank 0, as the driver expects
  tcd
  a8
  pha                           ; A is 0
  plb
  ; Show the I/O and the ROM at $C000-$FFFF again for the driver.
  lda f:SHADOW
  sta input_save_shadow
  and #<~SHADOW_IOLC
  sta f:SHADOW
  ; The driver parameters in page zero.
  lda input_save_command
  sta DRV_COMMAND
  lda input_save_unit
  sta DRV_UNIT
  a16
  lda #.loword(SAVE_BLOCK_BUFFER)
  sta DRV_BUFFER
  lda input_save_block
  sta DRV_BLOCK
  ; Emulation mode with the firmware stack; keep the native stack pointer.
  tsc
  sta input_save_stack
  ax8
  sec
  xce                           ; carry 1: emulation mode
  ldx #<EMULATION_STACK_TOP
  txs
  lda input_save_sp_unit        ; 0: a ProDOS block driver, else a SmartPort unit
  beq @legacy_driver
  jsr input_smartport_call
  bra @driver_done
@legacy_driver:
  jsr input_disk_jump
@driver_done:
  ; Keep the result: A = the error code, carry = the error flag.
  sta input_save_error
  lda #0
  rol                           ; A = the carry
  sta input_save_carry
  clc
  xce                           ; native mode again
  ax16
  ldx input_save_stack
  txs
  a8
  lda input_save_shadow
  sta f:SHADOW
  a16
  ldx #ZERO_PAGE_SIZE-2
@restore:
  lda f:native_settings_zero,x
  sta f:ZERO_PAGE,x
  dex
  dex
  bpl @restore
  jsl native_settings_fw_keep
  a8
  jsl native_input_capture
  ; The mapping, the page zero and the firmware state are back. IRQ may run
  ; during the second swap, before the return to the game.
  lda f:input_save_interrupt_mask
  bne :+
  cli
:
  ax16
  jsr input_disk_swap_lc        ; the game world data back
  sei
  ax16
  pld
  plb
  ply
  plx
  plp
  lda f:input_save_carry
  lsr                           ; carry = the driver's error flag
  lda f:input_save_error
  rtl

; input_disk_jump: a JSR here calls the ProDOS block driver (emulation mode).
input_disk_jump:
  jmp (input_save_driver)

; input_smartport_call: one SmartPort call. SmartPort reads the command byte
; and the parameter list address that follow its JSR; the indirect jump below
; keeps that return address on the stack. Emulation mode, A8, X8.
input_smartport_call:
  lda input_save_command
  sta @command
  lda input_save_sp_unit
  sta input_sp_unit
  lda input_save_block
  sta input_sp_block
  lda input_save_block+1
  sta input_sp_block+1
  jsr input_smartport_jump
@command: .byte 0               ; patched: the SmartPort command
  .word input_sp_params
  rts
input_smartport_jump:
  jmp (input_save_sp_entry)
; The SmartPort parameter list: count, unit, buffer, block number (3 bytes).
input_sp_params:
  .byte SP_BLOCK_PARAMETERS
input_sp_unit: .byte 0
  .word .loword(SAVE_BLOCK_BUFFER)
input_sp_block: .byte 0,0,0

; input_disk_swap_lc: exchange the game's world data with the firmware's
; images: the language card (LC_WORLD) and the bank-zero $C000 RAM
; (C_WORLD). The same call swaps both ways. A16, X16; A and X: changed.
.a16
.i16
input_disk_swap_lc:
  ldx #LC_WORLD_SIZE-2
@swap:
  lda f:FIRMWARE_LC_SAVE,x
  pha
  lda f:LC_WORLD,x
  sta f:FIRMWARE_LC_SAVE,x
  pla
  sta f:LC_WORLD,x
  dex
  dex
  bpl @swap
  ; Bank-zero $C000 RAM is the other language-card bank while IOLC is
  ; enabled. Exchange it with the firmware image that the handoff kept.
  ldx #C_WORLD_PART0_SIZE-2
@swap_c_first:
  lda f:FIRMWARE_C0_SAVE,x
  pha
  lda f:C_WORLD,x
  sta f:FIRMWARE_C0_SAVE,x
  pla
  sta f:C_WORLD,x
  dex
  dex
  bpl @swap_c_first
  ldx #C_WORLD_PART1_SIZE-2
@swap_c_last:
  lda f:FIRMWARE_C1_SAVE,x
  pha
  lda f:C_WORLD+C_WORLD_PART0_SIZE,x
  sta f:FIRMWARE_C1_SAVE,x
  pla
  sta f:C_WORLD+C_WORLD_PART0_SIZE,x
  dex
  dex
  bpl @swap_c_last
  rts

; The state of one bridge call. src/input_native.s sets the driver, the unit,
; the command and the block before the call; the bridge keeps the rest.
.a8
input_save_sp_entry: .word 0    ; the SmartPort entry address
input_save_sp_unit: .byte 0     ; the SmartPort unit; 0: use input_save_driver
input_save_driver: .word 0      ; the ProDOS block driver address
input_save_block: .word 0       ; the block number
input_save_unit: .byte 0        ; the ProDOS unit number (DSSS0000)
input_save_command: .byte 0     ; DRV_READ or DRV_WRITE
input_save_error: .byte 0       ; the driver's error code
input_save_carry: .byte 0       ; the driver's error flag (carry), 0 or 1
input_save_shadow: .byte 0      ; SHADOW of the game during the call
input_save_stack: .word 0       ; the native stack pointer during the call
input_save_interrupt_mask: .byte 0 ; P_IRQ_OFF of the caller's P
