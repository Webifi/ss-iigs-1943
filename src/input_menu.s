; The pause menu (ESC): the controls, the devices, the sound and the
; display settings. The game stops; the capture and the DOC clock go on.
; The game state, the world and the VRAM art stay: the menu writes only the
; text page, which the card shows (mirror_open). The menu draws a page in
; MENU_TEXT (MENU_ROWS x MENU_COLUMNS characters); menu_publish copies it
; to the centre of the 40-column text page.
; MENU_MARK: the choice marker. menu_publish flips bit 7, so it becomes $55,
; the MouseText right arrow (ALTCHAR: boot, and mirror_open for the card).
MENU_MARK = $d5
MENU_COLOURS = $f0           ; TBCOLOR: white text on black
MENU_WAIT = 8                ; GAME_CLOCK ticks between two menu samples
MENU_PITCH = 2*MENU_COLUMNS  ; a list: a choice on each second row
MENU_LIST = 3*MENU_COLUMNS   ; the row of the first choice
MENU_FOOTER = 22*MENU_COLUMNS  ; the row of the message
NAME_SIZE = 10               ; a name of menu_actions, menu_key_names, ...
SOURCE_NAME_SIZE = 14        ; a name of menu_sources
LEVEL_TEXT_SIZE = 3          ; a number of menu_audio_numbers
KEY_NO_NAME = 255            ; menu_key_index: no name; the menu shows the code
NO_BINDING = BINDINGS_BYTES  ; menu_find_binding: the action has no binding
ACTION_COLUMN = 2            ; MP_ACTIONS: the action name
KEY_COLUMN = 14              ; MP_ACTIONS: the name of the bound key
BINDING_COLUMN = 12          ; MP_BINDING: the name of the bound key
DEVICE_COLUMN = 19           ; MP_DEVICES: the values
SOUND_COLUMN = 22            ; MP_SOUND: the values
LEVEL_COLUMN = 2             ; MP_LEVEL: the levels
; menuPage: the page that shows.
MP_MAIN = 0
MP_GROUPS = 1                ; P1, P2, the start and coins
MP_DEVICES = 2
MP_SOUND = 3
MP_BINDING = 4               ; the binding of one action
MP_LEVEL = 5                 ; a volume
MP_ACTIONS = 6               ; the actions of a group
MP_DIPS = 7                  ; the DIP switches of the arcade
MP_MONITOR = 8               ; from this page on: display_control.s: the
                             ; monitor found at the start (display_apply)
MP_HORIZONTAL = 9            ; its horizontal timing
MP_VERTICAL = 10             ; its vertical timing
MP_EDIT = 11                 ; the numeric editor of one field
MP_PRESET = 12               ; the preset list
; menuAction: the choice on the page.
MAIN_DISPLAY = 3             ; MP_MAIN: 0-2 open MP_GROUPS-MP_SOUND
MAIN_DIPS = 4
MAIN_SAVE = 5
MAIN_RESUME = 6
MAIN_CHOICES = 7
GROUP_BACK = 3
GROUP_CHOICES = 4
DEVICE_BACK = 7              ; MP_DEVICES: menu_device has the choices
DEVICE_CHOICES = 8
SOUND_EFFECTS = 1            ; MP_SOUND: 0 the music volume
SOUND_DEMO = 2
SOUND_BACK = 3
SOUND_CHOICES = 4
BINDING_BACK = 5             ; MP_BINDING (menuChoice)
BINDING_CHOICES = 6
DIP_BACK = 7                 ; MP_DIPS: dip_items has the switches
DIP_CHOICES = 8
DIP_VALUE = MENU_COLUMNS+4   ; MP_DIPS: the value goes on the row under its switch
LISTEN_CHANGE = 1            ; menuListen: the next key replaces the binding
LISTEN_ADD = 2               ; menuListen: the next key is a new binding
PAD_SLOT_SKIP = 3            ; the SNES MAX slot choice: 1, 2, 4, 5, 6, then
PAD_SLOT_END = 7             ; 0 (none)
.a8
.i16
; menu_check (native_input_menu): open the menu on a new ESC press
; (SYSTEM_MENU, 0 = pressed); menuWasDown keeps a held ESC from opening it
; again. The menu runs here until RESUME, or ESC on the main page: each
; MENU_WAIT ticks a sample, the key, and a new picture after a change. JSL;
; the registers stay.
menu_check:
  php
  lda f:INPUT_SYSTEM
  and #SYSTEM_MENU
  beq @down
  lda #0
  sta f:menuWasDown
  plp
  rtl
@down:
  lda f:menuWasDown
  beq @open
  plp
  rtl
@open:
  ax16
  phx
  phy
  phb
  phd
  phk
  plb
  lda #0
  tcd
  lda #1
  sta a:.loword(menuMode)
  sta a:.loword(menuDirty)
  stz a:.loword(menuPage)       ; MP_MAIN
  stz a:.loword(menuAction)
  stz a:.loword(menuAlias)
  stz a:.loword(menuListen)
  stz a:.loword(menuMessage)
  lda a:.loword(inputSerial)
  sta a:.loword(menuSerial)
  jsl J13Menu
  jsl mirror_open
  a8
  lda f:TBCOLOR
  sta a:.loword(menu_saved_color)
  lda #MENU_COLOURS
  sta f:TBCOLOR
  a16
  jsr .loword(menu_clear_apple)
@loop:
  lda #JOY_READ_NOW             ; the joystick at each sample
  sta a:.loword(joyUpdate)
  jsl sample
  ax16
  lda a:.loword(menuDirty)
  beq @input
  stz a:.loword(menuDirty)
  jsr .loword(menu_draw)
@input:
  lda a:.loword(inputSerial)
  cmp a:.loword(menuSerial)
  bne :+
  jmp .loword(@wait)            ; no new key
:
  sta a:.loword(menuSerial)
  lda a:.loword(keyAction)
  cmp #KEY_ESC                  ; a device action is 0-15: never KEY_ESC
  bne @key
  ; ESC: the wait for a key stops; else the page before shows.
  lda a:.loword(menuListen)
  beq :+
  stz a:.loword(menuListen)
  bra @changed
:
  lda a:.loword(menuPage)
  bne :+
  jmp .loword(@resume)          ; MP_MAIN
:
  cmp #MP_MONITOR
  bcc :+
  jsl display_back
  bra @changed
:
  cmp #MP_BINDING
  bne :+
  jsr .loword(menu_binding_back)
  bra @changed
:
  cmp #MP_ACTIONS
  bne :+
  lda #MP_GROUPS
  sta a:.loword(menuPage)
  stz a:.loword(menuAction)
  bra @changed
:
  cmp #MP_SOUND
  bne :+
  jsr .loword(mix_apply)
  bra @main_back
:
  cmp #MP_LEVEL
  bne :+
  lda #MP_SOUND
  sta a:.loword(menuPage)
  bra @changed
:
@main_back:
  stz a:.loword(menuPage)       ; MP_MAIN
  stz a:.loword(menuAction)
  bra @changed
@key:
  lda a:.loword(menuListen)
  beq @navigate
  jsr .loword(menu_bind)
  bra @changed
@navigate:
  jsr .loword(menu_key)
@changed:
  lda a:.loword(menuMode)
  beq @resume
  lda #1
  sta a:.loword(menuDirty)
@wait:
  ; The menu is not a game update: it waits MENU_WAIT ticks for the next
  ; sample and sends the sound uploads (DBR = 0) in the wait. It makes no
  ; ADB transactions itself.
  lda f:GAME_CLOCK
  sta a:.loword(menuTime)
@tick:
  a8
  phb
  lda #0
  pha
  plb
  jsl audio_game_upload
  plb
  a16
  lda f:GAME_CLOCK
  sec
  sbc a:.loword(menuTime)
  cmp #MENU_WAIT
  bcc @tick
  jmp .loword(@loop)
@resume:
  stz a:.loword(menuMode)
  a8
  lda a:.loword(menu_saved_color)
  sta f:TBCOLOR
  a16
  jsl display_apply
  jsl mirror_close
  lda #1
  sta a:.loword(menuWasDown)
  ; The time in the menu is not owed to the game: the next update is due
  ; now. The sound clock goes on.
  lda f:GAME_CLOCK
  jsl game_clock_fraction_step
  sta f:GAME_DUE
  pld
  plb
  ply
  plx
  plp
  rtl

; menu_key: a key on a menu page. A device gives its directions as the
; arrow keys and its buttons as RETURN. The display pages go to
; display_key. JSR; A16.
.a16
menu_key:
  lda a:.loword(actionSource)
  cmp #SOURCE_DEVICE_FIRST
  bcc @keyboard
  lda a:.loword(keyAction)
  cmp #ACT_FIRE
  bcs @button
  asl
  tax
  lda a:.loword(menu_direction_keys),x
  bra @dispatch
@button:
  lda #KEY_RETURN
  bra @dispatch
@keyboard:
  lda a:.loword(keyAction)
@dispatch:
  ldx a:.loword(menuPage)
  cpx #MP_MONITOR
  bcc :+
  jsl display_key
  rts
:
  cpx #MP_BINDING
  bne :+
  jmp .loword(@binding_menu)
:
  cpx #MP_LEVEL
  bne :+
  jmp .loword(menu_level_key)
:
  cmp #KEY_UP
  beq :+
  cmp #KEY_MAC_UP
  bne :++
:
  jmp .loword(@up)
:
  cmp #KEY_DOWN
  beq :+
  cmp #KEY_MAC_DOWN
  bne :++
:
  jmp .loword(@down)
:
  cpx #MP_DIPS
  bne :+
  jmp .loword(menu_dip_key)
:
  cpx #MP_SOUND
  beq @audio
  cmp #KEY_RETURN
  beq @enter
  cmp #KEY_RIGHT
  beq @right
  cmp #KEY_MAC_RIGHT
  beq @right
  rts
@audio:
  jmp .loword(menu_audio_key)
@right:
  cpx #MP_DEVICES               ; RIGHT changes a device value
  bne :+
  jmp .loword(@device)
:
  rts
@enter:
  cpx #MP_MAIN
  beq @main
  cpx #MP_GROUPS
  beq @control_group
  cpx #MP_ACTIONS
  beq @controls
  cpx #MP_DEVICES
  bne :+
  jmp .loword(@device)
:
  rts
@main:
  lda a:.loword(menuAction)
  cmp #MAIN_DISPLAY
  bcc @open_page
  bne :+
  lda #MP_MONITOR               ; the page of the monitor found at the start
  sta a:.loword(menuPage)
  stz a:.loword(menuAction)
  rts
:
  cmp #MAIN_DIPS
  bne :+
  lda #MP_DIPS
  sta a:.loword(menuPage)
  stz a:.loword(menuAction)
  rts
:
  cmp #MAIN_SAVE
  beq @save
  stz a:.loword(menuMode)       ; MAIN_RESUME
  rts
@save:
  jmp .loword(settings_save)
@open_page:
  inc                           ; MP_GROUPS, MP_DEVICES or MP_SOUND
  sta a:.loword(menuPage)
  stz a:.loword(menuAction)
  stz a:.loword(menuAlias)
  rts
@control_group:
  lda a:.loword(menuAction)
  cmp #GROUP_BACK
  beq @back
  asl
  tax
  lda a:.loword(menu_group_bases),x
  sta a:.loword(menuBase)
  lda a:.loword(menu_group_limits),x
  sta a:.loword(menuLimit)
  lda #MP_ACTIONS
  sta a:.loword(menuPage)
  stz a:.loword(menuAction)
  stz a:.loword(menuAlias)
  rts
@controls:
  lda a:.loword(menuAction)
  cmp a:.loword(menuLimit)
  beq @group_back               ; BACK
  clc
  adc a:.loword(menuBase)
  sta a:.loword(menuAction)     ; the BIND_ACTION
  lda #MP_BINDING
  sta a:.loword(menuPage)
  stz a:.loword(menuChoice)
  rts
@group_back:
  lda #MP_GROUPS
  sta a:.loword(menuPage)
  stz a:.loword(menuAction)
  rts
@back:
  stz a:.loword(menuPage)       ; MP_MAIN
  stz a:.loword(menuAction)
  rts
@device:
  lda a:.loword(menuAction)
  cmp #DEVICE_BACK
  beq @back
  jmp .loword(menu_device)
@up:
  lda a:.loword(menuAction)
  beq @done
  dec a:.loword(menuAction)
  stz a:.loword(menuAlias)
@done:
  rts
@down:
  lda a:.loword(menuPage)
  beq @main_limit
  cmp #MP_GROUPS
  beq @group_limit
  cmp #MP_ACTIONS
  beq @controls_limit
  cmp #MP_DEVICES
  beq @device_limit
  cmp #MP_DIPS
  bne :+
  lda #DIP_BACK
  bra @limit
:
  lda #SOUND_BACK
  bra @limit
@main_limit:
  lda #MAIN_RESUME
  bra @limit
@group_limit:
  lda #GROUP_BACK
  bra @limit
@controls_limit:
  lda a:.loword(menuLimit)
  bra @limit
@device_limit:
  lda #DEVICE_BACK
@limit:
  cmp a:.loword(menuAction)
  beq @done
  inc a:.loword(menuAction)
  stz a:.loword(menuAlias)
  rts
@binding_menu:
  cmp #KEY_UP
  beq @choice_up
  cmp #KEY_MAC_UP
  beq @choice_up
  cmp #KEY_DOWN
  beq @choice_down
  cmp #KEY_MAC_DOWN
  beq @choice_down
  cmp #KEY_RETURN
  bne @done
  ; RETURN: 0 change, 1 add, 2 remove, 3 the next binding, 4 both
  ; keyboards, 5 back.
  lda a:.loword(menuChoice)
  beq @replace
  dec
  beq @add
  dec
  beq @delete
  dec
  beq @next_alias
  dec
  beq @both
  jmp .loword(menu_binding_back)
@choice_up:
  lda a:.loword(menuChoice)
  beq @done
  dec a:.loword(menuChoice)
  rts
@choice_down:
  lda a:.loword(menuChoice)
  cmp #BINDING_BACK
  beq @done
  inc a:.loword(menuChoice)
  rts
@next_alias:
  inc a:.loword(menuAlias)
  rts
@replace:
  lda #LISTEN_CHANGE
  sta a:.loword(menuListen)
  rts
@add:
  lda #LISTEN_ADD
  sta a:.loword(menuListen)
  rts
@delete:
  jsr .loword(menu_selected_binding)
  cpx #NO_BINDING
  bcc :+
  rts
:
  lda #BIND_NONE                ; BIND_KEY; BIND_SOURCE: SOURCE_NONE
  sta a:.loword(settings+SET_BINDINGS+BIND_KEY),x
  sta a:.loword(settings+SET_BINDINGS+BIND_ACTION),x
  jmp .loword(compile_bindings)
@both:
  jsr .loword(menu_selected_binding)
  cpx #NO_BINDING
  bcc :+
  rts
:
  lda a:.loword(settings+SET_BINDINGS+BIND_SOURCE),x
  and #255
  cmp #SOURCE_DEVICE_FIRST      ; keys only
  bcc :+
  rts
:
  a8
  lda #SOURCE_KEYBOARDS
  sta a:.loword(settings+SET_BINDINGS+BIND_SOURCE),x
  a16
  jmp .loword(compile_bindings)

; menu_binding_back: from MP_BINDING back to its action on MP_ACTIONS. JSR.
menu_binding_back:
  lda a:.loword(menuAction)
  sec
  sbc a:.loword(menuBase)
  sta a:.loword(menuAction)
  lda #MP_ACTIONS
  sta a:.loword(menuPage)
  rts

; menu_device: RETURN or RIGHT on a choice of MP_DEVICES: 0 J13 on or off,
; 1 the next pad slot, 2 look for the joystick again, 3 the next dead zone,
; 4 and 5 the player of the mouse and of the joystick, 6 the default
; bindings. JSR; A16.
menu_device:
  lda a:.loword(menuAction)
  bne @slot
  lda a:.loword(j13Available)
  bne :+
  rts
:
  lda a:.loword(j13Enabled)
  eor #J13_ON
  sta a:.loword(j13Enabled)
  lda #J13_CHOSEN
  sta a:.loword(j13Manual)
  jsl J13SettingsStore
  rts
@slot:
  dec
  bne @joystick
  a8
  lda a:.loword(settings+SET_SNES_SLOT)
  inc
  cmp #PAD_SLOT_SKIP
  bne :+
  inc
:
  cmp #PAD_SLOT_END
  bcc :+
  lda #0
:
  sta a:.loword(settings+SET_SNES_SLOT)
  a16
  jmp .loword(compile_bindings)
@joystick:
  dec
  bne @dead_zone
  a8
  stz a:.loword(joyAbsent)
  stz a:.loword(joyPresent)     ; the first read waits for the stick again
  stz a:.loword(joyCheck)
  lda #OPCODE_LDA_DP            ; input_poll works again (joy_read made it RTS)
  sta f:input_poll
  a16
  lda #JOY_READ_NOW
  sta a:.loword(joyUpdate)
  rts
@dead_zone:
  dec
  bne @players
  a8
  lda a:.loword(settings+SET_DEAD_ZONE)
  clc
  adc #DEAD_ZONE_STEP
  cmp #DEAD_ZONE_MAX+1
  bcc :+
  lda #DEAD_ZONE_STEP
:
  sta a:.loword(settings+SET_DEAD_ZONE)
  a16
  rts
@players:
  dec
  beq @mouse_player
  dec
  beq @joy_player
  stz a:.loword(settings+SET_MOUSE_PLAYER)  ; and SET_JOY_PLAYER: player 2
  ldx #BINDINGS_BYTES-2
@copy:
  lda a:.loword(menu_default_bindings),x
  sta a:.loword(settings+SET_BINDINGS+BIND_KEY),x
  dex
  dex
  bpl @copy
  jmp .loword(compile_bindings)
@mouse_player:
  ldx #0                        ; SET_MOUSE_PLAYER
  lda #SOURCE_MOUSE
  bra menu_player_change
@joy_player:
  ldx #SET_JOY_PLAYER-SET_MOUSE_PLAYER
  lda #SOURCE_JOYSTICK
; menu_player_change: the device A (SOURCE_MOUSE or SOURCE_JOYSTICK, its
; player at SET_MOUSE_PLAYER+X) goes to the other player, and its bindings
; to player actions move with it. JSR; A16.
menu_player_change:
  sta a:.loword(menuTemp)
  a8
  lda a:.loword(settings+SET_MOUSE_PLAYER),x
  eor #1
  sta a:.loword(settings+SET_MOUSE_PLAYER),x
  a16
  and #255
  sta a:.loword(menuPlayer)
  ldx #0
@player_loop:
  lda a:.loword(settings+SET_BINDINGS+BIND_SOURCE),x
  and #255
  cmp a:.loword(menuTemp)
  bne @player_next
  lda a:.loword(settings+SET_BINDINGS+BIND_ACTION),x
  and #255
  cmp #ACTION_SYSTEM
  bcs @player_next
  ldy a:.loword(menuPlayer)
  beq @to_p2
  cmp #ACTION_P2
  bcc @player_next
  sec
  sbc #ACTION_P2
  bra @player_store
@to_p2:
  cmp #ACTION_P2
  bcs @player_next
  clc
  adc #ACTION_P2
@player_store:
  a8
  sta a:.loword(settings+SET_BINDINGS+BIND_ACTION),x
  a16
@player_next:
  inx
  inx
  inx
  inx                           ; BINDING_SIZE
  cpx #BINDINGS_BYTES
  bcc @player_loop
  jmp .loword(compile_bindings)

; menu_bind: the key of the wait (keyAction, actionSource) goes to the
; action menuAction: in the selected binding (LISTEN_CHANGE), or in a free
; record (LISTEN_ADD, or the action has no binding). No free record:
; MSG_NO_ROOM. JSR; A16.
menu_bind:
  lda a:.loword(menuListen)
  cmp #LISTEN_ADD
  beq @free
  jsr .loword(menu_selected_binding)
  cpx #NO_BINDING
  bcc @store
@free:
  ldx #0
@find:
  lda a:.loword(settings+SET_BINDINGS+BIND_ACTION),x
  and #255
  cmp #BIND_ACTIONS
  bcs @store
  inx
  inx
  inx
  inx
  cpx #BINDINGS_BYTES
  bcc @find
  lda #MSG_NO_ROOM               ; every binding stays
  sta a:.loword(menuMessage)
  stz a:.loword(menuListen)
  rts
@store:
  ; A device belongs to one player. A binding to an action of the other
  ; player moves the device and its player bindings to that player.
  lda a:.loword(actionSource)
  cmp #SOURCE_MOUSE
  bcc @write
  cmp #SOURCE_PAD1              ; the mouse and the joystick only
  bcs @write
  lda a:.loword(menuAction)
  cmp #ACTION_SYSTEM
  bcs @write
  cmp #ACTION_P2
  lda #0
  bcs :+
  inc                           ; a P1 action: 1
:
  sta a:.loword(menuPlayer)
  phx
  lda a:.loword(actionSource)
  sec
  sbc #SOURCE_MOUSE
  tax
  lda a:.loword(settings+SET_MOUSE_PLAYER),x
  and #255
  cmp a:.loword(menuPlayer)
  beq :+
  lda a:.loword(actionSource)
  jsr .loword(menu_player_change)
:
  plx
@write:
  a8
  lda a:.loword(keyAction)
  sta a:.loword(settings+SET_BINDINGS+BIND_KEY),x
  lda a:.loword(actionSource)
  sta a:.loword(settings+SET_BINDINGS+BIND_SOURCE),x
  lda a:.loword(menuAction)
  sta a:.loword(settings+SET_BINDINGS+BIND_ACTION),x
  a16
  stz a:.loword(menuListen)
  stz a:.loword(menuMessage)
  jmp .loword(compile_bindings)

; menu_selected_binding: X = the offset of the binding menuAlias of the
; action menuAction (past the last one: the first again), or NO_BINDING.
; menu_find_binding: the same for menuFindAction and menuFindAlias. JSR;
; A16.
menu_selected_binding:
  lda a:.loword(menuAction)
  sta a:.loword(menuFindAction)
  lda a:.loword(menuAlias)
  sta a:.loword(menuFindAlias)
menu_find_binding:
  ldx #0
  ldy #NO_BINDING               ; Y: the first binding of the action
@record:
  lda a:.loword(settings+SET_BINDINGS+BIND_ACTION),x
  and #255
  cmp a:.loword(menuFindAction)
  bne @next
  cpy #NO_BINDING
  bne :+
  txy
:
  lda a:.loword(menuFindAlias)
  beq @done
  dec a:.loword(menuFindAlias)
@next:
  inx
  inx
  inx
  inx
  cpx #BINDINGS_BYTES
  bcc @record
  tyx                           ; past the last binding: the first
@done:
  rts

; menu_clear_apple: the text page all spaces. JSR; A16.
menu_clear_apple:
  a8
  lda #TEXT_SPACE
  ldx #TEXT_PAGE_SIZE-1
@clear:
  sta f:TEXT_PAGE1,x
  dex
  bpl @clear
  a16
  rts

; menu_draw: draw the page menuPage in MENU_TEXT and publish it. JSR; A16.
menu_draw:
  a8
  lda #' '
  ldx #MENU_ROWS*MENU_COLUMNS-1
@blank:
  sta f:MENU_TEXT,x
  dex
  bpl @blank
  a16
  lda a:.loword(menuPage)
  beq @main
  cmp #MP_GROUPS
  beq @controls
  cmp #MP_DEVICES
  beq @devices
  cmp #MP_SOUND
  beq @audio
  cmp #MP_DIPS
  bne :+
  jmp .loword(menu_draw_dips)
:
  cmp #MP_MONITOR
  bcc :+
  jsl display_draw
  jmp .loword(menu_footer)
:
  cmp #MP_LEVEL
  bne :+
  jmp .loword(menu_draw_level)
:
  cmp #MP_ACTIONS
  bne :+
  jmp .loword(menu_draw_controls)
:
  jmp .loword(menu_draw_binding)  ; MP_BINDING
@main:
  ldx #0
  ldy #.loword(menu_title_main)
  jsr .loword(menu_put)
  ldy #.loword(menu_main_text)
  lda #MAIN_CHOICES
  jmp .loword(menu_draw_choices)
@devices:
  ldx #0
  ldy #.loword(menu_title_devices)
  jsr .loword(menu_put)
  jmp .loword(menu_draw_devices)
@audio:
  ldx #0
  ldy #.loword(menu_title_sound)
  jsr .loword(menu_put)
  jmp .loword(menu_draw_audio)
@controls:
  ldx #0
  ldy #.loword(menu_title_controls)
  jsr .loword(menu_put)
  ldy #.loword(menu_group_text)
  lda #GROUP_CHOICES
  jmp .loword(menu_draw_choices)

; menu_draw_controls: MP_ACTIONS: the title of the group, each action with
; its selected binding (or UNBOUND), then BACK. JSR; A16.
menu_draw_controls:
  ldx a:.loword(menuBase)
  cpx #0
  bne :+
  ldy #.loword(menu_title_p1)
  bra @title
:
  cpx #ACTION_P2
  bne :+
  ldy #.loword(menu_title_p2)
  bra @title
:
  ldy #.loword(menu_title_system)
@title:
  ldx #0
  jsr .loword(menu_put)
  lda a:.loword(menuBase)
  sta a:.loword(menuFindAction)
  lda #MENU_LIST
  sta a:.loword(menuDest)
@action:
  stz a:.loword(menuFindAlias)
  lda a:.loword(menuFindAction)
  sec
  sbc a:.loword(menuBase)
  cmp a:.loword(menuAction)
  bne :+
  lda a:.loword(menuAlias)      ; the selected action: its selected binding
  sta a:.loword(menuFindAlias)
  a8
  ldx a:.loword(menuDest)
  lda #MENU_MARK
  sta f:MENU_TEXT,x
  a16
:
  lda a:.loword(menuFindAction)
  jsr .loword(menu_name_offset)
  clc
  adc #.loword(menu_actions)
  tay
  ldx a:.loword(menuDest)
  inx
  inx                           ; ACTION_COLUMN
  jsr .loword(menu_copy_name)
  jsr .loword(menu_find_binding)
  cpx #NO_BINDING
  bcs @unbound
  lda a:.loword(settings+SET_BINDINGS+BIND_SOURCE),x
  and #255
  sta a:.loword(menuBindingSource)
  lda a:.loword(settings+SET_BINDINGS+BIND_KEY),x
  and #255
  pha
  lda a:.loword(menuDest)
  clc
  adc #KEY_COLUMN
  tax
  pla
  jsr .loword(menu_copy_binding_name)
  bra @next
@unbound:
  lda a:.loword(menuDest)
  clc
  adc #KEY_COLUMN
  tax
  ldy #.loword(menu_unbound)
  jsr .loword(menu_put)
@next:
  lda a:.loword(menuDest)
  clc
  adc #MENU_PITCH
  sta a:.loword(menuDest)
  inc a:.loword(menuFindAction)
  lda a:.loword(menuFindAction)
  sec
  sbc a:.loword(menuBase)
  cmp a:.loword(menuLimit)
  bcs :+
  jmp .loword(@action)
:
  ldx a:.loword(menuDest)
  ldy #.loword(menu_back)
  jsr .loword(menu_put)
  lda a:.loword(menuAction)
  cmp a:.loword(menuLimit)
  bne menu_footer
  ldx a:.loword(menuDest)
  a8
  lda #MENU_MARK
  sta f:MENU_TEXT,x
  a16
; menu_footer: the message menuMessage (if any) on the footer row, then
; publish. JSR; A16.
menu_footer:
  lda a:.loword(menuMessage)
  beq @publish
  dec
  asl
  tax
  lda a:.loword(menu_messages),x
  tay
  ldx #MENU_FOOTER
  jsr .loword(menu_put)
@publish:
  jmp .loword(menu_publish)
.assert ACTION_COLUMN = 2, error  ; the two INXs above

; menu_draw_choices: the A choices from Y (menu_list), then the marker at
; menuAction. menu_draw_marker: the marker at the choice A, then the footer.
; JSR; A16.
menu_draw_choices:
  jsr .loword(menu_list)
  lda a:.loword(menuAction)
menu_draw_marker:
  sta a:.loword(menuTemp)       ; X = MENU_LIST + A * MENU_PITCH
  asl
  asl
  asl
  sec
  sbc a:.loword(menuTemp)
  asl
  asl
  asl
  clc
  adc #MENU_LIST
  tax
  a8
  lda #MENU_MARK
  sta f:MENU_TEXT,x
  a16
  jmp .loword(menu_footer)
.assert MENU_PITCH = 7*8, error

; menu_draw_binding: MP_BINDING: the action, its selected binding (the key
; and its source) or UNBOUND, WAITING in a wait for a key, the choices.
; JSR; A16.
menu_draw_binding:
  lda a:.loword(menuAction)
  jsr .loword(menu_name_offset)
  clc
  adc #.loword(menu_actions)
  tay
  ldx #0
  jsr .loword(menu_copy_name)
  jsr .loword(menu_selected_binding)
  cpx #NO_BINDING
  bcs @no_binding
  lda a:.loword(settings+SET_BINDINGS+BIND_SOURCE),x
  and #255
  sta a:.loword(menuBindingSource)
  lda a:.loword(settings+SET_BINDINGS+BIND_KEY),x
  and #255
  ldx #BINDING_COLUMN
  jsr .loword(menu_copy_binding_name)
  lda a:.loword(menuListen)
  bne @choices
  lda a:.loword(menuBindingSource)
  asl
  sta a:.loword(menuTemp)
  asl
  asl
  asl
  sec
  sbc a:.loword(menuTemp)       ; times SOURCE_NAME_SIZE
  clc
  adc #.loword(menu_sources)
  tay
  ldx #MENU_COLUMNS             ; row 1
  lda #SOURCE_NAME_SIZE
  jsr .loword(menu_copy)
  bra @choices
@no_binding:
  ldx #BINDING_COLUMN
  ldy #.loword(menu_unbound)
  jsr .loword(menu_put)
@choices:
  lda a:.loword(menuListen)
  beq :+
  ldx #MENU_COLUMNS
  ldy #.loword(menu_waiting)
  jsr .loword(menu_put)
:
  ldy #.loword(menu_binding_text)
  lda #BINDING_CHOICES
  jsr .loword(menu_list)
  lda a:.loword(menuChoice)
  jmp .loword(menu_draw_marker)
.assert SOURCE_NAME_SIZE = 16-2, error

; menu_draw_devices: MP_DEVICES: the choices, their values in
; DEVICE_COLUMN and the marker. JSR; A16.
menu_draw_devices:
  ldy #.loword(menu_device_text)
  lda #DEVICE_CHOICES
  jsr .loword(menu_list)
  lda a:.loword(j13Available)
  bne :+
  ldx #MENU_LIST+DEVICE_COLUMN
  ldy #.loword(menu_unavailable)
  jsr .loword(menu_put)
  bra @slot_value
:
  lda a:.loword(j13Enabled)
  ldx #MENU_LIST+DEVICE_COLUMN
  jsr .loword(menu_draw_boolean)
@slot_value:
  lda a:.loword(settings+SET_SNES_SLOT)
  and #255
  bne :+
  ldx #MENU_LIST+MENU_PITCH+DEVICE_COLUMN
  ldy #.loword(menu_audio_off)
  jsr .loword(menu_put)
  bra @joy_value
:
  ora #'0'
  a8
  sta f:MENU_TEXT+MENU_LIST+MENU_PITCH+DEVICE_COLUMN
  a16
@joy_value:
  lda a:.loword(joyAbsent)
  and #255
  beq :+
  ldy #.loword(menu_unavailable)
  bra @joy_status
:
  ldy #.loword(menu_found)
@joy_status:
  ldx #MENU_LIST+2*MENU_PITCH+DEVICE_COLUMN
  jsr .loword(menu_put)
  a8
  lda #'P'
  sta f:MENU_TEXT+MENU_LIST+4*MENU_PITCH+DEVICE_COLUMN
  sta f:MENU_TEXT+MENU_LIST+5*MENU_PITCH+DEVICE_COLUMN
  lda a:.loword(settings+SET_MOUSE_PLAYER)
  eor #1                        ; 1 player 1, 0 player 2
  clc
  adc #'1'
  sta f:MENU_TEXT+MENU_LIST+4*MENU_PITCH+DEVICE_COLUMN+1
  lda a:.loword(settings+SET_JOY_PLAYER)
  eor #1
  clc
  adc #'1'
  sta f:MENU_TEXT+MENU_LIST+5*MENU_PITCH+DEVICE_COLUMN+1
  a16
  lda a:.loword(settings+SET_DEAD_ZONE)  ; two digits
  and #255
  ldx #0
@tens:
  cmp #10
  bcc @ones
  sec
  sbc #10
  inx
  bra @tens
@ones:
  ora #'0'
  a8
  sta f:MENU_TEXT+MENU_LIST+3*MENU_PITCH+DEVICE_COLUMN+1
  txa
  ora #'0'
  sta f:MENU_TEXT+MENU_LIST+3*MENU_PITCH+DEVICE_COLUMN
  a16
  lda a:.loword(menuAction)
  jmp .loword(menu_draw_marker)

; menu_list: A zero-ended texts from Y (one after the other) on the rows
; of a list from MENU_LIST. JSR; A16.
menu_list:
  sta a:.loword(menuCount)
  lda #MENU_LIST
  sta a:.loword(menuDest)
@row:
  ldx a:.loword(menuDest)
  jsr .loword(menu_put)
  iny                           ; past the zero
  lda a:.loword(menuDest)
  clc
  adc #MENU_PITCH
  sta a:.loword(menuDest)
  dec a:.loword(menuCount)
  bne @row
  rts

; menu_draw_boolean: ON or OFF (the byte A) at X. JSR; A16.
menu_draw_boolean:
  and #255
  beq :+
  ldy #.loword(menu_audio_on)
  bra @write
:
  ldy #.loword(menu_audio_off)
@write:
  jmp .loword(menu_put)

; menu_copy_binding_name: at X the name of the key A of the source
; menuBindingSource: a key name, else KEY and the code in hex; for a device
; the name of its action (the mouse and joystick, or a pad). JSR; A16.
menu_copy_binding_name:
  phx
  ldx a:.loword(menuBindingSource)
  cpx #SOURCE_DEVICE_FIRST
  bcs @device
  tax
  a8
  lda a:.loword(menu_key_index),x
  cmp #KEY_NO_NAME
  beq @hex
  a16
  and #255
  jsr .loword(menu_name_offset)
  clc
  adc #.loword(menu_key_names)
  bra @copy
@hex:
  a16
  txa
  sta a:.loword(menuPlayer)     ; the code
  ldy #.loword(menu_key_prefix)
  plx
  jsr .loword(menu_put)
  lda a:.loword(menuPlayer)
  pha
  lsr
  lsr
  lsr
  lsr
  tay
  a8
  lda a:.loword(menu_hex),y
  sta f:MENU_TEXT,x
  inx
  a16
  pla
  and #15                       ; the low digit
  tay
  a8
  lda a:.loword(menu_hex),y
  sta f:MENU_TEXT,x
  a16
  rts
@device:
  jsr .loword(menu_name_offset)
  ldx a:.loword(menuBindingSource)
  cpx #SOURCE_PAD1
  bcs @pad
  clc
  adc #.loword(menu_device_names)
  bra @copy
@pad:
  clc
  adc #.loword(menu_pad_names)
@copy:
  tay
  plx
  jmp .loword(menu_copy_name)

; menu_name_offset: A = A * NAME_SIZE. JSR; A16.
menu_name_offset:
  asl
  sta a:.loword(menuTemp)
  asl
  asl
  clc
  adc a:.loword(menuTemp)
  rts
.assert NAME_SIZE = 10, error

; menu_put: the zero-ended text at Y (in this bank) to MENU_TEXT+X; it
; stops with Y at the zero. A text fits on its row. JSR; A16.
menu_put:
  a8
@byte:
  lda a:0,y
  beq @done
  sta f:MENU_TEXT,x
  inx
  iny
  bra @byte
@done:
  a16
  rts
; menu_copy_name: NAME_SIZE bytes from Y to MENU_TEXT+X. menu_copy: A
; bytes. JSR; A16.
menu_copy_name:
  lda #NAME_SIZE
menu_copy:
  sta a:.loword(menuCount)
  a8
@byte:
  lda a:0,y
  sta f:MENU_TEXT,x
  inx
  iny
  a16
  dec a:.loword(menuCount)
  a8
  bne @byte
  a16
  rts

; menu_publish: copy the MENU_ROWS x MENU_COLUMNS layout to the centre of
; the 40-column text page (menu_apple_rows) with bit 7 flipped. The card
; shows this page while the game stops. JSR; A16.
menu_publish:
  stz a:.loword(menuRow)
  stz a:.loword(menuFlat)
@row:
  lda a:.loword(menuRow)
  asl
  tax
  lda a:.loword(menu_apple_rows),x
  sta a:.loword(menuDest)
  lda #MENU_COLUMNS
  sta a:.loword(menuCount)
@column:
  ldx a:.loword(menuFlat)
  a8
  lda f:MENU_TEXT,x
  eor #TEXT_NORMAL
  ldx a:.loword(menuDest)
  sta f:TEXT_PAGE1,x
  a16
  inc a:.loword(menuFlat)
  inc a:.loword(menuDest)
  dec a:.loword(menuCount)
  bne @column
  inc a:.loword(menuRow)
  lda a:.loword(menuRow)
  cmp #MENU_ROWS
  bcc @row
  rts

; The menu texts.
menu_direction_keys: .word KEY_RIGHT,KEY_LEFT,KEY_DOWN,KEY_UP  ; ACT_RIGHT...
menu_title_main: .asciiz "1943 OPTIONS"
menu_title_controls: .asciiz "CONTROLS"
menu_title_p1: .asciiz "PLAYER 1"
menu_title_p2: .asciiz "PLAYER 2"
menu_title_system: .asciiz "START AND COINS"
menu_title_devices: .asciiz "DEVICES"
menu_title_sound: .asciiz "SOUND"
menu_key_prefix: .asciiz "KEY "
menu_hex: .byte "0123456789ABCDEF"
menu_unavailable: .asciiz "NO DEVICE"
menu_found: .asciiz "FOUND"
menu_unbound: .asciiz "UNBOUND"
menu_waiting: .asciiz "WAITING"
menu_back: .asciiz "  BACK"
menu_messages: .word .loword(menu_saved),.loword(menu_full),.loword(menu_error)  ; MSG_*
menu_saved: .asciiz "SETTINGS SAVED"
menu_full: .asciiz "BINDINGS FULL"
menu_error: .asciiz "SAVE FAILED"
menu_main_text:
  .asciiz "  CONTROLS"
  .asciiz "  DEVICES"
  .asciiz "  SOUND"
  .asciiz "  DISPLAY"
  .asciiz "  DIP SWITCHES"
  .asciiz "  SAVE"
  .asciiz "  RESUME"
menu_group_text:
  .asciiz "  PLAYER 1"
  .asciiz "  PLAYER 2"
  .asciiz "  START AND COINS"
  .asciiz "  BACK"
menu_binding_text:
  .asciiz "  CHANGE"
  .asciiz "  ADD"
  .asciiz "  REMOVE"
  .asciiz "  NEXT BINDING"
  .asciiz "  BOTH KEYBOARDS"
  .asciiz "  BACK"
menu_device_text:
  .asciiz "  J13 PLAY"
  .asciiz "  SNES MAX SLOT"
  .asciiz "  RECHECK JOYSTICK"
  .asciiz "  MOUSE DEAD ZONE"
  .asciiz "  MOUSE PLAYER"
  .asciiz "  JOYSTICK PLAYER"
  .asciiz "  RESTORE DEFAULT BINDINGS"
  .asciiz "  BACK"
; MP_GROUPS: the first action and the count of actions of each group.
menu_group_bases: .word 0,ACTION_P2,ACTION_SYSTEM
menu_group_limits: .word PLAYER_ACTIONS,PLAYER_ACTIONS,SYSTEM_ACTIONS
; The menu state.
menu_saved_color: .word 0       ; TBCOLOR before the menu
menuWasDown: .word 0            ; 1: ESC is held since the menu closed
menuDirty: .word 0              ; 1: draw the page again
menuPage: .word 0               ; MP_*
menuAction: .word 0             ; the choice; on MP_BINDING the action
menuAlias: .word 0              ; the selected binding of the action
menuChoice: .word 0             ; the choice on MP_BINDING, the level on MP_LEVEL
menuBase: .word 0               ; MP_ACTIONS: the first action of the group
menuLimit: .word 0              ; MP_ACTIONS: the count of actions (BACK)
menuPlayer: .word 0             ; menu_player_change: 1 player 1, 0 player 2
menuListen: .word 0             ; LISTEN_*: the menu waits for a key; 0 no
menuMessage: .word 0            ; MSG_*; 0 none
menuSerial: .word 0             ; inputSerial at the last key
menuTime: .word 0               ; GAME_CLOCK at the last sample
menuFindAction: .word 0         ; menu_find_binding: the action
menuFindAlias: .word 0          ; menu_find_binding: the binding number
menuDest: .word 0               ; the MENU_TEXT offset of the next row
menuBindingSource: .word 0      ; menu_copy_binding_name: the source
menuTemp: .word 0
menuCount: .word 0              ; menu_list, menu_copy: the count left
menuRow: .word 0                ; menu_publish: the row
menuFlat: .word 0               ; menu_publish: the MENU_TEXT offset

; menu_audio_key: RETURN on MP_SOUND: a volume opens MP_LEVEL at its
; level; DEMO SOUNDS changes; BACK applies the mix. JSR; A16.
.a16
menu_audio_key:
  cmp #KEY_RETURN
  beq :+
  rts
:
  ldx a:.loword(menuAction)
  cpx #SOUND_BACK
  beq @back
  cpx #SOUND_DEMO
  beq @demo
  lda a:.loword(settings+SET_MUSIC_LEVEL),x
  and #255
  sta a:.loword(menuChoice)
  lda #MP_LEVEL
  sta a:.loword(menuPage)
  rts
@demo:
  a8
  lda a:.loword(settings+SET_MIX_FLAGS)
  eor #MIX_DEMO_SOUND
  sta a:.loword(settings+SET_MIX_FLAGS)
  jsl dip_apply
  a16
  rts
@back:
  jsr .loword(mix_apply)
  stz a:.loword(menuPage)       ; MP_MAIN
  stz a:.loword(menuAction)
  rts
.assert SET_EFFECTS_LEVEL = SET_MUSIC_LEVEL+SOUND_EFFECTS, error

; menu_level_key: MP_LEVEL: UP and DOWN move the choice; RETURN sets the
; volume and goes back to MP_SOUND. A music volume applies at once (with
; the effects volume in use), an effects volume at BACK. JSR; A16.
menu_level_key:
  cmp #KEY_UP
  beq @up
  cmp #KEY_MAC_UP
  beq @up
  cmp #KEY_DOWN
  beq @down
  cmp #KEY_MAC_DOWN
  beq @down
  cmp #KEY_RETURN
  bne @done
  ldx a:.loword(menuAction)
  lda a:.loword(menuChoice)
  a8
  sta a:.loword(settings+SET_MUSIC_LEVEL),x
  a16
  cpx #SOUND_EFFECTS
  beq :+
  ; A new effects volume (not applied yet) must not go to the mix with
  ; the music volume.
  a8
  lda a:.loword(settings+SET_EFFECTS_LEVEL)
  pha
  lda a:.loword(mixEffects)
  sta a:.loword(settings+SET_EFFECTS_LEVEL)
  a16
  jsr .loword(mix_apply)
  a8
  pla
  sta a:.loword(settings+SET_EFFECTS_LEVEL)
  a16
:
  lda #MP_SOUND
  sta a:.loword(menuPage)
  rts
@up:
  lda a:.loword(menuChoice)
  beq @done
  dec a:.loword(menuChoice)
  rts
@down:
  lda a:.loword(menuChoice)
  cmp #MIX_LEVEL_MAX
  beq @done
  inc a:.loword(menuChoice)
@done:
  rts

; menu_draw_level: MP_LEVEL: the title, the levels 0-100 on the rows of a
; list, and the marker at menuChoice. JSR; A16.
menu_draw_level:
  ldx #0
  ldy #.loword(menu_level_music)
  lda a:.loword(menuAction)
  beq :+
  ldy #.loword(menu_level_effects)
:
  jsr .loword(menu_put)
  ldx #0
@row:
  phx
  txa
  asl
  sta a:.loword(menuTemp)
  txa
  clc
  adc a:.loword(menuTemp)       ; times LEVEL_TEXT_SIZE
  clc
  adc #.loword(menu_audio_numbers)
  tay
  txa
  sta a:.loword(menuTemp)
  asl
  asl
  asl
  sec
  sbc a:.loword(menuTemp)
  asl
  asl
  asl                           ; times MENU_PITCH
  clc
  adc #MENU_LIST+LEVEL_COLUMN
  tax
  lda #LEVEL_TEXT_SIZE
  jsr .loword(menu_copy)
  plx
  inx
  cpx #MIX_LEVELS
  bcc @row
  lda a:.loword(menuChoice)
  jmp .loword(menu_draw_marker)
.assert LEVEL_TEXT_SIZE = 3, error

; menu_draw_audio: MP_SOUND: the choices, the two volumes and the demo
; sound (ON or OFF) in SOUND_COLUMN, and the marker. JSR; A16.
menu_draw_audio:
  ldy #.loword(menu_audio_text)
  lda #SOUND_CHOICES
  jsr .loword(menu_list)
  ldx #0
@value:
  phx
  lda a:.loword(settings+SET_MUSIC_LEVEL),x
  and #255
  asl
  clc
  adc a:.loword(settings+SET_MUSIC_LEVEL),x
  and #255                      ; times LEVEL_TEXT_SIZE
  clc
  adc #.loword(menu_audio_numbers)
  tay
  cpx #0
  bne @second_value
  ldx #MENU_LIST+SOUND_COLUMN
  bra @value_pos
@second_value:
  ldx #MENU_LIST+MENU_PITCH+SOUND_COLUMN
@value_pos:
  lda #LEVEL_TEXT_SIZE
  jsr .loword(menu_copy)
  plx
  inx
  cpx #SOUND_DEMO               ; the two volumes
  bcc @value
  a8
  lda a:.loword(settings+SET_MIX_FLAGS)
  beq @off
  a16
  ldy #.loword(menu_audio_on)
  bra @demo
@off:
  a16
  ldy #.loword(menu_audio_off)
@demo:
  ldx #MENU_LIST+2*MENU_PITCH+SOUND_COLUMN
  jsr .loword(menu_put)
  lda a:.loword(menuAction)
  jmp .loword(menu_draw_marker)
menu_audio_numbers: .byte "0  10 20 30 40 50 60 70 80 90 100"
menu_level_music: .asciiz "MUSIC VOLUME"
menu_level_effects: .asciiz "EFFECTS VOLUME"
menu_audio_on: .asciiz "ON"
menu_audio_off: .asciiz "OFF"
menu_audio_text:
  .asciiz "  MUSIC VOLUME"
  .asciiz "  EFFECTS VOLUME"
  .asciiz "  DEMO SOUNDS"
  .asciiz "  BACK"

; The DIP switches of MP_DIPS: a dip_items entry for each choice before
; DIP_BACK. The value of a switch is its index (0 to its count - 1) in the
; order of its names: the bits inverted (a switch is on at 0), shifted down.
DI_OFFSET = 0                ; .word: the settings byte (SET_DIP_A, ...)
DI_MASK = 2                  ; the bits of the switch
DI_COUNT = 3                 ; its values
DI_SHIFT = 4                 ; .word: the low bit of DI_MASK
DI_NAMES = 6                 ; .word: the zero-ended value names; 0: the number 1-16
DIP_ITEM_SIZE = 8
dip_items:
  .word SET_DIP_A
  .byte DIP_A_LEVEL,16
  .word 0,0
  .word SET_DIP_A
  .byte DIP_A_TWO_CREDITS,2
  .word 4,.loword(dip_players)
  .word SET_DIP_B
  .byte DIP_B_COIN_A,8
  .word 0,.loword(dip_coins)
  .word SET_DIP_B
  .byte DIP_B_COIN_B,8
  .word DIP_B_COIN_B_SHIFT,.loword(dip_coins)
  .word SET_DIP_B
  .byte DIP_B_CONTINUE,2
  .word 6,.loword(menu_audio_on)
  .word SET_MIX_FLAGS
  .byte MIX_DEMO_SOUND,2
  .word 0,.loword(menu_audio_on)
  .word SET_DIP_A
  .byte DIP_A_STOP,2
  .word 6,.loword(dip_off_on)
.assert *-dip_items = DIP_BACK*DIP_ITEM_SIZE, error
.assert DIP_A_TWO_CREDITS = 1<<4 .and DIP_B_CONTINUE = 1<<6 .and DIP_A_STOP = 1<<6, error
.assert DIP_B_COIN_B = DIP_B_COIN_A<<DIP_B_COIN_B_SHIFT .and DIP_A_LEVEL = 15, error
menu_dip_text:
  .asciiz "  DIFFICULTY (1-16)"
  .asciiz "  2 PLAYER GAME"
  .asciiz "  COIN A"
  .asciiz "  COIN B"
  .asciiz "  CONTINUE"
  .asciiz "  DEMO SOUNDS"
  .asciiz "  SCREEN STOP"
  .asciiz "  BACK"
dip_players:
  .asciiz "2 PLAYERS COST 2 CREDITS"
  .asciiz "2 PLAYERS COST 1 CREDIT"
dip_coins:                    ; the index of the switch value: its bits inverted
  .asciiz "1 COIN 1 CREDIT"
  .asciiz "1 COIN 2 CREDITS"
  .asciiz "1 COIN 3 CREDITS"
  .asciiz "1 COIN 4 CREDITS"
  .asciiz "1 COIN 5 CREDITS"
  .asciiz "2 COINS 1 CREDIT"
  .asciiz "3 COINS 1 CREDIT"
  .asciiz "4 COINS 1 CREDIT"
dip_off_on:
  .asciiz "OFF"
  .asciiz "ON"
.assert menu_audio_off = menu_audio_on+3, error  ; "ON" then "OFF"

; menu_dip_key: the key A on MP_DIPS: RETURN and RIGHT give the switch of
; the choice its next value, LEFT the one before; RETURN on BACK goes to the
; main page. The switches apply at once (dip_apply); a new difficulty at the
; next game start (cabinet_start). JSR; A16.
.a16
menu_dip_key:
  ldx a:.loword(menuAction)
  cpx #DIP_BACK
  bne @switch
  cmp #KEY_RETURN
  bne @done
  stz a:.loword(menuPage)       ; MP_MAIN
  stz a:.loword(menuAction)
@done:
  rts
@switch:
  ldy #1
  cmp #KEY_RETURN
  beq @step
  cmp #KEY_RIGHT
  beq @step
  cmp #KEY_MAC_RIGHT
  beq @step
  ldy #$ffff                    ; -1
  cmp #KEY_LEFT
  beq @step
  cmp #KEY_MAC_LEFT
  bne @done
@step:
  sty a:.loword(menuTemp)
  txa
  asl
  asl
  asl                           ; times DIP_ITEM_SIZE
  tax
  a8
  lda a:.loword(dip_items+DI_COUNT),x
  sta a:.loword(menuCount)
  jsr .loword(dip_index)
  clc
  adc a:.loword(menuTemp)
  bpl @up
  lda a:.loword(menuCount)      ; before the first: the last
  dec
  bra @set
@up:
  cmp a:.loword(menuCount)
  bcc @set
  lda #0                        ; after the last: the first
@set:
  ldy a:.loword(dip_items+DI_SHIFT),x
  beq @placed
@left:
  asl
  dey
  bne @left
@placed:
  eor #$ff                      ; a switch is on at 0
  and a:.loword(dip_items+DI_MASK),x
  sta a:.loword(menuTemp)
  ldy a:.loword(dip_items+DI_OFFSET),x
  lda a:.loword(dip_items+DI_MASK),x
  eor #$ff
  and a:.loword(settings),y
  ora a:.loword(menuTemp)
  sta a:.loword(settings),y
  a16
  jsl dip_apply
  rts
.assert DIP_ITEM_SIZE = 8, error

; dip_index: A8 = the value index of the switch at dip_items+X. JSR; A8.
.a8
dip_index:
  ldy a:.loword(dip_items+DI_OFFSET),x
  lda a:.loword(settings),y
  eor #$ff
  and a:.loword(dip_items+DI_MASK),x
  ldy a:.loword(dip_items+DI_SHIFT),x
  beq @done
@shift:
  lsr
  dey
  bne @shift
@done:
  rts

; menu_draw_dips: MP_DIPS: the title, the switches with their values on the
; row under each, and the marker. JSR; A16.
.a16
menu_draw_dips:
  ldx #0
  ldy #.loword(menu_title_dips)
  jsr .loword(menu_put)
  ldy #.loword(menu_dip_text)
  lda #DIP_CHOICES
  jsr .loword(menu_list)
  lda #MENU_LIST+DIP_VALUE
  sta a:.loword(menuDest)
  ldx #0
@item:
  phx
  a8
  jsr .loword(dip_index)
  a16
  and #255
  ldy a:.loword(dip_items+DI_NAMES),x
  bne @skip
  inc                           ; the difficulty: the number 1-16
  ldx a:.loword(menuDest)
  cmp #10
  bcc @ones
  sbc #10                       ; carry 1
  pha
  lda #'1'
  a8
  sta f:MENU_TEXT,x
  a16
  inx
  pla
@ones:
  ora #'0'
  a8
  sta f:MENU_TEXT,x
  a16
  bra @next
@skip:
  cmp #0                        ; skip A names
  beq @put
  a8
@name:
  lda a:0,y
  iny
  cmp #0
  bne @name
  a16
  dec
  bra @skip
@put:
  ldx a:.loword(menuDest)
  jsr .loword(menu_put)
@next:
  lda a:.loword(menuDest)
  clc
  adc #MENU_PITCH
  sta a:.loword(menuDest)
  pla
  clc
  adc #DIP_ITEM_SIZE
  tax
  cpx #DIP_BACK*DIP_ITEM_SIZE
  bcc @item
  lda a:.loword(menuAction)
  jmp .loword(menu_draw_marker)
menu_title_dips: .asciiz "DIP SWITCHES"
