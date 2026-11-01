; The card handoff of the pause menu: mirror_open saves the card state (its
; SRAM packet area and slots, the video of $E0/$E1 in language card RAM, the
; palette) to the host, and lets the card firmware show the Apple text page
; (the menu); mirror_close puts all of it back. Each buffer has its own
; checked place (host_memory.inc, scripts/menu_mirror.py).
.a8
.i16
RESTORE_SRAM = $11C000       ; the linear card address of the restore code (in
                             ; the slot that MIRROR_SLOT keeps)
RESTORE_RUN = $E000          ; its run address (secondsight.ld .mirror_restore)
RESTORE_CBR = $0E            ; the MMU for RunCode: $E000 + $E000 = SRAM $1C000
RESTORE_CBAR = $EC           ; common area 1 from $E000, bank area from $C000
RESTORE_BBR = $10
HANDSHAKE_WAIT = 32          ; mirror_open: times 65535 reads for the card token
SETTLE_LOOPS = 2             ; then times 65535 loops before the video changes

; mirror_read_started: the first read after the caller's mirror_gate_on:
; count bytes from the card to address. mirror_read, mirror_write: count
; bytes from the card to address, or back (mirror_in, mirror_out).
.macro mirror_read_started address, count
.local loop
  lda f:SS_DATA_IN               ; DMA read pipeline's documented dummy read
  ldx #0
loop:
  lda f:SS_DATA_IN
  sta f:address,x
  inx
  cpx #count
  bne loop
  jsl mirror_gate_off
.endmacro
.macro mirror_read address, count
  ldx #.loword(address)
  ldy #count
  lda #^(address)
  jsr mirror_in
.endmacro
.macro mirror_write address, count
  ldx #.loword(address)
  ldy #count
  lda #^(address)
  jsr mirror_out
.endmacro

; mirror_read_lc, mirror_write_lc: the language card RAM of the bank (16 KiB).
.macro mirror_read_lc bank
  lda #bank
  jsr mirror_lc_read
.endmacro
.macro mirror_write_lc bank
  lda #bank
  jsr mirror_lc_write
.endmacro

; The card receive packet (src/secondsight/menu_mirror.s): CARD_PACKET_SIZE bytes from
; CARD_PACKET. Its first CARD_PACKET_SCRATCH bytes are already consumed: scratch, except
; the MIRROR_RETURN_SIZE bytes at secondsight_mirror_saved (return SP and MMU), which
; MIRROR_RETURN keeps. The executing host code (MIRROR_CODE) stays intact; no
; card state outside packet scratch is discarded.
CARD_PACKET = secondsight_mirror_boot
CARD_PACKET_SIZE = $4000
CARD_PACKET_SCRATCH = $0400
SAVED_OFFSET = secondsight_mirror_saved-CARD_PACKET
SNAPSHOT_PART = $4000                   ; the bytes of one snapshot transfer
.assert MIRROR_CODE = MIRROR_SNAPSHOT+CARD_PACKET, error
.assert MIRROR_CODE_SIZE <= CARD_PACKET_SCRATCH, error

; MIRROR_RETURN: the saved bytes, in game RAM, where no snapshot transfer
; writes.
.pushseg
.segment "GAMERAM"
MIRROR_RETURN: .res MIRROR_RETURN_SIZE
.popseg
; mirror_read_packet: the card packet into the snapshot, but the
; MIRROR_RETURN bytes to MIRROR_RETURN and the scratch to nothing.
; mirror_write_packet: the packet back with MIRROR_RETURN in it.
.macro mirror_read_packet
.local skip0, save, skip1, copy
  jsl mirror_gate_on
  lda f:SS_DATA_IN
  ldx #0
skip0:
  lda f:SS_DATA_IN
  inx
  cpx #SAVED_OFFSET
  bne skip0
  ldx #0
save:
  lda f:SS_DATA_IN
  sta f:MIRROR_RETURN,x
  inx
  cpx #MIRROR_RETURN_SIZE
  bne save
  ldx #0
skip1:
  lda f:SS_DATA_IN
  inx
  cpx #CARD_PACKET_SCRATCH-SAVED_OFFSET-MIRROR_RETURN_SIZE
  bne skip1
  ldx #0
copy:
  lda f:SS_DATA_IN
  sta f:MIRROR_SNAPSHOT+CARD_PACKET+CARD_PACKET_SCRATCH,x
  inx
  cpx #CARD_PACKET_SIZE-CARD_PACKET_SCRATCH
  bne copy
  jsl mirror_gate_off
.endmacro
.macro mirror_write_packet
.local first, saved, rest
  jsl mirror_gate_on
  a16
.a16
  ldx #0
first:
  lda f:MIRROR_SNAPSHOT+CARD_PACKET,x
  sta f:SS_DATA_OUT
  inx
  inx
  cpx #SAVED_OFFSET
  bne first
  ldx #0
saved:
  lda f:MIRROR_RETURN,x
  sta f:SS_DATA_OUT
  inx
  inx
  cpx #MIRROR_RETURN_SIZE
  bne saved
  ldx #0
rest:
  lda f:MIRROR_SNAPSHOT+CARD_PACKET+SAVED_OFFSET+MIRROR_RETURN_SIZE,x
  sta f:SS_DATA_OUT
  inx
  inx
  cpx #CARD_PACKET_SIZE-SAVED_OFFSET-MIRROR_RETURN_SIZE
  bne rest
  a8
.a8
  jsl mirror_gate_off
.endmacro

; mirror_open: save the text page and its switches, send the menu packet,
; then read the card state into the snapshot: the slot, the SRAM below the
; packet, the packet, the SRAM above, the video in the language card RAM of
; $E0 and $E1, the palette. When the card firmware is up (secondsight_mirror_token),
; the firmware shows the 40-column text page with ALTCHAR. JSL.
mirror_open:
  php
  ax16
  phx
  phy
  phb
  phd
  phk
  plb
  lda #0
  tcd
  ldx #TEXT_PAGE_SIZE-2
@save_page:
  lda f:TEXT_PAGE1,x
  sta f:MIRROR_TEXT,x
  dex
  dex
  bpl @save_page
  a8
  lda f:RDTEXT
  sta a:mirror_text
  lda f:RDPAGE2
  sta a:mirror_page
  lda f:RD80VID
  sta a:mirror_80col
  a16
  ldx #MIRROR_PACKET_BYTES-2
@packet:
  lda f:MIRROR_PACKET,x
  xba                         ; the PEI transport sends the high byte first
  sta f:PACKET_BUFFER,x
  dex
  dex
  bpl @packet
  lda #MIRROR_PAYLOAD_BYTES
  sta f:PACKET_LENGTH
  a8
  jsl input_menu_send
  jsl mirror_gate_on
  mirror_read_started MIRROR_SLOT,MIRROR_SLOT_SIZE
  mirror_write MIRROR_ENTER,MIRROR_ENTER_BYTES
  mirror_read MIRROR_SNAPSHOT,CARD_PACKET
  mirror_read_packet
  mirror_read MIRROR_SNAPSHOT+CARD_PACKET+CARD_PACKET_SIZE,SNAPSHOT_PART
  mirror_read MIRROR_SNAPSHOT+CARD_PACKET+CARD_PACKET_SIZE+SNAPSHOT_PART,SNAPSHOT_PART
  jsr mirror_lc_save
  mirror_read_lc ^MIRROR_VIDEO_E0
  mirror_read_lc ^MIRROR_VIDEO_E1
  jsr mirror_lc_restore
  mirror_read MIRROR_PALETTE,MIRROR_PALETTE_SIZE
  ldy #HANDSHAKE_WAIT
@outer:
  ldx #$ffff
@wait_rom:
  lda f:SS_HANDSHAKE
  cmp #secondsight_mirror_token
  beq @copied
  dex
  bne @wait_rom
  dey
  bne @outer
  jml failed
@copied:
  ldy #SETTLE_LOOPS
@delay_outer:
  ldx #$ffff
@delay:
  dex
  bne @delay
  dey
  bne @delay_outer
  lda #0
  sta f:CLR80VID               ; 40 columns, main text page
  lda f:TXTSET
  lda f:TXTPAGE1
  lda #SS_SET_SHADOW
  sta f:SS_COMMAND
  jsl mirror_gate_on
  lda #SS_SHADOW_ALL
  sta f:SS_DATA_OUT
  jsl mirror_gate_off
  lda #SS_SET_MODE
  sta f:SS_COMMAND
  jsl mirror_gate_on
  lda #SS_MODE_TEXT40
  sta f:SS_DATA_OUT
  lda #SS_EMULATION
  sta f:SS_DATA_OUT
  jsl mirror_gate_off
  jsl mirror_gate_done
  sta f:SETALTCHAR               ; ALTCHAR again: the re-entered mirror shows
                              ; MouseText (menu marker) only after this write
  ax16
  pld
  plb
  ply
  plx
  plp
  rtl

; mirror_close: the text page and its switches back; the card stops the
; Apple video copy, takes the restore code into the slot at RESTORE_SRAM
; and runs it, which receives the snapshot in the order of mirror_open. JSL.
mirror_close:
  php
  ax16
  phx
  phy
  phb
  phd
  phk
  plb
  lda #0
  tcd
  a16
  ldx #TEXT_PAGE_SIZE-2
@restore_page:
  lda f:MIRROR_TEXT,x
  sta f:TEXT_PAGE1,x
  dex
  dex
  bpl @restore_page
  a8
  lda a:mirror_80col
  bpl :+
  sta f:SET80VID
  bra :++
: sta f:CLR80VID
:
  lda a:mirror_page
  bpl :+
  lda f:TXTPAGE2
  bra :++
: lda f:TXTPAGE1
:
  lda a:mirror_text
  bpl :+
  lda f:TXTSET
  bra :++
: lda f:TXTCLR
:
  a8
  lda #SS_SET_SHADOW          ; inhibit Apple video capture before restoring
  sta f:SS_COMMAND
  jsl mirror_gate_on
  lda #SS_SHADOW_NONE
  sta f:SS_DATA_OUT
  jsl mirror_gate_off
  lda #SS_UPLOAD_DATA         ; to the backed-up SRAM slot
  sta f:SS_COMMAND
  jsl mirror_gate_on
  lda #SS_UPLOAD_LINEAR
  sta f:SS_DATA_OUT
  lda #<RESTORE_SRAM            ; the destination
  sta f:SS_DATA_OUT
  lda #>RESTORE_SRAM
  sta f:SS_DATA_OUT
  lda #^RESTORE_SRAM
  sta f:SS_DATA_OUT
  lda #<MIRROR_RESTORE_BYTES    ; the length
  sta f:SS_DATA_OUT
  lda #>MIRROR_RESTORE_BYTES
  sta f:SS_DATA_OUT
  lda #0
  sta f:SS_DATA_OUT
  sta f:SS_DATA_OUT             ; the IIgs source (not used)
  sta f:SS_DATA_OUT
  sta f:SS_DATA_OUT
  jsl mirror_gate_off
  mirror_write MIRROR_RESTORE,MIRROR_RESTORE_BYTES
  lda #SS_RUN_CODE            ; in the temporary SRAM slot
  sta f:SS_COMMAND
  jsl mirror_gate_on
  lda #RESTORE_CBR
  sta f:SS_DATA_OUT
  lda #RESTORE_CBAR
  sta f:SS_DATA_OUT
  lda #RESTORE_BBR
  sta f:SS_DATA_OUT
  lda #<RESTORE_RUN
  sta f:SS_DATA_OUT
  lda #>RESTORE_RUN
  sta f:SS_DATA_OUT
  jsl mirror_gate_off
  mirror_write MIRROR_SNAPSHOT,CARD_PACKET
  mirror_write_packet
  mirror_write MIRROR_SNAPSHOT+CARD_PACKET+CARD_PACKET_SIZE,SNAPSHOT_PART
  mirror_write MIRROR_SNAPSHOT+CARD_PACKET+CARD_PACKET_SIZE+SNAPSHOT_PART,SNAPSHOT_PART
  mirror_write_lc ^MIRROR_VIDEO_E0
  mirror_write_lc ^MIRROR_VIDEO_E1
  jsr mirror_lc_restore
  mirror_write MIRROR_PALETTE,MIRROR_PALETTE_SIZE
  mirror_write MIRROR_SLOT,MIRROR_SLOT_SIZE
  ax16
  pld
  plb
  ply
  plx
  plp
  rtl
mirror_text: .byte 0            ; RDTEXT, RDPAGE2, RD80VID before the menu
mirror_page: .byte 0
mirror_80col: .byte 0
.assert RESTORE_SRAM-$100000 = RESTORE_RUN+RESTORE_CBR*$1000, error  ; the SRAM of the linear address

; One continuous 16 KiB card transfer into or out of bank A's language card:
; 12 KiB at $D000-$FFFF (bank 2), then 4 KiB at $D000 (bank 1). The bank
; byte of the long store/load is patched before the copy (MIRROR is RAM).
mirror_lc_read:
  sta @to+3
  jsl mirror_gate_on
  lda f:SS_DATA_IN               ; DMA read pipeline's documented dummy read
  lda f:LCRAM2_RW
  lda f:LCRAM2_RW
  ldy #LC_HIGH_SIZE
@part:
  ldx #0
@loop:
  lda f:SS_DATA_IN
@to:
  sta f:MIRROR_VIDEO_E0,x       ; the bank: patched
  inx
  dey
  bne @loop
  cpx #LC_BANK_SIZE
  beq @done
  lda f:LCRAM1_RW
  lda f:LCRAM1_RW
  ldy #LC_BANK_SIZE
  bra @part
@done:
  jsl mirror_gate_off
  rts
mirror_lc_write:
  sta @from+3
  jsl mirror_gate_on
  lda f:LCRAM2_RW
  lda f:LCRAM2_RW
  ldy #LC_HIGH_SIZE/2
@part:
  ldx #0
  a16
.a16
@loop:
@from:
  lda f:MIRROR_VIDEO_E0,x       ; the bank: patched
  sta f:SS_DATA_OUT
  inx
  inx
  dey
  bne @loop
  a8
.a8
  cpx #LC_BANK_SIZE
  beq @done
  lda f:LCRAM1_RW
  lda f:LCRAM1_RW
  ldy #LC_BANK_SIZE/2
  bra @part
@done:
  jsl mirror_gate_off
  rts
; mirror_lc_save: MIRROR_LC_STATE = the language card read state that the
; firmware left (the bank, RAM or ROM). mirror_lc_restore: that state again,
; write-protected, after the snapshot copies. JSR; A8.
mirror_lc_save:
  lda f:RDLCBNK2
  asl
  lda f:RDLCRAM
  rol
  rol
  and #3
  sta f:MIRROR_LC_STATE        ; bit 0 reading RAM, bit 1 bank 2
  rts
mirror_lc_restore:
  lda f:MIRROR_LC_STATE
  a16
  and #3                        ; the two state bits
  tax
  a8
  lda f:@switch,x
  a16
  and #$00ff
  tax
  a8
  lda f:SLOT_DEVICE,x
  rts
@switch:                       ; by MIRROR_LC_STATE
  .byte LCROM1-SLOT_DEVICE,LCRAM1_READ-SLOT_DEVICE,LCROM2-SLOT_DEVICE,LCRAM2_READ-SLOT_DEVICE
; mirror_in: Y bytes from the card to the host address A (bank) : X.
; mirror_out: Y bytes (even) from there to the card. The long store and the
; count are patched in place (this code is in RAM). JSR; A8.
mirror_in:
  sta f:@to+3
  a16
  txa
  sta f:@to+1
  tya
  sta f:@count+1
  a8
  jsl mirror_gate_on
  lda f:SS_DATA_IN               ; DMA read pipeline's documented dummy read
  ldx #0
@loop:
  lda f:SS_DATA_IN
@to:
  sta f:0,x                   ; the address is patched
  inx
@count:
  cpx #$0000
  bne @loop
  jsl mirror_gate_off
  rts
mirror_out:
  sta f:@from+3
  a16
  txa
  sta f:@from+1
  tya
  sta f:@count+1
  a8
  jsl mirror_gate_on
  ldx #0
  a16
.a16
@loop:
@from:
  lda f:0,x                   ; the address is patched
  sta f:SS_DATA_OUT
  inx
  inx
@count:
  cpx #$0000
  bne @loop
  a8
.a8
  jsl mirror_gate_off
  rts
