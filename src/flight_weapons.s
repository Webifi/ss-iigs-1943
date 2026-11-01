; flight_tick: one game tick (flight_loop runs two in each update).
; In play it runs the stage, the camera, the players, their shots, the enemy
; bullets, the enemies and the large objects, in the arcade's order. When no
; game logic runs (attract scenes, reports, waits) it only steps the random
; state, as the arcade does on every frame. A8, X16, DBR = 0, D = 0.
.a8
.i16

flight_tick:
  lda CAB_DEMO
  cmp #DEMO_END
  beq flight_idle_random        ; freeze the last demo state during its exit
  lda GAME_FLOW
  bne flight_idle_random        ; a cabinet scene, not play
special_tick_site:
  ; src/special_loop.s patches these three bytes: during a special attack
  ; they are JSR special_tick_trampoline, which also loads CAB_RESULT_ACTIVE.
  lda CAB_RESULT_ACTIVE
  bne flight_idle_random        ; the stage result report shows
  jsl alarm_tick
  lda PLAYER+PL_STATE
  ora PLAYER2+PL_STATE
  bne flight_play
  jsr game_players_tick         ; no player in the field: the players' waits only
; flight_idle_random: step the random state. GAME_RNG_SKIP skips one step:
; the arcade coin task misses one frame at a scene change (src/cabinet.s).
flight_idle_random:
  lda GAME_RNG_SKIP
  beq @advance_random
  stz GAME_RNG_SKIP
  rts
@advance_random:
  jsr random_step
  rts
flight_play:
  jsl stage_scroll_tick
  jsl game_scene_tick
  jsr camera_step
  jsr stage_event
  ; This tick's camera move and random bytes for the enemy decisions.
  lda CAMERA_OBJECT_CROSS
  sta ENEMY_CAM_X
  lda CAMERA_OBJECT_ALONG
  sta ENEMY_CAM_Y
  lda RANDOM_STATE+3            ; random stream 3
  sta AI_RANDOM
  lda RANDOM_STATE+4            ; random stream 4
  sta MEDIUM_RANDOM
  jsr game_players_tick
  jsr projectiles_step
  inc COMBAT_PHASE              ; bit 0 alternates the collision halves
  jsr bullet_tick
  jsr wave_combat_tick
  jsl large_loop_tick
  jsr random_step
  rts
