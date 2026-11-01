; The continue of each player (the times are updates at 59.637 Hz): the
; join prompt, the CONTINUE countdown and GAME OVER, each player on its own;
; the entry of a player; the scores kept for the ending; the dive.
.a8
.i16
PROMPT_TIME = 60             ; updates of a prompt or a countdown step
OVER_ON_TIME = 45            ; updates GAME OVER shows
OVER_OFF_TIME = 30           ; updates GAME OVER is off
OVER_BLINKS = 8              ; GAME OVER blinks without a continue
OVER_BLINKS_LATE = 6         ; after the countdown
COUNTDOWN_SOUND = 10         ; SND_COUNTDOWN at this count
CONTINUE_START = 2           ; GAME_CONTINUE_LEVEL steps up by this
CONTINUE_LEVEL_MAX = 4
PLAYER_CROSS_RADIUS = 7      ; PL_CROSS_RADIUS of a new plane
PLAYER_ALONG_RADIUS = 5
RESPAWN_IMMUNE = 32          ; PL_IMMUNE after a continue
RESPAWN_ALONG = $f0          ; a new plane starts below the field
RESPAWN_CROSS_P1 = $30
RESPAWN_CROSS_P2 = $b0
ENTRY_STEP = 2               ; native_player_entry: the along step

; native_player_wait: one update of a player out of the play (PL_STATE 0;
; game_players_tick, X = PLAYER_CURSOR, Y = the player 0/1): the join
; prompt, or the CONTINUE countdown then GAME OVER. With a credit the start
; button of the player continues or joins. JSL.
native_player_wait:
  ldx PLAYER_CURSOR
  ldy #0
  cpx #0
  beq :+
  iny
:
  lda GAME_OUT
  cpy #0
  beq :+
  and #OUT_P2
  bra :++
:
  and #OUT_P1
:
  beq :+
  lda CAB_LIVE_STATE,y
  beq :+                        ; a player out can join after the initials
  rtl
:
  ; The first update: keep the score; after a death the countdown starts
  ; (GAME OVER without a continue), else the join prompt.
  lda PLAYER+PL_PROMPT,x
  bne @start_button
  jsr .loword(native_retain_score)
  lda #1
  sta PLAYER+PL_PROMPT_DELAY,x
  lda #PROMPT_ON
  sta PLAYER+PL_PROMPT,x
  lda PLAYER+PL_COUNTDOWN,x
  beq @start_button
  lda #PROMPT_COUNTDOWN
  sta PLAYER+PL_PROMPT,x
  lda CAMERA_STAGE
  cmp #STAGES
  beq @no_continue
  lda GAME_DIP_B
  and #DIP_B_CONTINUE
  bne @start_button
@no_continue:
  lda #PROMPT_OVER_ON
  sta PLAYER+PL_PROMPT,x
  lda #OVER_BLINKS
  sta PLAYER+PL_COUNTDOWN,x
  lda #SND_CONTINUE_MUSIC
  jsl game_sound_request
@start_button:
  lda CAMERA_STAGE
  cmp #STAGES
  beq @clock
  lda PLAYER+PL_PROMPT,x
  and #PROMPT_OVER_BITS
  bne @clock
  lda GAME_CREDITS
  beq @clock
  lda INPUT_SYSTEM
  cpy #0
  beq :+
  lsr                           ; SYSTEM_START2
:
  and #SYSTEM_START1            ; pressed = 0
  bne @clock
  dec GAME_CREDITS
  lda PLAYER+PL_PROMPT,x
  cmp #PROMPT_COUNTDOWN
  bne @join
  lda #SND_STOP_EFFECTS
  jsl game_sound_request
  bra @restart
@join:
  ; A new join is a fresh aircraft, unlike an ordinary continue.
  stz PLAYER+PL_WINGS,x
  stz PLAYER+PL_BANK_INDEX,x
  stz PLAYER+PL_WEAPON,x
  stz PLAYER+PL_WEAPON_TIME,x
  jsl native_player_respawn_position
@restart:
  jmp .loword(native_player_restart)
@clock:
  ; The next step of the prompt.
  dec PLAYER+PL_PROMPT_DELAY,x
  bne @done
  lda PLAYER+PL_PROMPT,x
  cmp #PROMPT_COUNTDOWN
  beq @countdown
  cmp #PROMPT_OVER_ON
  beq @over_on
  cmp #PROMPT_OVER_OFF
  beq @over_off
  cmp #PROMPT_ON
  beq @prompt_off
  lda GAME_CREDITS              ; UI_INSERT_COIN, or UI_PUSH_BUTTON with a credit
  beq :+
  lda #1
:
  inc
  sta PLAYER_UI_MODE,y
  lda #PROMPT_ON
  bra @prompt_time
@prompt_off:
  lda #UI_BLANK
  sta PLAYER_UI_MODE,y
  lda #PROMPT_OFF
@prompt_time:
  sta PLAYER+PL_PROMPT,x
  lda #PROMPT_TIME
  sta PLAYER+PL_PROMPT_DELAY,x
@done:
  rtl
@countdown:
  dec PLAYER+PL_COUNTDOWN,x
  bmi @expired
  lda PLAYER+PL_COUNTDOWN,x
  sta PLAYER_UI_COUNT,y
  cmp #COUNTDOWN_SOUND
  bne :+
  lda #SND_COUNTDOWN
  jsl game_sound_request
:
  lda #UI_CONTINUE
  sta PLAYER_UI_MODE,y
  lda #PROMPT_TIME
  sta PLAYER+PL_PROMPT_DELAY,x
  rtl
@expired:
  lda #SND_STOP_EFFECTS
  jsl game_sound_request
  lda #SND_CONTINUE_MUSIC
  jsl game_sound_request
  lda #OVER_BLINKS_LATE
  sta PLAYER+PL_COUNTDOWN,x
  lda #PROMPT_OVER_ON
  sta PLAYER+PL_PROMPT,x
@over_on:
  dec PLAYER+PL_COUNTDOWN,x
  beq @finished
  lda #UI_GAME_OVER
  sta PLAYER_UI_MODE,y
  .assert UI_GAME_OVER = PROMPT_OVER_OFF, error
  sta PLAYER+PL_PROMPT,x
  lda #OVER_ON_TIME
  sta PLAYER+PL_PROMPT_DELAY,x
  rtl
@over_off:
  lda #UI_BLANK
  sta PLAYER_UI_MODE,y
  lda #PROMPT_OVER_ON
  sta PLAYER+PL_PROMPT,x
  lda #OVER_OFF_TIME
  sta PLAYER+PL_PROMPT_DELAY,x
  rtl
@finished:
  ; The player is out: the score back, the initials, then the join prompt.
  lda GAME_OUT
  cpy #0
  beq @out_one
  ora #OUT_P2
  bra @out_save
@out_one:
  ora #OUT_P1
@out_save:
  sta GAME_OUT
  jsr .loword(native_restore_score)
  jsl cabinet_live_begin        ; the other player plays on
  lda #UI_BLANK
  sta PLAYER_UI_MODE,y
  lda #PROMPT_ON
  sta PLAYER+PL_PROMPT,x
  lda #PROMPT_TIME
  sta PLAYER+PL_PROMPT_DELAY,x
  rtl

; native_player_respawn_position: the four pieces of the player X below
; the field at the player's side, until the entry (US arcade bank 1
; $8AAA-$8B2A, after the death clears the record). JSL.
native_player_respawn_position:
  lda #POSE_CODE+2*2            ; pose 2: level
  sta PLAYER,x
  inc
  sta PLAYER+PL_BODY2+SPR_CODE,x
  lda #WING_ARRIVE_CODE
  sta PLAYER+PL_LEFT_WING+SPR_CODE,x
  sta PLAYER+PL_RIGHT_WING+SPR_CODE,x
  lda PLAYER+SPR_ATTR,x
  ora #SPR_ALONG_HIGH
  sta PLAYER+SPR_ATTR,x
  sta PLAYER+PL_BODY2+SPR_ATTR,x
  sta PLAYER+PL_LEFT_WING+SPR_ATTR,x
  sta PLAYER+PL_RIGHT_WING+SPR_ATTR,x
  lda PLAYER+PL_NUMBER,x
  beq :+
  lda #RESPAWN_CROSS_P2
  bra :++
:
  lda #RESPAWN_CROSS_P1
:
  ; The wings are one piece to the left and to the right of the body.
  sta PLAYER+SPR_CROSS,x
  sec
  sbc #BODY2_CROSS
  sta PLAYER+PL_LEFT_WING+SPR_CROSS,x
  clc
  adc #2*BODY2_CROSS
  sta PLAYER+PL_BODY2+SPR_CROSS,x
  clc
  adc #BODY2_CROSS
  sta PLAYER+PL_RIGHT_WING+SPR_CROSS,x
  lda #RESPAWN_ALONG
  sta PLAYER+SPR_ALONG,x
  sta PLAYER+PL_BODY2+SPR_ALONG,x
  sta PLAYER+PL_LEFT_WING+SPR_ALONG,x
  sta PLAYER+PL_RIGHT_WING+SPR_ALONG,x
  rtl

; native_player_restart: a continue or a join: the player is in again, the
; score from 0, full energy, PS_RESPAWN, RESPAWN_IMMUNE; GAME_CONTINUE_LEVEL
; steps up. JMP from native_player_wait; JSL end.
native_player_restart:
  lda GAME_OUT
  cpy #0
  beq @one
  and #OUT_P1
  bra @save
@one:
  and #OUT_P2
@save:
  sta GAME_OUT
  lda #0
  sta PLAYER_UI_MODE,y
  sta PLAYER+PL_PROMPT,x
  sta PLAYER+PL_COUNTDOWN,x
  sta PLAYER+PL_HIT,x
  sta PLAYER+PL_WEAPON_GATE,x
  sta PLAYER+ANIM_WORK,x
  sta PLAYER+ANIM_WORK+1,x
  sta PLAYER+ANIM_WORK+2,x
  sta PLAYER+ANIM_WORK+3,x
  sta PLAYER+ANIM_WORK+4,x
  a16
  stz PLAYER+PL_SCORE,x
  stz PLAYER+PL_SCORE+2,x
  stz PLAYER+PL_SCORE+4,x
  stz PLAYER+PL_SCORE+6,x
  a8
  lda #2                        ; level
  sta PLAYER+PL_POSE,x
  lda #ENERGY_START
  sta PLAYER+PL_ENERGY,x
  lda #PS_RESPAWN
  sta PLAYER+PL_STATE,x
  lda #PLAYER_CROSS_RADIUS
  sta PLAYER+PL_CROSS_RADIUS,x
  lda #PLAYER_ALONG_RADIUS
  sta PLAYER+PL_ALONG_RADIUS,x
  lda #RESPAWN_IMMUNE
  sta PLAYER+PL_IMMUNE,x
  lda GAME_CONTINUE_LEVEL
  clc
  adc #CONTINUE_START
  cmp #CONTINUE_LEVEL_MAX+1
  bcc :+
  lda #CONTINUE_LEVEL_MAX
:
  sta GAME_CONTINUE_LEVEL
  jsl special_sync_shadow
  jsl player_energy_hud_far
  rtl

; native_retain_score: CAB_ENDING_SCORES of the player keeps the best score
; of the player's attempts until the ranking; the last game over shows it
; (cabinet_save_scores). X = the player record, Y = the player; both kept.
; JSR.
native_retain_score:
  phx
  phy
  tya
  a16
  and #$00ff
  asl
  asl
  asl                           ; times SCORE_DIGITS
  tay
  a8
  lda #SCORE_DIGITS
  sta SCORE_COUNT
@compare:
  lda PLAYER+PL_SCORE,x
  cmp CAB_ENDING_SCORES,y
  bcc @done
  bne @copy_reset
  inx
  iny
  dec SCORE_COUNT
  bne @compare
  bra @done
@copy_reset:
  ply
  plx
  phx
  phy
  tya
  a16
  and #$00ff
  asl
  asl
  asl
  tay
  a8
  lda #SCORE_DIGITS
  sta SCORE_COUNT
@copy:
  lda PLAYER+PL_SCORE,x
  sta CAB_ENDING_SCORES,y
  inx
  iny
  dec SCORE_COUNT
  bne @copy
@done:
  ply
  plx
  rts

; native_restore_score: PL_SCORE = the kept CAB_ENDING_SCORES, which is
; cleared. X = the player record, Y = the player; both kept. JSR.
native_restore_score:
  phx
  phy
  tya
  a16
  and #$00ff
  asl
  asl
  asl
  tay
  a8
  lda #SCORE_DIGITS
  sta SCORE_COUNT
@restore:
  lda CAB_ENDING_SCORES,y
  sta PLAYER+PL_SCORE,x
  lda #0
  sta CAB_ENDING_SCORES,y
  inx
  iny
  dec SCORE_COUNT
  bne @restore
  ply
  plx
  rts

; native_player_entry: one update of PS_RESPAWN (game_players_tick): the
; plane comes up ENTRY_STEP each update and blinks; on the field at
; ENTRY_ALONG it is live (SND_RESPAWN). JSL.
native_player_entry:
  ldx PLAYER_CURSOR
  stz PLAYER+PL_COLLIDE,x
  stz PLAYER+PL_WEAPON_GATE,x
  lda PLAYER+SPR_ALONG,x
  clc
  adc #ENTRY_STEP
  sta PLAYER+SPR_ALONG,x
  sta PLAYER+PL_BODY2+SPR_ALONG,x
  bcc :+
  lda PLAYER+SPR_ATTR,x
  and #<~SPR_ALONG_HIGH
  sta PLAYER+SPR_ATTR,x
  sta PLAYER+PL_BODY2+SPR_ATTR,x
:
  lda PLAYER,x                  ; the blink: code 0 and the level pose in turn
  beq @entry_show
  lda #0
  bra @entry_pose
@entry_show:
  lda #POSE_CODE+2*2
@entry_pose:
  sta PLAYER,x
  inc
  sta PLAYER+PL_BODY2+SPR_CODE,x
  lda PLAYER+SPR_ATTR,x
  and #SPR_ALONG_HIGH
  bne @entry_done
  lda PLAYER+SPR_ALONG,x
  cmp #ENTRY_ALONG
  bcc @entry_done
  lda #PS_LIVE
  sta PLAYER+PL_STATE,x
  lda #SND_RESPAWN
  jsl game_sound_request
@entry_done:
  rtl

; Four temporary dive pieces per player. The wing sprites of PLAYER stay the wing planes.
; A piece: SPR_CODE, SPR_ATTR, SPR_CROSS, SPR_ALONG.
DIVE_PIECE_SIZE = 4
DIVE_PIECES = 4
DIVE_EXTRA: .res 2*DIVE_PIECES*DIVE_PIECE_SIZE
; The dive (PS_DIVE) in ANIM_WORK of the body.
DIVE_TIME = ANIM_WORK        ; updates left of this dive pose
DIVE_STEP = ANIM_WORK+1      ; the next native_dive_first or native_dive_second entry
DIVE_ALONG = ANIM_WORK+2     ; the climb: the along move of this pose
; The dive clears the small objects and the enemy bullets from ENEMY_POOL on.
DIVE_CLEAR_SIZE = 64*OBJECT_SIZE
DIVE_END = $ff               ; native_dive_first, native_dive_second: the end
DIVE_SEA_MARK = $28          ; the native_dive_first entry with this time: the sea scene starts
DIVE_SEA_SCROLL = $1000      ; CAMERA_BG2_SCROLL of the ship scene sea
DIVE_BOTTOM = $d0            ; the dive goes down to this along
CLIMB_CROSS_P1 = $30         ; the climb starts at this cross,
CLIMB_CROSS_P2 = $a0
CLIMB_ALONG = $10            ; and this along,
CLIMB_CODE = $c0             ; with this sprite code
CLIMB_SHIFT_STEP = 4         ; at this climb step the plane moves 8 right and 8 up
CLIMB_SHIFT = 8
DIVE_CLIMB_ENTRY = 3         ; native_dive_second: time, code, along move

; native_dive_reset: no dive: the sea runs, no dive pieces. JSL.
native_dive_reset:
  stz GAME_BG2_DISABLED
  jsl special_sync_shadow
  stz GAME_DIVE_ACTIVE
  phx
  ldx #2*DIVE_PIECES*DIVE_PIECE_SIZE-DIVE_PIECE_SIZE
  lda #0
@clear:
  sta f:DIVE_EXTRA,x
  dex
  dex
  dex
  dex
  bpl @clear
  plx
  rtl

; native_dive_append: the dive pieces with a code as packet object records
; at X (state_packet), during a dive; the object count of the packet counts
; them. JSL; A16.
.a16
native_dive_append:
  lda GAME_BG2_DISABLED
  bit #$ff00                    ; the next byte: GAME_DIVE_ACTIVE
  bne :+
  rtl
:
  txy
  ldx #0
@entry:
  lda f:DIVE_EXTRA,x
  bit #$00ff
  beq @next
  xba                           ; high byte first
  sta a:PACKET_CODE,y
  lda f:DIVE_EXTRA+SPR_CROSS,x  ; with SPR_ALONG
  xba
  sta a:PACKET_POSITION,y
  iny
  iny
  iny
  iny
@next:
  inx
  inx
  inx
  inx
  cpx #2*DIVE_PIECES*DIVE_PIECE_SIZE
  bne @entry
  tyx
  rtl
.a8

; native_player_dive: one update of PS_DIVE (game_players_tick): the wing
; planes leave; the dive poses (native_dive_first) take the plane down; at
; DIVE_SEA_MARK the ship scene starts (the sea scroll, no small objects);
; then the climb (native_dive_second) with the dive pieces; then the plane
; is live in the ship scene. JSL.
native_player_dive:
  ldx PLAYER_CURSOR
  stz PLAYER+PL_COLLIDE,x
  stz PLAYER+PL_WEAPON_GATE,x
  ; The wing planes leave; their state goes to the high nibble for later.
  lda PLAYER+PL_WINGS,x
  and #WINGS_ON
  beq @wings_done
  lda PLAYER+PL_WINGS,x
  and #<~WINGS_STATE
  bne @wings_move
  lda PLAYER+PL_WINGS,x
  and #3
  asl
  asl
  asl
  asl
  ora #WINGS_ON
  sta PLAYER+PL_WINGS,x
@wings_move:
  phd
  a16
  txa
  clc
  adc #PLAYER
  tcd
  a8
  jsr .loword(player_wing_depart)
  pld
  ldx PLAYER_CURSOR
@wings_done:
  lda PLAYER+PL_DIVE_CLIMB,x
  beq :+
  jmp @climb
:
  lda PLAYER+DIVE_TIME,x
  bne @down
  phx
  lda PLAYER+DIVE_STEP,x
  a16
  and #$00ff
  asl
  tax
  a8
  lda f:native_dive_first,x
  sta DIVE_POSE_TIME
  lda f:native_dive_first+1,x
  sta DIVE_POSE_CODE
  plx
  lda DIVE_POSE_TIME
  cmp #DIVE_END
  beq @climb_init
  cmp #DIVE_SEA_MARK
  bne @down_pose
  ; The ship scene: the sea of the ship, no small objects or bullets (the
  ; clear takes the bullets, not their settings).
  lda #1
  sta GAME_BG2_DISABLED
  jsl special_sync_shadow
  a16
  lda #DIVE_SEA_SCROLL
  sta CAMERA_BG2_SCROLL
  phx
  .assert BULLETS = ENEMY_POOL+ENEMY_COUNT*OBJECT_SIZE, error, "dive bullet pool moved"
  .assert BULLETS+BULLET_COUNT*OBJECT_SIZE <= ENEMY_POOL+DIVE_CLEAR_SIZE, error, "dive bullet pool outside clear"
  ldx #DIVE_CLEAR_SIZE-2
@clear_ambient:
  stz ENEMY_POOL,x
  dex
  dex
  bpl @clear_ambient
  ldx #EXTENDED_COUNT*OBJECT_SIZE-2
@clear_extended:
  stz EXTENDED_POOL,x
  dex
  dex
  bpl @clear_extended
  plx
  a8
  stz CAMERA_BG2_DIVISOR
  stz DIVE_POSE_TIME
@down_pose:
  lda DIVE_POSE_TIME
  sta PLAYER+DIVE_TIME,x
  lda DIVE_POSE_CODE
  sta PLAYER+SPR_CODE,x
  inc
  sta PLAYER+PL_BODY2+SPR_CODE,x
  inc PLAYER+DIVE_STEP,x
@down:
  lda PLAYER+SPR_ALONG,x
  cmp #DIVE_BOTTOM
  bcs :+
  inc
:
  sta PLAYER+SPR_ALONG,x
  sta PLAYER+PL_BODY2+SPR_ALONG,x
  dec PLAYER+DIVE_TIME,x
  rtl
@climb_init:
  ; The climb starts from the top at the player's side.
  stz PLAYER+DIVE_TIME,x
  stz PLAYER+DIVE_STEP,x
  stz PLAYER+DIVE_ALONG,x
  stz PLAYER+ANIM_WORK+3,x
  stz PLAYER+ANIM_WORK+4,x
  lda #$ff
  sta PLAYER+PL_DIVE_CLIMB,x
  stz GAME_BG2_DISABLED
  jsl special_sync_shadow
  inc GAME_DIVE_ACTIVE
  lda PLAYER+PL_NUMBER,x
  beq :+
  lda #CLIMB_CROSS_P2
  bra :++
:
  lda #CLIMB_CROSS_P1
:
  sta PLAYER+SPR_CROSS,x
  clc
  adc #BODY2_CROSS
  sta PLAYER+PL_BODY2+SPR_CROSS,x
  lda #CLIMB_ALONG
  sta PLAYER+SPR_ALONG,x
  sta PLAYER+PL_BODY2+SPR_ALONG,x
  lda #CLIMB_CODE
  sta PLAYER+SPR_CODE,x
  inc
  sta PLAYER+PL_BODY2+SPR_CODE,x
  jsr native_dive_pieces
  lda #SND_DIVE
  jsl game_sound_request
  rtl
@climb:
  lda PLAYER+DIVE_TIME,x
  bne @climb_move
  phx
  lda PLAYER+DIVE_STEP,x
  a16
  and #$00ff
  sta DIVE_STEP_OFFSET
  asl
  clc
  adc DIVE_STEP_OFFSET          ; times DIVE_CLIMB_ENTRY
  tax
  a8
  lda f:native_dive_second,x
  sta DIVE_POSE_TIME
  lda f:native_dive_second+1,x
  sta DIVE_POSE_CODE
  lda f:native_dive_second+2,x
  sta DIVE_POSE_ALONG
  plx
  lda DIVE_POSE_TIME
  cmp #DIVE_END
  beq @finish
  sta PLAYER+DIVE_TIME,x
  lda DIVE_POSE_CODE
  sta PLAYER+SPR_CODE,x
  inc
  sta PLAYER+PL_BODY2+SPR_CODE,x
  lda PLAYER+DIVE_STEP,x
  cmp #CLIMB_SHIFT_STEP
  bne :+
  lda PLAYER+SPR_CROSS,x
  clc
  adc #CLIMB_SHIFT
  sta PLAYER+SPR_CROSS,x
  clc
  adc #BODY2_CROSS
  sta PLAYER+PL_BODY2+SPR_CROSS,x
  lda PLAYER+SPR_ALONG,x
  sec
  sbc #CLIMB_SHIFT
  sta PLAYER+SPR_ALONG,x
:
  lda DIVE_POSE_ALONG
  sta PLAYER+DIVE_ALONG,x
  inc PLAYER+DIVE_STEP,x
@climb_move:
  lda PLAYER+SPR_ALONG,x
  clc
  adc PLAYER+DIVE_ALONG,x
  sta PLAYER+SPR_ALONG,x
  sta PLAYER+PL_BODY2+SPR_ALONG,x
  jsr native_dive_pieces
  dec PLAYER+DIVE_TIME,x
  rtl
@finish:
  ; The climb ends: the player is live in the ship scene; wing planes that
  ; were with the player come again.
  stz PLAYER+PL_DIVE_CLIMB,x
  stz PLAYER+DIVE_TIME,x
  stz PLAYER+DIVE_STEP,x
  stz PLAYER+DIVE_ALONG,x
  stz PLAYER+ANIM_WORK+3,x
  stz PLAYER+ANIM_WORK+4,x
  stz CAMERA_BG1_GATE
  stz CAMERA_BG1_GATE+1
  lda #1
  sta CAMERA_BG1_DIVISOR
  sta STAGE_SHIP_SCENE
  lda #PS_LIVE
  sta PLAYER+PL_STATE,x
  stz STAGE_FINISH
  stz STAGE_PLAYER_REQUEST
  stz GAME_DEPART_MODE
  lda PLAYER+PL_WINGS,x
  and #WINGS_ON<<4              ; the state kept in the high nibble
  beq :+
  lda PLAYER+PL_WINGS,x
  ora #WINGS_COMING
  sta PLAYER+PL_WINGS,x
  lda #2                        ; level
  sta PLAYER+PL_POSE,x
:
  jsr native_dive_pieces        ; the level pose hides the dive pieces
  dec GAME_DIVE_ACTIVE
  rtl

; native_dive_pieces: the four dive pieces of the player X around the body
; (codes + 2, + 8, + 9, + 10), or none at the level pose or code 0; the wing
; planes do not change. JSR.
native_dive_pieces:
  lda PLAYER+SPR_CODE,x
  cmp #POSE_CODE+2*2            ; level
  bne :+
  jmp @hide
:
  cmp #0
  beq @hide
  sta PIECE_CODE
  lda PLAYER+SPR_ATTR,x
  sta PIECE_ATTR
  lda PLAYER+SPR_CROSS,x
  sta PIECE_CROSS
  lda PLAYER+SPR_ALONG,x
  sta PIECE_ALONG
  phx
  lda PLAYER+PL_NUMBER,x
  asl
  asl
  asl
  asl                           ; times DIVE_PIECES * DIVE_PIECE_SIZE
  a16
  and #$00ff
  tax
  a8
  lda PIECE_CODE
  clc
  adc #2
  sta f:DIVE_EXTRA+SPR_CODE,x
  clc
  adc #CODE_ROW-2
  sta f:DIVE_EXTRA+1*DIVE_PIECE_SIZE+SPR_CODE,x
  inc
  sta f:DIVE_EXTRA+2*DIVE_PIECE_SIZE+SPR_CODE,x
  inc
  sta f:DIVE_EXTRA+3*DIVE_PIECE_SIZE+SPR_CODE,x
  lda PIECE_ATTR
  sta f:DIVE_EXTRA+SPR_ATTR,x
  sta f:DIVE_EXTRA+1*DIVE_PIECE_SIZE+SPR_ATTR,x
  sta f:DIVE_EXTRA+2*DIVE_PIECE_SIZE+SPR_ATTR,x
  sta f:DIVE_EXTRA+3*DIVE_PIECE_SIZE+SPR_ATTR,x
  lda PIECE_CROSS
  clc
  adc #2*BODY2_CROSS
  sta f:DIVE_EXTRA+SPR_CROSS,x
  sta f:DIVE_EXTRA+3*DIVE_PIECE_SIZE+SPR_CROSS,x
  lda PIECE_CROSS
  sta f:DIVE_EXTRA+1*DIVE_PIECE_SIZE+SPR_CROSS,x
  clc
  adc #BODY2_CROSS
  sta f:DIVE_EXTRA+2*DIVE_PIECE_SIZE+SPR_CROSS,x
  lda PIECE_ALONG
  sta f:DIVE_EXTRA+SPR_ALONG,x
  sec
  sbc #PIECE_RISE
  sta f:DIVE_EXTRA+1*DIVE_PIECE_SIZE+SPR_ALONG,x
  sta f:DIVE_EXTRA+2*DIVE_PIECE_SIZE+SPR_ALONG,x
  sta f:DIVE_EXTRA+3*DIVE_PIECE_SIZE+SPR_ALONG,x
  plx
  rts
@hide:
  phx
  lda PLAYER+PL_NUMBER,x
  asl
  asl
  asl
  asl
  a16
  and #$00ff
  tax
  a8
  lda #0
  sta f:DIVE_EXTRA+SPR_CODE,x
  sta f:DIVE_EXTRA+1*DIVE_PIECE_SIZE+SPR_CODE,x
  sta f:DIVE_EXTRA+2*DIVE_PIECE_SIZE+SPR_CODE,x
  sta f:DIVE_EXTRA+3*DIVE_PIECE_SIZE+SPR_CODE,x
  plx
  rts

; native_dive_first: (updates, sprite code) of each dive pose; the time
; DIVE_SEA_MARK starts the ship scene; DIVE_END ends the list.
native_dive_first:
  .byte $20,$24,$10,$26,$10,$28,$0a,$e0,$0a,$e2,$08,$e4,$08,$e6,$28,0,$ff,0
; native_dive_second: (updates, sprite code, along move) of each climb pose;
; DIVE_END ends the list.
native_dive_second:
  .byte $10,$c0,3,$08,$c3,2,$08,$d0,2,$08,$d3,2,$10,$24,1,$ff,0,0
.assert DIVE_PIECES*DIVE_PIECE_SIZE = 16 .and DIVE_CLIMB_ENTRY = 3 .and WINGS_STATE = $0f, error
