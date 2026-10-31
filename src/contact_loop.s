; Connect the verified bullet contact/energy routines to the live component.
; Player death-state progression and special-weapon interception remain ports.
.a8
.i16
CONTACT_HITS = $11da
CONTACT_LAST_SOUND = $11db
CONTACT_DEATH_REQUESTS = $11dc

contact_init:
  rep #$20
  ldx #54
@hud:
  lda contact_initial_hud,x
  sta ENERGY_HUD,x
  dex
  dex
  bpl @hud
  stz CONTACT_HITS
  stz CONTACT_DEATH_REQUESTS
  sep #$20
  lda #64
  sta CONTACT_CONTEXT
  ldx #0
  jsr energy_hud_update
  rts

contact_hud:
  rep #$20
  ldx #0
  ldy #0
@tile:
  lda ENERGY_HUD,x
  and #255
  sta $d0
  phx
  lda energy_character_offsets,y
  tax
  lda $d0
  sta $1600,x
  plx
  iny
  iny
  inx
  cpx #8
  bne @tile
  sep #$20
  rts
