; Original-US $6133-$61D7 and energy HUD $063C-$069C.
; Caller has selected a visible active bullet on its collision phase.
.a8
.i16
.ifndef ENEMY
ENEMY = $1100
.endif
.ifndef PLAYER
PLAYER = $1000
.endif
CONTACT_CONTEXT = $11d0
ENERGY_HUD = $1e00

bullet_contact:
  stz CONTACT_CONTEXT+1
  stz CONTACT_CONTEXT+2
  lda ENEMY+9
  and #1
  bne @players
  rts
@players:
  ldx #128
  jsr bullet_try_player
  bcs @done
  ldx #0
  jsr bullet_try_player
@done:
  rts

bullet_try_player:
  ; No collision can be delivered to an inactive player.
  lda PLAYER+7,x
  bne :+
  clc
  rts
:
  lda PLAYER+3,x
  sec
  sbc ENEMY+3
  bcs @y_abs
  eor #255
  inc
@y_abs:
  sta $d0
  lda ENEMY+$0d
  clc
  adc PLAYER+$11,x
  cmp $d0
  bcc @miss
  lda ENEMY+2
  clc
  adc #8
  sec
  sbc PLAYER+$22,x
  bcs @x_abs
  eor #255
  inc
@x_abs:
  sta $d0
  lda ENEMY+$0c
  clc
  adc PLAYER+$10,x
  cmp $d0
  bcc @miss
  lda PLAYER+4,x
  and #1
  beq @damage
  lda PLAYER+4,x
  cmp #1
  beq @first_dodge
  lda #8
  bra @dodge
@first_dodge:
  lda #3
@dodge:
  sta PLAYER+4,x
  lda #1
  sta PLAYER+$0e,x
  jmp bullet_contact_hit
@miss:
  clc
  rts
@damage:
  lda ENEMY+$0b
  .repeat 3
    asl
    bcc :+
    ora #1
:
  .endrepeat
  sta $d0
  lda PLAYER+6,x
  sec
  sbc $d0
  sta PLAYER+6,x
  lda #1
  sta PLAYER+$0e,x
  lda #2
  bcs @sound
  stz PLAYER+6,x
  lda #4
  sta PLAYER+8,x
  lda #5
@sound:
  sta CONTACT_CONTEXT+1
  jsr energy_hud_update
bullet_contact_hit:
.a8
  txa
  beq @p1
  lda #2
  bra @hit
@p1:
  lda #1
@hit:
  sta CONTACT_CONTEXT+2
  stz ENEMY+$0b
  stz ENEMY+9
  stz ENEMY+4
  rep #$20
  lda ENEMY+$1c
  sta ENEMY+$1e
  sep #$20
  sec
  rts

energy_hud_update:
  lda CONTACT_CONTEXT
  cmp PLAYER+6,x
  bcs @capped
  sta PLAYER+6,x
@capped:
  ldy #0
  lda PLAYER+5,x
  beq @hud_player
  ldy #28
@hud_player:
  sty $dc
  ; All original energy caps are multiples of eight, at most 112.
  lda CONTACT_CONTEXT
  lsr
  lsr
  lsr
  sta $da
  phx
  rep #$20
  lda PLAYER+6,x
  and #255
  asl
  tax
  lda f:ENERGY_OFFSETS,x
  tax
  sep #$20
@tile:
  lda f:ENERGY_TILES,x
  sta ENERGY_HUD,y
  inx
  iny
  dec $da
  bne @tile
  rep #$20
  lda $dc
  clc
  adc #14
  tay
  ; Seven word stores replace the fourteen-byte color loop. The HUD is
  ; consumed after this routine; interrupts do not inspect its partial row.
  lda #$0000
  sta ENERGY_HUD,y
  iny
  iny
  lda #$0202
  sta ENERGY_HUD,y
  iny
  iny
  lda #$0404
  .repeat 5
    sta ENERGY_HUD,y
    iny
    iny
  .endrepeat
  lda #$0004                 ; preserve the original accumulator high byte
  sec                         ; original final CPX leaves carry set
  sep #$20
  plx
  rts
