; Native original-US four-piece object controller, fixed $5B6D-$5C89.
; D selects one 128-byte live record. No per-tick record copy is needed.
; The caller handles returned AI callbacks, contacts, score and sound.
.a8
.i16
LARGE_GROUPS = $1c00         ; original E570..E59F
LARGE_TOTAL = $1c30          ; original E553
LARGE_CAM_X = $1c31         ; original E419
LARGE_CAM_Y = $1c32         ; original E41A
LARGE_KIND = $1c33          ; 0 moved, 1 retired, 2 native callback needed
LARGE_CALLBACK = $1c34
LARGE_MODE = $1c36          ; fixture: 0 script+move, 1 move only
LARGE_RECORD = $1c38
LARGE_SOURCE = $1c3a
LARGE_BANK = $1c3c
LARGE_WORD = $1c3e

large_object_tick:
  phd
  rep #$20
  lda LARGE_RECORD
  tcd
  sep #$20
  stz LARGE_KIND
  rep #$20
  stz LARGE_CALLBACK
  sep #$20
  lda LARGE_MODE
  bne large_object_move
 .ifdef CONTINUOUS_GAME
  jml large_turret_stationary
large_object_decode:
 .else
  lda $04
  bne large_object_move
 .endif
  jsr .loword(large_object_script)
  lda LARGE_KIND
  bne large_object_done
large_object_move:
  jsr .loword(large_object_motion)
large_object_done:
  pld
  rtl

.ifdef CONTINUOUS_GAME
.pushseg
.segment "SOUND"
; Bank-six turret templates start with a zero countdown. A continuing
; stationary record has already had its four piece coordinates established.
large_turret_stationary:
  lda $04
  beq @decode
  lda $08
  cmp #$21
  bne @move
  lda $0a
  and #$70
  cmp #$60
  bne @move
  lda $09
  and #4
  beq @move
  lda LARGE_CAM_X
  ora LARGE_CAM_Y
  bne @move
  lda SHIP_FINISH_ACTIVE
  bne @move
  stz $18
  stz $19
  stz $1a
  stz $1b
  dec $04
  pld
  rtl
@move:
  jml large_object_move
@decode:
  jml large_object_decode
.popseg
.endif

large_object_script:
  lda $04
  beq @advance
  rts
@advance:
  rep #$20
  lda $0a
  and #$70
  asl
  asl
  sta LARGE_BANK
  lda $1e
  clc
  adc #7
  sta LARGE_SOURCE
large_object_record:
  ; Sparse native data pages contain movement data only, not Z80 opcodes.
  lda LARGE_SOURCE
  xba
  and #255
  cmp #$80
  bcs @banked
  ora #512
  bra @page
@banked:
  and #63
  ora LARGE_BANK
@page:
  sta LARGE_WORD
  asl
  clc
  adc LARGE_WORD
  tax
  lda LARGE_SOURCE
  and #255
  clc
  adc f:enemy_script_pages,x
  sta f:large_object_read+1
  sep #$20
  lda f:enemy_script_pages+2,x
  adc #0
  sta f:large_object_read+3
  ldx #0
  jsr .loword(large_object_read)
  bne :+
  jmp .loword(large_object_callback)
:
  cmp #255
  bne :+
  jmp .loword(large_object_jump)
:
  cmp #254
  bne :+
  jmp .loword(large_object_retire)
:
  sta $04
  rep #$20
  lda LARGE_SOURCE
  sta $1e
  sep #$20
  inx
  jsr .loword(large_object_read)
  sta $00
  inc
  sta $20
  clc
  adc #7
  sta $40
  inc
  sta $60
  inx
  jsr .loword(large_object_read)
  sta LARGE_WORD
  lda $01
  and #16
  ora LARGE_WORD
  sta $01
  sta $21
  lda $41
  and #16
  ora LARGE_WORD
  sta $41
  sta $61
  inx
  jsr .loword(large_object_read)
  sta $19
  inx
  jsr .loword(large_object_read)
  sta $18
  inx
  jsr .loword(large_object_read)
  sta $1b
  inx
  jsr .loword(large_object_read)
  sta $1a
  rts
large_object_jump:
  rep #$20
  ldx #1
  jsr .loword(large_object_read)
  sta $1e
  sta LARGE_SOURCE
  jmp .loword(large_object_record)
large_object_callback:
  rep #$20
  ldx #1
  jsr .loword(large_object_read)
  sta LARGE_CALLBACK
  sep #$20
  lda #2
  sta LARGE_KIND
  rts
large_object_read:
  lda f:$000000,x
  rts

large_object_motion:
.a8
  lda $09
  and #4
  beq @x
  lda LARGE_CAM_X
  sta $18
  stz $19
@x:
  clc
  lda $05
  adc $19
  sta $05
  lda $02
  adc $18
  sta $02
  sta $42
  clc
  adc #16
  sta $22
  sta $62
  cmp #$f9
  bcc :+
  jmp .loword(large_object_retire)
:
  lda $09
  and #4
  beq @y
  lda LARGE_CAM_Y
  sta $1a
  stz $1b
@y:
  clc
  lda $06
  adc $1b
  sta $06
  lda $03
  adc $1a
  sta $03
  sta $23
  bcc @no_carry
  lda $1a
  bmi @bottom
  bra @toggle
@no_carry:
  lda $1a
  bpl @bottom
@toggle:
  lda $01
  eor #16
  sta $01
  sta $21
@bottom:
  ; A borrow from the low byte toggles the original ninth vertical bit.
  lda $03
  sec
  sbc #16
  sta $43
  sta $63
  lda $01
  bcs :+
  eor #16
:
  and #16
  beq @bottom_inside
  lda $41
  ora #16
  bra @bottom_attr
@bottom_inside:
  lda $41
  and #$ef
@bottom_attr:
  sta $41
  sta $61
  lda $01
  and #16
  beq @inside
  lda $03
  cmp #$28
  bcc @inside
  cmp #$e0
  bcs @inside
  jmp .loword(large_object_retire)
@inside:
  dec $04
  rts

large_object_retire:
.a8
  stz $08
  stz $02
  stz $22
  stz $42
  stz $62
  lda #1
  sta LARGE_KIND
  lda $0f
  beq @done
  rep #$20
  and #255
  tax
  sep #$20
  lda LARGE_GROUPS,x
  beq @done
  sec
  sbc $0b
  clc
  adc LARGE_TOTAL
  sta LARGE_TOTAL
@done:
  rts
