; Mouse coordinates are a persistent virtual stick, not velocity controls.
; SNES MAX protocol follows Lukazi's SNES_MAX_ASS5 source. No slot probing.
; Paddle timing uses the real IIgs video counter rather than CPU loop counts.
.a16
.i16
devices_sample:
  sep #$20
  jsr .loword(mouse_directions)
  ; ADB reports the keyboard's own Apple keys. J13 has only the shared
  ; switches: a bound J13 Apple signal belongs to the keyboard; unbinding
  ; it frees the signal for the joystick. No software can distinguish both
  ; physical switches being held together on that shared wire.
  ldx #52
  lda f:BUTN0
  bpl @button0_up
  lda a:.loword(keyHeld+$37)
  and #1                      ; ADB has its own physical key identity
  bne @button0_up
  lda a:.loword(keyHeld+$37)
  and #2
  beq @button0_joy
  lda a:.loword(commandMasks+(128+$37)*4)
  ora a:.loword(commandMasks+(128+$37)*4+1)
  ora a:.loword(commandMasks+(128+$37)*4+2)
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
  lda a:.loword(keyHeld+$3a)
  and #1
  bne @button1_up
  lda a:.loword(keyHeld+$3a)
  and #2
  beq @button1_joy
  lda a:.loword(commandMasks+(128+$3a)*4)
  ora a:.loword(commandMasks+(128+$3a)*4+1)
  ora a:.loword(commandMasks+(128+$3a)*4+2)
  bne @button1_up
@button1_joy:
  lda #1
  bra @button1
@button1_up:
  lda #0
@button1:
  jsr .loword(set_device)
  lda a:.loword(settings+9)
  beq @no_pad
  jsr .loword(pad_read)
@no_pad:
  ; Prefer the update's idle interval. If there was none, the bounded
  ; threshold read is still required to avoid stale joystick directions.
  lda a:.loword(joyAbsent)
  bne @done
  rep #$20
  lda f:$000068
  cmp a:.loword(joyUpdate)
  beq @done16
  sep #$20
  jsr .loword(joy_read)
@done:
  rep #$20
@done16:
  rts

.a8
mouse_directions:
  lda a:.loword(mouseX)
  jsr .loword(stick_axis)
  ldx #32
  jsr .loword(set_device)
  xba
  inx
  jsr .loword(set_device)
  lda a:.loword(mouseY)
  jsr .loword(stick_axis)
  ldx #34
  jsr .loword(set_device)
  xba
  inx
  jsr .loword(set_device)
  rts

.a8
stick_axis:
  pha
  lda #0
  xba
  pla
  bmi @negative
  cmp a:.loword(settings+10)
  bcc @zero
  lda #1
  rts
@negative:
  eor #255
  inc
  cmp a:.loword(settings+10)
  bcc @zero
  lda #1
  xba
@zero:
  lda #0
  rts

; Paddles are RC timers on real hardware. Poll only the two direction
; thresholds, independent of accelerator speed. The counter advances every
; two 63.6-us lines. A disconnected axis remains high after 32 steps.
.a8
devices_idle:
  lda a:.loword(joyAbsent)
  bne @done
  rep #$20
  lda f:$000068
  cmp a:.loword(joyUpdate)
  sep #$20
  beq @done
  jsr .loword(joy_read)
@done:
  rts
joy_read:
  lda f:$e0c02e
  sta a:.loword(joyBeam)
  lda f:$e0c070
  lda #8
  jsr .loword(joy_wait)
  php
  sei
  jsr .loword(joy_elapsed)
  cmp #10
  bcc :+
  plp
  jmp .loword(@stamp)
:
  lda f:$e0c064
  sta a:.loword(joyLowX)
  lda f:$e0c065
  sta a:.loword(joyLowY)
  plp
  lda #14
  jsr .loword(joy_wait)
  php
  sei
  jsr .loword(joy_elapsed)
  cmp #16
  bcc :+
  plp
  jmp .loword(@stamp)
:
  lda f:$e0c064
  sta a:.loword(joyHighX)
  lda f:$e0c065
  sta a:.loword(joyHighY)
  plp
  lda a:.loword(joyHighX)
  and a:.loword(joyHighY)
  bpl @connected
  ; Check absence only when both axes exceed the high threshold.
  lda #32
  jsr .loword(joy_wait)
  lda f:$e0c064
  and f:$e0c065
  bpl @connected
  lda #1
  sta a:.loword(joyAbsent)
  lda #$60                    ; no timer work on an absent game-port stick
  sta f:input_poll            ; raw ADB/J13 capture belongs to IRQ, not idle
@connected:
  ldx #48
  ldy #0
@axis:
  lda a:.loword(joyHighX),y
  asl
  lda #0
  rol
  jsr .loword(set_device)
  inx
  lda a:.loword(joyLowX),y
  eor #128
  asl
  lda #0
  rol
  jsr .loword(set_device)
  inx
  iny
  cpy #2
  bcc @axis
  lda a:.loword(joyAbsent)
  beq @stamp
  ldx #48
  lda #0
@clear_absent:
  jsr .loword(set_device)
  inx
  cpx #52
  bcc @clear_absent
@stamp:
  rep #$20
  lda f:$000068
  sta a:.loword(joyUpdate)
  sep #$20
  rts
joy_wait:
  sta a:.loword(joyThreshold)
@wait:
  jsr .loword(joy_elapsed)
  cmp a:.loword(joyThreshold)
  bcc @wait
  rts
; IRQs remain enabled during the RC wait. A sound service may pass the
; sampling deadline: keep the previous direction in that case. Only the
; counter check and two paddle reads are atomic, never the millisecond wait.
joy_elapsed:
  lda f:$e0c02e
  sec
  sbc a:.loword(joyBeam)
  bcs :+
  clc
  adc a:.loword(beamPeriod)
:
  rts

; User-selected slot only: card has no identifying ROM/signature. Bytes
; $C0n0 latch/read; $C0n1 clocks both controllers. First eight bits also NES.
pad_read:
  stz a:.loword(padBits)
  stz a:.loword(padBits+1)
  stz a:.loword(padBits+2)
  stz a:.loword(padBits+3)
  lda #0
pad_latch:
  sta f:$e0c090               ; patched from the explicit slot setting
  ldx #0
pad_bit:
  cpx #8
  bcc @first
  ldy #2
  bra @read
@first:
  ldy #0
@read:
pad_data:
  lda f:$e0c090
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
  sta f:$e0c091
  inx
  cpx #16
  bcc pad_bit
  ldx #0
@pad:
  lda a:.loword(padBits),x
  eor #255
  sta a:.loword(padPressed)
  txa
  beq :+
  lda #16
:
  clc
  adc #64
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
  eor #255
  sta a:.loword(padPressed)
  txa
  beq :+
  lda #16
:
  clc
  adc #72
  tay
  lda #128
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

joyUpdate: .word $ffff
joyAbsent: .byte 0
joyBeam: .byte 0
joyThreshold: .byte 0
joyLowX: .byte 0
joyLowY: .byte 0
joyHighX: .byte 0
joyHighY: .byte 0
beamPeriod: .byte 131
padSerial: .byte 0
padBits: .res 4
padPressed: .byte 0
padMask: .byte 0
deviceKeys: .res 128
