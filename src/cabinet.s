; Native cabinet presentation. Timers advance with the game clock, not draws.
; ROM material below is text, art and the authored attract control sequence.
.a8
.i16
CAB_PAGE = $14c0
CAB_LOADED = $14c1
CAB_LOADING = $14c2
CAB_WAIT = $14c4
CAB_LIST = $14c6
CAB_OFFSET = $14ca
CAB_LENGTH = $14cc
CAB_PACKET_MODE = $14ce
CAB_START_PENDING = $14cf
CAB_SCORES = $01b300
CAB_DEMO = $1520
CAB_DEMO_POS = $1522
CAB_DEMO_HOLD = $1524
CAB_BLINK = $1525
CAB_PLANE_STEP = $1526
CAB_PLANE_WAIT = $1527
CAB_WORLD_TARGET = $1528
CAB_KEYS = $1529
CAB_ENDING_STEP = $152a
CAB_ENDING = $152b
CAB_ENDING_TEXT = $1544
CAB_ENDING_RATE = $1545
CAB_LAYOUT_LOADED = $1546
GAME_RNG_SKIP = $17fc

cabinet_init:
  jsl native_dive_reset
  lda #5
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
  lda #255
  sta CAB_WORLD_TARGET
  rep #$20
  stz CAB_OFFSET
  lda #31                     ; first cabinet tick consumes one count immediately
  sta CAB_WAIT
  ldx #78
@score:
  lda f:cabinet_initial_scores,x
  sta f:CAB_SCORES,x
  dex
  dex
  bpl @score
  ldx #14
@clear_scores:
  stz CAB_ENDING_SCORES,x
  dex
  dex
  bpl @clear_scores
  sep #$20
  jsl cabinet_live_reset
  rtl

; Main-loop entry after live keyboard sampling. The ordinary flow owns coins
; and real-game continue rules. Demo input never replaces system/coin input.
cabinet_frame:
  jsl native_input_menu
  jsl cabinet_live_tick
  jsl cabinet_result_tick
  jsl game_flow_tick
  lda CAB_DEMO
  beq @done
  lda GAME_FLOW
  cmp #3
  bcs @done
  jsl cabinet_tick
@done:
  rtl

cabinet_select:
  pha
  jsl native_dive_reset
  lda CAB_ENDING
  beq @ordinary
  lda CAB_LOADED
  cmp #17
  bcc @ordinary
  pla
  sta CAB_PAGE
  sta GAME_FLOW
  sta CAB_LOADED               ; all ending text uses the one loaded tableau
  stz CAB_ENDING_TEXT
  stz CAB_ENDING_RATE
  rtl
@ordinary:
  pla
  sta CAB_PAGE
  sta GAME_FLOW
  stz CAB_LOADING
  stz CAB_DEMO
  rep #$20
  stz CAB_OFFSET
  sep #$20
  lda CAB_PAGE
  cmp #5
  beq @static
  cmp #17
  bcs @static
  sta CAB_LOADED
  cmp #4
  bne @done
  jsl cabinet_clear_play
  lda #255
  sta CAB_LOADED
  sta WORLD_TAGS+1             ; cabinet_surface borrows world slot 1 only
  sta CAB_WORLD_TARGET
  stz CAB_PLANE_STEP
  stz CAB_BLINK
  lda #2
  sta CAB_PLANE_WAIT
  rep #$20
  lda #$d000
  sta CAMERA+$0f
  lda #210                    ; $0324 plus $0330 = 420 arcade ticks
  sta CAB_WAIT
  sep #$20
@done:
  rtl
@static:
  lda #255
  sta CAB_LOADED
  rtl

cabinet_tick:
  lda $d0
  sta CAB_KEYS
  lda CAB_START_PENDING
  beq @coin
  lda CAB_LOADING
  bne @done
  lda WORLD_LOADING
  cmp #255
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
  and #16
  bne @one
@both:
  lda #7
  bra @title
@one:
  lda #6
@title:
  cmp CAB_PAGE
  beq @start
  pha
  jsl cabinet_clear_play
  pla
  jsl cabinet_select
  stz CAMERA_STAGE             ; preload the real first stage while waiting
  lda #255
  sta CAB_WORLD_TARGET
@start:
  lda CAB_KEYS
  and #1
  bne @one_player
  lda CAB_KEYS
  and #2
  bne :+
  jmp .loword(@idle_sea)
:
  lda GAME_DIP_A
  and #16
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
  cmp #45                     ; insert-coin blink: 60 on, 30 off game ticks
  bcc :+
  stz CAB_BLINK
:
  rtl
@presentation:
  lda CAB_PAGE
  cmp CAB_LOADED
  beq :+
  jmp .loword(@idle_sea)
:
  cmp #4
  beq @plane
  cmp #16
  bne @timer
@plane:
  lda CAB_PAGE
  cmp #4
  bne @ranking_preload
  inc CAB_BLINK
  lda CAB_BLINK
  cmp #45
  bcc @plane_draw
  stz CAB_BLINK
  bra @plane_draw
@ranking_preload:
  ; Once the ranking and plane have been composed on the hidden page, the
  ; borrowed art surface can be reused to prepare the next live demo. Keep
  ; displaying the ranking while the normal world loader fills that slot.
  lda GAME_FLOW
  cmp #3
  beq @timer
  rep #$20
  lda CAB_WAIT
  cmp #180
  sep #$20
  bcs @plane_draw
  lda #3
  sta GAME_FLOW
  lda #2
  sta CAMERA_STAGE
  rep #$20
  lda #$d000
  sta CAMERA+$0f
  sep #$20
  bra @timer
@plane_draw:
  jsr .loword(cabinet_plane_tick)
@timer:
  rep #$20
  lda CAB_WAIT
  beq @advance
  dec CAB_WAIT
  bne @idle16
@advance:
  sep #$20
  lda CAB_PAGE
  cmp #5
  bne @after_warning
  jsl cabinet_clear_play
  lda #2
  sta CAMERA_STAGE             ; attract uses the third stage's land section
  inc GAME_RNG_SKIP            ; coin task misses this transition frame in 1943ua
  lda #3
  bra @ranking
@after_warning:
.a8
  cmp #4
  bne @demo
  lda #16
@ranking:
  jsl cabinet_select
  rep #$20
  lda #240                    ; ranking: 480 arcade ticks
  sta CAB_WAIT
  bra @idle16
@demo:
.a8
  jmp .loword(cabinet_demo_start)
@idle16:
  sep #$20
@idle_sea:
  rep #$20
  inc CAMERA
  lda CAMERA
  and #$0fff
  sta CAMERA
  sep #$20
  rtl

cabinet_clear_play:
  lda #0
  jsl game_sound_request
  jsl gameplay_reset_far
  rep #$20
  ldx #254
@players:
  stz PLAYER,x
  dex
  dex
  bpl @players
  ldx #38
@camera:
  stz CAMERA,x
  dex
  dex
  bpl @camera
  lda #$d000                   ; resident, fully transparent intro map rows
  sta CAMERA+$0f
  stz GAME_SEQUENCE_TICKS
  ldx #62
@flags:
  stz STAGE_FLAGS,x
  dex
  dex
  bpl @flags
  sep #$20
  stz GAME_OUT
  stz GAME_SEQUENCE
  stz GAME_STAGE_EXIT
  stz STAGE_EVENTS
  stz STAGE_BOSS_COUNT
  stz PLAYER_UI_MODE
  stz PLAYER_UI_MODE+1
  stz CAB_DEMO
  rtl

cabinet_demo_start:
  ; Quiet title time loads the demo region. A bounded final upload may still
  ; be in flight; the displayed ranking keeps scrolling until it completes.
  lda WORLD_TAGS
  cmp #WORLD_DEMO_ID
  beq @ready
  lda WORLD_TAGS+1
  cmp #WORLD_DEMO_ID
  beq @ready
  lda CAB_PAGE
  cmp #3
  beq :+
  lda #3
  jsl cabinet_select
:
  lda #2
  sta CAMERA_STAGE
  lda #255
  sta CAB_WORLD_TARGET
  rep #$20
  lda #$d000
  sta CAMERA+$0f
  sep #$20
  rtl
@ready:
  jsl cabinet_clear_play
  rep #$20
  ldx #38
@players:
  lda f:cabinet_demo_player,x
  sta PLAYER,x
  lda f:cabinet_demo_player_two,x
  sta PLAYER+128,x
  dex
  dex
  bpl @players
  lda #$b000
  sta CAMERA+$0f
  lda #$3000
  sta CAMERA
 .ifdef STAGE_COMPACT
  lda #$18
 .else
  lda #$24
 .endif
  sta CAMERA+$11
  stz CAB_DEMO_POS
  sep #$20
  lda #2
  sta CAMERA_STAGE
  lda #1
  sta CAMERA+2
  sta CAB_DEMO
  sta GAME_TWO_PLAYERS
  lda #4
  stz SPECIAL_TIMER
  stz BULLET_CONTEXT+1
  sta GAME_CONTINUE_LEVEL
  jsl special_sync_shadow
  lda #255
  sta CAB_WORLD_TARGET
  stz CAB_DEMO_HOLD
  stz CAB_BLINK
  stz DEATH_CONTEXT+3          ; attract: death exits instead of offering continue
  stz DEATH_CONTEXT+6
  stz GAME_FLOW
  stz CAB_PAGE
  stz CAB_LOADED
  ldx #0
  jsl player_energy_hud_far
  ldx #128
  jsl player_energy_hud_far
  rtl

; Called once per native 59.637-Hz game tick. These controls are the arcade's
; authored ROM demo sequence, converted at build time; no captured play state.
cabinet_controls:
  lda CAB_DEMO
  bne :+
  rtl
:
  cmp #2
  beq @tail
  ldx CAB_DEMO_POS
  lda CAB_DEMO_HOLD
  bne @controls
  lda f:cabinet_demo_controls+1,x
  cmp #255
  beq @end
  phx
  rep #$20
  and #$00ff
  asl
  tax
  lda f:cabinet_demo_dictionary,x
  sta f:cabinet_demo_cached
  sep #$20
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
  rep #$20
  dec CAB_WAIT
  bne @tail_done
  sep #$20
  lda #4
  jsl cabinet_select
  rtl
@tail_done:
  sep #$20
  lda #255
  sta INPUT_P1
  sta INPUT_P2
  rtl

; The arcade ends attract at the first completed player death ($8BCF-$8BDD)
; or at the end of the authored controls ($19F0). Both wait 180 game ticks.
; Freeze gameplay during this wait, while coins and the cabinet clock run.
cabinet_demo_finish:
  lda CAB_DEMO
  cmp #1
  bne @done
  lda #2
  sta CAB_DEMO
  rep #$20
  lda #180
  sta CAB_WAIT
  sep #$20
@done:
  rtl

cabinet_plane_tick:
  lda CAB_PLANE_WAIT
  sec
  sbc #2
  sta CAB_PLANE_WAIT
  bcc @next
  beq @next
  rts
@next:
  lda CAB_PLANE_STEP
  rep #$20
  and #255
  tax
  sep #$20
  lda f:cabinet_plane_frames,x
  cmp #255
  beq @done
  clc
  adc CAB_PLANE_WAIT          ; retain the odd tick between 30 Hz pictures
  sta CAB_PLANE_WAIT
  rep #$20
  lda f:cabinet_plane_frames+1,x
  sta CAMERA+$0f
  sep #$20
  inx
  inx
  inx
  txa
  sta CAB_PLANE_STEP
@done:
  rts

; The first byte of the world trailer carries a display layout, independently
; of the host's live-game state. The next frame's raw packet stays untouched.
cabinet_wire_mode:
  lda CAB_RESULT_ACTIVE
  beq @ordinary
  lda CAB_RESULT_PHASE
  bne @statistics
  lda CAB_RESULT_DATA+1
  beq @success
  lda CAB_RESULT_DATA+7
  and #1
  beq :+
  lda #44
  rtl
:
  lda #31
  rtl
@success:
  lda CAB_RESULT_DATA
  clc
  adc #46
  rtl
@statistics:
  lda CAB_RESULT_DATA+5
  bne :+
  lda CAB_RESULT_DATA+3
  clc
  adc #62
  rtl
:
  lda CAB_RESULT_DATA+3
  clc
  adc #32
  rtl
@ordinary:
  lda CAB_DEMO
  cmp #2
  beq @demo                    ; the insert-coin prompt keeps blinking
  lda GAME_FLOW
  cmp #3
  bne :+
  lda CAB_PAGE
  cmp #16
  bne :+
  lda #16                     ; ranking stays visible while demo loads
  rtl
:
  lda GAME_FLOW
  beq @demo
  cmp #4
  beq @static
  cmp #5
  beq @static
  cmp #17
  bcc @done
  cmp #30
  bcs @done
@static:
  cmp CAB_LOADED
  beq @done
  ora #128
  rtl
@demo:
  lda CAB_LIVE_LAYOUT
  beq :+
  lda #85                     ; live text overlay, gameplay remains active
  rtl
:
  lda CAB_DEMO
  beq @done
  lda CAB_BLINK
  cmp #30
  lda #1
  bcc @done
  inc
@done:
  rtl

cabinet_world_request:
  pha
  lda CAB_WORLD_TARGET
  cmp #255
  beq @normal
  pla
  lda CAB_WORLD_TARGET
  rtl
@normal:
  pla
  rtl

cabinet_start:
  jsl native_dive_reset
  jsl cabinet_live_reset
  jsl input_mouse_center
  lda #1
  sta DEATH_CONTEXT+3
  stz DEATH_CONTEXT+6
  stz CAB_START_PENDING
  stz CAB_DEMO
  stz CAB_ENDING
  stz CAB_RESULT_ACTIVE
  lda #255
  sta CAB_WORLD_TARGET
  stz GAME_OUT
  stz GAME_CONTINUE_LEVEL
  jsl special_sync_shadow
  stz SPECIAL_TIMER
  stz BULLET_CONTEXT+1
  lda #2
  sta SPECIAL_LOOPS
  jsl special_sync_shadow
  lda GAME_TWO_PLAYERS
  beq :+
  lda #4
  sta SPECIAL_LOOPS
  jsl special_sync_shadow
:
  stz PLAYER_UI_MODE
  stz PLAYER_UI_MODE+1
  rep #$20
  ldx #14
@clear_attempts:
  stz CAB_ENDING_SCORES,x
  dex
  dex
  bpl @clear_attempts
  sep #$20
  lda GAME_TWO_PLAYERS
  bne :+
  lda #2
  sta GAME_OUT
:
  jsl gameplay_reset_far
  rep #$20
  ldx #254
@player:
  stz PLAYER,x
  dex
  dex
  bpl @player
  ldx #38
@template:
  lda f:cabinet_player_start,x
  sta PLAYER,x
  dex
  dex
  bpl @template
  sep #$20
  lda GAME_TWO_PLAYERS
  beq @one
  rep #$20
  ldx #38
@second:
  lda f:cabinet_player_two_start,x
  sta PLAYER+128,x
  dex
  dex
  bpl @second
@one:
  sep #$20
  lda #1
  sta PLAYER+$85
  rep #$20
  ldx #36
@camera:
  stz CAMERA,x
  dex
  dex
  bpl @camera
  lda #$d0ff                    ; US $0F2A, before the first native event
  sta CAMERA+$0f
  stz $6c
  sta $6e
  stz GAME_SEQUENCE_TICKS
  ldx #62
@flags:
  stz STAGE_FLAGS,x
  dex
  dex
  bpl @flags
  sep #$20
  lda #1
  sta CAMERA+2
  sta STAGE_FLAGS+$10           ; original E150, takeoff control
  lda #16
  sta STAGE_DIFFICULTY+6
  stz GAME_FLOW
  stz GAME_SEQUENCE
  stz GAME_STAGE_EXIT
  stz STAGE_EVENTS
  stz STAGE_BOSS_COUNT
  stz DEATH_CONTEXT+5
  lda #1
  sta DEATH_CONTEXT+4
  stz PLAYER+$54             ; start with the cleared arcade fire timer
  ldx #0
  jsl player_energy_hud_far
  lda GAME_TWO_PLAYERS
  beq :+
  ldx #128
  jsl player_energy_hud_far
:
  rtl


cabinet_ending:
  ; Preserve the completed scores while clearing live gameplay objects.
  phx
  phy
  stz CAB_POST_MASK
  lda PLAYER+8
  beq :+
  inc CAB_POST_MASK
  ldx #0
  ldy #0
  jsr .loword(native_retain_score)
  jsr .loword(native_restore_score)
:
  lda PLAYER+$88
  beq :+
  lda CAB_POST_MASK
  ora #2
  sta CAB_POST_MASK
  ldx #128
  ldy #1
  jsr .loword(native_retain_score)
  jsr .loword(native_restore_score)
:
  ply
  plx
  jsl cabinet_save_scores
  jsl cabinet_clear_play
  phx
  rep #$20
  ldx #6
@restore_scores:
  lda CAB_ENDING_SCORES,x
  sta PLAYER+$38,x
  lda CAB_ENDING_SCORES+8,x
  sta PLAYER+$b8,x
  dex
  dex
  bpl @restore_scores
  sep #$20
  plx
  jsl cabinet_actors_init
  lda #1
  sta CAB_ENDING
  stz CAB_ENDING_STEP
  stz CAB_ENDING_TEXT
  stz CAB_ENDING_RATE
  lda #17
  jsl cabinet_select
  lda #17
  jsl cabinet_text_select
  lda #0                      ; stop the stage cue before the ending opens
  jsl game_sound_request
  rtl

cabinet_ending_tick:
  lda CAB_ENDING
  cmp #2
  bne :+
  jml cabinet_post_tick
:
  lda CAB_PAGE
  cmp CAB_LOADED
  bne @done
 .ifdef AUDIO_FM
  jsl fm_ending_hint
 .endif
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
  rep #$20
  and #255
  tax
  sep #$20
  lda f:cabinet_ending_pages,x
  jsl cabinet_select
  lda f:cabinet_ending_sounds,x
  cmp #255
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
  dec CAB_ENDING_STEP          ; finish active initials before this handoff
  rtl
:
 .ifdef AUDIO_FM
  jsl fm_ending_hint_clear
 .endif
  jml cabinet_post_begin
; Return X after the appended, word-swapped upload batch, M=16.
cabinet_append:
  lda CAB_PAGE
  sta CAB_PACKET_MODE
  cmp CAB_LOADED
  bne @upload
  jmp .loword(world_no_upload)
@upload:
  ora #$80                      ; retain the old complete picture while loading
  sta CAB_PACKET_MODE
  lda CAB_LOADING
  bne @entry
  lda #1
  sta CAB_LOADING
  rep #$20
  lda CAB_PAGE
  and #255
  asl
  asl
  tax
  lda f:CABINET_PAGES,x
  sta CAB_LIST
  lda f:CABINET_PAGES+2,x
  sta CAB_LIST+2
  stz CAB_OFFSET
  sep #$20
@entry:
  rep #$20
  lda CAB_LIST
  sta $d0
  lda CAB_LIST+2
  sta $d2
  ldy CAB_OFFSET
  lda [$d0],y
  bne @copy
  sep #$20
  lda CAB_PAGE
  sta CAB_LOADED
  sta CAB_PACKET_MODE
  stz CAB_LOADING
  jmp .loword(world_no_upload)
@copy:
  sta CAB_LENGTH
  iny
  iny
  lda [$d0],y
  sta $d4
  iny
  iny
  lda [$d0],y
  sta $d6
  iny
  iny
  sty CAB_OFFSET
  jsl d500_stage_layout
  ldx WORLD_OUTPUT
  ldy #0
@word:
  lda [$d4],y
  xba
  sta a:0,x
  inx
  inx
  iny
  iny
  cpy CAB_LENGTH
  bcc @word
  stx WORLD_OUTPUT
  rtl

cabinet_demo_cached: .word 0
cabinet_coin_required: .byte 4,3,2,1,1,1,1,1
cabinet_coin_awarded: .byte 1,1,1,5,4,3,2,1

.include "cabinet_result.s"
.include "cabinet_text.s"
.include "cabinet_actors.s"

; Prepared text list, sent only on a page change. This uses the same bounded
; SRAM upload format as the world data, with no VRAM allocation or decoding
; of the arcade text format at runtime. Carry set means this packet is done.
cabinet_layout_append:
.a8
  jsl cabinet_wire_mode
  and #127
  cmp #4
  bne :+
  lda CAB_BLINK
  cmp #30
  lda #4
  bcs :+
  lda #86
:
  cmp #0
  beq @none
  cmp #5
  beq @none
  cmp #85                     ; resident initials never defer a world upload
  beq @none
  pha
  lda CAB_ENDING
  cmp #2
  bne :+
  pla
  jml cabinet_post_append
:
  pla
  cmp #2
  bne :+
  dec
:
  cmp CAB_LAYOUT_LOADED
  beq @none
  sta CAB_LAYOUT_LOADED
  rep #$20
  and #127
  asl
  sta $d4
  asl
  adc $d4
  tax
  lda f:CABINET_LAYOUTS,x
  sta CAB_LENGTH
  lda f:CABINET_LAYOUTS+2,x
  sta $d4
  lda f:CABINET_LAYOUTS+4,x
  sta $d6
  jsl d500_stage_layout
  ldx WORLD_OUTPUT
  ldy #0
@copy:
  lda [$d4],y
  xba
  sta a:0,x
  inx
  inx
  iny
  iny
  cpy CAB_LENGTH
  bcc @copy
  sep #$20
  lda CAB_LAYOUT_LOADED
  cmp #3
  beq @rank_fields
  cmp #16
  bne @copied
@rank_fields:
  jsl cabinet_rank_packet
@copied:
  rep #$20
  lda WORLD_OUTPUT
  clc
  adc CAB_LENGTH
  tax
  sec
  rtl
@none:
  rep #$20
  ldx WORLD_OUTPUT
  clc
  rtl
