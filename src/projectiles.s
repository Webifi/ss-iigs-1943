; Native port of original-US $124F-$130D, all eighteen player-shot slots.
; PLAYER includes both 128-byte player records; SHOTS is eighteen 32-byte slots.
; Movement, delay, lifetime, paired-hit animation and owner-count retirement.
; Collision detection is separate. M=8/X=16, DBR=DP=0, scratch $d0.
.a8
.i16

.ifdef CONTINUOUS_GAME
projectiles_step:
  jsl projectiles_step_fast
  rts
.pushseg
.segment "SOUND_EXTRA"
projectiles_step_fast:
  phy
  ldy #0
@group:
  .repeat 6,I
    lda SHOTS+I*32+8,y
    beq :+
    pha
    rep #$20
    tya
    clc
    adc #I*32
    tax
    sep #$20
    pla
    jsl projectile_one
:
  .endrepeat
  rep #$20
  tya
  clc
  adc #192
  tay
  sep #$20
  cpy #18*32
  beq :+
  jmp .loword(@group)
:
  ply
  ldx #18*32
  cpx #18*32
  rtl
.popseg
.else
projectiles_step:
  ldx #0
@slot:
  lda SHOTS+8,x
  beq @next
  jsr projectile_one
@next:
  rep #$20
  txa
  clc
  adc #32
  tax
  sep #$20
  cpx #18*32
  bne @slot
  rts

.endif

.ifdef CONTINUOUS_GAME
.macro projectile_return
  rtl
.endmacro
.else
.macro projectile_return
  rts
.endmacro
.endif
.ifdef CONTINUOUS_GAME
.pushseg
.segment "INPUT_LATE"
.endif
projectile_one:
  cmp #4
  beq @explosion
  lda SHOTS+$0b,x
  beq @move
  dec
  sta SHOTS+$0b,x
  bne @done
@move:
  lda SHOTS+4,x
  clc
  adc SHOTS+2,x
  cmp #$10
  bcc @dead
  cmp #$e0
  bcs @dead
  sta SHOTS+2,x
  lda SHOTS+5,x
  clc
  adc SHOTS+3,x
  bcs @dead
  sta SHOTS+3,x
  dec SHOTS+$0a,x
  beq @dead
@done:
  projectile_return
@explosion:
  lda SHOTS+$0e,x
  beq @animate
  stz SHOTS+$0e,x
  lda SHOTS+$0f,x
  bne @previous
  lda #4
  sta SHOTS+$28,x
  stz SHOTS+$2e,x
  bra @animate
@previous:
  lda #4
  sta SHOTS-$18,x
  stz SHOTS-$12,x
@animate:
  lda SHOTS+$1b,x
  beq @animation_next
  dec SHOTS+$1b,x
  projectile_return
@animation_next:
  lda SHOTS+$1c,x
  asl
  adc #0
  inc SHOTS+$1c,x
  phx
  rep #$20
  and #255
  tax
  sep #$20
  lda f:shot_animation,x
  sta $d0
  cmp #255
  beq @animation_end
  lda f:shot_animation+1,x
  plx
  sta SHOTS,x
  lda $d0
  sta SHOTS+$1b,x
  projectile_return
@animation_end:
  plx
  stz SHOTS+$1b,x
  stz SHOTS+$1c,x
@dead:
  stz SHOTS,x
  stz SHOTS+8,x
  lda SHOTS+9,x
  bne @owner_two
  lda PLAYER+$53
  beq @retired
  dec PLAYER+$53
@retired:
  projectile_return
@owner_two:
  lda PLAYER+$d3
  beq @retired
  dec PLAYER+$d3
  projectile_return

.ifdef CONTINUOUS_GAME
.popseg
.endif
