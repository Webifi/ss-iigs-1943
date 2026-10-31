; Original-US ordinary-flight prefix and periodic energy, native record access.
.a8
.i16
PLAYER_EVENT_SOUND = $17cc
PLAYER_SPECIAL_LOCK = $17cd
PLAYER_DIP = $17ce

player_live_before:
  stz PLAYER_EVENT_SOUND
  lda PLAYER+$14
  beq @vulnerable
  dec PLAYER+$14
  stz PLAYER+7
  bra @weapon
@vulnerable:
  lda PLAYER_DIP
  and #$a0
  beq :+
  lda #1
:
  sta PLAYER+7
@weapon:
  lda PLAYER_SPECIAL_LOCK
  beq @ordinary
  lda #$f0
  sta PLAYER+$55
  rtl
@ordinary:
  lda PLAYER+$55
  ora #$fc
  sta PLAYER+$55
  rtl

player_live_after:
  lda PLAYER+$0d
  cmp #$a0
  bne @done
  stz PLAYER+$0d
  lda PLAYER+6
  beq @done
  dec PLAYER+6
  ; Only one energy glyph changes on this tick ($8982).
  lda PLAYER+6
  and #7
  clc
  adc #$80
  pha
  lda PLAYER+6
  lsr
  lsr
  lsr
  rep #$20
  and #255
  tax
  sep #$20
  pla
  sta ENERGY_HUD,x
@done:
  rtl

; Original fixed $1912-$1945. The wing helper owns color during a dodge.
; The arcade flips the palette here to spin the propellers; the card spins
; them with two DAC entries (scripts/propellers.py), so the colour stays on
; the even palette of the pair.
player_live_palette:
  lda #0
@ordinary:
  sta PLAYER_PALETTE
  lda PLAYER+1
  and #$f0
  ora PLAYER_PALETTE
  sta PLAYER+1
  lda PLAYER+$21
  and #$f0
  ora PLAYER_PALETTE
  sta PLAYER+$21
  lda PLAYER+4
  cmp #3
  beq @done
  lda PLAYER+$41
  and #$f0
  ora PLAYER_PALETTE
  sta PLAYER+$41
  lda PLAYER+$61
  and #$f0
  ora PLAYER_PALETTE
  sta PLAYER+$61
@done:
  rtl
PLAYER_PALETTE = $17d0
