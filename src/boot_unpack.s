; Unpack one card startup record (scripts/startup_pack.py) from DATA_BUFFER
; to STARTUP_UNPACK_OUTPUT. In: unpack_end = the unpacked size.
; MVN copies forward, including overlapping matches; interrupts are masked.
; MVN sets the data bank to the output bank, so the variables are in page zero.
; A token below TOKEN_MATCH: token + 1 literal bytes follow; from it: a
; match of (token - TOKEN_MATCH) + MATCH_MIN bytes at the word distance that
; follows. MVN copies C + 1 bytes.
UNPACK_SOURCE = DATA_BUFFER & $FF0000   ; X holds the full source address
TOKEN_MATCH = $80
MATCH_MIN = 3
.a8
.i16
; startup_unpack: unpack the record. JSR; A8, X16.
startup_unpack:
  phb
  ldx #.loword(DATA_BUFFER)
  ldy #.loword(STARTUP_UNPACK_OUTPUT)
  a16
  lda unpack_end
  clc
  adc #.loword(STARTUP_UNPACK_OUTPUT)
  sta unpack_end
  a8
@token:
  lda f:UNPACK_SOURCE,x
  bmi @match                    ; TOKEN_MATCH
  inx
  a16
  and #$00ff                    ; the count - 1
  mvn #^DATA_BUFFER,#^STARTUP_UNPACK_OUTPUT
  a8
  bra @next
@match:
  inx
  and #<~TOKEN_MATCH
  clc
  adc #MATCH_MIN-1              ; the count - 1
  a16
  and #$00ff
  sta unpack_length
  lda f:UNPACK_SOURCE,x
  sta unpack_distance
  inx
  inx
  phx
  tya
  sec
  sbc unpack_distance
  tax
  lda unpack_length
  mvn #^STARTUP_UNPACK_OUTPUT,#^STARTUP_UNPACK_OUTPUT
  plx
  a8
@next:
  cpy unpack_end
  bcc @token
  plb
  rts
