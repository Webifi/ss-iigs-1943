; The arcade sound commands. game_sound_request (src/audio_game.s) queues
; one. $01-$1E and $3A start an SSG effect, $20-$32 an FM piece. The names
; come from the code that requests each command.
SND_STOP_ALL        = $00       ; stop the FM piece and the SSG effects
SND_GUN             = $01       ; standard and AUTO guns
SND_SHOTGUN         = $02       ; the SHOT GUN
SND_BULLET_STRIKE   = $02       ; a bullet hits a player who keeps some energy
SND_3WAY            = $03       ; the 3 WAY gun
SND_SHELL           = $04       ; the SHELL gun
SND_PLAYER_DOWN     = $05       ; the energy of a player is gone
SND_PLAYER_HIT      = $06       ; a player is hit and keeps some energy
SND_PICKUP          = $07       ; a player collects a pickup
SND_EXPLOSION       = $08       ; the air boss core is destroyed
SND_LOW_ENERGY      = $0A       ; the low energy alarm (it repeats until SND_STOP_EFFECTS)
SND_TALLY           = $0B       ; energy sharing; the stage result tally
SND_TURRET_SHOT     = $0C       ; ship turrets fire
SND_GIANT_KILL      = $0D       ; a shot kills a giant
SND_ENEMY_KILL      = $0E       ; a shot kills an enemy
SND_BULLET_HIT      = $0F       ; a shot ends an enemy bullet or kills a large object
SND_DIVE            = $10       ; the player dives into the ship scene
SND_TEXT_SEGMENT    = $11       ; a cabinet text segment with flag bit 7
SND_COIN            = $12
SND_ENEMY_HIT       = $13       ; a shot hits an enemy that lives; a cabinet text letter
SND_COUNTDOWN       = $14       ; the continue countdown starts at 10
SND_RESPAWN         = $15       ; the player reaches the field again
SND_LIGHTNING       = $15       ; the Lightning special
SND_TSUNAMI         = $16       ; the Tsunami special
SND_CYCLONE         = $17       ; the Cyclone special
SND_WINGS           = $18       ; the wing planes arrive
SND_START_EFFECT    = $19       ; the effect part of the start music
SND_BOSS_PART       = $1A       ; a boss part is destroyed
SND_LOOP            = $1B       ; the paid loop
SND_BOSS_DOWN       = $1C       ; the air boss core is destroyed, after SND_EXPLOSION
SND_SHIP_EXPLODE    = $1D       ; a ship core explodes
SND_LASER           = $1E       ; the LASER gun
SND_STOP_EFFECTS    = $1F       ; stop the SSG effects
SND_FM_FIRST        = $20       ; the first FM piece
SND_START_MUSIC     = $20       ; the start music
SND_GAME_OVER       = $28       ; the cabinet game over
SND_BOSS_RESULT     = $29       ; the boss result starts (stage_control_boss_result)
SND_BOSS_MUSIC      = $2A       ; air boss scenes 1 and 2 (stage_control_boss_camera)
SND_CLEAR_MUSIC     = $2B       ; a stage passed (stage_end)
SND_CLEAR_REPLAY    = $2C       ; a stage passed in a replay pass (stage_end)
SND_RESULT_MUSIC    = $2D       ; a stage failed (stage_end)
SND_CONTINUE_MUSIC  = $2E       ; game over and the continue prompt
SND_SHAKE_END       = $30       ; the camera shake ends
SND_BOSS3_MUSIC     = $31       ; air boss scene 3 (stage_control_boss_camera)
SND_SHIP_FINISH     = $3A       ; the ship is finished
SND_STOP_MUSIC      = $3F       ; stop the FM piece ($33-$3F except $3A)
; Not an arcade command: game_sound_request stops the effects and keeps the
; FM notes until the next piece starts (audio_game.s).
SND_SMOOTH_STOP     = $3E
