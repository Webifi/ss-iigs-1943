; Native port of the US basic gun ($1579-$15AE, bank 1 $9522-$95C6).
; Caller has already selected the basic weapon and accepted the fire input.
; PLAYER uses the native flight record. SHOTS contains nine 32-byte P1 slots.
; Does not replace the weapon controller, collision or projectile movement.
; Output GUN_SOUND is a command for the native sound queue (0 means none).
; M=8/X=16, DBR=DP=0. Scratch $d0..d7.
.a8
.i16
SHOTS = $1800
GUN_SOUND = $17f0
.ifndef GUN_OVERFLOW
GUN_OVERFLOW = SHOTS+9*32
.endif

gun_basic:
  stz GUN_SOUND
  lda PLAYER+$54
  clc
  adc #8
  sta PLAYER+$54
  beq @ready
  rts
@ready:
  ldx #0
  stz $d0
@count:
  lda SHOTS+8,x
  beq @next
  inc $d0
@next:
  rep #$20
  txa
  clc
  adc #32
  tax
  sep #$20
  cpx #9*32
  bne @count
  lda $d0
  sta PLAYER+$53
  lda PLAYER+4
  and #1
  bne @paired
  lda $d0
  cmp #4
  beq @done
  ldx #0
@single_slot:
  lda SHOTS+8,x
  beq @single
  rep #$20
  txa
  clc
  adc #32
  tax
  sep #$20
  cpx #9*32
  bne @single_slot
  ; Keep the original scratch-overflow behavior after the nine live slots.
  ldx #GUN_OVERFLOW-SHOTS
@single:
  jsr gun_spawn
  bra @fired
@paired:
  lda $d0
  cmp #7
  bcs @done
  ldx #0
@pair_slot:
  lda SHOTS+8,x
  beq @pair
  rep #$20
  txa
  clc
  adc #64
  tax
  sep #$20
  cpx #4*64
  bne @pair_slot
  ldx #GUN_OVERFLOW-SHOTS
@pair:
  jsr gun_spawn
  lda SHOTS+2,x
  sec
  sbc #16
  sta SHOTS+2,x
  lda #1
  sta SHOTS+$0e,x
  stz SHOTS+$0f,x
  rep #$20
  txa
  clc
  adc #32
  tax
  sep #$20
  jsr gun_spawn
  lda SHOTS+2,x
  clc
  adc #16
  sta SHOTS+2,x
  lda #1
  sta SHOTS+$0e,x
  sta SHOTS+$0f,x
@fired:
  lda #2
  sta PLAYER+$12
  lda #1
  sta GUN_SOUND
@done:
  rts

gun_spawn:
  lda f:gun_basic_template
  sta SHOTS,x
  lda #9
  sta SHOTS+1,x
  lda PLAYER+2
  clc
  adc f:gun_basic_template+1
  sta SHOTS+2,x
  lda PLAYER+3
  clc
  adc f:gun_basic_template+2
  sta SHOTS+3,x
  .repeat 4,I
    lda f:gun_basic_template+3+I
    sta SHOTS+4+I,x
  .endrepeat
  .repeat 5,I
    lda f:gun_basic_template+7+I
    sta SHOTS+$0a+I,x
  .endrepeat
  lda #2
  sta SHOTS+8,x
  inc PLAYER+$53
  lda PLAYER+5
  sta SHOTS+9,x
  rts
