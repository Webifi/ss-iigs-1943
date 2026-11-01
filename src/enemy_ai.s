; The decisions of the small enemies: the native code for the arcade code
; tails of the motion scripts (AI_TAIL). The decision inputs and outputs are
; the AI_* variables (src/game_ram.s); D = the object record.
.a8
.i16
TARGET_NEAR = 32             ; ai_target: players closer along than this: AI_PREFERENCE
; ai_target: the ai_angles group of the aim, from the signs and the major axis.
AIM_LEFT = 32                ; the player is to the left
AIM_UP = 24                  ; the player is above
AIM_CROSS_MAJOR = 8          ; the cross distance is the larger
AIM_THRESHOLDS = 4           ; ai_thresholds: four minor limits for each major / 8
APPROACH_ALONG = $a0         ; ai_approach: a player at this along or lower: pass
LOW_TURN_ALONG = $40         ; ai_low_turn: an object above this along chooses a side
NEAR_TURN_GAP = $28          ; ai_near_turn: closer along than this: choose a side
SIDE_FAR = $20               ; ai_choose_side: farther to the side than this: AI_FAR
AI_PATTERN_STEPS = 32        ; ai_pattern: the steps of a pattern (a power of two)
PATTERN_ENTRY_SIZE = 3       ; a pattern entry: the decisions, the motion record

; The family bytes of the object record for these decisions.
AI_PATTERN_STEP = $10        ; ai_pattern, ai_pair_pattern: the step, 0-31
AI_STEP_TIME = $11           ; ai_pattern, ai_pair_pattern: decisions left of this step
AI_FAR = $11                 ; ai_choose_side: the player is far to the side
AI_LOOPS = $12               ; ai_left_count, ai_right_count: loops left

; Motion code tails: the arcade code that a motion record calls
; (AI_TAIL). Fixed bank unless the comment gives a bank.
TAIL_BULLET_HIT_SOUND = $49b5 ; queue SND_BULLET_HIT, then the next motion record
TAIL_EXPLOSION = $5a3e
TAIL_OWNER_EXPLOSION = $5ac8 ; the explosion that shows the scoring player
TAIL_BONUS_SCORE = $6faa     ; a bonus object becomes PV_SCORE
TAIL_LASER_PICKUP = $726b
TAIL_TELEPORT_BONUS = $729d
TAIL_BONUS_B = $735b         ; a bonus object becomes PV_SCORE_B
TAIL_BONUS_C = $7573         ; a bonus object becomes PV_TIME
TAIL_BONUS_D = $75eb         ; a bonus object becomes PV_SCORE_D
TAIL_BONUS_E = $7675         ; a bonus object takes contact and shot flags
TAIL_CYCLE_BONUS = $768d
TAIL_APPROACH = $8914        ; bank 0
TAIL_LOW_TURN = $893f        ; bank 0
TAIL_NEAR_TURN = $899a       ; bank 0
TAIL_LEFT_COUNT = $89b7      ; bank 0
TAIL_LEFT_LOOP = $89c1       ; bank 0
TAIL_RIGHT_COUNT = $8a07     ; bank 0
TAIL_RIGHT_LOOP = $8a11      ; bank 0
TAIL_RANDOM_FIRE = $8a57     ; bank 0: fire when the random byte is odd
TAIL_PATTERN = $9ad1         ; bank 6
TAIL_PAIR_PATTERN = $aac5    ; bank 6

; Motion records that these decisions select (AI_NEXT). Fixed bank unless
; the comment gives a bank.
MOTION_EXPLOSION = $5a53     ; ai_explosion
MOTION_EXPLOSION_P2 = $5a8c
MOTION_OWNER_EXPLOSION = $5add
MOTION_OWNER_EXPLOSION_P2 = $5b25
MOTION_BONUS_SCORE = $6fbc
MOTION_TELEPORT_BONUS = $72fe
MOTION_BONUS_B = $736d
MOTION_BONUS_C = $7585
MOTION_BONUS_D = $75fd
MOTION_BONUS_E = $7683
; Bank 0, ai_destinations. _DROP: the path of an object with a drop
; (OBJ_DROP). _FAR: the path when the player is far to the side.
MOTION_PURSUE = $8a92
MOTION_PURSUE_DROP = $8b93
MOTION_PASS = $8a81
MOTION_PASS_DROP = $8b82
MOTION_SIDE_LEFT = $8b0a
MOTION_SIDE_LEFT_DROP = $8c12
MOTION_SIDE_RIGHT = $8aa3
MOTION_SIDE_RIGHT_DROP = $8ba4
MOTION_LEFT_LOOP = $8b67
MOTION_LEFT_LOOP_DROP = $8c6f
MOTION_LEFT_LOOP_FAR = $8b56
MOTION_LEFT_LOOP_FAR_DROP = $8c5e
MOTION_LEFT_LEAVE = $8d3a
MOTION_LEFT_LEAVE_DROP = $8e32
MOTION_LEFT_LEAVE_FAR = $8cfc
MOTION_LEFT_LEAVE_FAR_DROP = $8df4
MOTION_RIGHT_LOOP = $8af9
MOTION_RIGHT_LOOP_DROP = $8c01
MOTION_RIGHT_LOOP_FAR = $8ae8
MOTION_RIGHT_LOOP_FAR_DROP = $8bf0
MOTION_RIGHT_LEAVE = $8cbe
MOTION_RIGHT_LEAVE_DROP = $8db6
MOTION_RIGHT_LEAVE_FAR = $8c80
MOTION_RIGHT_LEAVE_FAR_DROP = $8d78

; enemy_ai: the decision of the code tail AI_TAIL of the object D. The ground
; objects, the formations, the carrier aircraft (motion bank 4) and the
; medium objects have their own decisions; the others are here. Returns
; AI_NEXT (0: the object stays), AI_FIRE and AI_SOUND. JSR.
enemy_ai:
  stz AI_FIRE
  stz AI_SOUND
  jsl ground_ai
  bcc :+
  rts
:
  a16
  stz AI_NEXT
  jsl formation_ai
  bcc :+
  rts
:
  a16
  lda AI_TAIL
  cmp #ARCADE_BANK_WINDOW
  bcc :+
  lda z:OBJ_VARIANT
  and #OBJ_BANK_BITS
  cmp #4<<4                   ; bank 4: carrier aircraft
  bne :+
  jsl ship_ai
  bcc ai_unknown_ship
  rts
ai_unknown_ship:
  a8
  rts
:
 .a16
  lda AI_TAIL
  cmp #TAIL_CYCLE_BONUS
  bne :+
  a8
  jsl pickup_change
  rts
:
 .a16
  cmp #TAIL_LASER_PICKUP
  bne :+
  a8
  jsl pickup_laser
  rts
:
 .a16
  cmp #TAIL_TELEPORT_BONUS
  bne :+
  lda #MOTION_TELEPORT_BONUS
  sta AI_NEXT
  a8
  rts
:
 .a16
  cmp #TAIL_BULLET_HIT_SOUND
  bne :+
  lda z:OBJ_MOTION
  clc
  adc #STEP_SIZE+STEP_TAIL_SIZE ; the record after the tail
  sta AI_NEXT
  a8
  lda #SND_BULLET_HIT
  sta AI_SOUND
  rts
:
  .a16
  cmp #TAIL_APPROACH
  bne :+
  jmp ai_approach
:
  cmp #TAIL_LOW_TURN
  bne :+
  jmp ai_low_turn
:
  cmp #TAIL_NEAR_TURN
  bne :+
  jmp ai_near_turn
:
  cmp #TAIL_LEFT_COUNT
  bne :+
  jmp ai_left_count
:
  cmp #TAIL_LEFT_LOOP
  bne :+
  jmp ai_left_loop
:
  cmp #TAIL_RIGHT_COUNT
  bne :+
  jmp ai_right_count
:
  cmp #TAIL_RIGHT_LOOP
  bne :+
  jmp ai_right_loop
:
  cmp #TAIL_EXPLOSION
  bne :+
  jmp ai_explosion
:
  cmp #TAIL_PATTERN
  bne :+
  jmp ai_pattern
:
  cmp #TAIL_OWNER_EXPLOSION
  bne :+
  a8
  lda z:OBJ_OWNER
  stz z:OBJ_OWNER
  cmp #2                        ; player 2
  beq @burst_two
  a16
  lda #MOTION_OWNER_EXPLOSION
  bra @burst_path
@burst_two:
  a16
  lda #MOTION_OWNER_EXPLOSION_P2
@burst_path:
  sta AI_NEXT
  a8
  rts
:
.a16
  cmp #TAIL_BONUS_SCORE
  bne :+
  a8
  lda #OF_CONTACT
  sta z:OBJ_FLAGS
  lda #PV_SCORE
  sta z:OBJ_VARIANT
  lda #$67                      ; the score code
  sta z:OBJ_SCORE
  a16
  lda #MOTION_BONUS_SCORE
  bra @burst_path
:
.a16
  cmp #TAIL_BONUS_B
  bne :+
  a8
  lda #PV_SCORE_B
  sta z:OBJ_VARIANT
  lda #$6f                      ; the score code
  sta z:OBJ_SCORE
  lda #OF_CONTACT|OF_CAMERA
  sta z:OBJ_FLAGS
  a16
  lda #MOTION_BONUS_B
  bra @burst_path
:
.a16
  cmp #TAIL_BONUS_C
  bne :+
  a8
  lda #PV_TIME
  sta z:OBJ_VARIANT
  lda #$5f                      ; the score code
  sta z:OBJ_SCORE
  lda #OF_CONTACT|OF_CAMERA
  sta z:OBJ_FLAGS
  a16
  lda #MOTION_BONUS_C
  jmp @burst_path
:
.a16
  cmp #TAIL_BONUS_D
  bne :+
  a8
  lda #PV_SCORE_D
  sta z:OBJ_VARIANT
  lda #$67                      ; the score code
  sta z:OBJ_SCORE
  lda #OF_CONTACT
  sta z:OBJ_FLAGS
  a16
  lda #MOTION_BONUS_D
  jmp @burst_path
:
.a16
  cmp #TAIL_BONUS_E
  bne :+
  a8
  lda #OF_CONTACT|OF_CAMERA
  sta z:OBJ_FLAGS
  lda #$4f                      ; the score code
  sta z:OBJ_SCORE
  a16
  lda #MOTION_BONUS_E
  sta AI_NEXT
  a8
  rts
:
.a16
  cmp #TAIL_PAIR_PATTERN
  bne :+
  jmp ai_pair_pattern
:
  cmp #TAIL_RANDOM_FIRE
  bne ai_unknown
  a8
  lda AI_RANDOM
  and #1                        ; odd: AIF_AIMED
  sta AI_FIRE
  beq :+
  jsr ai_target
:
  a16
  lda AI_CONTINUE
  sta AI_NEXT
  a8
  rts
; ai_unknown: the medium objects decide the other tails.
ai_unknown:
.a16
  jsl medium_ai
  bcc :+
  rts
:
  a8
  rts

; ai_target: Y = the player record the object D aims at (US arcade
; $051B-$054B): the one player in the game, else the one further along,
; else AI_PREFERENCE when they are closer than TARGET_NEAR; OBJ_AIM = the
; angle to that player (ai_angles). JSR; ai_target_far: JSL.
ai_target_far:
  jsr ai_target
  rtl
ai_target:
  ldy #0
  lda PLAYER+PL_STATE
  beq @second
  lda PLAYER2+PL_STATE
  beq @done
  lda PLAYER+SPR_ALONG
  sec
  sbc PLAYER2+SPR_ALONG
  bcc @negative
  cmp #TARGET_NEAR
  bcs @done
  bra @preference
@negative:
  eor #$ff
  inc
  cmp #TARGET_NEAR
  bcs @second
@preference:
  lda AI_PREFERENCE
  beq @done
@second:
  ldy #PLAYER_SIZE
@done:
  ; The distances and the ai_angles group.
  stz a:AIM_OCTANT
  lda PLAYER+SPR_CROSS,y
  sec
  sbc z:SPR_CROSS
  bcs @x_positive
  eor #$ff
  inc
  pha
  lda #AIM_LEFT
  sta a:AIM_OCTANT
  pla
@x_positive:
  sta a:AIM_CROSS
  lda PLAYER+SPR_ALONG,y
  sec
  sbc z:SPR_ALONG
  bcs @y_positive
  eor #$ff
  inc
  pha
  lda a:AIM_OCTANT
  ora #AIM_UP
  sta a:AIM_OCTANT
  pla
@y_positive:
  sta a:AIM_ALONG
  cmp a:AIM_CROSS
  bcs @major_y
  sta a:AIM_MINOR
  lda a:AIM_OCTANT
  eor #AIM_CROSS_MAJOR
  sta a:AIM_OCTANT
  lda a:AIM_CROSS
  bra @ratio_index
@major_y:
  lda a:AIM_CROSS
  sta a:AIM_MINOR
  lda a:AIM_ALONG
@ratio_index:
  ; The minor / major ratio, 0-4, from the AIM_THRESHOLDS of major / 8.
  lsr
  and #$7c                      ; major / 8 * AIM_THRESHOLDS
  a16
  and #255
  tax
  a8
  lda a:AIM_MINOR
  cmp f:ai_thresholds,x
  bcc @ratio_zero
  beq @ratio_zero
  cmp f:ai_thresholds+1,x
  bcc @ratio_one
  beq @ratio_one
  cmp f:ai_thresholds+2,x
  bcc @ratio_two
  beq @ratio_two
  cmp f:ai_thresholds+3,x
  bcc @ratio_three
  beq @ratio_three
  lda #4
  bra @ratio_ready
@ratio_zero:
  lda #0
  bra @ratio_ready
@ratio_one:
  lda #1
  bra @ratio_ready
@ratio_two:
  lda #2
  bra @ratio_ready
@ratio_three:
  lda #3
@ratio_ready:
  eor a:AIM_OCTANT
  a16
  and #255
  tax
  a8
  lda ai_angles,x
  sta z:OBJ_AIM
  rts

; ai_approach: pursue the player, or pass a player low on the field.
ai_approach:
.a16
  a8
  jsr ai_target
  ldx #ai_pursue-ai_destinations
  lda PLAYER+SPR_ALONG,y
  cmp #APPROACH_ALONG
  bcc ai_pair
  ldx #ai_pass-ai_destinations
  bra ai_pair

; ai_low_turn: pass, or choose a side when the object is still high.
ai_low_turn:
.a16
  a8
  ldx #ai_pass-ai_destinations
  lda z:SPR_ALONG
  cmp #LOW_TURN_ALONG
  bcs ai_pair
  bra ai_choose_side

; ai_near_turn: pursue, or choose a side when the player is near along.
ai_near_turn:
.a16
  a8
  jsr ai_target
  ldx #ai_pursue-ai_destinations
  lda PLAYER+SPR_ALONG,y
  clc
  adc #NEAR_TURN_GAP
  cmp z:SPR_ALONG
  bcc ai_pair

; ai_choose_side: turn to the side of the player; AI_FAR when the player is
; farther than SIDE_FAR to that side.
ai_choose_side:
  jsr ai_target
  lda PLAYER+SPR_CROSS,y
  cmp z:SPR_CROSS
  bcs @right
  ldx #ai_side_left-ai_destinations
  lda z:SPR_CROSS
  sec
  sbc #SIDE_FAR
  cmp PLAYER+SPR_CROSS,y
  bcc ai_pair
  lda #1
  sta z:AI_FAR
  bra ai_pair
@right:
  ldx #ai_side_right-ai_destinations
  lda z:SPR_CROSS
  clc
  adc #SIDE_FAR
  cmp PLAYER+SPR_CROSS,y
  bcs ai_pair
  lda #1
  sta z:AI_FAR
; ai_pair: AI_NEXT = the ai_destinations path X, the drop path for an object
; with a drop.
ai_pair:
  lda z:OBJ_DROP
  beq @ordinary
  inx
  inx
@ordinary:
  a16
  lda ai_destinations,x
  sta AI_NEXT
  a8
  rts

; ai_left_count, ai_right_count: loop again while AI_LOOPS lasts, else leave.
; ai_left_loop, ai_right_loop: loop. With AI_FAR, the far paths.
ai_left_count:
.a16
  a8
  lda z:AI_LOOPS
  beq @leave
  dec z:AI_LOOPS
  bra ai_left_loop8
@leave:
  ldx #ai_left_leave-ai_destinations
  bra ai_flag_choice
ai_left_loop:
.a16
  a8
ai_left_loop8:
  ldx #ai_left_loop_path-ai_destinations
  bra ai_flag_choice

ai_right_count:
.a16
  a8
  lda z:AI_LOOPS
  beq @leave
  dec z:AI_LOOPS
  bra ai_right_loop8
@leave:
  ldx #ai_right_leave-ai_destinations
  bra ai_flag_choice
ai_right_loop:
.a16
  a8
ai_right_loop8:
  ldx #ai_right_loop_path-ai_destinations
ai_flag_choice:
  lda z:AI_FAR
  beq @ready
  inx
  inx
  inx
  inx
@ready:
  jmp ai_pair

; ai_explosion: the explosion path of the player that scored (OBJ_OWNER).
ai_explosion:
.a16
  a8
  lda z:OBJ_OWNER
  stz z:OBJ_OWNER
  cmp #2                        ; player 2
  beq @second
  a16
  lda #MOTION_EXPLOSION
  bra @store
@second:
.a8
  a16
  lda #MOTION_EXPLOSION_P2
@store:
  sta AI_NEXT
  a8
  rts

; ai_pattern: the bank 6 pattern: each step of ai_pattern_table lasts its
; number of decisions, then the next step (AI_PATTERN_STEPS, in a loop).
ai_pattern:
.a16
  a8
  dec z:AI_STEP_TIME
  bne @same
  lda z:AI_PATTERN_STEP
  inc
  and #AI_PATTERN_STEPS-1
  sta z:AI_PATTERN_STEP
  jsr ai_pattern_index
  lda ai_pattern_table,x
  sta z:AI_STEP_TIME
  bra @pointer
@same:
  jsr ai_pattern_index
@pointer:
  a16
  lda ai_pattern_table+1,x
  sta AI_NEXT
  a8
  rts
; ai_pattern_index: X = AI_PATTERN_STEP * PATTERN_ENTRY_SIZE.
ai_pattern_index:
  a16
  lda z:AI_PATTERN_STEP
  and #255
  sta a:AI_PATTERN_OFFSET
  asl
  clc
  adc a:AI_PATTERN_OFFSET
  tax
  a8
  rts

; ai_pair_pattern: the same with game_pair_turns (the two-player formation).
ai_pair_pattern:
.a16
  a8
  dec z:AI_STEP_TIME
  bne @same
  lda z:AI_PATTERN_STEP
  inc
  and #AI_PATTERN_STEPS-1
  sta z:AI_PATTERN_STEP
  jsr ai_pattern_index
  lda f:game_pair_turns,x
  sta z:AI_STEP_TIME
  bra @pointer
@same:
  jsr ai_pattern_index
@pointer:
  a16
  lda f:game_pair_turns+1,x
  sta AI_NEXT
  a8
  rts

; ai_pair adds 2 for an object with a drop; ai_flag_choice adds 4 when AI_FAR.
ai_destinations:
ai_pursue: .word MOTION_PURSUE,MOTION_PURSUE_DROP
ai_pass: .word MOTION_PASS,MOTION_PASS_DROP
ai_side_left: .word MOTION_SIDE_LEFT,MOTION_SIDE_LEFT_DROP
ai_side_right: .word MOTION_SIDE_RIGHT,MOTION_SIDE_RIGHT_DROP
ai_left_loop_path: .word MOTION_LEFT_LOOP,MOTION_LEFT_LOOP_DROP
  .word MOTION_LEFT_LOOP_FAR,MOTION_LEFT_LOOP_FAR_DROP
ai_left_leave: .word MOTION_LEFT_LEAVE,MOTION_LEFT_LEAVE_DROP
  .word MOTION_LEFT_LEAVE_FAR,MOTION_LEFT_LEAVE_FAR_DROP
ai_right_loop_path: .word MOTION_RIGHT_LOOP,MOTION_RIGHT_LOOP_DROP
  .word MOTION_RIGHT_LOOP_FAR,MOTION_RIGHT_LOOP_FAR_DROP
ai_right_leave: .word MOTION_RIGHT_LEAVE,MOTION_RIGHT_LEAVE_DROP
  .word MOTION_RIGHT_LEAVE_FAR,MOTION_RIGHT_LEAVE_FAR_DROP
.assert AIM_THRESHOLDS = 4 .and PATTERN_ENTRY_SIZE = 3, error
