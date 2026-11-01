; The settings block: one disk block, the file SS1943.CONFIG. The game keeps
; it at `settings` (src/input_settings.s). scripts/boot_disk.py reads these
; names to write SS1943.CONFIG.
SETTINGS_SIZE       = 512
SETTINGS_CHECKSUM   = 510       ; 2 bytes: settings_sum of the bytes before it
SETTINGS_SEED       = $1943     ; the start value of settings_sum

; The fields of the settings block (src/input_settings.s gives the defaults).
SET_MAGIC           = 0         ; "1943KEY", then the version, 1
SET_J13             = 8         ; J13_ON, J13_CHOSEN
SET_SNES_SLOT       = 9         ; the slot of a SNES MAX adapter; 0 none
SET_DEAD_ZONE       = 10        ; the mouse dead zone
DEAD_ZONE_DEFAULT   = 9
DEAD_ZONE_STEP      = 3         ; the menu: DEAD_ZONE_STEP, 2 * DEAD_ZONE_STEP, ... DEAD_ZONE_MAX
DEAD_ZONE_MAX       = 24
SET_MUSIC_LEVEL     = 12        ; 0-10
SET_EFFECTS_LEVEL   = 13        ; 0-10
SET_MIX_FLAGS       = 14        ; MIX_DEMO_SOUND
SET_MIX_MARK        = 15        ; $A5 when the mix fields are valid
SET_MOUSE_PLAYER    = 16        ; the player of the mouse: 1 player 1, 0 player 2
SET_JOY_PLAYER      = 17        ; the player of the joystick: 1 player 1, 0 player 2
SET_DIP_A           = 18        ; the DIP switches A (DIP_A_*)
SET_DIP_B           = 19        ; the DIP switches B (DIP_B_*; the demo sound is in SET_MIX_FLAGS)
SET_DIP_MARK        = 20        ; DIP_MARK when SET_DIP_A and SET_DIP_B are valid
DIP_MARK            = $A5
DIP_A_DEFAULT       = $F8       ; difficulty 8 (normal), two players two credits
DIP_B_DEFAULT       = $FF       ; 1 coin 1 credit in both slots, continue, demo sound
; The DIP switches of the arcade (SW A, SW B): a bit is 0 when its switch is on.
DIP_A_LEVEL         = $0F       ; the difficulty: $0F level 1 (easy), $08 level 8, $00 level 16
DIP_A_TWO_CREDITS   = $10       ; set: two players cost two credits; clear: one credit
DIP_A_FLIP          = $20       ; clear: the screen upside down (not in the port)
DIP_A_STOP          = $40       ; clear: the play stops (screen stop)
DIP_A_SERVICE       = $80       ; clear: the service mode (not in the port)
DIP_B_COIN_A        = $07       ; coin slot A: the cabinet_coin_required/awarded entry
DIP_B_COIN_B        = $38       ; coin slot B: the same
DIP_B_COIN_B_SHIFT  = 3
DIP_B_CONTINUE      = $40       ; set: a continue is possible
DIP_B_DEMO_SOUND    = $80       ; set: the attract demo plays sound
SET_BINDINGS        = 32        ; BINDING_SIZE records, up to SET_DISPLAY_MARK
SET_DISPLAY_MARK    = 288       ; 2 bytes: DISPLAY_MARK, or DISPLAY_MARK_V1
SET_DISPLAY_EDITED  = 290       ; bit n: display record n was edited
SET_DISPLAY_PRESET  = 292       ; the selected display preset, 0-3
SET_DISPLAY_RECORDS = 294       ; DISPLAY_RECORDS records of DISPLAY_RECORD_SIZE bytes
DISPLAY_MARK        = $4452     ; SET_DISPLAY_MARK of version 2
DISPLAY_MARK_V1     = $4451     ; SET_DISPLAY_MARK of version 1
J13_ON              = 1         ; SET_J13: the play reads the J13 keyboard
J13_CHOSEN          = 2         ; SET_J13: set by hand; else the first menu may turn J13 on
MIX_DEMO_SOUND      = 1         ; SET_MIX_FLAGS: the attract demo plays sound
SETTINGS_MAGIC0     = '1'|('9'<<8)
SETTINGS_MAGIC1     = '4'|('3'<<8)
SETTINGS_MAGIC2     = 'K'|('E'<<8)
SETTINGS_MAGIC3     = 'Y'|(1<<8)
MIX_MARK_DEFAULT    = $A501     ; SET_MIX_FLAGS 1, SET_MIX_MARK $A5
MIX_LEVELS_DEFAULT  = $0A0A     ; SET_MUSIC_LEVEL 10, SET_EFFECTS_LEVEL 10
DISPLAY_RECORD_SIZE = 24
DISPLAY_RECORDS     = 9
; A display record: words in the field order of Timing (scripts/display_timing.py)
DR_HTOTAL           = 0         ; characters
DR_HBLANK_START     = 2
DR_HBLANK_END       = 4
DR_HSYNC_START      = 6
DR_HSYNC_END        = 8
DR_VTOTAL           = 10        ; lines
DR_VBLANK_START     = 12
DR_VBLANK_END       = 14
DR_VSYNC_START      = 16
DR_VSYNC_END        = 18
DR_CLOCK            = 20        ; the display_clock_select entry
DR_POLARITY         = 22        ; bit 0: negative horizontal sync, bit 1: negative vertical sync
; menuMessage: the message of the menu footer (menu_messages entry + 1); 0 none
MSG_SAVED           = 1
MSG_NO_ROOM         = 2         ; no free binding record
MSG_SAVE_ERROR      = 3
; A binding record
BIND_KEY            = 0         ; the key code, or the device action
BIND_SOURCE         = 1         ; SOURCE_*
BIND_ACTION         = 2         ; the game action; BIND_ACTIONS or more: unused
BIND_ACTIONS        = 16
BIND_NONE           = $FF       ; BIND_KEY and BIND_ACTION of a free record
; BIND_ACTION: the actions of player 1 (ACT_*), the same of player 2, then
; the system actions: P1 START, P2 START, COIN A, COIN B.
PLAYER_ACTIONS      = 6
ACTION_P2           = 6
ACTION_SYSTEM       = 12
SYSTEM_ACTIONS      = 4
; BIND_SOURCE: the keyboards (the keyHeld bits: HELD_ADB, HELD_J13), then
; the devices: their device key states are (source - 2) * 16 (DEV_*).
SOURCE_NONE         = 0
SOURCE_ADB          = 1
SOURCE_J13          = 2
SOURCE_KEYBOARDS    = 3         ; both keyboards
SOURCE_MOUSE        = 4
SOURCE_JOYSTICK     = 5
SOURCE_PAD1         = 6
SOURCE_PAD2         = 7
SOURCE_DEVICE_FIRST = SOURCE_MOUSE
; The device key states (deviceKeys, set_device): 16 for each source from 2,
; the action first: right, left, down, up, fire, special, then more buttons.
DEV_MOUSE           = 2*16
DEV_JOYSTICK        = 3*16
DEV_PAD1            = 4*16
DEV_PAD2            = 5*16
ACT_RIGHT           = 0
ACT_LEFT            = 1
ACT_DOWN            = 2
ACT_UP              = 3
ACT_FIRE            = 4
ACT_SPECIAL         = 5
ACT_START1          = ACTION_SYSTEM ; the system actions
ACT_START2          = ACTION_SYSTEM+1
ACT_COIN_A          = ACTION_SYSTEM+2
ACT_COIN_B          = ACTION_SYSTEM+3
BINDING_SIZE        = 4
.assert DEV_MOUSE = (SOURCE_MOUSE-2)*16 .and DEV_PAD2 = (SOURCE_PAD2-2)*16, error
.assert SET_DISPLAY_RECORDS+DISPLAY_RECORDS*DISPLAY_RECORD_SIZE = SETTINGS_CHECKSUM, error
