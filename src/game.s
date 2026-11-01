; The IIgs program of the game: the entry, the startup, the place of every
; routine and data file, and the handoff from the boot loader.
;
; The boot loader (src/boot.s) loads every file, then jumps to world_handoff
; at the end of this file. The handoff moves the world data into place and
; enters the game at entry. Files that end in .inc and are not in src/ are
; data that the build writes (build/game).
.setcpu "65816"
.smart                          ; ca65 follows REP and SEP for the immediate sizes
.include "w65c816.inc"          ; the processor status bits and the width macros
.include "iigs.inc"             ; the IIgs registers and the firmware entries
.include "second_sight.inc"     ; the host side of the Second Sight card
.include "host_memory.inc"      ; the memory map of the host
.include "settings.inc"         ; the settings block (SS1943.CONFIG)
.include "direct_page.inc"      ; the page-zero variables
.include "records.inc"          ; the arcade object, player and shot records
.include "sounds.inc"           ; the arcade sound commands
.include "packet.inc"           ; the update packet to the card
.include "cabinet_layouts.inc"  ; the cabinet pages and the card layouts
.include "game_ram.s"           ; the game variables (linker-placed)
.include "secondsight_symbols.inc" ; the Second Sight symbols (build/secondsight/secondsight.elf)
.include "host_data.inc"        ; the labels of the host data (build/game/host_data.s)

; src/iigs.cfg places the areas that host_memory.inc names for the code: the
; link stops when the two disagree.
.import __NATIVE_START__, __NATIVE_SIZE__, __BOOT_START__, __BOOT_SIZE__
.import __SOUND_START__, __SOUND_SIZE__, __GAMEPLAY_START__, __GAMEPLAY_SIZE__
.import __GAMEFLOW_START__, __GAMEFLOW_SIZE__, __GAMERAM_START__, __GAMERAM_SIZE__
.import __POOLRAM_START__, __POOLRAM_SIZE__, __BANK1RAM_START__, __BANK1RAM_SIZE__
.import __A_WORLD_START__, __A_WORLD_SIZE__, __C_WORLD_START__, __C_WORLD_SIZE__
.import __D_WORLD_START__, __D_WORLD_SIZE__, __LOW_WORLD_START__, __LOW_WORLD_SIZE__
.import __B_WORLD0_START__, __CABSCORES_START__, __CABSCORES_SIZE__
.import __B_WORLD2_START__, __B_WORLD2_SIZE__, __LC_WORLD_START__, __LC_WORLD_SIZE__
.import __BC_WORLD_START__, __BC_WORLD_SIZE__, __VIDEO_E0_START__, __VIDEO_E0_SIZE__
.import __VIDEO_E1_START__, __VIDEO_E1_SIZE__, __DATA02_START__, __SNAPSHOT0_START__
.import __SNAPSHOT1_START__, __SNAPSHOT1_SIZE__, __MIRROR_START__, __MIRROR_SIZE__
.assert __NATIVE_START__ = NATIVE_CODE && __NATIVE_SIZE__ = NATIVE_CODE_SIZE, error, "iigs.cfg NATIVE"
.assert __BOOT_START__ = BOOT_CODE && __BOOT_SIZE__ = BOOT_CODE_SIZE, error, "iigs.cfg BOOT"
.assert __SOUND_START__ = SOUND_CODE && __SOUND_SIZE__ = SOUND_CODE_SIZE, error, "iigs.cfg SOUND"
.assert __GAMEPLAY_START__ = GAMEPLAY_CODE && __GAMEPLAY_SIZE__ = GAMEPLAY_CODE_SIZE, error, "iigs.cfg GAMEPLAY"
.assert __GAMEFLOW_START__ = GAMEFLOW_CODE && __GAMEFLOW_SIZE__ = GAMEFLOW_CODE_SIZE, error, "iigs.cfg GAMEFLOW"
.assert __GAMERAM_START__ = GAME_RAM && __GAMERAM_SIZE__ = GAME_RAM_SIZE, error, "iigs.cfg GAMERAM"
.assert __POOLRAM_START__ = POOL_RAM && __POOLRAM_SIZE__ = POOL_RAM_SIZE, error, "iigs.cfg POOLRAM"
.assert __BANK1RAM_START__ = BANK1_RAM && __BANK1RAM_SIZE__ = BANK1_RAM_SIZE, error, "iigs.cfg BANK1RAM"
.assert __A_WORLD_START__ = A_WORLD && __A_WORLD_SIZE__ = A_WORLD_SIZE, error, "iigs.cfg A_WORLD"
.assert __C_WORLD_START__ = C_WORLD && __C_WORLD_SIZE__ = C_WORLD_SIZE, error, "iigs.cfg C_WORLD"
.assert __D_WORLD_START__ = D_WORLD && __D_WORLD_SIZE__ = D_WORLD_SIZE, error, "iigs.cfg D_WORLD"
.assert __LOW_WORLD_START__ = LOW_WORLD && __LOW_WORLD_SIZE__ = LOW_WORLD_SIZE, error, "iigs.cfg LOW_WORLD"
.assert __B_WORLD0_START__ = B_WORLD && __B_WORLD2_START__ = WORLD_SLOTS, error, "iigs.cfg B_WORLD"
.assert __B_WORLD2_START__ + __B_WORLD2_SIZE__ = B_WORLD + B_WORLD_SIZE, error, "iigs.cfg B_WORLD2"
.assert __CABSCORES_START__ = CAB_SCORES && __CABSCORES_SIZE__ = CAB_SCORES_SIZE, error, "iigs.cfg CABSCORES"
.assert __LC_WORLD_START__ = LC_WORLD && __LC_WORLD_SIZE__ = LC_WORLD_SIZE, error, "iigs.cfg LC_WORLD"
.assert __BC_WORLD_START__ = BC_WORLD && __BC_WORLD_SIZE__ = BC_WORLD_SIZE, error, "iigs.cfg BC_WORLD"
.assert __VIDEO_E0_START__ = VIDEO_E0_DATA && __VIDEO_E0_SIZE__ = VIDEO_DATA_SIZE, error, "iigs.cfg VIDEO_E0"
.assert __VIDEO_E1_START__ = VIDEO_E1_DATA && __VIDEO_E1_SIZE__ = VIDEO_DATA_SIZE, error, "iigs.cfg VIDEO_E1"
.assert __DATA02_START__ = PAYLOAD && __SNAPSHOT0_START__ = MIRROR_SNAPSHOT, error, "iigs.cfg payload"
.assert __SNAPSHOT1_START__ + __SNAPSHOT1_SIZE__ = PAYLOAD_END, error, "iigs.cfg SNAPSHOT1"
.assert __MIRROR_START__ = MIRROR_CODE && __MIRROR_SIZE__ = MIRROR_CODE_SIZE, error, "iigs.cfg MIRROR"

.a8
.i16
.segment "CODE"

; The game starts here (from world_handoff), in emulation mode.
; It sets native mode, the game stack, D and DBR, then runs the startup.
entry:
  sei                           ; no IRQ until music_irq_install sets its vector
  clc
  xce                           ; carry 0: native 65816 mode
  ax16
  ldx #STACK_TOP
  txs
  lda #ZERO_PAGE                ; D = the game page zero
  tcd
  a8
  pha                           ; A is still ZERO_PAGE: DBR = bank 0, the game RAM
  plb
  jmp startup
.assert ZERO_PAGE = 0 .and ^GAME_RAM = 0, error

; The Second Sight command handshake. The host writes a command to
; SS_COMMAND, then waits for the card at SS_HANDSHAKE. A missing or stopped
; card makes each wait time out, and the game stops at failed.
SS_POLLS        = $FFFF         ; the handshake reads before a wait fails
SS_DONE_ROUNDS  = 8             ; done waits this many times SS_POLLS: SetMode is slow

; on: wait until the card is ready for the parameters of the command.
; X: changed. A8.
on:
  ldx #SS_POLLS
@poll:
  lda SS_HANDSHAKE
  cmp #SS_READY
  beq @ok
  dex
  bne @poll
  jmp failed
@ok:
  rts

; off: wait until the card has read the parameters (handshake SS_PHASE_DONE).
; X: changed. A8.
off:
  ldx #SS_POLLS
@poll:
  lda SS_HANDSHAKE              ; SS_PHASE_DONE is 0
  beq @ok
  dex
  bne @poll
  jmp failed
@ok:
  rts

; done: wait until SetMode is finished (SS_DONE). SS_MODE_FAILED stops the
; game: the monitor has no such mode. X, Y: changed. A8.
done:
  ldy #SS_DONE_ROUNDS
@restart:
  ldx #SS_POLLS
@poll:
  lda SS_HANDSHAKE
  cmp #SS_DONE
  beq @ok
  cmp #SS_MODE_FAILED
  beq failed
  dex
  bne @poll
  dey
  bne @restart
  jmp failed
@ok:
  rts

; The card did not answer. Stop here; the screen keeps what it shows.
failed:
  bra failed

; ram_clear FIRST, LAST: fill FIRST up to (not including) LAST with zeros.
; It writes two zeros at FIRST, then MVN copies each byte to the next one.
; Call with A16, X16. A, X, Y: changed. DBR becomes the bank of FIRST.
.macro ram_clear first, last
  lda #0
  sta f:first
  ldx #.loword(first)           ; MVN source: FIRST
  ldy #.loword(first)+1         ; MVN destination: the next byte
  lda #(last)-(first)-2         ; MVN copies A+1 bytes: up to LAST-1
  mvn #^(first),#^(first)
.endmacro

; The startup: clear the game RAM, send the palette to the card, set the
; first game state, start the sound and the card program, then run the game
; loop. It never returns.
startup:
  ; The arcade clears its RAM at reset. No variable starts with the bytes
  ; that the boot left in its RAM.
  ax16
  ram_clear PLAYER, GAME_RAM_END
  ram_clear MUSIC_PAGE, MUSIC_PAGE+$100     ; the whole music page
  ram_clear ENEMY_POOL, POOLS_END
  ram_clear MUSIC_STATES, BANK1_RAM_END
  a8
  lda #^GAME_RAM                ; DBR = bank 0 again (the MVN changed it)
  pha
  plb
  ; SetPalette: three source address bytes (the card ignores them), then the
  ; palette. card_palette is the build's palette of the game (256 colours).
  lda #SS_SET_PALETTE
  sta SS_COMMAND
  jsr on
  lda #0                        ; the source address, three bytes
  sta SS_DATA_OUT
  sta SS_DATA_OUT
  sta SS_DATA_OUT
  jsr off
  jsr on
  ldx #0
palette:
  lda f:card_palette,x
  sta f:SS_DATA_OUT
  inx
  cpx #SS_PALETTE_SIZE
  bne palette
  jsr off
  ; The first game state from the build: the camera, the first player record
  ; and the seeds of the random streams. Each loop copies words, last first.
  ax16
  ldx #COMBAT_CAMERA_SIZE-2
combat_camera_copy:
  lda f:combat_camera,x
  sta a:CAMERA,x
  dex
  dex
  bpl combat_camera_copy
  ldx #FLIGHT_INITIAL_SIZE-2
flight_initial_copy:
  lda f:flight_initial,x
  sta a:PLAYER,x
  dex
  dex
  bpl flight_initial_copy
  ldx #RANDOM_STATES-2
bullet_seed_copy:
  lda f:bullet_seed,x
  sta a:RANDOM_STATE,x
  dex
  dex
  bpl bullet_seed_copy
  a8
  jsl audio_game_init           ; the sound chip and the music interrupt
  ; RunCode: the card starts its program at secondsight_entry_begin with the game's
  ; MMU setting (src/secondsight/secondsight.ld: game_cbr, game_cbar, game_bbr).
  lda #SS_RUN_CODE
  sta SS_COMMAND
  jsr on
  lda #secondsight_game_cbr
  sta SS_DATA_OUT
  lda #secondsight_game_cbar
  sta SS_DATA_OUT
  lda #secondsight_game_bbr
  sta SS_DATA_OUT
  lda #<secondsight_entry_begin
  sta SS_DATA_OUT
  lda #>secondsight_entry_begin
  sta SS_DATA_OUT
  jsr off
  jsr flight_loop               ; the game loop never returns
.assert COMBAT_CAMERA_SIZE <= CAMERA_SIZE .and FLIGHT_INITIAL_SIZE <= PLAYER_SIZE, error

; The routines and their data, by segment (src/iigs.cfg):
; NATIVE, GAMEPLAY, SOUND, SOUND_EXTRA, SPECIAL, CABDATA, GAMEFLOW, INPUT,
; DISPLAY and MIRROR. NATIVE is bank 0; the others are far code (JSL).
.segment "NATIVE"
.include "game_world.inc"
.include "input.s"
.include "flight.s"
.include "stream.s"
.include "flight_loop.s"
.include "projectiles.s"
.include "flight_weapons.s"
.include "shot_data.inc"
.include "weapon_data.inc"
.segment "GAMEPLAY"
.include "weapons.s"
.segment "NATIVE"
.include "player_aux_data.inc"
.segment "GAMEPLAY"
.include "player_aux.s"
.include "weapon_timer.s"
.include "player_contact.s"
.include "player_core.s"
.include "pickups.s"
.include "pickup_data.inc"
.segment "NATIVE"
.include "player_live.s"
.segment "GAMEPLAY"
.include "medium_data.inc"
.include "medium_spawn.s"
.include "simple_spawn_data.inc"
.include "simple_spawn.s"
.include "formation_data.inc"
.include "extended_spawn_data.inc"
.include "extended_spawn.s"
.include "ground_data.inc"
.include "large_data.inc"
.include "large_spawn.s"
.include "large_object.s"
.include "large_ai.s"
.include "large_contact.s"
.include "large_loop.s"
.segment "NATIVE"
.include "large_bridge.s"
.segment "GAMEPLAY"
.include "ship_data.inc"
.include "ship_spawn.s"
.include "large_aircraft.s"
.include "turret_data.inc"
.include "ship_turrets.s"
.include "turret_spawn.s"
.include "turret_bullet.s"
.include "ship_finish_data.inc"
.include "ship_finish.s"
.include "giant_object.s"
.include "stage_controls.inc"
.include "stage_controls.s"
.include "stage_flow.s"
.segment "NATIVE"
.include "audio_game.s"
.segment "SOUND"
.include "audio_data.inc"
.include "audio_doc.s"
.include "music_player.s"
.include "fm_voice.s"
.include "music_irq.s"
.segment "SOUND_EXTRA"
.include "audio_bank_data.inc"
.include "audio_bank.s"
.segment "SOUND"
.include "audio_binary.s"
.include "audio_ssg.s"
.segment "NATIVE"
.include "combat.s"
.include "enemy_script_data.inc"
.include "camera.s"
.include "camera_data.inc"
.include "score_data.inc"
.include "enemy_ai_data.inc"
.include "waves.s"
.include "wave_data.inc"
.include "stage_data.inc"
.include "stage.s"
.include "wave_combat.s"
.include "random.s"
.include "bullet_data.inc"
.include "bullet_loop.s"
.include "contact_loop.s"
.include "death_data.inc"
.include "player_death.s"
.include "death_loop.s"
; The routines of one pool record: D addresses the record.
.include "pool_record.s"
.include "enemy_motion.s"
.include "bullet_motion.s"
.include "enemy_script.s"
.include "enemy_ai.s"
.segment "GAMEPLAY"
.include "medium_ai.s"
.include "ship_ai.s"
.include "formation_ai.s"
.include "formation_extra.s"
.include "ground_ai.s"
.segment "NATIVE"
.include "ground_bullet.s"
.include "enemy_collision.s"
.include "enemy_bullets.s"
.include "bullet_contact.s"
.include "bullet_intercept.s"
.include "stationary_motion.s"
.segment "GAMEPLAY"
.include "state_packet.s"
.segment "NATIVE"
.include "state_packet_bridge.s"
.segment "SPECIAL"
.include "special_loop.s"
.segment "NATIVE"
.include "game_players.s"
.segment "GAMEPLAY"
.include "game_enemy_data.inc"
.include "game_enemies.s"
.segment "CABDATA"
.include "cabinet_data.inc"
.segment "GAMEFLOW"
.include "game_flow.s"
.include "game_world.s"
.include "cabinet.s"
.include "launch_flow.s"
.include "player_continue.s"
.segment "INPUT"
.include "hitch_stage.s"
.include "input_native.s"
.include "cabinet_post.s"
.segment "DISPLAY"
.include "display_control.s"
.segment "SPECIAL"
.include "display_game_clock.s"
.segment "MIRROR"
.include "menu-mirror.inc"
.include "menu_mirror_host.s"

; world_handoff: the boot loader (at BOOT_LOADER) jumps here after it loads
; every file, in emulation mode. The loader had to stage some world data in
; free RAM; this bank-zero stub moves each part to its place, then enters
; the game. The firmware's own $C000 RAM goes to FIRMWARE_C0_SAVE and
; FIRMWARE_C1_SAVE for the save bridge (src/input_disk_bridge.s).
.segment "CODE"
.a8
.i8
.export world_handoff
world_handoff:
  sei
  clc
  xce                           ; native mode
  ax16
  ; The A world: one MVN from its staging area.
  ldx #.loword(A_WORLD_STAGE)
  ldy #.loword(A_WORLD)
  lda #A_WORLD_SIZE-1           ; MVN copies A+1 bytes
  mvn #^A_WORLD_STAGE,#^A_WORLD
  ; Show the RAM under $C000-$FFFF of banks 0 and 1 (no I/O, no ROM) while
  ; the C world goes there. The old SHADOW value waits on the stack.
  a8
  lda f:SHADOW
  pha
  ora #SHADOW_IOLC
  sta f:SHADOW
  ax16
  ; Exchange the staged C world with the firmware's bank-zero $C000 RAM,
  ; one word at a time, in two parts.
  ldx #C_WORLD_PART0_SIZE-2
@swap_c_first:
  lda f:C_WORLD_STAGE0,x
  pha
  lda f:C_WORLD,x
  sta f:C_WORLD_STAGE0,x
  pla
  sta f:C_WORLD,x
  dex
  dex
  bpl @swap_c_first
  ldx #C_WORLD_PART1_SIZE-2
@swap_c_last:
  lda f:C_WORLD_STAGE1,x
  pha
  lda f:C_WORLD+C_WORLD_PART0_SIZE,x
  sta f:C_WORLD_STAGE1,x
  pla
  sta f:C_WORLD+C_WORLD_PART0_SIZE,x
  dex
  dex
  bpl @swap_c_last
  ; The staging areas now hold the firmware's $C000 image. Keep it for the
  ; save bridge.
  ldx #.loword(C_WORLD_STAGE0)
  ldy #.loword(FIRMWARE_C0_SAVE)
  lda #C_WORLD_PART0_SIZE-1
  mvn #^C_WORLD_STAGE0,#^FIRMWARE_C0_SAVE
  ldx #.loword(C_WORLD_STAGE1)
  ldy #.loword(FIRMWARE_C1_SAVE)
  lda #C_WORLD_PART1_SIZE-1
  mvn #^C_WORLD_STAGE1,#^FIRMWARE_C1_SAVE
  ; The D world waits in four parts, in RAM that the game uses later for its
  ; state, the pools, the packet and the sound. Join the parts at D_WORLD.
  ldx #.loword(D_WORLD_STAGE0)
  ldy #.loword(D_WORLD)
  lda #D_WORLD_PART0_SIZE-1
  mvn #^D_WORLD_STAGE0,#^D_WORLD
  ldx #.loword(D_WORLD_STAGE1)
  ldy #.loword(D_WORLD+D_WORLD_PART0_SIZE)
  lda #D_WORLD_PART1_SIZE-1
  mvn #^D_WORLD_STAGE1,#^D_WORLD
  ldx #.loword(D_WORLD_STAGE2)
  ldy #.loword(D_WORLD+D_WORLD_PART0_SIZE+D_WORLD_PART1_SIZE)
  lda #D_WORLD_PART2_SIZE-1
  mvn #^D_WORLD_STAGE2,#^D_WORLD
  ldx #.loword(D_WORLD_STAGE3)
  ldy #.loword(D_WORLD+D_WORLD_PART0_SIZE+D_WORLD_PART1_SIZE+D_WORLD_PART2_SIZE)
  lda #D_WORLD_PART3_SIZE-1
  mvn #^D_WORLD_STAGE3,#^D_WORLD
  ; Clear the D world staging parts 1 and 2: the game uses that RAM later.
  ; DBR is the bank of D_WORLD after the last MVN.
  ldx #D_WORLD_PART1_SIZE-2
  lda #0
@clear_d_scratch:
  sta .loword(D_WORLD_STAGE1),x
  cpx #D_WORLD_PART2_SIZE       ; part 2 is shorter: clear only its range
  bcs :+
  sta .loword(D_WORLD_STAGE2),x
:
  dex
  dex
  bpl @clear_d_scratch
  ; Put the old SHADOW value back, then enter the game in emulation mode
  ; with DBR = bank 0, as entry expects.
  a8
  pla
  sta f:SHADOW
  ax8
  lda #^GAME_RAM
  pha
  plb
  sec
  xce                           ; carry 1: emulation mode
  jml entry
