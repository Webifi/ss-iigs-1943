; The texts and tables of the pause menu (src/input_menu.s), in the
; input_native scope.

; menu_name: a text of NAME_SIZE characters, filled with spaces.
.macro menu_name text
  .byte text
  .res NAME_SIZE-.strlen(text), ' '
.endmacro
; menu_source_name: a text of SOURCE_NAME_SIZE characters.
.macro menu_source_name text
  .byte text
  .res SOURCE_NAME_SIZE-.strlen(text), ' '
.endmacro

; menu_apple_rows: the text page offset of each MENU_TEXT row: the text page
; interleaves its rows, and MENU_CENTRE columns centre the layout.
MENU_CENTRE = (40-::MENU_COLUMNS)/2
menu_apple_rows:
.repeat ::MENU_ROWS, ROW
  .word (ROW .mod 8)*128+(ROW/8)*40+MENU_CENTRE
.endrepeat

; menu_actions: the name of each BIND_ACTION.
menu_actions:
  menu_name "P1 RIGHT"
  menu_name "P1 LEFT"
  menu_name "P1 DOWN"
  menu_name "P1 UP"
  menu_name "P1 FIRE"
  menu_name "P1 SPECIAL"
  menu_name "P2 RIGHT"
  menu_name "P2 LEFT"
  menu_name "P2 DOWN"
  menu_name "P2 UP"
  menu_name "P2 FIRE"
  menu_name "P2 SPECIAL"
  menu_name "P1 START"
  menu_name "P2 START"
  menu_name "COIN A"
  menu_name "COIN B"

; The key names: KN_* is the menu_key_names entry of a name.
.enum
  KN_A
  KN_S
  KN_D
  KN_W
  KN_1
  KN_2
  KN_5
  KN_6
  KN_RETURN
  KN_TAB
  KN_SPACE
  KN_DELETE
  KN_ESC
  KN_CONTROL
  KN_COMMAND
  KN_SHIFT
  KN_CAPS_LOCK
  KN_OPTION
  KN_LEFT
  KN_RIGHT
  KN_DOWN
  KN_UP
  KN_PAD_ENTER
  KN_PAD_1
  KN_PAD_2
  KN_PAD_3
  KN_PAD_4
  KN_PAD_5
  KN_PAD_6
  KN_PAD_7
  KN_PAD_8
  KN_PAD_9
  KEY_NAMES
.endenum
menu_key_names:
  menu_name "A"
  menu_name "S"
  menu_name "D"
  menu_name "W"
  menu_name "1"
  menu_name "2"
  menu_name "5"
  menu_name "6"
  menu_name "RETURN"
  menu_name "TAB"
  menu_name "SPACE"
  menu_name "DELETE"
  menu_name "ESC"
  menu_name "CONTROL"
  menu_name "OPEN APPLE"
  menu_name "SHIFT"
  menu_name "CAPS LOCK"
  menu_name "OPTION"
  menu_name "LEFT"
  menu_name "RIGHT"
  menu_name "DOWN"
  menu_name "UP"
  menu_name "PAD ENTER"
  menu_name "PAD 1"
  menu_name "PAD 2"
  menu_name "PAD 3"
  menu_name "PAD 4"
  menu_name "PAD 5"
  menu_name "PAD 6"
  menu_name "PAD 7"
  menu_name "PAD 8"
  menu_name "PAD 9"
.assert *-menu_key_names = KEY_NAMES*NAME_SIZE, error

; menu_key_index: the KN_* name of each ADB key code, or KEY_NO_NAME (the
; menu shows the code). (:: names the global key codes of iigs.inc, which
; .if needs as constants inside the scope.)
menu_key_index:
.repeat KEY_CODES, K
  .if K = ::KEY_A
    .byte KN_A
  .elseif K = ::KEY_S
    .byte KN_S
  .elseif K = ::KEY_D
    .byte KN_D
  .elseif K = ::KEY_W
    .byte KN_W
  .elseif K = ::KEY_1
    .byte KN_1
  .elseif K = ::KEY_2
    .byte KN_2
  .elseif K = ::KEY_5
    .byte KN_5
  .elseif K = ::KEY_6
    .byte KN_6
  .elseif K = ::KEY_RETURN
    .byte KN_RETURN
  .elseif K = ::KEY_TAB
    .byte KN_TAB
  .elseif K = ::KEY_SPACE
    .byte KN_SPACE
  .elseif K = ::KEY_DELETE
    .byte KN_DELETE
  .elseif K = ::KEY_ESC
    .byte KN_ESC
  .elseif K = ::KEY_CONTROL
    .byte KN_CONTROL
  .elseif K = ::KEY_COMMAND
    .byte KN_COMMAND
  .elseif K = ::KEY_SHIFT
    .byte KN_SHIFT
  .elseif K = ::KEY_CAPS_LOCK
    .byte KN_CAPS_LOCK
  .elseif K = ::KEY_OPTION
    .byte KN_OPTION
  .elseif K = ::KEY_LEFT .or K = ::KEY_MAC_LEFT
    .byte KN_LEFT
  .elseif K = ::KEY_RIGHT .or K = ::KEY_MAC_RIGHT
    .byte KN_RIGHT
  .elseif K = ::KEY_DOWN .or K = ::KEY_MAC_DOWN
    .byte KN_DOWN
  .elseif K = ::KEY_UP .or K = ::KEY_MAC_UP
    .byte KN_UP
  .elseif K = ::KEY_PAD_ENTER
    .byte KN_PAD_ENTER
  .elseif K = ::KEY_PAD_1
    .byte KN_PAD_1
  .elseif K = ::KEY_PAD_2
    .byte KN_PAD_2
  .elseif K = ::KEY_PAD_3
    .byte KN_PAD_3
  .elseif K = ::KEY_PAD_4
    .byte KN_PAD_4
  .elseif K = ::KEY_PAD_5
    .byte KN_PAD_5
  .elseif K = ::KEY_PAD_6
    .byte KN_PAD_6
  .elseif K = ::KEY_PAD_7
    .byte KN_PAD_7
  .elseif K = ::KEY_PAD_8
    .byte KN_PAD_8
  .elseif K = ::KEY_PAD_9
    .byte KN_PAD_9
  .else
    .byte KEY_NO_NAME
  .endif
.endrepeat

; menu_device_names: the device actions of the mouse and the joystick.
menu_device_names:
  menu_name "RIGHT"
  menu_name "LEFT"
  menu_name "DOWN"
  menu_name "UP"
  menu_name "BUTTON 1"
  menu_name "BUTTON 2"
  menu_name "BUTTON 3"
  menu_name "BUTTON 4"
  menu_name "BUTTON A"
  menu_name "BUTTON X"
  menu_name "BUTTON L"
  menu_name "BUTTON R"
; menu_pad_names: the pad keys, in the serial bit order of the SNES MAX.
menu_pad_names:
  menu_name "RIGHT"
  menu_name "LEFT"
  menu_name "DOWN"
  menu_name "UP"
  menu_name "START"
  menu_name "SELECT"
  menu_name "BUTTON Y"
  menu_name "BUTTON B"
  menu_name "BUTTON A"
  menu_name "BUTTON X"
  menu_name "BUTTON L"
  menu_name "BUTTON R"
; menu_sources: the name of each BIND_SOURCE.
menu_sources:
  menu_source_name "UNBOUND"
  menu_source_name "ADB KEYBOARD"
  menu_source_name "J13 KEYBOARD"
  menu_source_name "ADB AND J13"
  menu_source_name "MOUSE"
  menu_source_name "JOYSTICK"
  menu_source_name "PAD ONE"
  menu_source_name "PAD TWO"
; menu_default_bindings: RESTORE DEFAULT BINDINGS copies these.
menu_default_bindings:
  default_bindings
