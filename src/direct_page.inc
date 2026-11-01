; The direct-page variables: the game page (D = 0), then the music page
; (D = MUSIC_PAGE). Names that share an address belong to routines that never
; run at the same time.

; The game loop (src/flight_loop.s, src/game_clock.s, src/stream.s).
PACKET_LENGTH       = $28       ; the payload bytes in PACKET_BUFFER that stream_packet sends
STREAM_TOKEN        = $60       ; the handshake byte that says the card takes the next packet
GAME_UPDATES        = $68       ; 2 bytes: logic updates since the game started
SEA_CAMERA          = $6c       ; 2 bytes: the sea camera of the packet
FG_CAMERA           = $6e       ; 2 bytes: the foreground camera of the packet
WL_RECORD           = $70       ; 3 bytes: the record that the world decoder inflates (src/world_lz.s)

; Startup: audio_bank_init (src/audio_bank.s) gives audio_binary_upload
; (src/audio_binary.s) one packed SSG table at a time.
AUDIO_BINARY_SOURCE = $30       ; 3 bytes: the packed table
AUDIO_BINARY_LOW    = $33       ; the low level of this page
AUDIO_BINARY_HIGH   = $34       ; the high level of this page
AUDIO_BINARY_BITS   = $35       ; the packed bits left in this byte
AUDIO_BINARY_COUNT  = $36       ; the packed bytes left in this page
AUDIO_BINARY_AM     = $37       ; nonzero: map each level through AUDIO_VOLUME_MAP

; Enemy decisions (src/enemy_ai.s and the family files) while D points at the
; object record; they use these bytes as absolute addresses.
AIM_OCTANT          = $d0       ; ai_target: the base direction of the octant
AIM_CROSS           = $d2       ; ai_target: the cross distance to the player
AIM_ALONG           = $d3       ; ai_target: the along distance to the player
AIM_MINOR           = $d4       ; ai_target: the smaller distance
AI_PATTERN_OFFSET   = $d0       ; ai_pattern_index: AI_PATTERN_STEP
MEDIUM_NEXT_DIRECTION = $d4     ; medium_return: the direction one step on
MEDIUM_PATH_OFFSET  = $d6       ; medium_home: OBJ_AIM times two
GROUND_PATH_OFFSET  = $d4       ; ground_select: GROUND_KIND times 16
FORMATION_PATH_OFFSET = $d6     ; formation_select: FORMATION_TYPE times 64
TURN_TARGET         = $d6       ; formation turns: the direction to the target
TURN_NEXT           = $d7       ; formation turns: the heading one step on
FORMATION_TABLE_OFFSET = $d8    ; formation_extra_table: the formation_paths row
PATTERN_DELTA       = $d4       ; formation_delta_pattern: the heading change
SHIP_SEQUENCE_OFFSET = $d4      ; ship_sequence_index: the entry times 3
SHIP_FIRE_ODDS      = $d4       ; ship_random_fire: the odds out of 16
SHIP_TURN_NEXT      = $d4       ; ship_turn: the heading one step on
AIR_PERCENT_PART    = $d4       ; air_core_tick: the lives left, for AIR_PERCENT
AIR_PIECE_RISE      = $d4       ; air_piece_tick: the along offset of the piece
LOOP_STEP_OFFSET    = $d0       ; special_loop_tick: LOOP_STEP times 3
TURRET_PATH_OFFSET  = $d4       ; turret path select: TURRET_KIND times 32
TRIPLE_TARGET       = $d4       ; game_triple_quad: the barrel for the target, 0-2
TRIPLE_MUZZLE_OFFSET = $d4      ; game_triple_quad: the muzzle entry
BULLET_SEARCH_END   = $d0       ; bullet spawns: the end of the free bullet search
BULLET_RECORD       = $d2       ; bullet spawns: the new bullet record
LARGE_PLANE_OFFSET  = $d4       ; large_plane_index: the entry times 3
CONTACT_NEXT        = $dc       ; large_shot_test: the iterator step, list or linear
CONTACT_ADJUST      = $de       ; large_shot_test: added to the shot coordinates
SCRIPT_STEP         = $d2       ; enemy_script: the address of the next motion step
SCRIPT_BANK_ROW     = $d4       ; enemy_script: the first enemy_script_pages row of the bank
SCRIPT_ADDRESS      = $d8       ; enemy_script: the host address of the step
SCRIPT_ATTR         = $dc       ; enemy_script: SPR_ALONG_HIGH of the record, kept
TURN_ODDS           = $d6       ; game_turn_random: the odds out of 16
CHILD_SIDE          = $d6       ; game_carrier_child_spawn: 1 the right child
LARGE_SCAN_END      = $d2       ; large_scan_forward: the end of the slot scan
OPEN_PATH_OFFSET    = $d4       ; game_open_aircraft: OPEN_PHASE times 3
FALL_ODDS           = $d4       ; game_fall_random_shot: the odds out of 16
MOTION_FRACTION     = $d2       ; enemy_motion, bullet_motion: the new OBJ_CROSS_FRACTION
                                ; until the cross bounds check passes

; Player input (src/game_players.s, src/flight.s).
FLIGHT_INPUT        = $40       ; the stick and buttons of the player that runs, active low
FLIGHT_TABLE        = $42       ; live_flight_step: the offset of the speed table
FLIGHT_STICK        = $44       ; live_flight_step: the stick directions, active high

; The camera (src/camera.s), D = 0.
SEA_NEXT            = $d0       ; camera_step: the next sea scroll
PAN_POINTER         = $d4       ; camera_step: 2 bytes, the pan step of the stage

; The world decoder (src/world_lz.s), D = 0.
ROUTE_ROW           = $d0       ; world_choose_region: the WORLD_ROUTES row of the stage
WORLD_POINTER       = $d0       ; 4 bytes: the world list, or the LZ dictionary
WORLD_SOURCE        = $d4       ; 4 bytes: the encoded record

; Specials and the packet (src/special_loop.s, src/game_world.s), D = 0.
SPECIAL_SOURCE      = $d4       ; 4 bytes: the special wave or hook data
PACKET_HEADER       = $d8       ; game_world_append: the header of this packet

; Stage controls (src/stage_flow.s), D = 0.
REVIVE_COUNT        = $d0       ; the boss pass: the empty ledger slots left to revive
SPEED_FROM_STATE    = $d0       ; stage_speed_players: the PL_STATE to change
SPEED_TO_STATE      = $d1       ; stage_speed_players: the new PL_STATE
SECRET_INPUT        = $d0       ; stage_secret_player: the player input, active high

; The continue, the scores and the dive (src/player_continue.s), D = 0.
SCORE_COUNT         = $d3       ; score copies: the digits left
DIVE_POSE_TIME      = $d0       ; native_player_dive: the duration of the pose
DIVE_POSE_CODE      = $d1       ; native_player_dive: the sprite code of the pose
DIVE_POSE_ALONG     = $d2       ; native_player_dive: the along move of the pose
DIVE_STEP_OFFSET    = $d4       ; native_player_dive: DIVE_STEP times 3
PIECE_ATTR          = $d0       ; native_dive_pieces: the body attributes
PIECE_CROSS         = $d1       ; native_dive_pieces: the body cross coordinate
PIECE_ALONG         = $d2       ; native_dive_pieces: the body along coordinate
PIECE_CODE          = $d3       ; native_dive_pieces: the body sprite code

; Initials entry and the rank table (src/cabinet_post.s), D = 0.
POST_JOB            = $d4       ; cabinet_post_append: 4 bytes, the job data
POST_INSERT_END     = $d4       ; cabinet_post_insert: the end of the moved entries
POST_CHAR_POS       = $d4       ; cabinet_post_index: the character position of the player
POST_SLOT_OFFSET    = $d4       ; cabinet_post_commit: the score entry of the player
RANK_FONT           = $d7       ; rank fields: 0 white, 1 red high score, 2 player scores
RANK_LEADING        = $d8       ; cabinet_rank_score: nonzero while the zeros are leading
RANK_COUNT          = $d9       ; rank fields: the characters left
RANK_GLYPH          = $da       ; cabinet_rank_emit: the glyph of the character

; The update packet (src/state_packet.s), D = 0.
PLAYER_END          = $b6       ; flight_state_packet_far: the end of this player record

; The cabinet flow (src/game_flow.s, src/cabinet.s), D = 0.
SYSTEM_PRESSED      = $d0       ; game_flow_tick: the system keys pressed in this update;
                                ; cabinet_tick reads it after game_flow_tick
CAB_POINTER         = $d0       ; cabinet_append: 4 bytes, the cabinet page list
CAB_SOURCE          = $d4       ; cabinet appends: 4 bytes, the data to copy

; Waves (src/waves.s), D = 0.
WAVE_POSITION       = $d0       ; the wave_positions entry, or the next duration
WAVE_LEFT           = $d2       ; planes left to spawn
WAVE_RECORD         = $d4       ; the ENEMY_POOL record of this plane

; Stage events (src/stage.s), D = 0.
STAGE_POINTER       = $d8       ; stage_event: 3 bytes, the event table of the stage

; The stage result (src/stage_result.s), D = 0.
DIVIDEND            = $d8       ; game_ship_result: the damage, then the remainder
DIVISOR             = $da       ; game_ship_result: LARGE_THRESHOLD
QUOTIENT            = $d4       ; game_ship_result: the damage ratio, 8 bits
REFILL_STAGE        = $d4       ; game_refill_index: the stage
REFILL_ENERGY       = $d6       ; game_refill_tick: the energy of the refill

; The air boss (src/air_boss.s), D = 0.
AIR_MOVE            = $d4       ; 2 bytes: this update's move, fraction then integer

; The deck sequence (src/launch_flow.s), D = 0.
LAUNCH_TEMPLATE     = $d4       ; native_intro_tick: 3 bytes, the record template
LAUNCH_POSITION     = $d0       ; native_intro_tick: 2 bytes, the cross and along start

; World uploads (src/game_world.s), D = 0; also WORLD_POINTER, WORLD_SOURCE.
DIRECTORY_SIDE      = $d0       ; the WORLD_DIRECTORY side offset of the region
BUSY_COUNT          = $d0       ; live small objects; five or more delay the upload

; Bullet contact (src/bullet_contact.s), absolute while D points at the bullet.
CONTACT_DISTANCE    = $d0       ; the axis distance; then the damage
HUD_TILES           = $da       ; energy_hud_update: gauge tiles left
HUD_OFFSET          = $dc       ; energy_hud_update: the ENERGY_HUD row of the player

; Cabinet text and departures, D = 0.
STAT_TEXT           = $d4       ; cabinet_statistics_select: the CABINET_STAT_TEXT entry
TEXT_SEGMENT        = $d4       ; cabinet text: 3 bytes, this text segment
DEPART_BIT          = $d4       ; game_flow departure: the GAME_DEPART_DONE bit of this player
RESULT_BCD          = $d4       ; cabinet_result_number: the cabinet_percent_bcd entry

; Deck image staging (src/hitch_stage.s); it keeps the caller's bytes.
D500_SOURCE         = $d4       ; 4 bytes: the staged fragment

; The bullet loop (src/bullet_loop.s), D = 0.
INTERCEPT_WEAPON    = $e9       ; bullet_tick: nonzero when a player has the shotgun

; Shot collisions (src/bullet_intercept.s, src/enemy_collision.s), absolute
; while D points at the object.
SHOT_SCAN_END       = $dc       ; the end of the shot scan
SHOT_DISTANCE       = $de       ; the axis distance of this shot

; Spawns and scores, D = 0.
SPAWN_CROSS         = $d0       ; medium_spawn: the cross start
SPAWN_TEMPLATE      = $d2       ; medium_spawn: 2 bytes, the template offset
SPAWN_SEARCH_END    = $d4       ; medium_spawn: the end of the free slot search
SHIP_SEARCH_END     = $d2       ; ship_copy_template: the end of the free slot search
SCORE_CARRY         = $d0       ; the score add: the decimal carry
SCORE_ADD_LEFT      = $d2       ; the score add: the digits left
FLAG_RISE           = $d4       ; cabinet flag: the along offset of this record
FLAG_ALONG          = $d8       ; cabinet flag: the along coordinate of the flag
FLAG_ATTR           = $da       ; cabinet flag: the attributes of this record
GATE_VALUE          = $d0       ; stage_control_player_gate: the PL_WEAPON_GATE value
LARGE_SPAWN_CROSS   = $d0       ; large_spawn: the large_spawn_x entry
LARGE_SPAWN_FIRE    = $d1       ; large_spawn: the large_spawn_pattern entry, for CORE_TURRET_FIRE

; Player shots (src/projectiles.s), D = 0.
SHOT_FRAME_TIME     = $d0       ; projectile_one: the shot_animation time of the frame

; Sound uploads in the game loop (src/fm_voice.s), D = 0.
FM_UP_PTR           = $e8       ; 3 bytes: the FM upload source

; The music page (D = MUSIC_PAGE): the music interrupt (src/music_irq.s) and
; the sound code that it calls. The names with MUSIC_PAGE are absolute
; addresses. Code with D = 0 uses the other names at MUSIC_PAGE+name.
ENERGY_HUD          = MUSIC_PAGE     ; 2 rows of ENERGY_HUD_ROW: the energy gauges
ENERGY_HUD_ROW      = 28             ; a row: ENERGY_HUD_CELLS tiles, then their colours
ENERGY_HUD_CELLS    = 14             ; eight energy for each cell
ENERGY_GLYPH        = $80            ; the tile of a cell with 0-7 eighths left: + the eighths
MUSIC_NONE          = $ffff     ; MUSIC_SELECTED, MUSIC_NEXT, MS_REPEAT: none
MUSIC_SELECTED      = MUSIC_PAGE+$80 ; 2 bytes: the MUSIC_STATES slot that plays, or MUSIC_NONE
MUSIC_TICK          = MUSIC_PAGE+$82 ; 2 bytes
MUSIC_TEMP          = MUSIC_PAGE+$84 ; 2 bytes: music_start: the song, then its part offsets
MUSIC_NEXT          = MUSIC_PAGE+$86 ; 2 bytes: ticks to the earliest event of the selected slot; 0 = rescan
MUSIC_FAST          = MUSIC_PAGE+$88 ; 2 bytes: ticks the selected slot ran since its part delays were updated
MUSIC_SLOT          = MUSIC_PAGE+$8a ; 2 bytes: the MUSIC_STATES slot in work
MUSIC_PENDING       = MUSIC_PAGE+$8c ; the FM command for music_player_tick, or MUSIC_STOP
MUSIC_STOP          = $ff       ; MUSIC_PENDING: stop the music
MUSIC_PART          = MUSIC_PAGE+$8e ; 2 bytes: the MUSIC_STATES part in work
MUSIC_IRQ_PHASE     = MUSIC_PAGE+$90 ; 2 bytes: the next music_irq_frequencies entry
GAME_CLOCK          = MUSIC_PAGE+$96 ; 2 bytes: DOC timer interrupts; the game clock and the input times
MUSIC_IRQ_PERIODS   = MUSIC_PAGE+$98 ; the DOC timer frequency, low byte
SSG_TEMP            = $b0       ; 4 bytes: audio_ssg work
SSG_SLOT            = $b4       ; 2 bytes: the SSG_STATES offset of the part in work
SSG_MASK            = $b6       ; 2 bytes: the voice bits that audio_ssg walks
SSG_PENDING         = $b8       ; nonzero: audio_ssg_command has a command
SSG_ACTIVE          = $ba       ; nonzero: an SSG list plays
SSG_ODD             = $bc       ; the first DOC oscillator of the SSG voice pair (T_ODD)
SSG_EVEN            = $bd       ; the second one (SSG_ODD + 1)
SSG_DUE             = $be       ; audio_ssg_tick: the SSG_PHASES bits of the parts still to test
SSG_TIME            = $bf       ; low byte of the active SSG tick clock
SSG_PTR             = $d0       ; 3 bytes: the SSG list record
SSG_COMMAND_PTR     = $d4       ; 3 bytes: audio_ssg_command: the command table entry
MUSIC_POOL_PTR      = $e8       ; 3 bytes: MUSIC_SCORE
FM_PTR              = $f0       ; 3 bytes: the FM record
NOTE_ENTRY          = $f3       ; 4 bytes: the music_note_dictionary entry of the note
FM_T0               = $f3       ; 2 bytes: fm_voice work (also NOTE_ENTRY)
FM_T1               = $f5       ; 2 bytes: fm_voice work
FM_T2               = $f7       ; 2 bytes: fm_voice work
FM_V                = $f9       ; voice 0/1
FM_G                = $fa       ; register group
FM_VAL              = $fb       ; fm_wr: the value for the DOC register
FM_PRE              = $fc       ; prefetch capture of the note being started
FM_SONG             = $fd       ; music_start: song/phase entry offset
