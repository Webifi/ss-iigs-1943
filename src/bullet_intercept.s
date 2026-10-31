; Original US $6079-$6132. Enemy-bullet interception precedes body contact.
; Carry set means an intercepted bullet; the caller plays INTERCEPT_SOUND.
.a8
.i16
INTERCEPT_SOUND = $17cf

bullet_intercept:
  stz INTERCEPT_SOUND
  ldx #0
  ldy #9*32
  lda PLAYER+8
  cmp #2
  beq @p1
  lda PLAYER+$88
  cmp #2
  beq :+
  clc
  rts
:
  ldx #9*32
  ldy #18*32
  bra @eligible
@p1:
  lda PLAYER+$88
  cmp #2
  bne @eligible
  ldy #18*32
@eligible:
  lda ENEMY+9
  and #2
  bne @start
  lda PLAYER+$51
  and #2
  beq @p2_weapon
  ldx #0
  ldy #9*32
  lda PLAYER+$d1
  and #2
  beq @start
  ldy #18*32
  bra @start
@p2_weapon:
  lda PLAYER+$d1
  and #2
  beq @miss
  ldx #9*32
  ldy #18*32
@start:
  sty $dc
@shot:
  lda SHOTS+8,x
  cmp #2
  bne @next
  lda SHOTS+3,x
  sec
  sbc ENEMY+3
  bcs :+
  eor #255
  inc
:
  sta $de
  lda SHOTS+7,x
  clc
  adc ENEMY+$0d
  cmp $de
  bcc @next
  lda SHOTS+2,x
  sec
  sbc ENEMY+2
  bcs :+
  eor #255
  inc
:
  sta $de
  lda SHOTS+6,x
  clc
  adc ENEMY+$0c
  cmp $de
  bcs @hit
@next:
  rep #$20
  txa
  clc
  adc #32
  tax
  sep #$20
  cpx $dc
  bne @shot
@miss:
  clc
  rts
@hit:
  lda ENEMY+$0b
  cmp SHOTS+$0d,x
  bcc @penetrates
  lda #4
  sta SHOTS+8,x
  bra @erase
@penetrates:
  ; Z80 LD (IX+$0B),0 leaves the old HP in A before SUB/NEG.
  sta $de
  lda SHOTS+$0d,x
  sec
  sbc $de
  sta SHOTS+$0d,x
@erase:
  stz ENEMY+$0b
  stz ENEMY+9
  stz ENEMY+4
  rep #$20
  lda ENEMY+$1c
  sta ENEMY+$1e
  sep #$20
  lda #$0f
  sta INTERCEPT_SOUND
  sec
  rts
