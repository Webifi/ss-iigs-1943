; The IIgs sends game state. It does no sprite lookup, clipping, restoration
; or HUD layout. Packet words are swapped only for the existing PEI sender.
.a16
.i16
; Code zero is transparent in the verified original art. Normalize its
; palette so the otherwise unused blank/color-15 word is a compound marker.
.macro state_code
.ifdef STATE_COMPOUNDS
  cmp #$0f00
  bne :+
  lda #0
:
.endif
  xba
.endmacro
flight_state_packet_far:
  rep #$30
  lda $6c
  xba
  sta a:$8002
  lda $6e
  xba
  sta a:$8004
.ifdef CONTINUOUS_GAME
  lda GAME_PICTURE
.else
  lda $68
.endif
  xba
  sta a:$8006
  .repeat 4,I
    lda PLAYER+$38+I*2
    xba
    sta a:$800a+I*2
    lda ENERGY_HUD+I*2
    xba
    sta a:$8012+I*2
  .endrepeat
 .if FLIGHT_PLAYER_AUX
  sep #$20
  lda PLAYER+$51
  sta a:$801b
  lda PLAYER+$57
  sta a:$801a
.ifdef CONTINUOUS_GAME
  lda GAME_FLOW
  beq :+
  clc
  adc #16
  sta a:$801b
  lda GAME_SECONDS
  sta a:$801a
:
.endif
  rep #$20
  ldx #$801c
 .else
  ldx #$801a
 .endif
  ldy #0
@enemies:
  lda ENEMY_POOL+8,y
  and #255
  beq @next_enemy
  lda ENEMY_POOL,y
  state_code
  sta a:$0000,x
  lda ENEMY_POOL+2,y
  xba
  sta a:$0002,x
  inx
  inx
  inx
  inx
@next_enemy:
  tya
  clc
  adc #32
  tay
  cpy #1024
  bne @enemies
.ifdef NATIVE_LARGE_OBJECTS
  ldy #0
@large_head:
  lda LARGE_POOL+8,y
  and #255
.ifdef GIANT_ENEMIES
  bne :+
  jmp @large_next
:
  cmp #$40
  beq :+
  jmp @four_piece
:
  .repeat 16,I
   .ifdef STATE_COMPOUNDS
    .if (I .mod 4)=0
      lda #$000f
      sta a:0,x
      lda #$0400
      sta a:2,x
      inx
      inx
      inx
      inx
    .endif
   .endif
    lda LARGE_POOL-128+I*32,y
    state_code
    sta a:$0000,x
    lda LARGE_POOL-126+I*32,y
    xba
    sta a:$0002,x
    inx
    inx
    inx
    inx
  .endrepeat
  tya
  clc
  adc #256
  tay
  jmp @large_next
@four_piece:
.else
  bne :+
  jmp @large_next
:
.endif
.ifdef STATE_COMPOUNDS
  lda #$000f                 ; blank code / reserved palette, then four pieces
  sta a:$0000,x
  lda #$0400
  sta a:$0002,x
  inx
  inx
  inx
  inx
.endif
  .repeat 4,I
    lda LARGE_POOL+I*32,y
    state_code
    sta a:$0000,x
    lda LARGE_POOL+I*32+2,y
    xba
    sta a:$0002,x
    inx
    inx
    inx
    inx
  .endrepeat
@large_next:
  tya
  clc
  adc #128
  tay
  cpy #1536
.ifdef GIANT_ENEMIES
  beq :+
  jmp @large_head
:
.else
  beq :+
  jmp @large_head
:
.endif
.endif
 .ifdef EXTENDED_STAGE_ENEMIES
  ldy #0
@extended:
  lda EXTENDED_POOL+8,y
  and #255
  beq @extended_next
  lda EXTENDED_POOL,y
  state_code
  sta a:0,x
  lda EXTENDED_POOL+2,y
  xba
  sta a:2,x
  inx
  inx
  inx
  inx
@extended_next:
  tya
  clc
  adc #32
  tay
  cpy #17*32
  bne @extended
 .endif
  ; Active players use two pieces; death uses four; inactive players vanish.
.if FLIGHT_DEATH
  ldy #0
@player_head:
  lda PLAYER+8,y
  and #255
  beq @player_next
  tya
  clc
  adc #128
  sta $b6
@player_piece:
  lda PLAYER,y
  state_code
  sta a:0,x
  lda PLAYER+2,y
  xba
  sta a:2,x
  inx
  inx
  inx
  inx
  tya
  clc
  adc #32
  tay
  cpy $b6
  bne @player_piece
  bra @player_check
@player_next:
  tya
  clc
  adc #128
  tay
@player_check:
  cpy #256
  bcc @player_head
@players_done:
.else
  ; The two native player pieces precede the player's projectiles.
  lda PLAYER
  and #255
  xba
  sta a:$0000,x
  lda PLAYER+$20
  and #255
  xba
  sta a:$0004,x
  lda PLAYER+2
  xba
  sta a:$0002,x
  lda PLAYER+2
  clc
  adc #16
  xba
  sta a:$0006,x
  txa
  clc
  adc #8
  tax
.endif
.ifdef CONTINUOUS_GAME
  jsl native_dive_append
.endif
  ldy #0
@shots:
  lda SHOTS+8,y
  and #255
  beq @next_shot
  lda SHOTS,y
  and #$0fff
  state_code
  sta a:$0000,x
  lda SHOTS+2,y
  xba
  sta a:$0002,x
  inx
  inx
  inx
  inx
@next_shot:
  tya
  clc
  adc #32
  tay
  cpy #18*32
  bne @shots
  txa
  sec
 .if FLIGHT_PLAYER_AUX
  sbc #$801c
 .else
  sbc #$801a
 .endif
  lsr
  lsr
  xba
  sta a:$8008
.ifdef CONTINUOUS_GAME
  jsl game_world_append
.endif
.ifdef FLIGHT_QUIET_ART
  jsl quiet_packet_append
.endif
  txa
  sec
  sbc #$8002
  sta $28
  xba
  sta a:$8000
  sep #$20
  rtl
