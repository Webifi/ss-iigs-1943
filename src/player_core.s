; Per-tick player rules around the flight (US arcade code): the collision
; and special gates before the flight, the energy drain after it, and the
; colour of the player's sprites. The far entries point D at the player in
; PLAYER_CURSOR; the live_* routines expect D = the player record. A8, X16.
.a8
.i16

; player_live_before, player_live_after, player_live_palette: JSL entries
; for game_players_tick. They keep D.
player_live_before:
  phd
  a16
  lda PLAYER_CURSOR
  clc
  adc #PLAYER
  tcd
  a8
  jsr .loword(live_player_live_before)
  pld
  rtl
player_live_after:
  phd
  a16
  lda PLAYER_CURSOR
  clc
  adc #PLAYER
  tcd
  a8
  jsr .loword(live_player_live_after)
  pld
  rtl
player_live_palette:
  phd
  a16
  lda PLAYER_CURSOR
  clc
  adc #PLAYER
  tcd
  a8
  jsr .loword(live_player_live_palette)
  pld
  rtl

; live_player_live_before: after a respawn the player cannot collide for
; PL_IMMUNE ticks. The special gate opens again each tick, unless
; PLAYER_SPECIAL_LOCK holds it closed.
live_player_live_before:
  lda z:PL_IMMUNE
  beq @vulnerable
  dec z:PL_IMMUNE
  stz z:PL_COLLIDE
  bra @weapon
@vulnerable:
  lda #1
  sta z:PL_COLLIDE
@weapon:
  lda PLAYER_SPECIAL_LOCK
  beq @ordinary
  lda #GATE_USED
  sta z:PL_WEAPON_GATE
  rts
@ordinary:
  lda z:PL_WEAPON_GATE
  ora #GATE_READY
  sta z:PL_WEAPON_GATE
  rts

; live_player_live_after: every DRAIN_TICKS ticks the player loses one
; energy, and the energy gauge tile of that cell changes (arcade $8982):
; cell energy/8 of the player's ENERGY_HUD row shows ENERGY_GLYPH + energy&7.
live_player_live_after:
  lda z:PL_DRAIN
  cmp #DRAIN_TICKS
  bne @done
  stz z:PL_DRAIN
  lda z:PL_ENERGY
  beq @done
  dec z:PL_ENERGY
  lda z:PL_ENERGY
  and #7
  clc
  adc #ENERGY_GLYPH
  pha
  lda z:PL_ENERGY
  lsr
  lsr
  lsr
  a16
  and #255
  tax
  a8
  pla
  pha
  lda z:PL_NUMBER
  beq :+
  a16
  txa
  clc
  adc #ENERGY_HUD_ROW           ; the row of player 2
  tax
  a8
:
  pla
  sta ENERGY_HUD,x
@done:
  rts

; live_player_live_palette: the colour of the player: palette 0 for P1, 2 for
; P2 (arcade $1912-$1945). The arcade also flips the palette to spin the
; propellers; the card spins them with two DAC entries (scripts/propellers.py),
; so the colour stays on the even palette of the pair. Damaged wings keep the
; flash colour of player_aux.
live_player_live_palette:
  lda z:PL_NUMBER
  asl
  sta PLAYER_PALETTE
  lda z:SPR_ATTR
  and #<~SPR_COLOUR
  ora PLAYER_PALETTE
  sta z:SPR_ATTR
  lda z:PL_BODY2+SPR_ATTR
  and #<~SPR_COLOUR
  ora PLAYER_PALETTE
  sta z:PL_BODY2+SPR_ATTR
  lda z:PL_WINGS
  cmp #WINGS_DAMAGED
  beq @done
  lda z:PL_LEFT_WING+SPR_ATTR
  and #<~SPR_COLOUR
  ora PLAYER_PALETTE
  sta z:PL_LEFT_WING+SPR_ATTR
  lda z:PL_RIGHT_WING+SPR_ATTR
  and #<~SPR_COLOUR
  ora PLAYER_PALETTE
  sta z:PL_RIGHT_WING+SPR_ATTR
@done:
  rts
