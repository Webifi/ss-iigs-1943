; The death of a player (US arcade bank 1 $8B46-$8C2B, $8305-$8385 and
; $19DF-$19EF): the plane explodes frame by frame; then the continue
; countdown starts (DEATH_PLAYING), or the demo ends (DEATH_DEMO_END). The
; shadow sprites follow the plane of their owner.
.a8
.i16
SHADOW_OWNER = 5              ; PL_NUMBER of the player that owns the shadows
DEATH_TIME = ANIM_WORK+1       ; updates left of this death frame
DEATH_FRAME = ANIM_WORK+2      ; the player_death_frames offset of the next frame
; player_death_frames: DEATH_FRAME_SIZE entries (the updates, the sprite code
; of the body); DEATH_END ends the list.
DEATH_FRAME_SIZE = 2
DEATH_END = 255
DEATH_DROP = 4                 ; the explosion is this much further along
CONTINUE_COUNT = $0b           ; PL_COUNTDOWN: the countdown shows 10 first
; The shadow (PLAYER_SHADOW: four pieces as a plane) is SHADOW_CROSS to the
; right of the plane and SHADOW_ALONG above it. Hidden, it is below the field.
SHADOW_COLOUR = $0e
SHADOW_CROSS = 16
SHADOW_ALONG = 18
SHADOW_HIDDEN = $e0            ; SPR_ALONG with SPR_ALONG_HIGH: below the field

; player_death: one update of the death of the player DEATH_PLAYER
; (game_players_tick). The first frame puts the four pieces around the body.
; JSL end; A8, X16.

player_death:
  stz DEATH_DEMO_END
  a16
  lda DEATH_PLAYER
  and #PLAYER_SIZE              ; the record of player 1 or 2
  tax
  a8
  stz PLAYER+PL_WEAPON_GATE,x
  stz PLAYER+PL_COLLIDE,x
  stz PLAYER+PL_WINGS,x
  lda PLAYER+DEATH_TIME,x
  bne @delay
  lda PLAYER+DEATH_FRAME,x
  bne @next_frame
  stz PLAYER+SPR_ATTR,x
  stz PLAYER+PL_BODY2+SPR_ATTR,x
  stz PLAYER+PL_LEFT_WING+SPR_ATTR,x
  stz PLAYER+PL_RIGHT_WING+SPR_ATTR,x
  lda PLAYER+SPR_CROSS,x
  sta PLAYER+PL_LEFT_WING+SPR_CROSS,x
  clc
  adc #BODY2_CROSS
  sta PLAYER+PL_BODY2+SPR_CROSS,x
  sta PLAYER+PL_RIGHT_WING+SPR_CROSS,x
  lda PLAYER+SPR_ALONG,x
  clc
  adc #DEATH_DROP
  sta PLAYER+SPR_ALONG,x
  sta PLAYER+PL_BODY2+SPR_ALONG,x
  sec
  sbc #PIECE_RISE
  sta PLAYER+PL_LEFT_WING+SPR_ALONG,x
  sta PLAYER+PL_RIGHT_WING+SPR_ALONG,x
@next_frame:
  a16
  lda PLAYER+DEATH_FRAME,x
  and #255
  tay
  a8
  inc PLAYER+DEATH_FRAME,x
  inc PLAYER+DEATH_FRAME,x      ; DEATH_FRAME_SIZE
  lda player_death_frames,y
  cmp #DEATH_END
  beq @finished
  sta PLAYER+DEATH_TIME,x
  lda player_death_frames+1,y
  sta PLAYER+SPR_CODE,x
  inc
  sta PLAYER+PL_BODY2+SPR_CODE,x
  clc
  adc #CODE_ROW-1               ; the upper pieces
  sta PLAYER+PL_LEFT_WING+SPR_CODE,x
  inc
  sta PLAYER+PL_RIGHT_WING+SPR_CODE,x
@delay:
  dec PLAYER+DEATH_TIME,x
  jmp player_shadow_death
@finished:
  ; The explosion ends: the demo ends, or the continue countdown starts.
  lda DEATH_PLAYING
  bne @playing
  lda #1
  sta DEATH_DEMO_END
  rts
@playing:
  lda #CONTINUE_COUNT
  sta PLAYER+PL_COUNTDOWN,x
  stz PLAYER+PL_STATE,x
  .repeat ANIM_WORK_SIZE,i
    stz PLAYER+ANIM_WORK+i,x
    stz PLAYER+PL_LEFT_WING+ANIM_WORK+i,x
    stz PLAYER+PL_RIGHT_WING+ANIM_WORK+i,x
  .endrepeat
  ; The arcade leaves the ANIM_WORK of the second piece ($3B-$3F) as it is.
  jsl native_player_respawn_position
; player_shadow_death: the shadow of the player X, when that player owns it:
; at the plane, or hidden when PL_SHADOW is 0.
player_shadow_death:
  lda PLAYER_SHADOW+SHADOW_OWNER
  cmp PLAYER+PL_NUMBER,x
  beq @owner
  rts
@owner:
  lda PLAYER+PL_SHADOW,x
  bne @visible
  lda PLAYER_SHADOW+SPR_ATTR
  ora #SPR_ALONG_HIGH|SHADOW_COLOUR
  sta PLAYER_SHADOW+SPR_ATTR
  sta PLAYER_SHADOW+SPRITE_SIZE+SPR_ATTR
  sta PLAYER_SHADOW+2*SPRITE_SIZE+SPR_ATTR
  sta PLAYER_SHADOW+3*SPRITE_SIZE+SPR_ATTR
  lda #SHADOW_HIDDEN
  sta PLAYER_SHADOW+SPR_ALONG
  sta PLAYER_SHADOW+SPRITE_SIZE+SPR_ALONG
  lda #SHADOW_HIDDEN-PIECE_RISE
  sta PLAYER_SHADOW+2*SPRITE_SIZE+SPR_ALONG
  sta PLAYER_SHADOW+3*SPRITE_SIZE+SPR_ALONG
  rts
@visible:
  lda #SHADOW_COLOUR
  sta PLAYER_SHADOW+SPR_ATTR
  sta PLAYER_SHADOW+SPRITE_SIZE+SPR_ATTR
  sta PLAYER_SHADOW+2*SPRITE_SIZE+SPR_ATTR
  sta PLAYER_SHADOW+3*SPRITE_SIZE+SPR_ATTR
  .repeat 4,i
    lda PLAYER+i*SPRITE_SIZE+SPR_CODE,x
    sta PLAYER_SHADOW+i*SPRITE_SIZE+SPR_CODE
  .endrepeat
  lda PLAYER+SPR_CROSS,x
  clc
  adc #SHADOW_CROSS
  sta PLAYER_SHADOW+SPR_CROSS
  sta PLAYER_SHADOW+2*SPRITE_SIZE+SPR_CROSS
  clc
  adc #BODY2_CROSS
  sta PLAYER_SHADOW+SPRITE_SIZE+SPR_CROSS
  sta PLAYER_SHADOW+3*SPRITE_SIZE+SPR_CROSS
  lda PLAYER+SPR_ALONG,x
  sec
  sbc #SHADOW_ALONG
  sta PLAYER_SHADOW+SPR_ALONG
  sta PLAYER_SHADOW+SPRITE_SIZE+SPR_ALONG
  sec
  sbc #PIECE_RISE
  sta PLAYER_SHADOW+2*SPRITE_SIZE+SPR_ALONG
  sta PLAYER_SHADOW+3*SPRITE_SIZE+SPR_ALONG
  rts
.assert PLAYER_SIZE = $80 .and BODY2_CROSS = 16 .and PIECE_RISE = 16, error
