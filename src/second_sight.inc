; The IIgs side of the Second Sight card in slot 3 (Second Sight reference,
; github.com/Webifi/second-sight-reference: docs/09-host-protocol.md and
; docs/reference/host-commands.md). A write of
; $C0B0 raises the card's INT1.

SS_COMMAND      = $E0C0B0       ; write: a command byte
SS_DATA_OUT     = $E0C0B1       ; write: parameters and bulk data to the card
SS_DATA_IN      = $E0C0B2       ; read: results from the card
SS_BURST        = $E0C0B7       ; top of $C0B0-$C0B7: each write there is one packet byte
SS_BURST_SIZE   = 8             ; the bytes of $C0B0-$C0B7: one burst of pushes
SS_HANDSHAKE    = $E0C0B8       ; read: the handshake byte of the card

; Firmware commands (host-commands.md, command table)
SS_GET_STATUS   = $00           ; 13 reads: one dummy, then SS_STATUS_SIZE bytes
SS_SET_MODE     = $01           ; mode, SS_EMULATION or SS_NATIVE; completion SS_DONE
SS_UPLOAD_DATA  = $02           ; SS_UPLOAD_PARAMETERS bytes, then the data
SS_SCREEN_OFF   = $04           ; no parameters, no completion
SS_SET_PALETTE  = $06           ; source (3, ignored), then SS_PALETTE_SIZE bytes
SS_RUN_CODE     = $09           ; CBR, CBAR, BBR, address (2)
SS_SET_SHADOW   = $0B           ; SS_SHADOW_ALL or SS_SHADOW_NONE
SS_SET_VGA_REG  = $0C           ; SS_VGA_REG_PARAMETERS bytes

; Handshake values (host-commands.md, handshake values)
SS_PHASE_DONE   = $00           ; the phase is finished
SS_READY        = $01           ; the card waits for bytes, or has bytes to read
SS_DONE         = $A5           ; SetMode finished
SS_MODE_FAILED  = $A6           ; SetMode: the monitor has no such mode

; GetStatus: the bytes after the dummy read
SS_STATUS_SIZE  = 12
SS_SIGNATURE    = 0             ; "GSVGA"
SS_STATUS_COUNT = 5             ; the count of the bytes that follow: SS_STATUS_BYTES
SS_STATUS_BYTES = 6

; SetMode
SS_MODE_TEXT40  = $FC           ; 40-column text, with the same timing on each monitor
SS_EMULATION    = 0             ; the firmware draws the Apple screen
SS_NATIVE       = 1             ; native VGA mode

; SetShadow
SS_SHADOW_ALL   = $00           ; copy the Apple video writes
SS_SHADOW_NONE  = $04           ; stop all copies

; UploadData: flag, destination (3), length (3), IIgs source (3, ignored)
SS_UPLOAD_PARAMETERS = 10
SS_UPLOAD_LINEAR = 1            ; flag: the destination is a linear card address

; SetPalette
SS_PALETTE_SIZE = 768           ; 256 entries of red, green, blue

; SetVGAReg: index port (2), index, data port (2), value
SS_VGA_REG_PARAMETERS = 6

; The firmware's 40-column text screen in VRAM: two plane addresses for each
; cell, 40 cells for each row.
SS_TEXT40       = $000000

; Card VGA ports and register indexes for SS_SET_VGA_REG. The card code uses
; the same names (src/secondsight/include/vga.inc).
VGA_SEQ_INDEX   = $03C4
VGA_SEQ_DATA    = $03C5
VGA_GC_INDEX    = $03CE
VGA_GC_DATA     = $03CF
SEQ_MAP_MASK    = $02
SEQ_MEMORY_MODE = $04
GC_MODE         = $05
