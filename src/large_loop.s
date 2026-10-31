; Native owner for the twelve four-piece enemy records. Controllers and
; contacts use the live records directly; only object pixels cross to Oak.
.a8
.i16
LARGE_SLOT = $1c4c
LARGE_PENDING_ACTION = $1c4e
LARGE_PENDING_OWNER = $1c50
LARGE_PENDING_PATTERN = $1c52

large_loop_init:
  rep #$20
  ldx #1534
@clear:
  stz LARGE_POOL,x
  dex
  dex
  bpl @clear
  ldx #46
@groups:
  stz LARGE_GROUPS,x
  dex
  dex
  bpl @groups
  stz LARGE_TOTAL
  stz LARGE_SLOT
  stz LARGE_PENDING_ACTION
  stz LARGE_PENDING_OWNER
  stz LARGE_PENDING_PATTERN
  sep #$20
.ifdef GIANT_ENEMIES
  stz SHIP_FINISH_ACTIVE
  stz SHIP_FINISH_WAIT
.endif
.ifdef BANK6_TURRETS
  stz TURRET_GROUP
  stz TURRET_RETRY
.endif
  rtl

large_loop_tick:
  lda CAMERA+$17
  sta LARGE_CAM_X
  lda CAMERA+$18
  sta LARGE_CAM_Y
  stz LARGE_MODE
  rep #$20
  stz LARGE_SLOT
@slot:
  ldx LARGE_SLOT
  sep #$20
  lda LARGE_POOL+8,x
  bne :+
  jmp .loword(@next)
:
  cmp #$40
  bne :+
.ifndef GIANT_ENEMIES
  ; Giant controllers have their own eight/sixteen-piece record contract.
  lda #$e8
  sta f:$050301
  jmp .loword(@next)
.endif
:
  rep #$20
  txa
  clc
  adc #LARGE_POOL
  sta LARGE_RECORD
  sep #$20
@script:
.ifdef GIANT_ENEMIES
  ldx LARGE_SLOT
  lda LARGE_POOL+8,x
  cmp #$40
  bne @ordinary_tick
  jsl giant_object_tick
  bra @ticked
@ordinary_tick:
.endif
  jsl large_object_tick
.ifdef GIANT_ENEMIES
@ticked:
.endif
  lda LARGE_KIND
  bne :+
  jmp .loword(@contact)
:
  cmp #1
  bne :+
  jmp .loword(@next)
:
  ; Fixed callbacks are shared; dispatch banked controllers by their bank.
  rep #$20
  lda LARGE_CALLBACK
  cmp #$8000
  bcc @call_ai
  ldx LARGE_SLOT
  lda LARGE_POOL+10,x
  and #$70
  beq @call_ai
  cmp #$40
  beq @call_ai
.ifdef BANK6_TURRETS
  cmp #$60
  beq @call_ai
.endif
  sep #$20
  bra @unknown
@call_ai:
  sep #$20
.ifdef BANK6_TURRETS
  lda INPUT_P1
  sta TURRET_INPUT
  lda #255
  sta TURRET_INPUT+1
.endif
  jsl large_ai
  bcs @known
@unknown:
  lda #$e7
  sta f:$050301
  jmp .loword(@next)
@known:
.ifdef BANK6_TURRETS
  lda TURRET_FIRE
  beq :+
  jsl turret_bullet_spawn
  cpx #BULLET_SCRATCH
  beq :+
  inc BULLET_SPAWNS
:
.endif
  lda LARGE_AI_SOUND
  beq :+
  sta PLAYER_EVENT_SOUND
:
 .ifdef SHIP_ENEMIES
  lda LARGE_AI_X
  sta SHIP_REQUEST+1
  lda LARGE_AI_Y
  sta SHIP_REQUEST+2
  lda LARGE_AI_FIRE
  beq :+
  sta SHIP_REQUEST
  jsl ship_launch
:
  lda LARGE_AI_ACTION
  and #8
  beq :+
  jsl ship_secondary_ready
:
  lda LARGE_AI_ACTION
  and #32
  beq :+
  jsl large_bullet_far
:
 .ifdef CONTINUOUS_GAME
  lda LARGE_AI_ACTION
  and #64
  beq :+
  jsl game_large_spread_far
:
 .endif
 .else
  lda LARGE_AI_FIRE
  beq :+
  sta LARGE_PENDING_PATTERN
:
 .endif
  lda LARGE_AI_ACTION
  pha
 .ifdef SHIP_ENEMIES
  and #7
 .else
  and #$ef
 .endif
  beq @no_outer_action
  ora LARGE_PENDING_ACTION
  sta LARGE_PENDING_ACTION
  rep #$20
  lda LARGE_RECORD
  sta LARGE_PENDING_OWNER
  sep #$20
@no_outer_action:
.a8
  pla
  and #16
  beq @selected
  jsl large_common_kill
  bra @next
@selected:
  rep #$20
  lda LARGE_AI_NEXT
  sec
  sbc #7
  ldx LARGE_SLOT
  sta LARGE_POOL+$1e,x
  sep #$20
  jmp .loword(@script)
@contact:
  jsr .loword(large_loop_contacts)
@next:
  rep #$20
  lda LARGE_SLOT
  clc
  adc #128
  sta LARGE_SLOT
  cmp #1536
  beq @done
  jmp .loword(@slot)
@done:
  sep #$20
.ifdef GIANT_ENEMIES
  lda LARGE_PENDING_ACTION
  and #2
  beq :+
  stz SHIP_FINISH_ACTIVE
:
  lda LARGE_PENDING_ACTION
  and #4
  beq @looping_finish
  lda #2
  jsl ship_finish_begin
  bra @finish_tick
@looping_finish:
  lda LARGE_PENDING_ACTION
  and #1
  beq @finish_tick
  jsl ship_finish_begin
@finish_tick:
  stz LARGE_PENDING_ACTION
  jsl ship_finish_tick
.endif
  rtl

large_loop_contacts:
.ifdef GIANT_ENEMIES
  ldx LARGE_SLOT
  lda LARGE_POOL+8,x
  cmp #$40
  bne @ordinary_phase
  lda LARGE_POOL+9,x
  beq @done
  lda COMBAT_PHASE
  and #1
  beq @done                    ; arcade $642C checks giants on odd ticks
  bra @phase_ready
@ordinary_phase:
.endif
  lda COMBAT_PHASE
  and #1
  bne @done                    ; arcade $5C8C checks ordinary objects on even ticks
.ifdef GIANT_ENEMIES
@phase_ready:
.endif
  ldx LARGE_SLOT
  lda LARGE_POOL+9,x
  beq @done
  lda LARGE_POOL+1,x
  ora LARGE_POOL+$41,x
  and #16
  bne @done
  lda PLAYER+8
  cmp #2
  beq :+
  lda PLAYER+$88
  cmp #2
  bne @done
:
  jsl large_shot_contact
  lda CONTACT_SOUND
  beq :+
  sta PLAYER_EVENT_SOUND
:
  lda CONTACT_ACTION
  bne @kill
  ldx LARGE_SLOT
  lda LARGE_POOL+9,x
  and #1
  beq @done
  ldx #0
  jsl large_body_contact
  lda CONTACT_ACTION
  bne @body
  ldx #128
  jsl large_body_contact
  lda CONTACT_ACTION
  beq @done
@body:
  lda CONTACT_SOUND
  beq @kill
  sta PLAYER_EVENT_SOUND
@kill:
  jsl large_common_kill
@done:
  rts

large_common_kill:
  ldx LARGE_SLOT
  lda LARGE_POOL+9,x
  and #4
  sta LARGE_POOL+9,x
  stz LARGE_POOL+4,x
  rep #$20
  lda LARGE_POOL+$1c,x
  sta LARGE_POOL+$1e,x
  lda LARGE_POOL+$0f,x
  and #255
  tay
  sep #$20
  beq @award
  lda LARGE_TOTAL
  clc
  adc LARGE_GROUPS,y
  sta LARGE_TOTAL
  lda #0
  sta LARGE_GROUPS,y
@award:
  lda LARGE_POOL+$0e,x
  beq @done
  sta SCORE_OWNER
  lda LARGE_POOL+$17,x
  sta SCORE_AWARD_INDEX
  jsl large_score_far
@done:
  rtl
