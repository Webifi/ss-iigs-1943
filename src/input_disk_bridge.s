; The block driver requires bank-zero code, D=0 and an emulation stack.
; Preserve every game zero-page byte and the native stack/IRQ/GLU mapping.
; Driver/unit come from ProDOS's validated table at boot (Apple TN P8 #20).
.a8
.i16
input_disk_call:
  php
  sei
  rep #$30
  phx
  phy
  phb
  phd
.ifdef PRODUCTION_LC_WORLD
  ; The caller's P is eight bytes above the current stack. The swap only
  ; touches private world/firmware buffers, so permit the existing IRQ if
  ; the caller had enabled it; mask again before touching firmware state.
  tsc
  clc
  adc #8
  tax
  sep #$20
  lda f:$000000,x
  and #4
  sta f:input_save_interrupt_mask
  bne :+
  cli
:
  rep #$30
  jsr input_disk_swap_lc
  sei
.endif
  jsl native_settings_fw_restore
  ldx #254
@keep:
  lda f:$000000,x
  sta f:native_settings_zero,x
  dex
  dex
  bpl @keep
  lda #0
  tcd
  sep #$20
  pha
  plb
  lda f:$e0c035
  sta input_save_shadow
  and #$bf
  sta f:$e0c035
  lda input_save_command
  sta $42
  lda input_save_unit
  sta $43
  rep #$20
  lda #$0800
  sta $44
  lda input_save_block
  sta $46
  tsc
  sta input_save_stack
  sep #$30
  sec
  xce
  ldx #$ff
  txs
  lda input_save_sp_unit
  beq @legacy_driver
  jsr input_smartport_call
  bra @driver_done
@legacy_driver:
  jsr input_disk_jump
@driver_done:
  sta input_save_error
  lda #0
  rol
  sta input_save_carry
  clc
  xce
  rep #$30
  ldx input_save_stack
  txs
  sep #$20
  lda input_save_shadow
  sta f:$e0c035
  rep #$20
  ldx #254
@restore:
  lda f:native_settings_zero,x
  sta f:$000000,x
  dex
  dex
  bpl @restore
  jsl native_settings_fw_keep
  sep #$20
  jsl native_input_capture
.ifdef PRODUCTION_LC_WORLD
  ; The mapping, zero page and firmware state are restored. IRQ may safely
  ; run during the second swap, before returning to foreground game code.
  lda f:input_save_interrupt_mask
  bne :+
  cli
:
  rep #$30
  jsr input_disk_swap_lc
  sei
.endif
  rep #$30
  pld
  plb
  ply
  plx
  plp
  lda f:input_save_carry
  lsr
  lda f:input_save_error
  rtl
input_disk_jump:
  jmp (input_save_driver)
; SmartPort interprets the command and parameter pointer after the JSR.
; The indirect trampoline leaves that exact return address on the stack.
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
@command: .byte 0
  .word input_sp_params
  rts
input_smartport_jump:
  jmp (input_save_sp_entry)
input_sp_params:
  .byte 3
input_sp_unit: .byte 0
  .word $0800
input_sp_block: .byte 0,0,0
.ifdef PRODUCTION_LC_WORLD
.a16
.i16
input_disk_swap_lc:
  ldx #$0bfe
@swap:
  lda f:$00b000,x
  pha
  lda f:$01f400,x
  sta f:$00b000,x
  pla
  sta f:$01f400,x
  dex
  dex
  bpl @swap
.ifdef PRODUCTION_C_WORLD
  ; Bank-zero $C000 RAM is the alternate language-card bank while IOLC is
  ; enabled. Exchange it with the firmware image in the packet/loader gaps.
  ldx #$0bfe
@swap_c_first:
  lda f:$009400,x
  pha
  lda f:$00c000,x
  sta f:$009400,x
  pla
  sta f:$00c000,x
  dex
  dex
  bpl @swap_c_first
  ldx #$03fe
@swap_c_last:
  lda f:$00ac00,x
  pha
  lda f:$00cc00,x
  sta f:$00ac00,x
  pla
  sta f:$00cc00,x
  dex
  dex
  bpl @swap_c_last
.endif
  rts
.a8
.endif
input_save_sp_entry: .word 0
input_save_sp_unit: .byte 0
input_save_driver: .word 0
input_save_block: .word 0
input_save_unit: .byte 0
input_save_command: .byte 0
input_save_error: .byte 0
input_save_carry: .byte 0
input_save_shadow: .byte 0
input_save_stack: .word 0
.ifdef PRODUCTION_LC_WORLD
input_save_interrupt_mask: .byte 0
.endif
