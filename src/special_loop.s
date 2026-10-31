; Original-US defensive loop, bank 1 $8F5F-$9065. Player direct page is
; selected by PLAYER_CURSOR; animation triples come directly from $9066.
.a8
.i16
SPECIAL_LOOPS = $14e8       ; original E12B: shared continue/join/loop stock
SPECIAL_FLAGS = $14df       ; bit 0 BG2; bits 2-4 shared stock
.assert SPECIAL_PRESENTED_POSE+1 = SPECIAL_FLAGS, error, "special flags adjacency"
.assert PLAYER_CURSOR = SPECIAL_FLAGS+1, error, "player cursor adjacency"

special_loop_tick:
  phd
  rep #$20
  lda PLAYER_CURSOR
  clc
  adc #PLAYER
  tcd
  sep #$20
  stz z:$07
  stz z:$55
  lda z:$04
  beq :+
  jmp @finish
:
  lda z:$1b
  bne @move
  lda z:$1c
  rep #$20
  and #255
  sta a:$d0
  asl
  clc
  adc a:$d0
  tax
  sep #$20
  lda f:special_loop_table,x
  cmp #255
  bne :+
  jmp @finish
:
  sta z:$1b
  lda f:special_loop_table+1,x
  sta z:$1d
  lda f:special_loop_table+2,x
  sta z:$00
  inc
  sta z:$20
  lda z:$1c
  cmp #$17
  bne @hide_wings
  lda a:CAMERA+$21
  beq @wing_pictures
  cmp #1
  bne :+
  lda #$f0
  sta z:$1b
  stz z:$1d
  bra @wing_pictures
:
  lda #1
  sta z:$1b
@wing_pictures:
  lda z:$20
  clc
  adc #7
  sta z:$40
  inc
  sta z:$60
  bra @next_pose
@hide_wings:
  stz z:$40
  stz z:$60
@next_pose:
  inc z:$1c
@move:
  lda a:CAMERA+$21
  cmp #2
  bne :+
  lda #1
  sta z:$1b
:
  lda z:$03
  clc
  adc z:$1d
  cmp #$e0
  bcc :+
  lda #$e0
:
  cmp #$12
  bcs :+
  lda #$12
:
  sta z:$03
  sta z:$23
  sec
  sbc #16
  sta z:$43
  sta z:$63
  lda f:$000040
  eor #255
  and #3
  rep #$20
  and #255
  tax
  sep #$20
  lda z:$02
  clc
  adc f:special_loop_dx,x
  cmp #$10
  bcs :+
  lda #$10
:
  cmp #$d0
  bcc :+
  lda #$d0
:
  sta z:$02
  sta z:$42
  clc
  adc #16
  sta z:$22
  sta z:$62
  dec z:$1b
  pld
  rtl
@finish:
  stz z:$1b
  stz z:$1c
  stz z:$1d
  stz z:$1e
  stz z:$1f
  lda #2
  sta z:$08
  sta z:$0a
  lda #$2c
  sta z:$40
  sta z:$60
  lda #255
  sta z:$43
  sta z:$63
  pld
  ; Original $9044 clears all enemy bullets on completion.
  jsl special_clear_bullets
  rtl
special_loop_dx: .byte 0,2,$fe,0
special_loop_table:
  .byte $10,$01,$24,$10,$01,$02,$01,$01,$04,$01,$00,$04
  .byte $01,$01,$04,$01,$00,$04,$01,$01,$04,$01,$00,$04
  .byte $01,$01,$04,$01,$00,$04,$01,$01,$04,$01,$00,$04
  .byte $01,$01,$04,$01,$00,$04,$01,$01,$04,$01,$00,$04
  .byte $04,$00,$06,$01,$00,$0a,$01,$ff,$0a,$01,$00,$0a
  .byte $01,$ff,$0a,$06,$ff,$0c,$10,$ff,$44,$08,$ff,$0e
  .byte $08,$ff,$10,$04,$00,$12,$04,$00,$46,$04,$00,$4e
  .byte $01,$00,$24,$ff

special_clear_bullets:
  ldx #0
@slot:
  lda f:BULLETS+8,x
  beq @next
  lda #0
  sta f:BULLETS,x
  sta f:BULLETS+8,x
  lda #$f0
  sta f:BULLETS+2,x
@next:
  rep #$20
  txa
  clc
  adc #32
  tax
  sep #$20
  cpx #16*32
  bne @slot
  rtl

; The game's fixed-ROM weapon dispatcher ($13B9-$1441) owns the button edge.
SPECIAL_END = $14d8
SPECIAL_TYPE = $14da
SPECIAL_TIMER = $14db
SPECIAL_OWNER = $14dc
SPECIAL_PASS = $14dd
SPECIAL_PRESENTED_POSE = $14de
SPECIAL_WAVE_INDEX = $14fc
SPECIAL_WAVE_READY = $14fe
SPECIAL_LOADED = $14ff
SPECIAL_HOOK = $14ef

special_button:
  ldx PLAYER_CURSOR
  lda PLAYER+$55,x
  cmp #255
  beq :+
  sec
  rtl
:
  lda STAGE_FLAGS+16
  beq :+
  sec
  rtl
:
  lda f:$000040
  and #$10
  bne @attack
  lda PLAYER+4,x
  bne @attack
  lda SPECIAL_LOOPS
  beq @attack
  dec SPECIAL_LOOPS
  jsl special_sync_shadow
  lda #10
  sta PLAYER+8,x
  lda #$f0
  sta PLAYER+$55,x
  lda #$1b
  jsl game_sound_request
  sec
  rtl
@attack:
  lda SPECIAL_TIMER
  beq :+
  sec
  rtl
:
  lda PLAYER+6,x
  cmp #4
  bcs :+
  sec
  rtl
:
  sec
  sbc #4
  sta PLAYER+6,x
  lda #$f0
  sta PLAYER+$55
  sta PLAYER+$d5
  lda PLAYER+5,x
  inc
  sta SPECIAL_OWNER
  lda #200
  sta BULLET_CONTEXT+1
  ; Original $16EA: nearby live projectile selects the cyclone effect.
  ldy #0
@scan:
  lda BULLETS+8,y
  beq @next_bullet
  lda PLAYER+3,x
  clc
  adc #40
  cmp BULLETS+3,y
  bcc @next_bullet
  sec
  sbc #64
  cmp BULLETS+3,y
  bcs @next_bullet
  lda PLAYER+$22,x
  clc
  adc #32
  cmp BULLETS+2,y
  bcc @next_bullet
  sec
  sbc #64
  cmp BULLETS+2,y
  bcc @near
@next_bullet:
  rep #$20
  tya
  clc
  adc #32
  tay
  sep #$20
  cpy #14*32
  bne @scan
  ldx PLAYER_CURSOR
  lda PLAYER+6,x
  cmp #4
  bcc @near
  sec
  sbc #4
  sta PLAYER+6,x
  lda STAGE_FLAGS+5
  beq @lightning
  lda #2
  bra @select
@lightning:
  lda #1
  bra @select
@near:
  lda #0
@select:
  sta SPECIAL_TYPE
  beq @no_upload_init
  cmp #1
  bne :+
  ; Reset the per-packet presentation history for this attack.
  stz SPECIAL_PRESENTED_POSE
  ; The compact bolt poses were installed during startup and are permanent.
  lda #1
  sta SPECIAL_LOADED
  sta SPECIAL_WAVE_READY
  bra @no_upload_init
:
  lda SPECIAL_TYPE
  cmp SPECIAL_LOADED
  beq @preloaded
  clc
  adc #2
  cmp SPECIAL_LOADED          ; resume an interrupted wave transfer
  beq @no_upload_init
  sta SPECIAL_LOADED
  stz SPECIAL_WAVE_READY
  rep #$20
  stz SPECIAL_WAVE_INDEX
  sep #$20
  bra @no_upload_init
@preloaded:
  lda #1
  sta SPECIAL_WAVE_READY
@no_upload_init:
  lda SPECIAL_TYPE
  cmp #2
  bne :+
  lda #132
  bra @duration
:
  lda SPECIAL_TYPE
  bne :+
  lda #30
  bra @duration
:
  lda #18
@duration:
  sta SPECIAL_TIMER
  jsl special_install_tick
  lda #255
  sta CAMERA+4
  sta CAMERA+5
  sta CAMERA+$15
  sta CAMERA+$16
  lda SPECIAL_TYPE
  beq @cyclone_sound
  cmp #1
  beq @lightning_sound
  lda #$16
  bra @sound
@lightning_sound:
  lda #$15
  bra @sound
@cyclone_sound:
  lda #$17
@sound:
  jsl game_sound_request
  jsl special_clear_bullets
  lda SPECIAL_TYPE
  beq @finish_attack
  lda #1
  sta SPECIAL_PASS
  lda SPECIAL_TYPE
  cmp #2
  bne :+
  inc SPECIAL_PASS
:
  jsl special_damage_enemies
  jsl special_damage_large
@finish_attack:
  ldx PLAYER_CURSOR
  jsl player_energy_hud_far
  sec
  rtl
@consumed:
  sec
  rtl

; US $45EF small enemy pools. The two passes in surface mode apply two
; damage units. Pickups and records without hit/contact flags are untouched.
special_damage_enemies:
  rep #$20
  lda #0
  sta WAVE_SLOT
@small:
  ldx WAVE_SLOT
  sep #$20
  lda ENEMY_POOL+8,x
  beq @small_next
  lda ENEMY_POOL+$0a,x
  and #15
  bne @small_next
  lda ENEMY_POOL+9,x
  and #$fb
  beq @small_next
  lda SPECIAL_OWNER
  sta ENEMY_POOL+$0e,x
  lda ENEMY_POOL+$0b,x
  sec
  sbc SPECIAL_PASS
  bcc @small_kill
  beq @small_kill
  sta ENEMY_POOL+$0b,x
  bra @small_next
@small_kill:
  ; Original performs the first lethal transition once, even for two passes.
  lda #0
  sta ENEMY_POOL+$0b,x
  jsl special_enemy_kill_far
@small_next:
  rep #$20
  lda WAVE_SLOT
  clc
  adc #32
  sta WAVE_SLOT
  cmp #16*32
  bcc @small
  lda #EXTENDED_POOL-ENEMY_POOL
  sta WAVE_SLOT
@extended:
  ldx WAVE_SLOT
  sep #$20
  lda ENEMY_POOL+8,x
  beq @extended_next
  lda ENEMY_POOL+$0a,x
  and #15
  bne @extended_next
  lda ENEMY_POOL+9,x
  and #$fb
  beq @extended_next
  lda SPECIAL_OWNER
  sta ENEMY_POOL+$0e,x
  lda ENEMY_POOL+$0b,x
  sec
  sbc SPECIAL_PASS
  bcc @extended_kill
  beq @extended_kill
  sta ENEMY_POOL+$0b,x
  bra @extended_next
@extended_kill:
  lda #0
  sta ENEMY_POOL+$0b,x
  jsl special_enemy_kill_far
@extended_next:
  rep #$20
  lda WAVE_SLOT
  clc
  adc #32
  sta WAVE_SLOT
  cmp #EXTENDED_POOL-ENEMY_POOL+17*32
  bcc @extended
  sep #$20
  rtl

; Six large heads per class: two HP per hit; US $468C kills on borrow.
special_damage_large:
  rep #$20
  stz LARGE_SLOT
  lda #6*128
  sta SPECIAL_END
  sep #$20
  lda SPECIAL_TYPE
  cmp #2
  bne @large
  rep #$20
  lda #6*128
  sta LARGE_SLOT
  lda #12*128
  sta SPECIAL_END
@large:
  ldx LARGE_SLOT
  sep #$20
  lda LARGE_POOL+8,x
  beq @large_next
  lda LARGE_POOL+9,x
  and #$fb
  beq @large_next
  lda SPECIAL_OWNER
  sta LARGE_POOL+$0e,x
  lda LARGE_POOL+$0b,x
  sec
  sbc #2
  sta LARGE_POOL+$0b,x
  bcs @large_next
  jsl large_common_kill
@large_next:
  rep #$20
  lda LARGE_SLOT
  clc
  adc #128
  sta LARGE_SLOT
  cmp SPECIAL_END
  bcc @large
  sep #$20
  rtl

; Advance the original 200-tick projectile suppression and effect coroutine.
special_tick:
  lda SPECIAL_TIMER
  sta PLAYER_SPECIAL_LOCK
  lda BULLET_CONTEXT+1
  beq :+
  cmp #255
  beq :+
  dec BULLET_CONTEXT+1
:
  lda SPECIAL_TIMER
  beq @done
  lda STAGE_FLAGS+16
  bne @finish
  dec SPECIAL_TIMER
  bne @done
@finish:
  stz SPECIAL_TIMER
  lda SPECIAL_HOOK
  bne :+
  jsl special_restore_visual   ; no card cleanup was ever needed
:
  rep #$20
  stz CAMERA+4
  sep #$20
  ; Original $E1A0 is the moving-air-boss state.
  lda AIR_BOSS
  bne @done
  lda STAGE_FLAGS+$24
  bne @done
  rep #$20
  stz CAMERA+$15
  sep #$20
@done:
  lda SPECIAL_TIMER
  ora BULLET_CONTEXT+1
  ora SPECIAL_HOOK             ; do not strand the installed card patch
  bne :+
  jsl special_restore_tick
:
  rtl

; The site is ordinary LDA while idle; update its operand before opcode.
special_install_tick:
  php
  rep #$20
  lda #.loword(special_tick_trampoline)
  sta f:special_tick_site+1
  lda #.loword(d500_gate_stub)
  sta f:d500_gate_site+1
  lda #.loword(special_packet_trampoline)
  sta f:special_packet_site+1
.ifdef WORLD_LZ
  lda #.loword(special_lz_finish)
  sta f:world_lz_finish_call+1
.endif
  sep #$20
.ifdef WORLD_LZ
  lda #.bankbyte(special_lz_finish)
  sta f:world_lz_finish_call+3
.endif
  lda #$20
  sta f:special_tick_site
  sta f:d500_gate_site
  sta f:special_packet_site
  plp
  rtl

special_restore_tick:
  php
  sep #$20
  rep #$20
  lda #CAB_RESULT_ACTIVE
  sta f:special_tick_site+1
  lda #CAMERA+$0f
  sta f:d500_gate_site+1
  lda #SPECIAL_FLAGS
  sta f:special_packet_site+1
.ifdef WORLD_LZ
  lda #.loword(world_inflate_finish)
  sta f:world_lz_finish_call+1
.endif
  sep #$20
.ifdef WORLD_LZ
  lda #.bankbyte(world_inflate_finish)
  sta f:world_lz_finish_call+3
.endif
  lda #$ad
  sta f:special_tick_site
  sta f:d500_gate_site
  sta f:special_packet_site
  plp
  rtl

; Remove visual packet and staging hooks when their cleanup packet is queued.
; The independent timer hook remains installed while fire suppression runs.
special_restore_visual:
  php
  rep #$20
  lda #CAMERA+$0f
  sta f:d500_gate_site+1
  lda #SPECIAL_FLAGS
  sta f:special_packet_site+1
.ifdef WORLD_LZ
  lda #.loword(world_inflate_finish)
  sta f:world_lz_finish_call+1
.endif
  sep #$20
.ifdef WORLD_LZ
  lda #.bankbyte(world_inflate_finish)
  sta f:world_lz_finish_call+3
.endif
  lda #$ad
  sta f:d500_gate_site
  sta f:special_packet_site
  plp
  rtl

; Called only by stock/BG2 transitions; preserve A, X, Y, P and M width.
special_sync_shadow:
  php
  sep #$20
  pha
  lda SPECIAL_LOOPS
  and #7                     ; never leak stock into flash/overlay bits
  asl
  asl
  sta SPECIAL_FLAGS
  lda GAME_BG2_DISABLED
  and #1
  ora SPECIAL_FLAGS
  sta SPECIAL_FLAGS
  pla
  plp
  rtl

; Active packet path; the unpatched idle instruction loads SPECIAL_FLAGS.
special_packet_flash:
  jsl special_flash
  beq @packet_plain
  cmp #2
  bne @packet_cyan
  lda #$40
  bra @packet_sea_ready
@packet_cyan:
  lda #$02
@packet_sea_ready:
  sta $d2
  ; Never reached for Lightning (type 1): special_flash returns 0 for it, so
  ; the cloud flash comes only from special_packet_helper's $82.
  lda GAME_FLOW
  cmp #3
  bcs @packet_join
  lda SPECIAL_TYPE
  cmp #1
  bne @packet_join
  lda $d2
  ora #$80
  sta $d2
@packet_join:
  lda SPECIAL_FLAGS
  ora $d2
  rtl
@packet_plain:
  lda SPECIAL_FLAGS
  rtl

special_flash:
  lda SPECIAL_TIMER
  beq @no_flash
  lda SPECIAL_TYPE
  beq @cyclone
  cmp #1
  beq @lightning
  lda SPECIAL_TIMER
  cmp #129
  bcc @no_flash
  and #1
  bne @no_flash
  lda #2
  rtl
@cyclone:
  lda SPECIAL_TIMER
  cmp #25
  bcs @cyan
  cmp #19
  bcs @no_flash
  cmp #13
  bcs @cyan
  cmp #7
  bcs @no_flash
  bra @cyan
@lightning:
  ; Lightning palette flags are attached only when its bolt helper fits in
  ; this packet. Its picture phase is independent of the gameplay timer.
  bra @no_flash
@cyan:
  lda #1
  rtl
@no_flash:
  lda #0
  rtl

special_reset_stage:
  lda #2
  sta SPECIAL_LOOPS
  jsl special_sync_shadow
  lda PLAYER+8
  beq :+
  lda PLAYER+$88
  beq :+
  lda #4
  sta SPECIAL_LOOPS
  jsl special_sync_shadow
:
  rtl

; Bit five marks the final 14 state objects as renderer-only special art.
special_overlay_flag:
  lda #0
  rtl

; Append one prepared wave-texture upload batch to the ordinary state packet.
; The caller has saved $D4/$D6 and reports any following ordinary world bytes.
; Shared D500 groups must be staged again after an interrupted takeoff load.
.a16
special_wave_append:
  ldx SPECIAL_WAVE_INDEX
  lda f:SPECIAL_WAVE_LIST,x
  beq @complete
  sta D500_COPY_LENGTH
  lda f:SPECIAL_WAVE_LIST+2,x
  sta $d4
  lda f:SPECIAL_WAVE_LIST+4,x
  sta $d6
@check_packet:
  lda WORLD_OUTPUT
  sec
  sbc #$8000
  clc
  adc D500_COPY_LENGTH
  adc D500_FOLLOW
  adc #2
  cmp #1793
  bcs @return
  ; The temporary art invalidates every partial or completed D500 image.
  ; Await the next report before rebuilding it: zero would also permit a
  ; premature D0/D1 restage while flight is still using these fragments.
  lda #$8000
  sta D500_INDEX
  ldx WORLD_OUTPUT
  ldy #0
@copy:
  lda [$d4],y
  xba
  sta a:0,x
  inx
  inx
  iny
  iny
  cpy D500_COPY_LENGTH
  bcc @copy
  stx WORLD_OUTPUT
  lda SPECIAL_WAVE_INDEX
  clc
  adc #6
  sta SPECIAL_WAVE_INDEX
  tax
  lda f:SPECIAL_WAVE_LIST,x
  bne @return
@complete:
  sep #$20
  lda #1
  sta SPECIAL_WAVE_READY
  lda SPECIAL_TYPE
  sta SPECIAL_LOADED
  rep #$20
@return:
  rtl
.a8

; Carry set when special owns the temporary groups this packet.
.a16
special_stage_gate:
  sep #$20
  lda SPECIAL_TIMER
  beq :+
  jmp .loword(@check_mode)
:
  lda SPECIAL_HOOK
  bne @finish_visual
  jmp .loword(@ordinary)
@finish_visual:
  lda SPECIAL_HOOK
  cmp #1
  bne @remove_hook
  inc SPECIAL_HOOK             ; one neutral picture restores palettes first
  rep #$20
  sec
  rtl
@remove_hook:
  rep #$20
  jsl special_remove_hook
  sec
  rtl
@check_mode:
.a8
  lda GAME_FLOW
  cmp #3
  bcs @ordinary
  lda CAB_RESULT_ACTIVE
  bne @ordinary
  ; Wave art shares D500. Bolt art has its own permanent reservation.
  lda SPECIAL_TYPE
  cmp #1
  beq @takeoff_safe
  rep #$20
  lda CAMERA+$0f
  cmp #$d500
  bne :+
  clc
  rtl
:
  sep #$20
@takeoff_safe:
  lda SPECIAL_HOOK
  bne :+
  rep #$20
  jsl special_install_card_hook
  sep #$20
  lda SPECIAL_HOOK
  beq @ordinary
:
.a8
  lda SPECIAL_TYPE
  beq @ordinary
  cmp SPECIAL_LOADED
  beq @owned
  cmp #1
  bne :+
  ; A missing bolt marker must never trigger an attack-time art transfer.
  rep #$20
  sec
  rtl
:
  rep #$20
  jsl special_wave_append
  sec
  rtl
@owned:
.a8
  rep #$20
  jsl special_packet_helper
  sec
  rtl
@ordinary:
.a8
  ; The ordinary D500 staging path remains in control.
  rep #$20
@ordinary16:
.a16
  clc
  rtl
.a8

; Inflated world packets otherwise bypass the special staging gate. This
; wrapper is installed only during a special and retains the world payload.
.ifdef WORLD_LZ
.a16
special_lz_finish:
  phx
  lda $d4
  pha
  lda $d6
  pha
  ldx $d8
  sep #$20
  lda a:39,x
  and #$20
  bne @already
  rep #$20
  lda f:WL_FINAL
  sta D500_FOLLOW
  jsl special_stage_gate
  sep #$20
@already:
  rep #$20
  pla
  sta $d6
  pla
  sta $d4
  plx
  ldx WORLD_OUTPUT
  jsl world_inflate_finish
  rtl
.a8
.endif

; Copy the helper into the inactive packet buffer for this picture. It runs
; before DMA is rearmed and that same buffer is reused for the next packet.
.a16
special_packet_helper:
  sep #$20
  lda SPECIAL_WAVE_READY
  bne :+
  rep #$20
  rtl
:
.a8
  lda SPECIAL_TYPE
  cmp #1
  beq @bolt
  cmp #2
  beq :+
  rep #$20
  rtl
:
.a8
  lda SPECIAL_TIMER
  cmp #129
  bcc :+
  rep #$20
  rtl
:
.a8
  lda GAME_PICTURE
  and #1
  rep #$20
  bne @wave1
  lda #SPECIAL_WAVE_HELPER0_LENGTH
  sta D500_COPY_LENGTH
  lda #.loword(SPECIAL_WAVE_HELPER0_ADDRESS)
  sta $d4
  lda #.hiword(SPECIAL_WAVE_HELPER0_ADDRESS)
  sta $d6
  bra @check
@wave1:
  lda #SPECIAL_WAVE_HELPER1_LENGTH
  sta D500_COPY_LENGTH
  lda #.loword(SPECIAL_WAVE_HELPER1_ADDRESS)
  sta $d4
  lda #.hiword(SPECIAL_WAVE_HELPER1_ADDRESS)
  sta $d6
  bra @check
@bolt:
.a8
  lda GAME_PICTURE
  and #1
  rep #$20
  bne @bolt1
  lda #SPECIAL_BOLT_HELPER0_LENGTH
  sta D500_COPY_LENGTH
  lda #.loword(SPECIAL_BOLT_HELPER0_ADDRESS)
  sta $d4
  lda #.hiword(SPECIAL_BOLT_HELPER0_ADDRESS)
  sta $d6
  bra @check
@bolt1:
  lda #SPECIAL_BOLT_HELPER1_LENGTH
  sta D500_COPY_LENGTH
  lda #.loword(SPECIAL_BOLT_HELPER1_ADDRESS)
  sta $d4
  lda #.hiword(SPECIAL_BOLT_HELPER1_ADDRESS)
  sta $d6
@check:
  lda WORLD_OUTPUT
  sec
  sbc #$8000
  clc
  adc D500_COPY_LENGTH
  adc D500_FOLLOW
  adc #2
  cmp #1793
  bcs @return
  ldx WORLD_OUTPUT
  ldy #0
@copy:
  lda [$d4],y
  xba
  sta a:0,x
  inx
  inx
  iny
  iny
  cpy D500_COPY_LENGTH
  bcc @copy
  stx WORLD_OUTPUT
  sep #$20
  lda #1
  sta SPECIAL_HOOK
  rep #$20
  ldx $d8
  sep #$20
  lda a:39,x
  ora #$20
  sta a:39,x
  lda SPECIAL_TYPE
  cmp #1
  bne @return8
  ; Time selects the pose; the first packet that actually carries each pose
  ; gets the bright flash. A later packet of that pose is blue. Never hold or
  ; replay a missed pose, and update history only after the helper fits.
  lda SPECIAL_TIMER
  ; Advance the final visual boundary by one tick so a late painter can
  ; present both colours without extending the 18-tick gameplay interval.
  cmp #7
  bne :+
  lda #6
:
  sta a:36,x
  cmp #13
  bcs @pose0
  cmp #7
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
  lda a:39,x
  ora #$82                   ; white bolt, lit sea and clouds together
  sta a:39,x
@return8:
.a8
  rep #$20
@return:
.a16
  rtl

; Install the palette entry jump before the first active picture.
.a16
special_install_card_hook:
  lda #SPECIAL_HOOK_ON_LENGTH
  sta D500_COPY_LENGTH
  lda WORLD_OUTPUT
  sec
  sbc #$8000
  clc
  adc D500_COPY_LENGTH
  adc D500_FOLLOW
  adc #2
  cmp #1793
  bcs @done
  lda #.loword(SPECIAL_HOOK_ON_ADDRESS)
  sta $d4
  lda #.hiword(SPECIAL_HOOK_ON_ADDRESS)
  sta $d6
  ldx WORLD_OUTPUT
  ldy #0
@copy:
  lda [$d4],y
  xba
  sta a:0,x
  inx
  inx
  iny
  iny
  cpy D500_COPY_LENGTH
  bcc @copy
  stx WORLD_OUTPUT
  sep #$20
  lda #1
  sta SPECIAL_HOOK
  rep #$20
@done:
  rtl

; Restore both original instructions after a neutral effect picture.
.a16
special_remove_hook:
  lda #SPECIAL_HOOK_OFF_LENGTH
  sta D500_COPY_LENGTH
  lda WORLD_OUTPUT
  sec
  sbc #$8000
  clc
  adc D500_COPY_LENGTH
  adc D500_FOLLOW
  adc #2
  cmp #1793
  bcs @done
  lda #.loword(SPECIAL_HOOK_OFF_ADDRESS)
  sta $d4
  lda #.hiword(SPECIAL_HOOK_OFF_ADDRESS)
  sta $d6
  ldx WORLD_OUTPUT
  ldy #0
@copy:
  lda [$d4],y
  xba
  sta a:0,x
  inx
  inx
  iny
  iny
  cpy D500_COPY_LENGTH
  bcc @copy
  stx WORLD_OUTPUT
  sep #$20
  stz SPECIAL_HOOK
  jsl special_restore_visual
  lda SPECIAL_TIMER
  ora BULLET_CONTEXT+1
  bne :+
  jsl special_restore_tick
:
  rep #$20
@done:
  rtl
