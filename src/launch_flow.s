; The stage intro on the carrier deck (US arcade $46E9-$484A) and the
; landing and takeoff of the players (bank 1 $9262/$934D). The times are
; game updates; the tables and templates are arcade data.
.a8
.i16
DECK_PLANES = 5              ; the planes parked on the deck (large slots 0-4)
DECK_ENTRY_SIZE = 3          ; launch_deck_positions: cross, OBJ_DURATION, DECK_TIME
INTRO_WAIT = 120             ; updates before the launches
DECK_BLINK = $d100           ; CAMERA_BG1_SCROLL on odd updates: the deck blinks
LAUNCH_SMALL_MAX = 5         ; small planes that take off
LAUNCH_LARGE_MAX = 9         ; large planes that take off; then the intro ends
LAUNCH_ENTRY_SIZE = 4        ; launch_small/large_positions: cross, along, -, OBJ_DURATION
DOCKED_CODE = $4a            ; the sprite code of a plane docked on the deck
DOCK_CROSS = $68             ; the landing goes to this place
DOCK_ALONG = $50
DOCKED = %11                 ; LANDING_DOCKED: both places reached
TAKEOFF_END = 255            ; launch_takeoff: the end
TAKEOFF_ENTRY_SIZE = 4       ; launch_takeoff: code, cross move, along move, moves
TAKEOFF_WINGS_STEP = $37     ; the wing planes show from this takeoff step
; Landing (PS_LANDING) and takeoff (PS_TAKEOFF) in ANIM_WORK of the body.
LANDING_DOCKED = ANIM_WORK   ; bit 0 at the deck cross, bit 1 at the deck along
LANDING_TIME = ANIM_WORK+1   ; updates left of this dock pose
LANDING_STEP = ANIM_WORK+2   ; the next dock pose
TAKEOFF_MOVES = ANIM_WORK    ; moves left of this takeoff step
TAKEOFF_STEP = ANIM_WORK+1   ; the next takeoff step
TAKEOFF_CROSS = ANIM_WORK+3  ; the cross move of this step, subtracted
TAKEOFF_ALONG = ANIM_WORK+4  ; the along move of this step

; native_intro_tick: one update of the intro (SEQ_INTRO). The first update
; parks DECK_PLANES planes; after INTRO_WAIT the deck blinks and a small and
; a large plane take off each update; after LAUNCH_LARGE_MAX the scroll runs
; and the players show. JML from game_scene_tick; JSL end.
native_intro_tick:
  a16
  lda GAME_SEQUENCE_TICKS
  bne @clock
  stz LAUNCH_SMALL
  stz LAUNCH_INDEX
  ldx #0
@deck:
  stx LAUNCH_SLOT
  jsr .loword(launch_large_clear)
  lda #.loword(launch_deck_template)
  sta LAUNCH_TEMPLATE
  lda #.bankbyte(launch_deck_template)
  sta LAUNCH_TEMPLATE+2
  ldy #0
@template:
  lda [LAUNCH_TEMPLATE],y
  sta LARGE_POOL,x
  inx
  inx
  iny
  iny
  cpy #OBJECT_SIZE
  bcc @template
  ldx LAUNCH_INDEX
  lda f:launch_deck_positions,x
  ldx LAUNCH_SLOT
  a8
  sta LARGE_POOL+SPR_CROSS,x
  a16
  ldx LAUNCH_INDEX
  lda f:launch_deck_positions+1,x
  ldx LAUNCH_SLOT
  a8
  sta LARGE_POOL+OBJ_DURATION,x
  xba
  sta LARGE_POOL+DECK_TIME,x
  lda LARGE_POOL+SPR_ATTR,x
  sta LARGE_POOL+2*SPRITE_SIZE+SPR_ATTR,x
  lda LARGE_POOL+SPR_ALONG,x
  sec
  sbc #PIECE_RISE
  sta LARGE_POOL+2*SPRITE_SIZE+SPR_ALONG,x
  a16
  lda LAUNCH_INDEX
  clc
  adc #DECK_ENTRY_SIZE
  sta LAUNCH_INDEX
  txa
  clc
  adc #LARGE_SIZE
  tax
  cpx #DECK_PLANES*LARGE_SIZE
  bcc @deck
@clock:
.a16
  inc GAME_SEQUENCE_TICKS
  lda GAME_SEQUENCE_TICKS
  cmp #INTRO_WAIT
  bcs :+
  a8
  rtl
:
.a16
  and #1
  beq :+
  lda #DECK_BLINK
  bra @blink
:
  lda #DECK_SCROLL
@blink:
  sta CAMERA_BG1_SCROLL
  a8
  lda LAUNCH_SMALL
  cmp #LAUNCH_SMALL_MAX
  bcs @large
  ldx #0
@small_free:
  lda EXTENDED_POOL+OBJ_TYPE,x
  beq @small_found
  a16
  txa
  clc
  adc #OBJECT_SIZE
  tax
  a8
  cpx #EXTENDED_COUNT*OBJECT_SIZE
  bcc @small_free
  bra @large
@small_found:
  stx LAUNCH_SLOT
  a16
  lda #.loword(launch_small_template)
  sta LAUNCH_TEMPLATE
  lda #.bankbyte(launch_small_template)
  sta LAUNCH_TEMPLATE+2
  ldy #0
@small_copy:
  lda [LAUNCH_TEMPLATE],y
  sta EXTENDED_POOL,x
  inx
  inx
  iny
  iny
  cpy #OBJECT_SIZE
  bcc @small_copy
  lda LAUNCH_SMALL
  and #255
  asl
  asl                           ; times LAUNCH_ENTRY_SIZE
  tax
  lda f:launch_small_positions,x
  sta LAUNCH_POSITION
  a8
  lda f:launch_small_positions+3,x
  ldx LAUNCH_SLOT
  sta EXTENDED_POOL+OBJ_DURATION,x
  a16
  lda LAUNCH_POSITION
  sta EXTENDED_POOL+SPR_CROSS,x
  a8
  inc LAUNCH_SMALL
@large:
  ldx #0
@large_free:
  lda LARGE_POOL+OBJ_TYPE,x
  beq @large_found
  a16
  txa
  clc
  adc #LARGE_SIZE
  tax
  a8
  cpx #LARGE_COUNT*LARGE_SIZE
  bcc @large_free
  rtl
@large_found:
  stx LAUNCH_SLOT
  a16
  jsr .loword(launch_large_clear)
  lda #.loword(launch_large_template)
  sta LAUNCH_TEMPLATE
  lda #.bankbyte(launch_large_template)
  sta LAUNCH_TEMPLATE+2
  ldy #0
@large_copy:
  lda [LAUNCH_TEMPLATE],y
  sta LARGE_POOL,x
  inx
  inx
  iny
  iny
  cpy #OBJECT_SIZE
  bcc @large_copy
  lda LAUNCH_LARGE
  and #255
  asl
  asl                           ; times LAUNCH_ENTRY_SIZE
  tax
  lda f:launch_large_positions,x
  sta LAUNCH_POSITION
  a8
  lda f:launch_large_positions+3,x
  ldx LAUNCH_SLOT
  sta LARGE_POOL+OBJ_DURATION,x
  a16
  lda LAUNCH_POSITION
  sta LARGE_POOL+SPR_CROSS,x
  a8
  lda LARGE_POOL+SPR_ALONG,x
  sec
  sbc #PIECE_RISE
  sta LARGE_POOL+2*SPRITE_SIZE+SPR_ALONG,x
  lda LARGE_POOL+SPR_ATTR,x
  sta LARGE_POOL+2*SPRITE_SIZE+SPR_ATTR,x
  inc LAUNCH_LARGE
  lda LAUNCH_LARGE
  cmp #LAUNCH_LARGE_MAX
  bcc @done
  ; The intro ends: the deck scroll runs and the players show.
  a16
  lda #DECK_SCROLL
  sta CAMERA_BG1_SCROLL
  stz CAMERA_BG1_GATE
  a8
  lda PLAYER+SPR_ATTR
  and #<~SPR_ALONG_HIGH
  sta PLAYER+SPR_ATTR
  sta PLAYER+PL_BODY2+SPR_ATTR
  lda PLAYER2+SPR_ATTR
  and #<~SPR_ALONG_HIGH
  sta PLAYER2+SPR_ATTR
  sta PLAYER2+PL_BODY2+SPR_ATTR
  stz STAGE_BANNER_TASK
@done:
  rtl

; launch_large_clear: clear the large slot X. JSR; X = LAUNCH_SLOT after it.
launch_large_clear:
.a16
  ldy #LARGE_SIZE/2
@clear:
  stz LARGE_POOL,x
  inx
  inx
  dey
  bne @clear
  ldx LAUNCH_SLOT
  rts

; native_player_presentation: one update of a player in PS_LANDING or
; PS_TAKEOFF (game_players_tick); D = the player record during it. JSL.
native_player_presentation:
  phd
  a16
  lda PLAYER_CURSOR
  clc
  adc #PLAYER
  tcd
  a8
  jsr .loword(live_native_player_presentation)
  pld
  rtl
; live_native_player_presentation: the landing goes to the dock place one
; step each axis (banking to the side), then plays launch_dock_poses; the
; takeoff plays launch_takeoff (code and moves); then the player is live.
live_native_player_presentation:
.a8
  stz z:PL_COLLIDE
  stz z:PL_WEAPON_GATE
  lda z:PL_STATE
  cmp #PS_TAKEOFF
  bne :+
  jmp .loword(@takeoff)
:
  cmp #PS_LANDING
  beq @on_deck
  rts
@on_deck:
  lda z:SPR_CODE
  cmp #DOCKED_CODE
  bne @return_to_deck
  a16
  stz z:ANIM_WORK
  stz z:ANIM_WORK+2
  a8
  stz z:ANIM_WORK+4             ; the last ANIM_WORK byte
  rts
@return_to_deck:
  ; The landing ($9281-$9316) starts from the place of the player.
  lda z:LANDING_DOCKED
  cmp #DOCKED
  beq @dock_animation
  lda z:SPR_CROSS
  cmp #DOCK_CROSS
  beq @dock_x
  bcs @left
  inc z:SPR_CROSS
  lda #POSE_CODE+3*2            ; pose 3: bank right
  bra @pose
@left:
  dec z:SPR_CROSS
  lda #POSE_CODE+1*2            ; pose 1: bank left
  bra @pose
@dock_x:
  lda z:LANDING_DOCKED
  ora #1
  sta z:LANDING_DOCKED
  lda #POSE_CODE+2*2            ; pose 2: level
@pose:
  sta z:SPR_CODE
  inc
  sta z:PL_BODY2+SPR_CODE
  lda z:SPR_CROSS
  clc
  adc #BODY2_CROSS
  sta z:PL_BODY2+SPR_CROSS
  lda z:SPR_ALONG
  cmp #DOCK_ALONG
  beq @dock_y
  bcs @up
  inc
  bra @y
@up:
  dec
  bra @y
@dock_y:
  lda z:LANDING_DOCKED
  ora #2
  sta z:LANDING_DOCKED
  lda z:SPR_ALONG
@y:
  sta z:SPR_ALONG
  sta z:PL_BODY2+SPR_ALONG
  rts
@dock_animation:
  lda z:LANDING_TIME
  bne @dock_wait
  a16
  lda z:LANDING_STEP
  and #255
  asl
  tax
  a8
  lda f:launch_dock_poses,x
  sta z:LANDING_TIME
  lda f:launch_dock_poses+1,x
  sta z:SPR_CODE
  inc
  sta z:PL_BODY2+SPR_CODE
  inc z:LANDING_STEP
@dock_wait:
  dec z:LANDING_TIME
  rts
@takeoff:
  lda z:TAKEOFF_MOVES
  bne @move
  a16
  lda z:TAKEOFF_STEP
  and #255
  asl
  asl                           ; times TAKEOFF_ENTRY_SIZE
  tax
  a8
  lda f:launch_takeoff,x
  cmp #TAKEOFF_END
  beq @finished
  sta z:SPR_CODE
  lda f:launch_takeoff+1,x
  sta z:TAKEOFF_CROSS
  lda f:launch_takeoff+2,x
  sta z:TAKEOFF_ALONG
  lda f:launch_takeoff+3,x
  sta z:TAKEOFF_MOVES
  inc z:TAKEOFF_STEP
@move:
  ; The wing planes stay hidden until TAKEOFF_WINGS_STEP (X also holds the
  ; byte after TAKEOFF_STEP, which is 0).
  lda z:PL_LEFT_WING+SPR_ATTR
  ora #SPR_ALONG_HIGH
  ldx z:TAKEOFF_STEP
  cpx #TAKEOFF_WINGS_STEP
  bne :+
  and #<~SPR_ALONG_HIGH
:
  sta z:PL_LEFT_WING+SPR_ATTR
  sta z:PL_RIGHT_WING+SPR_ATTR
  lda z:SPR_CODE
  inc
  sta z:PL_BODY2+SPR_CODE
  clc
  adc #CODE_ROW-1
  sta z:PL_LEFT_WING+SPR_CODE
  inc
  sta z:PL_RIGHT_WING+SPR_CODE
  lda z:SPR_CROSS
  sec
  sbc z:TAKEOFF_CROSS
  sta z:SPR_CROSS
  sta z:PL_LEFT_WING+SPR_CROSS
  clc
  adc #BODY2_CROSS
  sta z:PL_BODY2+SPR_CROSS
  sta z:PL_RIGHT_WING+SPR_CROSS
  lda z:SPR_ALONG
  clc
  adc z:TAKEOFF_ALONG
  sta z:SPR_ALONG
  sta z:PL_BODY2+SPR_ALONG
  sec
  sbc #PIECE_RISE
  sta z:PL_LEFT_WING+SPR_ALONG
  sta z:PL_RIGHT_WING+SPR_ALONG
  dec z:TAKEOFF_MOVES
  rts
@finished:
  a16
  stz z:ANIM_WORK
  stz z:ANIM_WORK+2
  a8
  stz z:ANIM_WORK+4             ; the last ANIM_WORK byte
  lda #1
  sta z:PL_COLLIDE
  lda #PS_LIVE
  sta z:PL_STATE
  stz STAGE_FINISH
  stz STAGE_SHIP_SCENE
  lda z:PL_LEFT_WING+SPR_ATTR
  and #<~SPR_ALONG_HIGH
  sta z:PL_LEFT_WING+SPR_ATTR
  sta z:PL_RIGHT_WING+SPR_ATTR
  lda #SPR_HIDDEN
  sta z:PL_LEFT_WING+SPR_ALONG
  sta z:PL_RIGHT_WING+SPR_ALONG
  rts
