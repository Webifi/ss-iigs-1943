; Full-rate resident samples. Paired oscillators preserve the short tails
; that cross a DOC table boundary. A pair's second voice is a one-shot.
.a8
.i16
doc_play_weapon:
  cmp #1
  bne :+
  jmp doc_play_gun
:
  cmp #2
  beq doc_play_player_hurt
  cmp #3
  bne :+
  ldx #$a6
  jmp doc_restart_one
:
  cmp #4
  bne :+
  ldx #$a7
  jmp doc_restart_one
:
  cmp #$1e
  bne @done
  ldx #$a8
  jmp doc_restart_pair
@done:
  rts

doc_play_hit:
  cmp #$0e
  bne @explosion
  ldx #$a1
  jmp doc_restart_one
@explosion:
  ldx #$a2
  jmp doc_restart_pair

doc_play_player_hurt:
  ldx #$a4
  jmp doc_restart_pair

doc_restart_one:
  phx
  lda #3
  jsr doc_write
  ldx #30
@reset:
  dex
  bne @reset
  plx
  lda #2
  jmp doc_write

doc_restart_pair:
  phx
  lda #3
  jsr doc_write
  inx
  lda #3
  jsr doc_write
  ldx #30
@reset:
  dex
  bne @reset
  plx
  lda #6
  jmp doc_write

; Observe the voice that this request actually started.
doc_weapon_control:
  rep #$20
  and #255
  tax
  sep #$20
  lda doc_weapon_voices,x
  rep #$20
  and #255
  tax
  sep #$20
  jmp doc_read
doc_weapon_voices:
  .byte $a0,$a0,$a4,$a6,$a7,$aa
  .res 24,$a0
  .byte $a8,$a0
