; Moving background bosses. Motion is prepared native data, independent of
; arcade scheduler stacks. $1BB0-$1BC7 lies after the active-shot list.
.a8
.i16
AIR_BOSS = $1bb0
AIR_FRAME = AIR_BOSS+1
AIR_SECONDS = AIR_BOSS+2
AIR_WAIT = AIR_BOSS+3
AIR_PATH = AIR_BOSS+4
AIR_DX = AIR_BOSS+6
AIR_DY = AIR_BOSS+8
AIR_XFRAC = AIR_BOSS+10
AIR_YFRAC = AIR_BOSS+11
AIR_SHAKE = AIR_BOSS+12
AIR_LIFE = AIR_BOSS+13
AIR_LOOPS = AIR_BOSS+14
AIR_RESULT = AIR_BOSS+15
AIR_PERCENT = AIR_BOSS+16
AIR_CORE = AIR_BOSS+18
AIR_TEMP = AIR_BOSS+20
AIR_TEMP2 = AIR_BOSS+22

game_airboss_event:
  rep #$20
  lda STAGE_CALLBACK
  cmp #$46da
  bne @other_event
  sep #$20
  stz AIR_BOSS
  stz AIR_LIFE
  lda CAMERA_STAGE
  bne :+
  lda #64
  sta CONTACT_CONTEXT
:
  clc
  rtl
@other_event:
.a16
  ldx #0
  cmp #$a6f3
  beq @start
  ldx #1
  cmp #$a704
  beq @start
  ldx #2
  cmp #$a715
  beq @start
  sep #$20
  clc
  rtl
@start:
.a16
  txa
  pha
  ldx #22
@clear:
  stz AIR_BOSS,x
  dex
  dex
  bpl @clear
  pla
  asl
  tax
  lda f:air_motion_starts,x
  sta AIR_PATH
  lda #$ffff
  sta CAMERA+$15
  txa
  lsr
  inc
  sep #$20
  sta AIR_BOSS
  clc
  adc #2
  sta AIR_LIFE
  jsr .loword(extended_allocate)
  bcc @done
  rep #$20
  stx AIR_CORE
  .repeat 16,I
    lda f:air_core_template+I*2
    sta a:I*2,x
  .endrepeat
  sep #$20
  lda AIR_LIFE
  sta a:$10,x
@done:
  sec
  rtl

game_airboss_tick:
.a8
  lda AIR_BOSS
  bne :+
  rtl
:
  inc AIR_FRAME
  lda AIR_FRAME
  cmp #60
  bne :+
  stz AIR_FRAME
  inc AIR_SECONDS
:
  lda AIR_BOSS
  bpl @alive
  rep #$20
  lda AIR_FRAME
  and #1
  beq @even
  lda CAMERA+$0f
  sec
  sbc #256
  bra @shake
@even:
  lda CAMERA+$0f
  clc
  adc #256
@shake:
  sta CAMERA+$0f
  sep #$20
  inc AIR_SHAKE
  lda AIR_SHAKE
  cmp #50
  bcs :+
  rtl
:
  jmp .loword(game_airboss_finish)
@alive:
  lda AIR_WAIT
  bne @move
@next:
  ldx AIR_PATH
  lda f:$010001,x
  beq @motion
  cmp #1
  beq @jump
  cmp #2
  beq @loop
  jmp .loword(game_airboss_finish)
@loop:
  inc AIR_LOOPS
  lda AIR_LOOPS
  cmp f:$010000,x
  bne @jump
  inx
  inx
@jump:
  rep #$20
  lda f:$010002,x
  sta AIR_PATH
  sep #$20
  bra @next
@motion:
  lda f:$010000,x
  sta AIR_WAIT
  rep #$20
  lda f:$010002,x
  sta AIR_DX
  lda f:$010004,x
  sta AIR_DY
  lda f:$010006,x
  sta AIR_PATH
  sep #$20
@move:
  rep #$20
  lda AIR_XFRAC
  and #255
  clc
  adc AIR_DX
  sta $d4
  sep #$20
  sta AIR_XFRAC
  lda $d5
  clc
  adc CAMERA+$0e
  sta CAMERA+$0e
  lda $d5
  eor #255
  inc
  sta CAMERA+$17
  rep #$20
  lda AIR_YFRAC
  and #255
  clc
  adc AIR_DY
  sta $d4
  sep #$20
  sta AIR_YFRAC
  lda $d5
  eor #255
  inc
  sta CAMERA+$18
  rep #$20
  lda $d4
  xba
  and #255
  cmp #128
  bcc :+
  ora #$ff00
:
  clc
  adc CAMERA+$0f
  sta CAMERA+$0f
  sep #$20
  dec AIR_WAIT
@return:
  rtl

game_airboss_finish:
.a8
  stz AIR_BOSS
  stz AIR_LIFE
  stz CAMERA+$0e
  rep #$20
  lda STAGE_SAVED_CAMERA
  sta CAMERA+$0f
  stz CAMERA+$15
  sep #$20
  lda #$30
  jsl game_sound_request
  rtl
