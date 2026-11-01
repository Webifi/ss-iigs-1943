; The native input: the ADB keyboard, the mouse, the J13 keyboard, the
; joystick and the pads become the bits of INPUT_P1, INPUT_P2 and
; INPUT_SYSTEM. The interrupts put timestamped events in inputRing (the
; Wolf3D code in input_adb.s and input_j13.s); each update applies the
; events up to its time (drain). A key that two sources hold stays held
; until both release it. The entries keep the DBR, D and widths of the
; game; this code and its data use the program bank.
.a8
.i16
input_native:
.scope input_native
BIND_COUNT = 64              ; the most key bindings (boundKeys...)
BINDINGS_BYTES = BIND_COUNT*BINDING_SIZE  ; the binding records of the settings
KEY_DRAIN_MAX = 4096         ; start: the most old DATAREG bytes to read
J13_ESCAPE = 0               ; j13Mode: the J13 code looks only for Esc
J13_MENU = 1                 ; j13Mode: a menu, a cabinet page or the demo
J13_PLAY = 2                 ; j13Mode: the play reads the J13 rows each frame
MOUSE_MOVE_BITS = $7f        ; an ADB mouse byte: a 7-bit signed move
MOUSE_MOVE_SIGN = $40
MOUSE_BUTTON_UP = $80        ; the mouse Y byte: the button is up
MOUSE_RANGE = 32             ; mouseX and mouseY stay in -MOUSE_RANGE..MOUSE_RANGE
INPUT_RELEASED = $ffff       ; INPUT_P1, INPUT_SYSTEM, INPUT_P2: a bit is 0 when pressed

; start (native_input_start): clear the held keys, keep the firmware
; settings, find the ROM 00/01 J13 keyboard, empty the GLU and set its
; modes: with a raw ADB keyboard the game asks for the keys itself (no
; keyboard poll, the keyboard service request on); else the firmware polls
; the keyboard. Then the bindings, the ADB interrupts on and all inputs
; released. JSL.
start:
  php
  sei
  ax16
  phb
  phd
  lda #0
  tcd
  phk
  plb
  ldx #KEY_CODES-1
  a8
@held:
  lda #0
  sta f:keyHeld,x
  dex
  bpl @held
  a16
  jsl settings_fw_keep
  jsl J13Init
  ; Without the J13 keyboard the timer interrupt has no J13 work: its call
  ; becomes a branch over the call's address (interrupts are off).
  lda a:.loword(j13Available)
  bne :+
  lda #OPCODE_BRA | (2 << 8)
  sta f:music_irq_doc_tick
:
  a8
  ldy #KEY_DRAIN_MAX
@drain:
  .a8
  lda f:KMSTATUS
  and #KM_DATA_FULL
  beq @modes
  lda f:DATAREG
  dey
  bne @drain
@modes:
  lda a:.loword(j13AdbPresent)
  beq @compat
  lda #GLU_SET_MODES
  jsr .loword(sendBounded)
  lda #GLU_NO_KEY_POLL          ; the mouse poll stays on
  jsr .loword(sendBounded)
  lda #GLU_SRQ_ON+ADB_KEYBOARD
  jsr .loword(sendBounded)
  bra @ready
@compat:
  lda #GLU_CLEAR_MODES          ; the firmware polls the keyboard (KBD)
  jsr .loword(sendBounded)
  lda #GLU_NO_KEY_POLL
  jsr .loword(sendBounded)
@ready:
  a16
  jsl J13Prime
  jsl J13Menu
  jsr .loword(defaults)
  a8
  lda #1
  sta a:.loword(ready)
  lda #KM_MOUSE_IRQ|KM_DATA_IRQ
  sta f:KMSTATUS
  a16
  lda #INPUT_RELEASED
  sta f:INPUT_P1                ; and INPUT_SYSTEM
  a8
  sta f:INPUT_P2
  pld
  plb
  plp
  rtl

; capture (native_input_capture): from the shared interrupt, with the CPU
; registers saved (music_irq keeps the DOC registers; this code does not
; touch the sound GLU). It works only when a J13 command runs, the ADB GLU
; has a byte or the keyboard waits for a talk. JSL; A8.
capture:
  lda f:ready
  beq @empty
  lda f:j13Owner
  bne @work
  lda f:KMSTATUS
  and #KM_MOUSE_FULL|KM_DATA_FULL
  bne @work
  lda f:keyPending
  bne @work
@empty:
  bra capture_done
@work:
  phb
  phd
  ax16
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
  a8
capture_done:
  rtl

; doc_tick (native_input_doc_tick): from the DOC timer interrupt: the J13
; send alarm and, in J13_PLAY, the controller clock and the row read. JSL;
; A8.
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
  ax16
  lda #0
  tcd
  phk
  plb
  lda a:.loword(j13SendTimer)
  beq :+
  jsr .loword(sendAlarm)
:
  lda a:.loword(j13Mode)
  cmp #J13_PLAY
  bne @done
  jsr .loword(readControllerClock)
  jsr .loword(j13Irq)
@done:
  pld
  plb
  a8
doc_tick_done:
  rtl

; idle (native_input_idle): the joystick axes in the idle time of an
; update. JSL.
idle:
  php
  phb
  phk
  plb
  a8
  jsr .loword(devices_idle)
  plb
  plp
  rtl

; sample (native_input_sample): once each update: set the J13 mode and let
; the J13 code read, apply the events up to now, read the devices without
; an interrupt, then write INPUT_P1, INPUT_P2 and INPUT_SYSTEM. A key
; pressed and released in one update shows once (keyLatch, systemLatch).
; JSL; returns A8 with B = 0.
sample:
  a16
  lda f:GAME_CLOCK
  php
  phb
  phd
  ax16
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
  ; A menu, a cabinet page and the demo: J13_MENU (all the J13 keys, so
  ; Esc always works). The play: J13_PLAY when the J13 keyboard is on,
  ; else J13_ESCAPE.
  lda a:.loword(menuMode)
  bne @menu
  lda f:GAME_FLOW
  and #255
  cmp #CAB_PAGE_FIRST
  bcs @menu
  lda f:CAB_DEMO
  and #255
  bne @menu
  lda a:.loword(j13Enabled)
  beq @raw
  lda #J13_PLAY
  bra @mode
@menu:
  lda #J13_MENU
  bra @mode
@raw:
  lda #J13_ESCAPE
@mode:
  cmp a:.loword(j13Mode)
  beq @same
  jsl setMode
@same:
  lda a:.loword(j13Mode)
  cmp #J13_PLAY
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
  eor #INPUT_RELEASED           ; 0 = pressed
  a8
  sta f:INPUT_P1
  xba
  sta f:INPUT_P2
  lda a:.loword(systemCommand)
  ora a:.loword(systemLatch)
  eor #<INPUT_RELEASED
  sta f:INPUT_SYSTEM
  a16
  stz a:.loword(keyLatch)
  stz a:.loword(systemLatch)
  lda #0                      ; native game expects B=0 for byte-to-index moves
  pld
  plb
  plp
  a8
  rtl

; consume_until (native_input_consume_until): a game tick between two
; samples: apply the events up to the time A, then the mouse stick. The
; devices are read only in sample; the coin and pause presses stay latched
; (systemLatch) for cabinet_frame. JSL with A16; returns A8 with B = 0.
.a16
consume_until:
  php
  phb
  phd
  ax16
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
  a8
  jsr .loword(mouse_directions)
  a16
  lda a:.loword(heldCommand)
  ora a:.loword(keyLatch)
  eor #INPUT_RELEASED
  a8
  sta f:INPUT_P1
  xba
  sta f:INPUT_P2
  a16
  stz a:.loword(keyLatch)
  lda #0
  pld
  plb
  plp
  a8
  rtl

; drain: apply the events of inputRing before inputLimit with a time of
; inputUntil or less. A key byte changes the held bit of its source
; (keyHeld) and the command bits of its bindings (apply_key_mask): a key
; stays held until all its sources release it. A mouse move moves the mouse
; stick, and its Y byte gives the mouse button. JSR; A16.
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
  sbc a:.loword(inputRing+INPUT_TIME),x
  bpl :+
  jmp .loword(@done)            ; a later event: the next tick applies it
:
  lda a:.loword(inputRing+INPUT_TYPE),x
  cmp #INPUT_MOUSE
  bne :+
  jmp .loword(@mouse)
:
  lsr
  inc                           ; INPUT_KEY: HELD_ADB; INPUT_J13: HELD_J13
  sta a:.loword(keySource)
  lda a:.loword(inputRing+INPUT_VALUE),x
  sta a:.loword(keyRaw)
  and #KEY_CODES-1
  tay
  a8
  lda a:.loword(keyRaw)
  bmi @release                  ; bit 7: a release
  lda a:.loword(keyHeld),y
  and a:.loword(keySource)
  bne @unchanged
  lda #1
  sta a:.loword(maskPressed)
  jsr .loword(drain_transition)
  bcc :+
  a16
  jmp .loword(@done)
:
  .a8
  lda a:.loword(keyHeld),y
  ora a:.loword(keySource)
  sta a:.loword(keyHeld),y
  a16
  lda a:.loword(keyRaw)         ; the last key for the menu
  sta a:.loword(keyAction)
  lda a:.loword(keySource)
  sta a:.loword(actionSource)
  inc a:.loword(inputSerial)
  a8
  bra @apply
@release:
  .a8
  lda a:.loword(keyHeld),y
  and a:.loword(keySource)
  beq @unchanged
  stz a:.loword(maskPressed)
  jsr .loword(drain_transition)
  bcc :+
  a16
  jmp .loword(@done)
:
  .a8
  lda a:.loword(keySource)
  eor #$ff
  and a:.loword(keyHeld),y
  sta a:.loword(keyHeld),y
@apply:
  .a8
  lda a:.loword(maskPressed)    ; X: the mask from drain_transition
  jsr .loword(apply_key_mask)
@unchanged:
  a16
  bra @next
@mouse:
  a8
  lda a:.loword(inputRing+INPUT_VALUE),x
  jsr .loword(mouse_signed)
  clc
  adc a:.loword(mouseX)
  jsr .loword(mouse_clamp)
  sta a:.loword(mouseX)
  lda a:.loword(inputRing+INPUT_AUX),x
  pha
  jsr .loword(mouse_signed)
  clc
  adc a:.loword(mouseY)
  jsr .loword(mouse_clamp)
  sta a:.loword(mouseY)
  pla
  eor #MOUSE_BUTTON_UP
  and #MOUSE_BUTTON_UP
  beq @mouse_up
  lda #1
@mouse_up:
  ldx #DEV_MOUSE+ACT_FIRE
  jsr .loword(set_device)
  a16
@next:
  lda a:.loword(inputTail)
  clc
  adc #INPUT_EVENT_SIZE
  and #INPUT_RING_SIZE-1
  sta a:.loword(inputTail)
  jmp .loword(@loop)
@done:
  rts

; drain_transition: X = the mask of the key (KEYBOARD2 + the code for a
; J13 key, times MASK_SIZE). Carry 1 when the edge must wait for the next
; tick: a press of a command that this drain released, or a release of one
; that it pressed. The drain stops there, so each tick sees each edge.
; Else the commands go into drainPress or drainRelease. JSR; A8.
.a8
drain_transition:
  a16
  lda a:.loword(keySource)
  dec
  xba
  lsr                           ; HELD_J13: KEYBOARD2
  sta a:.loword(maskIndex)
  lda a:.loword(keyRaw)
  and #KEY_CODES-1
  ora a:.loword(maskIndex)
  asl
  asl                           ; times MASK_SIZE
  tax
  a8
  lda a:.loword(maskPressed)
  beq @up
  a16
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
  a16
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
  a8
  clc
  rts
@blocked:
  a8
  sec
  rts
; mouse_signed: A = the 7-bit signed move of the ADB mouse byte A. JSR; A8.
.a8
mouse_signed:
  and #MOUSE_MOVE_BITS
  bit #MOUSE_MOVE_SIGN
  beq :+
  ora #<~MOUSE_MOVE_BITS
:
  rts
; mouse_clamp: A (signed) limited to -MOUSE_RANGE..MOUSE_RANGE. JSR; A8.
mouse_clamp:
  bpl @positive
  cmp #<-MOUSE_RANGE
  bcs @done
  lda #<-MOUSE_RANGE
  rts
@positive:
  cmp #MOUSE_RANGE+1
  bcc @done
  lda #MOUSE_RANGE
@done:
  rts
.assert HELD_J13 = 2 .and KEYBOARD2 = 128 .and MASK_SIZE = 4, error
.assert SET_BINDINGS+BINDINGS_BYTES = SET_DISPLAY_MARK, error
; center (native_input_center): the mouse stick goes back to the centre. JSL.
center:
  php
  a16
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
.include "menu_text.inc"
.a16
; The input state.
ready: .byte 0                  ; 1 after start: the interrupts may capture
inputHead: .word 0              ; inputRing: the offset of the next new event
inputTail: .word 0              ; inputRing: the offset of the next event to apply
inputLimit: .word 0             ; drain: the head when the drain starts
inputUntil: .word 0             ; drain: the last time to apply
inputSerial: .word 0            ; the count of presses (the menu sees a new key)
inputRing: .res INPUT_RING_SIZE
irqType: .word 0                ; the event that queueInput writes
irqValue: .word 0
irqAux: .word 0
keyTalk: .word 0                ; 1: a talk to the keyboard runs
keyPending: .word 0             ; 1: the keyboard asks for a talk
keyReply: .word 0               ; the key bytes of the talk still to come
keyHeaderByte: .word 0          ; the last ADB status byte
keyRaw: .word 0                 ; drain: the key byte
keySource: .word HELD_ADB       ; drain: the keyHeld bit of the key's source
keyAction: .word NONE           ; the last key or device action (the menu)
heldCommand: .word 0            ; the held command bits: P1 low, P2 high
systemCommand: .word 0          ; the held system bits
keyLatch: .word 0               ; the command bits pressed since the last write
systemLatch: .word 0            ; the system bits pressed since the last sample
drainPress: .res MASK_SIZE      ; drain: the commands that it pressed
drainRelease: .res MASK_SIZE    ; drain: the commands that it released
maskIndex: .word 0              ; drain_transition: KEYBOARD2 or 0
mouseTalkCount: .word 0         ; mouse moves since the last keyboard talk
mouseX: .word 0                 ; the mouse stick: -MOUSE_RANGE..MOUSE_RANGE
mouseY: .word 0
menuMode: .word 0               ; 1: the menu shows
keyHeld: .res KEY_CODES         ; each key: the HELD_* bits of its sources
actionSource: .word 0           ; the source of keyAction (the menu)
boundKeys: .res BIND_COUNT*2    ; the bindings, from compile_bindings
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
native_input_consume_until = input_native::consume_until

native_input_menu = input_native::menu_check

native_settings_fw_keep = input_native::settings_fw_keep
native_settings_fw_restore = input_native::settings_fw_restore
native_settings_zero = input_native::firmwareZero

native_input_dips = input_native::dip_apply
