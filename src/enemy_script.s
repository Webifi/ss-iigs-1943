; The motion script of a small enemy or a bullet (US arcade $5567-$55AE and
; $59CB-$59D8). The build copies the arcade motion data (enemy_script_pages);
; a code tail comes back as its arcade address for a native decision.
.a8
.i16
; ENEMY_SCRIPT_KIND values
SCRIPT_MOVE = 0              ; a motion step is in the record
SCRIPT_RETIRE = 1            ; the script ended; the object is retired
SCRIPT_TAIL = 2              ; a code tail: ENEMY_CALLBACK

; enemy_script: when the step time is over, read the next motion step of
; the record D (STEP_* fields) from OBJ_MOTION+STEP_SIZE, as
; large_object_script does. Returns ENEMY_SCRIPT_KIND (SCRIPT_TAIL with
; ENEMY_CALLBACK). The step data is in ENEMY_SCRIPT_FAST_BANK. JSR.
enemy_script:
  stz ENEMY_SCRIPT_KIND
  lda z:OBJ_DURATION
  beq @advance
  rts
@advance:
  a16
  lda z:OBJ_VARIANT
  and #OBJ_BANK_BITS
  asl
  asl                           ; bank*16*4 = bank*SCRIPT_BANK_ROWS
  sta a:SCRIPT_BANK_ROW
  lda z:OBJ_MOTION
  clc
  adc #STEP_SIZE
  sta a:SCRIPT_STEP
@record:
  ; X = the host address of the step SCRIPT_STEP (see large_object_record).
  lda a:SCRIPT_STEP
  xba
  and #255                      ; the arcade page of the step
  cmp #>ARCADE_BANK_WINDOW
  bcs @banked
  ora #SCRIPT_FIXED_ROW
  bra @page
@banked:
  and #SCRIPT_BANK_ROWS-1
  ora a:SCRIPT_BANK_ROW
@page:
  sta a:SCRIPT_ROW              ; the row; X = row * 3
  asl
  clc
  adc a:SCRIPT_ROW
  tax
  lda a:SCRIPT_STEP
  and #255
  clc
  adc f:enemy_script_pages,x
  sta a:SCRIPT_ADDRESS
  a8
  lda #ENEMY_SCRIPT_FAST_BANK
  ldx a:SCRIPT_ADDRESS
  phb
  pha
  plb
  lda a:STEP_DURATION,x
  beq @callback               ; STEP_TAIL
  cmp #STEP_JUMP
  beq @jump
  cmp #STEP_END
  beq @retire
  ; A motion step: the time, the code and the attributes (SPR_ALONG_HIGH
  ; stays), the two 8.8 moves.
  sta z:OBJ_DURATION
  a16
  lda f:SCRIPT_STEP
  sta z:OBJ_MOTION
  lda z:SPR_CODE                ; and SPR_ATTR
  and #SPR_ALONG_HIGH<<8
  sta f:SCRIPT_ATTR
  lda a:STEP_CODE,x             ; and STEP_ATTR
  ora f:SCRIPT_ATTR
  sta z:SPR_CODE
  lda a:STEP_CROSS_DELTA,x
  xba
  sta z:OBJ_CROSS_DELTA
  lda a:STEP_ALONG_DELTA,x
  xba
  sta z:OBJ_ALONG_DELTA
  plb
  a8
  rts
@jump:
  a16
  lda a:STEP_CODE,x            ; the jump target
  plb
  sta z:OBJ_MOTION
  sta a:SCRIPT_STEP
  jmp @record
@callback:
.a8
  a16
  lda a:STEP_CODE,x            ; the code tail
  plb
  sta ENEMY_CALLBACK
  a8
  lda #SCRIPT_TAIL
  sta ENEMY_SCRIPT_KIND
  rts
@retire:
.a8
  plb
  lda z:SPR_CROSS
  sta ENEMY_RETIRE_X
  stz z:SPR_CODE
  stz z:OBJ_TYPE
  stz z:SPR_CROSS
  lda #SCRIPT_RETIRE
  sta ENEMY_SCRIPT_KIND
  rts
.assert SPR_ATTR = SPR_CODE+1 .and STEP_ATTR = STEP_CODE+1, error
.assert OBJ_BANK_BITS = $70 .and SCRIPT_BANK_ROWS = 64, error
