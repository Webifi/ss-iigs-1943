; Quiet-window slot ownership. Guard ranges contain every reachable script
; record of the old family, including its spawn-delay entry. Current pixels
; alone cannot release a slot: a live object may use another pose next tick.
.a16
.i16
ART_GUARD = $1da0            ; 24-bit range-list pointer
ART_GUARD_COUNT = $1da3
ART_GUARD_SLOT = $1da4
ART_GUARD_END = $1da6
ART_GUARD_STRIDE = $1da8
ART_GUARD_SCRIPT = $1daa
ART_GUARD_BANK = $1dac
ART_GUARD_RESULT = $1dae
art_family_free:
  ; Carry set only when no live small/large actor owns any guarded script.
  ; Five-byte ranges: bank nibble, inclusive first, inclusive last.
  lda ART_GUARD
  sta f:art_range_read+1
  sep #$20
  lda ART_GUARD+2
  sta f:art_range_read+3
  lda ART_GUARD_COUNT
  bne :+
  rep #$20
  sec
  rtl
:
  rep #$20
  lda #$5000
  sta ART_GUARD_SLOT
  lda #$5200
  sta ART_GUARD_END
  lda #32
  sta ART_GUARD_STRIDE
@pool:
  ldx ART_GUARD_SLOT
  sep #$20
  lda a:8,x
  beq @next
  lda a:10,x
  and #$70
  sta ART_GUARD_BANK
  rep #$20
  lda a:$1e,x
  sta ART_GUARD_SCRIPT
  cmp #$8000
  bcs :+
  sep #$20
  lda #$80                 ; fixed scripts use their own family bank
  sta ART_GUARD_BANK
:
  rep #$20
  ldy #0
  ldx #0
@range:
  sep #$20
  jsr .loword(art_range_read)
  cmp ART_GUARD_BANK
  bne @skip
  inx
  rep #$20
  jsr .loword(art_range_read)
  cmp ART_GUARD_SCRIPT
  bcc @lower
  beq @lower
  dex
  bra @skip16
@lower:
  inx
  inx
  jsr .loword(art_range_read)
  cmp ART_GUARD_SCRIPT
  bcs @busy
  dex
  dex
  dex
@skip16:
  sep #$20
@skip:
  rep #$20
  txa
  clc
  adc #5
  tax
  iny
  tya
  sep #$20
  cmp ART_GUARD_COUNT
  rep #$20
  bcc @range
@next:
.a8
  rep #$20
  lda ART_GUARD_SLOT
  clc
  adc ART_GUARD_STRIDE
  sta ART_GUARD_SLOT
  cmp ART_GUARD_END
  bcc @pool
  cmp #$5200
  bne @free
  lda #$5400
  sta ART_GUARD_SLOT
  lda #$5a00
  sta ART_GUARD_END
  lda #128
  sta ART_GUARD_STRIDE
  jmp .loword(@pool)
@free:
  sec
  rtl
@busy:
.a16
  clc
  rtl
art_range_read:
  lda f:$000000,x
  rts
