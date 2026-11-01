; The cabinet pages and the attract (native): the power-on page, the
; rankings, the title and its P-38 fly-in, the demo with the arcade's
; recorded controls, the start of a game, and the ending pages. The timers
; count game updates, not pictures. The texts, the art and the demo controls
; come from the arcade ROM at build time (scripts/arcade_flow.py).
.a8
.i16
; cabinet_wire_mode: the layout of the card for this packet (CABINET_LAYOUTS;
; the layouts: cabinet_layouts.inc).
LAYOUT_SIZE = 6              ; a CABINET_LAYOUTS entry: the length, the long address
UPLOAD_SIZE = 6              ; an entry of a CABINET_PAGES list: the same
; The times, in game updates.
POWER_ON_TICKS = 30          ; PAGE_POWER_ON
TITLE_TICKS = 210            ; PAGE_TITLE: arcade $0324 + $0330 = 420 ticks
RANKING_TICKS = 240          ; PAGE_RANKING: 480 arcade ticks
RANKING_PRELOAD = 180        ; PAGE_RANKING: CAB_WAIT under this: the demo loads
DEMO_END_TICKS = 180         ; DEMO_END: the wait before the next scene
BLINK_PERIOD = 45            ; INSERT COIN: on for BLINK_ON updates of each period
BLINK_ON = 30
PLANE_TICKS = 2              ; CAB_PLANE_WAIT: the arcade ticks of one update
PLANE_STEP_SIZE = 3          ; cabinet_plane_frames: the ticks, the scroll word
FRAMES_END = 255             ; cabinet_plane_frames, cabinet_demo_controls: the end
NO_SOUND = 255               ; cabinet_ending_sounds: no sound
ATTRACT_STAGE = 2            ; CAMERA_STAGE: the attract uses the third stage
INTRO_SCROLL = $d000         ; CAMERA_BG1_SCROLL: the resident intro rows, all clear
DEMO_BG1_SCROLL = $b000      ; the demo start (arcade)
DEMO_BG2_SCROLL = $3000
DEMO_STAGE_OFFSET = $18
START_SCROLL = $d0ff         ; the game start: arcade $0F2A, before the first event
PLAYER_TEMPLATE = 40         ; cabinet_player_start, cabinet_demo_player: the bytes
SEA_IDLE_WRAP = $1000        ; the attract sea scroll wraps at this

; cabinet_init: the power-on page; the scores of the arcade ranking; no
; demo, no ending, no result. JSL.
cabinet_init:
  jsl native_dive_reset
  lda #PAGE_POWER_ON
  sta CAB_PAGE
  sta CAB_LOADED
  sta GAME_FLOW
  stz CAB_LOADING
  stz GAME_RNG_SKIP
  stz CAB_START_PENDING
  stz CAB_DEMO
  stz CAB_BLINK
  stz CAB_ENDING
  stz CAB_RESULT_ACTIVE
  stz CAB_LAYOUT_LOADED
  lda #WORLD_NONE
  sta CAB_WORLD_TARGET
  a16
  stz CAB_OFFSET
  lda #POWER_ON_TICKS+1         ; the first cabinet tick takes one at once
  sta CAB_WAIT
  ldx #CAB_SCORES_SIZE-2
@score:
  lda f:cabinet_initial_scores,x
  sta f:CAB_SCORES,x
  dex
  dex
  bpl @score
  ldx #2*SCORE_DIGITS-2
@clear_scores:
  stz CAB_ENDING_SCORES,x
  dex
  dex
  bpl @clear_scores
  a8
  jsl cabinet_live_reset
  rtl

; cabinet_frame: the cabinet work of a main-loop update, after the input
; sample: the menu, the live initials, the stage result, the game flow
; (coins and continues), then the attract (cabinet_tick) during the demo.
; The demo controls never replace the system and coin input. With the
; SCREEN STOP switch on, only the menu runs. JSL.
cabinet_frame:
  jsl native_input_menu
  lda GAME_DIP_A
  and #DIP_A_STOP               ; 0: SCREEN STOP: the cabinet stops too
  beq @done
  jsl cabinet_live_tick
  jsl cabinet_result_tick
  jsl game_flow_tick
  lda CAB_DEMO
  beq @done
  lda GAME_FLOW
  cmp #CAB_PAGE_FIRST
  bcs @done
  jsl cabinet_tick
@done:
  rtl

; cabinet_select: show the page A. In the ending all ending pages use the
; one loaded picture. PAGE_TITLE starts the fly-in; PAGE_POWER_ON and the
; ending pages have no page picture (PAGE_NONE). JSL.
cabinet_select:
  pha
  jsl native_dive_reset
  lda CAB_ENDING
  beq @ordinary
  lda CAB_LOADED
  cmp #PAGE_ENDING_FIRST
  bcc @ordinary
  pla
  sta CAB_PAGE
  sta GAME_FLOW
  sta CAB_LOADED
  stz CAB_ENDING_TEXT
  rtl
@ordinary:
  pla
  sta CAB_PAGE
  sta GAME_FLOW
  stz CAB_LOADING
  stz CAB_DEMO
  a16
  stz CAB_OFFSET
  a8
  lda CAB_PAGE
  cmp #PAGE_POWER_ON
  beq @static
  cmp #PAGE_ENDING_FIRST
  bcs @static
  sta CAB_LOADED
  cmp #PAGE_TITLE
  bne @done
  jsl cabinet_clear_play
  lda #PAGE_NONE
  sta CAB_LOADED
  sta WORLD_TAGS+1              ; WORLD_NONE: cabinet_surface takes world slot 1 only
  sta CAB_WORLD_TARGET          ; WORLD_NONE
  stz CAB_PLANE_STEP
  stz CAB_BLINK
  lda #PLANE_TICKS
  sta CAB_PLANE_WAIT
  a16
  lda #INTRO_SCROLL
  sta CAMERA_BG1_SCROLL
  lda #TITLE_TICKS
  sta CAB_WAIT
  a8
@done:
  rtl
@static:
  lda #PAGE_NONE
  sta CAB_LOADED
  rtl
.assert PAGE_NONE = WORLD_NONE, error

; cabinet_tick: one attract update. A start waits for the page and the world
; loads, then cabinet_start. A credit shows the title of the credits; START
; pays and starts the music. With no credit: the demo blinks INSERT COIN; a
; page counts down, then the next page: power-on, the first ranking, the
; demo; the title, the ranking, the demo. The sea scrolls under the pages.
; JSL.
cabinet_tick:
  lda SYSTEM_PRESSED
  sta CAB_KEYS
  lda CAB_START_PENDING
  beq @coin
  lda CAB_LOADING
  bne @done
  lda WORLD_LOADING
  cmp #WORLD_NONE
  bne @done
  jmp .loword(cabinet_start)
@coin:
  lda CAB_ENDING
  beq :+
  jmp .loword(cabinet_ending_tick)
:
  lda GAME_CREDITS
  beq @clock
  cmp #1
  bne @both
  lda GAME_DIP_A
  and #DIP_A_TWO_CREDITS
  bne @one
@both:
  lda #PAGE_COIN_TWO
  bra @title
@one:
  lda #PAGE_COIN_ONE
@title:
  cmp CAB_PAGE
  beq @start
  pha
  jsl cabinet_clear_play
  pla
  jsl cabinet_select
  stz CAMERA_STAGE              ; the first stage loads during the wait
  lda #WORLD_NONE
  sta CAB_WORLD_TARGET
@start:
  lda CAB_KEYS
  and #SYSTEM_START1
  bne @one_player
  lda CAB_KEYS
  and #SYSTEM_START2
  bne :+
  jmp .loword(@idle_sea)
:
  lda GAME_DIP_A
  and #DIP_A_TWO_CREDITS
  beq @two_cost_one
  lda GAME_CREDITS
  cmp #2
  bcs :+
  jmp .loword(@idle_sea)
:
  dec GAME_CREDITS
@two_cost_one:
  lda #1
  sta GAME_TWO_PLAYERS
  bra @pay
@one_player:
  stz GAME_TWO_PLAYERS
@pay:
  dec GAME_CREDITS
  lda #1
  sta CAB_START_PENDING
  jsl audio_start_music_begin
@done:
  rtl
@clock:
  lda CAB_DEMO
  beq @presentation
  inc CAB_BLINK
  lda CAB_BLINK
  cmp #BLINK_PERIOD
  bcc :+
  stz CAB_BLINK
:
  rtl
@presentation:
  lda CAB_PAGE
  cmp CAB_LOADED
  beq :+
  jmp .loword(@idle_sea)        ; the page still loads
:
  cmp #PAGE_TITLE
  beq @plane
  cmp #PAGE_RANKING
  bne @timer
@plane:
  lda CAB_PAGE
  cmp #PAGE_TITLE
  bne @ranking_preload
  inc CAB_BLINK
  lda CAB_BLINK
  cmp #BLINK_PERIOD
  bcc @plane_draw
  stz CAB_BLINK
  bra @plane_draw
@ranking_preload:
  ; The ranking stays on the card; at RANKING_PRELOAD the world loader takes
  ; the art surface back for the demo (GAME_FLOW PAGE_RANKING_FIRST).
  lda GAME_FLOW
  cmp #PAGE_RANKING_FIRST
  beq @timer
  a16
  lda CAB_WAIT
  cmp #RANKING_PRELOAD
  a8
  bcs @plane_draw
  lda #PAGE_RANKING_FIRST
  sta GAME_FLOW
  lda #ATTRACT_STAGE
  sta CAMERA_STAGE
  a16
  lda #INTRO_SCROLL
  sta CAMERA_BG1_SCROLL
  a8
  bra @timer
@plane_draw:
  jsr .loword(cabinet_plane_tick)
@timer:
  a16
  lda CAB_WAIT
  beq @advance
  dec CAB_WAIT
  bne @idle16
@advance:
  a8
  lda CAB_PAGE
  cmp #PAGE_POWER_ON
  bne @after_warning
  jsl cabinet_clear_play
  lda #ATTRACT_STAGE            ; the land section of the third stage
  sta CAMERA_STAGE
  inc GAME_RNG_SKIP             ; 1943ua: the coin task misses this frame
  lda #PAGE_RANKING_FIRST
  bra @ranking
@after_warning:
.a8
  cmp #PAGE_TITLE
  bne @demo
  lda #PAGE_RANKING
@ranking:
  jsl cabinet_select
  a16
  lda #RANKING_TICKS
  sta CAB_WAIT
  bra @idle16
@demo:
.a8
  jmp .loword(cabinet_demo_start)
@idle16:
  a8
@idle_sea:
  a16
  inc CAMERA_BG2_SCROLL          ; the sea scrolls under the pages
  lda CAMERA_BG2_SCROLL
  and #SEA_IDLE_WRAP-1
  sta CAMERA_BG2_SCROLL
  a8
  rtl

; cabinet_clear_play: no sound, no play: the players, the camera (the intro
; rows), the stage flags and the game state cleared. JSL.
cabinet_clear_play:
  lda #SND_STOP_ALL
  jsl game_sound_request
  jsl gameplay_reset_far
  a16
  ldx #2*PLAYER_SIZE-2
@players:
  stz PLAYER,x
  dex
  dex
  bpl @players
  ldx #CAMERA_SIZE-2
@camera:
  stz CAMERA,x
  dex
  dex
  bpl @camera
  lda #INTRO_SCROLL
  sta CAMERA_BG1_SCROLL
  stz GAME_SEQUENCE_TICKS
  ldx #STAGE_FLAGS_SIZE-2
@flags:
  stz STAGE_FLAGS,x
  dex
  dex
  bpl @flags
  a8
  stz GAME_OUT
  stz GAME_SEQUENCE
  stz GAME_STAGE_EXIT
  stz STAGE_BOSS_COUNT
  stz PLAYER_UI_MODE
  stz PLAYER_UI_MODE+1
  stz CAB_DEMO
  rtl

; cabinet_demo_start: the demo starts when its world is loaded (the quiet
; title time loads it; the ranking scrolls until the last upload is in);
; else the world loads under the first ranking. The demo: two players from
; the arcade templates, the attract stage, 2 * LOOPS_PER_PLAYER loops, and a
; death ends the demo (no continue). JSL.
cabinet_demo_start:
  lda WORLD_TAGS
  cmp #WORLD_DEMO_ID
  beq @ready
  lda WORLD_TAGS+1
  cmp #WORLD_DEMO_ID
  beq @ready
  lda CAB_PAGE
  cmp #PAGE_RANKING_FIRST
  beq :+
  lda #PAGE_RANKING_FIRST
  jsl cabinet_select
:
  lda #ATTRACT_STAGE
  sta CAMERA_STAGE
  lda #WORLD_NONE
  sta CAB_WORLD_TARGET
  a16
  lda #INTRO_SCROLL
  sta CAMERA_BG1_SCROLL
  a8
  rtl
@ready:
  jsl cabinet_clear_play
  a16
  ldx #PLAYER_TEMPLATE-2
@players:
  lda f:cabinet_demo_player,x
  sta PLAYER,x
  lda f:cabinet_demo_player_two,x
  sta PLAYER2,x
  dex
  dex
  bpl @players
  lda #DEMO_BG1_SCROLL
  sta CAMERA_BG1_SCROLL
  lda #DEMO_BG2_SCROLL
  sta CAMERA_BG2_SCROLL
  lda #DEMO_STAGE_OFFSET
  sta CAMERA_STAGE_OFFSET
  stz CAB_DEMO_POS
  a8
  lda #ATTRACT_STAGE
  sta CAMERA_STAGE
  lda #1
  sta CAMERA_BG2_DIVISOR
  sta CAB_DEMO                  ; DEMO_PLAY
  sta GAME_TWO_PLAYERS
  lda #2*LOOPS_PER_PLAYER
  stz SPECIAL_TIMER
  stz BULLET_SUPPRESS
  sta GAME_CONTINUE_LEVEL       ; SPECIAL_LOOPS
  jsl special_sync_shadow
  lda #WORLD_NONE
  sta CAB_WORLD_TARGET
  stz CAB_DEMO_HOLD
  stz CAB_BLINK
  stz DEATH_PLAYING             ; the attract: a death ends the demo
  stz DEATH_DEMO_END
  stz GAME_FLOW
  stz CAB_PAGE
  stz CAB_LOADED
  ldx #0
  jsl player_energy_hud_far
  ldx #PLAYER_SIZE
  jsl player_energy_hud_far
  rtl
.assert DEMO_PLAY = 1, error

; cabinet_controls: one game tick of the demo: INPUT_P1 and INPUT_P2 from
; the arcade's recorded demo controls (cabinet_demo_controls: the ticks to
; hold, then a cabinet_demo_dictionary pair). After DEMO_END_TICKS of
; DEMO_END the title comes back; in that wait no control is held. JSL.
cabinet_controls:
  lda CAB_DEMO
  bne :+
  rtl
:
  cmp #DEMO_END
  beq @tail
  ldx CAB_DEMO_POS
  lda CAB_DEMO_HOLD
  bne @controls
  lda f:cabinet_demo_controls+1,x
  cmp #FRAMES_END
  beq @end
  phx
  a16
  and #$00ff
  asl
  tax
  lda f:cabinet_demo_dictionary,x
  sta f:cabinet_demo_cached
  a8
  plx
  lda f:cabinet_demo_controls,x
  sta CAB_DEMO_HOLD
@controls:
  lda f:cabinet_demo_cached
  sta INPUT_P1
  lda f:cabinet_demo_cached+1
  sta INPUT_P2
  dec CAB_DEMO_HOLD
  bne @done
  inx
  inx
  stx CAB_DEMO_POS
@done:
  rtl
@end:
  jsl cabinet_demo_finish
@tail:
  a16
  dec CAB_WAIT
  bne @tail_done
  a8
  lda #PAGE_TITLE
  jsl cabinet_select
  rtl
@tail_done:
  a8
  lda #INPUT_NONE
  sta INPUT_P1
  sta INPUT_P2
  rtl

; cabinet_demo_finish: the demo ends at the first finished player death
; (arcade $8BCF-$8BDD) or at the end of the controls ($19F0): DEMO_END for
; DEMO_END_TICKS. The play stays frozen; the coins and the cabinet clock
; run. JSL.
cabinet_demo_finish:
  lda CAB_DEMO
  cmp #DEMO_PLAY
  bne @done
  lda #DEMO_END
  sta CAB_DEMO
  a16
  lda #DEMO_END_TICKS
  sta CAB_WAIT
  a8
@done:
  rtl

; cabinet_plane_tick: the P-38 fly-in of the title: each step of
; cabinet_plane_frames holds its ticks, then sets CAMERA_BG1_SCROLL (the
; plane rows). JSR.
cabinet_plane_tick:
  lda CAB_PLANE_WAIT
  sec
  sbc #PLANE_TICKS
  sta CAB_PLANE_WAIT
  bcc @next
  beq @next
  rts
@next:
  lda CAB_PLANE_STEP
  a16
  and #255
  tax
  a8
  lda f:cabinet_plane_frames,x
  cmp #FRAMES_END
  beq @done
  clc
  adc CAB_PLANE_WAIT            ; keep the odd tick between 30 Hz pictures
  sta CAB_PLANE_WAIT
  a16
  lda f:cabinet_plane_frames+1,x
  sta CAMERA_BG1_SCROLL
  a8
  inx
  inx
  inx                           ; PLANE_STEP_SIZE
  txa
  sta CAB_PLANE_STEP
@done:
  rts

; cabinet_wire_mode: A = the layout of this packet (the first byte of the
; world trailer), apart from the play state; LAYOUT_LOADING while a page
; picture loads. JSL.
cabinet_wire_mode:
  lda CAB_RESULT_ACTIVE
  beq @ordinary
  lda CAB_RESULT_PHASE
  bne @statistics
  lda CAB_RESULT_DATA+CRD_RESULT
  beq @success
  lda CAB_RESULT_DATA+CRD_FLAGS
  and #CRD_RETRY
  beq :+
  lda #LAYOUT_FAILED_RETRY
  rtl
:
  lda #LAYOUT_FAILED
  rtl
@success:
  lda CAB_RESULT_DATA+CRD_STAGE
  clc
  adc #LAYOUT_SUCCESS
  rtl
@statistics:
  lda CAB_RESULT_DATA+CRD_REFILL
  bne :+
  lda CAB_RESULT_DATA+CRD_BAND
  clc
  adc #LAYOUT_STATISTICS_NIL
  rtl
:
  lda CAB_RESULT_DATA+CRD_BAND
  clc
  adc #LAYOUT_STATISTICS
  rtl
@ordinary:
  lda CAB_DEMO
  cmp #DEMO_END
  beq @demo                     ; INSERT COIN still blinks
  lda GAME_FLOW
  cmp #PAGE_RANKING_FIRST
  bne :+
  lda CAB_PAGE
  cmp #PAGE_RANKING
  bne :+
  lda #PAGE_RANKING             ; the ranking stays while the demo loads
  rtl
:
  lda GAME_FLOW
  beq @demo
  cmp #PAGE_TITLE
  beq @static
  cmp #PAGE_POWER_ON
  beq @static
  cmp #PAGE_ENDING_FIRST
  bcc @done
  cmp #PAGE_ENDING_END
  bcs @done
@static:
  cmp CAB_LOADED
  beq @done
  ora #LAYOUT_LOADING
  rtl
@demo:
  lda CAB_LIVE_LAYOUT
  beq :+
  lda #LAYOUT_LIVE              ; the live initials; the play goes on
  rtl
:
  lda CAB_DEMO
  beq @done
  lda CAB_BLINK
  cmp #BLINK_ON
  lda #LAYOUT_DEMO
  bcc @done
  inc                           ; LAYOUT_DEMO_BLINK
@done:
  rtl

; cabinet_world_request: A = CAB_WORLD_TARGET when it is set, else A stays
; (the world loader's choice). JSL.
cabinet_world_request:
  pha
  lda CAB_WORLD_TARGET
  cmp #WORLD_NONE
  beq @normal
  sta 1,s
@normal:
  pla
  rtl

; cabinet_start: a game starts: the players from the arcade templates (P2 in
; a game of two; with one player P2 is out), LOOPS_PER_PLAYER loops for
; each player, the camera at START_SCROLL, the stage flags cleared, the
; takeoff (STAGE_FINISH), all spawn slots; a difficulty changed in the menu
; (game_difficulty_init). JSL.
cabinet_start:
  lda GAME_DIP_A                ; a difficulty changed in the menu applies now
  eor #$ff
  and #DIP_A_LEVEL
  cmp STAGE_DIP_LEVEL
  beq :+
  jsr .loword(game_difficulty_init)
:
  jsl native_dive_reset
  jsl cabinet_live_reset
  jsl input_mouse_center
  lda #1
  sta DEATH_PLAYING
  stz DEATH_DEMO_END
  stz CAB_START_PENDING
  stz CAB_DEMO
  stz CAB_ENDING
  stz CAB_RESULT_ACTIVE
  lda #WORLD_NONE
  sta CAB_WORLD_TARGET
  stz GAME_OUT
  stz SPECIAL_TIMER
  stz BULLET_SUPPRESS
  lda GAME_TWO_PLAYERS          ; LOOPS_PER_PLAYER for each player
  beq :+
  lda #LOOPS_PER_PLAYER
:
  clc
  adc #LOOPS_PER_PLAYER
  sta SPECIAL_LOOPS
  jsl special_sync_shadow
  stz PLAYER_UI_MODE
  stz PLAYER_UI_MODE+1
  a16
  ldx #2*SCORE_DIGITS-2
@clear_attempts:
  stz CAB_ENDING_SCORES,x
  dex
  dex
  bpl @clear_attempts
  a8
  lda GAME_TWO_PLAYERS
  bne :+
  lda #OUT_P2
  sta GAME_OUT
:
  jsl gameplay_reset_far
  a16
  ldx #2*PLAYER_SIZE-2
@player:
  stz PLAYER,x
  dex
  dex
  bpl @player
  ldx #PLAYER_TEMPLATE-2
@template:
  lda f:cabinet_player_start,x
  sta PLAYER,x
  dex
  dex
  bpl @template
  a8
  lda GAME_TWO_PLAYERS
  beq @one
  a16
  ldx #PLAYER_TEMPLATE-2
@second:
  lda f:cabinet_player_two_start,x
  sta PLAYER2,x
  dex
  dex
  bpl @second
@one:
  a8
  lda #1
  sta PLAYER2+PL_NUMBER
  a16
  ldx #CAMERA_SIZE-4            ; all but the last word of the camera
@camera:
  stz CAMERA,x
  dex
  dex
  bpl @camera
  lda #START_SCROLL
  sta CAMERA_BG1_SCROLL
  stz SEA_CAMERA
  sta FG_CAMERA
  stz GAME_SEQUENCE_TICKS
  ldx #STAGE_FLAGS_SIZE-2
@flags:
  stz STAGE_FLAGS,x
  dex
  dex
  bpl @flags
  a8
  lda #1
  sta CAMERA_BG2_DIVISOR
  sta STAGE_FINISH              ; arcade E150: the takeoff
  lda #ENEMY_COUNT              ; spawns may use all the small-object slots
  sta STAGE_SPAWN_SLOTS
  stz GAME_FLOW
  stz GAME_SEQUENCE
  stz GAME_STAGE_EXIT
  stz STAGE_BOSS_COUNT
  stz PLAYER+PL_CADENCE         ; the arcade fire timer starts cleared
  ldx #0
  jsl player_energy_hud_far
  lda GAME_TWO_PLAYERS
  beq :+
  ldx #PLAYER_SIZE
  jsl player_energy_hud_far
:
  rtl

; cabinet_ending: the game is complete: keep the scores of the players in
; the game (CAB_POST_MASK), clear the play, then the ending pages
; (ENDING_PAGES) from PAGE_ENDING_FIRST. JSL.
cabinet_ending:
  phx
  phy
  stz CAB_POST_MASK
  lda PLAYER+PL_STATE
  beq :+
  inc CAB_POST_MASK
  ldx #0
  ldy #0
  jsr .loword(native_retain_score)
  jsr .loword(native_restore_score)
:
  lda PLAYER2+PL_STATE
  beq :+
  lda CAB_POST_MASK
  ora #2                        ; bit 1: player 2; bit 0: player 1
  sta CAB_POST_MASK
  ldx #PLAYER_SIZE
  ldy #1
  jsr .loword(native_retain_score)
  jsr .loword(native_restore_score)
:
  ply
  plx
  jsl cabinet_save_scores
  jsl cabinet_clear_play
  phx
  a16
  ldx #SCORE_DIGITS-2
@restore_scores:
  lda CAB_ENDING_SCORES,x
  sta PLAYER+PL_SCORE,x
  lda CAB_ENDING_SCORES+SCORE_DIGITS,x
  sta PLAYER2+PL_SCORE,x
  dex
  dex
  bpl @restore_scores
  a8
  plx
  jsl cabinet_actors_init
  lda #ENDING_PAGES
  sta CAB_ENDING
  stz CAB_ENDING_STEP
  stz CAB_ENDING_TEXT
  lda #PAGE_ENDING_FIRST
  jsl cabinet_select
  lda #PAGE_ENDING_FIRST
  jsl cabinet_text_select
  lda #SND_STOP_ALL             ; the stage music stops before the ending
  jsl game_sound_request
  rtl

; cabinet_ending_tick: one update of the ending: the actors and the typed
; text of the page; a finished page goes to the next (cabinet_ending_pages,
; its sound); after the last one, the initials (cabinet_post) when the live
; initials are done. ENDING_POST runs cabinet_post_tick. JSL.
cabinet_ending_tick:
  lda CAB_ENDING
  cmp #ENDING_POST
  bne :+
  jml cabinet_post_tick
:
  lda CAB_PAGE
  cmp CAB_LOADED
  bne @done
  jsl fm_ending_hint
  jsl cabinet_actors_tick
  jsl cabinet_text_tick
  lda CAB_TEXT_DONE
  bne :+
  rtl
:
  inc CAB_ENDING_STEP
  lda CAB_ENDING_STEP
  cmp #CAB_ENDING_PAGES
  bcs @rank
  a16
  and #255
  tax
  a8
  lda f:cabinet_ending_pages,x
  jsl cabinet_select
  lda f:cabinet_ending_sounds,x
  cmp #NO_SOUND
  beq :+
  jsl game_sound_request
:
  lda CAB_PAGE
  jsl cabinet_text_select
@done:
  rtl
@rank:
  lda CAB_LIVE_STATE
  ora CAB_LIVE_STATE+1
  beq :+
  dec CAB_ENDING_STEP           ; the live initials finish first
  rtl
:
  jsl fm_ending_hint_clear
  jml cabinet_post_begin

; cabinet_append: the next upload of the page picture (CABINET_PAGES: a long
; pointer to its upload list for each page) in the packet, words
; byte-swapped; LAYOUT_LOADING keeps the old picture while it loads. Then
; X = the packet end. JSL; A16.
cabinet_append:
  lda CAB_PAGE
  sta CAB_PACKET_MODE
  cmp CAB_LOADED
  bne @upload
  jmp .loword(world_no_upload)
@upload:
  ora #LAYOUT_LOADING
  sta CAB_PACKET_MODE
  lda CAB_LOADING
  bne @entry
  lda #1
  sta CAB_LOADING
  a16
  lda CAB_PAGE
  and #255
  asl
  asl                           ; a long pointer for each page
  tax
  lda f:CABINET_PAGES,x
  sta CAB_LIST
  lda f:CABINET_PAGES+2,x
  sta CAB_LIST+2
  stz CAB_OFFSET
  a8
@entry:
  a16
  lda CAB_LIST
  sta CAB_POINTER
  lda CAB_LIST+2
  sta CAB_POINTER+2
  ldy CAB_OFFSET
  lda [CAB_POINTER],y
  bne @copy
  a8                            ; the list end: the page is loaded
  lda CAB_PAGE
  sta CAB_LOADED
  sta CAB_PACKET_MODE
  stz CAB_LOADING
  jmp .loword(world_no_upload)
@copy:
  sta CAB_LENGTH
  iny
  iny
  lda [CAB_POINTER],y
  sta CAB_SOURCE
  iny
  iny
  lda [CAB_POINTER],y
  sta CAB_SOURCE+2
  iny
  iny                           ; UPLOAD_SIZE
  sty CAB_OFFSET
  jsl d500_stage_layout
  jsr .loword(cabinet_copy_layout)
  stx WORLD_OUTPUT
  rtl
.assert UPLOAD_SIZE = 6, error

; cabinet_copy_layout: the CAB_LENGTH bytes at CAB_SOURCE into the packet at
; WORLD_OUTPUT (packet_copy). JSR; A16. Out: X = the end in the packet.
cabinet_copy_layout:
.a16
  a8
  lda CAB_SOURCE+2
  sta f:packet_copy_bank
  a16
  lda CAB_LENGTH
  ldx WORLD_OUTPUT
  ldy CAB_SOURCE
  jsl packet_copy
  rts

cabinet_demo_cached: .word 0    ; the cabinet_demo_dictionary pair now held
; game_flow_tick: the coins for one credit and the credits for one coin, for
; each coin setting.
cabinet_coin_required: .byte 4,3,2,1,1,1,1,1
cabinet_coin_awarded: .byte 1,1,1,5,4,3,2,1

.include "cabinet_result.s"
.include "cabinet_text.s"
.include "cabinet_actors.s"

; cabinet_layout_append: the text list of the layout (CABINET_LAYOUTS), only
; when the layout changes: an upload of the same bounded form as the world
; data (no VRAM and no arcade text decode at run time). The rankings get
; their score fields (cabinet_rank_packet). Carry 1: the packet has it; X =
; the packet end. JSL; A8 in, A16 out.
cabinet_layout_append:
.a8
  jsl cabinet_wire_mode
  and #<~LAYOUT_LOADING
  cmp #PAGE_TITLE
  bne :+
  lda CAB_BLINK
  cmp #BLINK_ON
  lda #PAGE_TITLE
  bcs :+
  lda #LAYOUT_TITLE_PROMPT
:
  cmp #0
  beq @none
  cmp #PAGE_POWER_ON
  beq @none
  cmp #LAYOUT_LIVE              ; the live initials never hold back a world upload
  beq @none
  pha
  lda CAB_ENDING
  cmp #ENDING_POST
  bne :+
  pla
  jml cabinet_post_append
:
  pla
  cmp #LAYOUT_DEMO_BLINK        ; both demo layouts use the LAYOUT_DEMO list
  bne :+
  dec
:
  cmp CAB_LAYOUT_LOADED
  beq @none
  sta CAB_LAYOUT_LOADED
  a16
  and #<~LAYOUT_LOADING
  asl
  sta CAB_SOURCE                ; the layout times 2, then times LAYOUT_SIZE
  asl
  adc CAB_SOURCE
  tax
  lda f:CABINET_LAYOUTS,x
  sta CAB_LENGTH
  lda f:CABINET_LAYOUTS+2,x
  sta CAB_SOURCE
  lda f:CABINET_LAYOUTS+4,x
  sta CAB_SOURCE+2
  jsl d500_stage_layout
  jsr .loword(cabinet_copy_layout)
  a8
  lda CAB_LAYOUT_LOADED
  cmp #PAGE_RANKING_FIRST
  beq @rank_fields
  cmp #PAGE_RANKING
  bne @copied
@rank_fields:
  jsl cabinet_rank_packet
@copied:
  a16
  lda WORLD_OUTPUT
  clc
  adc CAB_LENGTH
  tax
  sec
  rtl
@none:
  a16
  ldx WORLD_OUTPUT
  clc
  rtl
.assert LAYOUT_SIZE = 6, error
