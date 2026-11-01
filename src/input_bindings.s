; The key bindings: each physical key gets its action mask (the player
; bits, the system bits) once, at a load or an edit; at run time a key only
; changes the counts of its actions, so two keys of one action and two
; owners of one key work together.
.a16
.i16
; The physical keys: KEY_CODES of keyboard 1, then of keyboard 2, then the
; device keys from DEVICE_KEYS. Each has a MASK_SIZE entry in commandMasks.
KEY_CODES = 128
KEYBOARD2 = 128
DEVICE_KEYS = 256
PHYSICAL_KEYS = 384
MASK_SIZE = 4                ; the player bits word, the system bits word
ACTION_BYTES = 3             ; the action bits: 24, counted in actionRefs
DEVICE_STATE_FIRST = 32      ; deviceKeys: the device key states,
DEVICE_STATE_END = 96        ; 16 actions for each source from 2

; compile_masks: commandMasks from the bindings; ESC opens the menu on both
; keyboards; the keys held now count again. Not in the game tick. JSR.
compile_masks:
  ldx #PHYSICAL_KEYS*MASK_SIZE-2
@clear:
  stz a:.loword(commandMasks),x
  dex
  dex
  bpl @clear
  ldx #ACTION_BYTES*8-2
@refs:
  stz a:.loword(actionRefs),x
  dex
  dex
  bpl @refs
  stz a:.loword(heldCommand)
  stz a:.loword(systemCommand)
  stz a:.loword(keyLatch)
  stz a:.loword(systemLatch)
  ldx #0
@binding:
  lda a:.loword(boundKeys),x
  cmp #KEY_CODES
  bcs @next                     ; unused
  lda a:.loword(boundSources),x
  cmp #SOURCE_DEVICE_FIRST
  bcc @keyboard
  lda a:.loword(boundKeys),x
  ora #DEVICE_KEYS
  jsr .loword(mask_store)
  bra @next
@keyboard:
  bit #SOURCE_ADB
  beq :+
  lda a:.loword(boundKeys),x
  jsr .loword(mask_store)
:
  lda a:.loword(boundSources),x
  bit #SOURCE_J13
  beq @next
  lda a:.loword(boundKeys),x
  ora #KEYBOARD2
  jsr .loword(mask_store)
@next:
  inx
  inx
  cpx #BIND_COUNT*2
  bcc @binding
  ; ESC opens the menu on both keyboards, whatever the bindings say; the
  ; whole mask is replaced, so an old ESC binding does nothing.
  stz a:.loword(commandMasks+KEY_ESC*MASK_SIZE)
  stz a:.loword(commandMasks+(KEYBOARD2+KEY_ESC)*MASK_SIZE)
  lda #SYSTEM_MENU
  sta a:.loword(commandMasks+KEY_ESC*MASK_SIZE+2)
  sta a:.loword(commandMasks+(KEYBOARD2+KEY_ESC)*MASK_SIZE+2)
  ; The keys held now count with their new masks.
  ldx #0
@keys:
  lda a:.loword(keyHeld),x
  and #1
  beq :+
  phx
  txa
  asl
  asl                           ; times MASK_SIZE
  tax
  a8
  lda #1
  jsr .loword(apply_key_mask)
  a16
  plx
:
  lda a:.loword(keyHeld),x
  and #2
  beq @advance
  phx
  txa
  ora #KEYBOARD2
  asl
  asl
  tax
  a8
  lda #1
  jsr .loword(apply_key_mask)
  a16
  plx
@advance:
  inx
  cpx #KEY_CODES
  bcc @keys
  ldx #DEVICE_STATE_FIRST
@device:
  lda a:.loword(deviceKeys),x
  and #255
  beq @device_next
  phx
  txa
  ora #DEVICE_KEYS
  asl
  asl
  tax
  a8
  lda #1
  jsr .loword(apply_key_mask)
  a16
  plx
@device_next:
  inx
  cpx #DEVICE_STATE_END
  bcc @device
  rts
; mask_store: the bits of the binding X join the mask of the physical key A.
mask_store:
  asl
  asl                           ; times MASK_SIZE
  tay
  lda a:.loword(boundBits),x
  ora a:.loword(commandMasks),y
  sta a:.loword(commandMasks),y
  lda a:.loword(boundSystem),x
  ora a:.loword(commandMasks+2),y
  sta a:.loword(commandMasks+2),y
  rts

; apply_key_mask: the physical key X / MASK_SIZE is pressed (A8 = 1) or let
; go (0): each of its action bits counts up or down in actionRefs; the
; first press sets the bit in heldCommand and keyLatch, the last release
; clears heldCommand. Only the main loop changes the counts. JSR.
.a8
apply_key_mask:
  sta a:.loword(maskPressed)
  a16
  lda a:.loword(commandMasks),x
  sta a:.loword(maskWork)
  lda a:.loword(commandMasks+2),x
  sta a:.loword(maskWork+2)
  ora a:.loword(maskWork)
  beq @empty
  a8
  ldx #0
  ldy #0
@byte:
  lda #1
  sta a:.loword(maskBit)
@bit:
  lda a:.loword(maskWork),y
  and a:.loword(maskBit)
  beq @advance
  lda a:.loword(maskPressed)
  beq @up
  inc a:.loword(actionRefs),x
  lda a:.loword(actionRefs),x
  cmp #1
  bne @advance
  lda a:.loword(heldCommand),y
  ora a:.loword(maskBit)
  sta a:.loword(heldCommand),y
  lda a:.loword(keyLatch),y
  ora a:.loword(maskBit)
  sta a:.loword(keyLatch),y
  bra @advance
@up:
  lda a:.loword(actionRefs),x
  beq @advance
  dec a:.loword(actionRefs),x
  bne @advance
  lda a:.loword(maskBit)
  eor #$ff
  and a:.loword(heldCommand),y
  sta a:.loword(heldCommand),y
@advance:
  inx
  asl a:.loword(maskBit)
  bne @bit
  iny
  cpy #ACTION_BYTES
  bcc @byte
  rts
@empty:
  a8
  rts

; set_device: the device key state X (16 actions for each source from 2) is
; A8 = 1 (pressed) or 0; a change applies its mask; a press is also the
; last key for the menu (keyAction, actionSource, inputSerial). JSR; A, X, Y
; (with B) kept.
set_device:
  php
  ax16
  pha
  phx
  phy
  a8
  cmp a:.loword(deviceKeys),x
  beq @same
  sta a:.loword(deviceKeys),x
  sta a:.loword(devicePressed)
  beq @apply
  a16
  txa
  and #15                       ; the action
  sta a:.loword(keyAction)
  txa
  lsr
  lsr
  lsr
  lsr
  clc
  adc #SOURCE_MOUSE-DEV_MOUSE/16 ; the source
  sta a:.loword(actionSource)
  inc a:.loword(inputSerial)
  a8
@apply:
  a16
  txa
  ora #DEVICE_KEYS
  asl
  asl
  tax
  a8
  lda a:.loword(devicePressed)
  jsr .loword(apply_key_mask)
@same:
  ax16
  ply
  plx
  pla
  plp
  rts
maskWork: .res 4
maskBit: .byte 0
maskPressed: .byte 0
devicePressed: .byte 0
actionRefs: .res ACTION_BYTES*8 ; the keys that hold each action bit
commandMasks: .res PHYSICAL_KEYS*MASK_SIZE
.assert PHYSICAL_KEYS = DEVICE_KEYS+KEY_CODES .and MASK_SIZE = 4, error
