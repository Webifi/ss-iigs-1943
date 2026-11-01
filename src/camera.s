; The camera: the sea (BG2) and the foreground (BG1) scroll counters and the
; stage pans (US arcade $1044-$113F). CAMERA holds the arcade block
; $E402-$E423, then CAMERA_STAGE, CAMERA_PAN_ON and CAMERA_EVENT_READY.
; A gate is a delay: 0 runs, n waits n updates, a high byte of $FF stops.
.a8
.i16
CAMERA_BG2_SCROLL = CAMERA+$00   ; 2 bytes: the along scroll of the sea (BG2)
CAMERA_BG2_DIVISOR = CAMERA+$02  ; a sea step every CAMERA_BG2_DIVISOR + 1 updates
CAMERA_BG2_COUNTER = CAMERA+$03  ; updates since the last sea step
CAMERA_BG2_GATE = CAMERA+$04     ; 2 bytes: the gate of the sea
CAMERA_CROSS = CAMERA+$0e        ; the cross scroll
CAMERA_BG1_SCROLL = CAMERA+$0f   ; 2 bytes: the along scroll of the foreground (BG1)
CAMERA_STAGE_OFFSET = CAMERA+$11 ; the byte offset in the stage table
CAMERA_BG1_DIVISOR = CAMERA+$13  ; a foreground step every CAMERA_BG1_DIVISOR + 1 updates
CAMERA_BG1_COUNTER = CAMERA+$14  ; updates since the last foreground step
CAMERA_BG1_GATE = CAMERA+$15     ; 2 bytes: the gate of the foreground
SCROLL_STOP = $ff                ; a gate, both bytes: the scroll stops
GATE_RUNS = $ff00                ; a gate that counts down to this runs
CAMERA_OBJECT_CROSS = CAMERA+$17 ; this update's move of the objects that follow the camera
CAMERA_OBJECT_ALONG = CAMERA+$18
CAMERA_PAN_TIME = CAMERA+$1c     ; updates left of this pan step
CAMERA_PAN_OFFSET = CAMERA+$1d   ; 2 bytes: the next step in camera_pan_pointers
CAMERA_PAN_DELTA = CAMERA+$1f    ; the cross move of this pan step
CAMERA_PAN_HOLD = CAMERA+$20     ; nonzero: the foreground holds during the pan
CAMERA_HOLD = CAMERA+$21         ; HOLD_BACK or HOLD_STILL: no events; 0: the camera runs
HOLD_BACK = 1                    ; CAMERA_HOLD: the foreground goes back
HOLD_STILL = 2                   ; CAMERA_HOLD: the foreground holds
CAMERA_STAGE = CAMERA+34         ; the stage, 0 to STAGES-1; STAGES starts the ending
STAGES = 16
LAST_STAGE = STAGES-1
AIR_STAGE_1 = 2                  ; CAMERA_STAGE of the air boss stages (3, 9, 14)
AIR_STAGE_2 = 8
AIR_STAGE_3 = 13
CAMERA_PAN_ON = CAMERA+35        ; nonzero: the stage pan runs (stage_control_pan)
CAMERA_EVENT_READY = CAMERA+36   ; nonzero: the stage events may run this update
DECK_SCROLL = $d500             ; CAMERA_BG1_SCROLL of the carrier deck scene
; CAMERA_BG2_SCROLL: bits 12-15 select the sea section, bits 0-11 the line in
; it; at SEA_WRAP the line starts again at 0.
SEA_SECTION = $f000
SEA_WRAP = $0f00

; camera_step: one camera update: the sea and the foreground count their
; gates and steps; a foreground step pans or moves along (CAMERA_HOLD). The
; objects that follow the camera move by CAMERA_OBJECT_CROSS/ALONG. Each
; update that is not held sets CAMERA_EVENT_READY. JSR.
camera_step:
  stz CAMERA_EVENT_READY
  lda CAMERA_BG2_GATE+1
  cmp #SCROLL_STOP
  beq @foreground
  a16
  lda CAMERA_BG2_GATE
  dec
  cmp #GATE_RUNS
  bcs @sea_rate
  sta CAMERA_BG2_GATE
  a8
  bra @foreground
@sea_rate:
.a16
  a8
  inc CAMERA_BG2_COUNTER
  lda CAMERA_BG2_DIVISOR
  cmp CAMERA_BG2_COUNTER
  bcs @foreground
  stz CAMERA_BG2_COUNTER
  ; The sea step: one line on, in the same section.
  a16
  lda CAMERA_BG2_SCROLL
  inc
  sta SEA_NEXT
  and #SEA_WRAP
  cmp #SEA_WRAP
  bne @sea_no_wrap
  lda SEA_NEXT
  and #SEA_SECTION
  bra @sea_store
@sea_no_wrap:
  lda SEA_NEXT
@sea_store:
  sta CAMERA_BG2_SCROLL
  a8
@foreground:
  stz CAMERA_OBJECT_CROSS
  stz CAMERA_OBJECT_ALONG
  lda CAMERA_BG1_GATE+1
  cmp #SCROLL_STOP
  bne @fg_delay
  rts
@fg_delay:
  a16
  lda CAMERA_BG1_GATE
  dec
  cmp #GATE_RUNS
  bcs @fg_rate
  sta CAMERA_BG1_GATE
  a8
  rts
@fg_rate:
.a16
  a8
  inc CAMERA_BG1_COUNTER
  lda CAMERA_BG1_DIVISOR
  cmp CAMERA_BG1_COUNTER
  bcc @fg_tick
  jmp camera_event
@fg_tick:
  stz CAMERA_BG1_COUNTER
  lda CAMERA_PAN_ON
  bne @pan
  jmp camera_vertical
@pan:
  ; The next pan step of the stage when this one ends.
  lda CAMERA_PAN_TIME
  bne @pan_tick
  a16
  lda CAMERA_STAGE
  and #255
  asl
  tax
  lda camera_pan_pointers,x
  clc
  adc CAMERA_PAN_OFFSET
  sta PAN_POINTER
  a8
  ldy #PAN_TIME
  lda (PAN_POINTER),y
  cmp #PAN_END
  beq @pan_end
  sta CAMERA_PAN_TIME
  iny
  lda (PAN_POINTER),y           ; PAN_DELTA
  sta CAMERA_PAN_DELTA
  iny
  lda (PAN_POINTER),y           ; PAN_HOLD
  sta CAMERA_PAN_HOLD
  a16
  lda CAMERA_PAN_OFFSET
  clc
  adc #PAN_STEP_SIZE
  sta CAMERA_PAN_OFFSET
  a8
@pan_tick:
  ; The camera moves across; the objects move the other way.
  lda CAMERA_PAN_DELTA
  eor #$ff
  inc
  sta CAMERA_OBJECT_CROSS
  lda CAMERA_CROSS
  clc
  adc CAMERA_PAN_DELTA
  sta CAMERA_CROSS
  dec CAMERA_PAN_TIME
  lda CAMERA_PAN_HOLD
  beq camera_vertical
  bra camera_event
@pan_end:
  ; The pan ends: the camera is back in the middle.
  stz CAMERA_PAN_ON
  stz CAMERA_PAN_TIME
  stz CAMERA_PAN_DELTA
  stz CAMERA_CROSS
  stz CAMERA_PAN_HOLD
  a16
  stz CAMERA_PAN_OFFSET
  a8

; camera_vertical: the foreground step along: forward, back (HOLD_BACK) or
; none (HOLD_STILL). The objects move one line the other way.
camera_vertical:
  lda CAMERA_HOLD
  beq @forward
  cmp #HOLD_STILL
  beq camera_event
  a16
  dec CAMERA_BG1_SCROLL
  a8
  lda #1
  sta CAMERA_OBJECT_ALONG
  bra camera_event
@forward:
  a16
  inc CAMERA_BG1_SCROLL
  a8
  lda #$ff                      ; -1
  sta CAMERA_OBJECT_ALONG
; camera_event: the stage events may run this update.
camera_event:
  lda #1
  sta CAMERA_EVENT_READY
  rts
.assert PAN_DELTA = 1 .and PAN_HOLD = 2 .and CAMERA_BG2_SCROLL = CAMERA, error
