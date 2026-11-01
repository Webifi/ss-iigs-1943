; One tick of a large object (four sprite records, LARGE_SIZE): its motion
; script and its move. A native port of the US arcade code at $5B6D-$5C89.
; The caller (src/large_loop.s) runs the decisions of returned code tails,
; the contacts, the score and the sound. Pieces: record 0 the head, 1 to its
; right, 2 above the head, 3 above record 1.
.a8
.i16
PIECE_RIGHT = 16             ; the right pieces are this far to the right
LARGE_CROSS_END = $f9        ; past this cross the object retires
LARGE_ALONG_OUT_MIN = $28    ; past the field (SPR_ALONG_HIGH) and inside
LARGE_ALONG_OUT_MAX = $e0    ; LARGE_ALONG_OUT_MIN..MAX-1: the object retires

; large_object_tick: one tick of the object at LARGE_RECORD. Returns
; LARGE_KIND (0 moved, LK_RETIRED or LK_CALLBACK with LARGE_CALLBACK). JSL.
large_object_tick:
  phd
  a16
  lda LARGE_RECORD
  tcd
  a8
  stz LARGE_KIND
  a16
  stz LARGE_CALLBACK
  a8
  jml large_turret_stationary
large_object_decode:
  jsr .loword(large_object_script)
  lda LARGE_KIND
  bne large_object_done
large_object_move:
  jsr .loword(large_object_motion)
large_object_done:
  pld
  rtl

.pushseg
.segment "SOUND"
; large_turret_stationary: a ship turret (OT_TURRET, motion bank 6) that
; follows a camera that does not move only counts its step down: its four
; pieces are in place already. Bank-6 turret templates start with a step
; time of 0, so their first tick decodes the script.
large_turret_stationary:
  lda OBJ_DURATION
  beq @decode
  lda OBJ_TYPE
  cmp #OT_TURRET
  bne @move
  lda OBJ_VARIANT
  and #OBJ_BANK_BITS
  cmp #6<<4                     ; motion bank 6
  bne @move
  lda OBJ_FLAGS
  and #OF_CAMERA
  beq @move
  lda LARGE_CAM_X
  ora LARGE_CAM_Y
  bne @move
  lda SHIP_FINISH_ACTIVE
  bne @move
  stz OBJ_CROSS_DELTA
  stz OBJ_CROSS_DELTA+1
  stz OBJ_ALONG_DELTA
  stz OBJ_ALONG_DELTA+1
  dec OBJ_DURATION
  pld
  rtl
@move:
  jml large_object_move
@decode:
  jml large_object_decode
.popseg

; large_object_script: when the step time is over, read the next motion step
; (STEP_* fields) from the motion page of OBJ_MOTION+STEP_SIZE. The build
; keeps the arcade motion data in enemy_script_pages: one 3-byte entry for
; each 256-byte page, the fixed pages at SCRIPT_FIXED_ROW, a bank's pages
; from bank*SCRIPT_BANK_ROWS.
large_object_script:
  lda OBJ_DURATION
  beq @advance
  rts
@advance:
  a16
  lda OBJ_VARIANT
  and #OBJ_BANK_BITS
  asl
  asl                           ; bank*16*4 = bank*SCRIPT_BANK_ROWS
  sta LARGE_BANK
  lda OBJ_MOTION
  clc
  adc #STEP_SIZE
  sta LARGE_SOURCE
; large_object_record: point large_object_read at the step LARGE_SOURCE.
large_object_record:
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
  sta LARGE_WORD                ; the row; X = row * 3
  asl
  clc
  adc LARGE_WORD
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
  jmp .loword(large_object_callback)  ; STEP_TAIL
:
  cmp #STEP_JUMP
  bne :+
  jmp .loword(large_object_jump)
:
  cmp #STEP_END
  bne :+
  jmp .loword(large_object_retire)
:
  ; A motion step: the time, the sprite codes of the four pieces, the colour
  ; and the two 8.8 moves.
  sta OBJ_DURATION
  a16
  lda LARGE_SOURCE
  sta OBJ_MOTION
  a8
  inx
  jsr .loword(large_object_read)
  sta SPR_CODE
  inc
  sta SPRITE_SIZE+SPR_CODE
  clc
  adc #7                        ; the upper pieces: the code + 8 and + 9
  sta 2*SPRITE_SIZE+SPR_CODE
  inc
  sta 3*SPRITE_SIZE+SPR_CODE
  inx
  jsr .loword(large_object_read)
  sta LARGE_WORD                ; the colour; SPR_ALONG_HIGH stays
  lda SPR_ATTR
  and #SPR_ALONG_HIGH
  ora LARGE_WORD
  sta SPR_ATTR
  sta SPRITE_SIZE+SPR_ATTR
  lda 2*SPRITE_SIZE+SPR_ATTR
  and #SPR_ALONG_HIGH
  ora LARGE_WORD
  sta 2*SPRITE_SIZE+SPR_ATTR
  sta 3*SPRITE_SIZE+SPR_ATTR
  inx
  jsr .loword(large_object_read)
  sta OBJ_CROSS_DELTA+1
  inx
  jsr .loword(large_object_read)
  sta OBJ_CROSS_DELTA
  inx
  jsr .loword(large_object_read)
  sta OBJ_ALONG_DELTA+1
  inx
  jsr .loword(large_object_read)
  sta OBJ_ALONG_DELTA
  rts
; large_object_jump: STEP_JUMP: continue at the step in its word.
large_object_jump:
  a16
  ldx #STEP_CODE
  jsr .loword(large_object_read)
  sta OBJ_MOTION
  sta LARGE_SOURCE
  jmp .loword(large_object_record)
; large_object_callback: STEP_TAIL: the caller runs the decision of the tail.
large_object_callback:
  a16
  ldx #STEP_CODE
  jsr .loword(large_object_read)
  sta LARGE_CALLBACK
  a8
  lda #LK_CALLBACK
  sta LARGE_KIND
  rts
; large_object_read: A = the byte (or word) X bytes into the step.
large_object_read:
  lda f:0,x                     ; patched: the host address of the step
  rts

; large_object_motion: move by the 8.8 moves (or by the camera move, with
; OF_CAMERA). The right pieces are PIECE_RIGHT to the right, the upper pieces
; PIECE_RISE further along. SPR_ALONG_HIGH is the ninth along bit: a carry
; in the move direction toggles it. Off the field the object retires.
large_object_motion:
.a8
  lda OBJ_FLAGS
  and #OF_CAMERA
  beq @x
  lda LARGE_CAM_X
  sta OBJ_CROSS_DELTA
  stz OBJ_CROSS_DELTA+1
@x:
  clc
  lda OBJ_CROSS_FRACTION
  adc OBJ_CROSS_DELTA+1
  sta OBJ_CROSS_FRACTION
  lda SPR_CROSS
  adc OBJ_CROSS_DELTA
  sta SPR_CROSS
  sta 2*SPRITE_SIZE+SPR_CROSS
  clc
  adc #PIECE_RIGHT
  sta SPRITE_SIZE+SPR_CROSS
  sta 3*SPRITE_SIZE+SPR_CROSS
  cmp #LARGE_CROSS_END
  bcc :+
  jmp .loword(large_object_retire)
:
  lda OBJ_FLAGS
  and #OF_CAMERA
  beq @y
  lda LARGE_CAM_Y
  sta OBJ_ALONG_DELTA
  stz OBJ_ALONG_DELTA+1
@y:
  clc
  lda OBJ_ALONG_FRACTION
  adc OBJ_ALONG_DELTA+1
  sta OBJ_ALONG_FRACTION
  lda SPR_ALONG
  adc OBJ_ALONG_DELTA
  sta SPR_ALONG
  sta SPRITE_SIZE+SPR_ALONG
  bcc @no_carry
  lda OBJ_ALONG_DELTA
  bmi @bottom                   ; a negative move with a carry: no wrap
  bra @toggle
@no_carry:
  lda OBJ_ALONG_DELTA
  bpl @bottom
@toggle:
  lda SPR_ATTR
  eor #SPR_ALONG_HIGH
  sta SPR_ATTR
  sta SPRITE_SIZE+SPR_ATTR
@bottom:
  ; The upper pieces: a borrow from the low byte toggles the ninth bit.
  lda SPR_ALONG
  sec
  sbc #PIECE_RISE
  sta 2*SPRITE_SIZE+SPR_ALONG
  sta 3*SPRITE_SIZE+SPR_ALONG
  lda SPR_ATTR
  bcs :+
  eor #SPR_ALONG_HIGH
:
  and #SPR_ALONG_HIGH
  beq @bottom_inside
  lda 2*SPRITE_SIZE+SPR_ATTR
  ora #SPR_ALONG_HIGH
  bra @bottom_attr
@bottom_inside:
  lda 2*SPRITE_SIZE+SPR_ATTR
  and #<~SPR_ALONG_HIGH
@bottom_attr:
  sta 2*SPRITE_SIZE+SPR_ATTR
  sta 3*SPRITE_SIZE+SPR_ATTR
  lda SPR_ATTR
  and #SPR_ALONG_HIGH
  beq @inside
  lda SPR_ALONG
  cmp #LARGE_ALONG_OUT_MIN
  bcc @inside
  cmp #LARGE_ALONG_OUT_MAX
  bcs @inside
  jmp .loword(large_object_retire)
@inside:
  dec OBJ_DURATION
  rts

; large_object_retire: the object goes. A boss part gives its ledger value
; less its HP left to LARGE_TOTAL.
large_object_retire:
.a8
  stz OBJ_TYPE
  stz SPR_CROSS
  stz SPRITE_SIZE+SPR_CROSS
  stz 2*SPRITE_SIZE+SPR_CROSS
  stz 3*SPRITE_SIZE+SPR_CROSS
  lda #LK_RETIRED
  sta LARGE_KIND
  lda OBJ_LEDGER
  beq @done
  a16
  and #255
  tax
  a8
  lda LARGE_GROUPS,x
  beq @done
  sec
  sbc OBJ_HP
  clc
  adc LARGE_TOTAL
  sta LARGE_TOTAL
@done:
  rts
.assert OBJ_BANK_BITS = $70 .and SCRIPT_BANK_ROWS = 64, error  ; the two ASLs above
