; Native original-US sea/foreground counters and pan script, $1044-$113F.
; CAMERA contains original $E402-$E423, then stage, pan-enable, event-ready, pad.
.a8
.i16
.ifndef CAMERA
CAMERA = $1140
.endif
CAMERA_STAGE = CAMERA+34
CAMERA_PAN_ON = CAMERA+35
CAMERA_EVENT_READY = CAMERA+36

camera_step:
  stz CAMERA_EVENT_READY
  stz CAMERA+6
  lda CAMERA+5
  cmp #255
  beq @foreground
  rep #$20
  lda CAMERA+4
  dec
  cmp #$ff00
  bcs @sea_rate
  sta CAMERA+4
  sep #$20
  bra @foreground
@sea_rate:
.a16
  sep #$20
  inc CAMERA+3
  lda CAMERA+2
  cmp CAMERA+3
  bcs @foreground
  stz CAMERA+3
  rep #$20
  lda CAMERA
  inc
  sta $d0
  and #$0f00
  cmp #$0f00
  bne @sea_no_wrap
  lda $d0
  and #$f000
  bra @sea_store
@sea_no_wrap:
  lda $d0
@sea_store:
  sta CAMERA
  sep #$20
  lda #255
  sta CAMERA+6
@foreground:
  stz CAMERA+$17
  stz CAMERA+$18
  lda CAMERA+$16
  cmp #255
  bne @fg_delay
  rts
@fg_delay:
  rep #$20
  lda CAMERA+$15
  dec
  cmp #$ff00
  bcs @fg_rate
  sta CAMERA+$15
  sep #$20
  rts
@fg_rate:
.a16
  sep #$20
  inc CAMERA+$14
  lda CAMERA+$13
  cmp CAMERA+$14
  bcc @fg_tick
  jmp camera_event
@fg_tick:
  stz CAMERA+$14
  lda CAMERA_PAN_ON
  bne @pan
  jmp camera_vertical
@pan:
  lda CAMERA+$1c
  bne @pan_tick
  rep #$20
  lda CAMERA_STAGE
  and #255
  asl
  tax
  lda camera_pan_pointers,x
  clc
  adc CAMERA+$1d
  sta $d4
  sep #$20
  ldy #0
  lda ($d4),y
  cmp #255
  beq @pan_end
  sta CAMERA+$1c
  iny
  lda ($d4),y
  sta CAMERA+$1f
  iny
  lda ($d4),y
  sta CAMERA+$20
  rep #$20
  lda CAMERA+$1d
  clc
  adc #3
  sta CAMERA+$1d
  sep #$20
@pan_tick:
  lda CAMERA+$1f
  eor #255
  inc
  sta CAMERA+$17
  lda CAMERA+$0e
  clc
  adc CAMERA+$1f
  sta CAMERA+$0e
  dec CAMERA+$1c
  lda CAMERA+$20
  beq camera_vertical
  bra camera_event
@pan_end:
  stz CAMERA_PAN_ON
  stz CAMERA+$1c
  stz CAMERA+$1f
  stz CAMERA+$0e
  stz CAMERA+$20
  rep #$20
  stz CAMERA+$1d
  sep #$20

camera_vertical:
  lda CAMERA+$21
  beq @forward
  cmp #2
  beq camera_event
  rep #$20
  dec CAMERA+$0f
  sep #$20
  lda #1
  sta CAMERA+$18
  bra camera_event
@forward:
  rep #$20
  inc CAMERA+$0f
  sep #$20
  lda #255
  sta CAMERA+$18
camera_event:
  lda #1
  sta CAMERA_EVENT_READY
  rts
