; The game loop. Each pass waits for the game clock, runs two game ticks
; (the arcade logic runs twice for each picture), then sends the state packet
; when the card is ready for a picture. The sound and the input run inside
; the waits. Direct page: GAME_UPDATES, SEA_CAMERA, FG_CAMERA (src/direct_page.inc).
.include "flight_draw.inc"

; flight_loop: set the first game state, then loop for ever (startup).
flight_loop:
  ax16
  stz GAME_UPDATES
  lda #FLIGHT_INITIAL_CAMERA
  sta SEA_CAMERA
  lda #FLIGHT_FG_INITIAL
  sta FG_CAMERA
  a8
  ; The hi-res pages hold native code and game records, not IIgs video: stop
  ; their copies to the video banks. Keep the other SHADOW bits.
  lda f:SHADOW
  ora #SHADOW_HGR1|SHADOW_HGR2
  sta f:SHADOW
  stz FLIGHT_SPEED              ; no code changes it: speed table 0
  jsr input_init
  a16
  ldx #SHOT_COUNT*SHOT_SIZE-2
@clear_shots:
  stz SHOTS,x
  dex
  dex
  bpl @clear_shots
  a8
  jsr wave_combat_init
  jsl stage_flow_init
  jsl game_flow_init
  jsl game_world_init
  jsl large_loop_init
  lda #ENEMY_COUNT              ; spawns may use all the small-object slots
  sta STAGE_SPAWN_SLOTS
  stz PLAYER_SPECIAL_LOCK
  jsr flight_clock_init
; One update: wait for its time, then two game ticks with the input between
; (none while the SCREEN STOP switch is on; the menu still opens).
@frame:
  jsr flight_clock_wait
  jsl audio_game_upload
  jsr input_sample
  jsl cabinet_frame
  lda GAME_DIP_A
  and #DIP_A_STOP               ; 0: SCREEN STOP is on: no game ticks
  beq @stopped
  lda INPUT_P1
  sta FLIGHT_INPUT
  jsl cabinet_controls          ; the attract demo replaces the input
  jsr flight_tick
  jsr input_tick
  jsl cabinet_controls
  jsr flight_tick
@stopped:
  ; The cameras of the packet.
  a16
  lda CAMERA
  sta SEA_CAMERA
  lda CAMERA_BG1_SCROLL
  sta FG_CAMERA
  a8
  ; Send a picture when the card is ready and the update is on time.
  jsr flight_picture_ready
  bcs :+
  jmp @complete_update
:
  jsr flight_state_packet       ; it sets its own register widths; returns A8, X16
  lda GAME_PICTURE
  and #1                        ; bit 0 selects the card buffer
  clc
  adc #PACKET_TOKEN
  jsr stream_packet
  a16
  inc GAME_PICTURE
  lda GAME_UPDATES
  sta GAME_SENT_LOGIC
@complete_update:
  a16
  inc GAME_UPDATES
  a8
  jmp @frame

.include "game_clock.s"
