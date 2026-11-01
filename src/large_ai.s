; The decisions of the large objects (four sprite records): the code tails of
; their motion scripts (LARGE_CALLBACK) run here as native code. They cover
; the ship cores (US arcade bank 4 $8654-$872F), the core turrets, the shared
; explosion ($5E94), the deck aircraft and the other large planes and giants
; (src/game_enemies.s). The results are outputs, not arcade scheduler calls:
; LARGE_AI_NEXT (the next motion record), LARGE_AI_ACTION (LA_* bits),
; LARGE_AI_SOUND, LARGE_AI_X/Y (a secondary explosion or bullet place),
; LARGE_AI_FIRE (a turret pattern + 1) and TURRET_FIRE. src/large_loop.s acts
; on them.

; Motion code tails of the four-piece objects (LARGE_CALLBACK). The bank of
; a tail from ARCADE_BANK_WINDOW on comes from OBJ_VARIANT.
TAIL_AIMING_TURRET = $804b
TAIL_AIMING_TURRET_2 = $81c7
TAIL_AIMING_TURRET_3 = $8343
TAIL_AIMING_TURRET_4 = $84b7
TAIL_GIANT_EXPLOSION = $6626
TAIL_LARGE_PLANE_BEGIN = $b366
TAIL_LARGE_PLANE_WRAP = $b370
TAIL_LARGE_PLANE_WAIT = $b3ef
TAIL_LARGE_PLANE_ENABLE = $b425
TAIL_LARGE_PLANE_AIM = $b458
TAIL_LARGE_PLANE_FIRE = $b4d5
TAIL_CORE_TURRET = $8084
TAIL_LARGE_EXPLOSION = $5e94
TAIL_LAUNCH_DECK_TICK = $48e7
TAIL_LAUNCH_CREW_SOUND = $49bf
TAIL_QUAD_TICK = $aba5
TAIL_QUAD_FIRE = $ac55
TAIL_QUAD_ENABLE = $ac76
TAIL_OPEN_AIRCRAFT = $a8fc
TAIL_WEAVE_AIRCRAFT = $aa49
TAIL_WEAVE_PAUSE = $aa83
TAIL_FALL_WAIT = $aee3
TAIL_FALL_FIRE = $aefb
TAIL_FALL_ENABLE = $af09
TAIL_FALL_TAIL = $af14
TAIL_LARGE_BURST = $5f1e
TAIL_LARGE_BURST_LOOP = $5f67
TAIL_LARGE_BURST_LOOP_2 = $5fa8
TAIL_CARRIER_DESTROY = $a6e8
TAIL_SWAY_AIRCRAFT = $b094
TAIL_TURNING_AIRCRAFT = $b089
TAIL_RAID_GIANT = $a0c3
TAIL_CARRIER_DESTROY_2 = $a434
TAIL_CARRIER_GIANT = $a4bf
TAIL_LAND_QUAD = $b68d
TAIL_LAND_QUAD_2 = $b813
TAIL_LAND_QUAD_3 = $8972
TAIL_TRIPLE_QUAD = $861e
TAIL_GIANT_APPROACH = $9bee
TAIL_GIANT_OPEN = $9bff
TAIL_GIANT_READY = $9c10
TAIL_GIANT_TICK = $9c74
TAIL_GIANT_HIT = $9f1e
TAIL_GIANT_REOPEN = $9f48

; Fixed-bank explosion motions that show the scoring player.
MOTION_LARGE_EXPLOSION = $5ea9
MOTION_LARGE_EXPLOSION_P2 = $5ee2
MOTION_GIANT_OWNER_EXPLOSION = $663b
MOTION_GIANT_OWNER_EXPLOSION_P2 = $6674

CORE_TURRET_STEPS = 6        ; ship_turret: the steps of one turret cycle
CORE_TURRET_BURST = 4        ; ship_turret: the shots of one cycle
; The family bytes of the deck aircraft record.
DECK_TIME = $10              ; launch_deck_tick: decisions left of this step
DECK_STEP = $11              ; launch_deck_tick: the next launch_deck_delays entry
.a8
.i16
.include "boss_core_data.inc"

; large_ai: run the code tail LARGE_CALLBACK of the object at LARGE_RECORD.
; Returns carry 1 with LARGE_AI_NEXT, or carry 0 for an unknown tail. JSL.
large_ai:
  phd
  a16
  lda LARGE_RECORD
  tcd
  stz LARGE_AI_NEXT
  a8
  stz LARGE_AI_ACTION
  stz LARGE_AI_SOUND
  stz LARGE_AI_X
  stz LARGE_AI_Y
  stz LARGE_AI_FIRE
  stz TURRET_FIRE
  a16
  lda LARGE_CALLBACK
  cmp #TAIL_AIMING_TURRET
  beq @aiming_turret
  cmp #TAIL_AIMING_TURRET_2
  beq @aiming_turret
  cmp #TAIL_AIMING_TURRET_3
  beq @aiming_turret
  cmp #TAIL_AIMING_TURRET_4
  bne :+
@aiming_turret:
  jmp .loword(ship_aiming_turret)
:
  cmp #TAIL_GIANT_EXPLOSION
  bne :+
  jmp .loword(giant_explosion_select)
:
  cmp #TAIL_BULLET_HIT_SOUND
  bne :+
  a8
  lda #SND_BULLET_HIT
  sta LARGE_AI_SOUND
  a16
  lda LARGE_SOURCE
  clc
  adc #STEP_TAIL_SIZE           ; the step after the code tail
  jmp .loword(large_ai_selected)
:
.a16
  cmp #TAIL_LARGE_PLANE_BEGIN
  bne :+
  jmp .loword(large_plane_begin)
:
  cmp #TAIL_LARGE_PLANE_WRAP
  bne :+
  jmp .loword(large_plane_wrap)
:
  cmp #TAIL_LARGE_PLANE_WAIT
  bne :+
  jmp .loword(large_plane_wait)
:
  cmp #TAIL_LARGE_PLANE_ENABLE
  bne :+
  jmp .loword(large_plane_enable)
:
  cmp #TAIL_LARGE_PLANE_AIM
  bne :+
  jmp .loword(large_plane_aim)
:
  cmp #TAIL_LARGE_PLANE_FIRE
  bne :+
  jmp .loword(large_plane_fire)
:
  cmp #TAIL_CORE_TURRET
  bne :+
  jmp .loword(ship_turret)
:
  cmp #TAIL_LARGE_EXPLOSION
  bne :+
  jmp .loword(large_explosion_select)
:
  ; game_dispatch TAIL, ROUTINE: jump to ROUTINE for this code tail.
  .macro game_dispatch id, target
    cmp #id
    bne :+
    jmp .loword(target)
:
  .endmacro
  game_dispatch TAIL_LAUNCH_DECK_TICK, launch_deck_tick
  game_dispatch TAIL_LAUNCH_CREW_SOUND, launch_crew_sound
  game_dispatch TAIL_QUAD_TICK, game_quad_tick
  game_dispatch TAIL_QUAD_FIRE, game_quad_fire
  game_dispatch TAIL_QUAD_ENABLE, game_quad_enable
  game_dispatch TAIL_OPEN_AIRCRAFT, game_open_aircraft
  game_dispatch TAIL_WEAVE_AIRCRAFT, game_weave_aircraft
  game_dispatch TAIL_WEAVE_PAUSE, game_weave_pause
  game_dispatch TAIL_FALL_WAIT, game_fall_wait
  game_dispatch TAIL_FALL_FIRE, game_fall_fire
  game_dispatch TAIL_FALL_ENABLE, game_fall_enable
  game_dispatch TAIL_FALL_TAIL, game_fall_tail
  game_dispatch TAIL_LARGE_BURST, game_large_burst
  game_dispatch TAIL_LARGE_BURST_LOOP, game_large_burst_loop
  game_dispatch TAIL_LARGE_BURST_LOOP_2, game_large_burst_loop
  game_dispatch TAIL_CARRIER_DESTROY, game_carrier_destroy
  game_dispatch TAIL_SWAY_AIRCRAFT, game_sway_aircraft
  game_dispatch TAIL_TURNING_AIRCRAFT, game_turning_aircraft
  game_dispatch TAIL_RAID_GIANT, game_raid_giant
  game_dispatch TAIL_CARRIER_DESTROY_2, game_carrier_destroy
  game_dispatch TAIL_CARRIER_GIANT, game_carrier_giant
  game_dispatch TAIL_LAND_QUAD, game_land_quad
  game_dispatch TAIL_LAND_QUAD_2, game_land_quad
  game_dispatch TAIL_LAND_QUAD_3, game_land_quad
  game_dispatch TAIL_TRIPLE_QUAD, game_triple_quad
  game_dispatch TAIL_GIANT_APPROACH, game_giant_approach
  game_dispatch TAIL_GIANT_OPEN, game_giant_open
  game_dispatch TAIL_GIANT_READY, game_giant_ready
  game_dispatch TAIL_GIANT_TICK, game_giant_tick
  game_dispatch TAIL_GIANT_HIT, game_giant_hit
  game_dispatch TAIL_GIANT_REOPEN, game_giant_reopen
  .delmacro game_dispatch
  ; A ship core tail: boss_core_lookup gives its phase routine.
  jsr .loword(boss_core_lookup)
  bcc @unknown
  tax
  jmp (.loword(boss_core_vectors),x)
@unknown:
  a8
  pld
  clc
  rtl
; large_ai_selected: return A = the next motion record (LARGE_AI_NEXT), carry 1.
large_ai_selected:
.a16
  sta LARGE_AI_NEXT
  a8
  pld
  sec
  rtl

; large_explosion_select, giant_explosion_select: the explosion that shows
; the scoring player (OBJ_OWNER 2: player 2). The owner is used up.
large_explosion_select:
.a16
  a8
  lda OBJ_OWNER
  stz OBJ_OWNER
  cmp #2
  bne @ordinary
  a16
  lda #MOTION_LARGE_EXPLOSION_P2
  bra large_ai_selected

@ordinary:
  a16
  lda #MOTION_LARGE_EXPLOSION
  bra large_ai_selected

giant_explosion_select:
.a16
  a8
  lda OBJ_OWNER
  stz OBJ_OWNER
  cmp #2
  bne @ordinary
  a16
  lda #MOTION_GIANT_OWNER_EXPLOSION_P2
  jmp .loword(large_ai_selected)
@ordinary:
  a16
  lda #MOTION_GIANT_OWNER_EXPLOSION
  jmp .loword(large_ai_selected)

; The ship core phases (boss_core_vectors). BOSS_CONFIG = the core's
; boss_core_configs entry (BC_* fields).
; ship_core_alive: the core waits on its path. When STAGE_CORE_ARMED is set
; and the core is on the field, the damage total decides: at LARGE_THRESHOLD
; the core dies; else it takes shots on random ticks (random stream 0).
ship_core_alive:
.a16
  ldx BOSS_CONFIG
  lda f:boss_core_configs+BC_ALIVE,x
  sta LARGE_AI_NEXT
  a8
  lda STAGE_CORE_ARMED
  beq @done
  lda SPR_ATTR
  and #SPR_ALONG_HIGH
  bne @done
  lda LARGE_TOTAL
  cmp LARGE_THRESHOLD
  bne :+
  jmp .loword(ship_core_died)
:
  lda #OF_CAMERA
  sta OBJ_FLAGS
  lda RANDOM_STATE              ; random stream 0, step $77
  lsr
  bcc :+
  lda #OF_CAMERA|OF_SHOT
  sta OBJ_FLAGS
:
  lda RANDOM_STATE
  clc
  adc #$77
  sta RANDOM_STATE
@done:
  a16
  lda LARGE_AI_NEXT
  jmp .loword(large_ai_selected)

; ship_core_died: the core is destroyed. The turrets fall and score for the
; core's owner, the camera pan stops, and the players loop. Near the top of
; the field (SPR_ALONG >= BC_NEAR) the ship explodes now; else the camera
; goes back (HOLD_BACK) and the looping ship finish starts.
ship_core_died:
.a8
  a8
  lda OBJ_OWNER
  sta STAGE_CORE_OWNER
  lda #1
  sta STAGE_TURRETS_FALL
  sta STAGE_CORE_DOWN
  stz CAMERA_PAN_ON
  stz CAMERA_PAN_TIME
  stz CAMERA_PAN_DELTA
  stz CAMERA_PAN_HOLD
  a16
  stz CAMERA_PAN_OFFSET
  a8
  lda LARGE_THRESHOLD
  sta LARGE_TOTAL
  lda SPR_ALONG
  ldx BOSS_CONFIG
  cmp f:boss_core_configs+BC_NEAR,x
  bcs ship_core_explode
  ldx BOSS_CONFIG
  lda f:boss_core_configs+BC_PATTERN,x
  sta STAGE_BLAST_PATTERN
  a16
  lda LARGE_RECORD
  sta STAGE_BLAST_SOURCE
  a8
  lda #LA_FINISH_LOOP           ; = HOLD_BACK
  sta LARGE_AI_ACTION
  sta CAMERA_HOLD
  stz CAMERA_BG1_DIVISOR
  lda PLAYER+PL_STATE
  cmp #PS_LIVE
  bne :+
  lda #PS_LOOP
  sta PLAYER+PL_STATE
:
  lda PLAYER2+PL_STATE
  cmp #PS_LIVE
  bne :+
  lda #PS_LOOP
  sta PLAYER2+PL_STATE
:
  a16
  ldx BOSS_CONFIG
  lda f:boss_core_configs+BC_DYING,x
  jmp .loword(large_ai_selected)
.assert LA_FINISH_LOOP = HOLD_BACK, error

; ship_core_wait: the dead core moves until it reaches BC_FAR, then the ship
; explodes.
ship_core_wait:
.a16
  a8
  lda SPR_ALONG
  ldx BOSS_CONFIG
  cmp f:boss_core_configs+BC_FAR,x
  bcs ship_core_explode
  a16
  ldx BOSS_CONFIG
  lda f:boss_core_configs+BC_DYING,x
  jmp .loword(large_ai_selected)
; ship_core_explode: the ship explosion: the camera holds, the sound plays,
; and a secondary explosion starts above the core when it is on the field.
ship_core_explode:
.a8
  lda #HOLD_STILL
  sta CAMERA_HOLD
  lda #1
  sta CAMERA_BG1_DIVISOR
  lda #SND_SHIP_EXPLODE
  sta LARGE_AI_SOUND
  lda SPR_ALONG
  sec
  sbc #PIECE_RISE
  bcc @next
  sta LARGE_AI_Y
  lda SPR_CROSS
  clc
  adc #SPRITE_HALF
  sta LARGE_AI_X
  lda LARGE_AI_ACTION
  ora #LA_EXPLOSION
  sta LARGE_AI_ACTION
  ; The arcade ($832E) steps E009 (random stream 1) even when no explosion
  ; slot is free.
  lda RANDOM_STATE+1
  clc
  adc #$77
  sta RANDOM_STATE+1
@next:
  a16
  ldx BOSS_CONFIG
  lda f:boss_core_configs+BC_EXPLODE,x
  jmp .loword(large_ai_selected)
; ship_core_finish: the ship finish of this core (BC_PATTERN, BC_ACTION).
ship_core_finish:
.a16
  lda LARGE_RECORD
  sta STAGE_BLAST_SOURCE
  a8
  ldx BOSS_CONFIG
  lda f:boss_core_configs+BC_PATTERN,x
  sta STAGE_BLAST_PATTERN
  lda f:boss_core_configs+BC_ACTION,x
  sta LARGE_AI_ACTION
  a16
  ldx BOSS_CONFIG
  lda f:boss_core_configs+BC_FINISH,x
  jmp .loword(large_ai_selected)

; ship_turret: a turret beside a core. When the core falls (STAGE_TURRETS_FALL)
; the turret dies and scores for the core's owner. Else it counts
; CORE_TURRET_STEPS steps and fires at step 0, CORE_TURRET_BURST times in a
; cycle, while it is on the field: LARGE_AI_FIRE = its pattern + 1.
ship_turret:
.a16
  a8
  lda STAGE_TURRETS_FALL
  beq @alive
  lda STAGE_CORE_OWNER
  sta OBJ_OWNER
  lda #LA_KILL
  sta LARGE_AI_ACTION
  a16
  lda #0                        ; no next motion record
  jmp .loword(large_ai_selected)
@alive:
.a8
  lda CORE_TURRET_STEP
  inc
  cmp #CORE_TURRET_STEPS
  bcc @select
  pha
  lda CORE_TURRET_SHOTS
  cmp #CORE_TURRET_BURST
  bne @fire
  stz CORE_TURRET_SHOTS
  pla
  bra @select
@fire:
  pla
  lda 2*SPRITE_SIZE+SPR_ATTR
  and #SPR_ALONG_HIGH
  bne @reset                    ; the turret is off the field
  lda SPR_CROSS
  clc
  adc #SPRITE_HALF
  sta LARGE_AI_X
  lda SPR_ALONG
  sec
  sbc #SPRITE_HALF
  sta LARGE_AI_Y
  lda CORE_TURRET_FIRE
  inc
  sta LARGE_AI_FIRE
@reset:
  inc CORE_TURRET_SHOTS
  lda #0
@select:
  sta CORE_TURRET_STEP
  a16
  and #255
  asl
  tax
  lda f:large_turret_paths,x
  jmp .loword(large_ai_selected)

; boss_core_lookup: find the ship core row of LARGE_CALLBACK (motion bank 4).
; boss_core_pages has one list for each arcade page $80-$BF; a list holds
; BR_SIZE rows and ends with a zero word. Returns carry 1 with BOSS_CONFIG
; and A = the phase (a word index into boss_core_vectors), else carry 0.
; D is the object record; A16.
BOSS_CORE_BANK = .bankbyte(boss_core_pages) << 16
boss_core_lookup:
.a16
  lda OBJ_VARIANT
  and #OBJ_BANK_BITS
  cmp #4<<4                     ; motion bank 4
  bne @unknown
  lda LARGE_CALLBACK
  cmp #ARCADE_BANK_WINDOW
  bcc @unknown
  cmp #ARCADE_BANK_END
  bcs @unknown
  xba
  and #(ARCADE_BANK_END-ARCADE_BANK_WINDOW)/256-1  ; the page in the window
  asl
  tax
  lda f:boss_core_pages,x
  tax
@row:
  lda f:BOSS_CORE_BANK+BR_CALLBACK,x
  beq @unknown
  cmp LARGE_CALLBACK
  beq @found
  inx
  inx
  inx
  inx
  inx
  inx                           ; BR_SIZE
  bra @row
@found:
  lda f:BOSS_CORE_BANK+BR_CONFIG,x
  sta BOSS_CONFIG
  lda f:BOSS_CORE_BANK+BR_PHASE,x
  sec
  rts
@unknown:
  clc
  rts
.assert BR_SIZE = 6, error
; boss_core_retire: the core's retire phase: it follows the camera only.
boss_core_retire:
.a16
  a8
  lda #OF_CAMERA
  sta OBJ_FLAGS
  a16
  ldx BOSS_CONFIG
  lda f:boss_core_configs+BC_RETIRE,x
  jmp .loword(large_ai_selected)

; launch_deck_tick: a deck aircraft (US $48E7-$4912): DECK_TIME decisions on
; each launch_deck_paths step; launch_deck_delays gives the times.
launch_deck_tick:
  a8
  lda DECK_TIME
  beq @next
  dec DECK_TIME
  bra @select
@next:
  a16
  lda DECK_STEP
  and #255
  tax
  a8
  lda f:launch_deck_delays,x
  sta DECK_TIME
  inc DECK_STEP
@select:
  a16
  lda DECK_STEP
  and #255
  asl
  tax
  lda f:launch_deck_paths,x
  jmp .loword(large_ai_selected)
; launch_crew_sound: the deck crew tail: the bullet-hit sound, then go on.
launch_crew_sound:
  a8
  lda #SND_BULLET_HIT
  sta LARGE_AI_SOUND
  a16
  lda LARGE_SOURCE
  clc
  adc #STEP_TAIL_SIZE
  jmp .loword(large_ai_selected)
