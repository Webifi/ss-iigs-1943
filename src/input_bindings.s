; Configuration compiles physical-key action masks once. Runtime updates only
; the changed key's reference counts; aliases and two source owners coexist.
.a16
.i16
compile_masks:
  ldx #1534
@clear:
  stz a:.loword(commandMasks),x
  dex
  dex
  bpl @clear
  ldx #22
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
  cmp #128
  bcs @next
  lda a:.loword(boundSources),x
  cmp #4
  bcc @keyboard
  lda a:.loword(boundKeys),x
  ora #256
  jsr .loword(mask_store)
  bra @next
@keyboard:
  bit #1
  beq :+
  lda a:.loword(boundKeys),x
  jsr .loword(mask_store)
:
  lda a:.loword(boundSources),x
  bit #2
  beq @next
  lda a:.loword(boundKeys),x
  ora #128
  jsr .loword(mask_store)
@next:
  inx
  inx
  cpx #128
  bcc @binding
  ; ESC belongs to the menu on both keyboards, regardless of saved bindings.
  ; Replace the whole command mask so an old ESC binding cannot also fire.
  stz a:.loword(commandMasks+$35*4)
  stz a:.loword(commandMasks+($80+$35)*4)
  lda #16
  sta a:.loword(commandMasks+$35*4+2)
  sta a:.loword(commandMasks+($80+$35)*4+2)
  ; Reapply already-held physical identities after remapping. This runs in
  ; configuration, never in the ordinary game tick.
  ldx #0
@keys:
  lda a:.loword(keyHeld),x
  and #1
  beq :+
  phx
  txa
  asl
  asl
  tax
  sep #$20
  lda #1
  jsr .loword(apply_key_mask)
  rep #$20
  plx
:
  lda a:.loword(keyHeld),x
  and #2
  beq @advance
  phx
  txa
  ora #128
  asl
  asl
  tax
  sep #$20
  lda #1
  jsr .loword(apply_key_mask)
  rep #$20
  plx
@advance:
  inx
  cpx #128
  bcc @keys
  ldx #32
@device:
  lda a:.loword(deviceKeys),x
  and #255
  beq @device_next
  phx
  txa
  ora #256
  asl
  asl
  tax
  sep #$20
  lda #1
  jsr .loword(apply_key_mask)
  rep #$20
  plx
@device_next:
  inx
  cpx #96
  bcc @device
  rts
mask_store:
  asl
  asl
  tay
  lda a:.loword(boundBits),x
  ora a:.loword(commandMasks),y
  sta a:.loword(commandMasks),y
  lda a:.loword(boundSystem),x
  ora a:.loword(commandMasks+2),y
  sta a:.loword(commandMasks+2),y
  rts

; A8=pressed, X=physical key*4. Only this foreground consumer mutates refs.
.a8
apply_key_mask:
  sta a:.loword(maskPressed)
  rep #$20
  lda a:.loword(commandMasks),x
  sta a:.loword(maskWork)
  lda a:.loword(commandMasks+2),x
  sta a:.loword(maskWork+2)
  ora a:.loword(maskWork)
  beq @empty
  sep #$20
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
  eor #255
  and a:.loword(heldCommand),y
  sta a:.loword(heldCommand),y
@advance:
  inx
  asl a:.loword(maskBit)
  bne @bit
  iny
  cpy #3
  bcc @byte
  rts
@empty:
  sep #$20
  rts

; A8=0/1, X=device state index. Preserve caller's A/X/Y, including B.
set_device:
  php
  rep #$30
  pha
  phx
  phy
  sep #$20
  cmp a:.loword(deviceKeys),x
  beq @same
  sta a:.loword(deviceKeys),x
  sta a:.loword(devicePressed)
  beq @apply
  rep #$20
  txa
  and #15
  sta a:.loword(keyAction)
  txa
  lsr
  lsr
  lsr
  lsr
  clc
  adc #2
  sta a:.loword(actionSource)
  inc a:.loword(inputSerial)
  sep #$20
@apply:
  rep #$20
  txa
  ora #256
  asl
  asl
  tax
  sep #$20
  lda a:.loword(devicePressed)
  jsr .loword(apply_key_mask)
@same:
  rep #$30
  ply
  plx
  pla
  plp
  rts
maskWork: .res 4
maskBit: .byte 0
maskPressed: .byte 0
devicePressed: .byte 0
actionRefs: .res 24
commandMasks: .res 1536
