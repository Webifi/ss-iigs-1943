; US $46E9-$484A cooperative deck sequence and bank-one $9262/$934D.
; Timers are game ticks; script tables and templates are original ROM data.
.a8
.i16
LAUNCH_SMALL = $14d0
LAUNCH_LARGE = $14d1
LAUNCH_SLOT = $14d2
LAUNCH_INDEX = $14d4
LAUNCH_SOURCE = $14d6

native_intro_tick:
  rep #$20
  lda GAME_SEQUENCE_TICKS
  bne @clock
  stz LAUNCH_SMALL
  stz LAUNCH_INDEX
  ldx #0
@deck:
  stx LAUNCH_SLOT
  jsr .loword(launch_large_clear)
  lda #.loword(launch_deck_template)
  sta $d4
  lda #.bankbyte(launch_deck_template)
  sta $d6
  ldy #0
@template:
  lda [$d4],y
  sta LARGE_POOL,x
  inx
  inx
  iny
  iny
  cpy #32
  bcc @template
  ldx LAUNCH_INDEX
  lda f:launch_deck_positions,x
  ldx LAUNCH_SLOT
  sep #$20
  sta LARGE_POOL+2,x
  rep #$20
  ldx LAUNCH_INDEX
  lda f:launch_deck_positions+1,x
  ldx LAUNCH_SLOT
  sep #$20
  sta LARGE_POOL+4,x
  xba
  sta LARGE_POOL+$10,x
  lda LARGE_POOL+1,x
  sta LARGE_POOL+$41,x
  lda LARGE_POOL+3,x
  sec
  sbc #16
  sta LARGE_POOL+$43,x
  rep #$20
  lda LAUNCH_INDEX
  clc
  adc #3
  sta LAUNCH_INDEX
  txa
  clc
  adc #128
  tax
  cpx #640
  bcc @deck
@clock:
.a16
  inc GAME_SEQUENCE_TICKS
  lda GAME_SEQUENCE_TICKS
  cmp #120
  bcs :+
  sep #$20
  rtl
:
.a16
  and #1
  beq :+
  lda #$d100
  bra @blink
:
  lda #$d500
@blink:
  sta CAMERA+$0f
  sep #$20
  lda LAUNCH_SMALL
  cmp #5
  bcs @large
  ldx #0
@small_free:
  lda EXTENDED_POOL+8,x
  beq @small_found
  rep #$20
  txa
  clc
  adc #32
  tax
  sep #$20
  cpx #17*32
  bcc @small_free
  bra @large
@small_found:
  stx LAUNCH_SLOT
  rep #$20
  lda #.loword(launch_small_template)
  sta $d4
  lda #.bankbyte(launch_small_template)
  sta $d6
  ldy #0
@small_copy:
  lda [$d4],y
  sta EXTENDED_POOL,x
  inx
  inx
  iny
  iny
  cpy #32
  bcc @small_copy
  lda LAUNCH_SMALL
  and #255
  asl
  asl
  tax
  lda f:launch_small_positions,x
  sta $d0
  sep #$20
  lda f:launch_small_positions+3,x
  ldx LAUNCH_SLOT
  sta EXTENDED_POOL+4,x
  rep #$20
  lda $d0
  sta EXTENDED_POOL+2,x
  sep #$20
  inc LAUNCH_SMALL
@large:
  ldx #0
@large_free:
  lda LARGE_POOL+8,x
  beq @large_found
  rep #$20
  txa
  clc
  adc #128
  tax
  sep #$20
  cpx #1536
  bcc @large_free
  rtl
@large_found:
  stx LAUNCH_SLOT
  rep #$20
  jsr .loword(launch_large_clear)
  lda #.loword(launch_large_template)
  sta $d4
  lda #.bankbyte(launch_large_template)
  sta $d6
  ldy #0
@large_copy:
  lda [$d4],y
  sta LARGE_POOL,x
  inx
  inx
  iny
  iny
  cpy #32
  bcc @large_copy
  lda LAUNCH_LARGE
  and #255
  asl
  asl
  tax
  lda f:launch_large_positions,x
  sta $d0
  sep #$20
  lda f:launch_large_positions+3,x
  ldx LAUNCH_SLOT
  sta LARGE_POOL+4,x
  rep #$20
  lda $d0
  sta LARGE_POOL+2,x
  sep #$20
  lda LARGE_POOL+3,x
  sec
  sbc #16
  sta LARGE_POOL+$43,x
  lda LARGE_POOL+1,x
  sta LARGE_POOL+$41,x
  inc LAUNCH_LARGE
  lda LAUNCH_LARGE
  cmp #9
  bcc @done
  rep #$20
  lda #$d500
  sta CAMERA+$0f
  stz CAMERA+$15
  sep #$20
  lda PLAYER+1
  and #$ef
  sta PLAYER+1
  sta PLAYER+$21
  stz STAGE_BANNER_TASK
@done:
  rtl

launch_large_clear:
.a16
  ldy #64
@clear:
  stz LARGE_POOL,x
  inx
  inx
  dey
  bne @clear
  ldx LAUNCH_SLOT
  rts

native_player_presentation:
.a8
  stz PLAYER+7
  stz PLAYER+$55
  lda PLAYER+8
  cmp #16
  bne :+
  jmp .loword(@takeoff)
:
  cmp #14
  beq @on_deck
  rtl
@on_deck:
  lda PLAYER
  cmp #$4a
  bne @return_to_deck
  rep #$20
  stz PLAYER+$1b
  stz PLAYER+$1d
  sep #$20
  stz PLAYER+$1f         ; byte timer ends immediately before sprite code
  rtl
@return_to_deck:
  ; $9281-$9316, docking uses the current position, not a restored state.
  lda PLAYER+$1b
  cmp #3
  beq @dock_animation
  lda PLAYER+2
  cmp #$68
  beq @dock_x
  bcs @left
  inc PLAYER+2
  lda #$26
  bra @pose
@left:
  dec PLAYER+2
  lda #$22
  bra @pose
@dock_x:
  lda PLAYER+$1b
  ora #1
  sta PLAYER+$1b
  lda #$24
@pose:
  sta PLAYER
  inc
  sta PLAYER+$20
  lda PLAYER+2
  clc
  adc #16
  sta PLAYER+$22
  lda PLAYER+3
  cmp #$50
  beq @dock_y
  bcs @up
  inc
  bra @y
@up:
  dec
  bra @y
@dock_y:
  lda PLAYER+$1b
  ora #2
  sta PLAYER+$1b
  lda PLAYER+3
@y:
  sta PLAYER+3
  sta PLAYER+$23
  rtl
@dock_animation:
  lda PLAYER+$1c
  bne @dock_wait
  rep #$20
  lda PLAYER+$1d
  and #255
  asl
  tax
  sep #$20
  lda f:launch_dock_poses,x
  sta PLAYER+$1c
  lda f:launch_dock_poses+1,x
  sta PLAYER
  inc
  sta PLAYER+$20
  inc PLAYER+$1d
@dock_wait:
  dec PLAYER+$1c
  rtl
@takeoff:
  lda PLAYER+$1b
  bne @move
  rep #$20
  lda PLAYER+$1c
  and #255
  asl
  asl
  tax
  sep #$20
  lda f:launch_takeoff,x
  cmp #255
  beq @finished
  sta PLAYER
  lda f:launch_takeoff+1,x
  sta PLAYER+$1e
  lda f:launch_takeoff+2,x
  sta PLAYER+$1f
  lda f:launch_takeoff+3,x
  sta PLAYER+$1b
  inc PLAYER+$1c
@move:
  lda PLAYER+$41
  ora #16
  ldx PLAYER+$1c
  cpx #$37
  bne :+
  and #$ef
:
  sta PLAYER+$41
  sta PLAYER+$61
  lda PLAYER
  inc
  sta PLAYER+$20
  clc
  adc #7
  sta PLAYER+$40
  inc
  sta PLAYER+$60
  lda PLAYER+2
  sec
  sbc PLAYER+$1e
  sta PLAYER+2
  sta PLAYER+$42
  clc
  adc #16
  sta PLAYER+$22
  sta PLAYER+$62
  lda PLAYER+3
  clc
  adc PLAYER+$1f
  sta PLAYER+3
  sta PLAYER+$23
  sec
  sbc #16
  sta PLAYER+$43
  sta PLAYER+$63
  dec PLAYER+$1b
  rtl
@finished:
  rep #$20
  stz PLAYER+$1b
  stz PLAYER+$1d
  sep #$20
  stz PLAYER+$1f         ; byte timer ends immediately before sprite code
  lda #1
  sta PLAYER+7
  lda #2
  sta PLAYER+8
  stz STAGE_FLAGS+$10
  stz STAGE_FLAGS+5
  stz STAGE_WORLD_PHASE
  lda PLAYER+$41
  and #$ef
  sta PLAYER+$41
  sta PLAYER+$61
  lda #255
  sta PLAYER+$43
  sta PLAYER+$63
  rtl
