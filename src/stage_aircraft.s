; The decisions of the four-piece aircraft (large objects; D = the record,
; large_ai): the opening aircraft, the weave, the fall, the bursts and the
; carrier. The tables hold arcade motion data.
.a8
.i16
OPEN_PHASES = 4              ; game_open_paths: (OBJ_FLAGS, motion) entries
OPEN_ENTRY_SIZE = 3
WEAVE_PAUSES = 12            ; game_weave_pause: the weave turns back after this many
WEAVE_FIRE_HEADING = 3       ; the weave fires at this heading,
WEAVE_FIRE_ALONG = $60       ; at this along or lower
AIRCRAFT_GUN_CROSS = 8       ; the guns are this far right of the cross
AIRCRAFT_GUN_ALONG = 8       ; and this far above the along
FALL_FIRE_DELAY = 16         ; FALL_SHOT_DELAY after game_fall_fire

; The family bytes of the object record, by kind.
OPEN_PHASE = $10             ; game_open_aircraft: the game_open_paths entry, 0-3
OPEN_TIME = $11              ; game_open_aircraft: decisions left of this phase
OPEN_CLOSING = $12           ; game_open_aircraft: nonzero while the phases go back
WEAVE_HEADING = $10          ; weave: the game_weave_paths entry
WEAVE_DIRECTION = $11        ; weave: 0 heading + 1, $FF heading - 1
WEAVE_PAUSE = $12            ; game_weave_pause: pauses done; it turns back at 12
FALL_TIME = $10              ; game_fall_wait: decisions before the fall
FALL_SHOT_DELAY = $11        ; fall: decisions before the next random shot

; Motion records (large_ai_selected).
MOTION_FALL_WAIT = $af6b
MOTION_FALL = $af7c
MOTION_FALL_FIRE = $af9b
MOTION_FALL_PATH = $afba
MOTION_LARGE_BURST = $5f33       ; fixed: the burst that shows P1
MOTION_LARGE_BURST_P2 = $5f74    ; fixed
MOTION_LARGE_BURST_END = $5ee1   ; fixed: the burst when the stage ends
; game_open_aircraft: the phases 0 to 3 and back (game_open_delays times
; each); at phases 0 and 3 the aircraft fires three shots.
game_open_aircraft:
.a16
  a8
  dec OPEN_TIME
  bne @select
  lda OPEN_CLOSING
  bne @closing
  lda OPEN_PHASE
  inc
  cmp #OPEN_PHASES
  bne @phase
  lda #$ff
  sta OPEN_CLOSING
  lda #OPEN_PHASES-2
  bra @phase
@closing:
  lda OPEN_PHASE
  dec
  cmp #$ff
  bne @phase
  stz OPEN_CLOSING
  lda #1
@phase:
  sta OPEN_PHASE
  a16
  and #255
  tax
  a8
  lda f:game_open_delays,x
  sta OPEN_TIME
  lda OPEN_PHASE
  beq @shoot
  cmp #OPEN_PHASES-1
  bne @select
@shoot:
  jsr .loword(game_aircraft_triple)
@select:
  a16
  lda OPEN_PHASE
  and #255
  sta a:OPEN_PATH_OFFSET
  asl
  adc a:OPEN_PATH_OFFSET        ; times OPEN_ENTRY_SIZE
  tax
  a8
  lda f:game_open_paths,x
  sta OBJ_FLAGS
  a16
  lda f:game_open_paths+1,x
  jmp .loword(large_ai_selected)

; game_weave_pause: a pause; after WEAVE_PAUSES the weave turns back.
game_weave_pause:
.a16
  a8
  lda WEAVE_PAUSE
  cmp #WEAVE_PAUSES
  beq @reverse
  inc WEAVE_PAUSE
  bra game_weave_select
@reverse:
  lda WEAVE_DIRECTION
  eor #$ff
  sta WEAVE_DIRECTION
  stz WEAVE_PAUSE
  bra game_weave_step
; game_weave_aircraft: one heading step; three shots at WEAVE_FIRE_HEADING.
game_weave_aircraft:
.a16
  a8
game_weave_step:
  lda WEAVE_DIRECTION
  bne @decrease
  inc WEAVE_HEADING
  bra @shoot
@decrease:
  dec WEAVE_HEADING
@shoot:
  lda WEAVE_HEADING
  cmp #WEAVE_FIRE_HEADING
  bne game_weave_select
  lda SPR_ALONG
  cmp #WEAVE_FIRE_ALONG
  bcc game_weave_select
  jsr .loword(game_aircraft_triple)
game_weave_select:
.a8
  a16
  lda WEAVE_HEADING
  and #255
  asl
  tax
  lda f:game_weave_paths,x
  jmp .loword(large_ai_selected)

; game_aircraft_triple: three bullets from the guns in the arcade order: at
; the player, 2 angles to one side, 2 to the other (game_large_spread_far,
; with D = 0). JSR.
game_aircraft_triple:
.a8
  jsl ai_target_far
  lda SPR_CROSS
  clc
  adc #AIRCRAFT_GUN_CROSS
  sta LARGE_AI_X
  lda SPR_ALONG
  sec
  sbc #AIRCRAFT_GUN_ALONG
  sta LARGE_AI_Y
  lda OBJ_AIM
  sta MEDIUM_SHOT_ANGLE
  phd
  pea .loword(ZERO_PAGE)
  pld
  jsl game_large_spread_far
  pld
  lda OBJ_AIM
  clc
  adc #2
  and #DIRECTIONS-1
  sta MEDIUM_SHOT_ANGLE
  phd
  pea .loword(ZERO_PAGE)
  pld
  jsl game_large_spread_far
  pld
  lda OBJ_AIM
  sec
  sbc #2
  and #DIRECTIONS-1
  sta MEDIUM_SHOT_ANGLE
  phd
  pea .loword(ZERO_PAGE)
  pld
  jsl game_large_spread_far
  pld
  rts

; The falling aircraft. game_fall_wait: wait FALL_TIME decisions (2 in 16
; shots), then fall. game_fall_fire: 10 in 16, then FALL_FIRE_DELAY.
; game_fall_enable: contacts on. game_fall_tail: 4 in 16 when the delay ends.
game_fall_wait:
.a16
  a8
  dec FALL_TIME
  beq @fall
  dec FALL_SHOT_DELAY
  bne @wait
  lda #2
  jsr .loword(game_fall_random_shot)
@wait:
  a16
  lda #MOTION_FALL_WAIT
  jmp .loword(large_ai_selected)
@fall:
  a16
  lda #MOTION_FALL
  jmp .loword(large_ai_selected)
game_fall_fire:
.a16
  a8
  lda #10
  jsr .loword(game_fall_random_shot)
  lda #FALL_FIRE_DELAY
  sta FALL_SHOT_DELAY
  a16
  lda #MOTION_FALL_FIRE
  jmp .loword(large_ai_selected)
game_fall_enable:
.a16
  a8
  lda #OF_CONTACT|OF_SHOT
  sta OBJ_FLAGS
  bra game_fall_path
game_fall_tail:
.a16
  a8
  dec FALL_SHOT_DELAY
  bne game_fall_path
  lda #4
  jsr .loword(game_fall_random_shot)
game_fall_path:
.a8
  a16
  lda #MOTION_FALL_PATH
  jmp .loword(large_ai_selected)
; game_fall_random_shot: a plane shot with odds of A in 16 (random stream 0,
; step $55). JSR.
game_fall_random_shot:
.a8
  sta a:FALL_ODDS
  lda RANDOM_STATE
  pha
  clc
  adc #$55
  sta RANDOM_STATE
  pla
  and #15
  cmp a:FALL_ODDS
  bcs @done
  jsr .loword(large_plane_shot)
  lda SPR_ALONG
  sta LARGE_AI_Y
@done:
  rts

; game_large_burst: the explosion path of the player that scored.
game_large_burst:
.a16
  a8
  lda OBJ_OWNER
  stz OBJ_OWNER
  cmp #2                        ; player 2
  beq @two
  a16
  lda #MOTION_LARGE_BURST
  bra @next
@two:
  a16
  lda #MOTION_LARGE_BURST_P2
@next:
  jmp .loword(large_ai_selected)

; game_large_burst_loop: the burst again; after the ship core is down, the
; end burst.
game_large_burst_loop:
.a16
  lda LARGE_CALLBACK
  cmp #TAIL_LARGE_BURST_LOOP
  beq @one
  lda #MOTION_LARGE_BURST_P2
  bra @path
@one:
  lda #MOTION_LARGE_BURST
@path:
  tax
  a8
  lda STAGE_CORE_DOWN
  a16
  beq :+
  ldx #MOTION_LARGE_BURST_END
:
  txa
  jmp .loword(large_ai_selected)
; game_carrier_destroy: the carrier explodes; in the boss hold it counts.
game_carrier_destroy:
.a16
  a8
  lda STAGE_BOSS_HOLD
  beq :+
  inc LARGE_TOTAL
:
  lda #SND_BOSS_PART
  sta LARGE_AI_SOUND
  a16
  lda #MOTION_GIANT_EXPLOSION
  jmp .loword(large_ai_selected)
