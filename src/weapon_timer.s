; US $1762-$1818 native timer and exact character state. Live drawing sends
; selector/time to card-owned tables.
.a8
.i16
WEAPON_HUD = $1e40
weapon_timer:
  phd
  rep #$20
  tya
  clc
  adc #PLAYER
  tcd
  sep #$20
  lda $51
  beq @done
  inc $58
  lda $58
  cmp #60
  bcc @hud
  stz $58
  lda $57
  cmp #255
  beq @hud
  sec
  sbc #1
  sta $57
  bcs @hud
  stz $51
  stz $58
.ifndef WEAPON_TIMER_STATE_ONLY
  jsr .loword(weapon_hud_owner)
  lda #$24
  ldy #14
@clear:
  sta WEAPON_HUD,x
  stz WEAPON_HUD+14,x
  inx
  dey
  bne @clear
.endif
  bra @done
@hud:
.ifndef WEAPON_TIMER_STATE_ONLY
  jsr .loword(weapon_hud_draw)
.endif
@done:
  pld
.ifdef WEAPON_TIMER_FAR
  rtl
.else
  rts
.endif
.ifndef WEAPON_TIMER_STATE_ONLY
weapon_hud_owner:
  ldx #0
  lda $05
  beq :+
  ldx #28
:
  rts
weapon_hud_draw:
  jsr .loword(weapon_hud_owner)
  phx
  lda $57
  rep #$20
  and #255
  asl
  tay
  sep #$20
  lda weapon_timer_digits,y
  sta WEAPON_HUD+11,x
  lda weapon_timer_digits+1,y
  sta WEAPON_HUD+12,x
  lda #7
  sta WEAPON_HUD+25,x
  sta WEAPON_HUD+26,x
  lda $51
  rep #$20
  and #31
  asl
  tay
  lda weapon_name_offsets,y
  tay
  sep #$20
  lda weapon_names,y
  inx
  sta WEAPON_HUD+14,x
  pha
  iny
  .repeat 8,I
    lda weapon_names+I,y
    sta WEAPON_HUD+I,x
  .endrepeat
  pla
  .repeat 8,I
    sta WEAPON_HUD+14+I,x
  .endrepeat
  plx
  rts
.endif
