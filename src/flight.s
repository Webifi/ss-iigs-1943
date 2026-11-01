; The flight of a live player: the stick moves the plane, the plane banks
; towards the pose of the stick direction, and a hit makes it roll.
; A 65816 port of the US arcade code at bank 1 $8657-$8714 and $8741-$879A.
; The build decodes the tables from the ROM (scripts/flight.py).
; PLAYER is a native player record (src/records.inc). Enter and exit with
; A8, X16, DBR = 0. Sound, firing, collisions and energy are elsewhere.
PLAYER2 = PLAYER+PLAYER_SIZE    ; the record of player 2
; The hit roll (flight_roll) in ANIM_WORK of the body.
ROLL_TIME = ANIM_WORK+1      ; updates left of this roll step
ROLL_TURN = ANIM_WORK+2      ; the pose change of each step, less one
ROLL_STEP = ANIM_WORK+3      ; roll steps done; the roll ends at ROLL_STEPS
ROLL_STEP_TIME = 2           ; updates of each roll step
ROLL_TOP_POSE = 4            ; at this pose the roll turns back
ROLL_BACK = $fe              ; ROLL_TURN after the top pose: steps of -1
ROLL_STEPS = $18             ; the steps of one roll
; flight_moves: for each speed table (STAGE_PLAYER_SPEED), two halves; each half has
; one FLIGHT_STEP_SIZE entry for each of the 16 stick directions.
FLIGHT_STEP_SIZE = 3         ; cross move, along move, the pose of the direction
FLIGHT_HALF = 16*FLIGHT_STEP_SIZE ; the half of the updates with an even PL_DRAIN
; The field of the plane (the left half sprite).
FLIGHT_CROSS_MIN = $10
FLIGHT_CROSS_MAX = $d0
FLIGHT_ALONG_MIN = $12
FLIGHT_ALONG_MAX = $d0
BODY2_CROSS = 16             ; the right half sprite is 16 pixels to the right
POSE_CODE = $20              ; the sprite code of pose 0; each pose has two codes

; flight_step: one flight update of the player in PLAYER_CURSOR
; (game_players_tick). D points at the player record during the update.
flight_step:
  phd
  a16
  lda PLAYER_CURSOR
  clc
  adc #PLAYER
  tcd
  a8
  jsr live_flight_step
  pld
  rts

; live_flight_step: D = the player record, FLIGHT_INPUT = its input.
; X, A: changed.
live_flight_step:
  a16
  ; FLIGHT_STICK = the stick bits, 1 = pressed (the input is active low).
  lda a:FLIGHT_INPUT
  eor #$ffff
  and #INPUT_STICK
  sta a:FLIGHT_STICK
  ; FLIGHT_TABLE = the speed table of the stage, then its half for this update.
  lda a:STAGE_PLAYER_SPEED
  and #255
  asl
  tax
  lda f:flight_speed_offsets,x
  sta a:FLIGHT_TABLE
  lda z:PL_DRAIN
  and #1
  bne @odd
  lda a:FLIGHT_TABLE
  clc
  adc #FLIGHT_HALF
  sta a:FLIGHT_TABLE
@odd:
  ; X = the entry of the stick direction: FLIGHT_TABLE + stick * 3.
  lda a:FLIGHT_STICK
  asl
  clc
  adc a:FLIGHT_STICK
  adc a:FLIGHT_TABLE
  tax
  a8
  ; A new direction restarts the banking delay.
  lda a:FLIGHT_STICK
  cmp z:PL_DIRECTION
  beq @direction_same
  sta z:PL_DIRECTION
  jsr flight_delay_reset
@direction_same:
  ; Move across, inside FLIGHT_CROSS_MIN to FLIGHT_CROSS_MAX.
  lda z:SPR_CROSS
  clc
  adc f:flight_moves,x
  cmp #FLIGHT_CROSS_MIN
  bcs @left_inside
  lda #FLIGHT_CROSS_MIN
@left_inside:
  cmp #FLIGHT_CROSS_MAX
  bcc @right_inside
  lda #FLIGHT_CROSS_MAX
@right_inside:
  sta z:SPR_CROSS
  clc
  adc #BODY2_CROSS
  sta z:PL_BODY2+SPR_CROSS
  ; Move along, inside FLIGHT_ALONG_MIN to FLIGHT_ALONG_MAX.
  inx
  lda z:SPR_ALONG
  clc
  adc f:flight_moves,x
  cmp #FLIGHT_ALONG_MIN
  bcs @top_inside
  lda #FLIGHT_ALONG_MIN
@top_inside:
  cmp #FLIGHT_ALONG_MAX
  bcc @bottom_inside
  lda #FLIGHT_ALONG_MAX
@bottom_inside:
  sta z:SPR_ALONG
  sta z:PL_BODY2+SPR_ALONG
  lda z:PL_HIT
  bne flight_roll
  ; Bank one pose towards the pose of the direction when the delay ends.
  dec z:PL_BANK_DELAY
  bne flight_advance_phase
  jsr flight_delay_reset
  inx
  lda z:PL_POSE
  cmp f:flight_moves,x
  beq flight_pose
  bcc @bank_up
  dec z:PL_POSE
  bra flight_pose
@bank_up:
  inc z:PL_POSE
; flight_pose: show PL_POSE on the two body sprites.
flight_pose:
  lda z:PL_POSE
  asl
  clc
  adc #POSE_CODE
  sta z:SPR_CODE
  inc
  sta z:PL_BODY2+SPR_CODE
flight_advance_phase:
  inc z:PL_DRAIN                ; the update count: energy drain and the speed half
  rts

; flight_roll: the hit roll. The plane cannot collide while it rolls. Every
; ROLL_STEP_TIME updates the pose steps up to ROLL_TOP_POSE, then back down,
; for ROLL_STEPS steps.
flight_roll:
  stz z:PL_COLLIDE
  lda z:ROLL_TIME
  beq @roll_tick
  dec z:ROLL_TIME
  bra flight_advance_phase
@roll_tick:
  lda #ROLL_STEP_TIME
  sta z:ROLL_TIME
  lda z:PL_POSE
  cmp #ROLL_TOP_POSE
  bne @roll_direction
  lda #ROLL_BACK
  sta z:ROLL_TURN
@roll_direction:
  lda z:ROLL_TURN
  inc
  clc
  adc z:PL_POSE
  sta z:PL_POSE
  bne @roll_nonzero
  stz z:ROLL_TURN               ; pose 0: step up again
@roll_nonzero:
  dec z:ROLL_TIME
  inc z:ROLL_STEP
  lda z:ROLL_STEP
  cmp #ROLL_STEPS
  bne flight_pose
  ; The roll is over: clear its work bytes; the plane can collide again.
  stz z:PL_HIT
  stz z:ANIM_WORK
  stz z:ROLL_TIME
  stz z:ROLL_TURN
  stz z:ROLL_STEP
  stz z:ANIM_WORK+4
  lda #1
  sta z:PL_COLLIDE
  bra flight_pose

; flight_delay_reset: PL_BANK_DELAY = the flight_delays entry of
; PL_BANK_INDEX. X is kept.
flight_delay_reset:
  phx
  a16
  lda z:PL_BANK_INDEX
  and #255
  tax
  a8
  lda f:flight_delays,x
  sta z:PL_BANK_DELAY
  plx
  rts

.include "flight_data.inc"
