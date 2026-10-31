; One native controller selects each player's live record. No record copying.
.a8
.i16
PLAYER_CURSOR = $14e0

game_players_tick:
  stz PLAYER_CURSOR
  stz PLAYER_CURSOR+1
@player:
  ldx PLAYER_CURSOR
  lda INPUT_P1
  cpx #0
  beq :+
  lda INPUT_P2
:
  sta $40
  lda PLAYER+8,x
  bne @active
  lda CAB_DEMO
  bne @no_wait               ; the arcade demo has no continue prompt
  jsl native_player_wait
@no_wait:
  jmp @next
@active:
  cmp #4
  bne @alive
  txa
  sta DEATH_CONTEXT
  jsr player_death
  lda DEATH_CONTEXT+6
  bne :+
  jmp @next
:
  jsl cabinet_demo_finish
  jmp @done
@alive:
  cmp #6
  bne :+
  jsl native_player_entry
  jmp @palette
:
  cmp #8
  bne :+
  jsl native_player_dive
  jmp @palette
:
  cmp #14
  bcc @normal_mode
  jsl native_player_presentation
  jmp @palette
@other_live_state:
  cmp #10
  beq :+
  jmp @next
:
  jsl special_loop_tick
  jmp @palette
@normal_mode:
  cmp #2
  bne @other_live_state
  jsl player_live_before
  jsr flight_step
  jsl player_live_after
  lda COMBAT_PHASE
  sta PLAYER_AUX_PHASE
  ldy PLAYER_CURSOR
  jsl player_aux
  lda PLAYER_AUX_SOUND
  beq :+
  sta PLAYER_EVENT_SOUND
:
  ldy PLAYER_CURSOR
  jsl weapon_timer
  lda $40
  and #$20
  bne @special_released
  ldx PLAYER_CURSOR
  lda PLAYER+$55,x
  and #15
  beq @ordinary_fire
  jsl special_button
  jmp @palette
@special_released:
  ldx PLAYER_CURSOR
  lda PLAYER+$55,x
  ora #3
  sta PLAYER+$55,x
@ordinary_fire:
  lda $40
  and #$10
  bne @release
  ldy PLAYER_CURSOR
  jsl weapon_change
  ldy PLAYER_CURSOR
  jsl weapon_fire
  lda GUN_SOUND
  beq @palette
  jsr doc_play_weapon
  lda GUN_SOUND
  jsr doc_weapon_control
  jmp @palette
@release:
  ldx PLAYER_CURSOR
  lda #$f8
  sta PLAYER+$54,x
  stz PLAYER+$56,x
@palette:
  jsl player_live_palette
@next:
  lda PLAYER_CURSOR
  bne @done
  lda #128
  sta PLAYER_CURSOR
  jmp @player
@done:
  stz PLAYER_CURSOR
  lda INPUT_P1
  sta $40
  rts

; Idle executes the original LDA directly. The attack installs this same-bank
; trampoline only for the special and its 200-tick suppression interval.
special_tick_trampoline:
  jsl special_tick
  lda CAB_RESULT_ACTIVE
  rts
