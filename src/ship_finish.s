; Native timed destruction sequence, original US $32E2-$343E.
; Full pools defer to the next tick. No ROM scheduler or stack runs here.
.a8
.i16
SHIP_FINISH_ACTIVE = $1c80       ; 0 idle, 1 loop, 2 final, 3 giant pending
SHIP_FINISH_WAIT = $1c81
SHIP_FINISH_INDEX = $1c82
SHIP_FINISH_PATTERN = $1c83
SHIP_FINISH_OWNER = $1c84
SHIP_FINISH_KIND = $1c86         ; 0 four pieces, 1 sixteen pieces
SHIP_FINISH_DEST = $1c88
SHIP_FINISH_PATH = $1c8a
SHIP_FINISH_OFFSET = $1c8c
SHIP_FINISH_Y = $1c8e

ship_finish_begin:
  ; A is 1 (looping $32EA) or 2 (final $32E2).
  sta SHIP_FINISH_ACTIVE
  stz SHIP_FINISH_WAIT
  stz SHIP_FINISH_INDEX
  lda STAGE_FLAGS+$1c
  sta SHIP_FINISH_PATTERN
  lda #1
  sta STAGE_FLAGS+$10
  rep #$20
  lda STAGE_FLAGS+$1d
  sta SHIP_FINISH_OWNER
  sep #$20
  rtl

ship_finish_tick:
  lda SHIP_FINISH_ACTIVE
  bne :+
  rtl
:
  lda SHIP_FINISH_WAIT
  beq @ready
  dec SHIP_FINISH_WAIT
  beq :+
  rtl
:
  lda #$0f
  sta PLAYER_EVENT_SOUND
@ready:
  lda SHIP_FINISH_ACTIVE
  cmp #3
  bne @piece
  jmp .loword(ship_finish_giant)
@piece:
  jsr .loword(ship_finish_select_path)
  jsr .loword(ship_finish_read)
  cmp #255
  bne @spawn
  lda SHIP_FINISH_ACTIVE
  cmp #1
  bne @end
  stz SHIP_FINISH_INDEX
  bra @piece
@end:
  lda CAMERA_STAGE
  cmp #2
  beq ship_finish_done
  cmp #8
  beq ship_finish_done
  cmp #13
  beq ship_finish_done
  lda #3
  sta SHIP_FINISH_ACTIVE
  jmp .loword(ship_finish_giant)
@spawn:
  stz SHIP_FINISH_KIND
  jsl ship_finish_spawn
  bcs :+
  rtl
:
  inc SHIP_FINISH_INDEX
  ldx SHIP_FINISH_PATH
  inx
  inx
  jsr .loword(ship_finish_read)
  sta SHIP_FINISH_WAIT
  bne @return
  lda #$0f
  sta PLAYER_EVENT_SOUND
  bra @piece
@return:
  rtl
ship_finish_giant:
.a8
  lda #1
  sta SHIP_FINISH_KIND
  jsl ship_finish_spawn
  bcs :+
  rtl
:
  lda #12
  sta STAGE_FLAGS+9
ship_finish_done:
.a8
  stz CAMERA+$21
  stz SHIP_FINISH_ACTIVE
  lda #$1d
  sta PLAYER_EVENT_SOUND
  ; $3A is the original music/sequence command, retained separately.
  lda #$3a
  sta SHIP_FINISH_WAIT
  rtl

ship_finish_select_path:
.a8
  rep #$20
  lda SHIP_FINISH_PATTERN
  and #255
  asl
  tax
  lda f:ship_finish_paths,x
  sta SHIP_FINISH_PATH
  lda SHIP_FINISH_INDEX
  and #255
  sta SHIP_FINISH_OFFSET
  asl
  clc
  adc SHIP_FINISH_OFFSET
  clc
  adc SHIP_FINISH_PATH
  sta SHIP_FINISH_PATH
  tax
  sep #$20
  rts
ship_finish_read:
  lda f:$010000,x
  rts

ship_finish_spawn:
.a8
  lda SHIP_FINISH_KIND
  bne @giant
  jsr .loword(large_allocate_turret)
  bra @allocated
@giant:
  jsr .loword(giant_allocate)
@allocated:
  bcs @found
  clc
  rtl
@found:
  rep #$20
  txa
  clc
  adc #LARGE_POOL
  sta SHIP_FINISH_DEST
  tay
  lda SHIP_FINISH_KIND
  and #255
  asl
  asl
  asl
  asl
  asl
  tax
  .repeat 16
    lda f:ship_finish_templates,x
    sta a:0,y
    inx
    inx
    iny
    iny
  .endrepeat
  sep #$20
  lda SHIP_FINISH_KIND
  bne @giant_offset
  jsr .loword(ship_finish_select_path)
  bra @position
@giant_offset:
  rep #$20
  lda SHIP_FINISH_PATTERN
  and #255
  asl
  clc
  adc #.loword(ship_finish_offsets)
  tax
  sep #$20
@position:
.a8
  jsr .loword(ship_finish_read)
  ldy SHIP_FINISH_OWNER
  clc
  adc a:2,y
  ldy SHIP_FINISH_DEST
  sta a:2,y
  inx
  jsr .loword(ship_finish_read)
  rep #$20
  and #255
  cmp #128
  bcc :+
  ora #$ff00
:
  sta SHIP_FINISH_OFFSET
  ldx SHIP_FINISH_OWNER
  lda a:1,x
  and #16
  asl
  asl
  asl
  asl
  sta SHIP_FINISH_Y
  lda a:3,x
  and #255
  ora SHIP_FINISH_Y
  clc
  adc SHIP_FINISH_OFFSET
  sta SHIP_FINISH_Y
  ldx SHIP_FINISH_DEST
  sep #$20
  sta a:3,x
  sec
  sbc #16
  sta a:$43,x
  lda SHIP_FINISH_KIND
  beq @attr
  lda SHIP_FINISH_Y
  sec
  sbc #32
  sta a:$103,x
  sec
  sbc #16
  sta a:$143,x
@attr:
  lda SHIP_FINISH_Y+1
  beq @inside
  lda a:1,x
  ora #16
  bra @write
@inside:
  lda a:1,x
  and #$ef
@write:
  sta a:1,x
  sta a:$41,x
  pha
  lda SHIP_FINISH_KIND
  beq @four
  pla
  sta a:$101,x
  sta a:$141,x
  sec
  rtl
@four:
  pla
  sec
  rtl

giant_allocate:
.a8
  ldx #0
@group:
  lda LARGE_POOL+8,x
  ora LARGE_POOL+$88,x
  ora LARGE_POOL+$108,x
  ora LARGE_POOL+$188,x
  beq @found
  rep #$20
  txa
  clc
  adc #512
  tax
  sep #$20
  cpx #1536
  bne @group
  clc
  rts
@found:
  rep #$20
  txa
  clc
  adc #128
  tax
  sep #$20
  sec
  rts
