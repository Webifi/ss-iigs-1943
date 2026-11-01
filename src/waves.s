; The plane waves (US arcade bank 0 $880B-$88D5): a wave of WAVE_GROUP 1-5
; puts WAVE_PLANES planes (wave_template) in the first free ENEMY_POOL slots
; at its wave_positions; WAVE_CIRCLE puts CIRCLE_PLANES planes in a circle.
; With WAVE_MODIFIER the planes carry that drop (OBJ_DROP) on the drop path,
; and WAVE_COUNTS counts them. A full pool ends the wave: the planes made
; before stay.
.a8
.i16
MOTION_WAVE_DROP = $8b78     ; bank 0: the path of a wave plane with a drop
WAVE_PLANES = 3              ; the planes of a wave
WAVE_CIRCLE = 7              ; WAVE_GROUP of the circle wave
CIRCLE_PLANES = 8            ; the planes of the circle wave
CIRCLE_DELAY = 16            ; each circle plane starts this many updates later
; wave_positions: for each group from 1, WAVE_PLANES entries of the cross
; place and the start delay (OBJ_DURATION).
POSITION_SIZE = 2

; wave_spawn: the wave WAVE_GROUP (stage_dispatch). JSR; A8, X16.
wave_spawn:
  lda WAVE_GROUP
  cmp #WAVE_CIRCLE
  bne :+
  jmp wave_circle
:
  lda WAVE_MODIFIER
  beq @ordinary
  a16
  lda WAVE_GROUP
  and #255
  tax
  a8
  stz WAVE_COUNTS,x
@ordinary:
  a16
  lda WAVE_GROUP
  and #255
  dec
  asl
  sta WAVE_POSITION
  asl
  clc
  adc WAVE_POSITION
  sta WAVE_POSITION             ; (WAVE_GROUP - 1) * WAVE_PLANES * POSITION_SIZE
  lda #WAVE_PLANES
  sta WAVE_LEFT
  ldx #0
@find:
  a8
  lda ENEMY_POOL+OBJ_TYPE,x
  beq @found
  a16
  txa
  clc
  adc #OBJECT_SIZE
  tax
  cpx #ENEMY_COUNT*OBJECT_SIZE
  bne @find
  a8
  rts
@found:
.a8
  ; The plane: the template, its place and delay, its group.
  a16
  stx WAVE_RECORD
  ldy #0
@copy:
  lda wave_template,y
  sta ENEMY_POOL,x
  inx
  inx
  iny
  iny
  cpy #OBJECT_SIZE
  bne @copy
  ldx WAVE_RECORD
  ldy WAVE_POSITION
  a8
  lda wave_positions,y
  sta ENEMY_POOL+SPR_CROSS,x
  lda wave_positions+1,y
  sta ENEMY_POOL+OBJ_DURATION,x
  lda WAVE_GROUP
  sta ENEMY_POOL+OBJ_WAVE_COUNTER,x
  lda WAVE_MODIFIER
  beq @next
  sta ENEMY_POOL+OBJ_DROP,x
  a16
  lda #MOTION_WAVE_DROP
  sta ENEMY_POOL+OBJ_MOTION,x
  lda WAVE_GROUP
  and #255
  tay
  a8
  lda WAVE_COUNTS,y
  inc
  sta WAVE_COUNTS,y
@next:
  a16
  inc WAVE_POSITION
  inc WAVE_POSITION             ; POSITION_SIZE
  dec WAVE_LEFT
  bne @find
  a8
  stz WAVE_MODIFIER
  rts

; wave_circle: the circle wave: CIRCLE_PLANES planes (wave_circle_template)
; start CIRCLE_DELAY updates apart; all are counted in WAVE_COUNTS.
wave_circle:
  stz WAVE_COUNTS+WAVE_CIRCLE
  a16
  stz WAVE_POSITION             ; here: the start delay
  lda #CIRCLE_PLANES
  sta WAVE_LEFT
  ldx #0
@find:
  a8
  lda ENEMY_POOL+OBJ_TYPE,x
  beq @found
  a16
  txa
  clc
  adc #OBJECT_SIZE
  tax
  cpx #ENEMY_COUNT*OBJECT_SIZE
  bne @find
  bra @done
@found:
.a8
  a16
  stx WAVE_RECORD
  ldy #0
@copy:
  lda wave_circle_template,y
  sta ENEMY_POOL,x
  inx
  inx
  iny
  iny
  cpy #OBJECT_SIZE
  bne @copy
  ldx WAVE_RECORD
  a8
  lda WAVE_POSITION
  sta ENEMY_POOL+OBJ_DURATION,x
  clc
  adc #CIRCLE_DELAY
  sta WAVE_POSITION
  lda WAVE_MODIFIER
  sta ENEMY_POOL+OBJ_DROP,x
  inc WAVE_COUNTS+WAVE_CIRCLE
  a16
  dec WAVE_LEFT
  bne @find
@done:
  a8
  stz WAVE_MODIFIER
  rts
.assert WAVE_PLANES*POSITION_SIZE = 6, error ; the ASL, ASL, ADC above
