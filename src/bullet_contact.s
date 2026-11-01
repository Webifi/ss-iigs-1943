; An enemy bullet against the players (US arcade $6133-$61D7) and the
; energy gauge (US arcade $063C-$069C). The caller checked the update and
; the field.
.a8
.i16
BULLET_HALF = 8              ; the bullet's centre is this far right of its cross

; bullet_contact: the bullet D hits player 2, else player 1, when it touches
; a player who can collide. BULLET_HIT_SOUND: the sound of the hit, or 0.
; JSR.
bullet_contact:
  stz BULLET_HIT_SOUND
  lda z:OBJ_FLAGS
  and #OF_CONTACT
  bne @players
  rts
@players:
  ldx #PLAYER_SIZE
  jsr bullet_try_player
  bcs @done
  ldx #0
  jsr bullet_try_player
@done:
  rts

; bullet_try_player: the bullet against the player X: returns carry 1 on a
; hit. The wing planes take a hit first (WINGS_ON: they flash; damaged:
; they explode); else the player loses energy (OBJ_HP rotated 3 bits left,
; as the arcade), and at 0 the player dies. Each hit starts the hit roll.
bullet_try_player:
  lda PLAYER+PL_COLLIDE,x
  bne :+
  clc
  rts
:
  lda PLAYER+SPR_ALONG,x
  sec
  sbc z:SPR_ALONG
  bcs @y_abs
  eor #$ff
  inc
@y_abs:
  sta a:CONTACT_DISTANCE
  lda z:OBJ_ALONG_RADIUS
  clc
  adc PLAYER+PL_ALONG_RADIUS,x
  cmp a:CONTACT_DISTANCE
  bcc @miss
  lda z:SPR_CROSS
  clc
  adc #BULLET_HALF
  sec
  sbc PLAYER+PL_BODY2+SPR_CROSS,x ; the centre of the plane
  bcs @x_abs
  eor #$ff
  inc
@x_abs:
  sta a:CONTACT_DISTANCE
  lda z:OBJ_CROSS_RADIUS
  clc
  adc PLAYER+PL_CROSS_RADIUS,x
  cmp a:CONTACT_DISTANCE
  bcc @miss
  lda PLAYER+PL_WINGS,x
  and #WINGS_ON
  beq @damage
  lda PLAYER+PL_WINGS,x
  cmp #WINGS_ON
  beq @first_dodge
  lda #WINGS_EXPLODE
  bra @dodge
@first_dodge:
  lda #WINGS_DAMAGED
@dodge:
  sta PLAYER+PL_WINGS,x
  lda #1
  sta PLAYER+PL_HIT,x
  jmp bullet_contact_hit
@miss:
  clc
  rts
@damage:
  lda z:OBJ_HP
  .repeat 3
    asl
    bcc :+
    ora #1
:
  .endrepeat
  sta a:CONTACT_DISTANCE
  lda PLAYER+PL_ENERGY,x
  sec
  sbc a:CONTACT_DISTANCE
  sta PLAYER+PL_ENERGY,x
  lda #1
  sta PLAYER+PL_HIT,x
  lda #SND_BULLET_STRIKE
  bcs @sound
  stz PLAYER+PL_ENERGY,x
  lda #PS_DEATH
  sta PLAYER+PL_STATE,x
  lda #SND_PLAYER_DOWN
@sound:
  sta BULLET_HIT_SOUND
  jsr energy_hud_update
; bullet_contact_hit: the bullet ends: no HP, no flags, and its next step
; is the impact path (OBJ_PREDECESSOR). Returns carry 1.
bullet_contact_hit:
.a8
  stz z:OBJ_HP
  stz z:OBJ_FLAGS
  stz z:OBJ_DURATION
  a16
  lda z:OBJ_PREDECESSOR
  sta z:OBJ_MOTION
  a8
  sec
  rts

; energy_hud_update: the energy of the player X stays within ENERGY_MAX;
; the gauge row of that player gets the ENERGY_TILES of its energy (one tile
; for each 8 of ENERGY_MAX) and the cell colours. JSR; X kept.
energy_hud_update:
  lda ENERGY_MAX
  cmp PLAYER+PL_ENERGY,x
  bcs @capped
  sta PLAYER+PL_ENERGY,x
@capped:
  ldy #0
  lda PLAYER+PL_NUMBER,x
  beq @hud_player
  ldy #ENERGY_HUD_ROW
@hud_player:
  sty a:HUD_OFFSET
  ; Each arcade energy cap is a multiple of 8, at most 112.
  lda ENERGY_MAX
  lsr
  lsr
  lsr
  sta a:HUD_TILES
  phx
  a16
  lda PLAYER+PL_ENERGY,x
  and #255
  asl
  tax
  lda f:ENERGY_OFFSETS,x
  tax
  a8
@tile:
  lda f:ENERGY_TILES,x
  sta ENERGY_HUD,y
  inx
  iny
  dec a:HUD_TILES
  bne @tile
  a16
  lda a:HUD_OFFSET
  clc
  adc #ENERGY_HUD_CELLS
  tay
  ; The colours of the ENERGY_HUD_CELLS cells, two at a time: 2 cells of
  ; colour 0, 2 of colour 2, 10 of colour 4. The interrupt does not read
  ; ENERGY_HUD.
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
  lda #$0004                    ; A and carry as the arcade leaves them
  sec
  a8
  plx
  rts
.assert ENERGY_HUD_CELLS = 14, error ; seven word stores
