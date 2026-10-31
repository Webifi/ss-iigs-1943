; Native first-free-slot drops ($59D9-$5A1B) and item change ($768D-$76C4).
; Initialization copies are one-time object creation, never per-tick shuttles.
.a8
.i16
PICKUP_KIND = $17d3
PICKUP_X = $17d4
PICKUP_Y = $17d5
PICKUP_SLOT = $17d6
PICKUP_END = $17d8
PICKUP_CHANGE_INDEX = $17da

pickup_spawn:
  lda PICKUP_KIND
  cmp #8
  bne @select
  lda RANDOM_STATE+6
  pha
  clc
  adc #$99
  sta RANDOM_STATE+6
  pla
  and #15
  beq @select
  rtl

@select:
  rep #$20
  lda PICKUP_KIND
  and #255
  dec
  .repeat 5
    asl
  .endrepeat
  tay
  clc
  adc #32
  sta PICKUP_END
  ldx #0
  sep #$20
@find:
  lda ENEMY_POOL+8,x
  beq @found
  rep #$20
  txa
  clc
  adc #32
  tax
  sep #$20
  cpx #512
  bne @find
  rtl
@found:
  stx PICKUP_SLOT
  rep #$20
  phb
  phk
  plb
  .repeat 16,I
    lda .loword(pickup_templates)+I*2,y
    sta f:ENEMY_POOL+I*2,x
  .endrepeat
  plb
  sep #$20
  ldx PICKUP_SLOT
  lda PICKUP_X
  cmp #$10
  bcs :+
  lda #$10
:
  cmp #$e0
  bcc :+
  lda #$e0
:
  sta ENEMY_POOL+2,x
  lda PICKUP_Y
  sta ENEMY_POOL+3,x
  lda ENEMY_POOL+$0a,x
  and #15
  cmp #1
  beq @done
  lda #5
  sta ENEMY_POOL+9,x
@done:
  rtl

; D selects the record, as it does in the direct enemy callback dispatcher.
pickup_change:
  lda $02
  sta PICKUP_X
  lda $03
  sta PICKUP_Y
  lda $10
  inc
  sta PICKUP_CHANGE_INDEX
  rep #$20
  lda $10
  and #255
  .repeat 5
    asl
  .endrepeat
  tay
  phb
  phk
  plb
  .repeat 16,I
    lda .loword(pickup_change_templates)+I*2,y
    sta z:I*2
  .endrepeat
  plb
  sep #$20
  lda PICKUP_X
  sta $02
  lda PICKUP_CHANGE_INDEX
  sta $10
  lda PICKUP_Y
  clc
  adc #4
  bcc @inside
  stz $00
  stz $08
  stz $02
  lda #1
  sta ENEMY_RETIRED
  rtl
@inside:
  sta $03
  rep #$20
  lda $1e
  clc
  adc #7
  sta AI_NEXT
  sep #$20
  rtl

; Laser pickup chooses its next position from the original 16-entry table.
pickup_laser:
  lda $11
  inc
  cmp #16
  beq @end
  sta $11
  lda RANDOM_STATE+5
  pha
  clc
  adc #$77
  sta RANDOM_STATE+5
  pla
  and #15
  asl
  rep #$20
  and #255
  tax
  lda f:pickup_laser_positions,x
  sta $02
  lda #$72c3
  bra @next
@end:
  rep #$20
  lda #$72fe
@next:
  sta AI_NEXT
  sep #$20
  rtl
