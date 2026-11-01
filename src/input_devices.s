; The input devices: the mouse as a virtual stick (a position, not a
; speed), the game-port joystick (timed by the video counter, not by CPU
; loops), and the SNES MAX adapter (as Lukazi's SNES_MAX_ASS5; no slot
; probe). Each sets its device key states (set_device).
PAD_SLOT = 1    ; the gamepad adapter slot until input_settings patches the operands
PADDLE_LOW = 8               ; joy_read: the low and high thresholds, in
PADDLE_HIGH = 14             ; VERTCNT steps (two 63.6 us lines each)
PADDLE_ABSENT = 32           ; a stick still high after this is not there
PADDLE_LOW_LATE = 10         ; a read later than this is not used
PADDLE_HIGH_LATE = 16
JOY_READ_NOW = $ffff         ; joyUpdate: read the axes at the next sample
PAD_BITS = 16                ; bits of one SNES MAX read

.a16
.i16
; devices_sample: one input sample: the mouse, the joystick buttons (as the
; Apple keys of the J13 switches allow), the pad, the joystick axes once an
; update. JSR; A16.
devices_sample:
  a8
  jsr .loword(mouse_directions)
  ; ADB reports the keyboard's own Apple keys. J13 has only the shared
  ; switches: a bound J13 Apple key belongs to the keyboard; without a
  ; binding the switch is the joystick's. Both switches held together on
  ; that wire look the same.
  ldx #DEV_JOYSTICK+ACT_FIRE
  lda f:BUTN0
  bpl @button0_up
  lda a:.loword(keyHeld+KEY_COMMAND)
  and #1                      ; ADB has its own physical key identity
  bne @button0_up
  lda a:.loword(keyHeld+KEY_COMMAND)
  and #HELD_J13
  beq @button0_joy
  lda a:.loword(commandMasks+(KEYBOARD2+KEY_COMMAND)*MASK_SIZE)
  ora a:.loword(commandMasks+(KEYBOARD2+KEY_COMMAND)*MASK_SIZE+1)
  ora a:.loword(commandMasks+(KEYBOARD2+KEY_COMMAND)*MASK_SIZE+2)
  bne @button0_up
@button0_joy:
  lda #1
  bra @button0
@button0_up:
  lda #0
@button0:
  jsr .loword(set_device)
  inx
  lda f:BUTN1
  bpl @button1_up
  lda a:.loword(keyHeld+KEY_OPTION)
  and #1
  bne @button1_up
  lda a:.loword(keyHeld+KEY_OPTION)
  and #HELD_J13
  beq @button1_joy
  lda a:.loword(commandMasks+(KEYBOARD2+KEY_OPTION)*MASK_SIZE)
  ora a:.loword(commandMasks+(KEYBOARD2+KEY_OPTION)*MASK_SIZE+1)
  ora a:.loword(commandMasks+(KEYBOARD2+KEY_OPTION)*MASK_SIZE+2)
  bne @button1_up
@button1_joy:
  lda #1
  bra @button1
@button1_up:
  lda #0
@button1:
  jsr .loword(set_device)
  lda a:.loword(settings+SET_SNES_SLOT)
  beq @no_pad
  jsr .loword(pad_read)
@no_pad:
  ; The axes once an update: in the idle time when it comes, else here.
  lda a:.loword(joyAbsent)
  bne @done
  a16
  lda f:GAME_UPDATES
  cmp a:.loword(joyUpdate)
  beq @done16
  a8
  jsr .loword(joy_read)
@done:
  a16
@done16:
  rts

; mouse_directions: the mouse position (mouseX, mouseY) as the four stick
; directions of DEV_MOUSE. JSR; A8.
.a8
mouse_directions:
  lda a:.loword(mouseX)
  jsr .loword(stick_axis)
  ldx #DEV_MOUSE+ACT_RIGHT
  jsr .loword(set_device)
  xba
  inx
  jsr .loword(set_device)
  lda a:.loword(mouseY)
  jsr .loword(stick_axis)
  ldx #DEV_MOUSE+ACT_RIGHT+2     ; down, then up
  jsr .loword(set_device)
  xba
  inx
  jsr .loword(set_device)
  rts

; stick_axis: A = 1 when the signed position A is SET_DEAD_ZONE or more,
; B = 1 when it is -SET_DEAD_ZONE or less. JSR; A8.
.a8
stick_axis:
  pha
  lda #0
  xba
  pla
  bmi @negative
  cmp a:.loword(settings+SET_DEAD_ZONE)
  bcc @zero
  lda #1
  rts
@negative:
  eor #$ff
  inc
  cmp a:.loword(settings+SET_DEAD_ZONE)
  bcc @zero
  lda #1
  xba
@zero:
  lda #0
  rts

; devices_idle: the joystick axes in the idle time, once an update. The
; paddles are RC timers: only the two thresholds are read, whatever the CPU
; speed. JSR; A8.
.a8
devices_idle:
  lda a:.loword(joyAbsent)
  bne @done
  a16
  lda f:GAME_UPDATES
  cmp a:.loword(joyUpdate)
  a8
  beq @done
  jsr .loword(joy_read)
@done:
  rts
; joy_read: start the paddle timers; at PADDLE_LOW read both paddles, at
; PADDLE_HIGH both; a read too late (an interrupt in the wait) keeps the
; directions before. Both axes still high at PADDLE_HIGH: right and down
; from a stick that is known to be there, and the next read checks it
; first (joy_check); before that, joy_check waits for the stick now. Then
; the four directions of DEV_JOYSTICK. JSR.
joy_read:
  lda a:.loword(joyCheck)
  beq @start
  stz a:.loword(joyCheck)
  jsr .loword(joy_check)
  bcc @start
  jmp .loword(@stamp)           ; no stick
@start:
  lda f:VERTCNT
  sta a:.loword(joyBeam)
  lda f:PTRIG
  lda #PADDLE_LOW
  jsr .loword(joy_wait)
  php
  sei
  jsr .loword(joy_elapsed)
  cmp #PADDLE_LOW_LATE
  bcc :+
  plp
  jmp .loword(@stamp)
:
  lda f:PADDL0
  sta a:.loword(joyLowX)
  lda f:PADDL1
  sta a:.loword(joyLowY)
  plp
  lda #PADDLE_HIGH
  jsr .loword(joy_wait)
  php
  sei
  jsr .loword(joy_elapsed)
  cmp #PADDLE_HIGH_LATE
  bcc :+
  plp
  jmp .loword(@stamp)
:
  lda f:PADDL0
  sta a:.loword(joyHighX)
  lda f:PADDL1
  sta a:.loword(joyHighY)
  plp
  lda a:.loword(joyHighX)
  and a:.loword(joyHighY)
  bpl @connected
  ; Both axes high past the high threshold: right and down, or no stick.
  lda a:.loword(joyPresent)
  beq :+
  inc a:.loword(joyCheck)
  bra @connected
:
  jsr .loword(joy_check)
  bcs @stamp
@connected:
  ; Right/down: still high at PADDLE_HIGH; left/up: low at PADDLE_LOW.
  ldx #DEV_JOYSTICK
  ldy #0
@axis:
  lda a:.loword(joyHighX),y
  asl
  lda #0
  rol
  jsr .loword(set_device)
  inx
  lda a:.loword(joyLowX),y
  eor #$80
  asl
  lda #0
  rol
  jsr .loword(set_device)
  inx
  iny
  cpy #2
  bcc @axis
@stamp:
  a16
  lda f:GAME_UPDATES
  sta a:.loword(joyUpdate)
  a8
  rts
; joy_check: both axes were high at PADDLE_HIGH of the read that started at
; joyBeam. A stick ends its timers by PADDLE_ABSENT; a missing stick never
; does. Timers that ended already need no wait. Carry clear: the stick is
; there (joyPresent). Carry set: no stick; input_poll stops and the keys of
; DEV_JOYSTICK are released. JSR.
joy_check:
  lda f:PADDL0
  and f:PADDL1
  bpl @there
  lda #PADDLE_ABSENT
  jsr .loword(joy_wait)
  lda f:PADDL0
  and f:PADDL1
  bmi @absent
@there:
  lda #1
  sta a:.loword(joyPresent)
  clc
  rts
@absent:
  lda #1
  sta a:.loword(joyAbsent)
  lda #OPCODE_RTS               ; no stick: no more timer work (the ADB and J13
  sta f:input_poll              ; capture is in the interrupt)
  ldx #DEV_JOYSTICK
  lda #0
@release:
  jsr .loword(set_device)
  inx
  cpx #DEV_JOYSTICK+ACT_FIRE
  bcc @release
  sec
  rts
; joy_wait: wait until A VERTCNT steps since joyBeam. JSR.
joy_wait:
  sta a:.loword(joyThreshold)
@wait:
  jsr .loword(joy_elapsed)
  cmp a:.loword(joyThreshold)
  bcc @wait
  rts
; joy_elapsed: A = the VERTCNT steps since joyBeam (with the wrap at
; beamPeriod). The interrupts stay on in the wait; only the step check and
; the paddle reads are made with them off. JSR.
joy_elapsed:
  lda f:VERTCNT
  sec
  sbc a:.loword(joyBeam)
  bcs :+
  clc
  adc a:.loword(beamPeriod)
:
  rts

; pad_read: read the SNES MAX adapter in the slot of the settings (the card
; has no ROM to find): $C0n0 latches and reads, $C0n1 clocks both pads.
; PAD_BITS bits each (the first 8 also NES); bits 0-7 to DEV_PAD1/DEV_PAD2
; actions 0-7, bits 8-11 to actions 8-11. JSR.
pad_read:
  stz a:.loword(padBits)
  stz a:.loword(padBits+1)
  stz a:.loword(padBits+2)
  stz a:.loword(padBits+3)
  lda #0
pad_latch:
  sta f:SLOT_DEVICE+PAD_SLOT*16 ; patched from the explicit slot setting
  ldx #0
pad_bit:
  cpx #8                        ; bits 8-15 go to padBits+2
  bcc @first
  ldy #2
  bra @read
@first:
  ldy #0
@read:
pad_data:
  lda f:SLOT_DEVICE+PAD_SLOT*16
  sta a:.loword(padSerial)
  asl
  lda a:.loword(padBits),y
  rol
  sta a:.loword(padBits),y
  lda a:.loword(padSerial)
  asl
  asl
  lda a:.loword(padBits+1),y
  rol
  sta a:.loword(padBits+1),y
pad_clock:
  sta f:SLOT_DEVICE+PAD_SLOT*16+1
  inx
  cpx #PAD_BITS
  bcc pad_bit
  ldx #0
@pad:
  lda a:.loword(padBits),x
  eor #$ff                      ; pressed = 1
  sta a:.loword(padPressed)
  txa
  beq :+
  lda #DEV_PAD2-DEV_PAD1
:
  clc
  adc #DEV_PAD1
  tay
  lda #1
  sta a:.loword(padMask)
@button:
  lda a:.loword(padPressed)
  and a:.loword(padMask)
  beq :+
  lda #1
:
  phx
  tyx
  jsr .loword(set_device)
  plx
  iny
  asl a:.loword(padMask)
  bne @button
  inx
  cpx #2
  bcc @pad
  ldx #0
@extra:
  lda a:.loword(padBits+2),x
  eor #$ff
  sta a:.loword(padPressed)
  txa
  beq :+
  lda #DEV_PAD2-DEV_PAD1
:
  clc
  adc #DEV_PAD1+8
  tay
  lda #$80
  sta a:.loword(padMask)
@extra_bit:
  lda a:.loword(padPressed)
  and a:.loword(padMask)
  beq :+
  lda #1
:
  phx
  tyx
  jsr .loword(set_device)
  plx
  iny
  lsr a:.loword(padMask)
  lda a:.loword(padMask)
  cmp #8
  bne @extra_bit
  inx
  cpx #2
  bcc @extra
  rts

; The device state.
joyUpdate: .word JOY_READ_NOW
joyAbsent: .byte 0
joyPresent: .byte 0             ; joy_check saw the timers of the stick end
joyCheck: .byte 0               ; joy_read: both axes were high; check the stick first
joyBeam: .byte 0
joyThreshold: .byte 0
joyLowX: .byte 0                ; PADDL0 at PADDLE_LOW (joy_read indexes X, then Y)
joyLowY: .byte 0                ; PADDL1 at PADDLE_LOW
joyHighX: .byte 0               ; PADDL0 at PADDLE_HIGH
joyHighY: .byte 0               ; PADDL1 at PADDLE_HIGH
beamPeriod: .byte 131           ; VERTCNT steps of a picture (PAL: PAL_BEAM_PERIOD)
padSerial: .byte 0
padBits: .res 4
padPressed: .byte 0
padMask: .byte 0
deviceKeys: .res 128
