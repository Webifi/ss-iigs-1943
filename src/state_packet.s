; The update packet (src/packet.inc): the game state that the card draws.
; The host makes no sprite lookup, clipping or HUD layout. Each word goes
; high byte first (XBA) for the PEI sender.
.a16
.i16

; flight_state_packet_far: write the packet of this update: the cameras,
; the picture, the P1 score, energy and weapon (or the cabinet page and the
; seconds), the object records of the enemies, bullets, large objects,
; extended objects, players, dives and shots, then the world trailer
; (game_world_append). JSL; returns A8, X16.
flight_state_packet_far:
  ax16
  lda SEA_CAMERA
  xba
  sta a:PACKET_SEA
  lda FG_CAMERA
  xba
  sta a:PACKET_FOREGROUND
  lda GAME_PICTURE
  xba
  sta a:PACKET_PICTURE
  .repeat (PACKET_ENERGY-PACKET_SCORE)/2,I
    lda PLAYER+PL_SCORE+I*2
    xba
    sta a:PACKET_SCORE+I*2
    lda ENERGY_HUD+I*2
    xba
    sta a:PACKET_ENERGY+I*2
  .endrepeat
  a8
  lda PLAYER+PL_WEAPON
  sta a:PACKET_WEAPON
  lda PLAYER+PL_WEAPON_TIME
  sta a:PACKET_TIME
  lda GAME_FLOW
  beq :+
  clc
  adc #PACKET_PAGE_WEAPON
  sta a:PACKET_WEAPON
  lda GAME_SECONDS
  sta a:PACKET_TIME
:
  ; X = the next object record; each takes PACKET_RECORD bytes.
  a16
  ldx #.loword(PACKET_OBJECTS)
  ldy #0
@enemies:
  lda ENEMY_POOL+OBJ_TYPE,y
  and #255
  beq @next_enemy
  lda ENEMY_POOL+SPR_CODE,y
  xba
  sta a:PACKET_CODE,x
  lda ENEMY_POOL+SPR_CROSS,y
  xba
  sta a:PACKET_POSITION,x
  inx
  inx
  inx
  inx
@next_enemy:
  tya
  clc
  adc #OBJECT_SIZE
  tay
  cpy #(ENEMY_COUNT+BULLET_COUNT)*OBJECT_SIZE ; BULLETS follows ENEMY_POOL
  bne @enemies
  ldy #0
@large_head:
  lda LARGE_POOL+OBJ_TYPE,y
  and #255
  bne :+
  jmp @large_next
:
  cmp #OT_GIANT
  beq :+
  jmp @four_piece
:
  .repeat GIANT_ROWS*GIANT_COLUMNS,I
    lda LARGE_POOL-GIANT_HEAD+I*SPRITE_SIZE+SPR_CODE,y
    xba
    sta a:PACKET_CODE,x
    lda LARGE_POOL-GIANT_HEAD+I*SPRITE_SIZE+SPR_CROSS,y
    xba
    sta a:PACKET_POSITION,x
    inx
    inx
    inx
    inx
  .endrepeat
  tya
  clc
  adc #2*LARGE_SIZE             ; past the giant's slots 2 and 3 (slot 0 has no type)
  tay
  jmp @large_next
@four_piece:
  .repeat 4,I
    lda LARGE_POOL+I*SPRITE_SIZE+SPR_CODE,y
    xba
    sta a:PACKET_CODE,x
    lda LARGE_POOL+I*SPRITE_SIZE+SPR_CROSS,y
    xba
    sta a:PACKET_POSITION,x
    inx
    inx
    inx
    inx
  .endrepeat
@large_next:
  tya
  clc
  adc #LARGE_SIZE
  tay
  cpy #LARGE_COUNT*LARGE_SIZE
  beq :+
  jmp @large_head
:
  ldy #0
@extended:
  lda EXTENDED_POOL+OBJ_TYPE,y
  and #255
  beq @extended_next
  lda EXTENDED_POOL+SPR_CODE,y
  xba
  sta a:PACKET_CODE,x
  lda EXTENDED_POOL+SPR_CROSS,y
  xba
  sta a:PACKET_POSITION,x
  inx
  inx
  inx
  inx
@extended_next:
  tya
  clc
  adc #OBJECT_SIZE
  tay
  cpy #EXTENDED_COUNT*OBJECT_SIZE
  bne @extended
  ; The four pieces of each player in the game.
  ldy #0
@player_head:
  lda PLAYER+PL_STATE,y
  and #255
  beq @player_next
  tya
  clc
  adc #PLAYER_SIZE
  sta PLAYER_END
@player_piece:
  lda PLAYER+SPR_CODE,y
  xba
  sta a:PACKET_CODE,x
  lda PLAYER+SPR_CROSS,y
  xba
  sta a:PACKET_POSITION,x
  inx
  inx
  inx
  inx
  tya
  clc
  adc #SPRITE_SIZE
  tay
  cpy PLAYER_END
  bne @player_piece
  bra @player_check
@player_next:
  tya
  clc
  adc #PLAYER_SIZE
  tay
@player_check:
  cpy #2*PLAYER_SIZE
  bcc @player_head
@players_done:
  jsl native_dive_append
  ldy #0
@shots:
  lda SHOTS+SHOT_STATE,y
  and #255
  beq @next_shot
  lda SHOTS+SPR_CODE,y
  and #$0fff                    ; and SPR_ATTR without bits 4-7
  xba
  sta a:PACKET_CODE,x
  lda SHOTS+SPR_CROSS,y
  xba
  sta a:PACKET_POSITION,x
  inx
  inx
  inx
  inx
@next_shot:
  tya
  clc
  adc #SHOT_SIZE
  tay
  cpy #SHOT_COUNT*SHOT_SIZE
  bne @shots
  txa
  sec
  sbc #.loword(PACKET_OBJECTS)
  lsr
  lsr                           ; / PACKET_RECORD
  xba
  sta a:PACKET_OBJECTS_COUNT
  jsl game_world_append
  txa
  sec
  sbc #.loword(PACKET_SEA)
  sta PACKET_LENGTH
  xba
  sta a:PACKET_SIZE
  a8
  rtl
.assert PACKET_RECORD = 4 .and PACKET_ENERGY-PACKET_SCORE = 8, error
