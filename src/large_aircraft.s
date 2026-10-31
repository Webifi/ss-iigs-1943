; Four-piece carrier aircraft, bank four $B366-$B4FD. D is its live head.
.a8
.i16
large_plane_begin:
.a16
  sep #$20
  stz $09
  rep #$20
  lda #$b526
  jmp .loword(large_ai_selected)
large_plane_wrap:
.a16
  sep #$20
  lda $01
  and #16
  beq @sequence
  sta $41
  lda #16
  sta $03
  sta $10
  stz $43
  stz $04
  stz $11
  lda RANDOM_STATE+2
  pha
  clc
  adc #$99
  sta RANDOM_STATE+2
  pla
  and #15
  asl
  rep #$20
  and #255
  tax
  sep #$20
  lda f:large_plane_positions,x
  sta $02
  lda f:large_plane_positions+1,x
  sta $11
  rep #$20
  lda #$b583
  jmp .loword(large_ai_selected)
@sequence:
.a8
  lda $11
  beq @new
  dec $11
  lda $10
  jsr .loword(large_plane_index)
  bra @pointer
@new:
  lda $10
  inc $10
  jsr .loword(large_plane_index)
  lda f:large_plane_sequence,x
  sta $11
@pointer:
  rep #$20
  lda f:large_plane_sequence+1,x
  jmp .loword(large_ai_selected)
large_plane_index:
.a8
  rep #$20
  and #255
  sta a:$d4
  asl
  clc
  adc a:$d4
  tax
  sep #$20
  rts
large_plane_wait:
.a16
  sep #$20
  lda $11
  bne @waiting
  lda RANDOM_STATE+5
  pha
  clc
  adc #$88
  sta RANDOM_STATE+5
  pla
  lsr
  bcc large_plane_select
  jsr .loword(large_plane_shot)
  bra large_plane_select
@waiting:
  dec $11
  rep #$20
  lda #$b58d
  jmp .loword(large_ai_selected)
large_plane_enable:
.a16
  sep #$20
  lda #3
  sta $09
  rep #$20
  lda #$b58d
  jmp .loword(large_ai_selected)
large_plane_aim:
.a16
  sep #$20
  jsl LARGE_TARGET
  cmp $10
  beq large_plane_select
  bcc @decrease
  lda $10
  inc
  and #31
  cmp #24
  bcs large_plane_select
  sta $10
  bra large_plane_select
@decrease:
  lda $10
  dec
  and #31
  cmp #8
  bcc large_plane_select
  sta $10
large_plane_select:
.a8
  jsl LARGE_TARGET
  lda $03
  sec
  sbc PLAYER+3,y
  bcc @leave
  cmp #50
  bcc @leave
  lda $10
  sec
  sbc #8
  asl
  rep #$20
  and #255
  tax
  lda f:large_plane_paths,x
  jmp .loword(large_ai_selected)
@leave:
.a8
  lda $10
  cmp #16
  rep #$20
  lda #$b6bf
  bcs :+
  lda #$b797
:
  jmp .loword(large_ai_selected)
large_plane_fire:
.a16
  sep #$20
  lda RANDOM_STATE+5
  pha
  clc
  adc #$99
  sta RANDOM_STATE+5
  pla
  and #3
  bne @continue
  jsr .loword(large_plane_shot)
@continue:
  rep #$20
  lda LARGE_SOURCE
  clc
  adc #3
  jmp .loword(large_ai_selected)
large_plane_shot:
.a8
  jsl LARGE_TARGET
  lda #32
  sta LARGE_AI_ACTION
  lda $02
  clc
  adc #8
  sta LARGE_AI_X
  lda $03
  sec
  sbc #8
  sta LARGE_AI_Y
  rts
