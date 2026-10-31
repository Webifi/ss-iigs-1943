; Original-US wing planes and firing pose, bank 1 $87A1-$8981/$89B0-$89EB.
; Y selects the native player; no record copies. PLAYER_AUX_SOUND is a request.
.a8
.i16
PLAYER_AUX_SOUND = $17c0
PLAYER_AUX_PHASE = $17c1

player_aux:
  phd
  rep #$20
  tya
  clc
  adc #PLAYER
  tcd
  sep #$20
  stz PLAYER_AUX_SOUND
  jsr .loword(player_wing_step)
  jsr .loword(player_firing_pose)
  pld
.ifdef PLAYER_AUX_FAR
  rtl
.else
  rts
.endif

player_wing_step:
  lda $04
  and #15
  cmp #8
  bne :+
  jmp .loword(player_wing_explode)
:
  cmp #4
  bne :+
  jmp .loword(player_wing_depart)
:
  cmp #2
  bne :+
  jmp .loword(player_wing_arrive)
:
  and #1
  beq @hidden
  lda $03
  bra @vertical
@hidden:
  lda #255
@vertical:
  sta $43
  sta $63
  lda $01
  pha
  lda $04
  cmp #3
  bne @normal_color
  lda PLAYER_AUX_PHASE
  and #3
  beq @normal_color
  pla
  lda #9
  bra @color
@normal_color:
  pla
@color:
  sta $41
  sta $61
  lda $02
  sec
  sbc #16
  sta $42
  clc
  adc #48
  sta $62
  lda $0a
  clc
  adc #$2a
  sta $40
  sta $60
  rts

player_wing_explode:
  lda #7
  sta $10
  lda $5c
  bne @wait
  lda $5d
  asl
  rep #$20
  and #255
  tax
  sep #$20
  lda player_wing_explosion,x
  cmp #255
  beq @done
  sta $5c
  lda player_wing_explosion+1,x
  sta $40
  sta $60
  inc $5d
  lda $5d
  cmp #10
  bcs @done
@wait:
  dec $5c
  rts
@done:
  stz $5c
  stz $5d
  stz $04
  rts

player_wing_arrive:
  lda $43
  sec
  sbc #6
  cmp $03
  bcs @position
  lda $04
  lsr
  lsr
  lsr
  lsr
  ora #1
  sta $04
  lda #$14
  sta $10
  lda #$18
  sta PLAYER_AUX_SOUND
  lda $03
@position:
  sta $43
  sta $63
  lda #$2c
  sta $40
  sta $60
  lda $02
  sec
  sbc #16
  sta $42
  clc
  adc #48
  sta $62
  rts

player_wing_depart:
  lda #10
  sta $10
  ldy #$40
  lda $43
  cmp #255
  beq @right
  jsr .loword(player_wing_depart_one)
@right:
  ldy #$60
  lda $63
  cmp #255
  bne @moving
  lda $43
  cmp #255
  bne @done
  lda $04
  and #$f0
  sta $04
@done:
  rts
@moving:
  jmp .loword(player_wing_depart_one)

player_wing_depart_one:
  ; Indexed direct-page uses X on 65816; Y keeps the wing offset for lookup.
  tyx
  lda $1c,x
  bne @move
  lda $1d,x
  asl
  asl
  rep #$20
  and #255
  pha
  tya
  cmp #$40
  beq :+
  pla
  clc
  adc #20
  bra @table
:
  pla
@table:
  tay
  sep #$20
  lda player_wing_left,y
  sta $00,x
  lda player_wing_left+1,y
  sta $1e,x
  lda player_wing_left+2,y
  sta $1f,x
  lda player_wing_left+3,y
  sta $1c,x
  inc $1d,x
@move:
  cpx #$40
  bne @rightward
  lda $02,x
  sec
  sbc $1e,x
  bra @x
@rightward:
  lda $02,x
  clc
  adc $1e,x
@x:
  cmp #$f0
  bcs @off
  sta $02,x
  lda $03,x
  clc
  adc $1f,x
  bcs @off
  sta $03,x
  dec $1c,x
  rts
@off:
  lda #255
  sta $03,x
  stz $1b,x
  stz $1c,x
  stz $1d,x
  stz $1e,x
  stz $1f,x
  rts

player_firing_pose:
  lda $12
  beq @unlit
  dec $12
  lda $04
  and #1
  beq @body
  lda $40
  beq @body
  clc
  adc #16
  sta $40
  sta $60
@body:
  lda $00
  cmp #$2f
  bcs @done
  clc
  adc #16
  bra @store
@unlit:
  lda $00
  cmp #$2f
  bcc @done
  sec
  sbc #16
@store:
  sta $00
  inc
  sta $20
@done:
  rts
