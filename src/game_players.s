; game_players_tick: one update of each player (PLAYER_CURSOR = the record
; offset, FLIGHT_INPUT = its input), by PL_STATE: the continue wait, the
; death, the entry, the dive, the landing and takeoff, the loop, or the live
; flight with the wing planes, the weapon time, the special and the guns;
; then the colour. JSR; A8, X16.
.a8
.i16

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
  sta FLIGHT_INPUT
  lda PLAYER+PL_STATE,x
  bne @active
  lda CAB_DEMO
  bne @no_wait               ; the arcade demo has no continue prompt
  jsl native_player_wait
@no_wait:
  jmp @next
@active:
  cmp #PS_DEATH
  bne @alive
  txa
  sta DEATH_PLAYER
  jsr player_death
  lda DEATH_DEMO_END
  bne :+
  jmp @next
:
  jsl cabinet_demo_finish
  jmp @done
@alive:
  cmp #PS_RESPAWN
  bne :+
  jsl native_player_entry
  jmp @palette
:
  cmp #PS_DIVE
  bne :+
  jsl native_player_dive
  jmp @palette
:
  cmp #PS_LANDING
  bcc @normal_mode
  jsl native_player_presentation ; PS_LANDING, PS_TAKEOFF
  jmp @palette
@other_live_state:
  cmp #PS_LOOP
  beq :+
  jmp @next                     ; PS_LEAVE: game_depart_players moves it
:
  jsl special_loop_tick
  jmp @palette
@normal_mode:
  cmp #PS_LIVE
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
  jsl game_sound_request         ; wing planes, bank 1 $8874/$8A50
:
  ldy PLAYER_CURSOR
  jsl weapon_timer
  ; Button 2 (pressed is 0) starts a special when the gate is open.
  lda FLIGHT_INPUT
  and #INPUT_SPECIAL
  bne @special_released
  ldx PLAYER_CURSOR
  lda PLAYER+PL_WEAPON_GATE,x
  and #GATE_OPEN
  beq @ordinary_fire
  jsl special_button
  jmp @palette
@special_released:
  ldx PLAYER_CURSOR
  lda PLAYER+PL_WEAPON_GATE,x
  ora #GATE_RELEASED
  sta PLAYER+PL_WEAPON_GATE,x
@ordinary_fire:
  ; Button 1 fires; released, the cadence starts again.
  lda FLIGHT_INPUT
  and #INPUT_FIRE
  bne @release
  ldy PLAYER_CURSOR
  jsl weapon_change
  ldy PLAYER_CURSOR
  jsl weapon_fire
  lda GUN_SOUND
  beq @palette
  jsl game_sound_request
  jmp @palette
@release:
  ldx PLAYER_CURSOR
  lda #CADENCE_START
  sta PLAYER+PL_CADENCE,x
  stz PLAYER+PL_BURST,x
@palette:
  jsl player_live_palette
@next:
  lda PLAYER_CURSOR
  bne @done
  lda #PLAYER_SIZE
  sta PLAYER_CURSOR
  jmp @player
@done:
  stz PLAYER_CURSOR
  lda INPUT_P1
  sta FLIGHT_INPUT
  rts

; special_tick_trampoline: special_install_tick patches special_tick_site
; (flight_weapons) to JSR here during a special attack and its quiet time:
; the special runs, then A = CAB_RESULT_ACTIVE as the LDA there would load.
special_tick_trampoline:
  jsl special_tick
  lda CAB_RESULT_ACTIVE
  rts
