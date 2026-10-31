; Pool callbacks for moving bosses and their visible damage columns.
; D is the current live record; bank-zero scratch is always absolute.
.a8
.i16
airboss_enemy_ai:
  rep #$20
  lda AI_CONTEXT+2
  cmp #$5b18
  beq @burst_one
  cmp #$5b60
  bne @bank
  lda #$5b25
  bra @burst
@burst_one:
  lda #$5add
@burst:
  sta AI_NEXT
  sep #$20
  lda STAGE_FLAGS+$12
  beq :+
  jmp .loword(air_enemy_retire)
:
  sec
  rtl
@bank:
.a16
  rep #$20
  lda z:$0a
  and #$70
  beq @zero
  cmp #$40
  bne @unknown
  lda AI_CONTEXT+2
  cmp #$81e6
  bne :+
  jmp .loword(air_piece_tick)
:
  cmp #$82c6
  bne :+
  lda #$82e6
  bra @piece_path
:
  cmp #$82cc
  bne :+
  lda #$82fe
  bra @piece_path
:
  cmp #$82d2
  bne @unknown
  lda #$8316
@piece_path:
  sta AI_NEXT
  sep #$20
  lda AIR_BOSS
  beq air_enemy_retire
  lda AIR_LIFE
  beq air_enemy_retire
  sec
  rtl
@zero:
.a16
  lda AI_CONTEXT+2
  cmp #$aa94
  bne :+
  jmp .loword(air_core_tick)
:
  cmp #$ab09
  bne :+
  jmp .loword(air_core_hit)
:
  cmp #$bcb5
  bne @unknown
  jmp .loword(air_gun_tick)
@unknown:
  sep #$20
  clc
  rtl
air_enemy_retire:
.a8
  stz z:$00
  stz z:$02
  stz z:$08
  sec
  rtl
air_enemy_path:
.a16
  sta AI_NEXT
  sep #$20
  sec
  rtl

air_core_tick:
.a16
  sep #$20
  lda AIR_SECONDS
  cmp #51
  bcc @alive
  lda #3
  sta AIR_RESULT
  lda AIR_BOSS
  clc
  adc #2
  sec
  sbc z:$10
  rep #$20
  and #255
  sta a:$d4
  asl
  asl
  adc a:$d4
  asl
  sep #$20
  sta AIR_PERCENT
  jmp .loword(air_enemy_retire)
@alive:
.a8
  lda z:$11
  and #1
  beq @timer
  lda z:$0c
  cmp #$50
  bne @wide
  lda #$10
  sta z:$0c
  lda #$40
  sta z:$0d
  lda z:$03
  sec
  sbc #16
  bra @y
@wide:
  lda #$50
  sta z:$0c
  lda #$10
  sta z:$0d
  lda z:$03
  clc
  adc #16
@y:
  sta z:$03
@timer:
  lda z:$11
  beq @fan
  dec z:$11
  bra @side
@fan:
  lda #200
  sta z:$11
  jsl FORMATION_TARGET
  cmp #13
  bcs :+
  lda #13
:
  cmp #20
  bcc :+
  lda #19
:
  sta z:$13
  stz AIR_TEMP2
@fan_shot:
  rep #$20
  lda AIR_TEMP2
  and #255
  tax
  sep #$20
  lda f:air_fan_offsets,x
  clc
  adc z:$13
  and #31
  sta MEDIUM_SHOT_ANGLE
  lda z:$02
  sta LARGE_AI_X
  lda z:$03
  sec
  sbc #$58
  sta LARGE_AI_Y
  jsr .loword(air_enemy_shot)
  inc AIR_TEMP2
  lda AIR_TEMP2
  cmp #5
  bne @fan_shot
@side:
  lda z:$12
  beq @side_ready
  dec z:$12
  bra @select
@side_ready:
  lda z:$0c
  cmp #$50
  beq @select
  jsl FORMATION_TARGET
  cmp #23
  bcs @select
  cmp #18
  bcs @left
  cmp #10
  bcc @select
  cmp #15
  bcs @select
  sta MEDIUM_SHOT_ANGLE
  lda z:$02
  clc
  adc #8
  bra @side_position
@left:
  sta MEDIUM_SHOT_ANGLE
  lda z:$02
  sec
  sbc #8
@side_position:
  sta LARGE_AI_X
  lda z:$03
  sta LARGE_AI_Y
  jsr .loword(air_enemy_shot)
  lda #60
  sta z:$12
@select:
  rep #$20
  lda #$aba2
  jmp .loword(air_enemy_path)

air_core_hit:
.a16
  sep #$20
  dec z:$10
  lda z:$10
  sta AIR_LIFE
  beq @destroyed
  lda #$40
  sta z:$0b
  lda #7
  sta z:$09
  rep #$20
  lda #$aba2
  jmp .loword(air_enemy_path)
@destroyed:
.a8
  lda #$08
  jsr .loword(air_sound)
  lda #$1c
  jsr .loword(air_sound)
  lda z:$0e
  cmp #1
  beq @player_one
  lda #$c0
  bra @owner
@player_one:
  lda #$80
@owner:
  ora AIR_BOSS
  sta AIR_BOSS
  lda z:$0c
  cmp #$50
  beq :+
  lda z:$03
  clc
  adc #16
  sta z:$03
:
  lda #8
  sta STAGE_FLAGS+$1c
  rep #$20
  lda POOL_RECORD
  sta STAGE_FLAGS+$1d
  sep #$20
  phd
  pea $0000
  pld
  lda #2
  jsl ship_finish_begin
  pld
  stz AIR_RESULT
  lda #100
  sta AIR_PERCENT
  lda AIR_SECONDS
@percent:
  sec
  sbc #11
  bcc @percent_done
  pha
  lda AIR_PERCENT
  sec
  sbc #10
  sta AIR_PERCENT
  pla
  bra @percent
@percent_done:
  lda #4
  sta z:$09
  rep #$20
  lda #$abaf
  jmp .loword(air_enemy_path)

air_piece_tick:
.a16
  sep #$20
  lda AIR_LIFE
  cmp z:$11
  beq @destroy
  rep #$20
  lda #$8206
  jmp .loword(air_enemy_path)
@destroy:
.a8
  stz AIR_TEMP
@part:
  phd
  pea $0000
  pld
  jsr .loword(extended_allocate)
  pld
  bcs :+
  jmp .loword(@retire)
:
  stx AIR_CORE
  rep #$20
  lda AIR_TEMP
  and #255
  asl
  asl
  asl
  asl
  asl
  txy
  tax
  .repeat 16
    lda f:air_piece_templates,x
    sta a:0,y
    inx
    inx
    iny
    iny
  .endrepeat
  ldx AIR_CORE
  sep #$20
  lda z:$02
  sta a:2,x
  lda AIR_TEMP
  asl
  asl
  asl
  asl
  clc
  adc #10
  sta a:$d4
  lda z:$03
  sec
  sbc a:$d4
  sta a:3,x
  inc AIR_TEMP
  lda AIR_TEMP
  cmp #3
  beq @retire
  jmp .loword(@part)
@retire:
  lda #$1a
  sta AI_SOUND
  jmp .loword(air_enemy_retire)

air_gun_tick:
.a16
  sep #$20
  lda AIR_BOSS
  bpl @alive
  and #$40
  beq :+
  lda #2
:
  sta z:$0e
  rep #$20
  lda #$5a3b
  jmp .loword(air_enemy_path)
@alive:
.a8
  lda z:$11
  inc
  cmp #30
  bcc :+
  lda #0
:
  sta z:$11
  jsl FORMATION_TARGET
  sec
  sbc z:$10
  and #31
  beq @aligned
  cmp #1
  beq @aligned
  cmp #31
  beq @aligned
  cmp #16
  bcc @increase
  lda z:$10
  sec
  sbc #2
  bra @angle
@increase:
  lda z:$10
  clc
  adc #2
@angle:
  and #31
  sta z:$10
  bra @select
@aligned:
  lda z:$11
  bne @select
  stz AIR_TEMP2
@shot:
  lda z:$10
  ldx AIR_TEMP2
  cpx #0
  beq @heading
  cpx #1
  bne @minus
  inc
  bra @heading
@minus:
  dec
@heading:
  and #31
  sta MEDIUM_SHOT_ANGLE
  rep #$20
  lda z:$10
  and #31
  tax
  sep #$20
  lda f:turret_muzzles,x
  clc
  adc z:$02
  sta LARGE_AI_X
  lda f:turret_muzzles+1,x
  clc
  adc z:$03
  sta LARGE_AI_Y
  jsr .loword(air_enemy_shot)
  inc AIR_TEMP2
  lda AIR_TEMP2
  cmp #3
  bne @shot
@select:
  rep #$20
  lda z:$10
  and #31
  tax
  lda f:air_gun_paths,x
  jmp .loword(air_enemy_path)

air_enemy_shot:
.a8
  phd
  pea $0000
  pld
  jsl airboss_shot_far
  pld
  rts
air_sound:
.a8
  phd
  pea $0000
  pld
  jsl game_sound_request
  pld
  rts
