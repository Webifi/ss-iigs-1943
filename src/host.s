; Separate 65816 renderer fixture. Entry is native mode, M=8, X=16.
; Assets and command batches arrive in bank 2, not the normal game's RAM.
; No added IIgs interrupts. This file is not linked into the stock game.
.setcpu "65816"
.smart
.include "card.inc"
.include "host_labels.inc"
.a8
.i16
.segment "CODE"
entry:
  sei
  clc
  xce
  rep #$30
  ldx #$1fff
  txs
  lda #0
  tcd
  sep #$20
  pha
  plb
  jmp run_fixture

; All status reads are at B8 (no Z180 INT1 event). A bounded timeout
; marks failure; no card path must wait forever on a missing board.
on:
  ldx #$ffff
@poll:
  lda $e0c0b8
  cmp #1
  beq @ok
  dex
  bne @poll
  jmp failed
@ok:
  rts
off:
  ldx #$ffff
@poll:
  lda $e0c0b8
  beq @ok
  dex
  bne @poll
  jmp failed
@ok:
  rts
done:
  ldy #8
@restart:
  ldx #$ffff
@poll:
  lda $e0c0b8
  cmp #$a5
  beq @ok
  cmp #$a6
  beq failed
  dex
  bne @poll
  dey
  bne @restart
  jmp failed
@ok:
  rts
failed:
  lda #$ee
  sta $050301
@hold:
  bra @hold

; Build-time fixture operations use the documented ROM command framing.
.include "operations.s"
