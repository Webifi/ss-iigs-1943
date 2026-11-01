; The stage controls: the event handlers of the US arcade fixed ROM
; ($679B-$6EEC) that change the camera, the players or the stage settings.
; scripts/stage_controls.py maps each arcade handler to one of these handlers
; and its value (stage_control_targets, stage_control_values in
; stage_controls.inc); the handlers of stage_flow.s are in the same table.
; Each handler gets A = its value (A8) and ends at stage_control_done.
.a8
.i16
FINAL_SCROLL = $c400         ; CAMERA_BG1_SCROLL of the last ship scene
SHIP_SCROLL_STEP = $800      ; CAMERA_BG1_SCROLL from one ship scene to the next

; stage_control_run: run the stage control STAGE_CONTROL_INDEX (stage_dispatch).
; Returns carry 1 when it was a stage control, carry 0 for other events. JSL.
; The handler gets A = its value, X = the index * 2.
stage_control_run:
  lda STAGE_CONTROL_INDEX
  cmp #STAGE_CONTROL_COUNT
  bcc :+
  clc
  rtl
:
  a16
  and #255
  asl
  tax
  lda f:stage_control_values,x
  a8
  jmp (.loword(stage_control_targets),x)
stage_control_done:
  sec
  rtl
; stage_control_pan: CAMERA_PAN_ON = A: the camera pans across the stage's
; camera_pan_pointers path.
stage_control_pan:
  sta CAMERA_PAN_ON
  bra stage_control_done
; stage_control_flag: set the stage flag STAGE_FLAGS+A.
stage_control_flag:
  a16
  and #255
  tax
  a8
  lda #1
  sta STAGE_FLAGS,x
  bra stage_control_done
; stage_control_scroll: CAMERA_BG1_GATE = A in both bytes: 0 runs the
; foreground, SCROLL_STOP stops it.
stage_control_scroll:
  sta CAMERA_BG1_GATE
  sta CAMERA_BG1_GATE+1
  bra stage_control_done
; stage_control_boss_hold: the foreground stops while a boss lives.
stage_control_boss_hold:
  lda STAGE_BOSS_COUNT
  bne :+
  jmp .loword(stage_control_done)
:
  lda #SCROLL_STOP
  bra stage_control_scroll
; stage_control_end: the end of the stage: the foreground stops and the
; players leave.
stage_control_end:
  lda #SCROLL_STOP
  sta CAMERA_BG1_GATE
  sta CAMERA_BG1_GATE+1
  lda #PS_LEAVE
  sta STAGE_PLAYER_REQUEST
  bra stage_control_done
; stage_control_difficulty: STAGE_BULLET_SLOTS = STAGE_BULLET_BASE + A,
; limited to 0..BULLET_COUNT.
stage_control_difficulty:
  clc
  adc STAGE_BULLET_BASE
  cmp #BULLET_COUNT+1
  bcc @store
  lda STAGE_BULLET_BASE         ; out of range: a negative base gives 0
  bmi @zero
  lda #BULLET_COUNT
  bra @store
@zero:
  lda #0
@store:
  sta STAGE_BULLET_SLOTS
  bra stage_control_done
; stage_control_capacity: the plane slots that spawns may use.
stage_control_capacity:
  sta STAGE_SPAWN_SLOTS
  bra stage_control_done
; stage_control_modifier: the WAVE_MODIFIER of the next waves.
stage_control_modifier:
  sta WAVE_MODIFIER
  bra stage_control_done
; stage_control_land_camera: the land section A (0-3): the foreground and sea
; scroll of its start; the foreground moves every update; no ship scene.
stage_control_land_camera:
  a16
  and #255
  asl
  tax
  lda f:stage_land_foreground,x
  sta CAMERA_BG1_SCROLL
  lda CAMERA_BG2_SCROLL
  and #255
  ora f:stage_land_sea,x
  sta CAMERA_BG2_SCROLL
  a8
  stz CAMERA_BG1_DIVISOR
  stz STAGE_SHIP_SCENE
  jmp .loword(stage_control_done)
; stage_control_ship_camera: the ship scene A (0-15): the foreground scroll
; A*SHIP_SCROLL_STEP and its STAGE_SHIP_SCENE; specials and loops may start.
stage_control_ship_camera:
  a16
  and #255
  tax
  xba
  asl
  asl
  asl                           ; times SHIP_SCROLL_STEP
  sta CAMERA_BG1_SCROLL
  a8
  lda f:stage_ship_scenes,x
  sta STAGE_SHIP_SCENE
  lda #GATE_ARMED
  jmp .loword(stage_control_player_gate)
.assert SHIP_SCROLL_STEP = $800, error ; XBA and three ASLs
; stage_control_final_camera: the last ship scene.
stage_control_final_camera:
  a16
  lda #FINAL_SCROLL
  sta CAMERA_BG1_SCROLL
  a8
  lda #1
  sta STAGE_SHIP_SCENE
  jmp .loword(stage_control_done)
; stage_control_player_loop: each live player starts the loop (PS_LOOP).
stage_control_player_loop:
  ldx #0
@player:
  lda PLAYER+PL_STATE,x
  cmp #PS_LIVE
  bne @next
  lda #PS_LOOP
  sta PLAYER+PL_STATE,x
@next:
  cpx #PLAYER_SIZE
  bne :+
  jmp .loword(stage_control_done)
:
  ldx #PLAYER_SIZE
  bra @player
; stage_control_player_respawn: each player in the game enters again
; (PS_RESPAWN).
stage_control_player_respawn:
  ldx #0
@player:
  lda PLAYER+PL_STATE,x
  beq @next                     ; PS_INACTIVE
  lda #PS_RESPAWN
  sta PLAYER+PL_STATE,x
@next:
  cpx #PLAYER_SIZE
  bne :+
  jmp .loword(stage_control_done)
:
  ldx #PLAYER_SIZE
  bra @player
; stage_control_player_gate: PL_WEAPON_GATE = A of each player in the game:
; GATE_ARMED lets a special or a loop start, 0 stops them.
stage_control_player_gate:
  sta GATE_VALUE
  ldx #0
@player:
  lda PLAYER+PL_STATE,x
  beq @next                     ; PS_INACTIVE
  lda GATE_VALUE
  sta PLAYER+PL_WEAPON_GATE,x
@next:
  cpx #PLAYER_SIZE
  beq @done
  ldx #PLAYER_SIZE
  bra @player
@done:
  jmp .loword(stage_control_done)
.assert PS_INACTIVE = 0, error ; the BEQs above

; The start of each land section: CAMERA_BG1_SCROLL, and the high byte of
; CAMERA_BG2_SCROLL (the sea).
stage_land_foreground:
  .word $9000,$a000,$b000,$c000
stage_land_sea:
  .word $0000,$3000,$4000,$5000
; The STAGE_SHIP_SCENE of each ship scene: 1 on a ship (a special there is
; the Tsunami), 0 on the sea between ships.
stage_ship_scenes:
  .byte 1,1,0,1,1,0,1,1,0,1,0,1,1,0,1,1
