.include "profile.inc"
; Native enemy-bullet pool. Movement records are build data shared with the
; enemy decoder; no original opcode is interpreted.
.a8
.i16
BULLET_SLOT = $11d4
BULLET_SPAWNS = $11d6
BULLET_RETIREMENTS = $11d7
BULLET_MAX_ACTIVE = $11d8

bullet_init:
  rep #$20
  ldx #510
@clear:
  stz BULLETS,x
  dex
  dex
  bpl @clear
  stz BULLET_CONTEXT
  lda #16
  sta BULLET_CONTEXT+2
  stz BULLET_SLOT
  stz BULLET_SPAWNS
  stz BULLET_MAX_ACTIVE
  sep #$20
  rts

bullet_tick:
  rep #$20
  stz BULLET_SLOT
  stz $e8
.ifdef POOL_MOTION
  stz $ec
.endif
@slot:
  ldx BULLET_SLOT
  sep #$20
  lda BULLETS+8,x
  bne @active
  jmp @next
@active:
  inc $e8
.ifdef POOL_MOTION
  lda BULLETS+4,x
  beq @copied
.if FLIGHT_CONTACT
  lda COMBAT_PHASE
  and #1
  bne @copied
.endif
  stx $ee
  inc $ec
  stz ENEMY_SCRIPT_KIND
  rep #$20
  stz ENEMY_CALLBACK
  sep #$20
  routine_call bullet_motion_pool, 24
  lda ENEMY_RETIRED
  beq :+
  inc BULLET_RETIREMENTS
:
  jmp @next
@copied:
  stz $ec
.endif
  rep #$20
  .repeat 16,I
    lda BULLETS+I*2,x
    sta ENEMY+I*2
  .endrepeat
  sep #$20
@script:
  routine_call enemy_script, 20
  lda ENEMY_SCRIPT_KIND
  beq @move
  cmp #1
.ifdef ROUTINE_PROFILE
  bne :+
  jmp @retired
:
.else
  beq @retired
.endif
 .ifdef EXTENDED_STAGE_ENEMIES
  rep #$20
  lda ENEMY_CALLBACK
  sta AI_CONTEXT+2
  sep #$20
  jsr ground_bullet_ai
  bcc @unknown_callback
  rep #$20
  lda AI_NEXT
  sec
  sbc #7
  sta ENEMY+$1e
  sep #$20
  jmp @script
@unknown_callback:
 .endif
  ; Unsupported callback remains an explicit error.
  lda #$e8
  sta f:$050301
.ifdef ROUTINE_PROFILE
  jmp @save
.else
  bra @save
.endif
@move:
  routine_call bullet_motion, 24
  lda ENEMY_RETIRED
  bne @retired
.if FLIGHT_CONTACT
  lda COMBAT_PHASE
  and #1
  beq @save
  lda ENEMY+1
  and #16
  bne @save
 .if FLIGHT_PLAYER_AUX
  jsr bullet_intercept
  bcc @body_contact
  lda INTERCEPT_SOUND
  sta PLAYER_EVENT_SOUND
  bra @save
@body_contact:
 .endif
  routine_call bullet_contact, 25
  lda CONTACT_CONTEXT+2
  beq @save
  inc CONTACT_HITS
  lda CONTACT_CONTEXT+1
  sta CONTACT_LAST_SOUND
  cmp #2
  bne :+
  routine_call doc_play_player_hurt, 28
  bra @save
:
  cmp #5
  bne @save
  inc CONTACT_DEATH_REQUESTS
.if FLIGHT_DEATH
  jsr doc_play_player_death
.endif
.endif
  bra @save
@retired:
  inc BULLET_RETIREMENTS
@save:
  rep #$20
  ldx BULLET_SLOT
  .repeat 16,I
    lda ENEMY+I*2
    sta BULLETS+I*2,x
  .endrepeat
@next:
  rep #$20
  lda BULLET_SLOT
  clc
  adc #32
  sta BULLET_SLOT
  cmp #512
  beq @done
  sep #$20
  jmp @slot
@done:
.ifdef POOL_MOTION
  lda $ec
  beq :+
  ldx $ee
  .repeat 16,I
    lda BULLETS+I*2,x
    sta ENEMY+I*2
  .endrepeat
:
.endif
  sep #$20
  lda $e8
  cmp BULLET_MAX_ACTIVE
  bcc :+
  sta BULLET_MAX_ACTIVE
:
  rts
