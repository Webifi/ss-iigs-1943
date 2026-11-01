; The decisions of the one-piece formation planes (US arcade bank 0
; $82D7/$82EF, bank 4 $9707/$9ACF/$9EB5, bank 6 $8CDC): they fire, spiral,
; pursue and turn by the heading (formation_paths of FORMATION_TYPE). D = the
; object record. Each returns carry 1 with AI_NEXT, or carry 0.
.a8
.i16
; FORMATION_TYPE: the formation_paths group (DIRECTIONS paths of 2 bytes).
FT_SPIRAL = 0
FT_SECOND_SPIRAL = 1
FT_PURSUIT = 2
FT_BANK_SIX = 3
SPIRAL_SEARCH = 0            ; FORMATION_PHASE of a spiral: aim at the player
SPIRAL_ARC = 1               ; FORMATION_PHASE of a spiral: turn in an arc
SPIRAL_START = 2             ; FORMATION_PHASE of a spiral: wait, then the arc
TURN_UP = 0                  ; FORMATION_TURN: heading + 1
TURN_DOWN = 1                ; FORMATION_TURN: heading - 1
TURN_KEEP = 2                ; FORMATION_TURN: no turn
ARC_STEPS = 18               ; the arc steps of FT_SPIRAL
SECOND_ARC_STEPS = 26        ; the arc steps of FT_SECOND_SPIRAL
ARC_STEP_TIME = 3            ; decisions of an arc or search step
SEARCH_STEPS = 17            ; the aim steps of the search
HARD_DIP_LEVEL = 10          ; formation_pursuit: from this STAGE_DIP_LEVEL the turns are faster
COAST_TIME = 255             ; formation_pursuit: decisions of the straight flight
BANK_SIX_STEPS = 12          ; formation_bank_six: no step after this many
BANK_SIX_STEP_TIME = 4

; The family bytes of the object record for these formations.
FORMATION_HEADING = $10      ; the heading, 0-31
FORMATION_PHASE = $11        ; spiral: 0 search, 1 arc, 2 start; pursuit: 0 coast, 1 aim
FORMATION_START = $11        ; formation_bank_six: decisions before the first step
FORMATION_TIMER = $12        ; decisions left of this step
FORMATION_COUNT = $13        ; steps left; formation_bank_six: steps done
FORMATION_TURN = $14         ; formation_turn: 0 heading + 1, 1 heading - 1, 2 keep
FORMATION_FIRED = $14        ; formation_bank_six: the first step is done

; Motion code tails (AI_TAIL) and motion records (AI_NEXT).
TAIL_FORMATION_LEFT = $82d7  ; bank 0
TAIL_FORMATION_RIGHT = $82ef ; bank 0
MOTION_FORMATION_LEFT = $8342  ; bank 0
MOTION_FORMATION_RIGHT = $83b1 ; bank 0
TAIL_FORMATION_SPIRAL = $9707  ; bank 4
TAIL_FORMATION_SECOND_SPIRAL = $9acf ; bank 4
TAIL_FORMATION_PURSUIT = $9eb5 ; bank 4
TAIL_FORMATION_RANDOM_FIRE = $9f4f ; bank 4
TAIL_FORMATION_BANK_SIX = $8cdc ; bank 6

; formation_ai: the decision of AI_TAIL for a formation plane (enemy_ai);
; the multi-piece formations first (formation_extra). JSL.
formation_ai:
  jsl formation_extra
  bcc :+
  rtl
:
  a16
  lda z:OBJ_VARIANT
  and #OBJ_BANK_BITS
  beq @bank_zero
  cmp #4<<4                     ; motion bank 4
  beq @bank_four
  cmp #6<<4                     ; motion bank 6
  bne @unknown
  lda AI_TAIL
  cmp #TAIL_FORMATION_BANK_SIX
  bne @unknown
  a8
  lda #FT_BANK_SIX
  sta FORMATION_TYPE
  jmp .loword(formation_bank_six)
@bank_zero:
.a16
  lda AI_TAIL
  cmp #TAIL_FORMATION_LEFT
  beq @left
  cmp #TAIL_FORMATION_RIGHT
  bne @unknown
  a8
  jsr .loword(formation_fire)
  a16
  lda #MOTION_FORMATION_RIGHT
  bra @next
@left:
  a8
  jsr .loword(formation_fire)
  a16
  lda #MOTION_FORMATION_LEFT
@next:
  sta AI_NEXT
  a8
  sec
  rtl
@bank_four:
.a16
  lda AI_TAIL
  cmp #TAIL_FORMATION_SPIRAL
  beq @spiral
  cmp #TAIL_FORMATION_SECOND_SPIRAL
  beq @second_spiral
  cmp #TAIL_FORMATION_PURSUIT
  beq @pursuit
  cmp #TAIL_FORMATION_RANDOM_FIRE
  bne @unknown
  a8
  lda #8                        ; 8 in 16
  jsr .loword(formation_random_fire)
  a16
  lda AI_CONTINUE
  bra @next
@spiral:
  a8
  stz FORMATION_TYPE          ; FT_SPIRAL
  jmp .loword(formation_spiral)
@second_spiral:
  a8
  lda #FT_SECOND_SPIRAL
  sta FORMATION_TYPE
  jmp .loword(formation_spiral)
@pursuit:
  a8
  lda #FT_PURSUIT
  sta FORMATION_TYPE
  jmp .loword(formation_pursuit)
@unknown:
  a8
  clc
  rtl

; formation_select: AI_NEXT = the formation_paths path of FORMATION_TYPE and
; the heading; carry 1. JSL end.
formation_select:
.a8
  a16
  lda FORMATION_TYPE
  and #255
  asl
  asl
  asl
  asl
  asl
  asl                           ; times DIRECTIONS * 2
  sta a:FORMATION_PATH_OFFSET
  lda z:FORMATION_HEADING
  and #DIRECTIONS-1
  asl
  clc
  adc a:FORMATION_PATH_OFFSET
  tax
  lda f:formation_paths,x
  sta AI_NEXT
  a8
  sec
  rtl

; formation_fire: fire at the player. JSR.
formation_fire:
.a8
  jsl ai_target_far
  lda #AIF_AIMED
  sta AI_FIRE
  rts
; formation_random_fire: fire with odds of A in 16 (random stream 2, step
; $55). JSR.
formation_random_fire:
  sta FORMATION_ODDS
  lda RANDOM_STATE+2
  pha
  clc
  adc #$55
  sta RANDOM_STATE+2
  pla
  and #15
  cmp FORMATION_ODDS
  bcs @done
  jsr .loword(formation_fire)
@done:
  rts
; formation_turn: the heading turns by FORMATION_TURN. JSR.
formation_turn:
  lda z:FORMATION_TURN
  beq @increase                 ; TURN_UP
  cmp #TURN_DOWN
  bne @done
  lda z:FORMATION_HEADING
  dec
  bra @store
@increase:
  lda z:FORMATION_HEADING
  inc
@store:
  and #DIRECTIONS-1
  sta z:FORMATION_HEADING
@done:
  rts
; formation_aim_turn: FORMATION_TURN = the short way round to the player,
; then the turn. JSR.
formation_aim_turn:
  jsl ai_target_far
  cmp z:FORMATION_HEADING
  beq @straight
  sta a:TURN_TARGET
  lda z:FORMATION_HEADING
  inc
  and #DIRECTIONS-1
  sta a:TURN_NEXT
  lda a:TURN_TARGET
  sec
  sbc a:TURN_NEXT
  and #DIRECTIONS-1
  cmp #DIRECTIONS/2
  lda #TURN_UP
  bcc @set
  inc                           ; TURN_DOWN
  bra @set
@straight:
  lda #TURN_KEEP
@set:
  sta z:FORMATION_TURN
  jmp .loword(formation_turn)

; formation_spiral: the spiral: the start waits, the arc turns a step every
; ARC_STEP_TIME decisions and fires at some headings, the search aims at the
; player SEARCH_STEPS times; then the spiral starts again.
formation_spiral:
  lda z:FORMATION_PHASE
  bne :+
  jmp .loword(@search)          ; SPIRAL_SEARCH
:
  cmp #SPIRAL_ARC
  beq @arc
  dec z:FORMATION_TIMER         ; SPIRAL_START
  beq :+
  jmp .loword(formation_select)
:
  lda #1
  sta z:FORMATION_TIMER
  lda FORMATION_TYPE
  beq :+
  lda #SECOND_ARC_STEPS
  bra @arc_count
:
  lda #ARC_STEPS
@arc_count:
  sta z:FORMATION_COUNT
  dec z:FORMATION_PHASE
  jmp .loword(formation_select)
@arc:
  dec z:FORMATION_TIMER
  beq :+
  jmp .loword(formation_select)
:
  dec z:FORMATION_COUNT
  beq @search_begin
  lda #ARC_STEP_TIME
  sta z:FORMATION_TIMER
  jsr .loword(formation_turn)
  ; The arcade fires at these headings.
  lda FORMATION_TYPE
  bne @second_fire
  lda z:FORMATION_HEADING
  cmp #12
  beq @odds_four
  cmp #20
  beq @odds_four
  jmp .loword(formation_select)
@second_fire:
  lda z:FORMATION_HEADING
  beq @odds_even
  cmp #28
  beq @odds_four
  cmp #4
  beq @odds_two
  cmp #8
  beq @odds_two
  cmp #12
  beq @odds_two
  jmp .loword(formation_select)
@odds_even:
  lda RANDOM_STATE+2            ; random stream 2, step $55: 1 in 2
  pha
  clc
  adc #$55
  sta RANDOM_STATE+2
  pla
  and #1
  bne @selected
  jsr .loword(formation_fire)
  bra @selected
@odds_four:
  lda #4
  bra @random
@odds_two:
  lda #2
@random:
  jsr .loword(formation_random_fire)
@selected:
  jmp .loword(formation_select)
@search_begin:
  ; The search: FORMATION_TIMER counts the aim steps, FORMATION_COUNT the
  ; decisions of a step.
  lda #1
  sta z:FORMATION_COUNT
  lda #SEARCH_STEPS
  sta z:FORMATION_TIMER
  dec z:FORMATION_PHASE         ; SPIRAL_SEARCH
  bra @selected
@search:
  dec z:FORMATION_COUNT
  bne @selected
  lda #ARC_STEP_TIME
  sta z:FORMATION_COUNT
  dec z:FORMATION_TIMER
  beq @restart
  lda z:FORMATION_TIMER
  and #1
  bne :+
  lda #2                        ; 2 in 16 on every second step
  jsr .loword(formation_random_fire)
:
  jsr .loword(formation_aim_turn)
  jmp .loword(formation_select)
@restart:
  lda #SPIRAL_START
  sta z:FORMATION_PHASE
  stz z:FORMATION_TIMER
  bra @selected

; formation_pursuit: aim at the player FORMATION_COUNT times (faster from
; HARD_DIP_LEVEL), then fly straight for COAST_TIME decisions.
formation_pursuit:
  lda z:FORMATION_PHASE
  beq @coast
  dec z:FORMATION_TIMER
  bne @done
  dec z:FORMATION_COUNT
  beq @coast_begin
  lda STAGE_DIP_LEVEL
  cmp #HARD_DIP_LEVEL
  lda #3
  bcs :+
  inc
:
  sta z:FORMATION_TIMER
  jsr .loword(formation_aim_turn)
  jmp .loword(formation_select)
@coast_begin:
  lda #COAST_TIME
  sta z:FORMATION_TIMER
  stz z:FORMATION_PHASE
  bra @done
@coast:
  dec z:FORMATION_TIMER
  bne @done
  lda #1
  sta z:FORMATION_PHASE
  sta z:FORMATION_TIMER
@done:
  jmp .loword(formation_select)

; formation_bank_six: after FORMATION_START decisions, a step every
; BANK_SIX_STEP_TIME decisions (up to BANK_SIX_STEPS): fire (7 in 16 for the
; first step, else 1 in 16), then turn one step toward the player.
formation_bank_six:
  lda z:FORMATION_COUNT
  cmp #BANK_SIX_STEPS
  bcs @done
  lda z:FORMATION_START
  beq @delay
  dec z:FORMATION_START
  bra @done
@delay:
  lda z:FORMATION_TIMER
  beq @step
  dec z:FORMATION_TIMER
  bra @done
@step:
  lda #BANK_SIX_STEP_TIME
  sta z:FORMATION_TIMER
  inc z:FORMATION_COUNT
  lda z:FORMATION_FIRED
  bne @later_fire
  inc z:FORMATION_FIRED
  lda RANDOM_STATE              ; random stream 0, step $13
  clc
  adc #$13
  sta RANDOM_STATE
  and #15
  cmp #7
  bcs @turn
  bra @fire
@later_fire:
  lda RANDOM_STATE+1            ; random stream 1, step $42
  clc
  adc #$42
  sta RANDOM_STATE+1
  and #15
  bne @turn
@fire:
  jsr .loword(formation_fire)
@turn:
  ; The turn of formation_aim_turn, without FORMATION_TURN: the same byte
  ; is FORMATION_FIRED here.
  jsl ai_target_far
  cmp z:FORMATION_HEADING
  beq @done
  sta a:TURN_TARGET
  lda z:FORMATION_HEADING
  inc
  and #DIRECTIONS-1
  sta a:TURN_NEXT
  lda a:TURN_TARGET
  sec
  sbc a:TURN_NEXT
  and #DIRECTIONS-1
  cmp #DIRECTIONS/2
  lda z:FORMATION_HEADING
  bcc @increase
  dec
  bra @store
@increase:
  inc
@store:
  and #DIRECTIONS-1
  sta z:FORMATION_HEADING
@done:
  jmp .loword(formation_select)
.assert TURN_UP = 0 .and TURN_DOWN = 1 .and DIRECTIONS = 32, error
