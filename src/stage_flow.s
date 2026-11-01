; The stage flow controls: the event handlers of the US arcade fixed ROM
; ($46DA, $690A-$6EC4, $76F7) for the air bosses, the stage music, the
; banners, the carrier landing and takeoff, the difficulty and the secret
; weapons. They are in the stage_controls.s table: each gets A = its value
; (A8) and ends at stage_control_done. The arcade starts its own tasks here;
; the port sets STAGE_BANNER_TASK and STAGE_SCROLL_TASK for its own code.
.a8
.i16
BOSS_SCROLL_SKIP = $20       ; after the air boss the foreground is this far on
ALARM_ENERGY = $11           ; alarm_tick: a player below this energy is low (arcade $2E80)
SCROLL_ACCELERATE = 1        ; STAGE_SCROLL_TASK: the foreground speeds up
SCROLL_DECELERATE = 2        ; STAGE_SCROLL_TASK: the foreground slows down
SCROLL_STEPS = 4             ; the entries of the scroll speed tables
; stage_weapon_secrets: the player 1 list, then the player 2 list; one
; SECRET_SIZE entry for each of the SECRET_STAGES stages.
SECRET_CODE = 0              ; the input (active high) that gives the weapon
SECRET_WEAPON = 1            ; the PL_WEAPON it gives
SECRET_SIZE = 2
SECRET_STAGES = 16

; stage_flow_init: the scroll task, the boss phase and the banner task stop.
; JSL.
stage_flow_init:
  a16
  ldx #STAGE_SCROLL_END-STAGE_SAVED_CAMERA-2
@clear:
  stz STAGE_SAVED_CAMERA,x
  dex
  dex
  bpl @clear
  a8
  stz STAGE_BANNER_TASK
  rtl
.assert (STAGE_SCROLL_END-STAGE_SAVED_CAMERA) .mod 2 = 0, error ; word clear

; stage_sound_put: request the sound A (a JSR is shorter than the JSL).
stage_sound_put:
  jsl game_sound_request
  rts

; stage_control_boss_camera: the air boss scene A (0-2): keep the foreground
; scroll (plus BOSS_SCROLL_SKIP) for the end of the fight (air_boss.s), show
; the boss scene and start its music.
stage_control_boss_camera:
  a16
  and #255
  asl
  tax
  lda CAMERA_BG1_SCROLL
  clc
  adc #BOSS_SCROLL_SKIP
  sta STAGE_SAVED_CAMERA
  lda f:stage_boss_cameras,x
  sta CAMERA_BG1_SCROLL
  a8
  stz CAMERA_CROSS
  lda #SND_BOSS_MUSIC
  cpx #2*2                      ; scene 2
  bne :+
  lda #SND_BOSS3_MUSIC
:
  jsr .loword(stage_sound_put)
  jmp .loword(stage_control_done)
; The CAMERA_BG1_SCROLL of each air boss scene.
stage_boss_cameras:
  .word $f100,$e100,$f900

; stage_control_boss_reset: a new boss pass: the boss part ledger, the
; damage and the ship core state are cleared; the camera runs.
stage_control_boss_reset:
  stz STAGE_GROUP_INDEX
  stz LARGE_TOTAL
  stz LARGE_THRESHOLD
  stz STAGE_BOSS_PHASE
  stz CAMERA_PAN_ON
  stz CAMERA_HOLD
  stz STAGE_CORE_ARMED
  stz STAGE_CORE_DOWN
  stz STAGE_TURRETS_FALL
  a16
  ldx #LARGE_GROUPS_SIZE-2
@clear:
  stz LARGE_GROUPS,x
  dex
  dex
  bpl @clear
  a8
  jmp .loword(stage_control_done)

; stage_control_boss_replay: the boss pass starts again (arcade $6987). In
; the replay a boss part spawns only when its LARGE_GROUPS slot is not 0:
; the parts that live come back, and half of the destroyed parts (rounded
; up) come back with HP_REVIVED, taken in turn from the front and the back
; of the STAGE_GROUP_INDEX slots (1 to STAGE_GROUP_INDEX).
HP_REVIVED = $ff
stage_control_boss_replay:
  lda STAGE_GROUP_INDEX
  beq @reset
  ; Y = the destroyed parts.
  a16
  and #255
  tax
  ldy #0
  a8
@count:
  lda LARGE_GROUPS,x
  bne :+
  iny
:
  dex
  bne @count
  tya
  lsr
  adc #0                        ; half, rounded up
  beq @reset
  sta REVIVE_COUNT
  ldx #1                        ; the front
  a16
  lda STAGE_GROUP_INDEX
  and #255
  tay                           ; the back
  a8
@front:
  lda LARGE_GROUPS,x
  beq @front_empty
  inx
  bra @front
@front_empty:
  lda #HP_REVIVED
  sta LARGE_GROUPS,x
  inx
  dec REVIVE_COUNT
  beq @reset
@back:
  lda LARGE_GROUPS,y
  beq @back_empty
  dey
  bra @back
@back_empty:
  lda #HP_REVIVED
  sta LARGE_GROUPS,y
  dey
  dec REVIVE_COUNT
  bne @front
@reset:
  ; The damage, the ship core state and the camera pan are cleared.
  stz LARGE_TOTAL
  stz STAGE_GROUP_INDEX
  stz LARGE_THRESHOLD
  stz CAMERA_PAN_ON
  stz STAGE_CORE_ARMED
  stz STAGE_CORE_DOWN
  stz STAGE_TURRETS_FALL
  stz CAMERA_HOLD
  stz CAMERA_PAN_TIME
  stz CAMERA_PAN_DELTA
  stz CAMERA_CROSS
  stz CAMERA_PAN_HOLD
  a16
  stz CAMERA_PAN_OFFSET
  a8
  lda #1
  sta STAGE_BOSS_PHASE          ; a replay pass
  jsr .loword(alarm_start)      ; arcade $69C5
  jmp .loword(stage_control_done)

; stage_control_boss_result: the boss result (arcade $6A11): the foreground
; stops, the boss hold starts and the result repeats on a failure.
stage_control_boss_result:
  lda #SCROLL_STOP
  sta CAMERA_BG1_GATE
  sta CAMERA_BG1_GATE+1
  lda #SND_BOSS_RESULT
  jsr .loword(stage_sound_put)
  lda #1
  sta STAGE_BOSS_HOLD
  sta STAGE_RESULT_REPEAT
  stz LARGE_TOTAL
  stz LARGE_THRESHOLD
  lda #SEQ_RESULT
  sta STAGE_BANNER_TASK
  jmp .loword(stage_control_done)

; stage_control_music: start the stage music A (an FM piece). The sounds
; stop first; an even piece also starts SND_START_EFFECT. The start music
; that audio_start_music_stage already plans does not start again. Then the
; energy gauge of each player in the game is drawn again.
stage_control_music:
  sta STAGE_MUSIC
  jsl audio_start_music_stage
  bcs @music_scheduled
  lda #SND_STOP_ALL
  jsr .loword(stage_sound_put)
  lda STAGE_MUSIC
  and #1
  bne :+
  lda #SND_START_EFFECT
  jsr .loword(stage_sound_put)
:
  lda STAGE_MUSIC
  jsr .loword(stage_sound_put)
@music_scheduled:
  ldx #0
@player:
  lda PLAYER+PL_STATE,x
  beq @next                     ; PS_INACTIVE
  jsl player_energy_hud_far
@next:
  cpx #PLAYER_SIZE
  beq @done
  ldx #PLAYER_SIZE
  bra @player
@done:
  jmp .loword(stage_control_done)

; stage_control_banner: the banner of the stage start (arcade $6B41; the
; takeoff, bank 1 $934D, sets $E458 to 0 before it).
stage_control_banner:
  lda CAMERA_STAGE
  clc
  adc #LAYOUT_TARGET
; stage_banner_start: start the banner of layout A.
stage_banner_start:
  sta BANNER_LAYOUT
  lda #SEQ_BANNER
  sta STAGE_BANNER_TASK
  jmp .loword(stage_control_done)

; game_banner_tick: one update of a banner in the play (cabinet_frame): its
; text types; at its end the banner stops, and after the stage start banner
; the low energy alarm starts (arcade $2806). JSL.
game_banner_tick:
  lda GAME_FLOW
  bne @done
  lda GAME_SEQUENCE
  cmp #SEQ_BANNER
  bne @done
  jsl cabinet_text_tick
  lda CAB_TEXT_DONE
  beq @done
  stz STAGE_BANNER_TASK
  stz GAME_SEQUENCE
  lda BANNER_LAYOUT
  cmp #LAYOUT_CONTACT
  beq @done
  jsr .loword(alarm_start)
@done:
  rtl

; stage_end: the end of a stage, its AIR_RESULT known (game_stage_result;
; arcade $4AB9): the banner and the low energy alarm stop, all sound stops;
; then a pass plays SND_CLEAR_MUSIC (SND_CLEAR_REPLAY after a replay pass),
; a failure SND_RESULT_MUSIC. JSR.
stage_end:
  stz STAGE_BANNER_TASK
  stz GAME_SEQUENCE
  stz ALARM_FLAGS
  lda #SND_STOP_ALL
  jsr .loword(stage_sound_put)
  lda AIR_RESULT
  beq :+
  lda #SND_RESULT_MUSIC
  jmp .loword(stage_sound_put)
:
  lda #SND_STOP_MUSIC
  jsr .loword(stage_sound_put)
  lda STAGE_BOSS_PHASE
  cmp #1                        ; carry 1: a replay pass
  lda #SND_CLEAR_MUSIC
  adc #0                        ; SND_CLEAR_REPLAY
  jmp .loword(stage_sound_put)
.assert SND_CLEAR_REPLAY = SND_CLEAR_MUSIC+1, error

; alarm_start: the low energy alarm runs from now on, in a paid game only
; (arcade task $2E3F ends at once in the demo). JSR.
alarm_start:
  lda CAB_DEMO
  bne :+
  lda #ALARM_RUN
  tsb ALARM_FLAGS
:
  rts

; alarm_tick: one game tick of the low energy alarm (flight_tick; arcade
; task $2E3F): while a player in the field has less than ALARM_ENERGY,
; SND_LOW_ENERGY plays; when no player is low, SND_STOP_EFFECTS. JSL.
alarm_tick:
  bit ALARM_FLAGS
  bpl @done                     ; ALARM_RUN
  lda PLAYER+PL_STATE
  beq :+                        ; PS_INACTIVE
  lda PLAYER+PL_ENERGY
  cmp #ALARM_ENERGY
  bcc @low
:
  lda PLAYER2+PL_STATE
  beq @none
  lda PLAYER2+PL_ENERGY
  cmp #ALARM_ENERGY
  bcc @low
@none:
  bit ALARM_FLAGS
  bvc @done                     ; ALARM_SOUND
  lda #ALARM_RUN
  sta ALARM_FLAGS
  lda #SND_STOP_EFFECTS
  bra @sound
@low:
  bit ALARM_FLAGS
  bvs @done
  lda #ALARM_RUN|ALARM_SOUND
  sta ALARM_FLAGS
  lda #SND_LOW_ENERGY
@sound:
  jsr .loword(stage_sound_put)
@done:
  rtl
.assert ALARM_RUN = $80 .and ALARM_SOUND = $40, error ; the BIT tests

; stage_control_accelerate: the takeoff from the carrier: PS_LANDING players
; take off and the foreground speeds up (stage_scroll_tick).
stage_control_accelerate:
  lda #SCROLL_ACCELERATE
  sta STAGE_SCROLL_TASK
  lda #PS_LANDING
  sta SPEED_FROM_STATE
  lda #PS_TAKEOFF
  bra stage_speed_players
; stage_control_decelerate: the landing on the carrier: live players land
; and the foreground slows down, then stops (stage_scroll_tick).
stage_control_decelerate:
  lda #SCROLL_DECELERATE
  sta STAGE_SCROLL_TASK
  lda #PS_LIVE
  sta SPEED_FROM_STATE
  lda #PS_LANDING
; stage_speed_players: players in SPEED_FROM_STATE go to the state A; the
; scroll task starts at its first step.
stage_speed_players:
  sta SPEED_TO_STATE
  ldx #0
@player:
  lda PLAYER+PL_STATE,x
  cmp SPEED_FROM_STATE
  bne @next
  lda SPEED_TO_STATE
  sta PLAYER+PL_STATE,x
@next:
  cpx #PLAYER_SIZE
  beq @timer
  ldx #PLAYER_SIZE
  bra @player
@timer:
  stz STAGE_SCROLL_STEP
  a16
  stz STAGE_SCROLL_WAIT
  a8
  jmp .loword(stage_control_done)

; stage_scroll_tick: one update of the scroll task (flight_weapons). Each of
; the SCROLL_STEPS steps sets the CAMERA_BG1_DIVISOR of its table and waits
; its time. At the end the takeoff leaves the foreground at full speed (1)
; and the landing stops it. JSL.
stage_scroll_tick:
  lda STAGE_SCROLL_TASK
  bne :+
  rtl
:
  a16
  lda STAGE_SCROLL_WAIT
  beq @next
  dec STAGE_SCROLL_WAIT
  bne @done
@next:
  lda STAGE_SCROLL_STEP
  and #255
  asl
  tax
  a8
  lda STAGE_SCROLL_TASK
  cmp #SCROLL_ACCELERATE
  beq @accelerate
  cpx #SCROLL_STEPS*2
  bcc :+
  lda #SCROLL_STOP
  sta CAMERA_BG1_GATE
  sta CAMERA_BG1_GATE+1
  bra @finished
:
  lda f:stage_decelerate_speed,x
  sta CAMERA_BG1_DIVISOR
  a16
  lda f:stage_decelerate_wait,x
  bra @wait
@accelerate:
.a8
  cpx #SCROLL_STEPS*2
  bcc :+
  lda #1                        ; a foreground step every update
  sta CAMERA_BG1_DIVISOR
@finished:
  stz STAGE_SCROLL_TASK
  rtl
:
  lda f:stage_accelerate_speed,x
  sta CAMERA_BG1_DIVISOR
  a16
  lda f:stage_accelerate_wait,x
@wait:
  sta STAGE_SCROLL_WAIT
  a8
  inc STAGE_SCROLL_STEP
  rtl
@done:
  a8
  rtl
; The CAMERA_BG1_DIVISOR and the updates of each step. The divisors are
; words so that one X reads both tables.
stage_accelerate_speed: .word 5,4,3,2
stage_accelerate_wait: .word $c0,$5a,$20,$18
stage_decelerate_speed: .word 2,3,4,5
stage_decelerate_wait: .word $0e,$20,$5a,$c0

; stage_control_boss_departure: the players leave for the ship scene (arcade
; $6BBC): the foreground stops, specials and loops stop, the players dive and
; the banner LAYOUT_CONTACT shows.
stage_control_boss_departure:
  lda #SCROLL_STOP
  sta CAMERA_BG1_GATE
  sta CAMERA_BG1_GATE+1
  ldx #0
@player:
  lda PLAYER+PL_STATE,x
  beq @next                     ; PS_INACTIVE
  stz PLAYER+PL_WEAPON_GATE,x
@next:
  cpx #PLAYER_SIZE
  beq @ready
  ldx #PLAYER_SIZE
  bra @player
@ready:
  lda #SND_DIVE
  jsr .loword(stage_sound_put)
  lda #PS_DIVE
  sta STAGE_PLAYER_REQUEST
  lda #LAYOUT_CONTACT           ; arcade $6BD4: $E458 1
  jmp .loword(stage_banner_start)

; stage_control_stage_difficulty: STAGE_BULLET_SPEED and STAGE_PLAYER_SPEED
; come from stage_difficulty_values at STAGE_SPEED_BASE + CAMERA_STAGE.
stage_control_stage_difficulty:
  lda STAGE_SPEED_BASE
  clc
  adc CAMERA_STAGE
  a16
  and #255
  tax
  a8
  lda f:stage_difficulty_values,x
  sta STAGE_BULLET_SPEED
  sta STAGE_PLAYER_SPEED
  jmp .loword(stage_control_done)

; stage_control_secret_weapon: the secret weapons (arcade $6E11): a player
; who holds the stage's secret input gets its weapon. A player without it
; loses a LASER.
stage_control_secret_weapon:
  a16
  lda CAMERA_STAGE
  and #SECRET_STAGES-1
  asl                           ; times SECRET_SIZE
  tay
  a8
  lda INPUT_P1
  ldx #0
  jsr .loword(stage_secret_player)
  a16
  tya
  clc
  adc #SECRET_STAGES*SECRET_SIZE ; the player 2 list
  tay
  a8
  lda INPUT_P2                  ; read now, as the arcade reads $C002 ($6E5C)
  ldx #PLAYER_SIZE
  jsr .loword(stage_secret_player)
  jmp .loword(stage_control_done)
.assert SECRET_SIZE = 2, error ; the ASL above
; stage_secret_player: A = the input of the player at X (active low), Y = its
; stage_weapon_secrets entry. A player in the game with the secret input gets
; the weapon: WEAPON_TIME_MAX, or WEAPON_ENDLESS for the LASER. Y is kept.
stage_secret_player:
  eor #$ff                      ; active high
  sta SECRET_INPUT
  lda PLAYER+PL_STATE,x
  beq @done                     ; PS_INACTIVE
  phx
  tyx
  lda f:stage_weapon_secrets+SECRET_CODE,x
  cmp SECRET_INPUT
  beq @grant
  plx
  lda PLAYER+PL_WEAPON,x
  cmp #WEAPON_LASER
  bne @done
  stz PLAYER+PL_WEAPON,x
  stz PLAYER+PL_WEAPON_TIME,x
  rts
@grant:
  lda f:stage_weapon_secrets+SECRET_WEAPON,x
  plx
  sta PLAYER+PL_WEAPON,x
  cmp #WEAPON_LASER
  beq @laser
  lda #WEAPON_TIME_MAX
  bra @timer
@laser:
  lda #WEAPON_ENDLESS
@timer:
  sta PLAYER+PL_WEAPON_TIME,x
@done:
  rts

; stage_control_intro: the stage intro (arcade $46DA): the foreground stops.
stage_control_intro:
  lda #SEQ_INTRO
  sta STAGE_BANNER_TASK
  lda #SCROLL_STOP
  sta CAMERA_BG1_GATE
  sta CAMERA_BG1_GATE+1
  jmp .loword(stage_control_done)
; stage_control_bonus: the bonus pickup (arcade $76F7, game_bonus_spawn).
stage_control_bonus:
  jsl game_bonus_spawn
  jmp .loword(stage_control_done)
