; The editor and inactive timing tables occupy the checked alignment hole.
; Editable preset records are in the unused tail of the 512-byte settings block.
.a16
.i16
DSET = input_native::settings
DPAGE = input_native::menuPage
DACTION = input_native::menuAction
DCHOICE = input_native::menuChoice
DRECORD = DSET+294
DFLAGS = DSET+292

; Version 2 adds one record in the last 24 bytes before the checksum.
; Upgrade factory records only: every explicitly edited record stays intact.
display_init:
  lda f:DSET+288
  cmp #$4452
  beq @clamp
  cmp #$4451
  beq @upgrade
  lda #0
  sta f:DFLAGS
  sta f:DSET+290
@upgrade:
  lda #$4452
  sta f:DSET+288
  lda f:DSET+290
  and #$00ff
  sta f:DSET+290
  lda #1
  sta a:.loword(display_tmp)
  ldx #0
@record:
  lda a:.loword(display_tmp)
  and f:DSET+290
  beq @factory
  txa
  clc
  adc #24
  tax
  bra @next
@factory:
  ldy #12
@copy:
  lda a:.loword(display_defaults),x
  sta f:DRECORD,x
  inx
  inx
  dey
  bne @copy
@next:
  asl a:.loword(display_tmp)
  cpx #216
  bcc @record
@clamp:
  sep #$20
  lda f:DFLAGS
  cmp #4
  bcc :+
  lda #0
  sta f:DFLAGS
:
  lda f:DFLAGS+1
  cmp #5
  bcc :+
  lda #0
  sta f:DFLAGS+1
:
  rep #$20
  rts

; Return to the immediate parent and abandon an uncommitted numeric edit.
display_back:
  php
  rep #$30
  phb
  phk
  plb
  lda f:DPAGE
  cmp #11
  bne :+
  lda a:.loword(display_parent)
  bra @set
:
  cmp #9
  bcc :+
  lda #8
  bra @set
:
  lda #0
@set:
  sta f:DPAGE
  lda #0
  sta f:DACTION
  plb
  plp
  rtl

; Key actions. Pages: 8 monitor (the one detected at startup, display_apply),
; 9/10 horizontal/vertical, 11 numeric editor, 12 preset selection. ESC is
; handled by display_back.
display_key:
  phb
  phk
  plb
  sta a:.loword(display_keycode)
  jsr .loword(display_init)
  lda f:DPAGE
  cmp #11
  bne :+
  jmp .loword(display_edit_key)
:
  cmp #12
  bne :+
  jmp .loword(display_preset_key)
:
  lda a:.loword(display_keycode)
  cmp #$3e
  beq @up
  cmp #$7e
  beq @up
  cmp #$3d
  beq @down
  cmp #$7d
  beq @down
  cmp #$24
  beq @enter
  cmp #$3c
  beq @enter
  cmp #$7c
  beq @enter
  jmp .loword(display_key_done)
@up:
  lda f:DACTION
  bne :+
  jmp .loword(display_key_done)
:
  dec
  sta f:DACTION
  jmp .loword(display_key_done)
@down:
  lda f:DPAGE
  cmp #8
  beq @limit5
  cmp #9
  beq @limit6
  lda #5
  bra @limit
@limit5:
  lda a:.loword(display_monitor)
  beq :+
  lda #4
  bra @limit
:
  lda #5
  bra @limit
@limit6:
  lda #6
@limit:
  cmp f:DACTION
  bne :+
  jmp .loword(display_key_done)
:
  lda f:DACTION
  inc
  sta f:DACTION
  jmp .loword(display_key_done)
@enter:
  lda f:DPAGE
  cmp #8
  beq @monitor
  jmp .loword(display_field_enter)
@monitor:
  lda a:.loword(display_monitor)
  beq @vga_monitor
  lda f:DACTION
  cmp #3
  bne :+
  jmp .loword(display_reset)
:
  cmp #4
  beq @monitor_back
@vga_monitor:
  lda f:DACTION
  beq display_preset
  cmp #1
  beq @horizontal
  cmp #2
  beq @vertical
  cmp #3
  bne :+
  jmp .loword(display_polarity)
:
  cmp #4
  bne :+
  jmp .loword(display_reset)
:
@monitor_back:
  lda #0
  bra @page
@horizontal:
  lda #9
  bra @page
@vertical:
  lda #10
@page:
  sta f:DPAGE
  lda #0
  sta f:DACTION
display_key_done:
  plb
  rtl
display_preset:
  jsr .loword(display_get_preset)
  sta f:DACTION
  lda #12
  sta f:DPAGE
  jmp .loword(display_key_done)

display_preset_key:
  lda a:.loword(display_keycode)
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
  lda f:DACTION
  jsr .loword(display_set_preset)
  lda #8
  sta f:DPAGE
  lda #0
  sta f:DACTION
  bra @done
@up:
  lda f:DACTION
  beq @done
  dec
  sta f:DACTION
  bra @done
@down:
  lda f:DACTION
  ldx a:.loword(display_monitor)
  cpx #1
  ; Compare against the connector-specific last preset (VGA3, RGB4).
  lda #3
  adc #0
  cmp f:DACTION
  beq @done
  lda f:DACTION
  inc
  sta f:DACTION
@done:
  jmp .loword(display_key_done)
display_polarity:
  ; RGB composite TTL polarity is fixed. VGA H/V invert are two bits and
  ; selected in a dedicated numeric edit rather than an unbounded toggle.
  lda a:.loword(display_monitor)
  bne display_key_done
  lda #22
  sta a:.loword(display_field)
  lda #8
  sta a:.loword(display_parent)
  jmp .loword(display_begin_edit)
display_reset:
  jsr .loword(display_record_offset)
  ldy #0
@reset_loop:
  lda a:.loword(display_defaults),x
  sta f:DRECORD,x
  inx
  inx
  iny
  iny
  cpy #24
  bcc @reset_loop
  jsr .loword(display_dirty_mask)
  eor #$ffff
  and f:DSET+290
  sta f:DSET+290
  jmp .loword(display_key_done)

display_get_preset:
  ldx a:.loword(display_monitor)
  sep #$20
  lda f:DFLAGS,x
  rep #$20
  and #255
  rts
display_set_preset:
  ldx a:.loword(display_monitor)
  sep #$20
  sta f:DFLAGS,x
  rep #$20
  rts
display_record_offset:
  jsr .loword(display_get_preset)
  ldx a:.loword(display_monitor)
  beq :+
  clc
  adc #4
:
  sta a:.loword(display_slot)
  ; slot * 24 = (slot * 3) * 8
  asl
  clc
  adc a:.loword(display_slot)
  asl
  asl
  asl
  tax
  rts

display_dirty_mask:
  jsr .loword(display_record_offset)
  lda a:.loword(display_slot)
  asl
  tax
  lda a:.loword(display_dirty_bits),x
  rts

display_field_enter:
  lda f:DACTION
  pha
  lda f:DPAGE
  tax
  pla
  cpx #9
  bne @vfield
  cmp #6
  beq @field_back
  ; CLOCK, H TOTAL, H BLANK START/END, H SYNC START/END
  cmp #0
  beq @clock
  dec
  asl
  bra @field
@clock:
  lda #20
  bra @field
@vfield:
  cmp #5
  beq @field_back
  asl
  clc
  adc #10
@field:
  sta a:.loword(display_field)
  lda f:DPAGE
  sta a:.loword(display_parent)
  bra display_begin_edit
@field_back:
  lda #8
  sta f:DPAGE
  lda #0
  sta f:DACTION
  jmp .loword(display_key_done)

display_begin_edit:
  lda f:DACTION
  asl
  tax
  lda a:.loword(display_parent)
  cmp #9
  bne :+
  lda a:.loword(display_h_items),x
  bra :++
:
  cmp #10
  bne :+
  lda a:.loword(display_v_items),x
  bra :++
:
  lda #.loword(d_sync)
:
  sta a:.loword(display_heading)
  jsr .loword(display_record_offset)
  txa
  clc
  adc a:.loword(display_field)
  tax
  lda f:DRECORD,x
  sta a:.loword(display_edit)
  lda #0
  sta a:.loword(display_invalid)
  sta f:DACTION
  lda a:.loword(display_field)
  cmp #20
  bne @not_clock
  ldx #0
@find_clock:
  lda a:.loword(display_clock_words),x
  cmp a:.loword(display_edit)
  beq @clock_found
  inx
  inx
  cpx #10
  bcc @find_clock
  ldx #0
@clock_found:
  txa
  lsr
  sta f:DACTION
  bra @open_edit
@not_clock:
  cmp #22
  bne @open_edit
  lda a:.loword(display_edit)
  and #3
  sta f:DACTION
@open_edit:
  lda #11
  sta f:DPAGE
  jmp .loword(display_key_done)

; Numeric editor has -10, -1, +1, +10, APPLY and CANCEL.
display_edit_key:
  lda a:.loword(display_keycode)
  cmp #$3e
  beq @up
  cmp #$7e
  beq @up
  cmp #$3d
  beq @down
  cmp #$7d
  beq @down
  cmp #$24
  beq @enter
  jmp .loword(display_key_done)
@up:
  lda f:DACTION
  beq @done
  dec
  sta f:DACTION
@done:
  jmp .loword(display_key_done)
@down:
  lda f:DACTION
  cmp #5
  beq @done
  inc
  sta f:DACTION
  bra @done
@enter:
  lda a:.loword(display_field)
  cmp #20
  beq @clock_choice
  cmp #22
  beq @sync_choice
  lda f:DACTION
  cmp #4
  beq @apply
  cmp #5
  beq @cancel
  asl
  tax
  lda a:.loword(display_steps),x
  clc
  adc a:.loword(display_edit)
  bpl :+
  lda #0
:
  cmp #1026
  bcc :+
  lda #1025
:
  sta a:.loword(display_edit)
  stz a:.loword(display_invalid)
  bra @done
@clock_choice:
  lda f:DACTION
  cmp #5
  beq @cancel
  asl
  tax
  lda a:.loword(display_clock_words),x
  sta a:.loword(display_edit)
  bra @apply
@sync_choice:
  lda f:DACTION
  cmp #4
  bcs @cancel
  sta a:.loword(display_edit)
  bra @apply
@cancel:
  lda a:.loword(display_parent)
  sta f:DPAGE
  lda #0
  sta f:DACTION
  bra @done
@apply:
  jsr .loword(display_record_offset)
  txa
  clc
  adc a:.loword(display_field)
  tax
  lda f:DRECORD,x
  pha
  lda a:.loword(display_edit)
  sta f:DRECORD,x
  jsr .loword(display_validate)
  bcs @invalid
  pla
  jsr .loword(display_dirty_mask)
  ora f:DSET+290
  sta f:DSET+290
  bra @cancel
@invalid:
  pla
  sta a:.loword(display_old)
  jsr .loword(display_record_offset)
  txa
  clc
  adc a:.loword(display_field)
  tax
  lda a:.loword(display_old)
  sta f:DRECORD,x
  lda #1
  sta a:.loword(display_invalid)
  jmp .loword(@done)

; Strict absolute-coordinate validation before committing any edit.
; Carry set means invalid. Each endpoint remains inside blanking; widths fit
; the modulo end registers. VGA and RGB records are checked independently.
display_validate:
  jsr .loword(display_record_offset)
  lda f:DRECORD,x
  cmp #61
  bcs :+
  jmp .loword(@bad)
:
  cmp #261
  bcc :+
  jmp .loword(@bad)
:
  sta a:.loword(display_bound)
  lda f:DRECORD+2,x
  cmp #256
  bcc :+
  jmp .loword(@bad)
:
  cmp #56
  bcs :+
  jmp .loword(@bad)
:
  cmp f:DRECORD+4,x
  bcc :+
  jmp .loword(@bad)
:
  lda f:DRECORD+4,x
  cmp a:.loword(display_bound)
  beq :+
  bcc :+
  jmp .loword(@bad)
:
  sec
  sbc f:DRECORD+2,x
  cmp #64
  bcc :+
  jmp .loword(@bad)
:
  lda f:DRECORD+6,x
  cmp #256
  bcc :+
  jmp .loword(@bad)
:
  cmp f:DRECORD+2,x
  bcs :+
  jmp .loword(@bad)
:
  cmp f:DRECORD+8,x
  bcc :+
  jmp .loword(@bad)
:
  lda f:DRECORD+8,x
  cmp f:DRECORD+4,x
  beq :+
  bcc :+
  jmp .loword(@bad)
:
  sec
  sbc f:DRECORD+6,x
  cmp #32
  bcc :+
  jmp .loword(@bad)
:
  lda a:.loword(display_monitor)
  beq :+
  lda #256
  bra :++
:
  lda #512
:
  sta a:.loword(display_bound)
  lda f:DRECORD+10,x
  cmp #1026
  bcc :+
  jmp .loword(@bad)
:
  sec
  sbc #2
  cmp a:.loword(display_bound)
  bcs :+
  jmp .loword(@bad)
:
  clc
  adc #2
  sta a:.loword(display_total)
  lda f:DRECORD+12,x
  cmp #1024
  bcc :+
  jmp .loword(@bad)
:
  cmp a:.loword(display_bound)
  bcs :+
  jmp .loword(@bad)
:
  cmp f:DRECORD+14,x
  bcc :+
  jmp .loword(@bad)
:
  lda f:DRECORD+14,x
  cmp a:.loword(display_total)
  beq :+
  bcc :+
  jmp .loword(@bad)
:
  sec
  sbc f:DRECORD+12,x
  cmp #256
  bcc :+
  jmp .loword(@bad)
:
  lda f:DRECORD+16,x
  cmp #1024
  bcc :+
  jmp .loword(@bad)
:
  cmp f:DRECORD+12,x
  bcs :+
  jmp .loword(@bad)
:
  cmp f:DRECORD+18,x
  bcc :+
  jmp .loword(@bad)
:
  lda f:DRECORD+18,x
  cmp f:DRECORD+14,x
  beq :+
  bcc :+
  jmp .loword(@bad)
:
  sec
  sbc f:DRECORD+16,x
  cmp #16
  bcc :+
  jmp .loword(@bad)
:
  lda f:DRECORD+20,x
  cmp #0
  beq @clock_ok
  cmp #1
  beq @clock_ok
  cmp #5
  beq @clock_ok
  cmp #6
  beq @clock_ok
  cmp #12
  beq :+
  jmp .loword(@bad)
:
@clock_ok:
  lda f:DRECORD+22,x
  cmp #4
  bcc :+
  jmp .loword(@bad)
:
  ldy a:.loword(display_monitor)
  beq @good
  cmp #3
  beq :+
  jmp .loword(@bad)
:
@good:
  clc
  rts
@bad:
  sec
  rts

display_draw:
  phb
  phk
  plb
  jsr .loword(display_init)
  lda f:DPAGE
  cmp #8
  beq @monitor
  cmp #9
  beq @horizontal
  cmp #10
  beq @vertical
  cmp #12
  beq @preset_list
  jmp .loword(display_draw_edit)
@preset_list:
  ldy #.loword(d_preset)
  ldx #0
  jsr .loword(display_put)
  ldy #.loword(display_vga_names)
  lda a:.loword(display_monitor)
  beq :+
  ldy #.loword(display_rgb_names)
:
  ldx a:.loword(display_monitor)
  cpx #1
  lda #4
  adc #0
  jmp .loword(@list)
@monitor:
  ldy #.loword(display_title_vga)
  lda a:.loword(display_monitor)
  beq :+
  ldy #.loword(display_title_rgb)
:
  ldx #0
  jsr .loword(display_put)
  ldy #.loword(display_monitor_items)
  lda #6
  ldx a:.loword(display_monitor)
  beq :+
  ldy #.loword(display_monitor_items_rgb)
  lda #5
:
  bra @list
@horizontal:
  ldy #.loword(display_title_h)
  ldx #0
  jsr .loword(display_put)
  ldy #.loword(display_h_items)
  lda #7
  bra @list
@vertical:
  ldy #.loword(display_title_v)
  ldx #0
  jsr .loword(display_put)
  ldy #.loword(display_v_items)
  lda #6
@list:
  sta a:.loword(display_count)
  sty a:.loword(display_item_table)
  stz a:.loword(display_index)
@row:
  lda a:.loword(display_index)
  asl
  clc
  adc a:.loword(display_item_table)
  tay
  lda a:$0000,y
  tay
  lda a:.loword(display_index)
  jsr .loword(display_row)
  inx
  inx
  jsr .loword(display_put)
  lda a:.loword(display_index)
  cmp f:DACTION
  bne :+
  jsr .loword(display_row)
  sep #$20
  lda #input_native::MENU_MARK
  sta f:$000800,x
  rep #$20
:
  lda f:DPAGE
  cmp #8
  bne @advanced
  lda a:.loword(display_index)
  beq :+
  jmp .loword(@next)
:
  jsr .loword(display_get_preset)
  asl
  tax
  lda a:.loword(display_monitor)
  beq :+
  ldy a:.loword(display_rgb_names),x
  bra :++
:
  ldy a:.loword(display_vga_names),x
:
  ; The preset name goes on the blank row under PRESET, indented two columns.
  lda a:.loword(display_index)
  jsr .loword(display_row)
  txa
  clc
  adc #28+2
  tax
  jsr .loword(display_put)
  lda a:.loword(display_monitor)
  beq :+
  jsr .loword(display_get_preset)
  cmp #1
  bne :+
  ldy #.loword(d_tight)
  ldx #532
  jsr .loword(display_put)
:
  jmp .loword(@next)
@advanced:
  cmp #9
  beq @hvalue
  cmp #10
  bne @next
  lda a:.loword(display_index)
  cmp #5
  bcs @next
  asl
  clc
  adc #10
  bra @loadvalue
@hvalue:
  lda a:.loword(display_index)
  cmp #6
  bcs @next
  cmp #0
  beq @clockvalue
  dec
  asl
  bra @loadvalue
@clockvalue:
  lda #20
@loadvalue:
  sta a:.loword(display_field_draw)
  jsr .loword(display_record_offset)
  txa
  clc
  adc a:.loword(display_field_draw)
  tax
  lda f:DRECORD,x
  sta a:.loword(display_value)
  lda a:.loword(display_index)
  jsr .loword(display_row)
  txa
  clc
  adc #19
  tax
  lda a:.loword(display_field_draw)
  cmp #20
  bne @numeric_value
  lda a:.loword(display_value)
  ldy #.loword(d_c25s)
  cmp #0
  beq @put_value
  ldy #.loword(d_c28s)
  cmp #1
  beq @put_value
  ldy #.loword(d_c36s)
  cmp #5
  beq @put_value
  ldy #.loword(d_c40s)
  cmp #6
  beq @put_value
  ldy #.loword(d_c63s)
@put_value:
  jsr .loword(display_put)
  bra @next
@numeric_value:
  lda a:.loword(display_value)
  jsr .loword(display_number)
@next:
  inc a:.loword(display_index)
  lda a:.loword(display_index)
  cmp a:.loword(display_count)
  bcs :+
  jmp .loword(@row)
:
  plb
  rtl

display_draw_edit:
  ldy a:.loword(display_heading)
  ldx #0
  jsr .loword(display_put)
  lda a:.loword(display_field)
  cmp #20
  beq @value_done
  cmp #22
  beq @value_done
  lda a:.loword(display_edit)
  ldx #19
  jsr .loword(display_number)
@value_done:
  lda a:.loword(display_invalid)
  beq :+
  ldy #.loword(display_invalid_text)
  ldx #28
  jsr .loword(display_put)
:
  stz a:.loword(display_index)
@row:
  lda a:.loword(display_index)
  asl
  tay
  lda a:.loword(display_field)
  cmp #20
  beq @clock_labels
  cmp #22
  beq @sync_labels
  lda a:.loword(display_edit_items),y
  bra @have_label
@clock_labels:
  lda a:.loword(display_clock_items),y
  bra @have_label
@sync_labels:
  lda a:.loword(display_sync_items),y
@have_label:
  tay
  lda a:.loword(display_index)
  jsr .loword(display_row)
  inx
  inx
  jsr .loword(display_put)
  lda a:.loword(display_index)
  cmp f:DACTION
  bne :+
  jsr .loword(display_row)
  sep #$20
  lda #input_native::MENU_MARK
  sta f:$000800,x
  rep #$20
:
  inc a:.loword(display_index)
  lda a:.loword(display_index)
  cmp #6
  bcc @row
  plb
  rtl

display_row:
  sta a:.loword(display_tmp)
  asl
  asl
  asl
  sec
  sbc a:.loword(display_tmp)
  asl
  asl
  asl
  clc
  adc #84
  tax
  rts
display_put:
  sep #$20
@char:
  lda a:$0000,y
  beq @done
  sta f:$000800,x
  iny
  inx
  bra @char
@done:
  rep #$20
  rts
; Four decimal digits, zero padded. Inputs are bounded before acceptance.
display_number:
  sta a:.loword(display_value)
  ldy #0
@digit:
  lda #0
  sta a:.loword(display_digit)
  lda a:.loword(display_value)
@sub:
  cmp a:.loword(display_divisors),y
  bcc @emit
  sec
  sbc a:.loword(display_divisors),y
  inc a:.loword(display_digit)
  bra @sub
@emit:
  sta a:.loword(display_value)
  lda a:.loword(display_digit)
  clc
  adc #'0'
  sep #$20
  sta f:$000800,x
  rep #$20
  inx
  iny
  iny
  cpy #8
  bcc @digit
  rts

; Apply one validated monitor record only to suspended card SRAM.
; Invalid persisted records fall back to the selected monitor's default.
display_apply:
  php
  rep #$30
  phx
  phy
  phb
  phk
  plb
  jsr .loword(display_init)
  stz a:.loword(display_monitor)
  sep #$20
  lda f:DISPLAY_MODE+1
  cmp #$a9
  rep #$20
  bne :+
  lda #1
  sta a:.loword(display_monitor)
:
  lda a:.loword(display_monitor)
  beq :+
  ldy #DISPLAY_N
  bra :++
:
  ldy #0
:
  ldx #3
  sep #$20
@copy:
  lda a:.loword(display_profiles),y
  sta f:DISPLAY_MODE,x
  iny
  inx
  inx
  inx
  inx
  cpx #(DISPLAY_N*4+3)
  bne @copy
  rep #$20
  lda a:.loword(display_monitor)
  asl
  asl
  tax
  lda a:.loword(display_thresholds),x
  sta f:DISPLAY_FIRST
  lda a:.loword(display_thresholds+2),x
  sta f:DISPLAY_HALF
  jsr .loword(display_get_preset)
  bne @selected_record
  jsr .loword(display_dirty_mask)
  and f:DSET+290
  bne @selected_record
  jmp .loword(@default_done)
@selected_record:
  jsr .loword(display_validate)
  bcc :+
  jmp .loword(@default_done)
:
  jsr .loword(display_record_offset)
  ldy #0
@custom_loop:
  lda f:DRECORD,x
  sta a:.loword(display_work),y
  inx
  inx
  iny
  iny
  cpy #24
  bcc @custom_loop
@work_ready:
  ldx #0
  ; H total, blank start/end, sync start/end.
  lda a:.loword(display_work),x
  sec
  sbc #5
  sep #$20
  sta f:DISPLAY_MODE+DISPLAY_CRTC_00
  rep #$20
  lda a:.loword(display_work)+2,x
  sep #$20
  sta f:DISPLAY_MODE+DISPLAY_CRTC_02
  rep #$20
  lda a:.loword(display_work)+4,x
  and #31
  ora #$80
  sep #$20
  sta f:DISPLAY_MODE+DISPLAY_CRTC_03
  rep #$20
  lda a:.loword(display_work)+6,x
  sep #$20
  sta f:DISPLAY_MODE+DISPLAY_CRTC_04
  rep #$20
  lda a:.loword(display_work)+4,x
  and #32
  asl
  asl
  sta a:.loword(display_tmp)
  lda a:.loword(display_work)+8,x
  and #31
  ora a:.loword(display_tmp)
  sep #$20
  sta f:DISPLAY_MODE+DISPLAY_CRTC_05
  rep #$20
  ; Vertical overflow: preserve the fixed visible-height bits.
  lda a:.loword(display_work)+10,x
  sec
  sbc #2
  sta a:.loword(display_total)
  sep #$20
  sta f:DISPLAY_MODE+DISPLAY_CRTC_06
  lda f:DISPLAY_MODE+DISPLAY_CRTC_07
  and #$52
  sta a:.loword(display_bits)
  rep #$20
  lda a:.loword(display_total)
  xba
  and #3
  sta a:.loword(display_tmp)
  and #1
  ora a:.loword(display_bits)
  sta a:.loword(display_bits)
  lda a:.loword(display_tmp)
  and #2
  asl
  asl
  asl
  asl
  ora a:.loword(display_bits)
  sta a:.loword(display_bits)
  lda a:.loword(display_work)+16,x
  xba
  and #3
  sta a:.loword(display_tmp)
  and #1
  asl
  asl
  ora a:.loword(display_bits)
  sta a:.loword(display_bits)
  lda a:.loword(display_tmp)
  and #2
  asl
  asl
  asl
  asl
  asl
  asl
  ora a:.loword(display_bits)
  sta a:.loword(display_bits)
  lda a:.loword(display_work)+12,x
  xba
  and #1
  asl
  asl
  asl
  ora a:.loword(display_bits)
  sep #$20
  sta f:DISPLAY_MODE+DISPLAY_CRTC_07
  lda f:DISPLAY_MODE+DISPLAY_CRTC_09
  and #$df
  sta a:.loword(display_bits)
  rep #$20
  lda a:.loword(display_work)+12,x
  xba
  and #2
  asl
  asl
  asl
  asl
  ora a:.loword(display_bits)
  sep #$20
  sta f:DISPLAY_MODE+DISPLAY_CRTC_09
  rep #$20
  lda a:.loword(display_work)+16,x
  sep #$20
  sta f:DISPLAY_MODE+DISPLAY_CRTC_10
  rep #$20
  lda a:.loword(display_work)+18,x
  and #15
  ora #$30
  sep #$20
  sta f:DISPLAY_MODE+DISPLAY_CRTC_11
  rep #$20
  lda a:.loword(display_work)+12,x
  sep #$20
  sta f:DISPLAY_MODE+DISPLAY_CRTC_15
  rep #$20
  lda a:.loword(display_work)+14,x
  dec
  sep #$20
  sta f:DISPLAY_MODE+DISPLAY_CRTC_16
  rep #$20
  lda a:.loword(display_work)+20,x
  sep #$20
  sta f:DISPLAY_MODE+DISPLAY_CLOCK
  rep #$20
  and #3
  asl
  asl
  ora #$23
  sta a:.loword(display_bits)
  lda a:.loword(display_work)+22,x
  and #3
  asl
  asl
  asl
  asl
  asl
  asl
  ora a:.loword(display_bits)
  sep #$20
  sta f:DISPLAY_MODE+DISPLAY_MISC
  rep #$20
  ; Custom modes submit completed pictures immediately and still latch at
  ; retrace, so no division or per-picture host work is introduced.
  lda #$ffff
  sta f:DISPLAY_FIRST
@default_done:
@done:
  jsl game_clock_display_rate
  plb
  ply
  plx
  plp
  rtl

display_boot_apply:
  php
  rep #$30
  phb
  phk
  plb
  jsr .loword(display_init)
  ; Apply even factory timing at boot so its game deadline uses that rate.
  jsl mirror_open
  jsl display_apply
  jsl mirror_close
  rep #$20
  lda f:GAME_CLOCK
  sta f:GAME_CLOCK_ORIGIN
  jsl game_clock_fraction_step
  sta f:GAME_DUE
@done:
  plb
  plp
  rtl

display_title_vga: .asciiz "VGA"
display_title_rgb: .asciiz "APPLECOLOR RGB"
display_title_h: .asciiz "H TIMING (8 DOTS)"
display_title_v: .asciiz "V TIMING (LINES)"
display_title_edit: .asciiz "VALUE"
display_invalid_text: .asciiz "INVALID TIMING"
display_vga_names: .word .loword(d_arcade),.loword(d_near),.loword(d_standard),.loword(d_custom)
display_rgb_names: .word .loword(d_safe),.loword(d_rgbnear),.loword(d_50),.loword(d_custom),.loword(d_nominal)
; Preset names: at most 26 characters (the list and the row under PRESET).
d_nominal: .asciiz "IIGS LINE RATE 56.36 HZ"
d_rgbnear: .asciiz "NEAR ARCADE 59.59 HZ"
d_tight: .asciiz "SHORT RETRACE: MAY NOT SYNC"  ; 27 characters, row 19
d_safe: .asciiz "BALANCED 58.74 HZ"
d_arcade: .asciiz "ARCADE 59.64 HZ"
d_near: .asciiz "800X600 SYNC, 59.65 HZ"
d_standard: .asciiz "800X600 VESA, 60.32 HZ"
d_50: .asciiz "50 HZ FALLBACK 49.92 HZ"
d_custom: .asciiz "CUSTOM TIMING"
display_monitor_items: .word .loword(d_preset),.loword(d_horizontal),.loword(d_vertical),.loword(d_sync),.loword(d_reset),.loword(d_back)
display_monitor_items_rgb: .word .loword(d_preset),.loword(d_horizontal),.loword(d_vertical),.loword(d_reset),.loword(d_back)
display_h_items: .word .loword(d_clock),.loword(d_total),.loword(d_blank_start),.loword(d_blank_end),.loword(d_sync_start),.loword(d_sync_end),.loword(d_back)
display_v_items: .word .loword(d_total),.loword(d_blank_start),.loword(d_blank_end),.loword(d_sync_start),.loword(d_sync_end),.loword(d_back)
display_clock_items: .word .loword(d_c25),.loword(d_c28),.loword(d_c36),.loword(d_c40),.loword(d_c63),.loword(d_cancel)
display_clock_words: .word 0,1,5,6,12
display_sync_items: .word .loword(d_pp),.loword(d_np),.loword(d_pn),.loword(d_nn),.loword(d_cancel),.loword(d_cancel)
d_c25s: .asciiz "25.175"
d_c28s: .asciiz "28.322"
d_c36s: .asciiz "36.000"
d_c40s: .asciiz "40.000"
d_c63s: .asciiz "63.000"
d_c25: .asciiz "25.175 MHZ"
d_c28: .asciiz "28.322 MHZ"
d_c36: .asciiz "36.000 MHZ"
d_c40: .asciiz "40.000 MHZ"
d_c63: .asciiz "63.000 MHZ"
d_pp: .asciiz "H+ V+"
d_np: .asciiz "H- V+"
d_pn: .asciiz "H+ V-"
d_nn: .asciiz "H- V-"
display_edit_items: .word .loword(d_minus10),.loword(d_minus1),.loword(d_plus1),.loword(d_plus10),.loword(d_apply),.loword(d_cancel)
d_back: .asciiz "BACK"
d_preset: .asciiz "PRESET"
d_horizontal: .asciiz "HORIZONTAL"
d_vertical: .asciiz "VERTICAL"
d_sync: .asciiz "VGA SYNC"
d_reset: .asciiz "RESTORE DEFAULT"
d_clock: .asciiz "CLOCK MHZ"
d_total: .asciiz "TOTAL"
d_blank_start: .asciiz "BLANK START"
d_blank_end: .asciiz "BLANK END"
d_sync_start: .asciiz "SYNC START"
d_sync_end: .asciiz "SYNC END"
d_minus10: .asciiz "-10"
d_minus1: .asciiz "-1"
d_plus1: .asciiz "+1"
d_plus10: .asciiz "+10"
d_apply: .asciiz "APPLY"
d_cancel: .asciiz "CANCEL"
display_dirty_bits: .word 1,2,4,8,16,32,64,128,256
display_steps: .word $fff6,$ffff,1,10
display_divisors: .word 1000,100,10,1
display_work: .res 24
display_heading: .word 0
display_slot: .word 0
display_keycode: .word 0
display_monitor: .word 0
display_parent: .word 0
display_field: .word 0
display_field_draw: .word 0
display_edit: .word 0
display_old: .word 0
display_invalid: .word 0
display_index: .word 0
display_count: .word 0
display_item_table: .word 0
display_tmp: .word 0
display_bound: .word 0
display_total: .word 0
display_bits: .word 0
display_value: .word 0
display_digit: .word 0
.include "display-control.inc"
