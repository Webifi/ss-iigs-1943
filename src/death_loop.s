; Connect the verified death controller. Outer continue/game-over UI is open.
.a8
.i16
death_loop_init:
  rep #$20
  ldx #126
@clear_shadow:
  stz PLAYER_SHADOW,x
  dex
  dex
  bpl @clear_shadow
  stz DEATH_CONTEXT
  lda #$0100
  sta DEATH_CONTEXT+2
  lda #1
  sta DEATH_CONTEXT+4
  stz DEATH_CONTEXT+6
  sep #$20
.if FLIGHT_ART_STREAM
  jmp art_stream_init
.else
  rts
.endif

.ifndef STATE_ONLY
death_player_records:
  rep #$30
  ldy #0
  lda PLAYER+8
  and #255
  beq @done
  lda #2
  sta $b6
  lda PLAYER+8
  and #255
  cmp #4
  bne @pieces
  sta $b6
@pieces:
  ldx #0
@piece:
  lda PLAYER,x
  and #255
  sta FLIGHT_OBJECTS,y
  lda PLAYER+1,x
  and #15
  sta FLIGHT_OBJECTS+2,y
  lda PLAYER+2,x
  and #255
  sec
  sbc #16
  sta FLIGHT_OBJECTS+4,y
  lda PLAYER+3,x
  and #255
  sta $b8
  lda #240
  sec
  sbc $b8
  sta FLIGHT_OBJECTS+6,y
  txa
  clc
  adc #32
  tax
  tya
  clc
  adc #8
  tay
  dec $b6
  bne @piece
@done:
  tya
  lsr
  lsr
  lsr
  sta $2a
  rts

.endif
