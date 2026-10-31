; Native per-player cabinet continuation. Times are 59.637 Hz game ticks.
; States describe the visible prompts, independently of the other aircraft.
.a8
.i16
GAME_OUT = $14e7
GAME_CONTINUE_LEVEL = $14e8
PLAYER_UI_MODE = $14f0
PLAYER_UI_COUNT = $14f2

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
  and #2
  bra :++
:
  and #1
:
  beq :+
  lda CAB_LIVE_STATE,y
  beq :+                      ; inactive players can join after name entry
  rtl
:
  lda PLAYER+$28,x
  bne @start_button
  jsr .loword(native_retain_score)
  lda #1
  sta PLAYER+$29,x
  lda #16
  sta PLAYER+$28,x
  lda PLAYER+$2a,x
  beq @start_button
  lda #1
  sta PLAYER+$28,x
  lda CAMERA_STAGE
  cmp #16
  beq @no_continue
  lda GAME_DIP_B
  and #64
  bne @start_button
@no_continue:
  lda #2
  sta PLAYER+$28,x
  lda #8
  sta PLAYER+$2a,x
  lda #$2e
  jsl game_sound_request
@start_button:
  lda CAMERA_STAGE
  cmp #16
  beq @clock
  lda PLAYER+$28,x
  and #14
  bne @clock
  lda GAME_CREDITS
  beq @clock
  lda INPUT_SYSTEM
  cpy #0
  beq :+
  lsr
:
  and #1
  bne @clock
  dec GAME_CREDITS
  lda PLAYER+$28,x
  cmp #1
  bne @join
  lda #$1f
  jsl game_sound_request
  bra @restart
@join:
  ; A new join is a fresh aircraft, unlike an ordinary continue.
  stz PLAYER+4,x
  stz PLAYER+9,x
  stz PLAYER+$51,x
  stz PLAYER+$57,x
  jsl native_player_respawn_position
@restart:
  jmp .loword(native_player_restart)
@clock:
  dec PLAYER+$29,x
  bne @done
  lda PLAYER+$28,x
  cmp #1
  beq @countdown
  cmp #2
  beq @over_on
  cmp #4
  beq @over_off
  cmp #16
  beq @prompt_off
  lda GAME_CREDITS
  beq :+
  lda #1
:
  inc
  sta PLAYER_UI_MODE,y
  lda #16
  bra @prompt_time
@prompt_off:
  lda #5
  sta PLAYER_UI_MODE,y
  lda #32
@prompt_time:
  sta PLAYER+$28,x
  lda #60
  sta PLAYER+$29,x
@done:
  rtl
@countdown:
  dec PLAYER+$2a,x
  bmi @expired
  lda PLAYER+$2a,x
  sta PLAYER_UI_COUNT,y
  cmp #10
  bne :+
  lda #$14
  jsl game_sound_request
:
  lda #3
  sta PLAYER_UI_MODE,y
  lda #60
  sta PLAYER+$29,x
  rtl
@expired:
  lda #$1f
  jsl game_sound_request
  lda #$2e
  jsl game_sound_request
  lda #6
  sta PLAYER+$2a,x
  lda #2
  sta PLAYER+$28,x
@over_on:
  dec PLAYER+$2a,x
  beq @finished
  lda #4
  sta PLAYER_UI_MODE,y
  sta PLAYER+$28,x
  lda #45
  sta PLAYER+$29,x
  rtl
@over_off:
  lda #5
  sta PLAYER_UI_MODE,y
  lda #2
  sta PLAYER+$28,x
  lda #30
  sta PLAYER+$29,x
  rtl
@finished:
  lda GAME_OUT
  cpy #0
  beq @out_one
  ora #2
  bra @out_save
@out_one:
  ora #1
@out_save:
  sta GAME_OUT
  jsr .loword(native_restore_score)
  jsl cabinet_live_begin       ; qualification does not stop the other player
  lda #5
  sta PLAYER_UI_MODE,y
  lda #16
  sta PLAYER+$28,x
  lda #60
  sta PLAYER+$29,x
  rtl

; Original bank 1 $8AAA-$8B2A, called after the death record is cleared.
; X is the player offset. Keep all four pieces below the screen until entry.
native_player_respawn_position:
  lda #$24
  sta PLAYER,x
  inc
  sta PLAYER+$20,x
  lda #$2c
  sta PLAYER+$40,x
  sta PLAYER+$60,x
  lda PLAYER+1,x
  ora #$10
  sta PLAYER+1,x
  sta PLAYER+$21,x
  sta PLAYER+$41,x
  sta PLAYER+$61,x
  lda PLAYER+5,x
  beq :+
  lda #$b0
  bra :++
:
  lda #$30
:
  sta PLAYER+2,x
  sec
  sbc #$10
  sta PLAYER+$42,x
  clc
  adc #$20
  sta PLAYER+$22,x
  clc
  adc #$10
  sta PLAYER+$62,x
  lda #$f0
  sta PLAYER+3,x
  sta PLAYER+$23,x
  sta PLAYER+$43,x
  sta PLAYER+$63,x
  rtl

native_player_restart:
  lda GAME_OUT
  cpy #0
  beq @one
  and #1
  bra @save
@one:
  and #2
@save:
  sta GAME_OUT
  lda #0
  sta PLAYER_UI_MODE,y
  sta PLAYER+$28,x
  sta PLAYER+$2a,x
  sta PLAYER+$0e,x
  sta PLAYER+$55,x
  sta PLAYER+$1b,x
  sta PLAYER+$1c,x
  sta PLAYER+$1d,x
  sta PLAYER+$1e,x
  sta PLAYER+$1f,x
  rep #$20
  stz PLAYER+$38,x
  stz PLAYER+$3a,x
  stz PLAYER+$3c,x
  stz PLAYER+$3e,x
  sep #$20
  lda #2
  sta PLAYER+$0a,x
  lda #64
  sta PLAYER+6,x
  lda #6
  sta PLAYER+8,x
  lda #7
  sta PLAYER+$10,x
  lda #5
  sta PLAYER+$11,x
  lda #32
  sta PLAYER+$14,x
  lda GAME_CONTINUE_LEVEL
  clc
  adc #2
  cmp #5
  bcc :+
  lda #4
:
  sta GAME_CONTINUE_LEVEL
  jsl special_sync_shadow
  jsl player_energy_hud_far
  rtl

; CAB_ENDING_SCORES holds the best completed attempt until ranking insertion.
; On the final game-over path cabinet_save_scores reuses it for presentation.
; X is the player offset and Y is the player number; preserve both.
native_retain_score:
  phx
  phy
  tya
  rep #$20
  and #$00ff
  asl
  asl
  asl
  tay
  sep #$20
  lda #8
  sta $d3
@compare:
  lda PLAYER+$38,x
  cmp CAB_ENDING_SCORES,y
  bcc @done
  bne @copy_reset
  inx
  iny
  dec $d3
  bne @compare
  bra @done
@copy_reset:
  ply
  plx
  phx
  phy
  tya
  rep #$20
  and #$00ff
  asl
  asl
  asl
  tay
  sep #$20
  lda #8
  sta $d3
@copy:
  lda PLAYER+$38,x
  sta CAB_ENDING_SCORES,y
  inx
  iny
  dec $d3
  bne @copy
@done:
  ply
  plx
  rts

native_restore_score:
  phx
  phy
  tya
  rep #$20
  and #$00ff
  asl
  asl
  asl
  tay
  sep #$20
  lda #8
  sta $d3
@restore:
  lda CAB_ENDING_SCORES,y
  sta PLAYER+$38,x
  lda #0
  sta CAB_ENDING_SCORES,y
  inx
  iny
  dec $d3
  bne @restore
  ply
  plx
  rts

native_player_entry:
  ldx PLAYER_CURSOR
  stz PLAYER+7,x
  stz PLAYER+$55,x
  lda PLAYER+3,x
  clc
  adc #2
  sta PLAYER+3,x
  sta PLAYER+$23,x
  bcc :+
  lda PLAYER+1,x
  and #$ef
  sta PLAYER+1,x
  sta PLAYER+$21,x
:
  lda PLAYER,x
  beq @entry_show
  lda #0
  bra @entry_pose
@entry_show:
  lda #$24
@entry_pose:
  sta PLAYER,x
  inc
  sta PLAYER+$20,x
  lda PLAYER+1,x
  and #16
  bne @entry_done
  lda PLAYER+3,x
  cmp #$30
  bcc @entry_done
  lda #2
  sta PLAYER+8,x
  lda #$15
  jsl game_sound_request
@entry_done:
  rtl

; Four temporary dive pieces per player. PLAYER+$40/$60 remain wingmen.
DIVE_EXTRA: .res 32
native_dive_reset:
  stz GAME_BG2_DISABLED
  jsl special_sync_shadow
  stz GAME_DIVE_ACTIVE
  phx
  ldx #28
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

; X is the bank-zero packet destination. Eight four-byte records are the
; maximum; the existing counted-object header includes every appended piece.
.a16
native_dive_append:
  lda GAME_BG2_DISABLED
  bit #$ff00                 ; adjacent GAME_DIVE_ACTIVE byte
  bne :+
  rtl
:
  txy
  ldx #0
@entry:
  lda f:DIVE_EXTRA,x
  bit #$00ff
  beq @next
  state_code
  sta a:0,y
  lda f:DIVE_EXTRA+2,x
  xba
  sta a:2,y
  iny
  iny
  iny
  iny
@next:
  inx
  inx
  inx
  inx
  cpx #32
  bne @entry
  tyx
  rtl
.a8

; The arcade's dive uses a duration/pose table, then a 256-tick sea
; transition, followed by the six-piece climb. X is the player offset.
native_player_dive:
  ldx PLAYER_CURSOR
  stz PLAYER+7,x
  stz PLAYER+$55,x
  lda PLAYER+4,x
  and #1
  beq @wings_done
  lda PLAYER+4,x
  and #$f0
  bne @wings_move
  lda PLAYER+4,x
  and #3
  asl
  asl
  asl
  asl
  ora #1
  sta PLAYER+4,x
@wings_move:
  phd
  rep #$20
  txa
  clc
  adc #PLAYER
  tcd
  sep #$20
  jsr .loword(player_wing_depart)
  pld
  ldx PLAYER_CURSOR
@wings_done:
  lda PLAYER+$1a,x
  beq :+
  jmp @climb
:
  lda PLAYER+$1b,x
  bne @down
  phx
  lda PLAYER+$1c,x
  rep #$20
  and #$00ff
  asl
  tax
  sep #$20
  lda f:native_dive_first,x
  sta $d0
  lda f:native_dive_first+1,x
  sta $d1
  plx
  lda $d0
  cmp #$ff
  beq @climb_init
  cmp #$28
  bne @down_pose
  lda #1
  sta GAME_BG2_DISABLED
  jsl special_sync_shadow
  rep #$20
  lda #$1000
  sta CAMERA
  phx
  ; $5000-$57ff includes the 512-byte enemy-bullet pool at $5200.
  ; Do not reset its spawn configuration or cumulative debug counters.
  .assert BULLETS = ENEMY_POOL+$0200, error, "dive bullet pool moved"
  .assert BULLETS+$0200 <= ENEMY_POOL+$0800, error, "dive bullet pool outside clear"
  ldx #$07fe
@clear_ambient:
  stz ENEMY_POOL,x
  dex
  dex
  bpl @clear_ambient
  ldx #17*32-2
@clear_extended:
  stz EXTENDED_POOL,x
  dex
  dex
  bpl @clear_extended
  plx
  sep #$20
  stz CAMERA+2
  stz $d0
@down_pose:
  lda $d0
  sta PLAYER+$1b,x
  lda $d1
  sta PLAYER,x
  inc
  sta PLAYER+$20,x
  inc PLAYER+$1c,x
@down:
  lda PLAYER+3,x
  cmp #$d0
  bcs :+
  inc
:
  sta PLAYER+3,x
  sta PLAYER+$23,x
  dec PLAYER+$1b,x
  rtl
@climb_init:
  stz PLAYER+$1b,x
  stz PLAYER+$1c,x
  stz PLAYER+$1d,x
  stz PLAYER+$1e,x
  stz PLAYER+$1f,x
  lda #$ff
  sta PLAYER+$1a,x
  stz GAME_BG2_DISABLED
  jsl special_sync_shadow
  inc GAME_DIVE_ACTIVE
  lda PLAYER+5,x
  beq :+
  lda #$a0
  bra :++
:
  lda #$30
:
  sta PLAYER+2,x
  clc
  adc #$10
  sta PLAYER+$22,x
  lda #$10
  sta PLAYER+3,x
  sta PLAYER+$23,x
  lda #$c0
  sta PLAYER,x
  inc
  sta PLAYER+$20,x
  jsr native_dive_pieces
  lda #$10
  jsl game_sound_request
  rtl
@climb:
  lda PLAYER+$1b,x
  bne @climb_move
  phx
  lda PLAYER+$1c,x
  rep #$20
  and #$00ff
  sta $d4
  asl
  clc
  adc $d4
  tax
  sep #$20
  lda f:native_dive_second,x
  sta $d0
  lda f:native_dive_second+1,x
  sta $d1
  lda f:native_dive_second+2,x
  sta $d2
  plx
  lda $d0
  cmp #$ff
  beq @finish
  sta PLAYER+$1b,x
  lda $d1
  sta PLAYER,x
  inc
  sta PLAYER+$20,x
  lda PLAYER+$1c,x
  cmp #4
  bne :+
  lda PLAYER+2,x
  clc
  adc #8
  sta PLAYER+2,x
  clc
  adc #16
  sta PLAYER+$22,x
  lda PLAYER+3,x
  sec
  sbc #8
  sta PLAYER+3,x
:
  lda $d2
  sta PLAYER+$1d,x
  inc PLAYER+$1c,x
@climb_move:
  lda PLAYER+3,x
  clc
  adc PLAYER+$1d,x
  sta PLAYER+3,x
  sta PLAYER+$23,x
  jsr native_dive_pieces
  dec PLAYER+$1b,x
  rtl
@finish:
  stz PLAYER+$1a,x
  stz PLAYER+$1b,x
  stz PLAYER+$1c,x
  stz PLAYER+$1d,x
  stz PLAYER+$1e,x
  stz PLAYER+$1f,x
  stz CAMERA+$15
  stz CAMERA+$16
  lda #1
  sta CAMERA+$13
  sta STAGE_WORLD_PHASE
  sta STAGE_FLAGS+5
  lda #2
  sta PLAYER+8,x
  stz STAGE_FLAGS+$10
  stz STAGE_FLAGS+9
  stz GAME_DEPART_MODE
  lda PLAYER+4,x
  and #$10
  beq :+
  lda PLAYER+4,x
  ora #2
  sta PLAYER+4,x
  lda #2
  sta PLAYER+$0a,x
:
  jsr native_dive_pieces   ; final pose $24 removes the temporary pieces
  dec GAME_DIVE_ACTIVE
  rtl

; Materialize the four extra pieces without changing either wingman.
native_dive_pieces:
  lda PLAYER,x
  cmp #$24
  bne :+
  jmp @hide
:
  cmp #0
  beq @hide
  sta $d3
  lda PLAYER+1,x
  sta $d0
  lda PLAYER+2,x
  sta $d1
  lda PLAYER+3,x
  sta $d2
  phx
  lda PLAYER+5,x
  asl
  asl
  asl
  asl
  rep #$20
  and #$00ff
  tax
  sep #$20
  lda $d3
  clc
  adc #2
  sta f:DIVE_EXTRA,x
  clc
  adc #6
  sta f:DIVE_EXTRA+4,x
  inc
  sta f:DIVE_EXTRA+8,x
  inc
  sta f:DIVE_EXTRA+12,x
  lda $d0
  sta f:DIVE_EXTRA+1,x
  sta f:DIVE_EXTRA+5,x
  sta f:DIVE_EXTRA+9,x
  sta f:DIVE_EXTRA+13,x
  lda $d1
  clc
  adc #32
  sta f:DIVE_EXTRA+2,x
  sta f:DIVE_EXTRA+14,x
  lda $d1
  sta f:DIVE_EXTRA+6,x
  clc
  adc #16
  sta f:DIVE_EXTRA+10,x
  lda $d2
  sta f:DIVE_EXTRA+3,x
  sec
  sbc #16
  sta f:DIVE_EXTRA+7,x
  sta f:DIVE_EXTRA+11,x
  sta f:DIVE_EXTRA+15,x
  plx
  rts
@hide:
  phx
  lda PLAYER+5,x
  asl
  asl
  asl
  asl
  rep #$20
  and #$00ff
  tax
  sep #$20
  lda #0
  sta f:DIVE_EXTRA,x
  sta f:DIVE_EXTRA+4,x
  sta f:DIVE_EXTRA+8,x
  sta f:DIVE_EXTRA+12,x
  plx
  rts

native_dive_first:
  .byte $20,$24,$10,$26,$10,$28,$0a,$e0,$0a,$e2,$08,$e4,$08,$e6,$28,0,$ff,0
native_dive_second:
  .byte $10,$c0,3,$08,$c3,2,$08,$d0,2,$08,$d3,2,$10,$24,1,$ff,0,0
