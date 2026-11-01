; The guns of the players: the US arcade fire rules for each weapon mode, in
; native 65816 code (arcade $1579-$16E9). The names are the arcade labels of
; the modes.
; D points at the player record during each call; DBR = 0, A8, X16.
; Special attacks and weapon pickups are elsewhere.
.a8
.i16
; The cadence: each call adds a step to PL_CADENCE. The modes with
; CADENCE_STEP fire when it comes to 0; AUTO and SHELL fire when it carries.
CADENCE_STEP = 8
AUTO_CADENCE = $40
SHELL_CADENCE = $20
; The live shots that a mode allows (PL_SHOTS), and the AUTO burst.
STANDARD_SHOTS = 4           ; the standard guns without wing planes
PAIR_SHOTS = 7               ; with wing planes, and AUTO and 3 WAY
LASER_SHOTS = 6
AUTO_BURST = 8               ; AUTO shots until the button is released
; PL_FIRING: the updates that the firing sprite shows after a shot.
FIRING_STANDARD = 2
FIRING_AUTO = 1
FIRING_SPREAD = 6            ; SHOT GUN and 3 WAY
FIRING_SHELL = 2
FIRING_LASER = $10
SHOT_ATTR = 9                ; SPR_ATTR of every player shot
; A weapon_templates entry (WP_TEMPLATE_SIZE bytes, from the arcade ROM).
WT_CODE = 0                  ; the sprite code
WT_CROSS = 1                 ; the cross offset from the player
WT_ALONG = 2                 ; the along offset from the player
WT_STEPS = 3                 ; 4 bytes: SHOT_CROSS_STEP to SHOT_ALONG_RADIUS
WT_LIFE = 7                  ; 5 bytes: SHOT_LIFE to SHOT_PAIRED
; A weapon_patterns entry (WP_ENTRY_SIZE bytes, scripts/weapons.py); a
; template word of $FFFF ends a pattern.
WE_TEMPLATE = 0              ; 2 bytes: the offset of the template
WE_CROSS = 2                 ; the extra cross offset of this shot
WE_CODE = 3                  ; nonzero: the sprite code instead of WT_CODE
WE_LINK = 4                  ; $FF: no link; bit 0: SHOT_LINK; bit 7: paired
WE_SLOT = 5                  ; WP_SLOT_SINGLE, WP_SLOT_PAIR or WP_SLOT_NEXT
WE_NO_LINK = $ff

; weapon_fire: fire the gun of the player Y (0 or PLAYER_SIZE) when its
; mode and cadence allow (game_players_tick, while the fire button is held).
; Sets GUN_SOUND to the sound of the shot, or 0. A, X: changed.
weapon_fire:
  phd
  a16
  tya
  clc
  adc #PLAYER
  tcd
  a8
  stz GUN_SOUND
  lda PL_NUMBER
  sta WP_OWNER
  ; WP_BASE = the first shot record of this player.
  a16
  and #255
  beq :+
  lda #SHOTS_PER_PLAYER*SHOT_SIZE
:
  sta WP_BASE
  a8
  jsr .loword(weapon_dispatch)
  pld
  rtl

; weapon_dispatch: run the fire rule of PL_WEAPON.
weapon_dispatch:
  lda PL_WEAPON
  beq @standard
  cmp #WEAPON_AUTO
  beq @auto
  and #WEAPON_SHOTGUN           ; WEAPON_SHOTGUN or WEAPON_SHOTGUN_UP
  bne @shotgun
  lda PL_WEAPON
  cmp #WEAPON_3WAY
  beq @three_way
  cmp #WEAPON_SHELL
  beq @shell
  cmp #WEAPON_LASER
  beq @laser
  rts
  ; The standard guns (mode 0): one shot, or a linked pair with wing planes.
@standard:
  lda #CADENCE_STEP
  jsr .loword(weapon_cadence)
  bne @done
  jsr .loword(weapon_count)
  lda PL_WINGS
  and #1                        ; bit 0: the wing planes are on
  bne @standard_pair
  lda PL_SHOTS
  cmp #STANDARD_SHOTS
  beq @done
  ldy #WP_STANDARD
  bra @standard_emit
@standard_pair:
  lda PL_SHOTS
  cmp #PAIR_SHOTS
  bcs @done
  ldy #WP_STANDARD_PAIR
@standard_emit:
  jsr .loword(weapon_emit)
  lda #FIRING_STANDARD
  sta PL_FIRING
  lda #SND_GUN
  sta GUN_SOUND
@done:
  rts
  ; AUTO: a fast cadence, a burst of at most AUTO_BURST shots.
@auto:
  lda PL_CADENCE
  clc
  adc #AUTO_CADENCE
  sta PL_CADENCE
  bcc @done
  jsr .loword(weapon_count)
  cmp #PAIR_SHOTS
  bcs @done
  lda PL_BURST
  cmp #AUTO_BURST
  beq @done
  ldy #WP_AUTO
  lda PL_WINGS
  and #1
  beq :+
  ldy #WP_AUTO_PAIR
:
  jsr .loword(weapon_emit)
  inc PL_BURST
  lda #SND_GUN                  ; = FIRING_AUTO
  sta PL_FIRING
  sta GUN_SOUND
  rts
@shotgun:
  jmp .loword(weapon_shotgun)
@three_way:
  jmp .loword(weapon_3way)
@shell:
  jmp .loword(weapon_shell)
@laser:
  jmp .loword(weapon_laser)
.assert SND_GUN = FIRING_AUTO, error

; weapon_cadence: PL_CADENCE += A. Returns A and Z of the new value.
weapon_cadence:
  clc
  adc PL_CADENCE
  sta PL_CADENCE
  rts

; weapon_count: PL_SHOTS = the live shots of this player. Returns A =
; PL_SHOTS and Z when there is none. X: changed.
weapon_count:
  ldx WP_BASE
  a16
  txa
  clc
  adc #SHOTS_PER_PLAYER*SHOT_SIZE
  sta WP_END
  a8
  stz PL_SHOTS
@next:
  lda SHOTS+SHOT_STATE,x
  beq :+                        ; SHOT_FREE
  inc PL_SHOTS
:
  a16
  txa
  clc
  adc #SHOT_SIZE
  tax
  a8
  cpx WP_END
  bne @next
  lda PL_SHOTS
  rts

; weapon_shotgun: SHOT GUN (mode 2, or 3 upgraded): five pellets, or seven
; with wing planes, only when this player has no live shot.
weapon_shotgun:
  lda #CADENCE_STEP
  jsr .loword(weapon_cadence)
  bne @done
  jsr .loword(weapon_count)
  bne @done
  lda PL_WEAPON
  cmp #WEAPON_SHOTGUN_UP
  beq @upgraded
  ldy #WP_SHOTGUN
  lda PL_WINGS
  and #1
  beq @emit
  ldy #WP_SHOTGUN_PAIR
  bra @emit
@upgraded:
  ldy #WP_SHOTGUN_UP
  lda PL_WINGS
  and #1
  beq @emit
  ldy #WP_SHOTGUN_UP_PAIR
@emit:
  jsr .loword(weapon_emit)
  lda #FIRING_SPREAD
  sta PL_FIRING
  lda #SND_SHOTGUN
  sta GUN_SOUND
@done:
  rts

; weapon_3way: 3 WAY (mode 4): three shots on three paths.
weapon_3way:
  lda #CADENCE_STEP
  jsr .loword(weapon_cadence)
  bne @done
  jsr .loword(weapon_count)
  cmp #PAIR_SHOTS
  bcs @done
  ldy #WP_3WAY
  jsr .loword(weapon_emit)
  lda #FIRING_SPREAD
  sta PL_FIRING
  lda #SND_3WAY
  sta GUN_SOUND
@done:
  rts

; weapon_shell: SHELL (mode 8): one shell, or a pair with wing planes.
weapon_shell:
  lda PL_CADENCE
  clc
  adc #SHELL_CADENCE
  sta PL_CADENCE
  bcc @done
  jsr .loword(weapon_count)
  lda PL_WINGS
  and #1
  bne @paired
  lda PL_SHOTS
  cmp #STANDARD_SHOTS
  beq @done
  ldy #WP_SHELL
  bra @emit
@paired:
  lda PL_SHOTS
  cmp #PAIR_SHOTS
  bcs @done
  ldy #WP_SHELL_PAIR
@emit:
  jsr .loword(weapon_emit)
  lda #FIRING_SHELL
  sta PL_FIRING
  lda #SND_SHELL
  sta GUN_SOUND
@done:
  rts

; weapon_laser: LASER (mode $10): a beam of three segments.
weapon_laser:
  lda #CADENCE_STEP
  jsr .loword(weapon_cadence)
  bne @done
  jsr .loword(weapon_count)
  cmp #LASER_SHOTS
  bcs @done
  ldy #WP_LASER
  jsr .loword(weapon_emit)
  lda #FIRING_LASER
  sta PL_FIRING
  lda #SND_LASER
  sta GUN_SOUND
@done:
  rts

; weapon_emit: start every shot of the pattern at weapon_patterns+Y.
; Each shot takes a free record of this player: any free one (single) or the
; first record of a free pair; the second half of a pair takes the record
; after the first. With no free record the shot goes to GUN_OVERFLOW, a
; record that no code shows. A, X, Y: changed.
weapon_emit:
  sty WP_PLAN
@next:
  a16
  ldy WP_PLAN
  lda weapon_patterns+WE_TEMPLATE,y
  bpl @template
  a8                            ; $FFFF: the end of the pattern
  rts
@template:
  sta WP_TEMPLATE
  a8
  lda weapon_patterns+WE_CROSS,y
  sta WP_DX
  lda weapon_patterns+WE_CODE,y
  sta WP_CODE
  lda weapon_patterns+WE_LINK,y
  sta WP_LINK
  lda weapon_patterns+WE_SLOT,y
  cmp #WP_SLOT_NEXT
  beq @second
  ; Find a free record, as the US game does: WP_STEP and WP_END limit the
  ; search to single records, or to the first records of four pairs.
  a16
  and #255
  beq @single                   ; WP_SLOT_SINGLE
  lda #2*SHOT_SIZE              ; the first record of each pair
  sta WP_STEP
  lda WP_BASE
  clc
  adc #4*2*SHOT_SIZE            ; four pairs
  bra @limit
@single:
  lda #SHOT_SIZE
  sta WP_STEP
  lda WP_BASE
  clc
  adc #SHOTS_PER_PLAYER*SHOT_SIZE
@limit:
  sta WP_END
  ldx WP_BASE
  a8
@search:
  lda SHOTS+SHOT_STATE,x
  beq @spawn                    ; SHOT_FREE
  a16
  txa
  clc
  adc WP_STEP
  tax
  a8
  cpx WP_END
  bne @search
  ldx #GUN_OVERFLOW-SHOTS       ; no free record
  bra @spawn
@second:
  a16
  txa
  clc
  adc #SHOT_SIZE                ; the record after the first half
  tax
  a8
  ; Fill the record at SHOTS+X from the template and the player position.
@spawn:
  ldy WP_TEMPLATE
  lda weapon_templates+WT_CODE,y
  sta SHOTS+SPR_CODE,x
  lda #SHOT_ATTR
  sta SHOTS+SPR_ATTR,x
  lda SPR_CROSS
  clc
  adc weapon_templates+WT_CROSS,y
  clc
  adc WP_DX
  sta SHOTS+SPR_CROSS,x
  lda SPR_ALONG
  clc
  adc weapon_templates+WT_ALONG,y
  sta SHOTS+SPR_ALONG,x
  .repeat 4,I
    lda weapon_templates+WT_STEPS+I,y
    sta SHOTS+SHOT_CROSS_STEP+I,x
  .endrepeat
  .repeat 5,I
    lda weapon_templates+WT_LIFE+I,y
    sta SHOTS+SHOT_LIFE+I,x
  .endrepeat
  lda #SHOT_FLYING
  sta SHOTS+SHOT_STATE,x
  inc PL_SHOTS
  lda WP_OWNER
  sta SHOTS+SHOT_OWNER,x
  lda WP_CODE
  beq :+
  sta SHOTS+SPR_CODE,x
:
  lda WP_LINK
  cmp #WE_NO_LINK
  beq @advance
  and #1
  sta SHOTS+SHOT_LINK,x
  lda WP_LINK
  bpl @advance                  ; bit 7: the two halves share an impact
  lda #1
  sta SHOTS+SHOT_PAIRED,x
@advance:
  a16
  lda WP_PLAN
  clc
  adc #WP_ENTRY_SIZE
  sta WP_PLAN
  a8
  jmp @next
.assert WT_STEPS+4 = WT_LIFE .and WT_LIFE+5 = WP_TEMPLATE_SIZE, error
.assert SHOT_CROSS_STEP+3 = SHOT_ALONG_RADIUS .and SHOT_LIFE+4 = SHOT_PAIRED, error

; weapon_change: when PL_WEAPON differs from PL_WEAPON_INIT, end the live
; shots of player Y and restart its cadence (game_players_tick).
weapon_change:
  phd
  a16
  tya
  clc
  adc #PLAYER
  tcd
  a8
  lda PL_WEAPON
  cmp PL_WEAPON_INIT
  beq @done
  sta PL_WEAPON_INIT
  ldx #0
@slot:
  lda SHOTS+SHOT_STATE,x
  beq @next
  lda SHOTS+SHOT_OWNER,x
  cmp PL_NUMBER
  bne @next
  stz SHOTS+SPR_CODE,x
  stz SHOTS+SHOT_STATE,x        ; SHOT_FREE
@next:
  a16
  txa
  clc
  adc #SHOT_SIZE
  tax
  a8
  cpx #SHOT_COUNT*SHOT_SIZE
  bne @slot
  stz PL_SHOTS
  stz PL_BURST
  lda #CADENCE_START
  sta PL_CADENCE
@done:
  pld
  rtl
