; The raid after a boss result (US arcade): for RAID_TICKS, a giant plane
; comes every RAID_WAIT updates. The spawn choices, the turn times and the
; paths are arcade data.
.a8
.i16
RAID_TICKS = 1800            ; 30 s at 60 updates
RAID_WAIT = 60               ; updates between the raid giants
RAID_STEPS = 14              ; game_raid_steps: the times, then the left turns, then the right turns
RAID_STRAIGHT = 0            ; RAID_TURN
RAID_LEFT = 1                ; RAID_TURN: heading - 1
RAID_RIGHT = 2               ; RAID_TURN: heading + 1
RAID_LEAVE_TIME = 255        ; RAID_TIME of a straight run or the departure

; game_raid_tick: one update of the raid (game_flow_tick, SEQ_RESULT): one
; of four extended spawns (game_raid_spawns, random stream 7, step $77) when
; four large slots are free. JSL.
game_raid_tick:
  a16
  lda GAME_SEQUENCE_TICKS
  cmp #RAID_TICKS
  a8
  bcc :+
  rtl
:
  lda STAGE_RAID_WAIT
  beq @ready
  dec STAGE_RAID_WAIT
  rtl
@ready:
  jsr .loword(giant_allocate)
  bcs :+
  rtl
:
  lda RANDOM_STATE+7
  pha
  clc
  adc #$77
  sta RANDOM_STATE+7
  pla
  and #3
  asl
  tax
  a16
  lda f:game_raid_spawns,x
  sta STAGE_CALLBACK
  a8
  stz STAGE_BANK
  lda #CONTROL_EXTENDED
  sta STAGE_CONTROL_INDEX
  jsl extended_spawn
  lda #RAID_WAIT
  sta STAGE_RAID_WAIT
  inc LARGE_THRESHOLD
  rtl

; The raid giant (a large object; D = its record, large_ai). Its family bytes:
RAID_HEADING = $10           ; the heading, 0-31
RAID_TIME = $11              ; decisions left of this step
RAID_STEP = $12              ; the game_raid_steps entry; counts down
RAID_LAPS = $13              ; laps left; the giant leaves after the last
RAID_TURN = $14              ; 0 straight, 1 heading - 1, else heading + 1
RAID_SIDE = $15              ; nonzero: the right step table
; game_raid_giant: turn by RAID_TURN until the heading is 0, then follow
; the RAID_STEPS steps of its side (time and turn), RAID_LAPS times; at steps
; 11 and 5 two carrier children may come (1 in 2, random stream 4, step $55,
; on the field); then the giant turns away and leaves.
game_raid_giant:
.a16
  a8
  lda RAID_TURN
  beq @timer                    ; RAID_STRAIGHT
  cmp #RAID_LEFT
  beq @turn_left
  lda RAID_HEADING
  inc
  bra @heading
@turn_left:
  lda RAID_HEADING
  dec
@heading:
  and #DIRECTIONS-1
  sta RAID_HEADING
  bne @timer
  stz RAID_TURN                 ; RAID_STRAIGHT
  lda #RAID_LEAVE_TIME
  sta RAID_TIME
  bra @select
@timer:
  dec RAID_TIME
  bne @select
  a16
  lda RAID_STEP
  and #255
  tax
  a8
  lda RAID_SIDE
  beq @left_steps
  lda f:game_raid_steps+2*RAID_STEPS,x
  bra @step
@left_steps:
  lda f:game_raid_steps+RAID_STEPS,x
@step:
  sta RAID_TURN
  lda f:game_raid_steps,x
  sta RAID_TIME
  dec RAID_STEP
  bmi @lap
  lda RAID_STEP
  cmp #11
  beq @children
  cmp #5
  bne @select
@children:
  lda RANDOM_STATE+4
  clc
  adc #$55
  sta RANDOM_STATE+4
  and #1
  bne @select
  lda SPR_ATTR
  and #SPR_ALONG_HIGH
  bne @select
  lda #0
  jsr .loword(game_carrier_child_spawn)
  lda #1
  jsr .loword(game_carrier_child_spawn)
  bra @select
@lap:
  dec RAID_LAPS
  beq @depart
  lda #RAID_STEPS-1
  sta RAID_STEP
  bra @select
@depart:
  lda #RAID_LEAVE_TIME
  sta RAID_TIME
  lda RAID_SIDE
  beq :+
  lda #RAID_LEFT
  bra @mode
:
  lda #RAID_RIGHT
@mode:
  sta RAID_TURN
@select:
  a16
  lda RAID_HEADING
  and #DIRECTIONS-1
  asl
  tax
  lda f:game_raid_paths,x
  jmp .loword(large_ai_selected)
