; The stage formations and the large aircraft (US arcade): the pair wave,
; the giant, the four-piece quad plane and the bonus plane; the later
; aircraft, turret, air boss and raid code is included here. The templates
; are copied only at the spawn.
.a8
.i16
PAIR_WAVE_GROUP = 12         ; WAVE_COUNTS of the pair wave (its OBJ_WAVE_COUNTER)
PAIR_PLANES = 8
PAIR_DELAY = 16              ; each pair plane starts this many updates later
QUAD_HEADINGS = 16           ; QUAD_HEADING: 0 up to 15; 8 the other way
QUAD_FAR = 180               ; game_quad_tick: farther across: QUAD_DELAY 3
QUAD_NEAR = 60               ; game_quad_tick: farther across: QUAD_DELAY 2, else 0
QUAD_TURN_WAIT = 13          ; QUAD_WAIT at heading 0 or 8
QUAD_LEAVE_WAIT = 255        ; QUAD_WAIT after the second turn to heading 0
GIANT_TURN_STEPS = 63        ; game_giant_turns entries
GIANT_BONUS_LIFE = 2         ; GIANT_LIFE at which the score changes
GIANT_HIT_HP = 8             ; OBJ_HP after a hit that the giant survives
BONUS_CREDITS = 8            ; game_bonus_spawn: the bonus plane needs this many credits

; The family bytes of the object record, by kind.
QUAD_HEADING = $10           ; game_quad_tick: the heading, 0-15
QUAD_DELAY = $11             ; game_quad_tick: QUAD_WAIT of a turn, from the distance
QUAD_WAIT = $12              ; game_quad_tick: decisions left before the next turn
QUAD_TURNED = $13            ; game_quad_tick: the first turn to heading 0 is done
QUAD_DIRECTION = $14         ; game_quad_tick: 1 heading + 1, 0 heading - 1
GIANT_TIMER = $11            ; game_giant_tick: counts 0-119; bursts start at 30, 70, 100, 120
GIANT_TURN_STEP = $12        ; game_giant_select: the game_giant_turns entry, 0-62
GIANT_BURST = $13            ; game_giant_tick: burst shots left
GIANT_BURST_DIRECTION = $14  ; game_giant_tick: the direction of the next burst shot
GIANT_LIFE = $15             ; game_giant_hit: hits left

; Motion records (large_ai_selected).
MOTION_QUAD = $ad8f
MOTION_GIANT_APPROACH = $9c25    ; bank 0
MOTION_GIANT_OPEN = $9c44        ; bank 0
MOTION_GIANT_READY = $9c63       ; bank 0
MOTION_GIANT_ATTACK = $9d8b      ; bank 0
MOTION_GIANT_HIT = $9f52         ; bank 0
MOTION_GIANT_EXPLOSION = $6623   ; fixed
.segment "GAMEFLOW"
.include "stage_aircraft.s"
.include "later_aircraft.s"
.include "later_turrets.s"
.include "air_boss_data.inc"
.include "air_boss.s"
.include "air_boss_enemies.s"
.include "stage_raid.s"
.segment "GAMEPLAY"
; game_pair_wave: the two-player formation (EVENT_PAIR_WAVE): PAIR_PLANES
; planes (game_pair_template) PAIR_DELAY updates apart, with the drop of
; WAVE_MODIFIER, counted in WAVE_COUNTS. JSL.
game_pair_wave:
  stz WAVE_COUNTS+PAIR_WAVE_GROUP
  a16
  lda #PAIR_PLANES
  sta SIMPLE_LEFT
  stz SIMPLE_SLOT
  ldx #0
@find:
  a8
  lda ENEMY_POOL+OBJ_TYPE,x
  beq @found
  a16
  txa
  clc
  adc #OBJECT_SIZE
  tax
  cpx #ENEMY_COUNT*OBJECT_SIZE
  bne @find
  a8
  rtl
@found:
  stx SIMPLE_LIMIT
  a16
  ldy #0
@copy:
  phx
  tyx
  lda f:game_pair_template,x
  plx
  sta ENEMY_POOL,x
  inx
  inx
  iny
  iny
  cpy #OBJECT_SIZE
  bne @copy
  ldx SIMPLE_LIMIT
  a8
  lda WAVE_MODIFIER
  sta ENEMY_POOL+OBJ_DROP,x
  lda SIMPLE_SLOT               ; here: the start delay
  sta ENEMY_POOL+OBJ_DURATION,x
  clc
  adc #PAIR_DELAY
  sta SIMPLE_SLOT
  inc WAVE_COUNTS+PAIR_WAVE_GROUP
  dec SIMPLE_LEFT
  bne @find
  rtl

; game_giant_spawn: the giant plane (EVENT_GIANT): the template in four
; free large slots; the head column's rows 1-3 get its attributes and their
; places PIECE_RISE apart. JSL.
game_giant_spawn:
  jsr .loword(giant_allocate)
  bcs :+
  rtl
:
  a16
  stx LARGE_SPAWN_SLOT
  ldy #0
@copy:
  phx
  tyx
  lda f:game_giant_template,x
  plx
  sta LARGE_POOL,x
  inx
  inx
  iny
  iny
  cpy #OBJECT_SIZE
  bne @copy
  ldx LARGE_SPAWN_SLOT
  a8
  lda LARGE_POOL+SPR_ATTR,x
  sta LARGE_POOL+2*SPRITE_SIZE+SPR_ATTR,x
  sta LARGE_POOL+8*SPRITE_SIZE+SPR_ATTR,x
  sta LARGE_POOL+10*SPRITE_SIZE+SPR_ATTR,x
  lda LARGE_POOL+SPR_ALONG,x
  sec
  sbc #PIECE_RISE
  sta LARGE_POOL+2*SPRITE_SIZE+SPR_ALONG,x
  sec
  sbc #PIECE_RISE
  sta LARGE_POOL+8*SPRITE_SIZE+SPR_ALONG,x
  sec
  sbc #PIECE_RISE
  sta LARGE_POOL+10*SPRITE_SIZE+SPR_ALONG,x
  rtl

; The quad plane (a large object; D = its record, large_ai). game_quad_enable:
; contacts on, then the turns.
game_quad_enable:
.a16
  a8
  lda #OF_CONTACT|OF_SHOT
  sta OBJ_FLAGS
  a16
  lda #MOTION_QUAD
  jmp .loword(large_ai_selected)
; game_quad_fire: fire 1 time in 8 (random stream 2, no step), then turn.
game_quad_fire:
.a16
  a8
  lda RANDOM_STATE+2
  and #7
  bne game_quad_tick8
  jsr .loword(large_plane_shot)
game_quad_tick8:
  a16
; game_quad_tick: at headings 0 and 8 the quad turns toward the player's
; side; the wait of each turn grows with the distance across. After the
; second turn to heading 0 it leaves.
game_quad_tick:
.a16
  a8
  lda QUAD_WAIT
  beq @turn
  dec QUAD_WAIT
  jmp .loword(@select)
@turn:
  lda QUAD_HEADING
  beq @target
  cmp #QUAD_HEADINGS/2
  bne @step
@target:
  jsl ai_target_far
  lda SPR_CROSS
  sec
  sbc PLAYER+SPR_CROSS,y
  bcs @right
  eor #$ff
  inc
  pha
  lda QUAD_HEADING
  beq :+
  lda #0
  bra @direction
:
  lda #1
  bra @direction
@right:
  pha
  lda QUAD_HEADING
  beq :+
  lda #1
  bra @direction
:
  lda #0
@direction:
  sta QUAD_DIRECTION
  pla
  cmp #QUAD_FAR
  bcc :+
  lda #3
  bra @delay
:
  cmp #QUAD_NEAR
  bcc :+
  lda #2
  bra @delay
:
  lda #0
@delay:
  sta QUAD_DELAY
@step:
  lda QUAD_HEADING
  pha
  lda QUAD_DIRECTION
  beq @decrease
  pla
  inc
  bra @heading
@decrease:
  pla
  dec
@heading:
  and #QUAD_HEADINGS-1
  sta QUAD_HEADING
  beq @zero
  cmp #QUAD_HEADINGS/2
  bne @ordinary
  lda #QUAD_TURN_WAIT
  bra @wait
@zero:
  lda QUAD_TURNED
  bne @leave
  inc QUAD_TURNED
  lda #QUAD_TURN_WAIT
  bra @wait
@leave:
  lda #QUAD_LEAVE_WAIT
  bra @wait
@ordinary:
  lda QUAD_DELAY
@wait:
  sta QUAD_WAIT
@select:
  a16
  lda QUAD_HEADING
  and #QUAD_HEADINGS-1
  asl
  tax
  lda f:game_quad_turns,x
  jmp .loword(large_ai_selected)

; The giant (US arcade bank 0 $9BEE-$9F85): it comes down to along $70,
; opens to $7c, gets ready to $88 (then contacts on) and attacks.
game_giant_approach:
.a16
  ldx #MOTION_GIANT_APPROACH
  a8
  lda SPR_ALONG
  cmp #$70
  bne :+
  ldx #MOTION_GIANT_OPEN
:
  a16
  txa
  jmp .loword(large_ai_selected)
game_giant_open:
.a16
  ldx #MOTION_GIANT_OPEN
  a8
  lda SPR_ALONG
  cmp #$7c
  bne :+
  ldx #MOTION_GIANT_READY
:
  a16
  txa
  jmp .loword(large_ai_selected)
game_giant_ready:
.a16
  ldx #MOTION_GIANT_READY
  a8
  lda SPR_ALONG
  cmp #$88
  bne :+
  lda #OF_CONTACT|OF_SHOT
  sta OBJ_FLAGS
  ldx #MOTION_GIANT_ATTACK
:
  a16
  txa
  jmp .loword(large_ai_selected)
; game_giant_reopen: contacts on again, then the turns.
game_giant_reopen:
.a16
  a8
  lda #OF_CONTACT|OF_SHOT
  sta OBJ_FLAGS
  bra game_giant_select
; game_giant_tick: at GIANT_TIMER 30, 70, 100 and 120 a burst of 5 spread
; bullets starts at the player's angle (limited to 12..20) - 4, two angles
; apart, each when the player is 32 or more away on both axes (LA_SPREAD
; from 8 left of and 48 above the giant's cross and along).
game_giant_tick:
.a16
  a8
  inc GIANT_TIMER
  lda GIANT_TIMER
  cmp #30
  beq @burst
  cmp #70
  beq @burst
  cmp #100
  beq @burst
  cmp #120
  bne @fire
  stz GIANT_TIMER
@burst:
  jsl ai_target_far
  cmp #13
  bcs :+
  lda #12
:
  cmp #20
  bcc :+
  lda #20
:
  sec
  sbc #4
  sta GIANT_BURST_DIRECTION
  lda #5
  sta GIANT_BURST
@fire:
  lda GIANT_BURST
  beq game_giant_select
  jsl ai_target_far
  lda SPR_ALONG
  sec
  sbc #32
  sec
  sbc PLAYER+SPR_ALONG,y
  bcs :+
  eor #$ff
  inc
:
  cmp #32
  bcc game_giant_select
  lda PLAYER+SPR_CROSS,y
  clc
  adc #16
  sec
  sbc SPR_CROSS
  bcc :+                        ; arcade $9CCB keeps a negative difference
  eor #$ff
  inc
:
  cmp #32
  bcc game_giant_select
  dec GIANT_BURST
  lda GIANT_BURST_DIRECTION
  sta MEDIUM_SHOT_ANGLE
  inc GIANT_BURST_DIRECTION
  inc GIANT_BURST_DIRECTION
  lda #LA_SPREAD
  sta LARGE_AI_ACTION
  lda SPR_CROSS
  sec
  sbc #8
  sta LARGE_AI_X
  lda SPR_ALONG
  sec
  sbc #48
  sta LARGE_AI_Y
; game_giant_select: the next game_giant_turns path (in a loop).
game_giant_select:
.a8
  inc GIANT_TURN_STEP
  lda GIANT_TURN_STEP
  cmp #GIANT_TURN_STEPS
  bne :+
  stz GIANT_TURN_STEP
:
  a16
  lda GIANT_TURN_STEP
  and #255
  asl
  tax
  lda f:game_giant_turns,x
  jmp .loword(large_ai_selected)
; game_giant_hit: a hit takes one GIANT_LIFE; at the last but one the score
; changes; at 0 the giant explodes (SND_BOSS_PART), else it gets
; GIANT_HIT_HP again.
game_giant_hit:
.a16
  a8
  lda GIANT_LIFE
  cmp #GIANT_BONUS_LIFE
  bne :+
  lda #$5f                      ; the score code
  sta OBJ_SCORE
:
  dec GIANT_LIFE
  bne @survived
  lda #SND_BOSS_PART
  sta LARGE_AI_SOUND
  a16
  lda #MOTION_GIANT_EXPLOSION
  jmp .loword(large_ai_selected)
@survived:
.a8
  lda #GIANT_HIT_HP
  sta OBJ_HP
  a16
  lda #MOTION_GIANT_HIT
  jmp .loword(large_ai_selected)

; game_bonus_spawn: the bonus plane (US arcade $76F7), with BONUS_CREDITS
; credits or more, in the first free ENEMY_POOL slot. JSL.
game_bonus_spawn:
.a8
  lda GAME_CREDITS
  cmp #BONUS_CREDITS
  bcs :+
  rtl
:
  ldx #0
@find:
  lda ENEMY_POOL+OBJ_TYPE,x
  beq @copy
  a16
  txa
  clc
  adc #OBJECT_SIZE
  tax
  a8
  cpx #ENEMY_COUNT*OBJECT_SIZE
  bne @find
  rtl
@copy:
  a16
  ldy #0
@word:
  phx
  tyx
  lda f:game_bonus_template,x
  plx
  sta ENEMY_POOL,x
  inx
  inx
  iny
  iny
  cpy #OBJECT_SIZE
  bne @word
  a8
  rtl
