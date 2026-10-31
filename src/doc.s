; Raw IIgs DOC/GLU access. No IRQ installation. Original mono effects use
; oscillator 0, with optional hit and explosion one-shots on oscillators 1/2.
; See GLU-COMPLETE.md sections 3.3/host access and DOC-COMPLETE.md 8/9.
.a8
.i16
DOC_MASTER = $17f4

doc_write:
  php
  sei
  pha
@busy:
  lda f:$e0c03c
  bmi @busy
  lda DOC_MASTER
  sta f:$e0c03c
  txa
  sta f:$e0c03e
  pla
  sta f:$e0c03d
  plp
  rts

doc_read:
  php
  sei
@busy:
  lda f:$e0c03c
  bmi @busy
  lda DOC_MASTER
  sta f:$e0c03c
  txa
  sta f:$e0c03e
  lda f:$e0c03d
@wait:
  lda f:$e0c03c
  bmi @wait
  ; C03D returns the preceding fetch and posts another one (Apple Hardware
  ; Reference p.107). Retrieve the saved byte while posting a harmless read
  ; of frequency register 0. Re-reading E0 would consume a second IRQ.
  lda #0
  sta f:$e0c03e
  lda f:$e0c03d
  plp
  rts

doc_init:
  lda f:$e100ca
  and #15
  sta DOC_MASTER
  sta f:$050500
  ldx #$a0
@halt:
  lda #3
  jsr doc_write
  inx
  cpx #$c0
  bne @halt
  ldx #$e1
  lda #$3e
  jsr doc_write
@ready:
  lda f:$e0c03c
  bmi @ready
  lda DOC_MASTER
  ora #$60
  sta f:$e0c03c
  lda #0
  sta f:$e0c03e
  lda #>DOC_GUN_ADDRESS
  sta f:$e0c03f
  ldx #0
@upload:
  lda f:$e0c03c
  bmi @upload
  lda f:DOC_GUN_SOURCE,x
  sta f:$e0c03d
  inx
  cpx #DOC_GUN_BYTES
  bne @upload
  ldx #0
  lda #0
  jsr doc_write
  ldx #$20
  lda #2
  jsr doc_write
  ldx #$40
  lda #DOC_GUN_VOLUME
  jsr doc_write
  ldx #$80
  lda #>DOC_GUN_ADDRESS
  jsr doc_write
  ldx #$c0
  lda #DOC_GUN_SIZE_RESOLUTION
  jsr doc_write
.if DOC_EFFECTS
 .if DOC_WEAPON_SET
  jsl doc_init_effects_far
 .else
  jsr doc_init_effects
 .endif
.endif
  rts

.if DOC_WEAPON_SET
doc_read_far:
  jsr doc_read
  rtl
doc_write_far:
  jsr doc_write
  rtl
doc_stream_init_far:
  jsr doc_stream_init
  rtl
.endif

.if DOC_EFFECTS
.if DOC_WEAPON_SET
.include "weapon_audio.s"
.else
doc_play_hit:
  cmp #$0e
  bne @hurt
  ldx #$a1
  bra @voice
@hurt:
  ldx #$a2
@voice:
  phx
  lda #3
  jsr doc_write
  ldx #30
@reset:
  dex
  bne @reset
  plx
  lda #2
  jsr doc_write
  rts
.if DOC_HURT
doc_play_player_hurt:
  ldx #$a3
  lda #3
  jsr doc_write
  ldx #30
@reset:
  dex
  bne @reset
  ldx #$a3
  lda #2
  jsr doc_write
  rts
.endif
.endif

.endif

doc_play_gun:
  ldx #$a0
  lda #3
  jsr doc_write
  ; A halted one-shot must be serviced once before restart. At stock 2.8 MHz
  ; 30 DEX/BNE iterations exceed the 34-slot scan (about 38 us).
  ldx #30
@reset:
  dex
  bne @reset
  ldx #$a0
  lda #2
  jsr doc_write
  rts

doc_read_sample:
@busy:
  lda f:$e0c03c
  bmi @busy
  lda DOC_MASTER
  ora #$60
  sta f:$e0c03c
  lda #0
  sta f:$e0c03e
  lda #>DOC_GUN_ADDRESS
  sta f:$e0c03f
  lda f:$e0c03d
  ldx #0
@byte:
  lda f:$e0c03c
  bmi @byte
  lda f:$e0c03d
  sta f:$050600,x
  inx
  cpx #DOC_GUN_BYTES
  bne @byte
  rts
