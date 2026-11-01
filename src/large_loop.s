; The large objects: one pass over the LARGE_COUNT records of LARGE_POOL each
; tick. Each object runs its motion; a code tail runs its decision
; (large_ai) and the loop acts on the results; then the contacts with the
; shots and the players. The records stay in place.
.a8
.i16

; large_loop_init: clear the pool, the boss damage ledger and the finish
; state (flight_loop, gameplay_reset_far). JSL.
large_loop_init:
  a16
  ldx #LARGE_COUNT*LARGE_SIZE-2
@clear:
  stz LARGE_POOL,x
  dex
  dex
  bpl @clear
  ldx #LARGE_GROUPS_SIZE-2
@groups:
  stz LARGE_GROUPS,x
  dex
  dex
  bpl @groups
  stz LARGE_TOTAL
  stz LARGE_SLOT
  stz LARGE_PENDING_ACTION
  a8
  stz SHIP_FINISH_ACTIVE
  stz SHIP_FINISH_WAIT
  stz TURRET_GROUP
  stz TURRET_RETRY
  rtl

; large_loop_tick: one tick of every large object (flight_tick). JSL.
large_loop_tick:
  lda CAMERA_OBJECT_CROSS
  sta LARGE_CAM_X
  lda CAMERA_OBJECT_ALONG
  sta LARGE_CAM_Y
  ; Each slot with an object runs large_loop_object; an empty slot costs
  ; one test.
  .repeat LARGE_COUNT,I
    lda LARGE_POOL+I*LARGE_SIZE+OBJ_TYPE
    beq :+
    ldx #I*LARGE_SIZE
    jsr .loword(large_loop_object)
:
  .endrepeat
  jmp .loword(large_loop_finish)

; large_loop_object: the large object at the slot X: its tick, its decision
; and its contacts. JSR; A8.
large_loop_object:
  stx LARGE_SLOT
  a16
  txa
  clc
  adc #LARGE_POOL
  sta LARGE_RECORD
  a8
@script:
  ldx LARGE_SLOT
  lda LARGE_POOL+OBJ_TYPE,x
  cmp #OT_GIANT
  bne @ordinary_tick
  jsl giant_object_tick
  bra @ticked
@ordinary_tick:
  jsl large_object_tick
@ticked:
  lda LARGE_KIND
  bne :+
  jmp .loword(@contact)         ; it moved
:
  cmp #LK_RETIRED
  bne :+
  jmp .loword(@next)
:
  ; LK_CALLBACK. Fixed-bank tails are shared; a banked tail is known only
  ; in motion banks 0, 4 and 6.
  a16
  lda LARGE_CALLBACK
  cmp #ARCADE_BANK_WINDOW
  bcc @call_ai
  ldx LARGE_SLOT
  lda LARGE_POOL+OBJ_VARIANT,x
  and #OBJ_BANK_BITS
  beq @call_ai
  cmp #4<<4
  beq @call_ai
  cmp #6<<4
  beq @call_ai
  a8
  bra @unknown
@call_ai:
  a8
  lda INPUT_P1                  ; the turrets read P1's input; P2: none
  sta TURRET_INPUT
  lda #255
  sta TURRET_INPUT+1
  jsl large_ai
  bcs @known
@unknown:
  jmp .loword(@next)
  ; Act on the decision: a turret bullet, the sound, a ship launch, a
  ; secondary explosion, an aimed bullet, a spread, a ship finish request,
  ; the death of the object, or else its next motion record.
@known:
  lda TURRET_FIRE
  beq :+
  jsl turret_bullet_spawn
:
  lda LARGE_AI_SOUND
  beq :+
  jsl game_sound_request
:
  lda LARGE_AI_X
  sta SHIP_REQUEST_CROSS
  lda LARGE_AI_Y
  sta SHIP_REQUEST_ALONG
  lda LARGE_AI_FIRE
  beq :+
  sta SHIP_REQUEST
  jsl ship_launch
:
  lda LARGE_AI_ACTION
  and #LA_EXPLOSION
  beq :+
  jsl ship_secondary_ready
:
  lda LARGE_AI_ACTION
  and #LA_BULLET
  beq :+
  jsl large_bullet_far
:
  lda LARGE_AI_ACTION
  and #LA_SPREAD
  beq :+
  jsl game_large_spread_far
:
  lda LARGE_AI_ACTION
  pha
  and #LA_FINISH_LOOP|LA_FINISH_STOP|LA_FINISH_FINAL
  beq @no_outer_action
  ora LARGE_PENDING_ACTION      ; done after the pass, below
  sta LARGE_PENDING_ACTION
@no_outer_action:
.a8
  pla
  and #LA_KILL
  beq @selected
  jsl large_common_kill
  bra @next
@selected:
  ; OBJ_MOTION is one step before the record: the script reads from +STEP_SIZE.
  a16
  lda LARGE_AI_NEXT
  sec
  sbc #STEP_SIZE
  ldx LARGE_SLOT
  sta LARGE_POOL+OBJ_MOTION,x
  a8
  jmp .loword(@script)
@contact:
  jsr .loword(large_loop_contacts)
@next:
  a8
  rts

; large_loop_finish: the ship finish requests of this pass: stop, start the
; final one, or start the looping one; then one tick of the ship finish.
large_loop_finish:
  a8
  lda LARGE_PENDING_ACTION
  and #LA_FINISH_STOP
  beq :+
  stz SHIP_FINISH_ACTIVE
:
  lda LARGE_PENDING_ACTION
  and #LA_FINISH_FINAL
  beq @looping_finish
  lda #SF_FINAL
  jsl ship_finish_begin
  bra @finish_tick
@looping_finish:
  lda LARGE_PENDING_ACTION
  and #LA_FINISH_LOOP           ; A = SF_LOOP
  beq @finish_tick
  jsl ship_finish_begin
@finish_tick:
  stz LARGE_PENDING_ACTION
  jsl ship_finish_tick
  rtl
.assert LA_FINISH_LOOP = SF_LOOP, error

; large_loop_contacts: the contacts of the object in LARGE_SLOT. As in the
; arcade, giants test on odd ticks ($642C), other objects on even ticks
; ($5C8C). Only an object on the field with a live player. The shots first;
; with no shot hit, the players (OF_CONTACT).
large_loop_contacts:
  ldx LARGE_SLOT
  lda LARGE_POOL+OBJ_TYPE,x
  cmp #OT_GIANT
  bne @ordinary_phase
  lda LARGE_POOL+OBJ_FLAGS,x
  beq @done
  lda COMBAT_PHASE
  and #1
  beq @done
  bra @phase_ready
@ordinary_phase:
  lda COMBAT_PHASE
  and #1
  bne @done
@phase_ready:
  ldx LARGE_SLOT
  lda LARGE_POOL+OBJ_FLAGS,x
  beq @done
  lda LARGE_POOL+SPR_ATTR,x
  ora LARGE_POOL+2*SPRITE_SIZE+SPR_ATTR,x
  and #SPR_ALONG_HIGH
  bne @done
  lda PLAYER+PL_STATE
  cmp #PS_LIVE
  beq :+
  lda PLAYER2+PL_STATE
  cmp #PS_LIVE
  bne @done
:
  jsl large_shot_contact
  lda CONTACT_SOUND
  beq :+
  jsl game_sound_request
:
  lda CONTACT_ACTION
  bne @kill
  ldx LARGE_SLOT
  lda LARGE_POOL+OBJ_FLAGS,x
  and #OF_CONTACT
  beq @done
  ldx #0
  jsl large_body_contact
  lda CONTACT_ACTION
  bne @body
  ldx #PLAYER_SIZE
  jsl large_body_contact
  lda CONTACT_ACTION
  beq @done
@body:
  lda CONTACT_SOUND
  beq @kill
  jsl game_sound_request
@kill:
  jsl large_common_kill
@done:
  rts

; large_common_kill: the object in LARGE_SLOT dies: only its camera flag
; stays, it runs its death script, a boss part gives its ledger value to
; LARGE_TOTAL, and the owner scores. JSL.
large_common_kill:
  ldx LARGE_SLOT
  lda LARGE_POOL+OBJ_FLAGS,x
  and #OF_CAMERA
  sta LARGE_POOL+OBJ_FLAGS,x
  stz LARGE_POOL+OBJ_DURATION,x
  a16
  lda LARGE_POOL+OBJ_PREDECESSOR,x
  sta LARGE_POOL+OBJ_MOTION,x
  lda LARGE_POOL+OBJ_LEDGER,x
  and #255
  tay
  a8
  beq @award
  lda LARGE_TOTAL
  clc
  adc LARGE_GROUPS,y
  sta LARGE_TOTAL
  lda #0
  sta LARGE_GROUPS,y
@award:
  lda LARGE_POOL+OBJ_OWNER,x
  beq @done
  sta SCORE_OWNER
  lda LARGE_POOL+OBJ_SCORE,x
  sta SCORE_AWARD_INDEX
  jsl large_score_far
@done:
  rtl
