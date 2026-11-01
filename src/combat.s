; combat_init: the enemy combat state (COMBAT_STATE to COMBAT_STATE_END) is
; cleared at each game start (wave_combat_init). JSR; A8, X16.
.a8
.i16

combat_init:
  a16
  ldx #COMBAT_STATE_END-COMBAT_STATE-2
@clear:
  stz COMBAT_STATE,x
  dex
  dex
  bpl @clear
  a8
  rts
.assert (COMBAT_STATE_END-COMBAT_STATE) .mod 2 = 0, error
