; death_loop_init: a new game (wave_combat_init): no shadow sprites; a death
; leads to the continue (DEATH_PLAYING), not the end of the demo. JSR.
.a8
.i16
death_loop_init:
  a16
  ldx #4*SPRITE_SIZE-2
@clear_shadow:
  stz PLAYER_SHADOW,x
  dex
  dex
  bpl @clear_shadow
  a8
  lda #1
  sta DEATH_PLAYING
  stz DEATH_DEMO_END
  rts
