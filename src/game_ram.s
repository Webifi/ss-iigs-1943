; The game RAM. The linker places these variables (src/iigs.cfg GAMERAM at
; GAME_RAM, POOLRAM at POOL_RAM, BANK1RAM at BANK1_RAM); this order keeps the
; arcade records and the adjacent groups together.
.segment "GAMERAM"
PLAYER: .res $100 ; the two player records (PLAYER_SIZE each; P2 at PLAYER2); records.inc names the fields
COMBAT_STATE: ; combat_init clears COMBAT_STATE to COMBAT_STATE_END
ENEMY_SCRIPT_KIND: .res $1 ; enemy_script: SCRIPT_MOVE, SCRIPT_RETIRE or SCRIPT_TAIL
ENEMY_CALLBACK: .res $2 ; enemy_script: the code tail of the step (SCRIPT_TAIL)
ENEMY_CAM_X: .res $1 ; the camera move across of this tick for the enemy motion (flight_play)
ENEMY_CAM_Y: .res $1 ; the camera move along of this tick for the enemy motion (flight_play)
ENEMY_RETIRED: .res $1 ; 1: the motion of this tick retired the object or bullet
COMBAT_PHASE: .res $1 ; the tick count; bit 0 selects the collision half of this tick
COMBAT_HAS_SHOTS: .res $1 ; wave_combat_tick: nonzero when player shots are live this tick
COMBAT_STATE_END:
CAMERA_SIZE = $28 ; the bytes of CAMERA
CAMERA: .res CAMERA_SIZE ; the camera state; src/camera.s names its fields
SCORE_AWARD_INDEX: .res $2 ; the award of score_awards to add
AI_PREFERENCE: .res $1 ; ai_target: nonzero aims at P2 when the players are near (arcade E148)
AI_RANDOM: .res $1 ; RANDOM_STATE+3 of this update
AI_TAIL: .res $2 ; the motion code tail of the object (ENEMY_CALLBACK)
AI_CONTINUE: .res $2 ; the motion step after the tail
AI_NEXT: .res $2 ; the motion record that the decision selects
AIF_AIMED = 1 ; AI_FIRE: an enemy bullet at OBJ_AIM
AIF_ANGLE = 2 ; AI_FIRE: an enemy bullet at MEDIUM_SHOT_ANGLE
AIF_GROUND = 3 ; AI_FIRE: a ground bullet
AI_FIRE: .res $1 ; 0, or the AIF_* shot of the object
AI_SOUND: .res $1 ; the sound request of the decision
WAVE_MODIFIER: .res $1 ; the modifier of the wave that spawns (stage events, EVENT_* flags)
WAVE_GROUP: .res $2 ; stage_fighter: the group of the fighter wave (1-4)
WC_SIX = 6 ; WAVE_COUNTS: the counted bank-6 formation (EVENT_COUNTED_SIX)
WAVE_COUNTS: .res $28 ; the live planes of each counted wave, by OBJ_WAVE_COUNTER
STAGE_CALLBACK: .res $2 ; the code tail of the stage event that runs (stage_dispatch)
STAGE_BANK: .res $2 ; the motion bank of the stage event that runs
WAVE_SLOT: .res $2 ; the offset of the small object of the loop (ENEMY_POOL)
BULLET_ANGLE: .res $1 ; the direction of the new enemy bullet
BULLET_SUPPRESS: .res $1 ; nonzero: no new enemy bullets (arcade E146)
BULLET_SLOTS: .res $1 ; the enemy bullet slots to search: always BULLET_COUNT (the arcade uses E1D4)
BULLET_SPEED: .res $1 ; the speed row of aimed bullets: always 0 (the arcade uses E1D5)
RANDOM_STATES = 8 ; the random streams
RANDOM_STATE: .res RANDOM_STATES ; the random streams of the enemy decisions; game.s seeds them
ENERGY_MAX: .res $1 ; the energy cap of the players (arcade E12F); the energy pickups fill to it
BULLET_HIT_SOUND: .res $1 ; bullet_contact: SND_BULLET_STRIKE or SND_PLAYER_DOWN of a bullet hit
BULLET_SLOT: .res $2 ; bullet_tick: the offset of the bullet of the loop
POOL_RECORD: .res $2 ; the record that a spawn or a contact works on
DEATH_PLAYER: .res $1 ; player_death: the player record offset
DEATH_PLAYING: .res $1 ; nonzero in a game; 0 in attract, where a death ends the demo
DEATH_DEMO_END: .res $1 ; player_death: the attract death is finished
INPUT_P1: .res $1 ; the controls of player 1 (0 = pressed): INPUT_* bits
INPUT_SYSTEM: .res $1 ; the system keys (0 = pressed): SYSTEM_* bits
INPUT_P2: .res $1 ; the controls of player 2 (0 = pressed): INPUT_* bits
PLAYER_SHADOW: .res 4*SPRITE_SIZE ; the shadow sprites: four sprite records
PAGE_NONE = $ff ; CAB_LOADED: no page picture is loaded (the pages: cabinet_layouts.inc)
GAME_FLOW: .res $1 ; the arcade mode: 0 the play (a game or the demo), else a cabinet page
GAME_CREDITS: .res $1 ; the credits
GAME_INPUT_OLD: .res $1 ; game_flow_tick: INPUT_SYSTEM of the update before (for the edges)
GAME_SEQUENCE: .res $1 ; game_scene_tick: the step of the stage scene sequence (SEQ_*)
GAME_SEQUENCE_TICKS: .res $2 ; the updates in the step of GAME_SEQUENCE
EXIT_RESULT = 1 ; GAME_STAGE_EXIT: the players left: the stage result
EXIT_REFILL = 2 ; GAME_STAGE_EXIT: the result tally runs
EXIT_RETRY = 3 ; GAME_STAGE_EXIT: the boss pass failed: the stage again
EXIT_ENDING = 4 ; GAME_STAGE_EXIT: the last stage is done: the ending
GAME_STAGE_EXIT: .res $1 ; 0 in the stage, else EXIT_*
GAME_DEPART_DONE: .res $1 ; game_depart_players: bit 0 player 1, bit 1 player 2 is done
GAME_DEPART_MODE: .res $1 ; game_depart_players: the PL_STATE of the departure (PS_DIVE, PS_LEAVE)
RESULT_TICKS: .res $2 ; game_refill_tick: the updates to the next refill step
RESULT_REMAIN: .res $1 ; the energy that the stage result refill still adds
WORLD_LOADING: .res $2 ; the world section that loads, or WORLD_NONE
WORLD_LIST: .res $4 ; the upload list of the section that loads
WORLD_OFFSET: .res $2 ; the next entry of WORLD_LIST
WORLD_OUTPUT: .res $2 ; the packet address of the next appended byte
WORLD_SLOT: .res $2 ; the world slot of the job that loads
WORLD_TILE: .res $2 ; the tile of the job that loads
WORLD_LENGTH: .res $2 ; the bytes of the job that loads
WORLD_CURRENT: .res $1 ; the world region of the camera (world_choose_region)
WORLD_SKIPS: .res $1 ; world_choose_region: the regions it may still skip
WORLD_TAGS: .res $2 ; the section in each world slot, or WORLD_NONE
WORLD_SIDE: .res $2 ; the side of the region that loads
W_DONE: .res $2 ; world_inflate_force: the tokens done; $8000 up: no time limit
W_SCRATCH: .res $2 ; world_lz: work bytes
CAB_PAGE: .res $1 ; the cabinet page that shows (PAGE_*)
CAB_LOADED: .res $1 ; the page whose picture the card has, or PAGE_NONE
CAB_LOADING: .res $1 ; 1: the upload of a page picture runs
CAB_WAIT: .res $2 ; the updates left of the cabinet page or wait
CAB_LIST: .res $4 ; cabinet_append: the long address of the upload list of the page
CAB_OFFSET: .res $2 ; cabinet_append: the next entry of CAB_LIST
CAB_LENGTH: .res $2 ; the bytes of the cabinet upload or layout
CAB_PACKET_MODE: .res $1 ; the page mode for the packet (LAYOUT_LOADING while it loads)
CAB_START_PENDING: .res $1 ; 1: a paid start waits for the loads (cabinet_tick)
LAUNCH_SMALL: .res $1 ; native_intro_tick: the small objects of the launch done
LAUNCH_LARGE: .res $1 ; native_intro_tick: the large objects of the launch done
LAUNCH_SLOT: .res $2 ; native_intro_tick: the object slot of the launch
LAUNCH_INDEX: .res $2 ; native_intro_tick: the launch table entry
SPECIAL_END: .res $2 ; special_damage_large: the end of the large slots of the class
SPECIAL_CYCLONE = 0 ; SPECIAL_TYPE
SPECIAL_LIGHTNING = 1 ; SPECIAL_TYPE
SPECIAL_TSUNAMI = 2 ; SPECIAL_TYPE (a ship scene)
SPECIAL_TYPE: .res $1 ; the special attack: SPECIAL_CYCLONE, _LIGHTNING or _TSUNAMI
SPECIAL_TIMER: .res $1 ; the updates left of the special attack; 0 none
SPECIAL_OWNER: .res $1 ; the player of the special (1 or 2): it gets the score
SPECIAL_PASS: .res $1 ; the damage of the special to each small enemy (1 or 2)
SPECIAL_PRESENTED_POSE: .res $1 ; special_packet_helper: the Lightning pose of the last packet
SPECIAL_FLAGS: .res $1 ; SPF_BG2_OFF and SPF_LOOPS (special_sync_shadow)
PLAYER_CURSOR: .res $2 ; the offset of the player that game_players_tick works on (0 or PLAYER_SIZE)
GAME_TWO_PLAYERS: .res $1 ; 1: a game of two players
GAME_DIP_A: .res $1 ; the DIP switches A in use (DIP_A_*; dip_apply)
GAME_DIP_B: .res $1 ; the DIP switches B in use (DIP_B_*; dip_apply)
GAME_COIN_A: .res $1 ; the coins in slot A since its last credit (GAME_COIN_A,x: X 0 A, 1 B)
GAME_COIN_B: .res $1 ; the coins in slot B
OUT_P1 = 1 ; GAME_OUT: player 1 is out of the game
OUT_P2 = 2 ; GAME_OUT: player 2 is out of the game
GAME_OUT: .res $1 ; OUT_* bits
GAME_CONTINUE_LEVEL: .res $1 ; the continue level; also SPECIAL_LOOPS, the loops left (arcade E12B)
SPECIAL_LOOPS = GAME_CONTINUE_LEVEL ; original E12B: shared continue/join/loop stock
D500_INDEX: .res $2 ; the next D500_STAGE_LIST entry, or D500_DONE
D500_FOLLOW: .res $2 ; the world bytes that follow a D500 or special part in the packet
D500_COPY_LENGTH: .res $2 ; the bytes of the D500 or special part to append
HOOK_ON = 1 ; SPECIAL_HOOK: the card palette hook is in
HOOK_NEUTRAL = 2 ; SPECIAL_HOOK: a neutral picture went out; next the hook goes
SPECIAL_HOOK: .res $1 ; the card palette hook of the special: 0 out, HOOK_ON, HOOK_NEUTRAL
PLAYER_UI_MODE: .res $2 ; for each player: 0 none, else UI_* (packet_layout.inc, game_hud_messages)
PLAYER_UI_COUNT: .res $2 ; native_player_wait: the continue count of each player for the packet
W_LEN: .res $2 ; world_lz: the length of the LZ match or literal run
W_DIST: .res $2 ; world_lz: the distance of the LZ match
W_LEFT: .res $2 ; world_inflate_pump, world_inflate_force: the tokens still allowed
SPECIAL_WAVE_INDEX: .res $2 ; the next SPECIAL_WAVE_LIST entry of the Tsunami art upload
SPECIAL_WAVE_READY: .res $1 ; 1: the art of the special is in the card
LOADED_TRANSFER = 2 ; SPECIAL_LOADED: + the type: its art transfer runs
SPECIAL_LOADED: .res $1 ; the special whose art is in the card (+ LOADED_TRANSFER: its upload runs)
GAME_PICTURE: .res $2 ; pictures sent to the card; bit 0 selects the handshake token
GAME_DUE: .res $2 ; the GAME_CLOCK time of the next logic update
GAME_SENT_LOGIC: .res $2 ; GAME_UPDATES when the last picture was sent
DEMO_PLAY = 1 ; CAB_DEMO: the attract demo plays its recorded controls
DEMO_END = 2 ; CAB_DEMO: the demo ended; the game waits frozen before the next scene
CAB_DEMO: .res $2 ; 0, DEMO_PLAY or DEMO_END
CAB_DEMO_POS: .res $2 ; cabinet_controls: the next cabinet_demo_controls entry
CAB_DEMO_HOLD: .res $1 ; cabinet_controls: the ticks left of the controls held now
CAB_BLINK: .res $1 ; the INSERT COIN blink count (BLINK_PERIOD)
CAB_PLANE_STEP: .res $1 ; cabinet_plane_tick: the next cabinet_plane_frames entry
CAB_PLANE_WAIT: .res $1 ; cabinet_plane_tick: the arcade ticks left of the step
CAB_WORLD_TARGET: .res $1 ; the world section that the attract asks for, or WORLD_NONE
CAB_KEYS: .res $1 ; cabinet_tick: SYSTEM_PRESSED of this update
CAB_ENDING_STEP: .res $1 ; the ending page of cabinet_ending_pages that shows
ENDING_PAGES = 1 ; CAB_ENDING: the ending pages show
ENDING_POST = 2 ; CAB_ENDING: the initials after the ending (cabinet_post)
CAB_ENDING: .res $1 ; 0, ENDING_PAGES or ENDING_POST
CAB_RESULT_ACTIVE: .res $1 ; nonzero: the stage result shows
CAB_RESULT_PHASE: .res $1 ; the stage result: 0 the result, 1 the statistics
CRD_STAGE = 0 ; CAB_RESULT_DATA: CAMERA_STAGE
CRD_RESULT = 1 ; AIR_RESULT
CRD_PERCENT = 2 ; AIR_PERCENT
CRD_BAND = 3 ; the award band: the bonus text
CRD_ENERGY = 4 ; the energy cap of the refill
CRD_REFILL = 5 ; RESULT_REMAIN: the energy the refill adds
CRD_LEVEL = 6 ; GAME_CONTINUE_LEVEL
CRD_FLAGS = 7 ; CRD_RETRY
CRD_RETRY = 1 ; CRD_FLAGS: the retry line
CRD_SIZE = 8 ; the bytes of CAB_RESULT_DATA
CAB_RESULT_DATA: .res CRD_SIZE ; the stage result to show (game_present_result)
RESULT_DIGITS_SIZE = $c ; CAB_RESULT_DIGITS, CAB_LIVE_SAVE
CAB_RESULT_DIGITS: .res RESULT_DIGITS_SIZE ; the glyphs of the result fields; also the initials and rank fields
CAB_ENDING_TEXT: .res $1 ; the typed characters of the cabinet text (the card draws them)
CAB_LAYOUT_LOADED: .res $1 ; the layout whose text list the card has
CAB_TEXT_PTR: .res $4 ; cabinet_text: the long address of the next text segment
CAB_TEXT_WAIT: .res $2 ; cabinet_text: the updates to the next character
CAB_TEXT_TARGET: .res $1 ; cabinet_text: the character count at the segment end
CAB_TEXT_FLAGS: .res $1 ; cabinet_text: the TF_* flags of the segment
CAB_TEXT_DONE: .res $1 ; 1: the cabinet text is complete
CAB_FLAG_TIME: .res $2 ; cabinet_actors: the time of the flag animation
CAB_FLY_TIME: .res $2 ; cabinet_actors: the time of the plane that flies by
CAB_FLY_X: .res $2 ; cabinet_actors: the position of the plane that flies by
CAB_DOG_INDEX: .res $2 ; cabinet_actors: the step of the dog animation
CAB_FLAG_PHASE: .res $2 ; cabinet_actors: the frame of the flag
CAB_TEXT_CLOCK: .res $2 ; cabinet_text: the updates since the text started (the actors use it)
CAB_ENDING_SCORES: .res $10 ; the scores of both players (SCORE_DIGITS each) through the cabinet pages
CAB_POST_MASK: .res $1 ; the players in the game at the end: POST_P1, POST_P2
CAB_POST_PHASE: .res $1 ; cabinet_post: 0, POST_OVER, POST_ENTRY or POST_RANK
CAB_POST_REMAIN: .res $2 ; cabinet_post: the updates left of the phase
CAB_POST_BLINK: .res $1 ; cabinet_post: the blink count of the phase
CAB_POST_LAYOUT: .res $1 ; the post layout that shows, or NO_LAYOUT
CAB_POST_ACTIVE: .res $1 ; the players that enter initials: POST_P1, POST_P2
CAB_POST_SLOT: .res $2 ; the new rank of each player, or NO_SLOT
CAB_POST_POS: .res $2 ; the initial position of each player (POS_END: the end choice)
CAB_POST_CURSOR: .res $2 ; the alphabet choice of each player
CAB_POST_MOVE: .res $2 ; the direction repeat count of each player
CAB_POST_FIRE: .res $2 ; the fire repeat count of each player
CAB_POST_NAMES: .res $6 ; the initials of both players (NAME_LENGTH each)
CAB_POST_QUALIFIED: .res $1 ; the players with a new rank: POST_P1, POST_P2
CAB_POST_PLAYER: .res $2 ; cabinet_post_insert: the player offset
CAB_POST_RANK: .res $2 ; cabinet_post_insert: the offset of the rank
CAB_POST_TEMP: .res $1 ; cabinet_post: work byte
CAB_POST_DIRTY: .res $1 ; 1: cabinet_post_append sends the job of the new layout
CAB_POST_HISTORY: .res $6 ; the alphabet choice of each initial (BACK restores it)
LIVE_ENTRY = 1 ; CAB_LIVE_STATE: the player enters the initials
LIVE_RANK = 2 ; CAB_LIVE_STATE: the new rank blinks
CAB_LIVE_STATE: .res $2 ; for each player: 0 idle, LIVE_ENTRY or LIVE_RANK
CAB_LIVE_TIMER: .res $4 ; two 16-bit update counts
CAB_LIVE_CLOCK: .res $2 ; two independent display clocks
CAB_LIVE_LAYOUT: .res $1 ; first state + three times second state
CAB_LIVE_VALUES: .res $c ; six selected glyphs per player
CAB_LIVE_SAVE: .res RESULT_DIGITS_SIZE ; preserves simultaneous stage-result fields
CAB_LIVE_NEW_RANK: .res $1 ; cabinet_live_begin: the new rank; cabinet_live_fields: work
CAB_LIVE_END: ; cabinet_live_reset clears CAB_LIVE_STATE to CAB_LIVE_END
WP_BASE: .res $2 ; weapon_fire: the first shot record of the player
WP_END: .res $2 ; weapons: the end of the record search or count
WP_STEP: .res $2 ; weapon_emit: the search step (one record or a pair)
WP_PLAN: .res $2 ; weapon_emit: the weapon_patterns entry of the next shot
WP_TEMPLATE: .res $2 ; weapon_emit: the weapon_templates entry of this shot
WP_DX: .res $1 ; weapon_emit: the extra cross offset of this shot
WP_CODE: .res $1 ; weapon_emit: nonzero: the sprite code of this shot
WP_LINK: .res $1 ; weapon_emit: the link byte of this shot (WE_LINK)
WP_OWNER: .res $1 ; weapon_fire: PL_NUMBER of the shooter (SHOT_OWNER)
PLAYER_AUX_SOUND: .res $1 ; player_aux: the sound request of this update (SND_WINGS), 0 none
PLAYER_AUX_PHASE: .res $1 ; the update count for player_aux: damaged wings flash on 3 of 4
CONTACT_KILL = 1 ; CONTACT_ACTION: the object dies by the contact
CONTACT_RETIRE = 2 ; CONTACT_ACTION: the object goes (a collected pickup)
CONTACT_SCORE = 4 ; CONTACT_ACTION: the object's owner (OBJ_OWNER) gets its score
CONTACT_ACTION: .res $1 ; the result of a body contact: CONTACT_* bits
CONTACT_SOUND: .res $1 ; player_contact, large_contact: the sound of the contact
CONTACT_DELTA: .res $1 ; player_contact, large_contact: the axis distance, then the damage or the variant
PLAYER_SPECIAL_LOCK: .res $1 ; nonzero (SPECIAL_TIMER): the special gate stays GATE_USED
INTERCEPT_SOUND: .res $1 ; bullet_intercept: the sound of a shot that ends a bullet, 0 none
PLAYER_PALETTE: .res $1 ; live_player_live_palette: the palette of the player (PL_NUMBER * 2)
ENEMY_RETIRE_X: .res $1 ; the place of the retired enemy (for its pickup)
SCORE_OWNER: .res $1 ; the player that gets the next score (score_add_owned)
PICKUP_KIND: .res $1 ; the PV_* kind of the new pickup
PICKUP_X: .res $1 ; the cross place of the new pickup
PICKUP_Y: .res $1 ; the along place of the new pickup
PICKUP_SLOT: .res $2 ; pickup_spawn: the slot of the new pickup
PICKUP_CHANGE_INDEX: .res $1 ; pickup_change: the next kind of a shot pickup
GUN_SOUND: .res $1 ; weapon_fire: the sound of the shot, 0 none; game_players_tick plays it
DOC_MASTER: .res $1 ; the DOC master volume (audio_game_init)
EK_KILLED = 1 ; ENEMY_KILLED: a shot killed the object
EK_RETIRE = 2 ; ENEMY_KILLED: the object goes without a death
ENEMY_KILLED: .res $1 ; enemy_shot_collision: 0, EK_KILLED or EK_RETIRE
ENEMY_HIT_SOUND: .res $1 ; enemy_shot_collision: the sound of a shot that hits an enemy, 0 none
GAME_RNG_SKIP: .res $1 ; nonzero: skip one random step (the arcade coin task misses a frame at a scene change)
GAME_BG2_DISABLED: .res $1 ; trailer $7BCE bit 0; no other flags
GAME_DIVE_ACTIVE: .res $1 ; number of players with transient dive pieces
SHOTS: .res SHOT_COUNT*SHOT_SIZE ; the player shot records
STAGE_FLAGS_SIZE = $40 ; the bytes of STAGE_FLAGS
STAGE_FLAGS: .res STAGE_FLAGS_SIZE ; original E140..E17F; stage_control_flag sets one by index
STAGE_SHIP_SCENE = STAGE_FLAGS+$05 ; E145: nonzero in the ship scene; a special there is Tsunami
STAGE_CORE_OWNER = STAGE_FLAGS+$07 ; E147: the player that destroyed the ship core
STAGE_PLAYER_REQUEST = STAGE_FLAGS+$09 ; E149: PS_DIVE or PS_LEAVE starts the departure of the players
STAGE_PLAYER_SPEED = STAGE_FLAGS+$0a ; E14A: the speed table of the players, 0-5
STAGE_FINISH = STAGE_FLAGS+$10 ; E150: nonzero from the ship finish to the takeoff; no special then
STAGE_CORE_ARMED = STAGE_FLAGS+$11 ; E151: the ship cores start the complete destruction at LARGE_THRESHOLD
STAGE_CORE_DOWN = STAGE_FLAGS+$12 ; E152: the ship core is destroyed; the air enemies retire
STAGE_TURRETS_FALL = STAGE_FLAGS+$13 ; E153: the turrets die and score for STAGE_CORE_OWNER
STAGE_BLAST_PATTERN = STAGE_FLAGS+$1c ; E15C: the ship_finish explosion pattern
STAGE_BLAST_SOURCE = STAGE_FLAGS+$1d ; E15D: 2 bytes, the record of the destroyed core
STAGE_RAID_WAIT = STAGE_FLAGS+$23 ; E163: updates before the next raid spawn
STAGE_BOSS_HOLD = STAGE_FLAGS+$24 ; E164: the boss fight keeps BG1 held; carrier kills count
STAGE_RESULT_REPEAT = STAGE_FLAGS+$25 ; E165: a failed boss result repeats with AIR_RESULT 3
STAGE_DIFFICULTY: .res $8 ; original E1D0..E1D7
STAGE_BULLET_BASE = STAGE_DIFFICULTY ; E1D0: the base of STAGE_BULLET_SLOTS
STAGE_SPEED_BASE = STAGE_DIFFICULTY+1 ; E1D1: the base row of stage_difficulty_values
STAGE_AIR_PASS = STAGE_DIFFICULTY+3 ; E1D3: the AIR_PERCENT that passes the air boss
STAGE_BULLET_SLOTS = STAGE_DIFFICULTY+4 ; E1D4: the enemy bullet slots, 0-16
STAGE_BULLET_SPEED = STAGE_DIFFICULTY+5 ; E1D5: the speed row of aimed bullets
STAGE_SPAWN_SLOTS = STAGE_DIFFICULTY+6 ; E1D6: the plane slots that spawns may use; 0 stops them
STAGE_DIP_LEVEL = STAGE_DIFFICULTY+7 ; E1D7: the difficulty DIP setting, 0-15
STAGE_BOSS_COUNT: .res $1 ; original E430
STAGE_CONTROL_INDEX: .res $1 ; build-selected index, 255 for other handlers
STAGE_GROUP_INDEX: .res $1 ; the event group of the stage (stage_dispatch)
STAGE_SAVED_CAMERA: .res $2 ; the camera at the air boss start (stage_control_boss_camera)
STAGE_SCROLL_TASK: .res $2 ; stage_scroll_tick: the scroll change that runs (SCROLL_ACCELERATE or SCROLL_DECELERATE)
STAGE_SCROLL_WAIT: .res $2 ; stage_scroll_tick: the updates to the next speed step
STAGE_SCROLL_STEP: .res $1 ; stage_scroll_tick: the speed steps left
STAGE_BOSS_PHASE: .res $1 ; E551
STAGE_SCROLL_END: ; stage_flow_init clears STAGE_SAVED_CAMERA to STAGE_SCROLL_END
SOUND_WRITE: .res $1 ; game_sound_request: the next free SOUND_QUEUE entry
SOUND_READ: .res $1 ; audio_request_tick: the next SOUND_QUEUE entry to play
SEQ_REPLAY = 1 ; STAGE_BANNER_TASK: the boss pass starts again (arcade task $2E3F)
SEQ_RESULT = 2 ; STAGE_BANNER_TASK: the boss result and its raid (arcade task $324D)
SEQ_BANNER = 3 ; STAGE_BANNER_TASK: a banner (arcade task $2778)
SEQ_INTRO = 4 ; STAGE_BANNER_TASK: the stage intro (arcade task $46E9)
STAGE_BANNER_TASK: .res $1 ; the next GAME_SEQUENCE (game_flow_tick); 0 none
STAGE_INPUT_P2: .res $1 ; stage_flow_init: INPUT_P2 at the stage start (the secret weapon)
STAGE_MUSIC: .res $1 ; the music of the stage (stage_control_music)
SOUND_QUEUE_SIZE = $20 ; a power of two
SOUND_QUEUE: .res SOUND_QUEUE_SIZE ; the sound commands for the sound interrupt
SHOT_ACTIVE: .res $24 ; eighteen slot offsets, stable for this tick
SHOT_ACTIVE_END: .res $2 ; wave_combat_tick: the end of the live shot records
SHOT_ACTIVE_P2: .res $2 ; wave_combat_tick: the first live shot record of player 2
SHOT_Y_MIN: .res $1 ; shot_prepare_y_bounds: the along limits of all live shots
SHOT_Y_MAX: .res $1 ; shot_prepare_y_bounds
SHOT_X_MIN: .res $1 ; shot_prepare_y_bounds: the cross limits of all live shots
SHOT_X_MAX: .res $1 ; shot_prepare_y_bounds
AIR_BOSS: .res $50 ; the air boss state (air_boss.s names its AIR_* fields); AIR_BOSS nonzero: it runs (arcade E1A0)
LARGE_GROUPS_SIZE = $30 ; the bytes of LARGE_GROUPS
LARGE_GROUPS: .res LARGE_GROUPS_SIZE ; original E570..E59F: the HP left of each boss part (OBJ_LEDGER)
LARGE_TOTAL: .res $1 ; original E553
LARGE_CAM_X: .res $1 ; original E419
LARGE_CAM_Y: .res $1 ; original E41A
LK_RETIRED = 1 ; LARGE_KIND: the object retired
LK_CALLBACK = 2 ; LARGE_KIND: a code tail (LARGE_CALLBACK) needs its decision
LARGE_KIND: .res $1 ; large_object_tick result: 0 moved, LK_RETIRED or LK_CALLBACK
LARGE_CALLBACK: .res $2 ; large_object_tick: the code tail of the step (LK_CALLBACK)
LARGE_RECORD: .res $2 ; large_loop_tick: the address of the large object (its D)
LARGE_SOURCE: .res $2 ; the motion step of the large object
LARGE_BANK: .res $2 ; the motion bank row of the large object (SCRIPT_BANK_ROWS)
LARGE_WORD: .res $2 ; large_object: work word
LARGE_AI_NEXT: .res $2 ; large_ai: the motion step that the decision selects
LARGE_THRESHOLD: .res $1 ; E552
LA_FINISH_LOOP = 1 ; LARGE_AI_ACTION: start the looping ship finish (arcade $32EA)
LA_FINISH_STOP = 2 ; LARGE_AI_ACTION: stop the ship finish
LA_FINISH_FINAL = 4 ; LARGE_AI_ACTION: start the final ship finish (arcade $32E2)
LA_EXPLOSION = 8 ; LARGE_AI_ACTION: a secondary explosion at LARGE_AI_X, LARGE_AI_Y
LA_KILL = 16 ; LARGE_AI_ACTION: the object dies
LA_BULLET = 32 ; LARGE_AI_ACTION: an aimed bullet
LA_SPREAD = 64 ; LARGE_AI_ACTION: a spread of bullets
LARGE_AI_ACTION: .res $1 ; large_ai result: LA_* bits; src/large_loop.s acts on them
LARGE_AI_SOUND: .res $1 ; large_ai: the sound request of the decision
LARGE_AI_X: .res $1 ; large_ai: the cross place of a bullet or a spawn
LARGE_AI_Y: .res $1 ; large_ai: the along place of a bullet or a spawn
LARGE_AI_FIRE: .res $1 ; 1..4 original turret pattern, zero none
LARGE_SPAWN_SLOT: .res $2 ; large_spawn: the slot of the new large object
LARGE_SPAWN_KIND: .res $2 ; large_spawn: the kind of the new large object
LARGE_SLOT: .res $2 ; the offset of the large object of the loop (LARGE_POOL)
LARGE_PENDING_ACTION: .res $2 ; large_loop_tick: the action that waits for the next object
SHIP_REQUEST: .res $1 ; the kind of the ship spawn, 1-4
SHIP_REQUEST_CROSS: .res $1 ; large_loop_tick: the cross place for ship_spawn
SHIP_REQUEST_ALONG: .res $1 ; large_loop_tick: the along place for ship_spawn
SHIP_DEST: .res $2 ; ship_spawn: the record of the new part
SHIP_TEMPLATE: .res $2 ; ship_spawn: the template of the new part
SHIP_FRAGMENT: .res $2 ; ship_spawn: the fragment of the secondary part
GIANT_BASE: .res $2 ; giant_object_tick: the record of the giant's head
GIANT_WORD: .res $2 ; giant_object: work word
GIANT_SCRIPT: .res STEP_SIZE ; giant_object_script: the motion step
MEDIUM_RANDOM: .res $1 ; original E00C, supplied by the logic tick
MEDIUM_SHOT_ANGLE: .res $1 ; the direction of the next AIF_ANGLE or spread bullet
CONTACT_LIMIT: .res $2 ; large_contact: the end of the contact list
CONTACT_CENTER_X: .res $1 ; large_contact_center: the cross centre of the large object
CONTACT_CENTER_Y: .res $1 ; large_contact_center: the along centre of the large object
SF_LOOP = 1 ; SHIP_FINISH_ACTIVE: the looping ship finish runs
SF_FINAL = 2 ; SHIP_FINISH_ACTIVE: the final ship finish runs
SF_GIANT = 3 ; SHIP_FINISH_ACTIVE: a giant finish waits
SHIP_FINISH_ACTIVE: .res $1 ; 0 idle, SF_LOOP, SF_FINAL or SF_GIANT
SHIP_FINISH_WAIT: .res $1 ; ship_finish_tick: the ticks to the next piece
SHIP_FINISH_INDEX: .res $1 ; ship_finish: the piece of the list
SHIP_FINISH_PATTERN: .res $1 ; ship_finish: the pattern (STAGE_BLAST_PATTERN)
SHIP_FINISH_OWNER: .res $2 ; ship_finish: the destroyed core (its record)
SHIP_FINISH_KIND: .res $2 ; 0 four pieces, 1 sixteen pieces
SHIP_FINISH_DEST: .res $2 ; ship_finish_spawn: the record of the new explosion
SHIP_FINISH_PATH: .res $2 ; ship_finish_select_path: the address of the piece
SHIP_FINISH_OFFSET: .res $2 ; ship_finish: work: the piece offset, then the along offset
SHIP_FINISH_Y: .res $2 ; ship_finish_spawn: the 9-bit along place
TURRET_KIND: .res $2 ; the kind of the turret that aims
TURRET_INPUT: .res $2 ; original E250/E251, active-low P1/P2
TURRET_FIRE: .res $1 ; explicit request: speed class 1 or 2
TURRET_ANGLE: .res $1 ; the direction of the turret bullet
TURRET_SPAWN_ID: .res $2 ; stage_dispatch: the turret of the event (turret_spawn)
TURRET_GROUP: .res $1 ; original E560
TURRET_RETRY: .res $1 ; original E551
TURRET_DEST: .res $2 ; turret_spawn: the record of the new turret
TURRET_SPAWN_X: .res $1 ; turret_spawn: the cross place of the new turret
TURRET_TEMPLATE: .res $2 ; turret_spawn: the template of the new turret
BOSS_CONFIG: .res $2 ; boss_core_lookup: the boss core entry of the stage
GUN_OVERFLOW: .res SHOT_SIZE ; weapon_emit: a shot with no free record goes here (no effect)
BULLET_SCRATCH: .res $4 ; the bullet spawns: X points here when no bullet comes, so the caller's write has no effect
SIMPLE_PLAN: .res $2 ; simple_spawn: the spawn plan
SIMPLE_SLOT: .res $2 ; game_pair_wave: the slot of the pair
SIMPLE_LIMIT: .res $2 ; the end of the slots that the spawn may use
SIMPLE_LEFT: .res $2 ; simple_spawn: the records of the plan still to place
FORMATION_TYPE: .res $1 ; FT_*: the row of formation_paths
FORMATION_ODDS: .res $1 ; formation_ai: the fire chance of the formation
SIMPLE_TEMPLATE: .res $2 ; simple_spawn: the template of the record
SIMPLE_PATCHES: .res $1 ; simple_spawn: the patches of the plan record
SIMPLE_DEST: .res $2 ; simple_spawn: the new record
SIMPLE_GROUP: .res $1 ; simple_spawn: the group of the wave
EXTENDED_PLAN: .res $2 ; extended_spawn: the spawn plan
EXTENDED_DEST: .res $2 ; extended_spawn: the new record
EXTENDED_FLAGS: .res $1 ; extended_spawn: the flags of the plan record
EXTENDED_LEFT: .res $1 ; extended_spawn: the records of the plan still to place
EXTENDED_TEMPLATE: .res $2 ; extended_spawn: the template of the record
GROUND_KILL: .res $1 ; ground_ai: nonzero: the ground object is killed this tick
GROUND_SPEED: .res $1 ; the speed of the next ground bullet
GROUND_ANGLE: .res $2 ; the direction of the next ground bullet
GROUND_KIND: .res $2 ; GK_*: the offset of the tail in ground_callback_ids
GAME_RAM_END: ; game.s clears PLAYER to here at the start

.segment "POOLRAM"
ENEMY_COUNT = 16 ; the primary small objects
BULLET_COUNT = 16 ; the enemy bullets
LARGE_COUNT = 12 ; the large objects (four-piece records)
EXTENDED_COUNT = 17 ; the secondary small objects
ENEMY_POOL: .res ENEMY_COUNT*OBJECT_SIZE ; the small objects (EXTENDED_POOL further on)
BULLETS: .res BULLET_COUNT*OBJECT_SIZE ; the enemy bullet records
LARGE_POOL: .res LARGE_COUNT*LARGE_SIZE ; the large objects
EXTENDED_POOL: .res EXTENDED_COUNT*OBJECT_SIZE ; the extended small objects
POOLS_END: ; the pools from ENEMY_POOL to here are cleared together

; Bank 1. DBR=$01 code uses these with absolute addressing; other code uses f:.
MUSIC_PART_SIZE = 32 ; a music part record (src/music_player.s)
MUSIC_SLOT_SIZE = 6*MUSIC_PART_SIZE ; the six parts of a song
MUSIC_SLOTS = 4 ; the songs that can play (by priority)
SSG_PARTS = 6 ; the SSG effect voices
SSG_PART_SIZE = 32 ; an SSG part record (src/audio_ssg.s)
FM_PARTS = 6 ; the FM voices
FM_PART_SIZE = 64 ; an FM part record (src/fm_voice.s)
FM_CAPTURES = 76 ; the FM captures (scripts/fm_native.py)
FM_PAGES = 144 ; the FM cache pages
.segment "BANK1RAM"
MUSIC_STATES: .res MUSIC_SLOTS*MUSIC_SLOT_SIZE ; a song plays in the slot of its priority
SSG_STATES: .res SSG_PARTS*SSG_PART_SIZE ; the state of each SSG effect voice (audio_ssg)
SSG_PHASES: .res 8 ; audio_ssg: the parts due at each SSG_TIME & 7 (the delays are multiples of SSG_DELAY_UNIT = 8)
FM_STATES: .res FM_PARTS*FM_PART_SIZE ; the state of each FM voice (fm_voice)
FM_CACHE_PTR: .res $3 ; the shared capture directory of the active song
FM_CACHE_GEN: .res $1 ; changed by the IRQ when the song changes
FM_CACHE_UPGEN: .res $1 ; the generation of the main-loop upload
FM_CACHE_DONE: .res $1 ; entries completely in DOC
FM_CACHE_COUNT: .res $1 ; fm_voice: the cached FM pages of the song
FM_CACHE_INITIAL: .res $1 ; fm_song_start: the pages that must be in before the song starts
FM_CACHE_RESUME: .res $1 ; nonzero: the song resumes on the pages in the cache
FM_CACHE_LIST: .res $22 ; 2-byte header and up to 16 capture/page pairs
FM_LOOK_HINT: .res $1 ; main-loop stage lookahead requested
FM_LOOK_INDEX: .res $1 ; next safe boss-preload capture
FM_UP_KIND: .res $1 ; 0 current song, 1 lookahead
FM_ACTIVE_SONG: .res $1 ; score entry with phase bit cleared
FM_LOOK_KIND: .res $1 ; lookahead identity when index was reset
FM_UP_PAGE: .res $1 ; actual start page of the current upload
FM_UP_END: .res $1 ; exclusive end page of the current upload
FM_OWNER_START: .res $1 ; main-loop owner lookup scratch
FM_OWNER_END: .res $1 ; fm_upload_local_reserve_page: the end of the owned pages
PHASE_ARM = 1 ; FM_PHASE_WAIT: fm_song_wait sets FM_PHASE_DUE
PHASE_DUE = 2 ; FM_PHASE_WAIT: the late capture waits for FM_PHASE_DUE
FM_PHASE_WAIT: .res $1 ; 0, PHASE_ARM or PHASE_DUE (fm_voice.s)
FM_PHASE_DUE: .res $2 ; earliest safe $2E capture-65 upload tick
FM_PRESERVED_OLD: .res $1 ; score retained across repeated $2E cues
FM_SHORT_FLAGS: .res $1 ; shortened $2E capture-35/67 residency
FM_UP_ACTIVE: .res $1 ; main-loop upload in progress
FM_UP_SRC: .res $3 ; the FM page upload: the source
FM_UP_DST: .res $2 ; the FM page upload: the destination page
FM_UP_LEFT: .res $2 ; the FM page upload: the bytes left
FM_UP_CAP: .res $2 ; the FM page upload: the capture (CAP_*) that it loads
FM_WAIT: .res $1 ; song start: score held until first tables load
FM_TICK: .res $1 ; score tick (low byte): visit schedule
SMF_DUE = $80 ; START_MUSIC_FLAGS: the start music plays again at START_MUSIC_DUE
SMF_SMOOTH = $40 ; START_MUSIC_FLAGS: the FM notes sound until the next score starts
SMF_PRELOAD = $20 ; START_MUSIC_FLAGS: load the title music when the sound is idle
SMF_SKIPS = $03 ; START_MUSIC_FLAGS: stage 0 start music events still to skip
START_MUSIC_FLAGS: .res $1 ; SMF_* bits (audio_game.s, music_player.s)
START_MUSIC_DUE: .res $2 ; DOC tick at which the opening cue repeats
FM_UP_PACKED: .res $1 ; the FM page upload: nonzero: the source is packed
FM_UP_PREV: .res $1 ; fm_unpack_chunk: the last sample
FM_UP_BITS: .res $1 ; fm_unpack_chunk: the bits of the block
FM_UP_BLOCKS: .res $1 ; fm_unpack_chunk: the blocks left
FM_UP_AMOUNT: .res $2 ; fm_upload_local_advance: the bytes of this step
FM_UP_PAIRS: .res $1 ; number of packed pairs remaining
FM_HELD: .res $30 ; per part, voice: freq lo, hi, table, size
FM_RESIDENT: .res FM_CAPTURES ; the capture-completion flags
FM_PAGE_OWNER: .res FM_PAGES ; for each FM page: the capture ID + 1, 0 empty
FM_PAGE_OWNER_END: ; fm_voice_init clears FM_RESIDENT to here
WORLD_LZ_OUTPUT: .res $410 ; each encoded token expands at most 32 bytes (src/world_lz.s)
WLS_INFLATE = 1 ; WORLD_LZ_STATE: a section inflates
WLS_READY = 2 ; WORLD_LZ_STATE: the inflated batch is ready
WORLD_LZ_STATE: .res $1 ; 0, WLS_INFLATE or WLS_READY
WL_IN: .res $2 ; the next encoded byte
WL_OUT: .res $2 ; the next output byte
WL_FINAL: .res $2 ; the output length
FM_RESIDENT_END: .res FM_CAPTURES ; the end page of each capture
BANK1_RAM_END: ; game.s clears MUSIC_STATES to here at the start
