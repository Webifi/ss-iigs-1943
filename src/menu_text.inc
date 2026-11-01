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

; The keys without a character: menu_named_keys lists their ADB codes and
; menu_key_names their names, in the same order. Every other key is named
; by its character (menu_copy_binding_name).
menu_named_keys:
  .byte KEY_RETURN, KEY_TAB, KEY_SPACE, KEY_DELETE, KEY_ESC, KEY_CONTROL
  .byte KEY_COMMAND, KEY_SHIFT, KEY_CAPS_LOCK, KEY_OPTION
  .byte KEY_LEFT, KEY_RIGHT, KEY_DOWN, KEY_UP, KEY_PAD_ENTER, KEY_CLEAR
  .byte KEY_HELP, KEY_HOME, KEY_PAGE_UP, KEY_FORWARD_DELETE, KEY_END, KEY_PAGE_DOWN
menu_function_keys:                 ; named F and their number
  .byte KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8
  .byte KEY_F9, KEY_F10, KEY_F11, KEY_F12, KEY_F13, KEY_F14, KEY_F15
NAMED_KEYS = *-menu_named_keys
menu_key_names:
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
  menu_name "CLEAR"
  menu_name "HELP"
  menu_name "HOME"
  menu_name "PAGE UP"
  menu_name "DEL"
  menu_name "END"
  menu_name "PAGE DOWN"
FUNCTION_FIRST = menu_function_keys-menu_named_keys
.assert *-menu_key_names = FUNCTION_FIRST*NAME_SIZE .and NAMED_KEYS-FUNCTION_FIRST = 15, error
; menu_key_characters: the characters that name the other keys, unshifted:
; the first that asciiKeys (src/input_j13.s) gives the code of a key names it.
menu_key_characters:
  .byte "0123456789abcdefghijklmnopqrstuvwxyz',-./;=[", $5c, "]`"
KEY_CHARACTERS = *-menu_key_characters

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
