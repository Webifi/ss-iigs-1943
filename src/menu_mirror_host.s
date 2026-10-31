; Paused, reversible card handoff. Buffers have dedicated checked ownership.
.a8
.i16
.macro mirror_read_started address, count
.local loop
  lda f:$e0c0b2               ; DMA read pipeline's documented dummy read
  ldx #0
loop:
  lda f:$e0c0b2
  sta f:address,x
  inx
  cpx #count
  bne loop
  jsl mirror_gate_off
.endmacro
.macro mirror_read address, count
  ldx #.loword(address)
  ldy #count
  lda #^address
  jsr mirror_in
.endmacro
.macro mirror_write address, count
  ldx #.loword(address)
  ldy #count
  lda #^address
  jsr mirror_out
.endmacro

.macro mirror_read_lc bank
  lda #bank
  jsr mirror_lc_read
.endmacro
.macro mirror_write_lc bank
  lda #bank
  jsr mirror_lc_write
.endmacro

; The first 1 KiB of the already-consumed card receive packet is scratch.
; The card bootstrap stores its return SP and MMU bytes at $4100-$4107.
; Retain those eight bytes separately while keeping the executing host code
; at $0F4000 intact; no card state outside packet scratch is discarded.
.macro mirror_read_packet
.local skip0, save, skip1, copy
  jsl mirror_gate_on
  lda f:$e0c0b2
  ldx #0
skip0:
  lda f:$e0c0b2
  inx
  cpx #$100
  bne skip0
  ldx #0
save:
  lda f:$e0c0b2
  sta f:MIRROR_RETURN,x
  inx
  cpx #8
  bne save
  ldx #0
skip1:
  lda f:$e0c0b2
  inx
  cpx #$2f8
  bne skip1
  ldx #0
copy:
  lda f:$e0c0b2
  sta f:$0f4400,x
  inx
  cpx #$3c00
  bne copy
  jsl mirror_gate_off
.endmacro
.macro mirror_write_packet
.local first, saved, rest
  jsl mirror_gate_on
  rep #$20
.a16
  ldx #0
first:
  lda f:$0f4000,x
  sta f:$e0c0b1
  inx
  inx
  cpx #$100
  bne first
  ldx #0
saved:
  lda f:MIRROR_RETURN,x
  sta f:$e0c0b1
  inx
  inx
  cpx #8
  bne saved
  ldx #0
rest:
  lda f:$0f4108,x
  sta f:$e0c0b1
  inx
  inx
  cpx #$3ef8
  bne rest
  sep #$20
.a8
  jsl mirror_gate_off
.endmacro

mirror_open:
  php
  rep #$30
  phx
  phy
  phb
  phd
  phk
  plb
  lda #0
  tcd
  ldx #1022
@save_page:
  lda f:$e00400,x
  sta f:MIRROR_TEXT,x
  dex
  dex
  bpl @save_page
  sep #$20
  lda f:$e0c01a
  sta a:mirror_text
  lda f:$e0c01c
  sta a:mirror_page
  lda f:$e0c01f
  sta a:mirror_80col
  rep #$20
  ldx #MIRROR_PACKET_BYTES-2
@packet:
  lda f:MIRROR_PACKET,x
  sta f:$008000,x
  dex
  dex
  bpl @packet
  lda #MIRROR_PAYLOAD_BYTES
  sta f:$000028
  sep #$20
  jsl input_menu_send
mirror_snapshot_start:
  jsl mirror_gate_on
mirror_snapshot_ready:
  mirror_read_started MIRROR_SLOT,4096
  mirror_write MIRROR_ENTER,MIRROR_ENTER_BYTES
  mirror_read $0f0000,$4000
  mirror_read_packet
  mirror_read $0f8000,$4000
  mirror_read $0fc000,$4000
  jsr mirror_lc_save
  mirror_read_lc $e0
  mirror_read_lc $e1
  jsr mirror_lc_restore
  mirror_read MIRROR_PALETTE,776
  ldy #32
@outer:
  ldx #$ffff
@wait_rom:
  lda f:$e0c0b8
  cmp #$71
  beq @copied
  dex
  bne @wait_rom
  dey
  bne @outer
  jml failed
@copied:
  ldy #2
@delay_outer:
  ldx #$ffff
@delay:
  dex
  bne @delay
  dey
  bne @delay_outer
  lda #0
  sta f:$e0c00c               ; 40 columns, main text page
  lda f:$e0c051
  lda f:$e0c054
  lda #11                     ; firmware SetShadow(0)
  sta f:$e0c0b0
  jsl mirror_gate_on
  lda #0
  sta f:$e0c0b1
  jsl mirror_gate_off
  lda #1                      ; firmware SetMode($FC, 0)
  sta f:$e0c0b0
  jsl mirror_gate_on
  lda #$fc
  sta f:$e0c0b1
  lda #0
  sta f:$e0c0b1
  jsl mirror_gate_off
  jsl mirror_gate_done
  sta f:$e0c00f               ; ALTCHAR again: the re-entered mirror shows
                              ; MouseText (menu marker) only after this write
mirror_entry_complete:
  rep #$30
  pld
  plb
  ply
  plx
  plp
  rtl

mirror_close:
mirror_exit_start:
  php
  rep #$30
  phx
  phy
  phb
  phd
  phk
  plb
  lda #0
  tcd
  rep #$20
  ldx #1022
@restore_page:
  lda f:MIRROR_TEXT,x
  sta f:$e00400,x
  dex
  dex
  bpl @restore_page
  sep #$20
  lda a:mirror_80col
  bpl :+
  sta f:$e0c00d
  bra :++
: sta f:$e0c00c
:
  lda a:mirror_page
  bpl :+
  lda f:$e0c055
  bra :++
: lda f:$e0c054
:
  lda a:mirror_text
  bpl :+
  lda f:$e0c051
  bra :++
: lda f:$e0c050
:
  sep #$20
  lda #11                     ; inhibit Apple video capture before restoring
  sta f:$e0c0b0
  jsl mirror_gate_on
  lda #4
  sta f:$e0c0b1
  jsl mirror_gate_off
  lda #2                      ; firmware UploadData to the backed-up SRAM slot
  sta f:$e0c0b0
  jsl mirror_gate_on
  lda #1
  sta f:$e0c0b1
  lda #0
  sta f:$e0c0b1
  lda #$c0
  sta f:$e0c0b1
  lda #$11
  sta f:$e0c0b1
  lda #<MIRROR_RESTORE_BYTES
  sta f:$e0c0b1
  lda #>MIRROR_RESTORE_BYTES
  sta f:$e0c0b1
  lda #0
  sta f:$e0c0b1
  sta f:$e0c0b1
  sta f:$e0c0b1
  sta f:$e0c0b1
  jsl mirror_gate_off
  mirror_write MIRROR_RESTORE,MIRROR_RESTORE_BYTES
  lda #9                      ; firmware RunCode in the temporary SRAM slot
  sta f:$e0c0b0
  jsl mirror_gate_on
  lda #$0e
  sta f:$e0c0b1
  lda #$ec
  sta f:$e0c0b1
  lda #$10
  sta f:$e0c0b1
  lda #0
  sta f:$e0c0b1
  lda #$e0
  sta f:$e0c0b1
  jsl mirror_gate_off
  mirror_write $0f0000,$4000
  mirror_write_packet
  mirror_write $0f8000,$4000
  mirror_write $0fc000,$4000
  mirror_write_lc $e0
  mirror_write_lc $e1
  jsr mirror_lc_restore
  mirror_write MIRROR_PALETTE,776
  mirror_write MIRROR_SLOT,4096
mirror_restore_complete:
  rep #$30
  pld
  plb
  ply
  plx
  plp
  rtl
mirror_text: .byte 0
mirror_page: .byte 0
mirror_80col: .byte 0

; One continuous 16 KiB card transfer into or out of bank A's language card:
; 12 KiB at $D000-$FFFF (bank 2), then 4 KiB at $D000 (bank 1). The bank
; byte of the long store/load is patched before the copy (MIRROR is RAM).
mirror_lc_read:
  sta @to+3
  jsl mirror_gate_on
  lda f:$e0c0b2               ; DMA read pipeline's documented dummy read
  lda f:$e0c083
  lda f:$e0c083
  ldy #$3000
@part:
  ldx #0
@loop:
  lda f:$e0c0b2
@to:
  sta f:$e0d000,x
  inx
  dey
  bne @loop
  cpx #$1000
  beq @done
  lda f:$e0c08b
  lda f:$e0c08b
  ldy #$1000
  bra @part
@done:
  jsl mirror_gate_off
  rts
mirror_lc_write:
  sta @from+3
  jsl mirror_gate_on
  lda f:$e0c083
  lda f:$e0c083
  ldy #$1800
@part:
  ldx #0
  rep #$20
.a16
@loop:
@from:
  lda f:$e0d000,x
  sta f:$e0c0b1
  inx
  inx
  dey
  bne @loop
  sep #$20
.a8
  cpx #$1000
  beq @done
  lda f:$e0c08b
  lda f:$e0c08b
  ldy #$0800
  bra @part
@done:
  jsl mirror_gate_off
  rts
; Keep the language-card read state the firmware left (bank, RAM/ROM),
; write-protected, around the snapshot copies.
mirror_lc_save:
  lda f:$e0c011
  asl
  lda f:$e0c012
  rol
  rol
  and #3
  sta f:MIRROR_LC_STATE        ; bit 0 reading RAM, bit 1 bank 2
  rts
mirror_lc_restore:
  lda f:MIRROR_LC_STATE
  rep #$20
  and #$0003
  tax
  sep #$20
  lda f:@switch,x
  rep #$20
  and #$00ff
  tax
  sep #$20
  lda f:$e0c080,x
  rts
@switch:                       ; ROM bank 1, RAM bank 1, ROM bank 2, RAM bank 2
  .byte $0a,$08,$02,$00
; Card transfer into host bytes: X = address low word, A = its bank, Y = count.
; The long store and the count are patched in place (MIRROR is RAM).
mirror_in:
  sta f:@to+3
  rep #$20
  txa
  sta f:@to+1
  tya
  sta f:@count+1
  sep #$20
  jsl mirror_gate_on
  lda f:$e0c0b2               ; DMA read pipeline's documented dummy read
  ldx #0
@loop:
  lda f:$e0c0b2
@to:
  sta f:$000000,x
  inx
@count:
  cpx #$0000
  bne @loop
  jsl mirror_gate_off
  rts
mirror_out:
  sta f:@from+3
  rep #$20
  txa
  sta f:@from+1
  tya
  sta f:@count+1
  sep #$20
  jsl mirror_gate_on
  ldx #0
  rep #$20
.a16
@loop:
@from:
  lda f:$000000,x
  sta f:$e0c0b1
  inx
  inx
@count:
  cpx #$0000
  bne @loop
  sep #$20
.a8
  jsl mirror_gate_off
  rts
