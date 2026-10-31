; Native input event bank. Capture publishes time/source/value before head.
; Shared physical keys retain source ownership across menu/game transitions.
; Wolf mechanisms are in input_adb.s and input_j13.s; game bindings live here.
.a8
.i16
input_native:
.scope input_native
KBDSTRB = $e0c010
KEYMODREG = $e0c025
MOUSEDATA = $e0c024
DATAREG = $e0c026
KMSTATUS = $e0c027
KBD = $e0c000
BUTN0 = $e0c061
BUTN1 = $e0c062
ZIPCANCEL = $e0c05f
ROMVER = $fffb59

BIND_COUNT = 64

; Entry wrappers restore the game's DBR, DP and width. Private data uses PB.
start:
  php
  sei
  rep #$30
  phb
  phd
  lda #0
  tcd
  phk
  plb
  ldx #127
  sep #$20
@held:
  lda #0
  sta f:keyHeld,x
  dex
  bpl @held
  rep #$20
  jsl settings_fw_keep
  jsl J13Init
  sep #$20
  ldy #4096
@drain:
  .a8
  lda f:KMSTATUS
  and #$20
  beq @modes
  lda f:DATAREG
  dey
  bne @drain
@modes:
  lda a:.loword(j13AdbPresent)
  beq @compat
  lda #4
  jsr .loword(sendBounded)
  lda #1
  jsr .loword(sendBounded)
  lda #$52
  jsr .loword(sendBounded)
  bra @ready
@compat:
  lda #5
  jsr .loword(sendBounded)
  lda #1
  jsr .loword(sendBounded)
@ready:
  rep #$20
  jsl J13Prime
  jsl J13Menu
  jsr .loword(defaults)
  sep #$20
  lda #1
  sta a:.loword(ready)
  lda #$50
  sta f:KMSTATUS
  rep #$20
  lda #$ffff
  sta f:INPUT_P1
  sep #$20
  sta f:INPUT_P2
  pld
  plb
  plp
  rtl

; Called by the shared IRQ with its CPU registers saved. DOC transactions
; are already preserved by music_irq; these entries never touch the GLU.
capture:
  lda f:ready
  beq @empty
  lda f:j13Owner
  bne @work
  lda f:KMSTATUS
  and #$a0
  bne @work
  lda f:keyPending
  bne @work
@empty:
  bra capture_done
@work:
  phb
  phd
  rep #$30
  lda #0
  tcd
  phk
  plb
  lda a:.loword(j13Owner)
  beq :+
  jsr .loword(J13Pump)
:
  jsl CaptureInput
  pld
  plb
  sep #$20
capture_done:
  rtl

doc_tick:
  lda f:ready
  beq @empty
  lda f:j13Available
  bne @work
@empty:
  bra doc_tick_done
@work:
  phb
  phd
  rep #$30
  lda #0
  tcd
  phk
  plb
  lda a:.loword(j13SendTimer)
  beq :+
  jsr .loword(sendAlarm)
:
  lda a:.loword(j13Mode)
  cmp #2
  bne @done
  jsr .loword(readControllerClock)
  jsr .loword(j13Irq)
@done:
  pld
  plb
  sep #$20
doc_tick_done:
  rtl

idle:
  php
  phb
  phk
  plb
  sep #$20
  jsr .loword(devices_idle)
  plb
  plp
idle_done:
  rtl

I_GetTime:
  lda f:$001e96
  rtl

; One event frontier per game update. The caller can select a historical
; DOC frontier for catch-up with sample_until; ordinary callers use now.
sample:
  rep #$20
  lda f:$001e96
sample_until:
  php
  phb
  phd
  rep #$30
  pha
  lda #0
  tcd
  phk
  plb
  pla
  sta a:.loword(inputUntil)
  lda a:.loword(inputHead)
  sta a:.loword(inputLimit)
  lda a:.loword(j13Available)
  beq @events
  ; A menu or attract never prevents the compatibility keyboard opening Esc.
  lda a:.loword(menuMode)
  bne @menu
  lda f:$001490               ; GAME_FLOW, initialized by cabinet start
  and #255
  cmp #3
  bcs @menu
  lda f:$001520               ; CAB_DEMO
  and #255
  bne @menu
  lda a:.loword(j13Enabled)
  beq @raw
  lda #2
  bra @mode
@menu:
  lda #1
  bra @mode
@raw:
  lda #0
@mode:
  cmp a:.loword(j13Mode)
  beq @same
  jsl setMode
@same:
  lda a:.loword(j13Mode)
  cmp #2
  bne @poll
  jsl J13Frame
  bra @events
@poll:
  jsl J13Poll
@events:
  lda a:.loword(inputHead)
  sta a:.loword(inputLimit)
  jsr .loword(drain)
  jsr .loword(devices_sample)
  lda a:.loword(heldCommand)
  ora a:.loword(keyLatch)
  eor #$ffff
  sep #$20
  sta f:INPUT_P1
  xba
  sta f:INPUT_P2
  lda a:.loword(systemCommand)
  ora a:.loword(systemLatch)
  eor #255
  sta f:INPUT_SYSTEM
  rep #$20
  stz a:.loword(keyLatch)
  stz a:.loword(systemLatch)
  lda #0                      ; native game expects B=0 for byte-to-index moves
  pld
  plb
  plp
  sep #$20
sample_done:
  rtl

; The second 60 Hz logic tick consumes its own timestamp frontier. Hardware
; sampling stays in the IRQ; coin/pause edges remain latched for cabinet_frame.
.a16
consume_until:
  php
  phb
  phd
  rep #$30
  pha
  lda #0
  tcd
  phk
  plb
  pla
  sta a:.loword(inputUntil)
  lda a:.loword(inputHead)
  sta a:.loword(inputLimit)
  jsr .loword(drain)
  sep #$20
  jsr .loword(mouse_directions)
  rep #$20
  lda a:.loword(heldCommand)
  ora a:.loword(keyLatch)
  eor #$ffff
  sep #$20
  sta f:INPUT_P1
  xba
  sta f:INPUT_P2
  rep #$20
  stz a:.loword(keyLatch)
  lda #0
  pld
  plb
  plp
  sep #$20
consume_done:
  rtl

; Each key release removes only its source. Presses shorter than an update
; remain latched once, while held direction state follows all released aliases.
drain:
  .a16
  stz a:.loword(drainPress)
  stz a:.loword(drainPress+2)
  stz a:.loword(drainRelease)
  stz a:.loword(drainRelease+2)
@loop:
  ldx a:.loword(inputTail)
  cpx a:.loword(inputLimit)
  bne :+
  jmp .loword(@done)
:
  lda a:.loword(inputUntil)
  sec
  sbc a:.loword(inputRing),x
  bpl :+
  jmp .loword(@done)
:
  lda a:.loword(inputRing+2),x
  cmp #1
  bne :+
  jmp .loword(@mouse)
:
  lsr
  inc
  sta a:.loword(keySource)
  lda a:.loword(inputRing+4),x
  sta a:.loword(keyRaw)
  and #127
  tay
  sep #$20
  lda a:.loword(keyRaw)
  bmi @release
  lda a:.loword(keyHeld),y
  and a:.loword(keySource)
  bne @unchanged
  lda #1
  sta a:.loword(maskPressed)
  jsr .loword(drain_transition)
  bcc :+
  rep #$20
  jmp .loword(@done)
:
  .a8
  lda a:.loword(keyHeld),y
  ora a:.loword(keySource)
  sta a:.loword(keyHeld),y
  lda #1
  sta a:.loword(maskPressed)
  rep #$20
  lda a:.loword(keyRaw)
  sta a:.loword(keyAction)
  lda a:.loword(keySource)
  sta a:.loword(actionSource)
  inc a:.loword(inputSerial)
  bra @apply
@release:
  .a8
  lda a:.loword(keyHeld),y
  and a:.loword(keySource)
  beq @unchanged
  stz a:.loword(maskPressed)
  jsr .loword(drain_transition)
  bcc :+
  rep #$20
  jmp .loword(@done)
:
  .a8
  lda a:.loword(keySource)
  eor #255
  and a:.loword(keyHeld),y
  sta a:.loword(keyHeld),y
  stz a:.loword(maskPressed)
  rep #$20
@apply:
  lda a:.loword(keySource)
  dec
  xba
  lsr
  sta a:.loword(maskIndex)
  lda a:.loword(keyRaw)
  and #127
  ora a:.loword(maskIndex)
  asl
  asl
  tax
  sep #$20
  lda a:.loword(maskPressed)
  jsr .loword(apply_key_mask)
@unchanged:
  rep #$20
  bra @next
@mouse:
  sep #$20
  lda a:.loword(inputRing+4),x
  jsr .loword(mouse_signed)
  clc
  adc a:.loword(mouseX)
  jsr .loword(mouse_clamp)
  sta a:.loword(mouseX)
  lda a:.loword(inputRing+6),x
  pha
  jsr .loword(mouse_signed)
  clc
  adc a:.loword(mouseY)
  jsr .loword(mouse_clamp)
  sta a:.loword(mouseY)
  pla
  eor #128
  and #128
  beq @mouse_up
  lda #1
@mouse_up:
  ldx #36
  jsr .loword(set_device)
  rep #$20
@next:
  lda a:.loword(inputTail)
  clc
  adc #8
  and #1023
  sta a:.loword(inputTail)
  jmp .loword(@loop)
@done:
  rts

; Preserve opposing edges of the same action for separate logic updates.
; Leave the blocked event in the ring; unrelated sources retain their order.
.a8
drain_transition:
  rep #$20
  lda a:.loword(keySource)
  dec
  xba
  lsr
  sta a:.loword(maskIndex)
  lda a:.loword(keyRaw)
  and #127
  ora a:.loword(maskIndex)
  asl
  asl
  tax
  sep #$20
  lda a:.loword(maskPressed)
  beq @up
  rep #$20
  lda a:.loword(commandMasks),x
  and a:.loword(drainRelease)
  bne @blocked
  lda a:.loword(commandMasks+2),x
  and a:.loword(drainRelease+2)
  bne @blocked
  lda a:.loword(commandMasks),x
  ora a:.loword(drainPress)
  sta a:.loword(drainPress)
  lda a:.loword(commandMasks+2),x
  ora a:.loword(drainPress+2)
  sta a:.loword(drainPress+2)
  bra @ok
@up:
  rep #$20
  lda a:.loword(commandMasks),x
  and a:.loword(drainPress)
  bne @blocked
  lda a:.loword(commandMasks+2),x
  and a:.loword(drainPress+2)
  bne @blocked
  lda a:.loword(commandMasks),x
  ora a:.loword(drainRelease)
  sta a:.loword(drainRelease)
  lda a:.loword(commandMasks+2),x
  ora a:.loword(drainRelease+2)
  sta a:.loword(drainRelease+2)
@ok:
  sep #$20
  clc
  rts
@blocked:
  sep #$20
  sec
  rts
.a8
mouse_signed:
  and #127
  bit #64
  beq :+
  ora #128
:
  rts
mouse_clamp:
  bpl @positive
  cmp #$e0
  bcs @done
  lda #$e0
  rts
@positive:
  cmp #33
  bcc @done
  lda #32
@done:
  rts
center:
  php
  rep #$20
  lda #0
  sta f:mouseX
  sta f:mouseY
  plp
  rtl

.include "input_bindings.s"
.include "input_adb.s"
.include "input_j13.s"
.include "input_devices.s"
.include "input_settings.s"
.include "input_audio.s"
.include "input_menu.s"
.include "input_disk.s"
.include "input_menu_data.inc"
.a16
ready: .byte 0
inputHead: .word 0
inputTail: .word 0
inputLimit: .word 0
inputUntil: .word 0
inputDropped: .word 0
inputSerial: .word 0
inputRing: .res 1024
irqType: .word 0
irqValue: .word 0
irqAux: .word 0
keyTalk: .word 0
keyPending: .word 0
keyReply: .word 0
keyHeaderByte: .word 0
keyRaw: .word 0
keySource: .word 1
keyAction: .word 255
heldCommand: .word 0
systemCommand: .word 0
keyLatch: .word 0
systemLatch: .word 0
drainPress: .res 4
drainRelease: .res 4
maskIndex: .word 0
mouseTalkCount: .word 0
mouseX: .word 0
mouseY: .word 0
menuMode: .word 0
uiGameOn: .word 0
musicActive: .word 1
keyHeld: .res 128
actionSource: .word 0
boundKeys: .res BIND_COUNT*2
boundBits: .res BIND_COUNT*2
boundSources: .res BIND_COUNT*2
boundSystem: .res BIND_COUNT*2
.endscope

native_input_start = input_native::start
native_input_idle = input_native::idle
native_input_sample = input_native::sample
native_input_center = input_native::center
native_input_keyHeld = input_native::keyHeld
native_input_doc_tick = input_native::doc_tick
native_input_capture = input_native::capture
native_input_sample_until = input_native::sample_until
native_input_consume_until = input_native::consume_until

native_input_menu = input_native::menu_check
native_input_settings = input_native::settings

native_settings_fw_keep = input_native::settings_fw_keep
native_settings_fw_restore = input_native::settings_fw_restore
native_settings_zero = input_native::firmwareZero

native_input_demo_sound = input_native::mix_demo
