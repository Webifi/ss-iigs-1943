; Original-US ordinary weapon rules, in native 65816 code.
; Y selects the player record (0 or 128); DBR=0, M=8, X=16.
; The direct page points at that record during the call. No record copies.
; Special attacks and pickup changes are handled by their own controllers.
.a8
.i16
WP_BASE = $17b0
WP_END = $17b2
WP_STEP = $17b4
WP_PLAN = $17b6
WP_TEMPLATE = $17b8
WP_DX = $17ba
WP_CODE = $17bb
WP_LINK = $17bc
WP_OWNER = $17bd

weapon_fire:
  phd
  rep #$20
  tya
  clc
  adc #PLAYER
  tcd
  sep #$20
  stz GUN_SOUND
  lda $05
  sta WP_OWNER
  rep #$20
  and #255
  beq :+
  lda #9*32
:
  sta WP_BASE
  sep #$20
  jsr .loword(weapon_dispatch)
  pld
.ifdef WEAPON_FAR
  rtl
.else
  rts
.endif

weapon_dispatch:
  lda $51
  beq @basic
  cmp #1
  beq @rapid
  and #2
  bne @spread
  lda $51
  cmp #4
  beq @shell
  cmp #8
  beq @laser
  cmp #16
  beq @fire
  rts
@basic:
  lda #8
  jsr .loword(weapon_phase_zero)
  bne @done
  jsr .loword(weapon_count)
  lda $04
  and #1
  bne @basic_pair
  lda $53
  cmp #4
  beq @done
  ldy #WP_BASIC
  bra @basic_emit
@basic_pair:
  lda $53
  cmp #7
  bcs @done
  ldy #WP_BASIC_PAIR
@basic_emit:
  jsr .loword(weapon_emit)
  lda #2
  sta $12
  lda #1
  sta GUN_SOUND
@done:
  rts
@rapid:
  lda $54
  clc
  adc #$40
  sta $54
  bcc @done
  jsr .loword(weapon_count)
  cmp #7
  bcs @done
  lda $56
  cmp #8
  beq @done
  ldy #WP_RAPID
  lda $04
  and #1
  beq :+
  ldy #WP_RAPID_PAIR
:
  jsr .loword(weapon_emit)
  inc $56
  lda #1
  sta $12
  sta GUN_SOUND
  rts
@spread:
  jmp .loword(weapon_spread)
@shell:
  jmp .loword(weapon_shell)
@laser:
  jmp .loword(weapon_laser)
@fire:
  jmp .loword(weapon_fireball)

weapon_phase_zero:
  clc
  adc $54
  sta $54
  rts

weapon_count:
  ldx WP_BASE
  rep #$20
  txa
  clc
  adc #9*32
  sta WP_END
  sep #$20
  stz $53
@next:
  lda SHOTS+8,x
  beq :+
  inc $53
:
  rep #$20
  txa
  clc
  adc #32
  tax
  sep #$20
  cpx WP_END
  bne @next
  lda $53
  rts

weapon_spread:
  lda #8
  jsr .loword(weapon_phase_zero)
  bne @done
  jsr .loword(weapon_count)
  bne @done
  lda $51
  cmp #3
  beq @wide
  ldy #WP_SPREAD
  lda $04
  and #1
  beq @emit
  ldy #WP_SPREAD_PAIR
  bra @emit
@wide:
  ldy #WP_WIDE
  lda $04
  and #1
  beq @emit
  ldy #WP_WIDE_PAIR
@emit:
  jsr .loword(weapon_emit)
  lda #6
  sta $12
  lda #2
  sta GUN_SOUND
@done:
  rts

weapon_shell:
  lda #8
  jsr .loword(weapon_phase_zero)
  bne @done
  jsr .loword(weapon_count)
  cmp #7
  bcs @done
  ldy #WP_SHELL
  jsr .loword(weapon_emit)
  lda #6
  sta $12
  lda #3
  sta GUN_SOUND
@done:
  rts

weapon_laser:
  lda $54
  clc
  adc #$20
  sta $54
  bcc @done
  jsr .loword(weapon_count)
  lda $04
  and #1
  bne @paired
  lda $53
  cmp #4
  beq @done
  ldy #WP_LASER
  bra @emit
@paired:
  lda $53
  cmp #7
  bcs @done
  ldy #WP_LASER_PAIR
@emit:
  jsr .loword(weapon_emit)
  lda #2
  sta $12
  lda #4
  sta GUN_SOUND
@done:
  rts

weapon_fireball:
  lda #8
  jsr .loword(weapon_phase_zero)
  bne @done
  jsr .loword(weapon_count)
  cmp #6
  bcs @done
  ldy #WP_FIRE
  jsr .loword(weapon_emit)
  lda #$10
  sta $12
  lda #$1e
  sta GUN_SOUND
@done:
  rts

weapon_emit:
  sty WP_PLAN
@next:
  rep #$20
  ldy WP_PLAN
  lda weapon_patterns,y
  bpl @template
  sep #$20
  rts
@template:
  sta WP_TEMPLATE
  sep #$20
  lda weapon_patterns+2,y
  sta WP_DX
  lda weapon_patterns+3,y
  sta WP_CODE
  lda weapon_patterns+4,y
  sta WP_LINK
  lda weapon_patterns+5,y
  cmp #2
  beq @second
  ; Find one free slot or the first half of a pair, exactly as the US game.
  rep #$20
  and #255
  beq @single
  lda #64
  sta WP_STEP
  lda WP_BASE
  clc
  adc #256
  bra @limit
@single:
  lda #32
  sta WP_STEP
  lda WP_BASE
  clc
  adc #288
@limit:
  sta WP_END
  ldx WP_BASE
  sep #$20
@search:
  lda SHOTS+8,x
  beq @spawn
  rep #$20
  txa
  clc
  adc WP_STEP
  tax
  sep #$20
  cpx WP_END
  bne @search
  ldx #GUN_OVERFLOW-SHOTS
  bra @spawn
@second:
  rep #$20
  txa
  clc
  adc #32
  tax
  sep #$20
@spawn:
  ldy WP_TEMPLATE
  lda weapon_templates,y
  sta SHOTS,x
  lda #9
  sta SHOTS+1,x
  lda $02
  clc
  adc weapon_templates+1,y
  clc
  adc WP_DX
  sta SHOTS+2,x
  lda $03
  clc
  adc weapon_templates+2,y
  sta SHOTS+3,x
  .repeat 4,I
    lda weapon_templates+3+I,y
    sta SHOTS+4+I,x
  .endrepeat
  .repeat 5,I
    lda weapon_templates+7+I,y
    sta SHOTS+$0a+I,x
  .endrepeat
  lda #2
  sta SHOTS+8,x
  inc $53
  lda WP_OWNER
  sta SHOTS+9,x
  lda WP_CODE
  beq :+
  sta SHOTS,x
:
  lda WP_LINK
  cmp #$ff
  beq @advance
  and #1
  sta SHOTS+$0f,x
  lda WP_LINK
  bpl @advance
  lda #1
  sta SHOTS+$0e,x
@advance:
  rep #$20
  lda WP_PLAN
  clc
  adc #6
  sta WP_PLAN
  sep #$20
  jmp @next

; Y selects the player. Clear only that owner's live slots on weapon change.
weapon_change:
  phd
  rep #$20
  tya
  clc
  adc #PLAYER
  tcd
  sep #$20
  lda $51
  cmp $50
  beq @done
  sta $50
  ldx #0
@slot:
  lda SHOTS+8,x
  beq @next
  lda SHOTS+9,x
  cmp $05
  bne @next
  stz SHOTS,x
  stz SHOTS+8,x
@next:
  rep #$20
  txa
  clc
  adc #32
  tax
  sep #$20
  cpx #18*32
  bne @slot
  stz $53
  stz $56
  lda #$f8
  sta $54
@done:
  pld
.ifdef WEAPON_FAR
  rtl
.else
  rts
.endif
