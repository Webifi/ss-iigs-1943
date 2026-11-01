; One tick of a giant object (OT_GIANT): sixteen sprite records in a grid of
; GIANT_ROWS by GIANT_COLUMNS in four large slots (GIANT_SIZE). A native port
; of the US arcade code at $6207-$6426; the code works on the records in place.
; The head is the record at GIANT_HEAD (row 0, column GIANT_HEAD_COLUMN).
; Rows 1 to 3 are each PIECE_RISE further along; the columns are PIECE_RIGHT
; apart, columns 0 and 1 to the left of the head. The caller is
; large_loop_tick; it reads LARGE_KIND as for a large object.
.a8
.i16
GIANT_ROWS = 4
GIANT_COLUMNS = 4
GIANT_HEAD_COLUMN = 2
GIANT_CODE_ROW = 8           ; the sprite code of the piece above is the code + 8
GIANT_ALONG_OUT_MIN = $31    ; past the field (SPR_ALONG_HIGH) and inside
GIANT_ALONG_OUT_MAX = $ef    ; GIANT_ALONG_OUT_MIN..MAX-1: the giant retires
; giant_piece: the instruction op on a field of the piece at row, col, with
; X = GIANT_BASE. Large slot (row/2)*2 + col/2 holds the piece, as record
; (row mod 2)*2 + col mod 2 of that slot (the large object order). The 0+
; stops ca65 from reading a first parenthesis as an indirect address.
.macro giant_piece op, row, col, field
  op a:0+((row)/2)*2*LARGE_SIZE+((row) .mod 2)*2*SPRITE_SIZE+((col)/2)*LARGE_SIZE+((col) .mod 2)*SPRITE_SIZE+(field),x
.endmacro
.assert GIANT_ROWS*GIANT_COLUMNS*SPRITE_SIZE = GIANT_SIZE, error
.assert GIANT_HEAD = (GIANT_HEAD_COLUMN/2)*LARGE_SIZE, error ; row 0

; giant_object_tick: one tick of the giant whose head is at LARGE_RECORD.
; Returns LARGE_KIND (0 moved, LK_RETIRED or LK_CALLBACK with
; LARGE_CALLBACK). JSL; D is kept.
giant_object_tick:
  phd
  a16
  lda #ZERO_PAGE
  tcd
  lda LARGE_RECORD
  sec
  sbc #GIANT_HEAD
  sta GIANT_BASE
  tax
  stz LARGE_CALLBACK
  a8
  stz LARGE_KIND
  jsr .loword(giant_object_script)
  lda LARGE_KIND
  bne @done
  jsr .loword(giant_object_motion)
@done:
  pld
  rtl

; giant_object_script: when the step time is over, read the next motion step
; from OBJ_MOTION+STEP_SIZE, as large_object_script does, and give it to all
; sixteen pieces. In: X = GIANT_BASE. A step holds the code of the bottom left
; piece; each column is one code more, each row GIANT_CODE_ROW more. The
; moves keep the order of large_object_motion: integer byte first.
giant_object_script:
.a8
  lda a:GIANT_HEAD+OBJ_DURATION,x
  beq @advance
  rts
@advance:
  a16
  lda a:GIANT_HEAD+OBJ_VARIANT,x
  and #OBJ_BANK_BITS
  asl
  asl                           ; bank*16*4 = bank*SCRIPT_BANK_ROWS
  sta LARGE_BANK
  lda a:GIANT_HEAD+OBJ_MOTION,x
  clc
  adc #STEP_SIZE
  sta LARGE_SOURCE
@record:
  ; Point large_object_read at the step LARGE_SOURCE (see large_object_record).
  lda LARGE_SOURCE
  xba
  and #255                      ; the arcade page of the step
  cmp #>ARCADE_BANK_WINDOW
  bcs @banked
  ora #SCRIPT_FIXED_ROW
  bra @page
@banked:
  and #SCRIPT_BANK_ROWS-1
  ora LARGE_BANK
@page:
  sta GIANT_WORD                ; the row; X = row * 3
  asl
  clc
  adc GIANT_WORD
  tax
  lda LARGE_SOURCE
  and #255
  clc
  adc f:enemy_script_pages,x
  sta f:large_object_read+1     ; the host address of the step
  a8
  lda f:enemy_script_pages+2,x
  adc #0
  sta f:large_object_read+3
  ldx #STEP_DURATION
  jsr .loword(large_object_read)
  bne :+
  ; STEP_TAIL: the caller runs the decision of the tail.
  a16
  ldx #STEP_CODE
  jsr .loword(large_object_read)
  sta LARGE_CALLBACK
  a8
  lda #LK_CALLBACK
  sta LARGE_KIND
  rts
:
  cmp #STEP_JUMP
  bne :+
  ; STEP_JUMP: continue at the step in its word.
  a16
  ldx #STEP_CODE
  jsr .loword(large_object_read)
  sta LARGE_SOURCE
  ldx GIANT_BASE
  sta a:GIANT_HEAD+OBJ_MOTION,x
  jmp .loword(@record)
:
.a8
  cmp #STEP_END
  bne :+
  ldx GIANT_BASE
  jmp .loword(giant_object_retire)
:
  ; A motion step: copy it to GIANT_SCRIPT.
  ldx #0
@read:
  jsr .loword(large_object_read)
  sta GIANT_SCRIPT,x
  inx
  cpx #STEP_SIZE
  bne @read
  ldx GIANT_BASE
  a16
  lda LARGE_SOURCE
  sta a:GIANT_HEAD+OBJ_MOTION,x
  lda GIANT_SCRIPT+STEP_CROSS_DELTA
  xba
  sta a:GIANT_HEAD+OBJ_CROSS_DELTA,x
  lda GIANT_SCRIPT+STEP_ALONG_DELTA
  xba
  sta a:GIANT_HEAD+OBJ_ALONG_DELTA,x
  a8
  lda GIANT_SCRIPT+STEP_DURATION
  sta a:GIANT_HEAD+OBJ_DURATION,x
  ; The sprite codes of the sixteen pieces.
  lda GIANT_SCRIPT+STEP_CODE
  .repeat GIANT_ROWS,R
    .repeat GIANT_COLUMNS,C
      giant_piece sta, R, C, SPR_CODE
      .if C<GIANT_COLUMNS-1
        inc
      .endif
    .endrepeat
    .if R<GIANT_ROWS-1
      clc
      adc #GIANT_CODE_ROW-(GIANT_COLUMNS-1)
    .endif
  .endrepeat
  ; The colour of each row; its SPR_ALONG_HIGH stays.
  .repeat GIANT_ROWS,R
    giant_piece lda, R, GIANT_HEAD_COLUMN, SPR_ATTR
    and #SPR_ALONG_HIGH
    ora GIANT_SCRIPT+STEP_ATTR
    .repeat GIANT_COLUMNS,C
      giant_piece sta, R, C, SPR_ATTR
    .endrepeat
  .endrepeat
  rts

; giant_object_motion: move by the 8.8 moves (or by the camera move, with
; OF_CAMERA) and place the sixteen pieces around the head. SPR_ALONG_HIGH is
; the ninth along bit: a carry in the move direction toggles it on row 0; the
; upper rows take it from their 9-bit along. Off the field the giant retires.
giant_object_motion:
.a8
  ldx GIANT_BASE
  lda a:GIANT_HEAD+OBJ_FLAGS,x
  and #OF_CAMERA
  beq @x
  lda LARGE_CAM_X
  sta a:GIANT_HEAD+OBJ_CROSS_DELTA,x
  stz a:GIANT_HEAD+OBJ_CROSS_DELTA+1,x
@x:
  ; The cross: (SPR_CROSS:OBJ_CROSS_FRACTION) + the 8.8 move.
  a16
  lda a:GIANT_HEAD+OBJ_CROSS_DELTA,x
  xba
  sta GIANT_WORD
  lda a:GIANT_HEAD+SPR_CROSS,x
  and #255
  xba
  sta LARGE_SOURCE
  lda a:GIANT_HEAD+OBJ_CROSS_FRACTION,x
  and #255
  ora LARGE_SOURCE
  clc
  adc GIANT_WORD
  a8
  sta a:GIANT_HEAD+OBJ_CROSS_FRACTION,x
  xba                           ; the new cross of the head column
  .repeat GIANT_ROWS,R
    giant_piece sta, R, GIANT_HEAD_COLUMN, SPR_CROSS
  .endrepeat
  clc
  adc #PIECE_RIGHT
  .repeat GIANT_ROWS,R
    giant_piece sta, R, GIANT_HEAD_COLUMN+1, SPR_CROSS
  .endrepeat
  sec
  sbc #3*PIECE_RIGHT            ; from column 3 back to column 0
  .repeat GIANT_ROWS,R
    giant_piece sta, R, 0, SPR_CROSS
  .endrepeat
  clc
  adc #PIECE_RIGHT
  .repeat GIANT_ROWS,R
    giant_piece sta, R, 1, SPR_CROSS
  .endrepeat
  lda a:GIANT_HEAD+OBJ_FLAGS,x
  and #OF_CAMERA
  beq @y
  lda LARGE_CAM_Y
  sta a:GIANT_HEAD+OBJ_ALONG_DELTA,x
  stz a:GIANT_HEAD+OBJ_ALONG_DELTA+1,x
@y:
  ; The along of row 0: (SPR_ALONG:OBJ_ALONG_FRACTION) + the 8.8 move.
  a16
  lda a:GIANT_HEAD+OBJ_ALONG_DELTA,x
  xba
  sta GIANT_WORD
  lda a:GIANT_HEAD+SPR_ALONG,x
  and #255
  xba
  sta LARGE_SOURCE
  lda a:GIANT_HEAD+OBJ_ALONG_FRACTION,x
  and #255
  ora LARGE_SOURCE
  clc
  adc GIANT_WORD
  a8
  sta a:GIANT_HEAD+OBJ_ALONG_FRACTION,x
  xba
  .repeat GIANT_COLUMNS,C
    giant_piece sta, 0, C, SPR_ALONG
  .endrepeat
  bcc @no_carry
  lda a:GIANT_HEAD+OBJ_ALONG_DELTA,x
  bmi @inside                   ; a negative move with a carry: no wrap
  bra @toggle
@no_carry:
  lda a:GIANT_HEAD+OBJ_ALONG_DELTA,x
  bpl @inside
@toggle:
  lda a:GIANT_HEAD+SPR_ATTR,x
  eor #SPR_ALONG_HIGH
  .repeat GIANT_COLUMNS,C
    giant_piece sta, 0, C, SPR_ATTR
  .endrepeat
@inside:
  lda a:GIANT_HEAD+SPR_ATTR,x
  and #SPR_ALONG_HIGH
  beq @rows
  lda a:GIANT_HEAD+SPR_ALONG,x
  cmp #GIANT_ALONG_OUT_MIN
  bcc @rows
  cmp #GIANT_ALONG_OUT_MAX
  bcs @rows
  jmp .loword(giant_object_retire)
@rows:
  ; GIANT_WORD = the 9-bit along of row 0 (SPR_ALONG_HIGH is bit 8). Row R
  ; is R*PIECE_RISE less; bit 8 of the result is its SPR_ALONG_HIGH.
  a16
  lda a:GIANT_HEAD+SPR_ATTR,x
  and #SPR_ALONG_HIGH
  asl
  asl
  asl
  asl
  sta GIANT_WORD
  lda a:GIANT_HEAD+SPR_ALONG,x
  and #255
  ora GIANT_WORD
  sta GIANT_WORD
  .repeat GIANT_ROWS-1,I
    .a16
    lda GIANT_WORD
    sec
    sbc #(I+1)*PIECE_RISE
    a8
    .repeat GIANT_COLUMNS,C
      giant_piece sta, I+1, C, SPR_ALONG
    .endrepeat
    xba                         ; bit 8 of the along
    beq :+
    giant_piece lda, I+1, GIANT_HEAD_COLUMN, SPR_ATTR
    ora #SPR_ALONG_HIGH
    bra :++
:
    giant_piece lda, I+1, GIANT_HEAD_COLUMN, SPR_ATTR
    and #<~SPR_ALONG_HIGH
:
    .repeat GIANT_COLUMNS,C
      giant_piece sta, I+1, C, SPR_ATTR
    .endrepeat
    a16
  .endrepeat
  a8
  dec a:GIANT_HEAD+OBJ_DURATION,x
  rts
.assert SPR_ALONG_HIGH = $10, error ; the four ASLs above: bit 4 to bit 8

; giant_object_retire: the giant goes: its type and the cross of all pieces
; are cleared. In: X = GIANT_BASE.
giant_object_retire:
.a8
  stz a:GIANT_HEAD+OBJ_TYPE,x
  lda #0
  .repeat GIANT_ROWS,R
    .repeat GIANT_COLUMNS,C
      giant_piece sta, R, C, SPR_CROSS
    .endrepeat
  .endrepeat
  lda #LK_RETIRED
  sta LARGE_KIND
  rts
.delmacro giant_piece
