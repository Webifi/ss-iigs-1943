; Record fields of the arcade game state that the port keeps in the arcade
; layout. The routines point D at a record and read its fields as page zero.

; Arcade code and data addresses below ARCADE_BANK_WINDOW are in the fixed
; ROM; from it on they are in the selected ROM bank (OBJ_BANK_BITS).
ARCADE_BANK_WINDOW  = $8000
ARCADE_BANK_END     = $C000

; A hardware sprite: the first four bytes of each 32-byte record. The card
; reads them to draw the sprite. Cross and along are the game axes of the
; vertical screen: the along axis is the scroll direction.
SPR_CODE            = $00       ; sprite code, low eight bits
SPR_ATTR            = $01       ; bits 0-3: SPR_COLOUR; bit 4: SPR_ALONG_HIGH
SPR_COLOUR          = $0f       ; the SPR_ATTR bits of the palette
SPR_CROSS           = $02       ; cross coordinate, integer
SPR_ALONG           = $03       ; along coordinate, integer
SPR_HIDDEN          = $ff       ; SPR_ALONG of a sprite that is off the field
SPRITE_SIZE         = $20       ; one record; large objects and players use four
SPRITE_HALF         = 8         ; the centre of a 16-pixel sprite is this far from its corner

; An object record: enemy bullets, small, large and giant objects
; (pool_record.s). Bytes 0-3 are its first sprite.
OBJ_DURATION        = $04       ; motion steps left in this motion record
OBJ_CROSS_FRACTION  = $05
OBJ_ALONG_FRACTION  = $06
OBJ_WAVE_COUNTER    = $07       ; small objects: wave counter index; 0 none
OBJ_TYPE            = $08       ; 0 free, else OT_* (+1 for some kinds)
OBJ_FLAGS           = $09       ; bit 0 player contact, bit 1 shot collision, bit 2 camera follow
OBJ_VARIANT         = $0A       ; high nibble motion bank; low nibble PV_*: contact or pickup
VARIANT_BITS        = $0f       ; the OBJ_VARIANT bits of the variant
; The contact variants (arcade table $57C0)
PV_ENEMY            = 0         ; contact damages the player
PV_ENERGY           = 1         ; +ENERGY_PICKUP energy
PV_SCORE            = 2         ; the object's score
PV_ENERGY_FULL      = 3         ; energy up to ENERGY_MAX
PV_ENERGY_BIG       = 4         ; +ENERGY_PICKUP_BIG energy
PV_WINGS            = 5         ; the wing planes arrive
PV_SHOTGUN          = 6         ; SHOT GUN; a second one upgrades it
PV_3WAY             = 7         ; PV_3WAY to PV_LASER: player_pickup_weapons
PV_LASER            = 10
PV_SCORE_B          = 11
PV_TIME             = 12        ; weapon time WEAPON_TIME_MAX and the score
PV_SCORE_D          = 13
PV_MARKER           = 14        ; the first contact transforms the object
ENERGY_PICKUP       = 8
ENERGY_PICKUP_BIG   = 24
WEAPON_PICKUP_TIME  = 20        ; a weapon pickup adds this weapon time
WEAPON_TIME_MAX     = 64
OBJ_BANK_BITS       = $70       ; OBJ_VARIANT: the motion bank
OBJ_PICKUP_BITS     = $0f       ; OBJ_VARIANT: the PV_* kind; PV_ENEMY is not a pickup
OBJ_HP              = $0B       ; hit points; contact damage comes from it
OBJ_CROSS_RADIUS    = $0C
OBJ_ALONG_RADIUS    = $0D
OBJ_OWNER           = $0E       ; the player that gets the score: 1, 2, or 0 none
OBJ_LEDGER          = $0F       ; boss part ledger ID; 0 none
OBJ_FAMILY          = $10       ; $10-$16: family bytes; each family file names its own
OBJ_DROP            = $15       ; small objects: the drop: PICKUP_KIND, with DROP_WAIT; some paths depend on it
DROP_WAIT           = $f0       ; OBJ_DROP: the drop comes with the last plane of the wave
OBJ_AIM             = $16       ; the 32-way direction to the target player (ai_target)
; Family bytes of the turrets (src/later_turrets.s, src/ship_turrets.s).
TURRET_BARREL       = $10       ; the barrel direction, 0-31
TURRET_DELAY        = $11       ; decisions left before the next shot
TURRET_SHOT         = $12       ; the shot of this burst: the muzzle or the speed entry
CORE_TURRET_STEP    = $10       ; ship_turret: counts 0-5; the turret fires at 0
CORE_TURRET_SHOTS   = $11       ; ship_turret: shots of this cycle; four end it
CORE_TURRET_FIRE    = $12       ; ship_turret: the fire request, less one
OBJ_SCORE           = $17       ; offset of the last digit of the score value
OBJ_CROSS_DELTA     = $18       ; signed 8.8 step: the integer, then the fraction
OBJ_ALONG_DELTA     = $1A       ; signed 8.8 step: the integer, then the fraction
OBJ_PREDECESSOR     = $1C       ; 2 bytes: the death script predecessor
OBJ_MOTION          = $1E       ; 2 bytes: the current motion record
OBJECT_SIZE         = $20
; Object types (OBJ_TYPE)
OT_SMALL            = $10
OT_LARGE            = $20
OT_TURRET           = OT_LARGE+1 ; a ship turret (a bank-6 template)
OT_GIANT            = $40
; Object flags (OBJ_FLAGS)
OF_CONTACT          = $01       ; the object can hit a player
OF_SHOT             = $02       ; player shots can hit the object
OF_CAMERA           = $04       ; the camera move replaces the object's own move
; SPR_ATTR bit 4: the along coordinate is past 255, off the field.
SPR_ALONG_HIGH      = $10

; A motion step (the arcade motion records that OBJ_MOTION points at). A
; first byte of 0 is a code tail (a word follows), $FF a jump (a word
; follows), $FE the end.
STEP_DURATION       = 0
STEP_CODE           = 1         ; the sprite code, then the attributes
STEP_ATTR           = 2
STEP_CROSS_DELTA    = 3         ; signed 8.8, low byte first
STEP_ALONG_DELTA    = 5         ; signed 8.8, low byte first
STEP_SIZE           = 7
STEP_TAIL_SIZE      = 3         ; a tail or jump step: the byte, then a word
STEP_TAIL           = $00
STEP_JUMP           = $FF
STEP_END            = $FE
; enemy_script_pages (scripts/enemy_script.py): one 16-bit row for each
; 256-byte motion page (its address in bank ENEMY_SCRIPT_FAST_BANK); bank n
; has the rows from n*SCRIPT_BANK_ROWS, the fixed ROM the rows from
; SCRIPT_FIXED_ROW.
SCRIPT_BANK_ROWS    = 64
SCRIPT_FIXED_ROW    = 8*SCRIPT_BANK_ROWS
; A large object: four object-sized records, the object fields in the first.
PIECE_RISE          = 16        ; an upper piece of a large object is this far further along
LARGE_SIZE          = 4*OBJECT_SIZE
; A giant object: sixteen sprite records in one group; the object fields are
; in the head record at GIANT_HEAD.
GIANT_HEAD          = 4*OBJECT_SIZE
GIANT_SIZE          = 16*OBJECT_SIZE

; A player record: four sprite records, the body at +0 and +PL_BODY2, the
; wings at +PL_LEFT_WING and +PL_RIGHT_WING. P1 is at PLAYER, P2 at PLAYER2
; (src/flight.s). The logic fields use the bytes that the card does not read.
PL_WINGS            = $04       ; low nibble: WINGS_*; high nibble: the state after the arrival
WINGS_STATE         = $0f       ; the PL_WINGS bits of the state
WINGS_ON            = 1         ; bit 0 set: the wing planes fly with the player
WINGS_COMING        = 2
WINGS_DAMAGED       = 3         ; on, and they flash
WINGS_LEAVING       = 4
WINGS_EXPLODE       = 8
PL_NUMBER           = $05       ; 0 P1, 1 P2
PL_ENERGY           = $06
PL_COLLIDE          = $07       ; nonzero: enemies and bullets can hit the player
PL_STATE            = $08       ; PS_* below
PL_BANK_INDEX       = $09       ; the banking delay of flight_delays
PL_POSE             = $0A       ; the bank pose: sprite code offset
PL_BANK_DELAY       = $0B       ; updates left before the next pose step
PL_DIRECTION        = $0C       ; the stick direction of the last update
PL_DRAIN            = $0D       ; counts to DRAIN_TICKS, then one energy goes; bit 0 picks the speed half
DRAIN_TICKS         = $a0
PL_HIT              = $0E       ; nonzero: the hit roll runs
PL_SHADOW           = $0F       ; the body is over a BG1 shadow tile
PL_CROSS_RADIUS     = $10
PL_ALONG_RADIUS     = $11
PL_FIRING           = $12       ; updates left of the firing sprite
PL_SHARE_DELAY      = $13       ; energy sharing between the players: the overlap counter
PL_IMMUNE           = $14       ; updates left before PL_COLLIDE comes back after a respawn
PL_DIVE_CLIMB       = $1A       ; dive: $FF while the player climbs back
PL_PROMPT           = $28       ; the continue task: PROMPT_*
PROMPT_COUNTDOWN    = $01       ; the CONTINUE countdown
PROMPT_OVER_ON      = $02       ; GAME OVER shows (it blinks)
PROMPT_OVER_OFF     = $04       ; GAME OVER is off
PROMPT_INITIALS     = $08       ; the initials
PROMPT_OVER_BITS    = $0e       ; no start while one of these runs
PROMPT_ON           = $10       ; the join prompt shows
PROMPT_OFF          = $20       ; the join prompt is off
PL_PROMPT_DELAY     = $29       ; updates left of this prompt step
PL_COUNTDOWN        = $2A       ; the continue countdown digit
PL_SCORE            = $38       ; SCORE_DIGITS unpacked decimal digits, the most significant first
SCORE_DIGITS        = 8
PL_WEAPON_INIT      = $50       ; the weapon that weapon_change last set up
PL_WEAPON           = $51       ; the selected weapon mode: WEAPON_*
PL_SHOTS            = $53       ; live shots of this player
PL_CADENCE          = $54       ; the fire cadence byte: a shot when it reaches 0 or carries
CADENCE_START       = $f8       ; PL_CADENCE after a weapon change or a released button
PL_WEAPON_GATE      = $55       ; the special button gate: GATE_ARMED lets it start a special
GATE_READY          = $fc       ; player_live_before sets these bits each tick (no lock)
GATE_RELEASED       = $03       ; game_players_tick sets these while button 2 is up
GATE_ARMED          = $ff       ; GATE_READY and GATE_RELEASED: a special or a loop may start
GATE_USED           = $f0       ; after a special or a loop, and during PLAYER_SPECIAL_LOCK
GATE_OPEN           = $0f       ; any of these bits: button 2 starts a special
PL_BURST            = $56       ; AUTO: shots of this burst
PL_WEAPON_TIME      = $57       ; weapon time left; WEAPON_ENDLESS: no limit
WEAPON_ENDLESS      = $ff
PL_WEAPON_DIVIDER   = $58       ; counts WEAPON_DIVIDER updates for each PL_WEAPON_TIME step
WEAPON_DIVIDER      = 60
PL_BODY2            = $20
PL_LEFT_WING        = $40
PL_RIGHT_WING       = $60
PLAYER_SIZE         = $80
; PL_WEAPON modes (the names of the game's own weapon labels)
WEAPON_AUTO         = $01
WEAPON_SHOTGUN      = $02
WEAPON_SHOTGUN_UP   = $03       ; the upgraded SHOT GUN
WEAPON_3WAY         = $04
WEAPON_SHELL        = $08
WEAPON_LASER        = $10
; PL_STATE values
PS_INACTIVE         = $00
PS_LIVE             = $02
PS_DEATH            = $04
PS_RESPAWN          = $06
PS_DIVE             = $08
PS_LOOP             = $0A
PS_LEAVE            = $0C       ; leave the field after a boss
PS_LANDING          = $0E
PS_TAKEOFF          = $10
; $1B-$1F of each player sprite record: the work bytes of the animation that
; runs on it. Each animation names its own.
ANIM_WORK           = $1B
ANIM_WORK_SIZE      = 5
CODE_ROW            = 8         ; the sprite code of the piece above is the code + 8

; A player shot record (SHOTS, src/projectiles.s): 18 records, 9 for each
; player. Bytes 0-3 are its sprite.
SHOT_CROSS_STEP     = $04       ; the cross step of each move
SHOT_ALONG_STEP     = $05       ; the along step of each move
SHOT_CROSS_RADIUS   = $06
SHOT_ALONG_RADIUS   = $07
SHOT_STATE          = $08       ; SHOT_FREE, SHOT_FLYING or SHOT_IMPACT
SHOT_OWNER          = $09       ; PL_NUMBER of the player
SHOT_LIFE           = $0A       ; moves left
SHOT_DELAY          = $0B       ; updates left before the first move
SHOT_DAMAGE         = $0D       ; damage left; a kill takes the target's HP from it
SHOT_PAIRED         = $0E       ; nonzero: the impact goes to the linked half too
SHOT_LINK           = $0F       ; the linked half: 0 the next record, 1 the previous one
SHOT_ANIM_TIME      = $1B       ; impact animation: updates left of this frame
SHOT_ANIM_STEP      = $1C       ; impact animation: the next frame
SHOT_SIZE           = $20
SHOT_COUNT          = 18
SHOTS_PER_PLAYER    = 9         ; P1 has the first nine records
; SHOT_STATE values
SHOT_FREE           = 0
SHOT_FLYING         = 2
SHOT_IMPACT         = 4         ; the impact animation runs
