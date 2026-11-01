; The decisions of the air boss parts (D = the record): the core, the guns
; and the pieces that fall off as the core loses its lives.
.a8
.i16
AIR_TIME_LIMIT = 51          ; AIR_SECONDS: after this the boss leaves (AR_FAILED)
AIR_DOWN = $80               ; AIR_BOSS: the core is destroyed
AIR_DOWN_P2 = $40            ; AIR_BOSS: player 2 destroyed it
CORE_WIDE = $50              ; the core's OBJ_CROSS_RADIUS when it is wide
CORE_NARROW = $10            ; the radius across it when narrow, along it when wide
CORE_TALL = $40              ; the core's OBJ_ALONG_RADIUS when it is narrow
CORE_SHIFT = 16              ; the core moves this far along when it turns
CORE_HP = $40                ; OBJ_HP after each hit
FAN_DELAY = 200              ; decisions between two fans
FAN_SHOTS = 5                ; air_fan_offsets entries
CORE_GUN_ALONG = $58         ; the fan comes from this far above the core
SIDE_GUN_CROSS = 8           ; the side guns are this far to each side
SIDE_DELAY = 60              ; decisions between two side shots
AIR_BLAST_PATTERN = 8        ; STAGE_BLAST_PATTERN of the core explosion
AIR_GUN_CYCLE = 30           ; air_gun_tick: decisions between two bursts
AIR_GUN_SHOTS = 3            ; the barrel, then one to each side
AIR_PIECES = 3               ; air_piece_templates: the parts of a falling piece

; The family bytes of the object record, by part.
AIR_CORE_LIFE = $10          ; air_core: hits left; AIR_LIFE keeps a copy
AIR_CORE_TIMER = $11         ; air_core: decisions before the next fan; bit 0 turns the core
AIR_SIDE_DELAY = $12         ; air_core: decisions before the next side shot
AIR_FAN_DIRECTION = $13      ; air_core: the middle direction of the fan
AIR_PIECE_LIFE = $11         ; air_piece_tick: the piece falls when AIR_LIFE comes to this
AIR_GUN_BARREL = $10         ; air_gun_tick: the barrel direction, 0-31
AIR_GUN_TIME = $11           ; air_gun_tick: counts 0-29; the gun fires at 0

; Motion code tails (AI_TAIL).
TAIL_AIR_EXPLOSION = $5b18     ; fixed
TAIL_AIR_EXPLOSION_P2 = $5b60  ; fixed
TAIL_AIR_PIECE_TICK = $81e6    ; bank 4
TAIL_AIR_PIECE_A = $82c6       ; bank 4
TAIL_AIR_PIECE_B = $82cc       ; bank 4
TAIL_AIR_PIECE_C = $82d2       ; bank 4
TAIL_AIR_CORE_TICK = $aa94     ; bank 0
TAIL_AIR_CORE_HIT = $ab09      ; bank 0
TAIL_AIR_GUN_TICK = $bcb5      ; bank 0

; Motion records (AI_NEXT).
MOTION_AIR_GUN_DOWN = $5a3b    ; fixed
MOTION_AIR_PIECE = $8206       ; bank 4
MOTION_AIR_PIECE_A = $82e6     ; bank 4
MOTION_AIR_PIECE_B = $82fe     ; bank 4
MOTION_AIR_PIECE_C = $8316     ; bank 4
MOTION_AIR_CORE = $aba2        ; bank 0
MOTION_AIR_CORE_DOWN = $abaf   ; bank 0
; airboss_enemy_ai: the decision of AI_TAIL for an air boss part
; (formation_extra). Returns carry 1 with AI_NEXT, or carry 0. JSL.
airboss_enemy_ai:
  a16
  lda AI_TAIL
  cmp #TAIL_AIR_EXPLOSION
  beq @burst_one
  cmp #TAIL_AIR_EXPLOSION_P2
  bne @bank
  lda #MOTION_OWNER_EXPLOSION_P2
  bra @burst
@burst_one:
  lda #MOTION_OWNER_EXPLOSION
@burst:
  sta AI_NEXT
  a8
  lda STAGE_CORE_DOWN
  beq :+
  jmp .loword(air_enemy_retire)
:
  sec
  rtl
@bank:
.a16
  a16
  lda z:OBJ_VARIANT
  and #OBJ_BANK_BITS
  beq @zero
  cmp #4<<4                     ; motion bank 4
  bne @unknown
  lda AI_TAIL
  cmp #TAIL_AIR_PIECE_TICK
  bne :+
  jmp .loword(air_piece_tick)
:
  cmp #TAIL_AIR_PIECE_A
  bne :+
  lda #MOTION_AIR_PIECE_A
  bra @piece_path
:
  cmp #TAIL_AIR_PIECE_B
  bne :+
  lda #MOTION_AIR_PIECE_B
  bra @piece_path
:
  cmp #TAIL_AIR_PIECE_C
  bne @unknown
  lda #MOTION_AIR_PIECE_C
@piece_path:
  sta AI_NEXT
  a8
  lda AIR_BOSS
  beq air_enemy_retire
  lda AIR_LIFE
  beq air_enemy_retire
  sec
  rtl
@zero:
.a16
  lda AI_TAIL
  cmp #TAIL_AIR_CORE_TICK
  bne :+
  jmp .loword(air_core_tick)
:
  cmp #TAIL_AIR_CORE_HIT
  bne :+
  jmp .loword(air_core_hit)
:
  cmp #TAIL_AIR_GUN_TICK
  bne @unknown
  jmp .loword(air_gun_tick)
@unknown:
  a8
  clc
  rtl
; air_enemy_retire: the part goes; carry 1. air_enemy_path: AI_NEXT = A.
air_enemy_retire:
.a8
  stz z:SPR_CODE
  stz z:SPR_CROSS
  stz z:OBJ_TYPE
  sec
  rtl
air_enemy_path:
.a16
  sta AI_NEXT
  a8
  sec
  rtl

; air_core_tick: the core: after AIR_TIME_LIMIT it leaves (AIR_PERCENT = 10
; for each life taken); bit 0 of AIR_CORE_TIMER turns it wide or narrow;
; every FAN_DELAY decisions a fan of FAN_SHOTS; when narrow, a side shot
; every SIDE_DELAY decisions at a player to the side.
air_core_tick:
.a16
  a8
  lda AIR_SECONDS
  cmp #AIR_TIME_LIMIT
  bcc @alive
  lda #AR_FAILED
  sta AIR_RESULT
  lda AIR_BOSS
  clc
  adc #2                        ; the lives at the start
  sec
  sbc z:AIR_CORE_LIFE
  a16
  and #255
  sta a:AIR_PERCENT_PART
  asl
  asl
  adc a:AIR_PERCENT_PART
  asl                           ; times 10
  a8
  sta AIR_PERCENT
  jmp .loword(air_enemy_retire)
@alive:
.a8
  lda z:AIR_CORE_TIMER
  and #1
  beq @timer
  lda z:OBJ_CROSS_RADIUS
  cmp #CORE_WIDE
  bne @wide
  lda #CORE_NARROW
  sta z:OBJ_CROSS_RADIUS
  lda #CORE_TALL
  sta z:OBJ_ALONG_RADIUS
  lda z:SPR_ALONG
  sec
  sbc #CORE_SHIFT
  bra @y
@wide:
  lda #CORE_WIDE
  sta z:OBJ_CROSS_RADIUS
  lda #CORE_NARROW
  sta z:OBJ_ALONG_RADIUS
  lda z:SPR_ALONG
  clc
  adc #CORE_SHIFT
@y:
  sta z:SPR_ALONG
@timer:
  lda z:AIR_CORE_TIMER
  beq @fan
  dec z:AIR_CORE_TIMER
  bra @side
@fan:
  ; The fan: FAN_SHOTS bullets around the player's angle (limited to 13..19).
  lda #FAN_DELAY
  sta z:AIR_CORE_TIMER
  jsl ai_target_far
  cmp #13
  bcs :+
  lda #13
:
  cmp #20
  bcc :+
  lda #19
:
  sta z:AIR_FAN_DIRECTION
  stz AIR_TEMP2
@fan_shot:
  a16
  lda AIR_TEMP2
  and #255
  tax
  a8
  lda f:air_fan_offsets,x
  clc
  adc z:AIR_FAN_DIRECTION
  and #DIRECTIONS-1
  sta MEDIUM_SHOT_ANGLE
  lda z:SPR_CROSS
  sta LARGE_AI_X
  lda z:SPR_ALONG
  sec
  sbc #CORE_GUN_ALONG
  sta LARGE_AI_Y
  jsr .loword(air_enemy_shot)
  inc AIR_TEMP2
  lda AIR_TEMP2
  cmp #FAN_SHOTS
  bne @fan_shot
@side:
  lda z:AIR_SIDE_DELAY
  beq @side_ready
  dec z:AIR_SIDE_DELAY
  bra @select
@side_ready:
  ; A side shot: angles 18-22 from the left gun, 10-14 from the right one.
  lda z:OBJ_CROSS_RADIUS
  cmp #CORE_WIDE
  beq @select
  jsl ai_target_far
  cmp #23
  bcs @select
  cmp #18
  bcs @left
  cmp #10
  bcc @select
  cmp #15
  bcs @select
  sta MEDIUM_SHOT_ANGLE
  lda z:SPR_CROSS
  clc
  adc #SIDE_GUN_CROSS
  bra @side_position
@left:
  sta MEDIUM_SHOT_ANGLE
  lda z:SPR_CROSS
  sec
  sbc #SIDE_GUN_CROSS
@side_position:
  sta LARGE_AI_X
  lda z:SPR_ALONG
  sta LARGE_AI_Y
  jsr .loword(air_enemy_shot)
  lda #SIDE_DELAY
  sta z:AIR_SIDE_DELAY
@select:
  a16
  lda #MOTION_AIR_CORE
  jmp .loword(air_enemy_path)

; air_core_hit: the core loses a life. At 0 it is destroyed: the sounds,
; AIR_DOWN (and AIR_DOWN_P2), the final ship finish explosion, AIR_PERCENT
; = 100 less 10 for each 11 seconds, and the core goes down with the camera.
air_core_hit:
.a16
  a8
  dec z:AIR_CORE_LIFE
  lda z:AIR_CORE_LIFE
  sta AIR_LIFE
  beq @destroyed
  lda #CORE_HP
  sta z:OBJ_HP
  lda #OF_CONTACT|OF_SHOT|OF_CAMERA
  sta z:OBJ_FLAGS
  a16
  lda #MOTION_AIR_CORE
  jmp .loword(air_enemy_path)
@destroyed:
.a8
  lda #SND_EXPLOSION
  jsl game_sound_request
  lda #SND_BOSS_DOWN
  jsl game_sound_request
  lda z:OBJ_OWNER
  cmp #1                        ; player 1
  beq @player_one
  lda #AIR_DOWN|AIR_DOWN_P2
  bra @owner
@player_one:
  lda #AIR_DOWN
@owner:
  ora AIR_BOSS
  sta AIR_BOSS
  lda z:OBJ_CROSS_RADIUS
  cmp #CORE_WIDE
  beq :+
  lda z:SPR_ALONG
  clc
  adc #CORE_SHIFT
  sta z:SPR_ALONG
:
  lda #AIR_BLAST_PATTERN
  sta STAGE_BLAST_PATTERN
  a16
  lda POOL_RECORD
  sta STAGE_BLAST_SOURCE
  a8
  phd
  pea .loword(ZERO_PAGE)
  pld
  lda #SF_FINAL
  jsl ship_finish_begin
  pld
  stz AIR_RESULT                ; AR_PASS
  lda #100
  sta AIR_PERCENT
  lda AIR_SECONDS
@percent:
  sec
  sbc #11
  bcc @percent_done
  pha
  lda AIR_PERCENT
  sec
  sbc #10
  sta AIR_PERCENT
  pla
  bra @percent
@percent_done:
  lda #OF_CAMERA
  sta z:OBJ_FLAGS
  a16
  lda #MOTION_AIR_CORE_DOWN
  jmp .loword(air_enemy_path)

; air_piece_tick: when AIR_LIFE comes to AIR_PIECE_LIFE the piece falls
; apart into AIR_PIECES extended objects (air_piece_templates), each 16
; further up, from 10 above it; SND_BOSS_PART.
air_piece_tick:
.a16
  a8
  lda AIR_LIFE
  cmp z:AIR_PIECE_LIFE
  beq @destroy
  a16
  lda #MOTION_AIR_PIECE
  jmp .loword(air_enemy_path)
@destroy:
.a8
  stz AIR_TEMP
@part:
  phd
  pea .loword(ZERO_PAGE)
  pld
  jsr .loword(extended_allocate)
  pld
  bcs :+
  jmp .loword(@retire)
:
  stx AIR_CORE
  a16
  lda AIR_TEMP
  and #255
  asl
  asl
  asl
  asl
  asl                           ; times OBJECT_SIZE
  txy
  tax
  .repeat OBJECT_SIZE/2
    lda f:air_piece_templates,x
    sta a:0,y
    inx
    inx
    iny
    iny
  .endrepeat
  ldx AIR_CORE
  a8
  lda z:SPR_CROSS
  sta a:SPR_CROSS,x
  lda AIR_TEMP
  asl
  asl
  asl
  asl
  clc
  adc #10
  sta a:AIR_PIECE_RISE
  lda z:SPR_ALONG
  sec
  sbc a:AIR_PIECE_RISE
  sta a:SPR_ALONG,x
  inc AIR_TEMP
  lda AIR_TEMP
  cmp #AIR_PIECES
  beq @retire
  jmp .loword(@part)
@retire:
  lda #SND_BOSS_PART
  sta AI_SOUND
  jmp .loword(air_enemy_retire)

; air_gun_tick: a gun of the air boss: the barrel turns BARREL_STEP toward
; the player; aligned, every AIR_GUN_CYCLE decisions it fires AIR_GUN_SHOTS
; from the muzzle of the barrel. After the core: OBJ_OWNER = 2 for player 2,
; else 0 (as the arcade), and the gun goes down.
air_gun_tick:
.a16
  a8
  lda AIR_BOSS
  bpl @alive
  and #AIR_DOWN_P2
  beq :+
  lda #2
:
  sta z:OBJ_OWNER
  a16
  lda #MOTION_AIR_GUN_DOWN
  jmp .loword(air_enemy_path)
@alive:
.a8
  lda z:AIR_GUN_TIME
  inc
  cmp #AIR_GUN_CYCLE
  bcc :+
  lda #0
:
  sta z:AIR_GUN_TIME
  jsl ai_target_far
  sec
  sbc z:AIR_GUN_BARREL
  and #DIRECTIONS-1
  beq @aligned
  cmp #1
  beq @aligned
  cmp #DIRECTIONS-1
  beq @aligned
  cmp #DIRECTIONS/2
  bcc @increase
  lda z:AIR_GUN_BARREL
  sec
  sbc #BARREL_STEP
  bra @angle
@increase:
  lda z:AIR_GUN_BARREL
  clc
  adc #BARREL_STEP
@angle:
  and #DIRECTIONS-1
  sta z:AIR_GUN_BARREL
  bra @select
@aligned:
  lda z:AIR_GUN_TIME
  bne @select
  stz AIR_TEMP2
@shot:
  lda z:AIR_GUN_BARREL
  ldx AIR_TEMP2
  cpx #0
  beq @heading
  cpx #1
  bne @minus
  inc
  bra @heading
@minus:
  dec
@heading:
  and #DIRECTIONS-1
  sta MEDIUM_SHOT_ANGLE
  a16
  lda z:AIR_GUN_BARREL
  and #DIRECTIONS-1
  tax
  a8
  lda f:turret_muzzles,x
  clc
  adc z:SPR_CROSS
  sta LARGE_AI_X
  lda f:turret_muzzles+1,x
  clc
  adc z:SPR_ALONG
  sta LARGE_AI_Y
  jsr .loword(air_enemy_shot)
  inc AIR_TEMP2
  lda AIR_TEMP2
  cmp #AIR_GUN_SHOTS
  bne @shot
@select:
  a16
  lda z:AIR_GUN_BARREL
  and #DIRECTIONS-1
  tax
  lda f:air_gun_paths,x
  jmp .loword(air_enemy_path)

; air_enemy_shot: an air boss bullet (airboss_shot_far, D = 0). JSR.
air_enemy_shot:
.a8
  phd
  pea .loword(ZERO_PAGE)
  pld
  jsl airboss_shot_far
  pld
  rts
.assert OBJECT_SIZE = 32, error ; the ASLs above
