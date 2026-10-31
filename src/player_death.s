; Original-US bank 1 $8B46-$8C2B, $8305-$8385 and $19DF-$19EF.
; Native state, not execution of the original CPU program.
; Context: player offset, E430, E15A, E310, E150, E14C, attract exit, spare.
.a8
.i16
.ifndef PLAYER
PLAYER = $1000
.endif
.ifdef CONTINUOUS_GAME
PLAYER_SHADOW = $1400
.else
PLAYER_SHADOW = $1200
.endif
DEATH_CONTEXT = $11e0

player_death:
  stz DEATH_CONTEXT+6
  rep #$20
  lda DEATH_CONTEXT
  and #$80
  tax
  sep #$20
  stz PLAYER+$55,x
  stz PLAYER+7,x
  stz PLAYER+4,x
  phx
  lda PLAYER+5,x
  beq @other_p2
  ldx #0
  bra @other_state
@other_p2:
  ldx #128
@other_state:
  lda PLAYER+8,x
  plx
  cmp #2
  beq @countdown
  lda #1
  sta DEATH_CONTEXT+1
@countdown:
  lda PLAYER+$1c,x
  bne @delay
  lda PLAYER+$1d,x
  bne @next_frame
  stz PLAYER+1,x
  stz PLAYER+$21,x
  stz PLAYER+$41,x
  stz PLAYER+$61,x
  lda PLAYER+2,x
  sta PLAYER+$42,x
  clc
  adc #16
  sta PLAYER+$22,x
  sta PLAYER+$62,x
  lda PLAYER+3,x
  clc
  adc #4
  sta PLAYER+3,x
  sta PLAYER+$23,x
  sec
  sbc #16
  sta PLAYER+$43,x
  sta PLAYER+$63,x
@next_frame:
  rep #$20
  lda PLAYER+$1d,x
  and #255
  tay
  sep #$20
  inc PLAYER+$1d,x
  inc PLAYER+$1d,x
  lda player_death_frames,y
  cmp #255
  beq @finished
  sta PLAYER+$1c,x
  lda player_death_frames+1,y
  sta PLAYER,x
  inc
  sta PLAYER+$20,x
  clc
  adc #7
  sta PLAYER+$40,x
  inc
  sta PLAYER+$60,x
@delay:
  dec PLAYER+$1c,x
  jmp player_shadow_death
@finished:
  stz DEATH_CONTEXT+2
  lda DEATH_CONTEXT+3
  bne @playing
  lda #1
  sta DEATH_CONTEXT+6
  rts
@playing:
  phx
  lda PLAYER+5,x
  beq @finish_other_p2
  ldx #0
  bra @finish_other
@finish_other_p2:
  ldx #128
@finish_other:
  lda PLAYER+8,x
  plx
  beq @last_player
  cmp #4
  bne @clear_player
@last_player:
  lda DEATH_CONTEXT+4
  beq @clear_player
  stz DEATH_CONTEXT+4
  lda #1
  sta DEATH_CONTEXT+5
@clear_player:
  lda #$0b
  sta PLAYER+$2a,x
  stz PLAYER+8,x
  .repeat 5,i
    stz PLAYER+$1b+i,x
    stz PLAYER+$5b+i,x
    stz PLAYER+$7b+i,x
  .endrepeat
  ; The original deliberately leaves the second piece's $3B-$3F alone.
.ifdef CONTINUOUS_GAME
  jsl native_player_respawn_position
.endif
player_shadow_death:
  lda PLAYER_SHADOW+5
  cmp PLAYER+5,x
  beq @owner
  rts
@owner:
  lda PLAYER+$0f,x
  bne @visible
  lda PLAYER_SHADOW+1
  ora #$1e
  sta PLAYER_SHADOW+1
  sta PLAYER_SHADOW+$21
  sta PLAYER_SHADOW+$41
  sta PLAYER_SHADOW+$61
  lda #$e0
  sta PLAYER_SHADOW+3
  sta PLAYER_SHADOW+$23
  lda #$d0
  sta PLAYER_SHADOW+$43
  sta PLAYER_SHADOW+$63
  rts
@visible:
  lda #$0e
  sta PLAYER_SHADOW+1
  sta PLAYER_SHADOW+$21
  sta PLAYER_SHADOW+$41
  sta PLAYER_SHADOW+$61
  .repeat 4,i
    lda PLAYER+i*32,x
    sta PLAYER_SHADOW+i*32
  .endrepeat
  lda PLAYER+2,x
  clc
  adc #16
  sta PLAYER_SHADOW+2
  sta PLAYER_SHADOW+$42
  clc
  adc #16
  sta PLAYER_SHADOW+$22
  sta PLAYER_SHADOW+$62
  lda PLAYER+3,x
  sec
  sbc #18
  sta PLAYER_SHADOW+3
  sta PLAYER_SHADOW+$23
  sec
  sbc #16
  sta PLAYER_SHADOW+$43
  sta PLAYER_SHADOW+$63
  rts
