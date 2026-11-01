; The wing planes and the firing pose of a player: the wing planes arrive,
; fly beside the player, flash when damaged, leave, or explode; the body and
; the wings show the firing sprites after a shot.
; A port of the US arcade code at bank 1 $87A1-$8981 and $89B0-$89EB.
; D points at the player record during the call. PLAYER_AUX_SOUND returns
; a sound request (0 none).
.a8
.i16
; Wing arrival, departure and explosion in ANIM_WORK of each wing sprite.
WING_TIME = ANIM_WORK+1      ; updates left of this wing step
WING_STEP = ANIM_WORK+2      ; the next wing step
WING_CROSS = ANIM_WORK+3     ; departure: the cross move of this step
WING_ALONG = ANIM_WORK+4     ; departure: the along move of this step
; The wing sprites beside the body (the body's left half is at SPR_CROSS).
WING_LEFT_CROSS = 16         ; the left wing: this far to the left of the body
WING_SPAN = 48               ; the right wing: this far to the right of the left wing
WING_CODE = $2a              ; the wing sprite code of bank pose 0
WING_ARRIVE_CODE = $2c       ; the wing sprite code while it arrives
WING_ARRIVE_SPEED = 6        ; along pixels of each update while it arrives
WING_FLASH_ATTR = 9          ; SPR_ATTR of a damaged wing on its flash updates
WING_EXPLODE_STEPS = 10      ; the last step of player_wing_explosion
WING_RIGHT_TABLE = 20        ; player_wing_left + this: the right wing's steps
WING_OFF_CROSS = $f0         ; a leaving wing is gone past this cross
; PL_CROSS_RADIUS: the collision half-width of the player.
RADIUS_BODY = 7
RADIUS_LEAVING = 10
RADIUS_WINGS = $14
; The firing pose: each body and wing code has a firing code FIRING_CODE above.
FIRING_CODE = 16
FIRING_FIRST = $2f           ; body codes from here are firing codes

; player_aux: one update of the wing planes and the firing pose of player Y
; (0 or PLAYER_SIZE) (game_players_tick). A, X, Y: changed.
player_aux:
  phd
  a16
  tya
  clc
  adc #PLAYER
  tcd
  a8
  stz PLAYER_AUX_SOUND
  jsr .loword(player_wing_step)
  jsr .loword(player_firing_pose)
  pld
  rtl

; player_wing_step: run the wing state of PL_WINGS.
player_wing_step:
  lda PL_WINGS
  and #WINGS_STATE
  cmp #WINGS_EXPLODE
  bne :+
  jmp .loword(player_wing_explode)
:
  cmp #WINGS_LEAVING
  bne :+
  jmp .loword(player_wing_depart)
:
  cmp #WINGS_COMING
  bne :+
  jmp .loword(player_wing_arrive)
:
  ; No wings (hidden), or wings on: they follow the body.
  and #WINGS_ON
  beq @hidden
  lda SPR_ALONG
  bra @vertical
@hidden:
  lda #SPR_HIDDEN
@vertical:
  sta PL_LEFT_WING+SPR_ALONG
  sta PL_RIGHT_WING+SPR_ALONG
  ; The colour of the body, or the flash colour for damaged wings on 1 of
  ; 4 updates.
  lda SPR_ATTR
  pha
  lda PL_WINGS
  cmp #WINGS_DAMAGED
  bne @normal_color
  lda PLAYER_AUX_PHASE
  and #3
  beq @normal_color
  pla
  lda #WING_FLASH_ATTR
  bra @color
@normal_color:
  pla
@color:
  sta PL_LEFT_WING+SPR_ATTR
  sta PL_RIGHT_WING+SPR_ATTR
  lda SPR_CROSS
  sec
  sbc #WING_LEFT_CROSS
  sta PL_LEFT_WING+SPR_CROSS
  clc
  adc #WING_SPAN
  sta PL_RIGHT_WING+SPR_CROSS
  lda PL_POSE                   ; the wings bank with the body
  clc
  adc #WING_CODE
  sta PL_LEFT_WING+SPR_CODE
  sta PL_RIGHT_WING+SPR_CODE
  rts

; player_wing_explode: the wing explosion. player_wing_explosion holds
; (updates, sprite code) pairs; 255 or WING_EXPLODE_STEPS steps end it, and
; the player has no wings.
player_wing_explode:
  lda #RADIUS_BODY
  sta PL_CROSS_RADIUS
  lda PL_LEFT_WING+WING_TIME
  bne @wait
  lda PL_LEFT_WING+WING_STEP
  asl                           ; two bytes for each step
  a16
  and #255
  tax
  a8
  lda player_wing_explosion,x
  cmp #255
  beq @done
  sta PL_LEFT_WING+WING_TIME
  lda player_wing_explosion+1,x
  sta PL_LEFT_WING+SPR_CODE
  sta PL_RIGHT_WING+SPR_CODE
  inc PL_LEFT_WING+WING_STEP
  lda PL_LEFT_WING+WING_STEP
  cmp #WING_EXPLODE_STEPS
  bcs @done
@wait:
  dec PL_LEFT_WING+WING_TIME
  rts
@done:
  stz PL_LEFT_WING+WING_TIME
  stz PL_LEFT_WING+WING_STEP
  stz PL_WINGS
  rts

; player_wing_arrive: the wings fly up from below to the body. When they
; reach it, PL_WINGS takes its high nibble with WINGS_ON set, the collision
; width grows and the wing sound plays.
player_wing_arrive:
  lda PL_LEFT_WING+SPR_ALONG
  sec
  sbc #WING_ARRIVE_SPEED
  cmp SPR_ALONG
  bcs @position
  lda PL_WINGS
  lsr
  lsr
  lsr
  lsr
  ora #WINGS_ON
  sta PL_WINGS
  lda #RADIUS_WINGS
  sta PL_CROSS_RADIUS
  lda #SND_WINGS
  sta PLAYER_AUX_SOUND
  lda SPR_ALONG
@position:
  sta PL_LEFT_WING+SPR_ALONG
  sta PL_RIGHT_WING+SPR_ALONG
  lda #WING_ARRIVE_CODE
  sta PL_LEFT_WING+SPR_CODE
  sta PL_RIGHT_WING+SPR_CODE
  lda SPR_CROSS
  sec
  sbc #WING_LEFT_CROSS
  sta PL_LEFT_WING+SPR_CROSS
  clc
  adc #WING_SPAN
  sta PL_RIGHT_WING+SPR_CROSS
  rts

; player_wing_depart: each wing flies off on its own path. When both are off
; the field, PL_WINGS keeps only its high nibble (no wings).
player_wing_depart:
  lda #RADIUS_LEAVING
  sta PL_CROSS_RADIUS
  ldy #PL_LEFT_WING
  lda PL_LEFT_WING+SPR_ALONG
  cmp #SPR_HIDDEN
  beq @right
  jsr .loword(player_wing_depart_one)
@right:
  ldy #PL_RIGHT_WING
  lda PL_RIGHT_WING+SPR_ALONG
  cmp #SPR_HIDDEN
  bne @moving
  lda PL_LEFT_WING+SPR_ALONG
  cmp #SPR_HIDDEN
  bne @done
  lda PL_WINGS
  and #<~WINGS_STATE
  sta PL_WINGS
@done:
  rts
@moving:
  jmp .loword(player_wing_depart_one)

; player_wing_depart_one: one step of the wing at D+Y (PL_LEFT_WING or
; PL_RIGHT_WING). player_wing_left holds 4-byte steps (sprite code, cross
; move, along move, updates); the right wing's steps follow at
; WING_RIGHT_TABLE. The left wing moves left, the right wing right.
player_wing_depart_one:
  ; The 65816 has no direct-page,Y addressing for these; X holds the offset.
  tyx
  lda WING_TIME,x
  bne @move
  lda WING_STEP,x
  asl
  asl                           ; four bytes for each step
  a16
  and #255
  pha
  tya
  cmp #PL_LEFT_WING
  beq :+
  pla
  clc
  adc #WING_RIGHT_TABLE
  bra @table
:
  pla
@table:
  tay
  a8
  lda player_wing_left,y
  sta SPR_CODE,x
  lda player_wing_left+1,y
  sta WING_CROSS,x
  lda player_wing_left+2,y
  sta WING_ALONG,x
  lda player_wing_left+3,y
  sta WING_TIME,x
  inc WING_STEP,x
@move:
  cpx #PL_LEFT_WING
  bne @rightward
  lda SPR_CROSS,x
  sec
  sbc WING_CROSS,x
  bra @x
@rightward:
  lda SPR_CROSS,x
  clc
  adc WING_CROSS,x
@x:
  cmp #WING_OFF_CROSS
  bcs @off
  sta SPR_CROSS,x
  lda SPR_ALONG,x
  clc
  adc WING_ALONG,x
  bcs @off                      ; past the top of the field
  sta SPR_ALONG,x
  dec WING_TIME,x
  rts
@off:
  lda #SPR_HIDDEN
  sta SPR_ALONG,x
  stz ANIM_WORK,x
  stz WING_TIME,x
  stz WING_STEP,x
  stz WING_CROSS,x
  stz WING_ALONG,x
  rts

; player_firing_pose: for PL_FIRING updates after a shot, the body (and the
; wings that fly) show their firing codes; then the normal codes again.
player_firing_pose:
  lda PL_FIRING
  beq @unlit
  dec PL_FIRING
  lda PL_WINGS
  and #WINGS_ON
  beq @body
  lda PL_LEFT_WING+SPR_CODE
  beq @body
  clc
  adc #FIRING_CODE
  sta PL_LEFT_WING+SPR_CODE
  sta PL_RIGHT_WING+SPR_CODE
@body:
  lda SPR_CODE
  cmp #FIRING_FIRST
  bcs @done                     ; already the firing code
  clc
  adc #FIRING_CODE
  bra @store
@unlit:
  lda SPR_CODE
  cmp #FIRING_FIRST
  bcc @done                     ; already the normal code
  sec
  sbc #FIRING_CODE
@store:
  sta SPR_CODE
  inc
  sta PL_BODY2+SPR_CODE
@done:
  rts
