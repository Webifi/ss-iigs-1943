; The pickups: an object drop in the first free small-object slot (US arcade
; $59D9-$5A1B), the change of a bonus pickup into the next one ($768D-$76C4),
; and the jumps of the laser pickup. Each copies a whole template record once
; when the object starts.
.a8
.i16
PICKUP_CHANCE = 8            ; PICKUP_KIND: drop only 1 time in 16 (random stream 6)
DROP_CROSS_MIN = $10         ; a drop starts inside DROP_CROSS_MIN..DROP_CROSS_MAX
DROP_CROSS_MAX = $e0
CHANGE_DROP = 4              ; a changed pickup starts this far further along
LASER_PICKUP_MOVES = 16      ; the laser pickup jumps this often, then leaves

; pickup_spawn: drop the pickup PICKUP_KIND (1-8: pickup_templates entry
; PICKUP_KIND-1) at PICKUP_X, PICKUP_Y in the first free ENEMY_POOL slot.
; No free slot: no drop. JSL; A, X, Y: changed.
pickup_spawn:
  lda PICKUP_KIND
  cmp #PICKUP_CHANCE
  bne @select
  lda RANDOM_STATE+6            ; random stream 6, step $99
  pha
  clc
  adc #$99
  sta RANDOM_STATE+6
  pla
  and #15
  beq @select
  rtl
@select:
  ; Y = the template.
  a16
  lda PICKUP_KIND
  and #255
  dec
  .repeat 5
    asl                         ; times OBJECT_SIZE
  .endrepeat
  tay
  ldx #0
  a8
@find:
  lda ENEMY_POOL+OBJ_TYPE,x
  beq @found
  a16
  txa
  clc
  adc #OBJECT_SIZE
  tax
  a8
  cpx #ENEMY_COUNT*OBJECT_SIZE
  bne @find
  rtl
@found:
  stx PICKUP_SLOT
  ; Copy the template; DBR = this bank, where pickup_templates is.
  a16
  phb
  phk
  plb
  .repeat OBJECT_SIZE/2,I
    lda .loword(pickup_templates)+I*2,y
    sta f:ENEMY_POOL+I*2,x
  .endrepeat
  plb
  a8
  ldx PICKUP_SLOT
  lda PICKUP_X
  cmp #DROP_CROSS_MIN
  bcs :+
  lda #DROP_CROSS_MIN
:
  cmp #DROP_CROSS_MAX
  bcc :+
  lda #DROP_CROSS_MAX
:
  sta ENEMY_POOL+SPR_CROSS,x
  lda PICKUP_Y
  sta ENEMY_POOL+SPR_ALONG,x
  ; Every pickup except PV_ENERGY can touch the player and follows the camera.
  lda ENEMY_POOL+OBJ_VARIANT,x
  and #VARIANT_BITS
  cmp #PV_ENERGY
  beq @done
  lda #OF_CONTACT|OF_CAMERA
  sta ENEMY_POOL+OBJ_FLAGS,x
@done:
  rtl

; The object bytes and motion of the pickups below. D = the object record,
; as in the enemy decision dispatch.
BONUS_KIND = $10             ; pickup_change: the pickup_change_templates entry
LASER_MOVES = $11            ; pickup_laser: the jumps done
MOTION_LASER_PICKUP = $72c3  ; fixed bank: the motion of the laser pickup

; pickup_change: the bonus pickup becomes the next one: copy the next
; pickup_change_templates entry over the record at the same place, a little
; further along. Past the end of the field it retires. JSL.
pickup_change:
  lda SPR_CROSS
  sta PICKUP_X
  lda SPR_ALONG
  sta PICKUP_Y
  lda BONUS_KIND
  inc
  sta PICKUP_CHANGE_INDEX
  a16
  lda BONUS_KIND
  and #255
  .repeat 5
    asl                         ; times OBJECT_SIZE
  .endrepeat
  tay
  phb
  phk
  plb
  .repeat OBJECT_SIZE/2,I
    lda .loword(pickup_change_templates)+I*2,y
    sta z:I*2
  .endrepeat
  plb
  a8
  lda PICKUP_X
  sta SPR_CROSS
  lda PICKUP_CHANGE_INDEX
  sta BONUS_KIND
  lda PICKUP_Y
  clc
  adc #CHANGE_DROP
  bcc @inside
  stz SPR_CODE                  ; past the field: retire
  stz OBJ_TYPE
  stz SPR_CROSS
  lda #1
  sta ENEMY_RETIRED
  rtl
@inside:
  sta SPR_ALONG
  a16
  lda OBJ_MOTION
  clc
  adc #STEP_SIZE                ; the step after the code tail
  sta AI_NEXT
  a8
  rtl

; pickup_laser: the laser pickup jumps across to one of 16 places
; (pickup_laser_positions, random stream 5) for LASER_PICKUP_MOVES jumps,
; then it leaves as a teleport bonus. JSL; returns AI_NEXT.
pickup_laser:
  lda LASER_MOVES
  inc
  cmp #LASER_PICKUP_MOVES
  beq @end
  sta LASER_MOVES
  lda RANDOM_STATE+5            ; random stream 5, step $77
  pha
  clc
  adc #$77
  sta RANDOM_STATE+5
  pla
  and #15
  asl                           ; word entries
  a16
  and #255
  tax
  lda f:pickup_laser_positions,x
  sta SPR_CROSS                 ; with SPR_ALONG
  lda #MOTION_LASER_PICKUP
  bra @next
@end:
  a16
  lda #MOTION_TELEPORT_BONUS
@next:
  sta AI_NEXT
  a8
  rtl
.assert OBJECT_SIZE = 32, error ; the five ASLs above
