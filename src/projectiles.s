; The player shots: move each live shot, end it at the field edge or when its
; life runs out, and run the impact animation of a shot that hit.
; A native port of the US arcade code at $124F-$130D, for all SHOT_COUNT shot
; records (SHOTS). Collisions are elsewhere (src/enemy_collision.s,
; src/bullet_intercept.s, src/large_contact.s). A8, X16, DBR = 0, D = 0.
.a8
.i16
SHOT_GROUP = 6               ; shot records of one unrolled pass
SHOT_CROSS_MIN = $10         ; a shot ends outside SHOT_CROSS_MIN..SHOT_CROSS_MAX-1
SHOT_CROSS_MAX = $e0
SHOT_ANIM_END = 255          ; the time byte that ends shot_animation

; projectiles_step: one step of every shot (flight_weapons). A, X: changed.
projectiles_step:
  jsl projectiles_step_fast
  rts
.pushseg
.segment "SOUND_EXTRA"
; projectiles_step_fast: test SHOT_GROUP records in each unrolled pass and
; call projectile_one for each live one (X = its offset, A = its state).
projectiles_step_fast:
  phy
  ldy #0
@group:
  .repeat SHOT_GROUP,I
    lda SHOTS+I*SHOT_SIZE+SHOT_STATE,y
    beq :+
    pha
    a16
    tya
    clc
    adc #I*SHOT_SIZE
    tax
    a8
    pla
    jsl projectile_one
:
  .endrepeat
  a16
  tya
  clc
  adc #SHOT_GROUP*SHOT_SIZE
  tay
  a8
  cpy #SHOT_COUNT*SHOT_SIZE
  beq :+
  jmp .loword(@group)
:
  ply
  rtl
.popseg
.assert SHOT_COUNT .mod SHOT_GROUP = 0, error

.pushseg
.segment "INPUT_LATE"
; projectile_one: one step of the shot at SHOTS+X. A = its SHOT_STATE.
; X is kept. A: changed.
projectile_one:
  cmp #SHOT_IMPACT
  beq @explosion
  ; A flying shot: wait SHOT_DELAY updates, then move by its steps.
  lda SHOTS+SHOT_DELAY,x
  beq @move
  dec
  sta SHOTS+SHOT_DELAY,x
  bne @done
@move:
  lda SHOTS+SHOT_CROSS_STEP,x
  clc
  adc SHOTS+SPR_CROSS,x
  cmp #SHOT_CROSS_MIN
  bcc @dead
  cmp #SHOT_CROSS_MAX
  bcs @dead
  sta SHOTS+SPR_CROSS,x
  lda SHOTS+SHOT_ALONG_STEP,x
  clc
  adc SHOTS+SPR_ALONG,x
  bcs @dead                     ; past the top of the field
  sta SHOTS+SPR_ALONG,x
  dec SHOTS+SHOT_LIFE,x
  beq @dead
@done:
  rtl
  ; An impact. A paired shot (two records) passes the impact to its other
  ; half once: the next record (SHOT_LINK 0) or the previous one.
@explosion:
  lda SHOTS+SHOT_PAIRED,x
  beq @animate
  stz SHOTS+SHOT_PAIRED,x
  lda SHOTS+SHOT_LINK,x
  bne @previous
  lda #SHOT_IMPACT
  sta SHOTS+SHOT_SIZE+SHOT_STATE,x
  stz SHOTS+SHOT_SIZE+SHOT_PAIRED,x
  bra @animate
@previous:
  lda #SHOT_IMPACT
  sta SHOTS-SHOT_SIZE+SHOT_STATE,x
  stz SHOTS-SHOT_SIZE+SHOT_PAIRED,x
  ; The impact animation: shot_animation holds (updates, sprite code) pairs;
  ; a time of SHOT_ANIM_END ends it.
@animate:
  lda SHOTS+SHOT_ANIM_TIME,x
  beq @animation_next
  dec SHOTS+SHOT_ANIM_TIME,x
  rtl
@animation_next:
  lda SHOTS+SHOT_ANIM_STEP,x
  asl                           ; two bytes for each frame
  inc SHOTS+SHOT_ANIM_STEP,x
  phx
  a16
  and #255
  tax
  a8
  lda f:shot_animation,x
  sta SHOT_FRAME_TIME
  cmp #SHOT_ANIM_END
  beq @animation_end
  lda f:shot_animation+1,x
  plx
  sta SHOTS+SPR_CODE,x
  lda SHOT_FRAME_TIME
  sta SHOTS+SHOT_ANIM_TIME,x
  rtl
@animation_end:
  plx
  stz SHOTS+SHOT_ANIM_TIME,x
  stz SHOTS+SHOT_ANIM_STEP,x
  ; The shot ends: free its record and take one from its owner's live shots.
@dead:
  stz SHOTS+SPR_CODE,x
  stz SHOTS+SHOT_STATE,x        ; SHOT_FREE
  lda SHOTS+SHOT_OWNER,x
  bne @owner_two
  lda PLAYER+PL_SHOTS
  beq @retired
  dec PLAYER+PL_SHOTS
@retired:
  rtl
@owner_two:
  lda PLAYER2+PL_SHOTS
  beq @retired
  dec PLAYER2+PL_SHOTS
  rtl
.popseg
.assert SHOT_FREE = 0, error    ; @dead frees the record with STZ
