; Body contact of a player with one small object: damage, wing loss, or the
; collection of a pickup. A native port of the US arcade code at $570C-$5921.
; The caller does the object's retirement, the score and the death of the
; player from the results: CONTACT_ACTION (CONTACT_* bits) and CONTACT_SOUND
; (a sound command, 0 none); OBJ_OWNER gets the player (1 or 2).
.a8
.i16
BONUS_MARKER = $10           ; PV_MARKER object byte: the first contact sets it
HIT_ROLL = 1                 ; PL_HIT: start the hit roll
MARKER_SET = $ff             ; BONUS_MARKER after the first contact

; player_body_contact: test the object in POOL_RECORD against the player X
; (0 or PLAYER_SIZE). JSL; D is kept.
player_body_contact:
  phd
  a16
  lda POOL_RECORD
  tcd
  a8
  stz CONTACT_ACTION
  stz CONTACT_SOUND
  jsr .loword(player_body_test)
  pld
  rtl

; player_body_test: D = the object. A player that cannot collide (PL_COLLIDE
; 0) still collects pickups.
player_body_test:
  lda PLAYER+PL_COLLIDE,x
  bne @vertical
  lda OBJ_VARIANT
  and #VARIANT_BITS
  bne @vertical
  rts
  ; The overlap test: along, then cross (the object centre against the
  ; right half of the player), each against the sum of the two radii.
@vertical:
  lda PLAYER+SPR_ALONG,x
  sec
  sbc SPR_ALONG
  bcs :+
  eor #255                      ; the absolute distance
  inc
:
  sta CONTACT_DELTA
  lda OBJ_ALONG_RADIUS
  clc
  adc PLAYER+PL_ALONG_RADIUS,x
  cmp CONTACT_DELTA
  bcc @miss
  lda SPR_CROSS
  clc
  adc #SPRITE_HALF              ; the centre of the object
  sec
  sbc PLAYER+PL_BODY2+SPR_CROSS,x
  bcs :+
  eor #255
  inc
:
  sta CONTACT_DELTA
  lda OBJ_CROSS_RADIUS
  clc
  adc PLAYER+PL_CROSS_RADIUS,x
  cmp CONTACT_DELTA
  bcc @miss
  lda OBJ_VARIANT
  and #VARIANT_BITS
  beq @body                     ; PV_ENEMY
  jmp .loword(player_pickup)
@miss:
  rts
  ; An enemy hit the player. Wing planes take the hit first: attached wings
  ; become damaged, damaged wings explode.
@body:
  lda PLAYER+PL_WINGS,x
  and #WINGS_ON
  beq @damage
  lda PLAYER+PL_WINGS,x
  cmp #WINGS_ON
  bne @lose_wings
  lda #WINGS_DAMAGED
  bra @wings
@lose_wings:
  lda #WINGS_EXPLODE
@wings:
  sta PLAYER+PL_WINGS,x
  lda #HIT_ROLL
  sta PLAYER+PL_HIT,x
  bra @kill_enemy
  ; No wings: the player loses OBJ_HP times 8 energy; 256 or more kills.
@damage:
  lda OBJ_HP
  asl
  bcs @death
  asl
  bcs @death
  asl
  bcs @death
  sta CONTACT_DELTA
  lda PLAYER+PL_ENERGY,x
  sec
  sbc CONTACT_DELTA
  sta PLAYER+PL_ENERGY,x
  lda #HIT_ROLL
  sta PLAYER+PL_HIT,x
  bcc @death                    ; the energy went below 0
  lda #SND_PLAYER_HIT
  bra @sound
@death:
  stz PLAYER+PL_ENERGY,x
  lda #PS_DEATH
  sta PLAYER+PL_STATE,x
  lda #SND_PLAYER_DOWN
@sound:
  sta CONTACT_SOUND
  jsr .loword(player_contact_energy)
  ; The enemy dies too; the player gets its score.
@kill_enemy:
  stz OBJ_HP
  lda PLAYER+PL_NUMBER,x
  inc
  sta OBJ_OWNER
  lda #CONTACT_KILL
  sta CONTACT_ACTION
  rts

; player_pickup: A = the contact variant (PV_*). Only a live player
; (PS_LIVE) collects.
player_pickup:
  sta CONTACT_DELTA
  lda PLAYER+PL_STATE,x
  cmp #PS_LIVE
  beq :+
  rts
:
  lda CONTACT_DELTA
  cmp #PV_ENERGY
  bne :+
  lda #ENERGY_PICKUP
  bra @energy_add
:
  cmp #PV_ENERGY_FULL
  bne :+
  lda ENERGY_MAX
  sta PLAYER+PL_ENERGY,x
  bra @energy_hud
:
  cmp #PV_ENERGY_BIG
  bne @wing
  lda #ENERGY_PICKUP_BIG
@energy_add:
  clc
  adc PLAYER+PL_ENERGY,x
  cmp ENERGY_MAX
  bcc :+
  lda ENERGY_MAX
:
  sta PLAYER+PL_ENERGY,x
@energy_hud:
  jsr .loword(player_contact_energy)
  jmp .loword(player_pickup_retire)
  ; Wing planes come when the player has none, or damaged ones.
@wing:
  cmp #PV_WINGS
  bne @weapon
  lda PLAYER+PL_WINGS,x
  beq @wing_arrival
  cmp #WINGS_DAMAGED
  bne @retire
@wing_arrival:
  lda #WINGS_COMING
  sta PLAYER+PL_WINGS,x
@retire:
  jmp .loword(player_pickup_retire)
  ; A weapon: WEAPON_PICKUP_TIME more weapon time, at most WEAPON_TIME_MAX.
@weapon:
  cmp #PV_SHOTGUN
  bcc @bonus
  cmp #PV_LASER+1
  bcs @bonus
  pha
  lda PLAYER+PL_WEAPON_TIME,x
  clc
  adc #WEAPON_PICKUP_TIME
  cmp #WEAPON_TIME_MAX+1
  bcc :+
  lda #WEAPON_TIME_MAX
:
  sta PLAYER+PL_WEAPON_TIME,x
  pla
  cmp #PV_SHOTGUN
  bne @other_weapon
  ; SHOT GUN: a second one upgrades it; the upgraded one stays.
  lda PLAYER+PL_WEAPON,x
  cmp #WEAPON_SHOTGUN_UP
  beq @retire
  cmp #WEAPON_SHOTGUN
  bne :+
  lda #WEAPON_SHOTGUN_UP
  bra @weapon_set
:
  lda #WEAPON_SHOTGUN
  bra @weapon_set
@other_weapon:
  phx
  a16
  and #255
  tax
  a8
  lda f:player_pickup_weapons-PV_3WAY,x
  plx
@weapon_set:
  sta PLAYER+PL_WEAPON,x
  bra @retire
  ; The score pickups. PV_MARKER: the first contact sets BONUS_MARKER, starts
  ; the object's transform script (OBJ_PREDECESSOR) and gives the score; the
  ; object stays. A later contact collects it as a score pickup.
@bonus:
  cmp #PV_MARKER
  bne @timed_bonus
  lda BONUS_MARKER
  bne @score_retire
  lda #MARKER_SET
  sta BONUS_MARKER
  a16
  lda OBJ_PREDECESSOR
  sta OBJ_MOTION
  a8
  stz OBJ_DURATION
  lda #OF_CAMERA                ; = CONTACT_SCORE: the object follows the camera
  sta OBJ_FLAGS
  sta CONTACT_ACTION
  bra @award
@timed_bonus:
  cmp #PV_TIME
  bne @score_retire
  lda #WEAPON_TIME_MAX
  sta PLAYER+PL_WEAPON_TIME,x
@score_retire:
  lda #SND_PICKUP
  sta CONTACT_SOUND
  lda #CONTACT_RETIRE|CONTACT_SCORE
  sta CONTACT_ACTION
@award:
  lda PLAYER+PL_NUMBER,x
  inc
  sta OBJ_OWNER
  rts
.assert OF_CAMERA = CONTACT_SCORE, error

; player_pickup_retire: the pickup goes, with the pickup sound.
player_pickup_retire:
  lda #SND_PICKUP
  sta CONTACT_SOUND
  lda #CONTACT_RETIRE
  sta CONTACT_ACTION
  rts

; player_contact_energy: redraw the energy gauge of player X. The gauge code
; uses page-zero scratch, so D = 0 during the call.
player_contact_energy:
  phd
  a16
  lda #ZERO_PAGE
  tcd
  a8
  jsl player_energy_hud_far
  pld
  rts
; The weapons of pickups PV_3WAY to PV_LASER.
player_pickup_weapons:
  .byte WEAPON_3WAY,WEAPON_SHELL,WEAPON_AUTO,WEAPON_LASER
