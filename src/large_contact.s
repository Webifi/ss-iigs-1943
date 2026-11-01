; The contacts of a large object (four sprite records) with the player shots
; and with the players. A native port of the US arcade code at $5CC4-$5E29.
; D = the object during each test. The results go to the game loop as
; CONTACT_ACTION (CONTACT_* bits) and CONTACT_SOUND; OBJ_OWNER gets the player.
; The centre of a giant is its record 2; of other large objects, record 1's
; cross and record 0's along (large_contact_center).
.a8
.i16

; large_shot_contact: the player shots against the object at LARGE_RECORD.
; JSL; A, X, Y: changed.
large_shot_contact:
  phd
  a16
  lda LARGE_RECORD
  tcd
  a8
  stz CONTACT_ACTION
  stz CONTACT_SOUND
  jsr .loword(large_contact_center)
  jsr .loword(large_shot_test)
  pld
  rtl

; large_shot_test: only an object that shots can hit (OF_SHOT) and that is
; on the field. Ordinary objects test the live shots that the wave pass
; listed (SHOT_ACTIVE); giants run on another phase and test every shot
; record of the live players in order.
large_shot_test:
  lda OBJ_FLAGS
  and #OF_SHOT
  beq @done
  lda OBJ_TYPE
  cmp #OT_GIANT
  beq :+
  ldy SHOT_ACTIVE_END
  bne :+
  sty CONTACT_LIMIT             ; no live shot this tick
  rts
:
  lda SPR_ATTR
  ora 2*SPRITE_SIZE+SPR_ATTR
  and #SPR_ALONG_HIGH
  bne @done
  ; X..Y = the shot records of the live players.
  ldx #0
  ldy #SHOTS_PER_PLAYER*SHOT_SIZE
  lda PLAYER+PL_STATE
  cmp #PS_LIVE
  beq @p1
  lda PLAYER2+PL_STATE
  cmp #PS_LIVE
  beq @p2
@done:
  rts
@p2:
  ldx #SHOTS_PER_PLAYER*SHOT_SIZE
  ldy #SHOT_COUNT*SHOT_SIZE
  bra @start
@p1:
  lda PLAYER2+PL_STATE
  cmp #PS_LIVE
  bne @start
  ldy #SHOT_COUNT*SHOT_SIZE
@start:
  ; Choose the shot list or the record scan once. CONTACT_NEXT holds the
  ; step routine; CONTACT_ADJUST is SPRITE_HALF for listed shots (their
  ; centres), 0 for the scan. D stays on the object.
  jsl large_list_prepare
  bcc @linear_start
  cpy CONTACT_LIMIT
  beq @done
  jsl large_shot_y_cull
  bcs @done                     ; no listed shot can reach the object
  a16
  lda #.loword(@list_next)
  sta a:CONTACT_NEXT
  a8
  lda #SPRITE_HALF
  sta a:CONTACT_ADJUST
  ldx SHOT_ACTIVE,y
  bra @slot
@linear_start:
  sty CONTACT_LIMIT
  a16
  lda #.loword(@linear_next)
  sta a:CONTACT_NEXT
  a8
  stz a:CONTACT_ADJUST
  bra @slot
@next:
  jmp (CONTACT_NEXT)
@list_next:
  iny
  iny
  cpy CONTACT_LIMIT
  beq @done
  ldx SHOT_ACTIVE,y
  bra @slot
@linear_next:
  a16
  txa
  clc
  adc #SHOT_SIZE
  tax
  a8
  cpx CONTACT_LIMIT
  beq @done
  bra @slot
  ; The shot at SHOTS+X: a flying shot that overlaps the object on both axes.
  ; The arcade adds the 8 before the byte subtraction; adding it to the
  ; centre instead would change the borrow where the coordinates wrap.
@slot:
  lda SHOTS+SHOT_STATE,x
  cmp #SHOT_FLYING
  bne @next
  lda SHOTS+SPR_ALONG,x
  clc
  adc a:CONTACT_ADJUST
  sec
  sbc CONTACT_CENTER_Y
  bcs :+
  eor #255                      ; the absolute distance
  inc
:
  sta CONTACT_DELTA
  lda OBJ_ALONG_RADIUS
  clc
  adc SHOTS+SHOT_ALONG_RADIUS,x
  cmp CONTACT_DELTA
  bcc @next
  lda SHOTS+SPR_CROSS,x
  clc
  adc a:CONTACT_ADJUST
  sec
  sbc CONTACT_CENTER_X
  bcs :+
  eor #255
  inc
:
  sta CONTACT_DELTA
  lda OBJ_CROSS_RADIUS
  clc
  adc SHOTS+SHOT_CROSS_RADIUS,x
  cmp CONTACT_DELTA
  bcc @next
  ; A hit. The shot's damage takes HP: more HP than damage leaves the object
  ; alive; equal kills it and ends the shot; more damage kills it and the
  ; shot goes on with the damage left.
  lda OBJ_HP
  cmp SHOTS+SHOT_DAMAGE,x
  bcc @penetrate
  beq @equal
  sec
  sbc SHOTS+SHOT_DAMAGE,x
  sta OBJ_HP
  lda #SHOT_IMPACT
  sta SHOTS+SHOT_STATE,x
  lda #SND_ENEMY_HIT
  sta CONTACT_SOUND
  rts
@equal:
  lda #SHOT_IMPACT
  sta SHOTS+SHOT_STATE,x
  bra @kill
@penetrate:
  lda SHOTS+SHOT_DAMAGE,x
  sec
  sbc OBJ_HP
  sta SHOTS+SHOT_DAMAGE,x
@kill:
  stz OBJ_HP
  lda OBJ_TYPE
  cmp #OT_GIANT
  bne @ordinary_sound
  lda #SND_GIANT_KILL
  bra @sound_ready
@ordinary_sound:
  lda #SND_BULLET_HIT
@sound_ready:
  sta CONTACT_SOUND
  lda SHOTS+SHOT_OWNER,x
  inc
  sta OBJ_OWNER
  lda #CONTACT_KILL
  sta CONTACT_ACTION
  rts

; large_body_contact: the player X (0 or PLAYER_SIZE) against the object at
; LARGE_RECORD. JSL; A, Y: changed.
large_body_contact:
  phd
  a16
  lda LARGE_RECORD
  tcd
  a8
  stz CONTACT_ACTION
  stz CONTACT_SOUND
  jsr .loword(large_contact_center)
  jsr .loword(large_body_test)
  pld
  rtl
; large_body_test: the overlap of the player's centre with the object; the
; wings take the hit first, as in player_body_test.
large_body_test:
  lda PLAYER+PL_COLLIDE,x
  beq @miss
  lda PLAYER+SPR_ALONG,x
  clc
  adc #SPRITE_HALF
  sec
  sbc CONTACT_CENTER_Y
  bcs :+
  eor #255
  inc
:
  sta CONTACT_DELTA
  lda OBJ_ALONG_RADIUS
  clc
  adc PLAYER+PL_ALONG_RADIUS,x
  cmp CONTACT_DELTA
  bcc @miss
  lda CONTACT_CENTER_X
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
  bra @kill
@miss:
  rts
@damage:
  ; The damage is HP times 8 by three arcade RLCA steps: they rotate, not
  ; saturate. Only the third carry kills at once; the first two wrap.
  lda OBJ_HP
  asl
  bcc :+
  inc
:
  asl
  bcc :+
  inc
:
  asl
  bcs @death
  sta CONTACT_DELTA
  lda PLAYER+PL_ENERGY,x
  sec
  sbc CONTACT_DELTA
  sta PLAYER+PL_ENERGY,x
  lda #HIT_ROLL
  sta PLAYER+PL_HIT,x
  bcc @death
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
@kill:
  stz OBJ_HP
  lda PLAYER+PL_NUMBER,x
  inc
  sta OBJ_OWNER
  lda #CONTACT_KILL
  sta CONTACT_ACTION
  rts

; large_contact_center: CONTACT_CENTER_X/Y of the object (see the top).
large_contact_center:
  lda OBJ_TYPE
  cmp #OT_GIANT
  beq @giant
  lda SPRITE_SIZE+SPR_CROSS
  sta CONTACT_CENTER_X
  lda SPR_ALONG
  sta CONTACT_CENTER_Y
  rts
@giant:
  lda 2*SPRITE_SIZE+SPR_CROSS
  sta CONTACT_CENTER_X
  lda 2*SPRITE_SIZE+SPR_ALONG
  sta CONTACT_CENTER_Y
  rts

.pushseg
.segment "NATIVE"
; large_shot_y_cull: can a listed shot reach the object? The wave pass keeps
; the bounds of the listed shots (SHOT_X_MIN..SHOT_Y_MAX). Returns carry 1
; only when the object's range and the shot bounds are surely apart on an
; axis; when a value could wrap with the SPRITE_HALF offsets, it returns
; carry 0 and the shots are tested one by one. D = the object. JSL.
large_shot_y_cull:
  lda SHOT_Y_MAX
  cmp #256-SPRITE_HALF
  bcs @maybe
  lda CONTACT_CENTER_Y
  sec
  sbc #SPRITE_HALF
  bcc @maybe
  clc
  adc OBJ_ALONG_RADIUS
  bcs @maybe
  cmp SHOT_Y_MIN
  bcc @disjoint
  lda CONTACT_CENTER_Y
  sec
  sbc #SPRITE_HALF
  sec
  sbc OBJ_ALONG_RADIUS
  bcc @maybe
  cmp SHOT_Y_MAX
  bcc @maybe
  beq @maybe
@disjoint:
  sec
  rtl
@maybe:
  lda SHOT_X_MAX
  cmp #256-SPRITE_HALF
  bcs @overlap
  lda CONTACT_CENTER_X
  sec
  sbc #SPRITE_HALF
  bcc @overlap
  clc
  adc OBJ_CROSS_RADIUS
  bcs @overlap
  cmp SHOT_X_MIN
  bcc @disjoint
  lda CONTACT_CENTER_X
  sec
  sbc #SPRITE_HALF
  sec
  sbc OBJ_CROSS_RADIUS
  bcc @overlap
  cmp SHOT_X_MAX
  bcc @overlap
  beq @overlap
  bra @disjoint
@overlap:
  clc
  rtl

; large_list_prepare: in X..Y the shot records of the live players. For an
; ordinary object returns carry 1, Y = the first SHOT_ACTIVE entry and
; CONTACT_LIMIT = the end entry of those players (P1's entries come first,
; P2's from SHOT_ACTIVE_P2). A giant returns carry 0: the record scan. JSL.
large_list_prepare:
  lda OBJ_TYPE
  cmp #OT_GIANT
  beq @linear
  cpy #SHOTS_PER_PLAYER*SHOT_SIZE
  bne :+
  ldy SHOT_ACTIVE_P2            ; P1 only
  bra @end
:
  ldy SHOT_ACTIVE_END
@end:
  sty CONTACT_LIMIT
  cpx #0
  bne :+
  ldy #0
  bra @ready
:
  ldy SHOT_ACTIVE_P2            ; P2 only
@ready:
  sec
  rtl
@linear:
  clc
  rtl
.popseg
