; The aiming turrets of the ships (bank 6, US arcade $804B, $81C7, $8343,
; $84B7: kinds 0-3 in TURRET_KIND). D = the head record. The barrel turns two
; steps of 32 at a time towards the target; aligned and ready, the turret
; fires (TURRET_FIRE: the bullet speed class; LARGE_AI_X/Y: the muzzle).
; Kind 3 also leads the target: it turns towards where the player's stick
; points. When the ship core falls, the turret dies for STAGE_CORE_OWNER.
.a16
.i16
AIM_STEP = 2                 ; the barrel and the lead turn this many steps of 32
FIRE_DELAY = 9               ; decisions between shots (kind 0: FIRE_DELAY_FAST)
FIRE_DELAY_FAST = 7
NO_ANGLE = 255               ; turret_input_angles: no stick direction

; ship_aiming_turret: the decision of an aiming turret (large_ai). A16.
ship_aiming_turret:
  lda LARGE_CALLBACK
  ldx #0
  cmp #TAIL_AIMING_TURRET
  beq @kind
  ldx #1
  cmp #TAIL_AIMING_TURRET_2
  beq @kind
  ldx #2
  cmp #TAIL_AIMING_TURRET_3
  beq @kind
  ldx #3
@kind:
  stx TURRET_KIND
  a8
  stz TURRET_FIRE
  lda STAGE_TURRETS_FALL
  beq @alive
  lda STAGE_CORE_OWNER
  sta OBJ_OWNER
  lda #LA_KILL
  sta LARGE_AI_ACTION
  a16
  lda #0                        ; no next motion record
  jmp .loword(large_ai_selected)
@alive:
.a8
  lda TURRET_DELAY
  beq :+
  dec TURRET_DELAY
:
  jsl ai_target_far             ; OBJ_AIM = the direction to the target, Y = it
  lda TURRET_KIND
  cmp #3
  bne @turn
  ; Kind 3 leads the target: OBJ_AIM turns AIM_STEP towards the direction of
  ; the player's held stick (arcade $3166-$31AB), unless it is the same or
  ; the opposite direction.
  lda PLAYER+PL_NUMBER,y
  beq @p1
  lda TURRET_INPUT+1
  bra @input
@p1:
  lda TURRET_INPUT
@input:
  eor #255                      ; active high
  and #INPUT_STICK
  a16
  and #255
  tax
  a8
  lda f:turret_input_angles,x
  cmp #NO_ANGLE
  beq @turn
  sec
  sbc OBJ_AIM
  and #31
  beq @turn
  cmp #16
  beq @turn
  bcc @predict_plus
  lda OBJ_AIM
  sec
  sbc #AIM_STEP
  bra @predict_store
@predict_plus:
  lda OBJ_AIM
  clc
  adc #AIM_STEP
@predict_store:
  and #31
  sta OBJ_AIM
  ; The barrel turns AIM_STEP the short way; within one step it is aligned.
@turn:
  lda OBJ_AIM
  sec
  sbc TURRET_BARREL
  and #31
  beq @aligned
  cmp #1
  beq @aligned
  cmp #31
  beq @aligned
  cmp #16
  bcc @increase
  lda TURRET_BARREL
  sec
  sbc #AIM_STEP
  bra @angle
@increase:
  lda TURRET_BARREL
  clc
  adc #AIM_STEP
@angle:
  and #31
  sta TURRET_BARREL
  bra @select
  ; Aligned and ready: kind 3 fires; the others fire 1 time in 2 (random
  ; stream 0, step $77).
@aligned:
  lda TURRET_DELAY
  bne @select
  lda TURRET_KIND
  cmp #3
  beq @fire
  lda RANDOM_STATE
  pha
  clc
  adc #$77
  sta RANDOM_STATE
  pla
  lsr
  bcc @select
@fire:
  lda #FIRE_DELAY
  ldx TURRET_KIND
  bne :+
  lda #FIRE_DELAY_FAST
:
  sta TURRET_DELAY
  lda #2                        ; the bullet speed class: 2, or 1 for kind 0
  cpx #0
  bne :+
  dec
:
  sta TURRET_FIRE
  lda TURRET_BARREL
  sta TURRET_ANGLE
  a16
  and #31
  tax
  a8
  lda f:turret_muzzles,x        ; the cross and along offsets of the muzzle
  clc
  adc SPR_CROSS
  sta LARGE_AI_X
  lda f:turret_muzzles+1,x
  clc
  adc SPR_ALONG
  sta LARGE_AI_Y
  ; The motion record of the barrel: turret_aim_paths, 32 bytes for each kind.
@select:
  a16
  lda TURRET_KIND
  asl
  asl
  asl
  asl
  asl                           ; times 32
  sta a:TURRET_PATH_OFFSET
  lda TURRET_BARREL
  and #31
  clc
  adc a:TURRET_PATH_OFFSET
  tax
  lda f:turret_aim_paths,x
  jmp .loword(large_ai_selected)
