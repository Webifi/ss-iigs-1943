; contact_init: a new game (wave_combat_init): the energy gauges are blank,
; the energy cap is ENERGY_START, and the gauge of player 1 is drawn. JSR.
.a8
.i16
ENERGY_START = 64            ; ENERGY_MAX at a game start

contact_init:
  a16
  ldx #2*ENERGY_HUD_ROW-2
@hud:
  stz ENERGY_HUD,x
  dex
  dex
  bpl @hud
  a8
  lda #ENERGY_START
  sta ENERGY_MAX
  ldx #0
  jsr energy_hud_update
  rts
