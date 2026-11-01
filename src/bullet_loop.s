; The enemy bullets (BULLETS, BULLET_COUNT records): each update runs the
; motion script of each bullet (the same step records as the enemies), its
; move, and on odd updates its contacts: a SHOT GUN shot can stop it
; (bullet_intercept), or it hits a player (bullet_contact).
.a8
.i16

; bullet_init: no bullet; all BULLET_COUNT slots in use. JSR.
bullet_init:
  a16
  ldx #BULLET_COUNT*OBJECT_SIZE-2
@clear:
  stz BULLETS,x
  dex
  dex
  bpl @clear
  stz BULLET_ANGLE             ; and BULLET_SUPPRESS
  lda #BULLET_COUNT
  sta BULLET_SLOTS              ; and BULLET_SPEED = 0
  stz BULLET_SLOT
  a8
  rts

; bullet_tick: one update of the enemy bullets (flight_weapons). JSR; D = 0
; after it.
bullet_tick:
  a16
  stz BULLET_SLOT
  a8
  ; INTERCEPT_WEAPON: a SHOT GUN of either player can stop bullets.
  lda PLAYER+PL_WEAPON
  ora PLAYER2+PL_WEAPON
  and #WEAPON_SHOTGUN
  sta a:INTERCEPT_WEAPON
  a16
@slot:
  ldx BULLET_SLOT
  a8
  lda BULLETS+OBJ_TYPE,x
  bne @active
  jmp @next_zero
@active:
  ; D = the bullet record (POOL_RECORD) while it runs.
  a16
  txa
  clc
  adc #BULLETS
  sta POOL_RECORD
  tcd
  a8
@script:
  lda z:OBJ_DURATION
  bne @move
@script_decode:
  jsr enemy_script
  lda ENEMY_SCRIPT_KIND
  beq @move                     ; SCRIPT_MOVE
  cmp #SCRIPT_RETIRE
  bne :+
  jmp @retired
:
  a16
  lda ENEMY_CALLBACK
  sta AI_TAIL
  a8
  jsl ground_bullet_ai
  bcc @save
  a16
  lda AI_NEXT
  sec
  sbc #STEP_SIZE                ; the script reads OBJ_MOTION + STEP_SIZE
  sta z:OBJ_MOTION
  a8
  jmp @script
@move:
  jsr bullet_motion
  lda ENEMY_RETIRED
  bne @retired
  lda COMBAT_PHASE
  and #1
  beq @save                     ; even update: no bullet contacts
  lda z:SPR_ATTR
  and #SPR_ALONG_HIGH
  bne @save                     ; off the field
  ; Without the shot flag and a SHOT GUN no shot can stop the bullet.
  lda z:OBJ_FLAGS
  and #OF_SHOT
  ora a:INTERCEPT_WEAPON
  bne :+
  stz INTERCEPT_SOUND
  ; The original miss leaves Y at the upper player-slot boundary.
  ldy #SHOTS_PER_PLAYER*SHOT_SIZE
  lda PLAYER2+PL_STATE
  cmp #PS_LIVE
  bne @body_contact
  ldy #SHOT_COUNT*SHOT_SIZE
  bra @body_contact
:
  jsr bullet_intercept
  bcc @body_contact
  lda INTERCEPT_SOUND
  jsl game_sound_request        ; arcade $612D
  bra @save
@body_contact:
  jsr bullet_contact
  lda BULLET_HIT_SOUND          ; SND_BULLET_STRIKE or SND_PLAYER_DOWN, or 0
  beq @save
  jsl game_sound_request
@retired:
@save:
@next_zero:
  a16
  lda BULLET_SLOT
  clc
  adc #OBJECT_SIZE
  sta BULLET_SLOT
  cmp #BULLET_COUNT*OBJECT_SIZE
  beq @done
  a8
  jmp @slot
@done:
  a16
.a16
  ; D still identifies the last live record; zero means no record selected.
  ; On an empty pass leave X at the last slot, as the original loop did.
  tdc
  beq :+
  tax
  lda #0
  tcd
:
  a8
  stz INTERCEPT_WEAPON
  rts
