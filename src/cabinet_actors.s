; Ending sprites use ordinary live object records and the resident art cache.
; Time is in arcade frames, advanced twice per native update.
CAB_FLAG_TIME = $1552
CAB_FLY_TIME = $1554
CAB_FLY_X = $1556
CAB_DOG_INDEX = $1558
CAB_FLAG_PHASE = $155a
CAB_ENDING_SCORES = $1560

cabinet_actors_init:
.a8
  rep #$20
  lda #$ffff
  sta CAB_FLAG_TIME
  sta CAB_FLY_TIME
  sta CAB_DOG_INDEX
  stz CAB_FLY_X
  stz CAB_FLAG_PHASE
  sep #$20
  rtl

cabinet_actors_tick:
.a8
.i16
  ; Raise the flag after the first history paragraph, before its pause.
  lda CAB_ENDING_STEP
  cmp #1
  bne @flag_ready
  rep #$20
  lda CAB_TEXT_CLOCK
  cmp #CAB_FLAG_START_TICKS
  bcc @flag_ready16
  lda CAB_FLAG_TIME
  bpl :+
  stz CAB_FLAG_TIME
:
  sep #$20
@flag_ready:
  rep #$20
@flag_ready16:
  lda CAB_FLAG_TIME
  bpl :+
  jmp @fly
:
  clc
  adc #2
  sta CAB_FLAG_TIME
  lsr
  lsr
  ; The source tests $98 only after a complete 40-frame pose cycle:
  ; 6 + 15 cycles * 40/4 stops at 156, rather than mid-cycle at 152.
  cmp #150
  bcc :+
  lda #150
:
  clc
  adc #6
  sta $d8                     ; raw Y, rises at one quarter pixel per frame
  lda CAB_FLAG_PHASE
  clc
  adc #2
  cmp #40
  bcc :+
  sbc #40
:
  sta CAB_FLAG_PHASE
  ldx #0
@divide:
  cmp #10
  bcc @records
  sec
  sbc #10
  pha
  txa
  clc
  adc #64
  tax
  pla
  bra @divide
@records:
  ldy #0
  sep #$20
@flag_record:
  lda f:cabinet_flag_poses,x
  sta ENEMY_POOL,y
  lda f:cabinet_flag_poses+1,x
  sta $da
  lda f:cabinet_flag_poses+2,x
  sta ENEMY_POOL+2,y
  rep #$20
  lda f:cabinet_flag_poses+3,x
  and #255
  sta $d4
  lda $d8
  sec
  sbc $d4
  sep #$20
  sta ENEMY_POOL+3,y
  lda $da
  bcs :+
  ora #$10                    ; rows below the screen use the ninth Y bit
:
  sta ENEMY_POOL+1,y
  lda #1
  sta ENEMY_POOL+8,y
  rep #$20
  txa
  clc
  adc #4
  tax
  tya
  clc
  adc #32
  tay
  cpy #512
  bcc :+
  bra @fly
:
  sep #$20
  bra @flag_record
@fly:
.a16
  sep #$20
  lda CAB_ENDING_STEP
  cmp #4
  bcc @dog
  rep #$20
  lda CAB_FLY_TIME
  bpl :+
  lda #0
:
  clc
  adc #2
  sta CAB_FLY_TIME
  lsr
  lsr
  lsr
  lsr
  and #3
  tax
  lda CAB_FLY_X
  cmp #$ffff
  beq @fly_done
  clc
  adc #56
  bcc :+
  lda #$ffff
:
  sta CAB_FLY_X
  cmp #$ffff
  beq @fly_done
  sep #$20
  lda f:cabinet_fly_poses,x
  sta ENEMY_POOL+512
  lda #$a9
  sta ENEMY_POOL+513
  lda CAB_FLY_X+1
  sta ENEMY_POOL+514
  lda #200
  sta ENEMY_POOL+515
  lda #1
  sta ENEMY_POOL+520
  bra @dog
@fly_done:
.a16
  sep #$20
  stz ENEMY_POOL+520
@dog:
  lda CAB_ENDING_STEP
  cmp #11
  bcc @done
  bne @dog_started
  rep #$20
  lda CAB_TEXT_CLOCK
  cmp #CAB_DOG_START_TICKS
  bcs @dog_ready
  sep #$20
  rtl
@dog_started:
  rep #$20
@dog_ready:
  lda CAB_DOG_INDEX
  bpl :+
  lda #0
:
  cmp #CABINET_DOG_BYTES-2
  bcs @dog_done
  tax
  clc
  adc #2
  sta CAB_DOG_INDEX
  sep #$20
  lda f:cabinet_dog_poses,x
  sta ENEMY_POOL+544
  lda #9
  sta ENEMY_POOL+545
  lda f:cabinet_dog_poses+1,x
  sta ENEMY_POOL+546
  lda #128
  sta ENEMY_POOL+547
  lda #1
  sta ENEMY_POOL+552
@done:
  rtl
@dog_done:
  sep #$20
  stz ENEMY_POOL+552
  rtl
