; More decisions of the one-piece formation planes (US arcade banks 0 and
; 6): the returning, interval, crossing, edge, strafing, sweep, pattern, fan
; and carrier child planes. Each selects arcade motion records (AI_NEXT) and
; returns carry 1, or carry 0 for a tail that is not theirs.
.a8
.i16
RETURN_FIELD_MIN = $31       ; formation_returning: inside RETURN_FIELD_MIN..MAX-1
RETURN_FIELD_MAX = $d0       ; on both axes the plane is in the field
RETURN_SHOT_LIMIT = 6        ; formation_returning: no turn after this many shots
INTERVAL_FIRE = 3            ; formation_interval: the shot at this INTERVAL_TIME
CROSS_RIGHT_START = $90      ; formation_crossing: from this cross the right arc starts
CROSS_LEFT_START = $60       ; formation_crossing: below this cross the left arc starts
EDGE_TURN_LIMIT = 9          ; formation_edge_turn: no turn after this many
CHILD_TURN_LIMIT = 64        ; formation_carrier_child: no turn after this many

; Rows of formation_paths after those of formation_ai.s.
FT_RETURNING = 4
FT_INTERVAL = 5
FT_CROSSING = 6
FT_EDGE_TURN = 7

; The family bytes of the object record, by decision. FORMATION_HEADING
; ($10) is the heading wherever the decision turns with formation_aim_turn.
RETURN_TURNING = $10         ; formation_returning: 1 while it turns to the player
RETURN_SHOTS = $11           ; formation_returning: shots fired; it stops at 6
RETURN_STARTED = $12         ; formation_returning: the turn started outside the field
RETURN_HEADING = $13         ; formation_returning: the heading, 0-31
RETURN_TURN = $14            ; formation_returning: 0 heading + 1, 1 heading - 1
INTERVAL_TIME = $11          ; formation_interval: decisions left; it fires at 3
INTERVAL_LENGTH = $12        ; formation_interval: INTERVAL_TIME after each turn
CROSS_SIDE = $11             ; formation_crossing: 0 the right path, else the left
CROSS_ARC = $12              ; formation_crossing: the arc runs
CROSS_DELAY = $13            ; formation_crossing: decisions left of this arc step
EDGE_PATH = $12              ; formation_edge_second: nonzero takes the second path
EDGE_TURNS = $11             ; formation_edge_turn: turns done; it stops at 9
STRAFE_TIME = $11            ; formation_strafing: decisions left before it leaves
STRAFE_PATH = $12            ; strafing: nonzero takes the second path
STRAFE_FIRED = $13           ; formation_strafing: the first shot is done
SWEEP_TIME = $11             ; formation_sweep: decisions left of this heading
SWEEP_STEP = $12             ; formation_sweep: the next sequence entry, times 2
PATTERN_STEP = $11           ; formation_delta_pattern: the next delta
PATTERN_MIRROR = $12         ; formation_delta_pattern: bit 0 adds the delta, else subtracts
FAN_TIME = $11               ; fan: decisions left of this step
FAN_LENGTH = $12             ; formation_fan_turn: FAN_TIME after each step
FAN_SIDE = $13               ; formation_fan_turn: bit 0 the right paths
CHILD_TURNS = $11            ; formation_carrier_child: turns done; it stops at 64

; Motion code tails (AI_TAIL).
TAIL_FORMATION_CARRIER_CHILD = $99c9 ; bank 0
TAIL_FORMATION_RETURNING = $8497 ; bank 0
TAIL_FORMATION_INTERVAL = $93d6 ; bank 0
TAIL_FORMATION_CROSSING = $9729 ; bank 0
TAIL_FORMATION_SWEEP = $a153 ; bank 6
TAIL_FORMATION_PAIR_SWEEP = $ade8 ; bank 6
TAIL_FORMATION_CROSS_PATTERN = $a3fe ; bank 6
TAIL_FORMATION_EDGE_PATTERN = $a75e ; bank 6
TAIL_FORMATION_FAN_WAIT = $9e11 ; bank 6
TAIL_FORMATION_FAN_TURN = $9e22 ; bank 6
TAIL_FORMATION_EDGE_FIRST = $9010 ; bank 6
TAIL_FORMATION_EDGE_SECOND = $9019 ; bank 6
TAIL_FORMATION_EDGE_TURN = $902c ; bank 6
TAIL_FORMATION_STRAFING = $b48f ; bank 6
TAIL_FORMATION_STRAFE_FIRE = $b4d6 ; bank 6

; Motion records (AI_NEXT).
MOTION_CROSSING_RIGHT = $985f  ; bank 0
MOTION_CROSSING_LEFT = $98e7   ; bank 0
MOTION_EDGE_FIRST = $90df      ; bank 6
MOTION_EDGE_SECOND = $90e9     ; bank 6
MOTION_EDGE_SECOND_ALT = $915c ; bank 6: EDGE_PATH set
MOTION_STRAFE = $b514          ; bank 6
MOTION_STRAFE_ALT = $b54f      ; bank 6: STRAFE_PATH set
MOTION_STRAFE_LEAVE = $b5d3    ; bank 6
MOTION_STRAFE_LEAVE_ALT = $b58a ; bank 6: STRAFE_PATH set
MOTION_STRAFE_FIRE = $b634     ; bank 6
MOTION_STRAFE_FIRE_ALT = $b61c ; bank 6: STRAFE_PATH set
MOTION_FAN_WAIT = $9e99        ; bank 6
MOTION_FAN_TURN = $9eaa        ; bank 6

; formation_extra: the decision of AI_TAIL (formation_ai); the air boss
; enemies first. JSL.
formation_extra:
.a8
  jsl airboss_enemy_ai
  bcc :+
  rtl
:
  a16
  lda z:OBJ_VARIANT
  and #OBJ_BANK_BITS
  beq @zero
.a16
  cmp #6<<4                     ; motion bank 6
  beq @six
@unknown:
  a8
  clc
  rtl
@zero:
.a16
  lda AI_TAIL
  cmp #TAIL_FORMATION_CARRIER_CHILD
  bne :+
  a8
  jmp .loword(formation_carrier_child)
:
.a16
  cmp #TAIL_FORMATION_RETURNING
  bne :+
  a8
  jmp .loword(formation_returning)
:
.a16
  cmp #TAIL_FORMATION_INTERVAL
  bne :+
  a8
  jmp .loword(formation_interval)
:
.a16
  cmp #TAIL_FORMATION_CROSSING
  bne @unknown
  a8
  jmp .loword(formation_crossing)
@six:
.a16
  lda AI_TAIL
  .macro later_formation id, target
    cmp #id
    bne :+
    a8
    jmp .loword(target)
:
.a16
  .endmacro
  later_formation TAIL_FORMATION_SWEEP, formation_sweep
  later_formation TAIL_FORMATION_PAIR_SWEEP, formation_pair_sweep
  later_formation TAIL_FORMATION_CROSS_PATTERN, formation_cross_pattern
  later_formation TAIL_FORMATION_EDGE_PATTERN, formation_edge_pattern
  later_formation TAIL_FORMATION_FAN_WAIT, formation_fan_wait
  later_formation TAIL_FORMATION_FAN_TURN, formation_fan_turn
  .delmacro later_formation
.a16
  cmp #TAIL_FORMATION_EDGE_FIRST
  bne :+
  a8
  jmp .loword(formation_edge_first)
:
.a16
  cmp #TAIL_FORMATION_EDGE_SECOND
  bne :+
  a8
  jmp .loword(formation_edge_second)
:
.a16
  cmp #TAIL_FORMATION_EDGE_TURN
  bne :+
  a8
  jmp .loword(formation_edge_turn)
:
.a16
  cmp #TAIL_FORMATION_STRAFING
  bne :+
  a8
  jmp .loword(formation_strafing)
:
.a16
  cmp #TAIL_FORMATION_STRAFE_FIRE
  beq :+
  jmp .loword(@unknown)
:
  a8
  lda #2                        ; 2 in 16
  jsr .loword(formation_strafe_fire)
  a16
  lda z:STRAFE_PATH
  and #255
  beq :+
  lda #MOTION_STRAFE_FIRE_ALT
  bra formation_extra_path
:
  lda #MOTION_STRAFE_FIRE
; formation_extra_path: AI_NEXT = A; carry 1. JSL end.
formation_extra_path:
.a16
  sta AI_NEXT
  a8
  sec
  rtl
; formation_extra_table: the formation_paths path of heading A in the row at
; FORMATION_TABLE_OFFSET.
formation_extra_table:
.a8
  a16
  and #DIRECTIONS-1
  asl
  clc
  adc a:FORMATION_TABLE_OFFSET
  tax
  lda f:formation_paths,x
  bra formation_extra_path

; formation_returning: when the plane leaves the field (up to
; RETURN_SHOT_LIMIT times), it turns step by step to the player and fires.
formation_returning:
.a8
  lda z:RETURN_TURNING
  bne @turn
  lda z:SPR_CROSS
  cmp #RETURN_FIELD_MIN
  bcc @outside
  cmp #RETURN_FIELD_MAX
  bcs @outside
  lda z:SPR_ALONG
  cmp #RETURN_FIELD_MIN
  bcc @outside
  cmp #RETURN_FIELD_MAX
  bcs @outside
  stz z:RETURN_STARTED
  bra @select
@outside:
  lda z:RETURN_STARTED
  bne @select
  lda z:RETURN_SHOTS
  cmp #RETURN_SHOT_LIMIT
  bcs @select
  lda #1
  sta z:RETURN_TURNING
  sta z:RETURN_STARTED
  jsl ai_target_far
  sec
  sbc z:RETURN_HEADING
  and #DIRECTIONS-1
  cmp #DIRECTIONS/2
  lda #TURN_UP
  bcc :+
  inc                           ; TURN_DOWN
:
  sta z:RETURN_TURN
@turn:
  lda z:RETURN_TURN
  beq @increase
  lda z:RETURN_HEADING
  dec
  bra @heading
@increase:
  lda z:RETURN_HEADING
  inc
@heading:
  and #DIRECTIONS-1
  sta z:RETURN_HEADING
  jsl ai_target_far
  cmp z:RETURN_HEADING
  bne @select
  stz z:RETURN_TURNING
  jsr .loword(formation_fire)
  inc z:RETURN_SHOTS
@select:
  a16
  lda #FT_RETURNING*DIRECTIONS*2
  sta a:FORMATION_TABLE_OFFSET
  a8
  lda z:RETURN_HEADING
  jmp .loword(formation_extra_table)

; formation_turn_only: formation_aim_turn without a change of the byte
; FORMATION_TURN ($14), which these decisions use for other things. JSR.
formation_turn_only:
.a8
  lda z:FORMATION_TURN
  pha
  jsr .loword(formation_aim_turn)
  pla
  sta z:FORMATION_TURN
  rts
; formation_interval: every INTERVAL_LENGTH decisions turn one step toward
; the player; fire once in each interval.
formation_interval:
.a8
  lda z:INTERVAL_TIME
  beq @turn
  cmp #INTERVAL_FIRE
  bne :+
  jsr .loword(formation_fire)
:
  dec z:INTERVAL_TIME
  bra @select
@turn:
  lda z:INTERVAL_LENGTH
  sta z:INTERVAL_TIME
  jsr .loword(formation_turn_only)
@select:
  lda #FT_INTERVAL
  sta FORMATION_TYPE
  jmp .loword(formation_select)

; formation_cross_fire: fire 1 time in 2 (random stream 1, step $77). JSR.
formation_cross_fire:
.a8
  lda RANDOM_STATE+1
  pha
  clc
  adc #$77
  sta RANDOM_STATE+1
  pla
  and #1
  beq :+
  jsr .loword(formation_fire)
:
  rts
; formation_crossing: fly across until past the player (or the side limit),
; fire, then turn in an arc: a heading step every second decision.
formation_crossing:
.a8
  lda z:CROSS_ARC
  bne @arc
  lda z:CROSS_SIDE
  bne @left
  lda z:SPR_CROSS
  cmp #CROSS_RIGHT_START
  bcs @right_start
  jsl ai_target_far
  lda z:SPR_CROSS
  cmp PLAYER+SPR_CROSS,y
  bcc @right_path
@right_start:
  jsr .loword(formation_cross_fire)
  lda #1
  sta z:CROSS_ARC
@right_path:
  a16
  lda #MOTION_CROSSING_RIGHT
  jmp .loword(formation_extra_path)
@left:
.a8
  lda z:SPR_CROSS
  cmp #CROSS_LEFT_START
  bcc @left_start
  jsl ai_target_far
  lda z:SPR_CROSS
  cmp PLAYER+SPR_CROSS,y
  bcs @left_path
@left_start:
  jsr .loword(formation_cross_fire)
  lda #1
  sta z:CROSS_ARC
@left_path:
  a16
  lda #MOTION_CROSSING_LEFT
  jmp .loword(formation_extra_path)
@arc:
.a8
  lda z:CROSS_DELAY
  beq @step
  dec z:CROSS_DELAY
  bra @select
@step:
  lda #1
  sta z:CROSS_DELAY
  lda z:CROSS_SIDE
  bne :+
  inc z:FORMATION_HEADING
  bra @select
:
  dec z:FORMATION_HEADING
@select:
  lda #FT_CROSSING
  sta FORMATION_TYPE
  jmp .loword(formation_select)

; formation_edge_first: fire 1 time in 16 (random stream 1, step $42).
formation_edge_first:
.a8
  lda RANDOM_STATE+1
  clc
  adc #$42
  sta RANDOM_STATE+1
  and #15
  bne :+
  jsr .loword(formation_fire)
:
  a16
  lda #MOTION_EDGE_FIRST
  jmp .loword(formation_extra_path)
; formation_edge_second: fire 7 times in 16 (random stream 0, step $13).
formation_edge_second:
.a8
  lda RANDOM_STATE
  clc
  adc #$13
  sta RANDOM_STATE
  and #15
  cmp #7
  bcs :+
  jsr .loword(formation_fire)
:
  a16
  lda z:EDGE_PATH
  and #255
  beq :+
  lda #MOTION_EDGE_SECOND_ALT
  jmp .loword(formation_extra_path)
:
  lda #MOTION_EDGE_SECOND
  jmp .loword(formation_extra_path)
; formation_edge_turn: turn toward the player, EDGE_TURN_LIMIT times.
formation_edge_turn:
.a8
  lda z:EDGE_TURNS
  cmp #EDGE_TURN_LIMIT
  bcs @select
  inc z:EDGE_TURNS
  jsr .loword(formation_turn_only)
@select:
  lda #FT_EDGE_TURN
  sta FORMATION_TYPE
  jmp .loword(formation_select)

; formation_strafe_fire: fire with odds of A in 16 (random stream 1, step
; $13). JSR.
formation_strafe_fire:
.a8
  sta FORMATION_ODDS
  lda RANDOM_STATE+1
  clc
  adc #$13
  sta RANDOM_STATE+1
  and #15
  cmp FORMATION_ODDS
  bcs :+
  jsr .loword(formation_fire)
:
  rts
; formation_strafing: strafe (the first decision fires 8 in 16) while
; STRAFE_TIME lasts and the plane is above the player; then leave (4 in 16).
formation_strafing:
.a8
  lda z:STRAFE_TIME
  beq @leaving
  dec z:STRAFE_TIME
  lda z:STRAFE_FIRED
  bne :+
  lda #$ff
  sta z:STRAFE_FIRED
  lda #8
  jsr .loword(formation_strafe_fire)
:
  jsl ai_target_far
  lda PLAYER+SPR_ALONG,y
  cmp z:SPR_ALONG
  bcs @leaving
  a16
  lda z:STRAFE_PATH
  and #255
  beq :+
  lda #MOTION_STRAFE_ALT
  jmp .loword(formation_extra_path)
:
  lda #MOTION_STRAFE
  jmp .loword(formation_extra_path)
@leaving:
.a8
  lda #4
  jsr .loword(formation_strafe_fire)
  a16
  lda z:STRAFE_PATH
  and #255
  beq :+
  lda #MOTION_STRAFE_LEAVE_ALT
  jmp .loword(formation_extra_path)
:
  lda #MOTION_STRAFE_LEAVE
  jmp .loword(formation_extra_path)

.segment "GAMEFLOW"
; formation_sweep, formation_pair_sweep: each step of the sweep sequence
; (game_sweep_sequence, game_pair_sweep_sequence: the decisions, the
; heading) lasts its time. FORMATION_TYPE is 1 for the pair here.
formation_sweep:
.a8
  lda #0
  bra formation_sweep_common
formation_pair_sweep:
.a8
  lda #1
formation_sweep_common:
.a8
  sta FORMATION_TYPE
  lda z:SWEEP_TIME
  beq @change
  dec z:SWEEP_TIME
  bra @select
@change:
  a16
  lda z:SWEEP_STEP
  and #255
  tax
  a8
  inc z:SWEEP_STEP
  inc z:SWEEP_STEP              ; two bytes an entry
  lda FORMATION_TYPE
  bne @pair
  lda f:game_sweep_sequence,x
  sta z:SWEEP_TIME
  lda f:game_sweep_sequence+1,x
  bra @heading
@pair:
  lda f:game_pair_sweep_sequence,x
  sta z:SWEEP_TIME
  lda f:game_pair_sweep_sequence+1,x
@heading:
  sta z:FORMATION_HEADING
@select:
  a16
  lda z:FORMATION_HEADING
  and #DIRECTIONS-1
  asl
  tax
  a8
  lda FORMATION_TYPE
  bne @pair_path
  a16
  lda f:game_sweep_paths,x
  jmp .loword(formation_extra_path)
@pair_path:
  a16
  lda f:game_pair_sweep_paths,x
  jmp .loword(formation_extra_path)

; formation_cross_pattern, formation_edge_pattern: each decision turns the
; heading by the next delta (game_cross_deltas, game_edge_deltas), mirrored
; when PATTERN_MIRROR bit 0 is 0. FORMATION_TYPE is 1 for the edge here.
formation_cross_pattern:
.a8
  lda #0
  bra formation_delta_pattern
formation_edge_pattern:
.a8
  lda #1
formation_delta_pattern:
.a8
  sta FORMATION_TYPE
  a16
  lda z:PATTERN_STEP
  and #255
  tax
  a8
  inc z:PATTERN_STEP
  lda FORMATION_TYPE
  bne @edge
  lda f:game_cross_deltas,x
  bra @sign
@edge:
  lda f:game_edge_deltas,x
@sign:
  sta a:PATTERN_DELTA
  lda z:PATTERN_MIRROR
  lsr
  lda a:PATTERN_DELTA
  bcs @add
  eor #$ff
  inc
@add:
  clc
  adc z:FORMATION_HEADING
  and #DIRECTIONS-1
  sta z:FORMATION_HEADING
  a16
  and #255
  asl
  tax
  a8
  lda FORMATION_TYPE
  bne @edge_path
  a16
  lda f:game_cross_paths,x
  jmp .loword(formation_extra_path)
@edge_path:
  a16
  lda f:game_edge_paths,x
  jmp .loword(formation_extra_path)

; formation_fan_wait: wait FAN_TIME decisions, then the fan turn.
formation_fan_wait:
.a8
  dec z:FAN_TIME
  beq @turn
  a16
  lda #MOTION_FAN_WAIT
  jmp .loword(formation_extra_path)
@turn:
  a16
  lda #MOTION_FAN_TURN
  jmp .loword(formation_extra_path)
; formation_fan_turn: a heading step every FAN_LENGTH decisions, on the
; left or right fan paths (FAN_SIDE).
formation_fan_turn:
.a8
  lda z:FAN_TIME
  beq @step
  dec z:FAN_TIME
  bra @path
@step:
  inc z:FORMATION_HEADING
  lda z:FAN_LENGTH
  sta z:FAN_TIME
@path:
  a16
  lda z:FORMATION_HEADING
  and #255
  asl
  tax
  a8
  lda z:FAN_SIDE
  lsr
  bcs @right
  a16
  lda f:game_fan_left_paths,x
  jmp .loword(formation_extra_path)
@right:
  a16
  lda f:game_fan_right_paths,x
  jmp .loword(formation_extra_path)

; formation_carrier_child: turn toward the player, CHILD_TURN_LIMIT times.
formation_carrier_child:
.a8
  lda z:CHILD_TURNS
  cmp #CHILD_TURN_LIMIT
  bcs @select
  inc z:CHILD_TURNS
  jsr .loword(formation_aim_turn)
@select:
  a16
  lda z:FORMATION_HEADING
  and #DIRECTIONS-1
  asl
  tax
  lda f:game_carrier_child_paths,x
  jmp .loword(formation_extra_path)
.segment "GAMEPLAY"
