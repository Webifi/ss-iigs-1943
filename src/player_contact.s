; Own native port of US $570C-$5921. D selects the enemy; X the player.
; Common enemy retirement, score and death transitions remain caller actions.
; CONTACT_ACTION bits: 1 death transition, 2 retire, 4 award score.
.a8
.i16
CONTACT_ACTION = $17c4
CONTACT_SOUND = $17c5
CONTACT_PLAYER = $17c6
CONTACT_DELTA = $17c8

player_body_contact:
  phd
  rep #$20
.ifdef PLAYER_CONTACT_FAR
  lda POOL_RECORD
.else
  lda #ENEMY
.endif
  tcd
  sep #$20
  stz CONTACT_ACTION
  stz CONTACT_SOUND
  stz CONTACT_PLAYER
  jsr .loword(player_body_test)
  pld
.ifdef PLAYER_CONTACT_FAR
  rtl
.else
  rts
.endif

player_body_test:
  lda PLAYER+7,x
  bne @vertical
  lda $0a
  and #15
  bne @vertical
  rts
@vertical:
  lda PLAYER+3,x
  sec
  sbc $03
  bcs :+
  eor #255
  inc
:
  sta CONTACT_DELTA
  lda $0d
  clc
  adc PLAYER+$11,x
  cmp CONTACT_DELTA
  bcc @miss
  lda $02
  clc
  adc #8
  sec
  sbc PLAYER+$22,x
  bcs :+
  eor #255
  inc
:
  sta CONTACT_DELTA
  lda $0c
  clc
  adc PLAYER+$10,x
  cmp CONTACT_DELTA
  bcc @miss
  lda $0a
  and #15
  beq @body
  jmp .loword(player_pickup)
@miss:
  rts
@body:
  lda PLAYER+4,x
  and #1
  beq @damage
  lda PLAYER+4,x
  cmp #1
  bne @lose_wings
  lda #3
  bra @wings
@lose_wings:
  lda #8
@wings:
  sta PLAYER+4,x
  lda #1
  sta PLAYER+$0e,x
  bra @kill_enemy
@damage:
  lda $0b
  asl
  bcs @death
  asl
  bcs @death
  asl
  bcs @death
  sta CONTACT_DELTA
  lda PLAYER+6,x
  sec
  sbc CONTACT_DELTA
  sta PLAYER+6,x
  lda #1
  sta PLAYER+$0e,x
  bcc @death
  lda #6
  bra @sound
@death:
  stz PLAYER+6,x
  lda #4
  sta PLAYER+8,x
  lda #5
@sound:
  sta CONTACT_SOUND
  jsr .loword(player_contact_energy)
@kill_enemy:
  stz $0b
  lda PLAYER+5,x
  inc
  sta $0e
  sta CONTACT_PLAYER
  lda #1
  sta CONTACT_ACTION
  rts

player_pickup:
  sta CONTACT_DELTA
  lda PLAYER+8,x
  cmp #2
  beq :+
  rts
:
  lda CONTACT_DELTA
  cmp #1
  bne :+
  lda #8
  bra @energy_add
:
  cmp #3
  bne :+
  lda CONTACT_CONTEXT
  sta PLAYER+6,x
  bra @energy_hud
:
  cmp #4
  bne @wing
  lda #24
@energy_add:
  clc
  adc PLAYER+6,x
  cmp CONTACT_CONTEXT
  bcc :+
  lda CONTACT_CONTEXT
:
  sta PLAYER+6,x
@energy_hud:
  jsr .loword(player_contact_energy)
  jmp .loword(player_pickup_retire)
@wing:
  cmp #5
  bne @weapon
  lda PLAYER+4,x
  beq @wing_arrival
  cmp #3
  bne @retire
@wing_arrival:
  lda #2
  sta PLAYER+4,x
@retire:
  jmp .loword(player_pickup_retire)
@weapon:
  cmp #6
  bcc @bonus
  cmp #11
  bcs @bonus
  pha
  lda PLAYER+$57,x
  clc
  adc #20
  cmp #65
  bcc :+
  lda #64
:
  sta PLAYER+$57,x
  pla
  cmp #6
  bne @other_weapon
  lda PLAYER+$51,x
  cmp #3
  beq @retire
  cmp #2
  bne :+
  lda #3
  bra @weapon_set
:
  lda #2
  bra @weapon_set
@other_weapon:
  ; Types 7..10 select 3-WAY, SHELL, AUTO and LASER.
  phx
  rep #$20
  and #255
  tax
  sep #$20
  lda f:player_pickup_weapons-7,x
  plx
@weapon_set:
  sta PLAYER+$51,x
  bra @retire
@bonus:
  cmp #14
  bne @timed_bonus
  lda $10
  bne @score_retire
  lda #255
  sta $10
  rep #$20
  lda $1c
  sta $1e
  sep #$20
  stz $04
  lda #4
  sta $09
  sta CONTACT_ACTION
  bra @award
@timed_bonus:
  cmp #12
  bne @score_retire
  lda #64
  sta PLAYER+$57,x
@score_retire:
  lda #7
  sta CONTACT_SOUND
  lda #6
  sta CONTACT_ACTION
@award:
  lda PLAYER+5,x
  inc
  sta $0e
  sta CONTACT_PLAYER
  rts

player_pickup_retire:
  lda #7
  sta CONTACT_SOUND
  lda #2
  sta CONTACT_ACTION
  rts

player_contact_energy:
  ; The HUD helper uses the caller's direct page for scratch.
  phd
  rep #$20
  lda #0
  tcd
  sep #$20
.ifdef PLAYER_CONTACT_FAR
  jsl player_energy_hud_far
.else
  jsr energy_hud_update
.endif
  pld
  rts
player_pickup_weapons:
  .byte 4,8,1,16
