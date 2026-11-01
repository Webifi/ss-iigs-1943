; The loop and the special attacks of button 2 (US arcade code). The loop
; (PS_LOOP, bank 1 $8F5F-$9065) flies the player through the poses of
; special_loop_table (arcade $9066). A special attack (arcade $13B9-$1441,
; $16EA) is a Cyclone near an enemy bullet or with little energy, else a
; Lightning, or a Tsunami in a ship scene. It damages the enemies, stops
; the enemy bullets for SUPPRESS_TICKS, and shows its pictures on the card:
; the Lightning and Tsunami painters are helpers that this code puts in the
; packet, and patched sites in the main loop run the special work.
.a8
.i16
; The loop (PS_LOOP) in ANIM_WORK of the body.
LOOP_TIME = ANIM_WORK        ; updates left of this loop step
LOOP_STEP = ANIM_WORK+1      ; the next special_loop_table entry
LOOP_ALONG = ANIM_WORK+2     ; the along move of this step
LOOP_ENTRY_SIZE = 3          ; special_loop_table: the time, the along move, the code
LOOP_END = 255               ; special_loop_table: the end
LOOP_WING_STEP = $17         ; this step shows the wings and waits at a camera hold
LOOP_HOLD_TIME = $f0         ; LOOP_WING_STEP at HOLD_BACK: the updates it waits
LOOP_ALONG_MAX = $e0         ; the loop: the along limits (FLIGHT_ALONG_MIN under)
LOOP_HALF = 16               ; PL_BODY2 and the right wing: this far to the right
LOOP_WING_RISE = 16          ; the wings: this far less along than the body
LOOP_CROSS_SPEED = 2         ; the stick moves the loop this far across
CLEAR_CROSS = $f0            ; special_clear_bullets: a cross off the field
; The special attacks.
SPECIAL_ENERGY = 4           ; the energy that each special costs (the Lightning
                             ; and the Tsunami cost it twice)
SUPPRESS_TICKS = 200         ; BULLET_SUPPRESS: the updates without enemy bullets
CYCLONE_SCAN = 14            ; the enemy bullet slots that the Cyclone test looks at
NEAR_AHEAD = 40              ; a bullet is near: up to this far ahead along,
NEAR_BEHIND = 24             ; up to this far behind,
NEAR_SIDE = 32               ; and up to this far across from the body centre
CYCLONE_TICKS = 30           ; SPECIAL_TIMER at the start of each special
LIGHTNING_TICKS = 18
TSUNAMI_TICKS = 132
CYCLONE_FLASH = 6            ; the Cyclone flashes cyan, then not, each 6 ticks
LIGHTNING_POSE = 6           ; the ticks of each of the three Lightning poses
TSUNAMI_FLASH = 4            ; the Tsunami flashes in its first 4 ticks; then
                             ; its painter runs
LARGE_CLASS = 6              ; the large slots of a class: the Tsunami hits slots
                             ; 6-11, the others 0-5
LARGE_DAMAGE = 2             ; the HP that a special takes from a large object
LOOPS_PER_PLAYER = 2         ; special_reset_stage: SPECIAL_LOOPS for each player
WAVE_LENGTH = 0              ; a SPECIAL_WAVE_LIST entry: the bytes (0: the end),
WAVE_ADDRESS = 2             ; the long address of the bytes
WAVE_ENTRY_SIZE = 6
.assert SPECIAL_PRESENTED_POSE+1 = SPECIAL_FLAGS, error, "special flags adjacency"
.assert PLAYER_CURSOR = SPECIAL_FLAGS+1, error, "player cursor adjacency"

; special_loop_tick: one update of a loop (PS_LOOP) for the player at
; PLAYER_CURSOR: no collision and no weapon. Each step of special_loop_table
; sets the time, the along move and the body pose; at LOOP_WING_STEP the
; wings show (a camera hold waits there). The stick moves the loop across.
; Damaged wings or the table end: the player flies level again (PS_LIVE)
; and the enemy bullets go (arcade $9044). JSL.
special_loop_tick:
  phd
  a16
  lda PLAYER_CURSOR
  clc
  adc #PLAYER
  tcd
  a8
  stz z:PL_COLLIDE
  stz z:PL_WEAPON_GATE
  lda z:PL_WINGS
  beq :+
  jmp @finish
:
  lda z:LOOP_TIME
  bne @move
  lda z:LOOP_STEP
  a16
  and #255
  sta a:LOOP_STEP_OFFSET
  asl
  clc
  adc a:LOOP_STEP_OFFSET        ; times LOOP_ENTRY_SIZE
  tax
  a8
  lda f:special_loop_table,x
  cmp #LOOP_END
  bne :+
  jmp @finish
:
  sta z:LOOP_TIME
  lda f:special_loop_table+1,x
  sta z:LOOP_ALONG
  lda f:special_loop_table+2,x
  sta z:SPR_CODE
  inc
  sta z:PL_BODY2+SPR_CODE
  lda z:LOOP_STEP
  cmp #LOOP_WING_STEP
  bne @hide_wings
  lda a:CAMERA_HOLD
  beq @wing_pictures
  cmp #HOLD_BACK
  bne :+
  lda #LOOP_HOLD_TIME
  sta z:LOOP_TIME
  stz z:LOOP_ALONG
  bra @wing_pictures
:
  lda #1                        ; HOLD_STILL: one update at a time
  sta z:LOOP_TIME
@wing_pictures:
  lda z:PL_BODY2+SPR_CODE
  clc
  adc #7                        ; the wings: the body code + 8 and + 9
  sta z:PL_LEFT_WING+SPR_CODE
  inc
  sta z:PL_RIGHT_WING+SPR_CODE
  bra @next_pose
@hide_wings:
  stz z:PL_LEFT_WING+SPR_CODE
  stz z:PL_RIGHT_WING+SPR_CODE
@next_pose:
  inc z:LOOP_STEP
@move:
  lda a:CAMERA_HOLD
  cmp #HOLD_STILL
  bne :+
  lda #1                        ; the step waits while the foreground holds
  sta z:LOOP_TIME
:
  lda z:SPR_ALONG
  clc
  adc z:LOOP_ALONG
  cmp #LOOP_ALONG_MAX
  bcc :+
  lda #LOOP_ALONG_MAX
:
  cmp #FLIGHT_ALONG_MIN
  bcs :+
  lda #FLIGHT_ALONG_MIN
:
  sta z:SPR_ALONG
  sta z:PL_BODY2+SPR_ALONG
  sec
  sbc #LOOP_WING_RISE
  sta z:PL_LEFT_WING+SPR_ALONG
  sta z:PL_RIGHT_WING+SPR_ALONG
  lda f:FLIGHT_INPUT
  eor #INPUT_NONE               ; 1 = pressed
  and #INPUT_RIGHT|INPUT_LEFT
  a16
  and #255
  tax
  a8
  lda z:SPR_CROSS
  clc
  adc f:special_loop_dx,x
  cmp #FLIGHT_CROSS_MIN
  bcs :+
  lda #FLIGHT_CROSS_MIN
:
  cmp #FLIGHT_CROSS_MAX
  bcc :+
  lda #FLIGHT_CROSS_MAX
:
  sta z:SPR_CROSS
  sta z:PL_LEFT_WING+SPR_CROSS
  clc
  adc #LOOP_HALF
  sta z:PL_BODY2+SPR_CROSS
  sta z:PL_RIGHT_WING+SPR_CROSS
  dec z:LOOP_TIME
  pld
  rtl
@finish:
  stz z:LOOP_TIME               ; all of ANIM_WORK
  stz z:LOOP_STEP
  stz z:LOOP_ALONG
  stz z:ANIM_WORK+3
  stz z:ANIM_WORK+4
  lda #PS_LIVE                  ; also the level pose
  sta z:PL_STATE
  sta z:PL_POSE
  lda #WING_CODE+PS_LIVE        ; the wings of the level pose
  sta z:PL_LEFT_WING+SPR_CODE
  sta z:PL_RIGHT_WING+SPR_CODE
  lda #SPR_HIDDEN
  sta z:PL_LEFT_WING+SPR_ALONG
  sta z:PL_RIGHT_WING+SPR_ALONG
  pld
  jml special_clear_bullets
.assert ANIM_WORK_SIZE = 5, error
; special_loop_dx: the cross move for the right and left stick bits.
special_loop_dx: .byte 0,LOOP_CROSS_SPEED,<-LOOP_CROSS_SPEED,0
special_loop_table:
  .byte $10,$01,$24,$10,$01,$02,$01,$01,$04,$01,$00,$04
  .byte $01,$01,$04,$01,$00,$04,$01,$01,$04,$01,$00,$04
  .byte $01,$01,$04,$01,$00,$04,$01,$01,$04,$01,$00,$04
  .byte $01,$01,$04,$01,$00,$04,$01,$01,$04,$01,$00,$04
  .byte $04,$00,$06,$01,$00,$0a,$01,$ff,$0a,$01,$00,$0a
  .byte $01,$ff,$0a,$06,$ff,$0c,$10,$ff,$44,$08,$ff,$0e
  .byte $08,$ff,$10,$04,$00,$12,$04,$00,$46,$04,$00,$4e
  .byte $01,$00,$24,LOOP_END

; special_clear_bullets: all the enemy bullets go. JSL.
special_clear_bullets:
  ldx #0
@slot:
  lda f:BULLETS+OBJ_TYPE,x
  beq @next
  lda #0
  sta f:BULLETS+SPR_CODE,x
  sta f:BULLETS+OBJ_TYPE,x
  lda #CLEAR_CROSS
  sta f:BULLETS+SPR_CROSS,x
@next:
  a16
  txa
  clc
  adc #OBJECT_SIZE
  tax
  a8
  cpx #BULLET_COUNT*OBJECT_SIZE
  bne @slot
  rtl

; special_button: button 2 with GATE_ARMED (game_players_tick). With fire
; held, wings that are not damaged and a loop left: a loop. Else, with no
; special running and SPECIAL_ENERGY: a special attack (the arcade's weapon
; dispatcher $13B9-$1441). JSL.
special_button:
  ldx PLAYER_CURSOR
  lda PLAYER+PL_WEAPON_GATE,x
  cmp #GATE_ARMED
  bne @done
  lda STAGE_FINISH
  bne @done
  lda f:FLIGHT_INPUT
  and #INPUT_FIRE               ; 0: fire is held too: a loop
  bne @attack
  lda PLAYER+PL_WINGS,x
  bne @attack
  lda SPECIAL_LOOPS
  beq @attack
  dec SPECIAL_LOOPS
  jsl special_sync_shadow
  lda #PS_LOOP
  sta PLAYER+PL_STATE,x
  lda #GATE_USED
  sta PLAYER+PL_WEAPON_GATE,x
  lda #SND_LOOP
  jml game_sound_request
@attack:
  lda SPECIAL_TIMER
  bne @done
  lda PLAYER+PL_ENERGY,x
  cmp #SPECIAL_ENERGY
  bcs :+
@done:
  rtl
:
  sbc #SPECIAL_ENERGY           ; carry 1 from the BCS
  sta PLAYER+PL_ENERGY,x
  lda #GATE_USED
  sta PLAYER+PL_WEAPON_GATE
  sta PLAYER2+PL_WEAPON_GATE
  lda PLAYER+PL_NUMBER,x
  inc
  sta SPECIAL_OWNER
  lda #SUPPRESS_TICKS
  sta BULLET_SUPPRESS
  ; A live enemy bullet near the player: the Cyclone (arcade $16EA).
  ldy #0
@scan:
  lda BULLETS+OBJ_TYPE,y
  beq @next_bullet
  lda PLAYER+SPR_ALONG,x
  clc
  adc #NEAR_AHEAD
  cmp BULLETS+SPR_ALONG,y
  bcc @next_bullet
  sec
  sbc #NEAR_AHEAD+NEAR_BEHIND
  cmp BULLETS+SPR_ALONG,y
  bcs @next_bullet
  lda PLAYER+PL_BODY2+SPR_CROSS,x
  clc
  adc #NEAR_SIDE
  cmp BULLETS+SPR_CROSS,y
  bcc @next_bullet
  sec
  sbc #2*NEAR_SIDE
  cmp BULLETS+SPR_CROSS,y
  bcc @near
@next_bullet:
  a16
  tya
  clc
  adc #OBJECT_SIZE
  tay
  a8
  cpy #CYCLONE_SCAN*OBJECT_SIZE
  bne @scan
  ; No bullet near: the Lightning (the Tsunami in a ship scene) when the
  ; player has SPECIAL_ENERGY more; else the Cyclone.
  ldx PLAYER_CURSOR
  lda PLAYER+PL_ENERGY,x
  cmp #SPECIAL_ENERGY
  bcc @near
  sbc #SPECIAL_ENERGY           ; carry 1 from the BCC
  sta PLAYER+PL_ENERGY,x
  lda STAGE_SHIP_SCENE
  beq @lightning
  lda #SPECIAL_TSUNAMI
  bra @select
@lightning:
  lda #SPECIAL_LIGHTNING
  bra @select
@near:
  lda #SPECIAL_CYCLONE
@select:
  sta SPECIAL_TYPE
  beq @no_upload_init
  cmp #SPECIAL_LIGHTNING
  bne :+
  ; The bolt poses are in the card from the start; a new attack starts the
  ; pose history of the packets again.
  stz SPECIAL_PRESENTED_POSE
  sta SPECIAL_LOADED            ; A = SPECIAL_LIGHTNING = 1
  sta SPECIAL_WAVE_READY
  bra @no_upload_init
:
  ; The Tsunami: its art is loaded, or its transfer goes on, or starts.
  cmp SPECIAL_LOADED            ; A = SPECIAL_TYPE
  beq @preloaded
  clc
  adc #LOADED_TRANSFER
  cmp SPECIAL_LOADED            ; an interrupted transfer goes on
  beq @no_upload_init
  sta SPECIAL_LOADED
  stz SPECIAL_WAVE_READY
  a16
  stz SPECIAL_WAVE_INDEX
  a8
  bra @no_upload_init
@preloaded:
  lda #1
  sta SPECIAL_WAVE_READY
@no_upload_init:
  lda SPECIAL_TYPE
  cmp #SPECIAL_TSUNAMI
  bne :+
  lda #TSUNAMI_TICKS
  bra @duration
:
  lda SPECIAL_TYPE
  bne :+
  lda #CYCLONE_TICKS
  bra @duration
:
  lda #LIGHTNING_TICKS
@duration:
  sta SPECIAL_TIMER
  jsl special_install_tick
  lda #SCROLL_STOP              ; the sea and the foreground stop
  sta CAMERA_BG2_GATE
  sta CAMERA_BG2_GATE+1
  sta CAMERA_BG1_GATE
  sta CAMERA_BG1_GATE+1
  lda SPECIAL_TYPE
  beq @cyclone_sound
  cmp #SPECIAL_LIGHTNING
  beq @lightning_sound
  lda #SND_TSUNAMI
  bra @sound
@lightning_sound:
  lda #SND_LIGHTNING
  bra @sound
@cyclone_sound:
  lda #SND_CYCLONE
@sound:
  jsl game_sound_request
  jsl special_clear_bullets
  ; The Lightning hits the enemies once, the Tsunami twice; the Cyclone
  ; only ends the bullets.
  lda SPECIAL_TYPE
  beq @finish_attack
  lda #1
  sta SPECIAL_PASS
  lda SPECIAL_TYPE
  cmp #SPECIAL_TSUNAMI
  bne :+
  inc SPECIAL_PASS
:
  jsl special_damage_enemies
  jsl special_damage_large
@finish_attack:
  ldx PLAYER_CURSOR
  jml player_energy_hud_far
.assert SPECIAL_LIGHTNING = 1, error

; special_damage_enemies: SPECIAL_PASS damage to each small enemy that can
; be hit (US $45EF), in the small and the extended pools; the pickups and
; the records with only OF_CAMERA stay. A kill gives the score to
; SPECIAL_OWNER; a kill counts once, even with two passes. JSL.
special_damage_enemies:
  a16
  stz WAVE_SLOT
@slot:
  ldx WAVE_SLOT
  a8
  lda ENEMY_POOL+OBJ_TYPE,x
  beq @next
  lda ENEMY_POOL+OBJ_VARIANT,x
  and #OBJ_PICKUP_BITS
  bne @next
  lda ENEMY_POOL+OBJ_FLAGS,x
  and #<~OF_CAMERA
  beq @next
  lda SPECIAL_OWNER
  sta ENEMY_POOL+OBJ_OWNER,x
  lda ENEMY_POOL+OBJ_HP,x
  sec
  sbc SPECIAL_PASS
  bcc @kill
  beq @kill
  sta ENEMY_POOL+OBJ_HP,x
  bra @next
@kill:
  lda #0
  sta ENEMY_POOL+OBJ_HP,x
  jsl special_enemy_kill_far
@next:
  a16
  lda WAVE_SLOT
  clc
  adc #OBJECT_SIZE
  cmp #ENEMY_COUNT*OBJECT_SIZE
  bne :+
  lda #EXTENDED_POOL-ENEMY_POOL ; after the small pool, the extended pool
:
  sta WAVE_SLOT
  cmp #EXTENDED_POOL-ENEMY_POOL+EXTENDED_COUNT*OBJECT_SIZE
  bcc @slot
  a8
  rtl
.assert EXTENDED_POOL-ENEMY_POOL >= ENEMY_COUNT*OBJECT_SIZE, error

; special_damage_large: LARGE_DAMAGE to each large object of the class
; (LARGE_CLASS slots) that can be hit; a borrow kills it (US $468C). JSL.
special_damage_large:
  a16
  stz LARGE_SLOT
  lda #LARGE_CLASS*LARGE_SIZE
  sta SPECIAL_END
  a8
  lda SPECIAL_TYPE
  cmp #SPECIAL_TSUNAMI
  bne @large
  a16
  lda #LARGE_CLASS*LARGE_SIZE
  sta LARGE_SLOT
  lda #2*LARGE_CLASS*LARGE_SIZE
  sta SPECIAL_END
@large:
  ldx LARGE_SLOT
  a8
  lda LARGE_POOL+OBJ_TYPE,x
  beq @large_next
  lda LARGE_POOL+OBJ_FLAGS,x
  and #<~OF_CAMERA
  beq @large_next
  lda SPECIAL_OWNER
  sta LARGE_POOL+OBJ_OWNER,x
  lda LARGE_POOL+OBJ_HP,x
  sec
  sbc #LARGE_DAMAGE
  sta LARGE_POOL+OBJ_HP,x
  bcs @large_next
  jsl large_common_kill
@large_next:
  a16
  lda LARGE_SLOT
  clc
  adc #LARGE_SIZE
  sta LARGE_SLOT
  cmp SPECIAL_END
  bcc @large
  a8
  rtl

; special_tick: one update while a special or its bullet stop runs (from
; special_tick_site): BULLET_SUPPRESS counts down; SPECIAL_TIMER counts
; down (a stage finish ends it). At its end: the visual sites go back (when
; the card hook is out), the sea runs again, and the foreground too, except
; at an air boss or a boss hold. When all is done, the sites go back.
special_tick:
  lda SPECIAL_TIMER
  sta PLAYER_SPECIAL_LOCK
  lda BULLET_SUPPRESS
  beq :+
  dec BULLET_SUPPRESS
:
  lda SPECIAL_TIMER
  beq @done
  lda STAGE_FINISH
  bne @finish
  dec SPECIAL_TIMER
  bne @done
@finish:
  stz SPECIAL_TIMER
  lda SPECIAL_HOOK
  bne :+
  jsl special_restore_visual
:
  a16
  stz CAMERA_BG2_GATE
  a8
  lda AIR_BOSS                  ; arcade $E1A0: the air boss moves
  bne @done
  lda STAGE_BOSS_HOLD
  bne @done
  a16
  stz CAMERA_BG1_GATE
  a8
@done:
  lda SPECIAL_TIMER
  ora BULLET_SUPPRESS
  ora SPECIAL_HOOK              ; the card hook must go out first
  bne :+
  jsl special_restore_tick
:
  rtl

; special_install_tick: patch the four sites for a special: special_tick_site,
; d500_gate_site and special_packet_site become JSRs (the operand first, then
; the opcode: the LDA stays whole until then), and world_lz_finish_call calls
; special_lz_finish. JSL.
special_install_tick:
  php
  a16
  lda #.loword(special_tick_trampoline)
  sta f:special_tick_site+1
  lda #.loword(d500_gate_stub)
  sta f:d500_gate_site+1
  lda #.loword(special_packet_trampoline)
  sta f:special_packet_site+1
  lda #.loword(special_lz_finish)
  sta f:world_lz_finish_call+1
  a8
  lda #.bankbyte(special_lz_finish)
  sta f:world_lz_finish_call+3
  lda #OPCODE_JSR
  sta f:special_tick_site
  sta f:d500_gate_site
  sta f:special_packet_site
  plp
  rtl

; special_restore_tick: all four sites as they were: special_tick_site
; (LDA CAB_RESULT_ACTIVE), then the others (special_restore_visual). JSL.
special_restore_tick:
  php
  a16
  lda #CAB_RESULT_ACTIVE
  sta f:special_tick_site+1
  a8
  lda #OPCODE_LDA_ABS
  sta f:special_tick_site
  plp
  jmp .loword(special_restore_visual)

; special_restore_visual: the packet and staging sites as they were (LDA
; CAMERA_BG1_SCROLL, LDA SPECIAL_FLAGS, JSL world_inflate_finish), when the
; special pictures end; special_tick_site stays while the bullet stop runs.
; JSL.
special_restore_visual:
  php
  a16
  lda #CAMERA_BG1_SCROLL
  sta f:d500_gate_site+1
  lda #SPECIAL_FLAGS
  sta f:special_packet_site+1
  lda #.loword(world_inflate_finish)
  sta f:world_lz_finish_call+1
  a8
  lda #.bankbyte(world_inflate_finish)
  sta f:world_lz_finish_call+3
  lda #OPCODE_LDA_ABS
  sta f:d500_gate_site
  sta f:special_packet_site
  plp
  rtl

; special_sync_shadow: SPECIAL_FLAGS = SPECIAL_LOOPS (SPF_LOOPS) and
; GAME_BG2_DISABLED (SPF_BG2_OFF), after a change of either. JSL; all kept.
special_sync_shadow:
  php
  a8
  pha
  lda SPECIAL_LOOPS
  and #SPF_LOOPS>>SPF_LOOPS_SHIFT  ; never into the flash bits
  asl
  asl
  sta SPECIAL_FLAGS
  lda GAME_BG2_DISABLED
  and #SPF_BG2_OFF
  ora SPECIAL_FLAGS
  sta SPECIAL_FLAGS
  pla
  plp
  rtl
.assert SPF_LOOPS_SHIFT = 2, error  ; the two ASLs above

; special_packet_flash: A = SPECIAL_FLAGS with the flash bits of this tick
; (special_packet_trampoline, at special_packet_site): SPF_CYAN for the
; Cyclone (CYCLONE_FLASH ticks on, then off), SPF_DARK for the Tsunami
; (each second tick of its first TSUNAMI_FLASH). The Lightning gives its
; flash with its helper (special_packet_helper). JSL.
special_packet_flash:
  lda SPECIAL_TIMER
  beq @flags
  lda SPECIAL_TYPE
  beq @cyclone
  cmp #SPECIAL_LIGHTNING
  beq @no_flash
  lda SPECIAL_TIMER
  cmp #TSUNAMI_TICKS-TSUNAMI_FLASH+1
  bcc @no_flash
  and #1
  bne @no_flash
  lda #SPF_DARK
  bra @flags
@cyclone:
  lda SPECIAL_TIMER
  cmp #CYCLONE_TICKS-CYCLONE_FLASH+1
  bcs @cyan
  cmp #CYCLONE_TICKS-2*CYCLONE_FLASH+1
  bcs @no_flash
  cmp #CYCLONE_TICKS-3*CYCLONE_FLASH+1
  bcs @cyan
  cmp #CYCLONE_TICKS-4*CYCLONE_FLASH+1
  bcs @no_flash
@cyan:
  lda #SPF_CYAN
  bra @flags
@no_flash:
  lda #0
@flags:
  ora SPECIAL_FLAGS
  rtl

; special_reset_stage: at a stage start: LOOPS_PER_PLAYER loops for each
; player in the game. JSL.
special_reset_stage:
  lda #LOOPS_PER_PLAYER
  sta SPECIAL_LOOPS
  jsl special_sync_shadow
  lda PLAYER+PL_STATE
  beq :+
  lda PLAYER2+PL_STATE
  beq :+
  lda #2*LOOPS_PER_PLAYER
  sta SPECIAL_LOOPS
  jsl special_sync_shadow
:
  rtl

; special_wave_append: put the next batch of the Tsunami art upload
; (SPECIAL_WAVE_LIST) in the packet, when it fits with the D500_FOLLOW
; world bytes that come after it. The caller keeps SPECIAL_SOURCE. The art
; takes the D500 groups, so the D500 image must be staged again (D500_DONE
; until the next report). After the last batch: SPECIAL_WAVE_READY. JSL;
; A16.
.a16
special_wave_append:
  ldx SPECIAL_WAVE_INDEX
  lda f:SPECIAL_WAVE_LIST+WAVE_LENGTH,x
  beq @complete
  sta D500_COPY_LENGTH
  lda f:SPECIAL_WAVE_LIST+WAVE_ADDRESS,x
  sta SPECIAL_SOURCE
  lda f:SPECIAL_WAVE_LIST+WAVE_ADDRESS+2,x
  sta SPECIAL_SOURCE+2
  jsr .loword(special_append)
  bcs @return
  lda #D500_DONE
  sta D500_INDEX
  lda SPECIAL_WAVE_INDEX
  clc
  adc #WAVE_ENTRY_SIZE
  sta SPECIAL_WAVE_INDEX
  tax
  lda f:SPECIAL_WAVE_LIST+WAVE_LENGTH,x
  bne @return
@complete:
  a8
  lda #1
  sta SPECIAL_WAVE_READY
  lda SPECIAL_TYPE
  sta SPECIAL_LOADED
  a16
@return:
  rtl
.a8

; special_stage_gate: the D500 staging of this packet (from d500_gate_stub).
; Carry 1: the special takes the packet (its art, its helper, or its card
; hook going in or out); carry 0: the ordinary D500 staging goes on. JSL;
; A16.
.a16
special_stage_gate:
  a8
  lda SPECIAL_TIMER
  bne @check_mode
  lda SPECIAL_HOOK
  beq @ordinary
  ; The special ended with the hook in: one neutral picture first (the
  ; palettes go back), then the hook goes out.
  cmp #HOOK_ON
  bne @remove_hook
  inc SPECIAL_HOOK              ; HOOK_NEUTRAL
  a16
  sec
  rtl
@remove_hook:
  a16
  jsl special_remove_hook
  sec
  rtl
@check_mode:
.a8
  lda GAME_FLOW
  cmp #CAB_PAGE_FIRST
  bcs @ordinary
  lda CAB_RESULT_ACTIVE
  bne @ordinary
  ; The wave art takes the D500 groups: not on the deck. The bolt art has
  ; its own groups.
  lda SPECIAL_TYPE
  cmp #SPECIAL_LIGHTNING
  beq @takeoff_safe
  a16
  lda CAMERA_BG1_SCROLL
  cmp #DECK_SCROLL
  bne :+
  clc
  rtl
:
  a8
@takeoff_safe:
  lda SPECIAL_HOOK
  bne :+
  a16
  jsl special_install_card_hook
  a8
  lda SPECIAL_HOOK
  beq @ordinary
:
.a8
  lda SPECIAL_TYPE
  beq @ordinary
  cmp SPECIAL_LOADED
  beq @owned
  cmp #SPECIAL_LIGHTNING
  bne :+
  ; No bolt art marker: never an art transfer during an attack.
  a16
  sec
  rtl
:
  a16
  jsl special_wave_append
  sec
  rtl
@owned:
.a8
  a16
  jsl special_packet_helper
  sec
  rtl
@ordinary:
.a8
  a16
  clc
  rtl
.a8

; special_lz_finish: during a special, an inflated world packet goes through
; special_stage_gate too (from world_lz_finish_call), once a packet
; (SPF_OVERLAY), keeping SPECIAL_SOURCE; then world_inflate_finish. JSL;
; A16.
.a16
special_lz_finish:
  phx
  lda SPECIAL_SOURCE
  pha
  lda SPECIAL_SOURCE+2
  pha
  ldx PACKET_HEADER
  a8
  lda a:TRAILER_HEADER+TRAILER_SPECIAL,x
  and #SPF_OVERLAY
  bne @already
  a16
  lda f:WL_FINAL
  sta D500_FOLLOW
  jsl special_stage_gate
  a8
@already:
  a16
  pla
  sta SPECIAL_SOURCE+2
  pla
  sta SPECIAL_SOURCE
  plx
  ldx WORLD_OUTPUT
  jml world_inflate_finish
.a8

; special_packet_helper: put the painter of the Lightning or the Tsunami
; (after its flash) in the packet: helper 0 or 1 by the picture
; (GAME_PICTURE), as the packet buffers alternate; it runs before the next
; DMA. Then SPF_OVERLAY, and for the Lightning its pose and, on the first
; packet of each pose, the bright flash. JSL; A16.
.a16
special_packet_helper:
  a8
  lda SPECIAL_WAVE_READY
  bne :+
  a16
  rtl
:
.a8
  lda SPECIAL_TYPE
  cmp #SPECIAL_LIGHTNING
  beq @bolt
  cmp #SPECIAL_TSUNAMI
  beq :+
  a16
  rtl
:
.a8
  lda SPECIAL_TIMER
  cmp #TSUNAMI_TICKS-TSUNAMI_FLASH+1
  bcc :+
  a16
  rtl
:
.a8
  lda GAME_PICTURE
  and #1
  a16
  bne @wave1
  lda #SPECIAL_WAVE_HELPER0_LENGTH
  sta D500_COPY_LENGTH
  lda #.loword(SPECIAL_WAVE_HELPER0_ADDRESS)
  sta SPECIAL_SOURCE
  lda #.hiword(SPECIAL_WAVE_HELPER0_ADDRESS)
  sta SPECIAL_SOURCE+2
  bra @check
@wave1:
  lda #SPECIAL_WAVE_HELPER1_LENGTH
  sta D500_COPY_LENGTH
  lda #.loword(SPECIAL_WAVE_HELPER1_ADDRESS)
  sta SPECIAL_SOURCE
  lda #.hiword(SPECIAL_WAVE_HELPER1_ADDRESS)
  sta SPECIAL_SOURCE+2
  bra @check
@bolt:
.a8
  lda GAME_PICTURE
  and #1
  a16
  bne @bolt1
  lda #SPECIAL_BOLT_HELPER0_LENGTH
  sta D500_COPY_LENGTH
  lda #.loword(SPECIAL_BOLT_HELPER0_ADDRESS)
  sta SPECIAL_SOURCE
  lda #.hiword(SPECIAL_BOLT_HELPER0_ADDRESS)
  sta SPECIAL_SOURCE+2
  bra @check
@bolt1:
  lda #SPECIAL_BOLT_HELPER1_LENGTH
  sta D500_COPY_LENGTH
  lda #.loword(SPECIAL_BOLT_HELPER1_ADDRESS)
  sta SPECIAL_SOURCE
  lda #.hiword(SPECIAL_BOLT_HELPER1_ADDRESS)
  sta SPECIAL_SOURCE+2
@check:
  jsr .loword(special_append)
  bcs @return
  a8
  lda #HOOK_ON
  sta SPECIAL_HOOK
  a16
  ldx PACKET_HEADER
  a8
  lda a:TRAILER_HEADER+TRAILER_SPECIAL,x
  ora #SPF_OVERLAY
  sta a:TRAILER_HEADER+TRAILER_SPECIAL,x
  lda SPECIAL_TYPE
  cmp #SPECIAL_LIGHTNING
  bne @return8
  ; The time gives the pose; the first packet that carries a pose gets the
  ; bright flash, a later packet of that pose is blue. A missed pose is
  ; never shown late; the pose history changes only when the helper fits.
  lda SPECIAL_TIMER
  ; The last pose starts one tick early, so that a late painter shows both
  ; colours in the LIGHTNING_TICKS of the attack.
  cmp #LIGHTNING_TICKS-2*LIGHTNING_POSE+1
  bne :+
  lda #LIGHTNING_TICKS-2*LIGHTNING_POSE
:
  sta a:TRAILER_HEADER+TRAILER_COUNT,x
  cmp #LIGHTNING_TICKS-LIGHTNING_POSE+1   ; the card: BOLT_POSE_1
  bcs @pose0
  cmp #LIGHTNING_TICKS-2*LIGHTNING_POSE+1 ; the card: BOLT_POSE_2
  bcs @pose1
  lda #3
  bra @pose_ready
@pose1:
  lda #2
  bra @pose_ready
@pose0:
  lda #1
@pose_ready:
  cmp SPECIAL_PRESENTED_POSE
  beq @return8
  sta SPECIAL_PRESENTED_POSE
@bolt_bright:
  lda a:TRAILER_HEADER+TRAILER_SPECIAL,x
  ora #SPF_CLOUDS|SPF_CYAN      ; the white bolt, the lit sea and clouds
  sta a:TRAILER_HEADER+TRAILER_SPECIAL,x
@return8:
.a8
  a16
@return:
.a16
  rtl

; special_install_card_hook: put the palette hook (a jump in the card's
; palette entry) in the packet before the first special picture, when it
; fits: HOOK_ON. JSL; A16.
.a16
special_install_card_hook:
  lda #SPECIAL_HOOK_ON_LENGTH
  sta D500_COPY_LENGTH
  lda #.loword(SPECIAL_HOOK_ON_ADDRESS)
  sta SPECIAL_SOURCE
  lda #.hiword(SPECIAL_HOOK_ON_ADDRESS)
  sta SPECIAL_SOURCE+2
  jsr .loword(special_append)
  bcs @done
  a8
  lda #HOOK_ON
  sta SPECIAL_HOOK
  a16
@done:
  rtl

; special_remove_hook: after the neutral picture, put the restore of the two
; card instructions in the packet, when it fits: no hook, the visual sites
; go back, and all the sites when the bullet stop has ended too. JSL; A16.
.a16
special_remove_hook:
  lda #SPECIAL_HOOK_OFF_LENGTH
  sta D500_COPY_LENGTH
  lda #.loword(SPECIAL_HOOK_OFF_ADDRESS)
  sta SPECIAL_SOURCE
  lda #.hiword(SPECIAL_HOOK_OFF_ADDRESS)
  sta SPECIAL_SOURCE+2
  jsr .loword(special_append)
  bcs @done
  a8
  stz SPECIAL_HOOK
  jsl special_restore_visual
  lda SPECIAL_TIMER
  ora BULLET_SUPPRESS
  bne :+
  jsl special_restore_tick
:
  a16
@done:
  rtl

; special_append: copy the D500_COPY_LENGTH bytes at [SPECIAL_SOURCE] to the
; packet at WORLD_OUTPUT, each word byte-swapped as d500_stage_append does,
; when they fit with the D500_FOLLOW bytes that come after them and the end
; word. Carry 1: no room, nothing copied. JSR; A16.
.a16
special_append:
  lda WORLD_OUTPUT
  sec
  sbc #.loword(PACKET_BUFFER)
  clc
  adc D500_COPY_LENGTH
  adc D500_FOLLOW
  adc #2                        ; the end word
  cmp #PACKET_AREA+1
  bcs @done
  ldx WORLD_OUTPUT
  ldy #0
@copy:
  lda [SPECIAL_SOURCE],y
  xba
  sta a:0,x
  inx
  inx
  iny
  iny
  cpy D500_COPY_LENGTH
  bcc @copy
  stx WORLD_OUTPUT
  clc
@done:
  rts
