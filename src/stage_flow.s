.ifdef NATIVE_STAGE_FLOW
; Original-US stage transitions ($690A-$6EC4). The game owns these states;
; no arcade scheduler stack or program instruction is executed at runtime.
.a8
.i16
.ifndef STAGE_GROUP_INDEX
STAGE_GROUP_INDEX = $1b50
STAGE_GROUP_REPLAY = $1b51
.endif
STAGE_DAMAGE_GROUPS = $1c00
STAGE_DAMAGE_TOTAL = $1c30
STAGE_DAMAGE_THRESHOLD = $1c42
STAGE_SAVED_CAMERA = $1b52
STAGE_SCROLL_TASK = $1b54
STAGE_SCROLL_WAIT = $1b56
STAGE_SCROLL_STEP = $1b58
STAGE_BOSS_PHASE = $1b59        ; E551
STAGE_SOUND_WRITE = $1b5a
STAGE_SOUND_READ = $1b5b
STAGE_BANNER_TASK = $1b5c
STAGE_DEPARTURE = $1b5d         ; E458
STAGE_INPUT_P2 = $1b5e
STAGE_MUSIC = $1b5f
STAGE_SOUND_QUEUE = $1b60

stage_flow_init:
  rep #$20
  ldx #6
@clear:
  stz STAGE_SAVED_CAMERA,x
  dex
  dex
  bpl @clear
  stz STAGE_BANNER_TASK
  stz STAGE_INPUT_P2
  sep #$20
  lda #255
  sta STAGE_INPUT_P2
  rtl

stage_sound_put:
.ifdef CONTINUOUS_GAME
  jsl game_sound_request
  rts
.else
  pha
  rep #$20
  lda STAGE_SOUND_WRITE
  and #15
  tax
  sep #$20
  pla
  sta STAGE_SOUND_QUEUE,x
  txa
  inc
  and #15
  cmp STAGE_SOUND_READ
  bne :+
  lda #$d8                    ; queue overflow is a failure, never a lost cue
  sta f:$050301
  rts
:
  sta STAGE_SOUND_WRITE
  rts
.endif

stage_control_boss_camera:
  rep #$20
  and #255
  asl
  tax
  lda CAMERA+$0f
  clc
  adc #32
  sta STAGE_SAVED_CAMERA
  lda f:stage_boss_cameras,x
  sta CAMERA+$0f
  sep #$20
  stz CAMERA+$0e
  lda #$2a
  cpx #4
  bne :+
  lda #$31
:
  jsr .loword(stage_sound_put)
  jmp .loword(stage_control_done)
stage_boss_cameras:
  .word $f100,$e100,$f900

stage_control_boss_reset:
  stz STAGE_GROUP_INDEX
  stz STAGE_GROUP_REPLAY
  stz STAGE_DAMAGE_TOTAL
  stz STAGE_DAMAGE_THRESHOLD
  stz STAGE_BOSS_PHASE
  stz CAMERA_PAN_ON
  stz CAMERA+$21
  stz STAGE_FLAGS+17
  stz STAGE_FLAGS+18
  stz STAGE_FLAGS+19
  stz STAGE_FLAGS+11
  rep #$20
  ldx #46
@clear:
  stz STAGE_DAMAGE_GROUPS,x
  dex
  dex
  bpl @clear
  sep #$20
  jmp .loword(stage_control_done)

stage_control_boss_replay:
  ; $6987-$69C4 preserves the damaged targets and removes half the empty
  ; slots from alternating ends. This changes the next pass, not live art.
  lda STAGE_GROUP_INDEX
  beq @reset
  rep #$20
  and #255
  tax
  ldy #0
  sep #$20
@count:
  lda STAGE_DAMAGE_GROUPS,x
  bne :+
  iny
:
  dex
  bne @count
  tya
  lsr
  adc #0
  beq @reset
  sta $d0
  ldx #1
  rep #$20
  lda STAGE_GROUP_INDEX
  and #255
  tay
  sep #$20
@front:
  lda STAGE_DAMAGE_GROUPS,x
  beq @front_empty
  inx
  bra @front
@front_empty:
  lda #255
  sta STAGE_DAMAGE_GROUPS,x
  inx
  dec $d0
  beq @reset
@back:
  lda STAGE_DAMAGE_GROUPS,y
  beq @back_empty
  dey
  bra @back
@back_empty:
  lda #255
  sta STAGE_DAMAGE_GROUPS,y
  dey
  dec $d0
  bne @front
@reset:
  stz STAGE_GROUP_REPLAY
  stz STAGE_DAMAGE_TOTAL
  stz STAGE_GROUP_INDEX
  stz STAGE_DAMAGE_THRESHOLD
  stz CAMERA_PAN_ON
  stz STAGE_FLAGS+17
  stz STAGE_FLAGS+18
  stz STAGE_FLAGS+19
  stz CAMERA+$21
  stz STAGE_FLAGS+11
  stz CAMERA+$1c
  stz CAMERA+$1f
  stz CAMERA+$0e
  stz CAMERA+$20
  rep #$20
  stz CAMERA+$1d
  sep #$20
  lda #1
  sta STAGE_BOSS_PHASE
  sta STAGE_BANNER_TASK        ; native $2E3F continuation
  jmp .loword(stage_control_done)

stage_control_boss_result:
  lda #255
  sta CAMERA+$15
  sta CAMERA+$16
  lda #$29
  jsr .loword(stage_sound_put)
  lda #1
  sta STAGE_FLAGS+$24
  sta STAGE_FLAGS+$25
  stz STAGE_DAMAGE_TOTAL
  stz STAGE_DAMAGE_THRESHOLD
  lda #2
  sta STAGE_BANNER_TASK        ; native $324D continuation
  jmp .loword(stage_control_done)

stage_control_music:
  sta STAGE_MUSIC
  stz STAGE_FLAGS+$1a
.ifdef CONTINUOUS_GAME
  jsl audio_start_music_stage
  bcs @music_scheduled
.endif
  lda #0
  jsr .loword(stage_sound_put)
  lda STAGE_MUSIC
  and #1
  bne :+
  lda #$19
  jsr .loword(stage_sound_put)
:
  lda STAGE_MUSIC
  jsr .loword(stage_sound_put)
@music_scheduled:
  ldx #0
@player:
  lda PLAYER+8,x
  beq @next
  jsl player_energy_hud_far
@next:
  cpx #128
  beq @done
  ldx #128
  bra @player
@done:
  jmp .loword(stage_control_done)

stage_control_banner:
  lda #3
  sta STAGE_BANNER_TASK        ; native $2778 continuation
  jmp .loword(stage_control_done)

stage_control_accelerate:
  lda #1
  sta STAGE_SCROLL_TASK
  lda #14
  sta $d0
  lda #16
  bra stage_speed_players
stage_control_decelerate:
  lda #2
  sta STAGE_SCROLL_TASK
  lda #2
  sta $d0
  lda #14
stage_speed_players:
  sta $d1
  ldx #0
@player:
  lda PLAYER+8,x
  cmp $d0
  bne @next
  lda $d1
  sta PLAYER+8,x
@next:
  cpx #128
  beq @timer
  ldx #128
  bra @player
@timer:
  stz STAGE_SCROLL_STEP
  rep #$20
  stz STAGE_SCROLL_WAIT
  sep #$20
  jmp .loword(stage_control_done)

stage_scroll_tick:
  lda STAGE_SCROLL_TASK
  bne :+
  rtl
:
  rep #$20
  lda STAGE_SCROLL_WAIT
  beq @next
  dec STAGE_SCROLL_WAIT
  bne @done
@next:
  lda STAGE_SCROLL_STEP
  and #255
  asl
  tax
  sep #$20
  lda STAGE_SCROLL_TASK
  cmp #1
  beq @accelerate
  cpx #8
  bcc :+
  lda #255
  sta CAMERA+$15
  sta CAMERA+$16
  bra @finished
:
  lda f:stage_decelerate_speed,x
  sta CAMERA+$13
  rep #$20
  lda f:stage_decelerate_wait,x
  bra @wait
@accelerate:
.a8
  cpx #8
  bcc :+
  lda #1
  sta CAMERA+$13
@finished:
  stz STAGE_SCROLL_TASK
  rtl
:
  lda f:stage_accelerate_speed,x
  sta CAMERA+$13
  rep #$20
  lda f:stage_accelerate_wait,x
@wait:
  sta STAGE_SCROLL_WAIT
  sep #$20
  inc STAGE_SCROLL_STEP
  rtl
@done:
  sep #$20
  rtl
stage_accelerate_speed: .word 5,4,3,2
stage_accelerate_wait: .word $c0,$5a,$20,$18
stage_decelerate_speed: .word 2,3,4,5
stage_decelerate_wait: .word $0e,$20,$5a,$c0

stage_control_boss_departure:
  lda #255
  sta CAMERA+$15
  sta CAMERA+$16
  ldx #0
@player:
  lda PLAYER+8,x
  beq @next
  stz PLAYER+$55,x
@next:
  cpx #128
  beq @ready
  ldx #128
  bra @player
@ready:
  lda #1
  sta STAGE_DEPARTURE
  lda #3
  sta STAGE_BANNER_TASK
  lda #$10
  jsr .loword(stage_sound_put)
  lda #8
  sta STAGE_FLAGS+9
  jmp .loword(stage_control_done)

stage_control_stage_difficulty:
  lda STAGE_DIFFICULTY+1
  clc
  adc CAMERA_STAGE
  rep #$20
  and #255
  tax
  sep #$20
  lda f:stage_difficulty_values,x
  sta STAGE_DIFFICULTY+5
  sta STAGE_FLAGS+10
  jmp .loword(stage_control_done)

stage_control_secret_weapon:
  rep #$20
  lda CAMERA_STAGE
  and #15
  asl
  tay
  sep #$20
  lda INPUT_P1
  ldx #0
  jsr .loword(stage_secret_player)
  rep #$20
  tya
  clc
  adc #32
  tay
  sep #$20
  lda STAGE_INPUT_P2
  ldx #128
  jsr .loword(stage_secret_player)
  jmp .loword(stage_control_done)
stage_secret_player:
  eor #255
  sta $d0
  lda PLAYER+8,x
  beq @done
  phx
  tyx
  lda f:stage_weapon_secrets,x
  cmp $d0
  beq @grant
  plx
  lda PLAYER+$51,x
  cmp #16
  bne @done
  stz PLAYER+$51,x
  stz PLAYER+$57,x
  rts
@grant:
  lda f:stage_weapon_secrets+1,x
  plx
  sta PLAYER+$51,x
  cmp #16
  beq @laser
  lda #64
  bra @timer
@laser:
  lda #255
@timer:
  sta PLAYER+$57,x
@done:
  rts


stage_control_intro:
  lda #4
  sta STAGE_BANNER_TASK
  lda #255
  sta CAMERA+$15
  sta CAMERA+$16
  jmp .loword(stage_control_done)
stage_control_bonus:
  jsl game_bonus_spawn
  jmp .loword(stage_control_done)
.endif
