; The decisions of the later-stage aircraft (large objects; D = the record,
; large_ai): the sway, the turning aircraft and the carrier giant with its
; children. The paths are arcade motion data.
.a8
.i16
SWAY_DOWN = 0                ; LATER_PHASE of the sway
SWAY_PAUSE = 1
SWAY_UP = 2
TURNING_APPROACH = 0         ; LATER_PHASE of the turning aircraft
TURNING_TURN = 1
TURNING_STRAIGHT = 2
CARRIER_UP = 0               ; LATER_PHASE of the carrier giant
CARRIER_PAUSE = 1
CARRIER_DOWN = 2
TRIPLE_DIP_LEVEL = 9         ; game_sway_aircraft: from this STAGE_DIP_LEVEL three shots
PAUSE_TIME = 12              ; LATER_TIME after a pause
CHILD_OFFSET = 16            ; a carrier child starts this far above (and left)

; The family bytes of the object record for these aircraft.
LATER_HEADING = $10          ; the heading, 0-31
LATER_TIME = $11             ; decisions left of this phase
LATER_PHASE = $12            ; sway: 0 down, 1 pause, 2 up; turning: 0 approach,
                             ; 1 turn, 2 straight; carrier: 0 up, 1 pause, 2 down
LATER_PAUSES = $13           ; sway, carrier: pauses left
TURNING_DIRECTION = $13      ; game_turning_aircraft: 0 heading + 1, else heading - 1
LATER_COUNT = $14            ; turning: approach steps; carrier: headings since the turn
MOTION_CARRIER_CHILD_RIGHT = $9a49 ; bank 0: the right child of game_carrier_giant
; game_sway_aircraft: down, pause, up, pause, in a loop; at the end of the
; way up it fires (above the player, or 1 time in 256: random stream 1, step
; $55): three shots from TRIPLE_DIP_LEVEL, else one.
game_sway_aircraft:
.a16
  a8
  lda LATER_PHASE
  beq @down                     ; SWAY_DOWN
  cmp #SWAY_PAUSE
  beq @pause
  dec LATER_TIME
  bne @up_step
  jsl ai_target_far
  lda SPR_ALONG
  cmp PLAYER+SPR_ALONG,y
  bcc @shoot
  lda RANDOM_STATE+1
  pha
  clc
  adc #$55
  sta RANDOM_STATE+1
  pla
  bne @pause_up
@shoot:
  lda STAGE_DIP_LEVEL
  cmp #TRIPLE_DIP_LEVEL
  bcc @single
  jsr .loword(game_aircraft_triple)
  bra @pause_up
@single:
  jsr .loword(large_plane_shot)
@pause_up:
  stz LATER_PAUSES
  jsr .loword(game_sway_pause)
@up_step:
  inc LATER_HEADING
  bra @select
@down:
  dec LATER_TIME
  bne @down_step
  lda #1
  sta LATER_PAUSES
  jsr .loword(game_sway_pause)
@down_step:
  dec LATER_HEADING
  bra @select
@pause:
  dec LATER_TIME
  bne @select
  lda #PAUSE_TIME
  sta LATER_TIME
  stz LATER_PHASE               ; SWAY_DOWN
  dec LATER_PAUSES
  bne @select
  lda #SWAY_UP
  sta LATER_PHASE
@select:
  a16
  lda LATER_HEADING
  and #DIRECTIONS-1
  asl
  tax
  lda f:game_sway_quad_paths,x
  jmp .loword(large_ai_selected)
; game_sway_pause: a pause of 3 decisions. JSR.
game_sway_pause:
.a8
  lda #3
  sta LATER_TIME
  lda #SWAY_PAUSE
  sta LATER_PHASE
  rts

; game_turning_aircraft: the approach (a 1 in 16 shot each 5 decisions),
; the turn of 32 headings (shots at every eighth heading), then straight.
game_turning_aircraft:
.a16
  a8
  lda LATER_PHASE
  beq @approach                 ; TURNING_APPROACH
  cmp #TURNING_TURN
  beq @turn
  dec LATER_TIME
  bne @select
  lda #1
  jsr .loword(game_turn_random)
  lda #255
  sta LATER_TIME
  bra @select
@approach:
  dec LATER_TIME
  bne @select
  dec LATER_COUNT
  beq @begin
  lda #1
  sta LATER_COUNT
  jsr .loword(game_turn_random)
  lda #5
  sta LATER_TIME
  bra @select
@begin:
  lda #TURNING_TURN
  sta LATER_PHASE
  lda #DIRECTIONS
  sta LATER_TIME
  stz LATER_COUNT
  bra @select
@turn:
  lda TURNING_DIRECTION
  beq @plus
  lda LATER_HEADING
  dec
  bra @heading
@plus:
  lda LATER_HEADING
  inc
@heading:
  and #DIRECTIONS-1
  sta LATER_HEADING
  dec LATER_TIME
  bne @maybe_fire
  lda #6
  sta LATER_TIME
  lda #TURNING_STRAIGHT
  sta LATER_PHASE
  bra @select
@maybe_fire:
  and #7                        ; headings 4, 12, 20, 28
  cmp #4
  bne @select
  lda LATER_COUNT
  beq @three
  cmp #3
  beq @three
  lda #4
  bra @chance
@three:
  lda #3
@chance:
  jsr .loword(game_turn_random)
@select:
  a16
  lda LATER_HEADING
  and #DIRECTIONS-1
  asl
  tax
  lda f:game_turning_quad_paths,x
  jmp .loword(large_ai_selected)
; game_turn_random: a plane shot with odds of A in 16 (random stream 1,
; step $55). JSR.
game_turn_random:
.a8
  sta a:TURN_ODDS
  lda RANDOM_STATE+1
  pha
  clc
  adc #$55
  sta RANDOM_STATE+1
  pla
  and #15
  cmp a:TURN_ODDS
  bcs @done
  jsr .loword(large_plane_shot)
@done:
  rts

; game_carrier_giant: up and down with pauses; at heading 0 (after the
; first) on the field it sends out two carrier children.
game_carrier_giant:
.a16
  a8
  lda LATER_PHASE
  cmp #CARRIER_PAUSE
  beq @pause
  dec LATER_TIME
  bne @moving
  lda #11
  sta LATER_TIME
  lda LATER_PHASE
  lsr
  sta LATER_PAUSES
  pha
  lda #CARRIER_PAUSE
  sta LATER_PHASE
  pla
  beq @up_no_fire
  lda LATER_HEADING
  dec
  bra @store
@up_no_fire:
  lda LATER_HEADING
  inc
@store:
  and #DIRECTIONS-1
  sta LATER_HEADING
  bra @select
@moving:
  lda LATER_PHASE
  beq @up
  lda LATER_HEADING
  dec
  bra @fire_heading
@up:
  lda LATER_HEADING
  inc
@fire_heading:
  and #DIRECTIONS-1
  sta LATER_HEADING
  bne @select
  lda LATER_COUNT
  beq @armed
  lda SPR_ATTR
  and #SPR_ALONG_HIGH
  bne @armed
  lda #0
  jsr .loword(game_carrier_child_spawn)
  lda #1
  jsr .loword(game_carrier_child_spawn)
@armed:
  inc LATER_COUNT
  bra @select
@pause:
  dec LATER_TIME
  bne @select
  lda #PAUSE_TIME
  sta LATER_TIME
  stz LATER_PHASE               ; CARRIER_UP
  dec LATER_PAUSES
  beq @select
  lda #CARRIER_DOWN
  sta LATER_PHASE
@select:
  a16
  lda LATER_HEADING
  and #DIRECTIONS-1
  asl
  tax
  lda f:game_carrier_giant_paths,x
  jmp .loword(large_ai_selected)

; game_carrier_child_spawn: a carrier child A (0 left, 1 right) in an
; extended slot, CHILD_OFFSET above the object D (the left one also to the
; left); the right one starts at heading 1 on its own path. JSR.
game_carrier_child_spawn:
.a8
  pha
  phd
  pea .loword(ZERO_PAGE)
  pld
  jsr .loword(extended_allocate)
  pld
  pla
  bcs :+
  rts
:
  sta a:CHILD_SIDE
  a16
  .repeat OBJECT_SIZE/2,I
    lda f:game_carrier_child_template+I*2
    sta a:I*2,x
  .endrepeat
  a8
  lda SPR_ALONG
  sec
  sbc #CHILD_OFFSET
  sta a:SPR_ALONG,x
  lda a:CHILD_SIDE
  cmp #1
  beq @right
  lda SPR_CROSS
  sec
  sbc #CHILD_OFFSET
  sta a:SPR_CROSS,x
  rts
@right:
  lda SPR_CROSS
  sta a:SPR_CROSS,x
  lda #1
  sta a:FORMATION_HEADING,x
  a16
  lda #MOTION_CARRIER_CHILD_RIGHT
  sta a:OBJ_MOTION,x
  a8
@done:
  rts
