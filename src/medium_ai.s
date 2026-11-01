; The decisions of the homing and diving fighters (US arcade bank 0): the
; medium objects. Called from enemy_ai with the same record (D). Each
; returns carry 1 with AI_NEXT, or carry 0 for a tail that is not theirs.
.a8
.i16
DIRECTIONS = 32              ; OBJ_AIM and the return directions: 32 steps a circle
HOME_PURSUIT = 1             ; MEDIUM_HOME_PHASE: aim again after MEDIUM_DELAY
HOME_DIVE = 2                ; MEDIUM_HOME_PHASE: dive
HOME_PURSUIT_DELAY = 6       ; MEDIUM_DELAY of the pursuit
HOME_DIVE_DELAY = 8          ; MEDIUM_DELAY of the dive
HOME_DIVE_GAP = $28          ; the dive ends this close along to the player
FIRE_ANGLE_MIN = 8           ; medium_fire: the bullet angle is limited to
FIRE_ANGLE_MAX = 24          ; FIRE_ANGLE_MIN..FIRE_ANGLE_MAX
MEDIUM_DIVE_ALONG = $a0             ; medium_dive: a player at this along or lower: hold
MEDIUM_TURN_GAP = 32                ; medium_turn: closer along than this: turn to a side
MEDIUM_SIDE_FAR = 64                ; medium_side: farther to the side than this: the far path

; The family bytes of the object record for these fighters.
MEDIUM_PATH = $10            ; the selected path; medium_return: the direction, 0-31
MEDIUM_DELAY = $11           ; decisions left before the next turn or aim
MEDIUM_HOME_POINTER = $12    ; medium_home: the motion record, high byte first
MEDIUM_TURN_DELAY = $12      ; medium_dive, medium_return: MEDIUM_DELAY after each turn
MEDIUM_HOME_PHASE = $14      ; medium_home: 0 wait, 1 pursuit, 2 dive

; The bank-0 motion code tails of these fighters (AI_TAIL).
TAIL_MEDIUM_HOME = $8054
TAIL_MEDIUM_FIRE = $80d8
TAIL_MEDIUM_DIVE = $8eba
TAIL_MEDIUM_TURN = $8ee8
TAIL_MEDIUM_LOOP5 = $8f21
TAIL_MEDIUM_LOOP6 = $8f35
TAIL_MEDIUM_LOOP = $8f60
TAIL_MEDIUM_HOLD = $8f8c
TAIL_MEDIUM_AIM = $8fbe
TAIL_MEDIUM_RETURN = $90e0

; Bank-0 motion records that these decisions select (AI_NEXT).
MOTION_MEDIUM_WAIT = $81c4   ; medium_home: wait before the aim
MOTION_MEDIUM_LEAVE = $8219  ; medium_home: leave the dive
MOTION_MEDIUM_HOLD = $8ff8   ; medium_hold: hold
MOTION_MEDIUM_LOOP_RIGHT = $908e ; medium_loop: leave to the side of the larger cross
MOTION_MEDIUM_LOOP_LEFT = $90b7  ; medium_loop: leave to the other side

; medium_ai: the decision of AI_TAIL for a medium object. JSL.
medium_ai:
  a16
  lda AI_TAIL
  cmp #TAIL_MEDIUM_HOME
  bne :+
  jmp .loword(medium_home)
:
  cmp #TAIL_MEDIUM_FIRE
  bne :+
  jmp .loword(medium_fire)
:
  cmp #TAIL_MEDIUM_DIVE
  bne :+
  jmp .loword(medium_dive)
:
  cmp #TAIL_MEDIUM_TURN
  bne :+
  jmp .loword(medium_turn)
:
  cmp #TAIL_MEDIUM_LOOP5
  bne :+
  a8
  lda z:MEDIUM_PATH
  beq medium_loop_short
  lda #5                        ; the medium_dive_paths entry
  bra medium_loop_begin
:
  .a16
  cmp #TAIL_MEDIUM_LOOP6
  bne :+
  a8
  lda z:MEDIUM_PATH
  beq medium_loop_short
  lda #6                        ; the medium_dive_paths entry
  bra medium_loop_begin
:
  .a16
  cmp #TAIL_MEDIUM_LOOP
  bne :+
  jmp .loword(medium_loop)
:
  cmp #TAIL_MEDIUM_HOLD
  bne :+
  jmp .loword(medium_hold)
:
  cmp #TAIL_MEDIUM_RETURN
  bne :+
  jmp .loword(medium_return)
:
  cmp #TAIL_MEDIUM_AIM
  bne @unknown
  a8
  lda MEDIUM_RANDOM
  bmi medium_continue
  jsl ai_target_far
  lda #AIF_AIMED
  sta AI_FIRE
  bra medium_continue
@unknown:
  a8
  clc
  rtl

; medium_loop_begin: the loop path A for a random time (medium_delays).
medium_loop_short:
.a8
  lda #4                        ; the medium_dive_paths entry
medium_loop_begin:
  sta z:MEDIUM_PATH
  a16
  lda MEDIUM_RANDOM
  and #3                        ; four medium_delays
  tax
  a8
  lda f:medium_delays,x
  sta z:MEDIUM_DELAY
  lda z:MEDIUM_PATH
  jmp .loword(medium_select)
; medium_continue: the record after the tail. medium_next: AI_NEXT = A.
medium_continue:
  a16
  lda AI_CONTINUE
medium_next:
  sta AI_NEXT
  a8
  sec
  rtl

; medium_home: wait MEDIUM_DELAY, aim at the player (medium_home_paths of
; OBJ_AIM), aim again, then dive until the player is near or passed.
medium_home:
.a16
  a8
  lda z:MEDIUM_HOME_PHASE
  cmp #HOME_PURSUIT
  beq @pursuit
  cmp #HOME_DIVE
  beq @dive
  lda z:MEDIUM_DELAY
  beq @aim
  dec z:MEDIUM_DELAY
  a16
  lda #MOTION_MEDIUM_WAIT
  bra medium_next
@aim:
  .a8
  jsl ai_target_far
  lda #HOME_PURSUIT
  sta z:MEDIUM_HOME_PHASE
  lda #HOME_PURSUIT_DELAY
  sta z:MEDIUM_DELAY
  ldy #0                        ; the pursuit paths
  bra @angle
@pursuit:
  .a8
  lda z:MEDIUM_DELAY
  beq @second_aim
  dec z:MEDIUM_DELAY
  bra @cached
@second_aim:
  .a8
  jsl ai_target_far
  lda #HOME_DIVE
  sta z:MEDIUM_HOME_PHASE
  lda #HOME_DIVE_DELAY
  sta z:MEDIUM_DELAY
  ldy #DIRECTIONS*2             ; the dive paths
@angle:
  .a8
  a16
  lda z:OBJ_AIM
  and #DIRECTIONS-1
  asl
  sta a:MEDIUM_PATH_OFFSET
  tya
  clc
  adc a:MEDIUM_PATH_OFFSET
  tax
  lda f:medium_home_paths,x
  sta AI_NEXT
  xba
  sta z:MEDIUM_HOME_POINTER
  a8
  sec
  rtl
@dive:
  .a8
  lda z:MEDIUM_DELAY
  beq @leave
  dec z:MEDIUM_DELAY
  jsl ai_target_far
  lda z:SPR_ALONG
  sec
  sbc PLAYER+SPR_ALONG,y
  bcc @leave
  cmp #HOME_DIVE_GAP
  bcc @leave
@cached:
  .a8
  a16
  lda z:MEDIUM_HOME_POINTER
  xba
  jmp .loword(medium_next)
@leave:
  .a8
  a16
  lda #MOTION_MEDIUM_LEAVE
  jmp .loword(medium_next)

; medium_fire: fire at the player; the bullet angle is limited, OBJ_AIM is
; not (as in the arcade).
medium_fire:
.a16
  a8
  jsl ai_target_far
  cmp #FIRE_ANGLE_MIN
  bcs :+
  lda #FIRE_ANGLE_MIN
:
  cmp #FIRE_ANGLE_MAX+1
  bcc :+
  lda #FIRE_ANGLE_MAX
:
  sta MEDIUM_SHOT_ANGLE
  lda #AIF_ANGLE
  sta AI_FIRE
  jmp .loword(medium_continue)

; medium_dive: dive at the player (path 0), or hold (path 1) for a random
; time when the player is low on the field.
medium_dive:
.a16
  a8
  jsl ai_target_far
  lda PLAYER+SPR_ALONG,y
  cmp #MEDIUM_DIVE_ALONG
  bcs @hold
  lda #2
  sta z:MEDIUM_TURN_DELAY
  lda #0                        ; the medium_dive_paths entry
  bra medium_select
@hold:
  lda #1
  sta z:MEDIUM_TURN_DELAY
  lda MEDIUM_RANDOM
  bpl :+
  lda #10
  bra @delay
:
  lda #4
@delay:
  sta z:MEDIUM_DELAY
  lda #1                        ; the medium_dive_paths entry
  bra medium_select

; medium_turn: dive (path 0), or turn to the side when the player is near
; along. medium_side: path 2 (right) or 3 (left); MEDIUM_PATH = 1 when the
; player is far to that side.
medium_turn:
.a16
  a8
  jsl ai_target_far
  lda PLAYER+SPR_ALONG,y
  clc
  adc #MEDIUM_TURN_GAP
  cmp z:SPR_ALONG
  bcs medium_side
  lda #0
  bra medium_select
medium_side:
  stz z:MEDIUM_PATH
  lda z:SPR_CROSS
  sec
  sbc PLAYER+SPR_CROSS,y
  bcs @left
  eor #$ff
  inc
  cmp #MEDIUM_SIDE_FAR
  bcc :+
  inc z:MEDIUM_PATH
:
  lda #2
  bra medium_select
@left:
  cmp #MEDIUM_SIDE_FAR
  bcc :+
  inc z:MEDIUM_PATH
:
  lda #3
; medium_select: AI_NEXT = the medium_dive_paths entry A.
medium_select:
  a16
  and #255
  asl
  tax
  lda f:medium_dive_paths,x
  jmp .loword(medium_next)

; medium_loop: loop MEDIUM_DELAY times, then leave to the side away from
; the player.
medium_loop:
.a16
  a8
  lda z:MEDIUM_DELAY
  beq @leave
  dec z:MEDIUM_DELAY
  lda z:MEDIUM_PATH
  bra medium_select
@leave:
  lda #DIRECTIONS/2             ; medium_return starts straight down
  sta z:MEDIUM_PATH
  stz z:MEDIUM_DELAY
  jsl ai_target_far
  lda z:SPR_CROSS
  cmp PLAYER+SPR_CROSS,y
  a16
  lda #MOTION_MEDIUM_LOOP_RIGHT
  bcc :+
  lda #MOTION_MEDIUM_LOOP_LEFT
:
  jmp .loword(medium_next)

; medium_hold: hold MEDIUM_DELAY times, then turn to a side.
medium_hold:
.a16
  a8
  lda z:MEDIUM_DELAY
  beq @side
  dec z:MEDIUM_DELAY
  a16
  lda #MOTION_MEDIUM_HOLD
  jmp .loword(medium_next)
@side:
  .a8
  jsl ai_target_far
  jmp .loword(medium_side)

; medium_delays: the loop times of medium_loop_begin.
medium_delays:
  .byte $14,$10,$14,$18

; medium_return: every MEDIUM_TURN_DELAY decisions, turn one direction step
; (MEDIUM_PATH, 0 to DIRECTIONS-1) toward the player, the short way round
; (US arcade $90E0-$911F and $3144).
medium_return:
.a16
  a8
  lda z:MEDIUM_DELAY
  beq @aim
  dec z:MEDIUM_DELAY
  bra @pointer
@aim:
  lda z:MEDIUM_TURN_DELAY
  sta z:MEDIUM_DELAY
  jsl ai_target_far
  cmp z:MEDIUM_PATH
  beq @pointer
  lda z:MEDIUM_PATH
  inc
  and #DIRECTIONS-1
  sta a:MEDIUM_NEXT_DIRECTION
  lda z:OBJ_AIM
  sec
  sbc a:MEDIUM_NEXT_DIRECTION
  and #DIRECTIONS-1
  cmp #DIRECTIONS/2
  bcs @decrement
  lda z:MEDIUM_PATH
  inc
  bra @store
@decrement:
  lda z:MEDIUM_PATH
  dec
@store:
  and #DIRECTIONS-1
  sta z:MEDIUM_PATH
@pointer:
  a16
  lda z:MEDIUM_PATH
  and #255
  asl
  tax
  lda f:medium_return_paths,x
  jmp .loword(medium_next)
