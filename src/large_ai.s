; Original-US ship core ($8654-$872F, bank 4) and shared explosion $5E94.
; D is selected here from the live record. Outer flow and secondary explosion
; requests are explicit outputs, so no original scheduler code is executed.
.a8
.i16
.include "boss_core_data.inc"
BOSS_CONFIG = $1ca0
LARGE_AI_NEXT = $1c40
LARGE_THRESHOLD = $1c42        ; E552
LARGE_AI_ACTION = $1c43        ; schedule 32EA, cancel 3, schedule 32E2, explosion
LARGE_AI_SOUND = $1c44
LARGE_AI_X = $1c45
LARGE_AI_Y = $1c46
LARGE_AI_FIRE = $1c47         ; 1..4 original turret pattern, zero none

large_ai:
  phd
  rep #$20
  lda LARGE_RECORD
  tcd
  stz LARGE_AI_NEXT
  sep #$20
  stz LARGE_AI_ACTION
  stz LARGE_AI_SOUND
  stz LARGE_AI_X
  stz LARGE_AI_Y
  stz LARGE_AI_FIRE
.ifdef BANK6_TURRETS
  stz TURRET_FIRE
.endif
  rep #$20
  lda LARGE_CALLBACK
.ifdef BANK6_TURRETS
  cmp #$804b
  beq @aiming_turret
  cmp #$81c7
  beq @aiming_turret
  cmp #$8343
  beq @aiming_turret
  cmp #$84b7
  bne :+
@aiming_turret:
  jmp .loword(ship_aiming_turret)
:
.endif
.ifdef GIANT_ENEMIES
  cmp #$6626
  bne :+
  jmp .loword(giant_explosion_select)
:
  cmp #$49b5
  bne :+
  sep #$20
  lda #$0f
  sta LARGE_AI_SOUND
  rep #$20
  lda LARGE_SOURCE
  clc
  adc #3
  jmp .loword(large_ai_selected)
:
.endif
.a16
 .ifdef SHIP_ENEMIES
  cmp #$b366
  bne :+
  jmp .loword(large_plane_begin)
:
  cmp #$b370
  bne :+
  jmp .loword(large_plane_wrap)
:
  cmp #$b3ef
  bne :+
  jmp .loword(large_plane_wait)
:
  cmp #$b425
  bne :+
  jmp .loword(large_plane_enable)
:
  cmp #$b458
  bne :+
  jmp .loword(large_plane_aim)
:
  cmp #$b4d5
  bne :+
  jmp .loword(large_plane_fire)
:
 .endif
  cmp #$8084
  bne :+
  jmp .loword(ship_turret)
:
  cmp #$5e94
  bne :+
  jmp .loword(large_explosion_select)
:
.ifdef CONTINUOUS_GAME
  .macro game_dispatch id, target
    cmp #id
    bne :+
    jmp .loword(target)
:
  .endmacro
  game_dispatch $48e7, launch_deck_tick
  game_dispatch $49bf, launch_crew_sound
  game_dispatch $aba5, game_quad_tick
  game_dispatch $ac55, game_quad_fire
  game_dispatch $ac76, game_quad_enable
  game_dispatch $a8fc, game_open_aircraft
  game_dispatch $aa49, game_weave_aircraft
  game_dispatch $aa83, game_weave_pause
  game_dispatch $aee3, game_fall_wait
  game_dispatch $aefb, game_fall_fire
  game_dispatch $af09, game_fall_enable
  game_dispatch $af14, game_fall_tail
  game_dispatch $5f1e, game_large_burst
  game_dispatch $5f67, game_large_burst_loop
  game_dispatch $5fa8, game_large_burst_loop
  game_dispatch $a6e8, game_carrier_destroy
  game_dispatch $b094, game_sway_aircraft
  game_dispatch $b089, game_turning_aircraft
  game_dispatch $a0c3, game_raid_giant
  game_dispatch $a434, game_carrier_destroy
  game_dispatch $a4bf, game_carrier_giant
  game_dispatch $b68d, game_land_quad
  game_dispatch $b813, game_land_quad
  game_dispatch $8972, game_land_quad
  game_dispatch $861e, game_triple_quad
  game_dispatch $9bee, game_giant_approach
  game_dispatch $9bff, game_giant_open
  game_dispatch $9c10, game_giant_ready
  game_dispatch $9c74, game_giant_tick
  game_dispatch $9f1e, game_giant_hit
  game_dispatch $9f48, game_giant_reopen
  .delmacro game_dispatch
.endif
  jsr .loword(boss_core_lookup)
  bcc @unknown
  tax
  jmp (.loword(boss_core_vectors),x)
@unknown:
  sep #$20
  pld
  clc
  rtl
large_ai_selected:
.a16
  sta LARGE_AI_NEXT
  sep #$20
  pld
  sec
  rtl
large_explosion_select:
.a16
  sep #$20
  lda $0e
  stz $0e
  cmp #2
  bne @ordinary
  rep #$20
  lda #$5ee2
  bra large_ai_selected

@ordinary:
  rep #$20
  lda #$5ea9
  bra large_ai_selected

.ifdef GIANT_ENEMIES
giant_explosion_select:
.a16
  sep #$20
  lda $0e
  stz $0e
  cmp #2
  bne @ordinary
  rep #$20
  lda #$6674
  jmp .loword(large_ai_selected)
@ordinary:
  rep #$20
  lda #$663b
  jmp .loword(large_ai_selected)
.endif

ship_core_alive:
.a16
  ldx BOSS_CONFIG
  lda f:boss_core_configs+0,x
  sta LARGE_AI_NEXT
  sep #$20
  lda STAGE_FLAGS+$11
  beq @done
  lda $01
  and #16
  bne @done
  lda LARGE_TOTAL
  cmp LARGE_THRESHOLD
  bne :+
  jmp .loword(ship_core_died)
:
  lda #4
  sta $09
  lda RANDOM_STATE
  lsr
  bcc :+
  lda #6
  sta $09
:
  lda RANDOM_STATE
  clc
  adc #$77
  sta RANDOM_STATE
@done:
  rep #$20
  lda LARGE_AI_NEXT
  jmp .loword(large_ai_selected)

ship_core_died:
.a8
  sep #$20
  lda $0e
  sta STAGE_FLAGS+7
  lda #1
  sta STAGE_FLAGS+$13
  sta STAGE_FLAGS+$12
  stz CAMERA_PAN_ON
  stz CAMERA+$1c
  stz CAMERA+$1f
  stz CAMERA+$20
  rep #$20
  stz CAMERA+$1d
  sep #$20
  lda LARGE_THRESHOLD
  sta LARGE_TOTAL
  lda $03
  ldx BOSS_CONFIG
  cmp f:boss_core_configs+12,x
  bcs ship_core_explode
  ldx BOSS_CONFIG
  lda f:boss_core_configs+10,x
  sta STAGE_FLAGS+$1c
  rep #$20
  lda LARGE_RECORD
  sta STAGE_FLAGS+$1d
  sep #$20
  lda #1
  sta LARGE_AI_ACTION
  sta CAMERA+$21
  stz CAMERA+$13
  lda PLAYER+8
  cmp #2
  bne :+
  lda #10
  sta PLAYER+8
:
  lda PLAYER+$88
  cmp #2
  bne :+
  lda #10
  sta PLAYER+$88
:
  rep #$20
  ldx BOSS_CONFIG
  lda f:boss_core_configs+2,x
  jmp .loword(large_ai_selected)

ship_core_wait:
.a16
  sep #$20
  lda $03
  ldx BOSS_CONFIG
  cmp f:boss_core_configs+13,x
  bcs ship_core_explode
  rep #$20
  ldx BOSS_CONFIG
  lda f:boss_core_configs+2,x
  jmp .loword(large_ai_selected)
ship_core_explode:
.a8
  lda #2
  sta CAMERA+$21
  lda #1
  sta CAMERA+$13
  lda #$1d
  sta LARGE_AI_SOUND
  lda $03
  sec
  sbc #16
  bcc @next
  sta LARGE_AI_Y
  lda $02
  clc
  adc #8
  sta LARGE_AI_X
  lda LARGE_AI_ACTION
  ora #8
  sta LARGE_AI_ACTION
  ; Original $832E advances E009 even when no explosion slot is free.
  lda RANDOM_STATE+1
  clc
  adc #$77
  sta RANDOM_STATE+1
@next:
  rep #$20
  ldx BOSS_CONFIG
  lda f:boss_core_configs+4,x
  jmp .loword(large_ai_selected)
ship_core_finish:
.a16
  lda LARGE_RECORD
  sta STAGE_FLAGS+$1d
  sep #$20
  ldx BOSS_CONFIG
  lda f:boss_core_configs+10,x
  sta STAGE_FLAGS+$1c
  lda f:boss_core_configs+11,x
  sta LARGE_AI_ACTION
  rep #$20
  ldx BOSS_CONFIG
  lda f:boss_core_configs+6,x
  jmp .loword(large_ai_selected)

ship_turret:
.a16
  sep #$20
  lda STAGE_FLAGS+$13
  beq @alive
  lda STAGE_FLAGS+7
  sta $0e
  lda #16
  sta LARGE_AI_ACTION
  rep #$20
  lda #0
  jmp .loword(large_ai_selected)
@alive:
.a8
  lda $10
  inc
  cmp #6
  bcc @select
  pha
  lda $11
  cmp #4
  bne @fire
  stz $11
  pla
  bra @select
@fire:
  pla
  lda $41
  and #16
  bne @reset
  lda $02
  clc
  adc #8
  sta LARGE_AI_X
  lda $03
  sec
  sbc #8
  sta LARGE_AI_Y
  lda $12
  inc
  sta LARGE_AI_FIRE
@reset:
  inc $11
  lda #0
@select:
  sta $10
  rep #$20
  and #255
  asl
  tax
  lda f:large_turret_paths,x
  jmp .loword(large_ai_selected)

; The page table limits the search to callbacks sharing one ROM address page.
; D remains the live record; only the selected data-row offset is retained.
boss_core_lookup:
.a16
  lda $0a
  and #$70
  cmp #$40
  bne @unknown
  lda LARGE_CALLBACK
  cmp #$8000
  bcc @unknown
  cmp #$c000
  bcs @unknown
  xba
  and #63
  asl
  tax
  lda f:boss_core_pages,x
  tax
@row:
  lda f:$010000,x
  beq @unknown
  cmp LARGE_CALLBACK
  beq @found
  inx
  inx
  inx
  inx
  inx
  inx
  bra @row
@found:
  lda f:$010002,x
  sta BOSS_CONFIG
  lda f:$010004,x
  sec
  rts
@unknown:
  clc
  rts
boss_core_retire:
.a16
  sep #$20
  lda #4
  sta $09
  rep #$20
  ldx BOSS_CONFIG
  lda f:boss_core_configs+8,x
  jmp .loword(large_ai_selected)

.ifdef CONTINUOUS_GAME
; Native US $48E7-$4912. D selects a deck aircraft's live 128-byte record.
launch_deck_tick:
  sep #$20
  lda $10
  beq @next
  dec $10
  bra @select
@next:
  rep #$20
  lda $11
  and #255
  tax
  sep #$20
  lda f:launch_deck_delays,x
  sta $10
  inc $11
@select:
  rep #$20
  lda $11
  and #255
  asl
  tax
  lda f:launch_deck_paths,x
  jmp .loword(large_ai_selected)
launch_crew_sound:
  sep #$20
  lda #$0f
  sta LARGE_AI_SOUND
  rep #$20
  lda LARGE_SOURCE
  clc
  adc #3
  jmp .loword(large_ai_selected)
.endif
