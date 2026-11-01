; The decisions of the carrier aircraft (motion bank 4): the launch, the
; dive, the random fire and the homing. D = the object record. Each returns
; carry 1 with AI_NEXT, or carry 0 for a tail that is not theirs.
.a8
.i16
SHIP_TURN_LIMIT = 32         ; SHIP_TURNS: no turn after this many
WRAP_ALONG = $fa             ; ship_launch_wrap: at this along the aircraft wraps
WRAP_POSITIONS = 16          ; ship_wrap_positions: (cross, SHIP_TIME) entries
LAUNCH_FIRE_DELAY = 30       ; SHIP_FIRE_DELAY after a launch shot
SEQUENCE_ENTRY_SIZE = 3      ; ship_depart_sequence: the decisions, the motion record

; The family bytes of the object record for these aircraft.
SHIP_HEADING = $10           ; the heading, 0-31
SHIP_STEP = $10              ; ship_launch_wrap: the next ship_depart_sequence entry
SHIP_TIME = $11              ; decisions left of this step
SHIP_FIRE_DELAY = $12        ; launch: decisions left before the next shot
SHIP_DIVE_DONE = $12         ; dive: nonzero after the dive turn ends
SHIP_AIM_INTERVAL = $12      ; ship_homing_track: SHIP_TIME after each aim
SHIP_TURNS = $13             ; turns done; the aircraft stops at 32

; Bank-4 motion code tails (AI_TAIL).
TAIL_SHIP_LAUNCH_DEPART = $9283
TAIL_SHIP_LAUNCH_WRAP = $928d
TAIL_SHIP_LAUNCH_WAIT = $92f9
TAIL_SHIP_LAUNCH_ENABLE = $9309
TAIL_SHIP_LAUNCH_TRACK = $933c
TAIL_SHIP_DIVE_HOLD = $a1cc
TAIL_SHIP_DIVE_DELAY = $a1e0
TAIL_SHIP_DIVE_BEGIN = $a1ef
TAIL_SHIP_DIVE_WAIT = $a218
TAIL_SHIP_DIVE_AIM = $a233
TAIL_SHIP_DIVE_REAIM = $a267
TAIL_SHIP_DIVE_TURN_END = $a28e
TAIL_SHIP_FIRE_HALF = $a33e
TAIL_SHIP_FIRE_EIGHTH = $a343
TAIL_SHIP_FIRE_QUARTER = $a348
TAIL_SHIP_HOMING_BEGIN = $a6b5
TAIL_SHIP_HOMING_TRACK = $a6bf

; Bank-4 motion records (AI_NEXT).
MOTION_SHIP_DEPART = $9411
MOTION_SHIP_WRAP = $946e
MOTION_SHIP_WAIT = $9478
MOTION_SHIP_DIVE_HOLD = $a1d6
MOTION_SHIP_DIVE_DELAY = $a1fd
MOTION_SHIP_DIVE_WAIT = $a207
MOTION_SHIP_DIVE_AIM = $a22d
MOTION_SHIP_DIVE_LOOP = $a2af
MOTION_SHIP_DIVE_LEAVE = $a2b5     ; SHIP_HEADING below 16
MOTION_SHIP_DIVE_LEAVE_HIGH = $a2ec ; SHIP_HEADING 16 or more
MOTION_SHIP_DIVE_TURN = $a2db
MOTION_SHIP_HOMING = $a76e

; ship_ai: the decision of AI_TAIL for a carrier aircraft (enemy_ai). JSL.
ship_ai:
  a16
  lda AI_TAIL
  .macro dispatch id, dest
    cmp #id
    bne :+
    jmp .loword(dest)
:
  .endmacro
  dispatch TAIL_SHIP_LAUNCH_DEPART, ship_launch_depart
  dispatch TAIL_SHIP_LAUNCH_WRAP, ship_launch_wrap
  dispatch TAIL_SHIP_LAUNCH_WAIT, ship_launch_wait
  dispatch TAIL_SHIP_LAUNCH_ENABLE, ship_launch_enable
  dispatch TAIL_SHIP_LAUNCH_TRACK, ship_launch_track
  dispatch TAIL_SHIP_DIVE_HOLD, ship_dive_hold
  dispatch TAIL_SHIP_DIVE_DELAY, ship_dive_delay
  dispatch TAIL_SHIP_DIVE_BEGIN, ship_dive_begin
  dispatch TAIL_SHIP_DIVE_WAIT, ship_dive_wait
  dispatch TAIL_SHIP_DIVE_AIM, ship_dive_aim
  dispatch TAIL_SHIP_DIVE_REAIM, ship_dive_reaim
  dispatch TAIL_SHIP_DIVE_TURN_END, ship_dive_turn_end
  dispatch TAIL_SHIP_FIRE_HALF, ship_fire_half
  dispatch TAIL_SHIP_FIRE_EIGHTH, ship_fire_eighth
  dispatch TAIL_SHIP_FIRE_QUARTER, ship_fire_quarter
  dispatch TAIL_SHIP_HOMING_BEGIN, ship_homing_begin
  dispatch TAIL_SHIP_HOMING_TRACK, ship_homing_track
  .delmacro dispatch
  a8
  clc
  rtl
; ship_next: AI_NEXT = A; carry 1.
ship_next:
.a16
  sta AI_NEXT
  a8
  sec
  rtl
; ship_launch_depart: no contacts while the aircraft departs.
ship_launch_depart:
.a16
  a8
  stz z:OBJ_FLAGS
  a16
  lda #MOTION_SHIP_DEPART
  bra ship_next
; ship_launch_wrap: the departure: the steps of ship_depart_sequence; at
; WRAP_ALONG the aircraft comes back from the top at a random place.
ship_launch_wrap:
.a16
  a8
  lda z:SPR_ALONG
  cmp #WRAP_ALONG
  bcc @sequence
  lda #16                       ; the ship_depart_sequence entry after the wrap
  sta z:SHIP_STEP
  stz z:SHIP_TIME
  lda #SPR_HIDDEN
  sta z:SPR_ALONG
  lda RANDOM_STATE+2            ; random stream 2, step $99
  pha
  clc
  adc #$99
  sta RANDOM_STATE+2
  pla
  and #WRAP_POSITIONS-1
  asl
  a16
  and #255
  tax
  a8
  lda f:ship_wrap_positions,x
  sta z:SPR_CROSS
  lda f:ship_wrap_positions+1,x
  sta z:SHIP_TIME
  a16
  lda #MOTION_SHIP_WRAP
  bra ship_next
@sequence:
.a8
  lda z:SHIP_TIME
  beq @new
  dec z:SHIP_TIME
  lda z:SHIP_STEP
  jsr .loword(ship_sequence_index)
  bra @pointer
@new:
.a8
  lda z:SHIP_STEP
  inc z:SHIP_STEP
  jsr .loword(ship_sequence_index)
  lda f:ship_depart_sequence,x
  sta z:SHIP_TIME
@pointer:
  a16
  lda f:ship_depart_sequence+1,x
  jmp .loword(ship_next)
; ship_sequence_index: X = A * SEQUENCE_ENTRY_SIZE.
ship_sequence_index:
.a8
  a16
  and #255
  sta a:SHIP_SEQUENCE_OFFSET
  asl
  clc
  adc a:SHIP_SEQUENCE_OFFSET
  tax
  a8
  rts
; ship_launch_wait: wait SHIP_TIME decisions, then fire and turn.
ship_launch_wait:
.a16
  a8
  lda z:SHIP_TIME
  beq @fire
  dec z:SHIP_TIME
  a16
  lda #MOTION_SHIP_WAIT
  jmp .loword(ship_next)
@fire:
.a8
  jsr .loword(ship_launch_shot)
  jmp .loword(ship_launch_pointer)
; ship_launch_enable: the aircraft can hit and be hit.
ship_launch_enable:
.a16
  a8
  lda #OF_CONTACT|OF_SHOT
  sta z:OBJ_FLAGS
  a16
  lda #MOTION_SHIP_WAIT
  jmp .loword(ship_next)
; ship_launch_track: every second decision turn toward the player (up to
; SHIP_TURN_LIMIT turns); when the heading holds, fire every
; LAUNCH_FIRE_DELAY decisions.
ship_launch_track:
.a16
  a8
  lda z:SHIP_TIME
  beq @aim
  dec z:SHIP_TIME
  bra ship_launch_pointer
@aim:
  lda #1
  sta z:SHIP_TIME
  lda z:SHIP_TURNS
  cmp #SHIP_TURN_LIMIT
  bcs @fire_delay
  inc z:SHIP_TURNS
  jsr .loword(ship_turn)
  bcs ship_launch_pointer
@fire_delay:
  lda z:SHIP_FIRE_DELAY
  beq @fire
  dec z:SHIP_FIRE_DELAY
  bra ship_launch_pointer
@fire:
  jsr .loword(ship_launch_shot)
; ship_launch_pointer: the ship_launch_paths path of the heading.
ship_launch_pointer:
.a8
  a16
  lda z:SHIP_HEADING
  and #DIRECTIONS-1
  asl
  tax
  lda f:ship_launch_paths,x
  jmp .loword(ship_next)
; ship_launch_shot: fire, and wait LAUNCH_FIRE_DELAY. ship_shot: fire at the
; player. JSR.
ship_launch_shot:
.a8
  lda #LAUNCH_FIRE_DELAY
  sta z:SHIP_FIRE_DELAY
ship_shot:
  jsl ai_target_far
  lda #AIF_AIMED
  sta AI_FIRE
  rts
; ship_dive_begin: the dive starts: contacts on, a wait of 6 decisions.
ship_dive_begin:
.a16
  a8
  lda #OF_CONTACT|OF_SHOT
  sta z:OBJ_FLAGS
  lda #6
  sta z:SHIP_TIME
  a16
  lda #MOTION_SHIP_DIVE_WAIT
  jmp .loword(ship_next)
; ship_dive_wait: wait, then aim.
ship_dive_wait:
.a16
  a8
  lda z:SHIP_TIME
  beq @next
  dec z:SHIP_TIME
  a16
  lda #MOTION_SHIP_DIVE_WAIT
  jmp .loword(ship_next)
@next:
.a8
  a16
  lda #MOTION_SHIP_DIVE_AIM
  jmp .loword(ship_next)
; ship_dive_aim: turn toward the player for 5 more decisions.
ship_dive_aim:
.a16
  a8
  lda #5
  sta z:SHIP_TIME
  jsr .loword(ship_turn)
  bra ship_dive_pointer
; ship_dive_reaim: turn while SHIP_TIME lasts, then leave the dive by the
; side of the heading (once).
ship_dive_reaim:
.a16
  a8
  lda z:SHIP_TIME
  beq @leave
  dec z:SHIP_TIME
  jsr .loword(ship_turn)
  bra ship_dive_pointer
@leave:
  lda z:SHIP_DIVE_DONE
  bne ship_dive_pointer
  lda #10
  sta z:SHIP_TIME
  lda z:SHIP_HEADING
  cmp #DIRECTIONS/2
  a16
  lda #MOTION_SHIP_DIVE_LEAVE
  bcc :+
  lda #MOTION_SHIP_DIVE_LEAVE_HIGH
:
  jmp .loword(ship_next)
; ship_dive_pointer: the ship_dive_paths path of the heading.
ship_dive_pointer:
.a8
  a16
  lda z:SHIP_HEADING
  and #DIRECTIONS-1
  asl
  tax
  lda f:ship_dive_paths,x
  jmp .loword(ship_next)
; ship_dive_turn_end: the turn of the leave, then straight down in a loop.
ship_dive_turn_end:
.a16
  a8
  lda z:SHIP_TIME
  beq @complete
  dec z:SHIP_TIME
  a16
  lda #MOTION_SHIP_DIVE_TURN
  jmp .loword(ship_next)
@complete:
.a8
  lda #DIRECTIONS/2             ; straight down
  sta z:SHIP_HEADING
  lda #6
  sta z:SHIP_TIME
  lda #$ff
  sta z:SHIP_DIVE_DONE
  a16
  lda #MOTION_SHIP_DIVE_LOOP
  jmp .loword(ship_next)
; ship_fire_half, ship_fire_quarter, ship_fire_eighth: fire with odds of
; 8, 4 or 2 in 16 (random stream 0, step $13), then continue.
ship_fire_half:
.a16
  a8
  lda #8
  bra ship_random_fire
ship_fire_quarter:
.a16
  a8
  lda #4
  bra ship_random_fire
ship_fire_eighth:
.a16
  a8
  lda #2
ship_random_fire:
.a8
  sta a:SHIP_FIRE_ODDS
  lda RANDOM_STATE
  clc
  adc #$13
  sta RANDOM_STATE
  and #15                       ; 0-15
  cmp a:SHIP_FIRE_ODDS
  bcs @continue
  jsr .loword(ship_shot)
@continue:
  a16
  lda AI_CONTINUE
  jmp .loword(ship_next)
; ship_homing_begin: the homing starts with contacts on.
ship_homing_begin:
.a16
  a8
  lda #OF_CONTACT|OF_SHOT
  sta z:OBJ_FLAGS
  a16
  lda #MOTION_SHIP_HOMING
  jmp .loword(ship_next)
; ship_homing_track: every SHIP_AIM_INTERVAL decisions turn toward the
; player (up to SHIP_TURN_LIMIT turns), and fire 1 time in 16 (random
; stream 0, step $77).
ship_homing_track:
.a16
  a8
  lda z:SHIP_TIME
  beq @aim
  dec z:SHIP_TIME
  bra @pointer
@aim:
  lda z:SHIP_AIM_INTERVAL
  sta z:SHIP_TIME
  lda z:SHIP_TURNS
  cmp #SHIP_TURN_LIMIT
  bcs @pointer
  inc z:SHIP_TURNS
  lda RANDOM_STATE
  pha
  clc
  adc #$77
  sta RANDOM_STATE
  pla
  and #15
  bne :+
  jsr .loword(ship_shot)
:
  jsr .loword(ship_turn)
@pointer:
  a16
  lda z:SHIP_HEADING
  and #DIRECTIONS-1
  asl
  tax
  lda f:ship_homing_paths,x
  jmp .loword(ship_next)
; ship_turn: turn the heading one step toward the player, the short way
; round (US arcade $3144). Returns carry 1 when the heading changed. JSR.
ship_turn:
.a8
  jsl ai_target_far
  cmp z:SHIP_HEADING
  beq @same
  lda z:SHIP_HEADING
  inc
  and #DIRECTIONS-1
  sta a:SHIP_TURN_NEXT
  lda z:OBJ_AIM
  sec
  sbc a:SHIP_TURN_NEXT
  and #DIRECTIONS-1
  cmp #DIRECTIONS/2
  bcs @decrement
  lda z:SHIP_HEADING
  inc
  bra @store
@decrement:
  lda z:SHIP_HEADING
  dec
@store:
  and #DIRECTIONS-1
  sta z:SHIP_HEADING
  sec
  rts
@same:
  clc
  rts

; ship_dive_hold: the aircraft rides on the ship (OF_CAMERA), no contacts.
ship_dive_hold:
.a16
  a8
  lda #OF_CAMERA
  sta z:OBJ_FLAGS
  a16
  lda #MOTION_SHIP_DIVE_HOLD
  jmp .loword(ship_next)
; ship_dive_delay: wait SHIP_TIME decisions, then the dive starts.
ship_dive_delay:
.a16
  a8
  lda z:SHIP_TIME
  bne :+
  jmp .loword(ship_dive_begin)
:
  dec z:SHIP_TIME
  a16
  lda #MOTION_SHIP_DIVE_DELAY
  jmp .loword(ship_next)
.assert SEQUENCE_ENTRY_SIZE = 3, error ; ship_sequence_index
