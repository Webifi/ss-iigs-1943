; Apple IIgs addresses: soft switches and registers of the I/O page, screen
; memory and firmware locations. The names are those of the Apple IIgs
; Hardware Reference and Firmware Reference. Registers are given in bank $E0,
; where the I/O page is always visible; code that runs with the I/O page of
; bank $00 uses .loword(NAME).

; Video and memory soft switches
KBD             = $E0C000       ; read: keyboard data; write: 80STORE off
KBD_STROBE      = $80           ; KBD: a new character; KBDSTRB: a key is down
RDMAINRAM       = $E0C002       ; write: read main 48K
WRMAINRAM       = $E0C004       ; write: write main 48K
SETSLOTCXROM    = $E0C006       ; write: slot ROM at $C100-$CFFF
CLR80VID        = $E0C00C       ; write: 40 columns
SET80VID        = $E0C00D       ; write: 80 columns
CLRALTCHAR      = $E0C00E       ; write: primary character set
SETALTCHAR      = $E0C00F       ; write: alternate character set
KBDSTRB         = $E0C010       ; clear the keyboard strobe; read: any key down
RDLCBNK2        = $E0C011       ; read: bit 7 set when language card bank 2
RDLCRAM         = $E0C012       ; read: bit 7 set when language card RAM reads
RDTEXT          = $E0C01A       ; read: bit 7 set in text mode
RDPAGE2         = $E0C01C       ; read: bit 7 set when page 2
RD80VID         = $E0C01F       ; read: bit 7 set in 80 columns
TBCOLOR         = $E0C022       ; text and background colours
VGCINT          = $E0C023       ; video interrupt flags and enables
MOUSEDATA       = $E0C024       ; ADB mouse data
KEYMODREG       = $E0C025       ; ADB key modifiers
DATAREG         = $E0C026       ; ADB command and data
KMSTATUS        = $E0C027       ; ADB status
KM_MOUSE_IRQ    = $40           ; KMSTATUS: the mouse interrupt is on
KM_DATA_IRQ     = $10           ; KMSTATUS: the ADB data interrupt is on
KM_KEY_IRQ      = $04           ; KMSTATUS: the key interrupt is on
KM_MOUSE_FULL   = $80           ; KMSTATUS: MOUSEDATA has a byte
KM_DATA_FULL    = $20           ; KMSTATUS: DATAREG has a byte
KM_MOUSE_Y      = $02           ; KMSTATUS: the next MOUSEDATA byte is Y
KM_COMMAND_FULL = $01           ; KMSTATUS: the command register is busy
KMOD_SHIFT      = $01           ; KEYMODREG: shift
KMOD_CONTROL    = $02           ; KEYMODREG: control
KMOD_CAPS       = $04           ; KEYMODREG: caps lock
KMOD_REPEAT     = $08           ; KEYMODREG: the key repeats
KMOD_KEYPAD     = $10           ; KEYMODREG: a keypad key
KMOD_LATCH      = $20           ; KEYMODREG: a modifier changed with no key press
KMOD_OPTION     = $40           ; KEYMODREG: option
KMOD_COMMAND    = $80           ; KEYMODREG: open apple
KMOD_KEYS       = KMOD_SHIFT|KMOD_CONTROL|KMOD_CAPS|KMOD_OPTION|KMOD_COMMAND
; The commands of the ADB microcontroller (written to DATAREG).
GLU_FLUSH_KEYS  = $03           ; empty the keyboard buffer
GLU_SET_MODES   = $04           ; then a byte: set these mode bits
GLU_CLEAR_MODES = $05           ; then a byte: clear these mode bits
GLU_SET_CONFIG  = $06           ; then the CONFIG_BYTES configuration bytes
GLU_READ_MEMORY = $09           ; then the address, low and high: one byte back
GLU_READ_MODES  = $0A           ; one byte back: the mode byte
GLU_READ_CONFIG = $0B           ; CONFIG_BYTES back: the configuration bytes
GLU_SRQ_ON      = $50           ; + an ADB address: that device can ask for service
GLU_TALK        = $C0           ; + n * ADB_REGISTER + an ADB address: Talk register n
ADB_REGISTER    = $10
GLU_NO_KEY_POLL = $01           ; mode bit: the microcontroller does not poll the keyboard
GLU_KEY_BUFFER  = $10           ; mode bit: the microcontroller buffers the keys
CONFIG_BYTES    = 3
CONFIG_DELAY    = $70           ; configuration byte 3: the key repeat delay
CONFIG_NO_REPEAT = $40          ; CONFIG_DELAY: no key repeat
ADB_KEYBOARD    = 2             ; the ADB address of the keyboard
NEWVIDEO        = $E0C029       ; super hi-res and linear video
LANGSEL         = $E0C02B       ; language and display standard
SLTROMSEL       = $E0C02D       ; slot ROM select: bit n set = the card ROM of slot n
SLTROMSEL_SLOT4 = $10           ; slot 4: the card ROM, not the internal mouse firmware
VERTCNT         = $E0C02E       ; vertical counter
SCANINT         = $E0C032       ; scan line interrupt clear
CLOCKCTL        = $E0C034       ; clock control and border colour
SHADOW          = $E0C035       ; shadowing inhibit bits: SHADOW_*
SOUNDCTL        = $E0C03C       ; DOC sound GLU control
SOUNDDATA       = $E0C03D       ; DOC sound GLU data
SOUNDADRL       = $E0C03E       ; DOC sound GLU address, low
SOUNDADRH       = $E0C03F       ; DOC sound GLU address, high
; SOUNDCTL bits. Bits 0-3: the master volume.
SOUNDCTL_RAM    = $40           ; SOUNDADR selects DOC RAM, not a DOC register
SOUNDCTL_INC    = $20           ; SOUNDADR increments after each data access
; Ensoniq 5503 DOC registers: the base plus the oscillator number, 0-31.
DOC_FREQ_LOW    = $00
DOC_FREQ_HIGH   = $20
DOC_VOLUME      = $40
DOC_WAVE        = $80           ; the wave table page
DOC_CONTROL     = $A0
DOC_TABLE       = $C0           ; the table size and the resolution
DOC_IRQ         = $E0           ; bit 7 clear: an oscillator interrupt; bits 1-5 its number
DOC_ENABLE      = $E1           ; the number of enabled oscillators, times 2
DOC_OSCILLATORS = 32
DOC_IRQ_NONE    = $80
; DOC_CONTROL bits
DOC_HALT        = $01
DOC_ONE_SHOT    = $02
DOC_SYNC        = $04
DOC_IRQ_ENABLE  = $08
INTEN           = $E0C041       ; Mega II interrupt enables
TXTCLR          = $E0C050       ; graphics
TXTSET          = $E0C051       ; text
MIXCLR          = $E0C052       ; full screen
TXTPAGE1        = $E0C054       ; page 1
TXTPAGE2        = $E0C055       ; page 2
BUTN0           = $E0C061       ; button 0 (open apple)
BUTN1           = $E0C062       ; button 1 (option)
PADDL0          = $E0C064       ; paddle 0 timer
PADDL1          = $E0C065       ; paddle 1 timer
PTRIG           = $E0C070       ; paddle timer trigger

; SHADOW bits. A set bit stops the copy of bank $00/$01 writes to $E0/$E1.
SHADOW_HGR1     = $02           ; hi-res page 1
SHADOW_HGR2     = $04           ; hi-res page 2
SHADOW_SHGR     = $08           ; super hi-res
SHADOW_AUXHGR   = $10           ; bank $01 hi-res pages
SHADOW_GRAPHICS = SHADOW_HGR1 | SHADOW_HGR2 | SHADOW_SHGR | SHADOW_AUXHGR
SHADOW_IOLC     = $40           ; $C000-$FFFF of banks $00/$01 is RAM, no I/O or ROM

; ADB key codes (Apple IIgs Hardware Reference, the ADB keyboard).
KEY_COMMAND     = $37           ; open apple
KEY_OPTION      = $3A
KEY_SHIFT       = $38
KEY_CONTROL     = $36
KEY_CAPS_LOCK   = $39
KEY_A           = $00
KEY_S           = $01
KEY_D           = $02
KEY_W           = $0D
KEY_I           = $22
KEY_J           = $26
KEY_K           = $28
KEY_L           = $25
KEY_1           = $12
KEY_2           = $13
KEY_5           = $17
KEY_6           = $16
KEY_TAB         = $30
KEY_SPACE       = $31
KEY_DELETE      = $33
KEY_PAD_ENTER   = $4C
KEY_CLEAR       = $47
KEY_HELP        = $72           ; the keys of an extended keyboard
KEY_HOME        = $73
KEY_PAGE_UP     = $74
KEY_FORWARD_DELETE = $75
KEY_END         = $77
KEY_PAGE_DOWN   = $79
KEY_F1          = $7A
KEY_F2          = $78
KEY_F3          = $63
KEY_F4          = $76
KEY_F5          = $60
KEY_F6          = $61
KEY_F7          = $62
KEY_F8          = $64
KEY_F9          = $65
KEY_F10         = $6D
KEY_F11         = $67
KEY_F12         = $6F
KEY_F13         = $69
KEY_F14         = $6B
KEY_F15         = $71
KEY_PAD_POINT   = $41
KEY_PAD_TIMES   = $43
KEY_PAD_PLUS    = $45
KEY_PAD_DIVIDE  = $4B
KEY_PAD_MINUS   = $4E
KEY_PAD_EQUALS  = $51
KEY_PAD_0       = $52
KEY_PAD_1       = $53
KEY_PAD_2       = $54
KEY_PAD_3       = $55
KEY_PAD_4       = $56
KEY_PAD_5       = $57
KEY_PAD_6       = $58
KEY_PAD_7       = $59
KEY_PAD_8       = $5B
KEY_PAD_9       = $5C
KEY_RETURN      = $24
KEY_ESC         = $35
KEY_LEFT        = $3B
KEY_RIGHT       = $3C
KEY_DOWN        = $3D
KEY_UP          = $3E

; Language card RAM: $D000-$FFFF (bank 2 at $D000-$DFFF), and bank 1 at $D000-$DFFF.
LC_HIGH_SIZE    = $3000         ; $D000-$FFFF
LC_BANK_SIZE    = $1000         ; $D000-$DFFF of one bank
IRQ_VECTOR      = $00FFEE       ; the 65816 native-mode IRQ vector; RAM with SHADOW_IOLC

; Device select I/O: $C080 + slot * 16. Slot 0 is the language card.
SLOT_DEVICE     = $E0C080
LCRAM2_READ     = $E0C080       ; read RAM bank 2, no write
LCROM2          = $E0C082       ; read ROM, bank 2, no write
LCRAM2_RW       = $E0C083       ; read twice: read and write RAM bank 2
LCRAM1_READ     = $E0C088       ; read RAM bank 1, no write
LCROM1          = $E0C08A       ; read ROM, bank 1, no write
LCRAM1_RW       = $E0C08B       ; read twice: read and write RAM bank 1

; Text screen memory, page 1. TEXT_ROW_r is the first byte of text row r.
TEXT_PAGE1      = $E00400
TEXT_PAGE_SIZE  = $0400
TEXT_NORMAL     = $80           ; a text page character: bit 7 set: normal text
TEXT_SPACE      = ' '|TEXT_NORMAL
.repeat 24, R
  .ident(.sprintf("TEXT_ROW_%d", R)) = TEXT_PAGE1 + (R .mod 8) * $80 + (R / 8) * $28
.endrepeat

; Slot ROMs: the ROM of slot n (1 to 7) is at SLOT_ROMS + n * $100.
SLOT_ROMS       = $C000
SLOT1_ROM       = $C100
SLOT_ROMS_END   = $C800

; ProDOS block driver parameters in page zero (ProDOS 8 Technical Reference)
DRV_COMMAND     = $42           ; DRV_READ or DRV_WRITE
DRV_UNIT        = $43           ; drive in bit 7, slot in bits 4-6
DRV_BUFFER      = $44           ; 2 bytes: the 512-byte block buffer
DRV_BLOCK       = $46           ; 2 bytes: the block number
DRV_READ        = 1             ; also the SmartPort ReadBlock command
DRV_WRITE       = 2             ; also the SmartPort WriteBlock command

; Firmware work areas in bank $E1 that the disk firmware uses. The save code
; (src/input_disk.s) keeps a copy of them across each firmware call.
FW_E1_WORK0     = $E10000
FW_E1_WORK1     = $E10C00
FW_E1_WORK_SIZE = $0400

; Firmware locations
IDROUTINE       = $FE1F         ; call with carry set: only a IIgs clears it
ROMVER          = $FFFB59       ; ROM version: 0, 1 or 3
FW_BANKS_ROM00  = $E1161A       ; ROM 00: the top RAM bank the firmware counted
FW_BANKS_ROM03  = $E11624       ; ROM 01 and 03: the same count
CP_VOLUME       = $E100CA       ; Control Panel volume in bits 0-3
CP_VOLUME_BITS  = $0f
