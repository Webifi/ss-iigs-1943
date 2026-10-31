; Paused foreground UI. Capture and the DOC clock keep running. Game state,
; world residency and VRAM art stay resident; only a display page is repainted.
; Selection marker in the layout buffer. menu_publish flips bit 7, so it
; reaches the text page as $55, the MouseText right arrow (ALTCHAR: boot,
; and mirror_open for the card); every text character becomes normal text.
MENU_MARK = $d5
.a8
.i16
menu_check:
  php
  lda f:INPUT_SYSTEM
  and #16
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
  rep #$30
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
  stz a:.loword(menuPage)
  stz a:.loword(menuAction)
  stz a:.loword(menuAlias)
  stz a:.loword(menuListen)
  stz a:.loword(menuMessage)
  stz a:.loword(menuResumeReady)
  lda a:.loword(inputSerial)
  sta a:.loword(menuSerial)
  jsl J13Menu
  jsl mirror_open
  sep #$20
  lda f:$e0c022
  sta a:.loword(menu_saved_color)
  lda #$f0
  sta f:$e0c022
  rep #$20
  jsr .loword(menu_clear_apple)
@loop:
  lda #$ffff
  sta a:.loword(joyUpdate)
  jsl sample
  rep #$30
  lda a:.loword(menuDirty)
  beq @input
  stz a:.loword(menuDirty)
  jsr .loword(menu_draw)
@input:
  lda a:.loword(inputSerial)
  cmp a:.loword(menuSerial)
  bne :+
  jmp .loword(@wait)
:
  sta a:.loword(menuSerial)
  lda a:.loword(keyAction)
  cmp #$35
  bne @key
  lda a:.loword(actionSource)
  cmp #4
  bcs @key
  lda a:.loword(menuListen)
  beq :+
  stz a:.loword(menuListen)
  bra @changed
:
  lda a:.loword(menuPage)
  bne :+
  jmp .loword(@resume)
:
  cmp #8
  bcc :+
  jsl display_back
  bra @changed
:
  cmp #4
  bne :+
  jsr .loword(menu_binding_back)
  bra @changed
:
  cmp #6
  bne :+
  lda #1
  sta a:.loword(menuPage)
  stz a:.loword(menuAction)
  bra @changed
:
  cmp #3
  bne :+
  jsr .loword(mix_apply)
  bra @main_back
:
  cmp #5
  bne :+
  lda #3
  sta a:.loword(menuPage)
  bra @changed
:
@main_back:
  stz a:.loword(menuPage)
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
  ; This is a menu, not a game logic update. Consume the next captured
  ; event frontier once per DOC tick; no busy ADB transactions here.
  lda f:$001e96
  sta a:.loword(menuTime)
@tick:
  sep #$20
  phb
  lda #0
  pha
  plb
  jsl audio_game_upload
  plb
  rep #$20
  lda f:$001e96
  sec
  sbc a:.loword(menuTime)
  cmp #8
  bcc @tick
  jmp .loword(@loop)
@resume:
  stz a:.loword(menuMode)
  sep #$20
  lda a:.loword(menu_saved_color)
  sta f:$e0c022
  rep #$20
  jsl display_apply
  jsl mirror_close
  lda #1
  sta a:.loword(menuWasDown)
  ; Paused wall time is not game debt. Keep the independent sound clock.
  lda f:$001e96
  jsl game_clock_fraction_step
  sta f:GAME_DUE
  pld
  plb
  ply
  plx
  plp
  rtl

.a16
menu_key:
  lda a:.loword(actionSource)
  cmp #4
  bcc @keyboard
  lda a:.loword(keyAction)
  cmp #4
  bcs @button
  asl
  tax
  lda a:.loword(menu_direction_keys),x
  bra @dispatch
@button:
  lda #$24
  bra @dispatch
@keyboard:
  lda a:.loword(keyAction)
@dispatch:
  ldx a:.loword(menuPage)
  cpx #7
  bcc :+
  jsl display_key
  rts
:
  cpx #4
  bne :+
  jmp .loword(@binding_menu)
:
  cpx #5
  bne :+
  jmp .loword(menu_level_key)
:
  cmp #$3e
  beq :+
  cmp #$7e
  bne :++
:
  jmp .loword(@up)
:
  cmp #$3d
  beq :+
  cmp #$7d
  bne :++
:
  jmp .loword(@down)
:
  cpx #3
  beq @audio
  cmp #$24
  beq @enter
  cmp #$3c
  beq @right
  cmp #$7c
  beq @right
  rts
@audio:
  jmp .loword(menu_audio_key)
@right:
  cpx #2
  bne :+
  jmp .loword(@device)
:
  rts
@enter:
  cpx #0
  beq @main
  cpx #1
  beq @control_group
  cpx #6
  beq @controls
  cpx #2
  beq @device
  rts
@main:
  lda a:.loword(menuAction)
  cmp #3
  bcc @open_page
  bne :+
  lda #8                      ; the detected monitor's display page
  sta a:.loword(menuPage)
  stz a:.loword(menuAction)
  rts
:
  cmp #4
  beq @save
  stz a:.loword(menuMode)
  rts
@save:
  jmp .loword(menu_save)
@open_page:
  inc
  sta a:.loword(menuPage)
  stz a:.loword(menuAction)
  stz a:.loword(menuAlias)
  rts
@control_group:
  lda a:.loword(menuAction)
  cmp #3
  beq @back
  asl
  tax
  lda a:.loword(menu_group_bases),x
  sta a:.loword(menuBase)
  lda a:.loword(menu_group_limits),x
  sta a:.loword(menuLimit)
  lda #6
  sta a:.loword(menuPage)
  stz a:.loword(menuAction)
  stz a:.loword(menuAlias)
  rts
@controls:
  lda a:.loword(menuAction)
  cmp a:.loword(menuLimit)
  beq @group_back
  clc
  adc a:.loword(menuBase)
  sta a:.loword(menuAction)
  lda #4
  sta a:.loword(menuPage)
  stz a:.loword(menuChoice)
  rts
@group_back:
  lda #1
  sta a:.loword(menuPage)
  stz a:.loword(menuAction)
  rts
@back:
  stz a:.loword(menuPage)
  stz a:.loword(menuAction)
  rts
@device:
  lda a:.loword(menuAction)
  cmp #7
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
  cmp #1
  beq @group_limit
  cmp #6
  beq @controls_limit
  cmp #2
  beq @device_limit
  lda #3
  bra @limit
@main_limit:
  lda #5
  bra @limit
@group_limit:
  lda #3
  bra @limit
@controls_limit:
  lda a:.loword(menuLimit)
  bra @limit
@device_limit:
  lda #7
@limit:
  cmp a:.loword(menuAction)
  beq @done
  inc a:.loword(menuAction)
  stz a:.loword(menuAlias)
  rts
@binding_menu:
  cmp #$3e
  beq @choice_up
  cmp #$7e
  beq @choice_up
  cmp #$3d
  beq @choice_down
  cmp #$7d
  beq @choice_down
  cmp #$24
  bne @done
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
  cmp #5
  beq @done
  inc a:.loword(menuChoice)
  rts
@next_alias:
  inc a:.loword(menuAlias)
  rts
@replace:
  lda #1
  sta a:.loword(menuListen)
  rts
@add:
  lda #2
  sta a:.loword(menuListen)
  rts
@delete:
  jsr .loword(menu_selected_binding)
  cpx #256
  bcc :+
  rts
:
  lda #$00ff
  sta a:.loword(settings+32),x
  lda #255
  sta a:.loword(settings+34),x
  jmp .loword(compile_bindings)
@both:
  jsr .loword(menu_selected_binding)
  cpx #256
  bcc :+
  rts
:
  lda a:.loword(settings+33),x
  and #255
  cmp #4
  bcc :+
  rts
:
  sep #$20
  lda #3
  sta a:.loword(settings+33),x
  rep #$20
  jmp .loword(compile_bindings)

menu_binding_back:
  lda a:.loword(menuAction)
  sec
  sbc a:.loword(menuBase)
  sta a:.loword(menuAction)
  lda #6
  sta a:.loword(menuPage)
  rts

menu_device:
  lda a:.loword(menuAction)
  bne @pad
  lda a:.loword(j13Available)
  bne :+
  rts
:
  lda a:.loword(j13Enabled)
  eor #1
  sta a:.loword(j13Enabled)
  lda #2
  sta a:.loword(j13Manual)
  jsl J13SettingsStore
  rts
@pad:
  dec
  bne @joy
  sep #$20
  lda a:.loword(settings+9)
  inc
  cmp #3
  bne :+
  inc
:
  cmp #7
  bcc :+
  lda #0
:
  sta a:.loword(settings+9)
  rep #$20
  jmp .loword(compile_bindings)
@joy:
  dec
  bne @mouse
  sep #$20
  stz a:.loword(joyAbsent)
  lda #$a5                    ; restore input_poll's LDA direct-page update
  sta f:input_poll
  rep #$20
  lda #$ffff
  sta a:.loword(joyUpdate)
  rts
@mouse:
  dec
  bne @reset
  sep #$20
  lda a:.loword(settings+10)
  clc
  adc #3
  cmp #25
  bcc :+
  lda #3
:
  sta a:.loword(settings+10)
  rep #$20
  rts
@reset:
  dec
  beq @mouse_player
  dec
  beq @joy_player
  stz a:.loword(settings+16)
  ldx #254
@copy:
  lda a:.loword(menu_default_bindings),x
  sta a:.loword(settings+32),x
  dex
  dex
  bpl @copy
  jsr .loword(compile_bindings)
  rts
@mouse_player:
  ldx #0
  lda #4
  bra menu_player_change
@joy_player:
  ldx #1
  lda #5
menu_player_change:
  sta a:.loword(menuTemp)
  sep #$20
  lda a:.loword(settings+16),x
  eor #1
  sta a:.loword(settings+16),x
  rep #$20
  and #255
  sta a:.loword(menuPlayer)
  ldx #0
@player_loop:
  lda a:.loword(settings+33),x
  and #255
  cmp a:.loword(menuTemp)
  bne @player_next
  lda a:.loword(settings+34),x
  and #255
  cmp #12
  bcs @player_next
  ldy a:.loword(menuPlayer)
  beq @to_p2
  cmp #6
  bcc @player_next
  sec
  sbc #6
  bra @player_store
@to_p2:
  cmp #6
  bcs @player_next
  clc
  adc #6
@player_store:
  sep #$20
  sta a:.loword(settings+34),x
  rep #$20
@player_next:
  inx
  inx
  inx
  inx
  cpx #256
  bcc @player_loop
  jmp .loword(compile_bindings)
@done:
  rts

menu_bind:
  lda a:.loword(menuListen)
  cmp #2
  beq @free
  jsr .loword(menu_selected_binding)
  cpx #256
  bcc @store
@free:
  ldx #0
@find:
  lda a:.loword(settings+34),x
  and #255
  cmp #17
  bcs @store
  inx
  inx
  inx
  inx
  cpx #256
  bcc @find
  lda #2                      ; no empty record: keep every existing binding
  sta a:.loword(menuMessage)
  stz a:.loword(menuListen)
  rts
@store:
  ; A device belongs to one player. Binding it to the other player's
  ; action moves its existing gameplay bindings along with the choice.
  lda a:.loword(actionSource)
  cmp #4
  bcc @write
  cmp #6
  bcs @write
  lda a:.loword(menuAction)
  cmp #12
  bcs @write
  cmp #6
  lda #0
  bcs :+
  inc
:
  sta a:.loword(menuPlayer)
  phx
  lda a:.loword(actionSource)
  sec
  sbc #4
  tax
  lda a:.loword(settings+16),x
  and #255
  cmp a:.loword(menuPlayer)
  beq :+
  lda a:.loword(actionSource)
  jsr .loword(menu_player_change)
:
  plx
@write:
  sep #$20
  lda a:.loword(keyAction)
  sta a:.loword(settings+32),x
  lda a:.loword(actionSource)
  sta a:.loword(settings+33),x
  lda a:.loword(menuAction)
  sta a:.loword(settings+34),x
  rep #$20
  stz a:.loword(menuListen)
  stz a:.loword(menuMessage)
  jmp .loword(compile_bindings)

; X returns the chosen 4-byte alias or 256 for an unbound action.
menu_selected_binding:
  lda a:.loword(menuAction)
  sta a:.loword(menuFindAction)
  lda a:.loword(menuAlias)
  sta a:.loword(menuFindAlias)
menu_find_binding:
  ldx #0
  ldy #256
@record:
  lda a:.loword(settings+34),x
  and #255
  cmp a:.loword(menuFindAction)
  bne @next
  cpy #256
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
  cpx #256
  bcc @record
  tyx                         ; wrap to first alias
@done:
  rts

menu_clear_apple:
  sep #$20
  lda #$a0
  ldx #1023
@clear:
  sta f:$e00400,x
  dex
  bpl @clear
  rep #$20
  rts

menu_draw:
  sep #$20
  lda #32
  ldx #671
@blank:
  sta f:$000800,x
  dex
  bpl @blank
  rep #$20
  lda a:.loword(menuPage)
  beq @main
  cmp #1
  beq @controls
  cmp #2
  beq @devices
  cmp #3
  beq @audio
  cmp #7
  bcc :+
  jsl display_draw
  jmp .loword(menu_footer)
:
  cmp #5
  bne :+
  jmp .loword(menu_draw_level)
:
  cmp #6
  bne :+
  jmp .loword(menu_draw_controls)
:
  jmp .loword(menu_draw_binding)
@main:
  ldx #0
  ldy #.loword(menu_title_main)
  jsr .loword(menu_put)
  ldy #.loword(menu_main_text)
  lda #6
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
  lda #4
  jmp .loword(menu_draw_choices)

menu_draw_controls:
  ldx a:.loword(menuBase)
  cpx #0
  bne :+
  ldy #.loword(menu_title_p1)
  bra @title
:
  cpx #6
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
  lda #84
  sta a:.loword(menuDest)
@action:
  stz a:.loword(menuFindAlias)
  lda a:.loword(menuFindAction)
  sec
  sbc a:.loword(menuBase)
  cmp a:.loword(menuAction)
  bne :+
  lda a:.loword(menuAlias)
  sta a:.loword(menuFindAlias)
  sep #$20
  ldx a:.loword(menuDest)
  lda #MENU_MARK
  sta f:$000800,x
  rep #$20
:
  lda a:.loword(menuFindAction)
  jsr .loword(menu_times10)
  clc
  adc #.loword(menu_actions)
  tay
  ldx a:.loword(menuDest)
  inx
  inx
  jsr .loword(menu_copy10)
  jsr .loword(menu_find_binding)
  cpx #256
  bcs @unbound
  lda a:.loword(settings+33),x
  and #255
  sta a:.loword(menuBindingSource)
  lda a:.loword(settings+32),x
  and #255
  pha
  lda a:.loword(menuDest)
  clc
  adc #14
  tax
  pla
  jsr .loword(menu_copy_binding_name)
  bra @next
@unbound:
  ldx a:.loword(menuDest)
  txa
  clc
  adc #14
  tax
  ldy #.loword(menu_unbound)
  jsr .loword(menu_put)
@next:
  lda a:.loword(menuDest)
  clc
  adc #56
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
  sep #$20
  lda #MENU_MARK
  sta f:$000800,x
  rep #$20
menu_footer:
  lda a:.loword(menuMessage)
  beq @publish
  dec
  asl
  tax
  lda a:.loword(menu_messages),x
  tay
  ldx #616
  jsr .loword(menu_put)
@publish:
  jsr .loword(menu_publish)
  rts

; Main and action menus use rows separated by one blank row.
menu_draw_choices:
  jsr .loword(menu_list)
  lda a:.loword(menuAction)
menu_draw_marker:
  ; row offset = selected index * 56 + 84
  sta a:.loword(menuTemp)
  asl
  asl
  asl
  sec
  sbc a:.loword(menuTemp)
  asl
  asl
  asl
  clc
  adc #84
  tax
  sep #$20
  lda #MENU_MARK
  sta f:$000800,x
  rep #$20
  jmp .loword(menu_footer)

menu_draw_binding:
  lda a:.loword(menuAction)
  jsr .loword(menu_times10)
  clc
  adc #.loword(menu_actions)
  tay
  ldx #0
  jsr .loword(menu_copy10)
  jsr .loword(menu_selected_binding)
  cpx #256
  bcs @no_binding
  lda a:.loword(settings+33),x
  and #255
  sta a:.loword(menuBindingSource)
  lda a:.loword(settings+32),x
  and #255
  ldx #12
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
  sbc a:.loword(menuTemp)
  clc
  adc #.loword(menu_sources)
  tay
  ldx #28
  lda #14
  jsr .loword(menu_copy)
  bra @choices
@no_binding:
  ldx #12
  ldy #.loword(menu_unbound)
  jsr .loword(menu_put)
@choices:
  lda a:.loword(menuListen)
  beq :+
  ldx #28
  ldy #.loword(menu_waiting)
  jsr .loword(menu_put)
:
  ldy #.loword(menu_binding_text)
  lda #6
  jsr .loword(menu_list)
  lda a:.loword(menuChoice)
  jmp .loword(menu_draw_marker)

menu_draw_devices:
  ldy #.loword(menu_device_text)
  lda #8
  jsr .loword(menu_list)
  lda a:.loword(menuAction)
  ; Device choices use the same two-row pitch as the other menus.
  asl
  sta a:.loword(menuTemp)
  asl
  asl
  asl
  sec
  sbc a:.loword(menuTemp)
  asl
  asl
  clc
  adc #84
  tax
  sep #$20
  lda #MENU_MARK
  sta f:$000800,x
  rep #$20
  lda a:.loword(j13Available)
  bne :+
  ldx #84+19
  ldy #.loword(menu_unavailable)
  jsr .loword(menu_put)
  bra @slot_value
:
  lda a:.loword(j13Enabled)
  ldx #84+19
  jsr .loword(menu_draw_boolean)
@slot_value:
  lda a:.loword(settings+9)
  and #255
  bne :+
  ldx #140+19
  ldy #.loword(menu_audio_off)
  jsr .loword(menu_put)
  bra @joy_value
:
  ora #'0'
  sep #$20
  sta f:$000800+140+19
  rep #$20
@joy_value:
  lda a:.loword(joyAbsent)
  and #255
  beq :+
  ldy #.loword(menu_unavailable)
  bra @joy_status
:
  ldy #.loword(menu_found)
@joy_status:
  ldx #196+19
  jsr .loword(menu_put)
  sep #$20
  lda #'P'
  sta f:$000800+308+19
  sta f:$000800+364+19
  lda a:.loword(settings+16)
  eor #1
  clc
  adc #'1'
  sta f:$000800+308+20
  lda a:.loword(settings+17)
  eor #1
  clc
  adc #'1'
  sta f:$000800+364+20
  rep #$20
  lda a:.loword(settings+10)
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
  sep #$20
  sta f:$000800+252+20
  txa
  ora #'0'
  sta f:$000800+252+19
  rep #$20
  jmp .loword(menu_footer)

menu_list:
  sta a:.loword(menuCount)
  lda #84
  sta a:.loword(menuDest)
@row:
  ldx a:.loword(menuDest)
  jsr .loword(menu_put)
  iny
  lda a:.loword(menuDest)
  clc
  adc #56
  sta a:.loword(menuDest)
  dec a:.loword(menuCount)
  bne @row
  rts

menu_draw_boolean:
  and #255
  beq :+
  ldy #.loword(menu_audio_on)
  bra @write
:
  ldy #.loword(menu_audio_off)
@write:
  jmp .loword(menu_put)

 ; A=physical identity, X=text destination, source in menuBindingSource.
menu_copy_binding_name:
  phx
  ldx a:.loword(menuBindingSource)
  cpx #4
  bcs @device
  tax
  sep #$20
  lda a:.loword(menu_key_index),x
  cmp #255
  beq @hex
  rep #$20
  and #255
  jsr .loword(menu_times10)
  clc
  adc #.loword(menu_key_names)
  bra @copy
@hex:
  rep #$20
  txa
  sta a:.loword(menuPlayer)
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
  sep #$20
  lda a:.loword(menu_hex),y
  sta f:$000800,x
  inx
  rep #$20
  pla
  and #15
  tay
  sep #$20
  lda a:.loword(menu_hex),y
  sta f:$000800,x
  rep #$20
  rts
@device:
  jsr .loword(menu_times10)
  ldx a:.loword(menuBindingSource)
  cpx #6
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
  jmp .loword(menu_copy10)

menu_times10:
  asl
  sta a:.loword(menuTemp)
  asl
  asl
  clc
  adc a:.loword(menuTemp)
  rts

; X=flat text offset, Y=bank-local string; strings never exceed a line.
menu_put:
  sep #$20
@byte:
  lda a:0,y
  beq @done
  sta f:$000800,x
  inx
  iny
  bra @byte
@done:
  rep #$20
  rts
menu_copy10:
  lda #10
menu_copy:
  sta a:.loword(menuCount)
  sep #$20
@byte:
  lda a:0,y
  sta f:$000800,x
  inx
  iny
  rep #$20
  dec a:.loword(menuCount)
  sep #$20
  bne @byte
  rep #$20
  rts

menu_publish:
  ; Copy the 28-column layout into the centered 40-column Apple text page.
  ; The card firmware mirrors this page while gameplay is paused.
  stz a:.loword(menuRow)
  stz a:.loword(menuFlat)
@row:
  lda a:.loword(menuRow)
  asl
  tax
  lda a:.loword(menu_apple_rows),x
  sta a:.loword(menuDest)
  lda #28
  sta a:.loword(menuCount)
@column:
  ldx a:.loword(menuFlat)
  sep #$20
  lda f:$000800,x
  eor #$80
  ldx a:.loword(menuDest)
  sta f:$e00400,x
  rep #$20
  inc a:.loword(menuFlat)
  inc a:.loword(menuDest)
  dec a:.loword(menuCount)
  bne @column
  inc a:.loword(menuRow)
  lda a:.loword(menuRow)
  cmp #24
  bcc @row
  rts

; Save is added by the disk bridge below; UI errors never claim success.
menu_save:
  jmp .loword(settings_save)

menu_direction_keys: .word $3c,$3b,$3d,$3e
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
menu_messages: .word .loword(menu_saved),.loword(menu_full),.loword(menu_error)
menu_saved: .asciiz "SETTINGS SAVED"
menu_full: .asciiz "BINDINGS FULL"
menu_error: .asciiz "SAVE FAILED"
menu_main_text:
  .asciiz "  CONTROLS"
  .asciiz "  DEVICES"
  .asciiz "  SOUND"
  .asciiz "  DISPLAY"
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
menu_group_bases: .word 0,6,12
menu_group_limits: .word 6,6,4
menu_saved_color: .word 0
menuResumeReady: .word 0
menuWasDown: .word 0
menuDirty: .word 0
menuPage: .word 0
menuAction: .word 0
menuAlias: .word 0
menuChoice: .word 0
menuBase: .word 0
menuLimit: .word 0
menuPlayer: .word 0
menuListen: .word 0
menuMessage: .word 0
menuSerial: .word 0
menuTime: .word 0
menuFindAction: .word 0
menuFindAlias: .word 0
menuDest: .word 0
menuBindingSource: .word 0
menuTemp: .word 0
menuCount: .word 0
menuPacket: .word 0
menuRow: .word 0
menuCol: .word 0
menuFlat: .word 0
menuPixel: .word 0

.a16
menu_audio_key:
  cmp #$24
  beq :+
  rts
:
  ldx a:.loword(menuAction)
  cpx #3
  beq @back
  cpx #2
  beq @demo
  lda a:.loword(settings+12),x
  and #255
  sta a:.loword(menuChoice)
  lda #5
  sta a:.loword(menuPage)
  rts
@demo:
  sep #$20
  lda a:.loword(settings+14)
  eor #1
  sta a:.loword(settings+14)
  jsl mix_demo
  rep #$20
  rts
@back:
  jsr .loword(mix_apply)
  stz a:.loword(menuPage)
  stz a:.loword(menuAction)
  rts

menu_level_key:
  cmp #$3e
  beq @up
  cmp #$7e
  beq @up
  cmp #$3d
  beq @down
  cmp #$7d
  beq @down
  cmp #$24
  bne @done
  ldx a:.loword(menuAction)
  lda a:.loword(menuChoice)
  sep #$20
  sta a:.loword(settings+12),x
  rep #$20
  cpx #1
  beq :+
  ; A pending effects selection must not be uploaded by a music edit.
  sep #$20
  lda a:.loword(settings+13)
  pha
  lda a:.loword(mixEffects)
  sta a:.loword(settings+13)
  rep #$20
  jsr .loword(mix_apply)
  sep #$20
  pla
  sta a:.loword(settings+13)
  rep #$20
:
  lda #3
  sta a:.loword(menuPage)
  rts
@up:
  lda a:.loword(menuChoice)
  beq @done
  dec a:.loword(menuChoice)
  rts
@down:
  lda a:.loword(menuChoice)
  cmp #10
  beq @done
  inc a:.loword(menuChoice)
@done:
  rts

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
  adc a:.loword(menuTemp)
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
  asl
  clc
  adc #86
  tax
  lda #3
  jsr .loword(menu_copy)
  plx
  inx
  cpx #11
  bcc @row
  lda a:.loword(menuChoice)
  sta a:.loword(menuTemp)
  asl
  asl
  asl
  sec
  sbc a:.loword(menuTemp)
  asl
  asl
  asl
  clc
  adc #84
  tax
  sep #$20
  lda #MENU_MARK
  sta f:$000800,x
  rep #$20
  jmp .loword(menu_footer)

menu_draw_audio:
  ldy #.loword(menu_audio_text)
  lda #4
  jsr .loword(menu_list)
  ldx #0
@value:
  phx
  lda a:.loword(settings+12),x
  and #255
  asl
  clc
  adc a:.loword(settings+12),x
  and #255
  clc
  adc #.loword(menu_audio_numbers)
  tay
  cpx #0
  bne @second_value
  ldx #84+22
  bra @value_pos
@second_value:
  ldx #140+22
@value_pos:
  lda #3
  jsr .loword(menu_copy)
  plx
  inx
  cpx #2
  bcc @value
  sep #$20
  lda a:.loword(settings+14)
  beq @off
  rep #$20
  ldy #.loword(menu_audio_on)
  bra @demo
@off:
  rep #$20
  ldy #.loword(menu_audio_off)
@demo:
  ldx #196+22
  jsr .loword(menu_put)
  lda a:.loword(menuAction)
  asl
  tax
  lda a:.loword(menu_audio_rows),x
  tax
  sep #$20
  lda #MENU_MARK
  sta f:$000800,x
  rep #$20
  jmp .loword(menu_footer)
menu_audio_rows: .word 84,140,196,252
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
