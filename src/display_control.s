; The display pages of the menu: the preset and the timing of the monitor
; that the start found (VGA or AppleColor RGB). The timing records
; (DISPLAY_RECORD_SIZE, DR_* fields) are in the settings block: VGA_PRESETS
; for VGA, then RGB_PRESETS for RGB. display_apply writes a record into the
; mode table of the card (the VGA CRTC registers). The editor and the timing
; tables of the other monitor are in a checked alignment hole of the code.
.a16
.i16
DSET = input_native::settings
DPAGE = input_native::menuPage
DACTION = input_native::menuAction
DRECORD = DSET+SET_DISPLAY_RECORDS
DFLAGS = DSET+SET_DISPLAY_PRESET    ; byte 0: the VGA preset; byte 1: the RGB preset
MP_MONITOR = input_native::MP_MONITOR
MP_HORIZONTAL = input_native::MP_HORIZONTAL
MP_VERTICAL = input_native::MP_VERTICAL
MP_EDIT = input_native::MP_EDIT
MP_PRESET = input_native::MP_PRESET
MENU_LIST = input_native::MENU_LIST  ; the row of the first choice
MENU_MARK = input_native::MENU_MARK
MONITOR_VGA = 0              ; display_monitor
MONITOR_RGB = 1
VGA_PRESETS = 4              ; the presets (and the records) of each monitor
RGB_PRESETS = 5
V1_RECORDS = 8               ; DISPLAY_MARK_V1: the records of version 1
; The choices of the pages (DACTION).
MON_HORIZONTAL = 1           ; MP_MONITOR: 0 the preset
MON_VERTICAL = 2
MON_SYNC = 3                 ; VGA only
MON_VGA_RESET = 4            ; MON_SYNC, MON_VGA_RESET, MON_VGA_BACK on VGA;
MON_VGA_BACK = 5             ; on RGB the reset and back are one choice earlier
MON_RGB_RESET = 3
MON_RGB_BACK = 4
H_BACK = 6                   ; MP_HORIZONTAL: 0 the clock, 1-5 the fields
V_BACK = 5                   ; MP_VERTICAL: 0-4 the fields
EDIT_APPLY = 4               ; MP_EDIT: 0-3 the steps (display_steps)
EDIT_CANCEL = 5              ; also the cancel of the clock choices (0-4)
EDIT_CHOICES = 6
EDIT_MAX = VTOTAL_END-1      ; MP_EDIT: the greatest value
; The limits of a record (display_validate), from the CRTC registers.
HTOTAL_MIN = 61              ; characters
HTOTAL_END = 261
HBLANK_MIN = 56
CHAR_END = 256               ; a character register has 8 bits
HBLANK_WIDTH_END = 64        ; the end registers keep 6 bits (blanking)
HSYNC_WIDTH_END = 32         ; and 5 bits (sync)
VTOTAL_END = 1026            ; lines (CRTC 6 and its overflow: the total - 2)
LINE_END = 1024              ; a line register has 10 bits
VBLANK_WIDTH_END = 256       ; the end registers keep 8 bits (blanking)
VSYNC_WIDTH_END = 16         ; and 4 bits (sync)
VGA_LINES = 512              ; the lines of the picture: blanking starts after them
RGB_LINES = 256
POLARITIES = 4               ; DR_POLARITY: bit 0 H negative, bit 1 V negative
RGB_POLARITY = 3             ; the RGB TTL sync: both negative, fixed
; The CRTC register bits that display_apply writes.
HTOTAL_BIAS = 5              ; CRTC 0: the total - 5
VTOTAL_BIAS = 2              ; CRTC 6: the total - 2
END_LOW_BITS = $1f           ; CRTC 3 and 5: the end bits 0-4
CRTC3_FIXED = $80            ; CRTC 3: bit 7 set
OVERFLOW_KEEP = $52          ; CRTC 7: the fixed visible height and line compare bits
MAX_SCAN_KEEP = $df          ; CRTC 9: all but bit 5 (the blanking start bit 9)
VSYNC_END_BITS = $0f         ; CRTC 11: the end bits
VSYNC_IRQ_OFF = $30          ; CRTC 11: the vertical interrupt cleared and off
MISC_FIXED = $23             ; MISC: colour I/O, RAM on, the high page
MODE_ENTRY = 4               ; DISPLAY_MODE: an entry of the card's mode table;
MODE_DATA = 3                ; its data byte
NO_THRESHOLD = $ffff         ; DISPLAY_FIRST: a custom record has no threshold
VALUE_COLUMN = 19            ; the values on the pages
DIGITS = 4                   ; display_number

; display_init: the timing records as the current version: a version 1
; block gets the new record, other records keep their edits; no mark: all
; factory. Then the presets inside their counts. JSR; A16.
display_init:
  lda f:DSET+SET_DISPLAY_MARK
  cmp #DISPLAY_MARK
  beq @clamp
  cmp #DISPLAY_MARK_V1
  beq @upgrade
  lda #0
  sta f:DFLAGS
  sta f:DSET+SET_DISPLAY_EDITED
@upgrade:
  lda #DISPLAY_MARK
  sta f:DSET+SET_DISPLAY_MARK
  lda f:DSET+SET_DISPLAY_EDITED
  and #(1<<V1_RECORDS)-1        ; the edits of the version 1 records
  sta f:DSET+SET_DISPLAY_EDITED
  lda #1
  sta a:.loword(display_tmp)
  ldx #0
@record:
  lda a:.loword(display_tmp)
  and f:DSET+SET_DISPLAY_EDITED
  beq @factory
  txa
  clc
  adc #DISPLAY_RECORD_SIZE
  tax
  bra @next
@factory:
  ldy #DISPLAY_RECORD_SIZE/2
@copy:
  lda a:.loword(display_defaults),x
  sta f:DRECORD,x
  inx
  inx
  dey
  bne @copy
@next:
  asl a:.loword(display_tmp)
  cpx #DISPLAY_RECORDS*DISPLAY_RECORD_SIZE
  bcc @record
@clamp:
  a8
  lda f:DFLAGS
  cmp #VGA_PRESETS
  bcc :+
  lda #0
  sta f:DFLAGS
:
  lda f:DFLAGS+1
  cmp #RGB_PRESETS
  bcc :+
  lda #0
  sta f:DFLAGS+1
:
  a16
  rts

; display_back: ESC on a display page: the page before (an edit is not
; kept); from MP_MONITOR the main page. JSL.
display_back:
  php
  ax16
  phb
  phk
  plb
  lda f:DPAGE
  cmp #MP_EDIT
  bne :+
  lda a:.loword(display_parent)
  bra @set
:
  cmp #MP_HORIZONTAL
  bcc :+
  lda #MP_MONITOR
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

; display_key: the key A (an ADB code) on a display page: UP and DOWN move
; the choice; RETURN (and RIGHT) takes it. ESC is display_back. JSL.
display_key:
  phb
  phk
  plb
  sta a:.loword(display_keycode)
  jsr .loword(display_init)
  lda f:DPAGE
  cmp #MP_EDIT
  bne :+
  jmp .loword(display_edit_key)
:
  cmp #MP_PRESET
  bne :+
  jmp .loword(display_preset_key)
:
  lda a:.loword(display_keycode)
  cmp #KEY_UP
  beq @up
  cmp #KEY_DOWN
  beq @down
  cmp #KEY_RETURN
  beq @enter
  cmp #KEY_RIGHT
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
  cmp #MP_MONITOR
  beq @limit5
  cmp #MP_HORIZONTAL
  beq @limit6
  lda #V_BACK
  bra @limit
@limit5:
  lda a:.loword(display_monitor)
  beq :+
  lda #MON_RGB_BACK
  bra @limit
:
  lda #MON_VGA_BACK
  bra @limit
@limit6:
  lda #H_BACK
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
  cmp #MP_MONITOR
  beq @monitor
  jmp .loword(display_field_enter)
@monitor:
  lda a:.loword(display_monitor)
  beq @vga_monitor
  lda f:DACTION
  cmp #MON_RGB_RESET
  bne :+
  jmp .loword(display_reset)
:
  cmp #MON_RGB_BACK
  beq @monitor_back
@vga_monitor:
  lda f:DACTION
  beq display_preset
  cmp #MON_HORIZONTAL
  beq @horizontal
  cmp #MON_VERTICAL
  beq @vertical
  cmp #MON_SYNC
  bne :+
  jmp .loword(display_polarity)
:
  cmp #MON_VGA_RESET
  bne :+
  jmp .loword(display_reset)
:
@monitor_back:
  lda #0                        ; MP_MAIN
  bra @page
@horizontal:
  lda #MP_HORIZONTAL
  bra @page
@vertical:
  lda #MP_VERTICAL
@page:
  sta f:DPAGE
  lda #0
  sta f:DACTION
display_key_done:
  plb
  rtl
; display_preset: the preset list, at the current preset.
display_preset:
  jsr .loword(display_get_preset)
  sta f:DACTION
  lda #MP_PRESET
  sta f:DPAGE
  jmp .loword(display_key_done)

; display_preset_key: MP_PRESET: RETURN selects the preset.
display_preset_key:
  lda a:.loword(display_keycode)
  cmp #KEY_UP
  beq @up
  cmp #KEY_DOWN
  beq @down
  cmp #KEY_RETURN
  bne @done
  lda f:DACTION
  jsr .loword(display_set_preset)
  lda #MP_MONITOR
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
  cpx #MONITOR_RGB
  ; The last preset of the monitor (carry 1 for RGB).
  lda #VGA_PRESETS-1
  adc #0
  cmp f:DACTION
  beq @done
  lda f:DACTION
  inc
  sta f:DACTION
@done:
  jmp .loword(display_key_done)
; display_polarity: MON_SYNC: the VGA sync polarities, as a choice of the
; four (the RGB TTL polarity is fixed).
display_polarity:
  lda a:.loword(display_monitor)
  bne display_key_done
  lda #DR_POLARITY
  sta a:.loword(display_field)
  lda #MP_MONITOR
  sta a:.loword(display_parent)
  jmp .loword(display_begin_edit)
; display_reset: the record of the preset as in the factory, not edited.
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
  cpy #DISPLAY_RECORD_SIZE
  bcc @reset_loop
  jsr .loword(display_dirty_mask)
  eor #$ffff
  and f:DSET+SET_DISPLAY_EDITED
  sta f:DSET+SET_DISPLAY_EDITED
  jmp .loword(display_key_done)

; display_get_preset: A = the preset of the monitor. display_set_preset:
; the preset of the monitor = A. JSR; A16.
display_get_preset:
  ldx a:.loword(display_monitor)
  a8
  lda f:DFLAGS,x
  a16
  and #255
  rts
display_set_preset:
  ldx a:.loword(display_monitor)
  a8
  sta f:DFLAGS,x
  a16
  rts
; display_record_offset: display_slot = the record of the preset (RGB after
; the VGA_PRESETS records); X = its offset. JSR; A16.
display_record_offset:
  jsr .loword(display_get_preset)
  ldx a:.loword(display_monitor)
  beq :+
  clc
  adc #VGA_PRESETS
:
  sta a:.loword(display_slot)
  ; slot * DISPLAY_RECORD_SIZE = (slot * 3) * 8
  asl
  clc
  adc a:.loword(display_slot)
  asl
  asl
  asl
  tax
  rts

; display_dirty_mask: A = the SET_DISPLAY_EDITED bit of the record of the
; preset. JSR; A16.
display_dirty_mask:
  jsr .loword(display_record_offset)
  lda a:.loword(display_slot)
  asl
  tax
  lda a:.loword(display_dirty_bits),x
  rts

; display_field_enter: RETURN on MP_HORIZONTAL or MP_VERTICAL: edit the
; field of the choice (the clock, then the H fields from DR_HTOTAL; the V
; fields from DR_VTOTAL), or back.
display_field_enter:
  lda f:DACTION
  pha
  lda f:DPAGE
  tax
  pla
  cpx #MP_HORIZONTAL
  bne @vfield
  cmp #H_BACK
  beq @field_back
  cmp #0
  beq @clock
  dec
  asl
  bra @field
@clock:
  lda #DR_CLOCK
  bra @field
@vfield:
  cmp #V_BACK
  beq @field_back
  asl
  clc
  adc #DR_VTOTAL
@field:
  sta a:.loword(display_field)
  lda f:DPAGE
  sta a:.loword(display_parent)
  bra display_begin_edit
@field_back:
  lda #MP_MONITOR
  sta f:DPAGE
  lda #0
  sta f:DACTION
  jmp .loword(display_key_done)
.assert DR_HTOTAL = 0, error

; display_begin_edit: open MP_EDIT for display_field: its name as the
; heading, its value; the clock and the polarity start at their choice.
display_begin_edit:
  lda f:DACTION
  asl
  tax
  lda a:.loword(display_parent)
  cmp #MP_HORIZONTAL
  bne :+
  lda a:.loword(display_h_items),x
  bra :++
:
  cmp #MP_VERTICAL
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
  cmp #DR_CLOCK
  bne @not_clock
  ldx #0
@find_clock:
  lda a:.loword(display_clock_words),x
  cmp a:.loword(display_edit)
  beq @clock_found
  inx
  inx
  cpx #2*DISPLAY_CLOCKS
  bcc @find_clock
  ldx #0
@clock_found:
  txa
  lsr
  sta f:DACTION
  bra @open_edit
@not_clock:
  cmp #DR_POLARITY
  bne @open_edit
  lda a:.loword(display_edit)
  and #POLARITIES-1
  sta f:DACTION
@open_edit:
  lda #MP_EDIT
  sta f:DPAGE
  jmp .loword(display_key_done)

; display_edit_key: MP_EDIT: -10, -1, +1, +10 (inside 0..EDIT_MAX), APPLY
; (display_validate: a bad record keeps the old value and shows INVALID
; TIMING) and CANCEL; the clock and the polarity are choices.
display_edit_key:
  lda a:.loword(display_keycode)
  cmp #KEY_UP
  beq @up
  cmp #KEY_DOWN
  beq @down
  cmp #KEY_RETURN
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
  cmp #EDIT_CHOICES-1
  beq @done
  inc
  sta f:DACTION
  bra @done
@enter:
  lda a:.loword(display_field)
  cmp #DR_CLOCK
  beq @clock_choice
  cmp #DR_POLARITY
  beq @sync_choice
  lda f:DACTION
  cmp #EDIT_APPLY
  beq @apply
  cmp #EDIT_CANCEL
  beq @cancel
  asl
  tax
  lda a:.loword(display_steps),x
  clc
  adc a:.loword(display_edit)
  bpl :+
  lda #0
:
  cmp #EDIT_MAX+1
  bcc :+
  lda #EDIT_MAX
:
  sta a:.loword(display_edit)
  stz a:.loword(display_invalid)
  bra @done
@clock_choice:
  lda f:DACTION
  cmp #EDIT_CANCEL
  beq @cancel
  asl
  tax
  lda a:.loword(display_clock_words),x
  sta a:.loword(display_edit)
  bra @apply
@sync_choice:
  lda f:DACTION
  cmp #POLARITIES
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
  ora f:DSET+SET_DISPLAY_EDITED
  sta f:DSET+SET_DISPLAY_EDITED
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

; display_validate: check the record of the preset before an edit stays.
; Carry 1: bad. Each sync is inside its blanking; each width fits its end
; register (CHAR_END and LINE_END registers, the widths below the
; *_WIDTH_END); the picture has VGA_LINES or RGB_LINES lines; the clock is
; one of display_clock_words; the RGB polarity is RGB_POLARITY. JSR; A16.
display_validate:
  jsr .loword(display_record_offset)
  lda f:DRECORD+DR_HTOTAL,x
  cmp #HTOTAL_MIN
  bcs :+
  jmp .loword(@bad)
:
  cmp #HTOTAL_END
  bcc :+
  jmp .loword(@bad)
:
  sta a:.loword(display_bound)
  lda f:DRECORD+DR_HBLANK_START,x
  cmp #CHAR_END
  bcc :+
  jmp .loword(@bad)
:
  cmp #HBLANK_MIN
  bcs :+
  jmp .loword(@bad)
:
  cmp f:DRECORD+DR_HBLANK_END,x
  bcc :+
  jmp .loword(@bad)
:
  lda f:DRECORD+DR_HBLANK_END,x
  cmp a:.loword(display_bound)
  beq :+
  bcc :+
  jmp .loword(@bad)
:
  sec
  sbc f:DRECORD+DR_HBLANK_START,x
  cmp #HBLANK_WIDTH_END
  bcc :+
  jmp .loword(@bad)
:
  lda f:DRECORD+DR_HSYNC_START,x
  cmp #CHAR_END
  bcc :+
  jmp .loword(@bad)
:
  cmp f:DRECORD+DR_HBLANK_START,x
  bcs :+
  jmp .loword(@bad)
:
  cmp f:DRECORD+DR_HSYNC_END,x
  bcc :+
  jmp .loword(@bad)
:
  lda f:DRECORD+DR_HSYNC_END,x
  cmp f:DRECORD+DR_HBLANK_END,x
  beq :+
  bcc :+
  jmp .loword(@bad)
:
  sec
  sbc f:DRECORD+DR_HSYNC_START,x
  cmp #HSYNC_WIDTH_END
  bcc :+
  jmp .loword(@bad)
:
  lda a:.loword(display_monitor)
  beq :+
  lda #RGB_LINES
  bra :++
:
  lda #VGA_LINES
:
  sta a:.loword(display_bound)
  lda f:DRECORD+DR_VTOTAL,x
  cmp #VTOTAL_END
  bcc :+
  jmp .loword(@bad)
:
  sec
  sbc #VTOTAL_BIAS
  cmp a:.loword(display_bound)
  bcs :+
  jmp .loword(@bad)
:
  clc
  adc #VTOTAL_BIAS
  sta a:.loword(display_total)
  lda f:DRECORD+DR_VBLANK_START,x
  cmp #LINE_END
  bcc :+
  jmp .loword(@bad)
:
  cmp a:.loword(display_bound)
  bcs :+
  jmp .loword(@bad)
:
  cmp f:DRECORD+DR_VBLANK_END,x
  bcc :+
  jmp .loword(@bad)
:
  lda f:DRECORD+DR_VBLANK_END,x
  cmp a:.loword(display_total)
  beq :+
  bcc :+
  jmp .loword(@bad)
:
  sec
  sbc f:DRECORD+DR_VBLANK_START,x
  cmp #VBLANK_WIDTH_END
  bcc :+
  jmp .loword(@bad)
:
  lda f:DRECORD+DR_VSYNC_START,x
  cmp #LINE_END
  bcc :+
  jmp .loword(@bad)
:
  cmp f:DRECORD+DR_VBLANK_START,x
  bcs :+
  jmp .loword(@bad)
:
  cmp f:DRECORD+DR_VSYNC_END,x
  bcc :+
  jmp .loword(@bad)
:
  lda f:DRECORD+DR_VSYNC_END,x
  cmp f:DRECORD+DR_VBLANK_END,x
  beq :+
  bcc :+
  jmp .loword(@bad)
:
  sec
  sbc f:DRECORD+DR_VSYNC_START,x
  cmp #VSYNC_WIDTH_END
  bcc :+
  jmp .loword(@bad)
:
  lda f:DRECORD+DR_CLOCK,x
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
  lda f:DRECORD+DR_POLARITY,x
  cmp #POLARITIES
  bcc :+
  jmp .loword(@bad)
:
  ldy a:.loword(display_monitor)
  beq @good
  cmp #RGB_POLARITY
  beq :+
  jmp .loword(@bad)
:
@good:
  clc
  rts
@bad:
  sec
  rts

; display_draw: draw the display page in MENU_TEXT: the title, the choices
; with the marker, and the values (the preset name, the field values, the
; clock). MP_EDIT: display_draw_edit. JSL.
display_draw:
  phb
  phk
  plb
  jsr .loword(display_init)
  lda f:DPAGE
  cmp #MP_MONITOR
  beq @monitor
  cmp #MP_HORIZONTAL
  beq @horizontal
  cmp #MP_VERTICAL
  beq @vertical
  cmp #MP_PRESET
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
  cpx #MONITOR_RGB
  lda #VGA_PRESETS              ; RGB: carry 1, RGB_PRESETS
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
  lda #MON_VGA_BACK+1
  ldx a:.loword(display_monitor)
  beq :+
  ldy #.loword(display_monitor_items_rgb)
  lda #MON_RGB_BACK+1
:
  bra @list
@horizontal:
  ldy #.loword(display_title_h)
  ldx #0
  jsr .loword(display_put)
  ldy #.loword(display_h_items)
  lda #H_BACK+1
  bra @list
@vertical:
  ldy #.loword(display_title_v)
  ldx #0
  jsr .loword(display_put)
  ldy #.loword(display_v_items)
  lda #V_BACK+1
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
  lda a:0,y
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
  a8
  lda #MENU_MARK
  sta f:MENU_TEXT,x
  a16
:
  lda f:DPAGE
  cmp #MP_MONITOR
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
  adc #MENU_COLUMNS+2
  tax
  jsr .loword(display_put)
  lda a:.loword(display_monitor)
  beq :+
  jsr .loword(display_get_preset)
  cmp #1                        ; the RGB preset "NEAR ARCADE"
  bne :+
  ldy #.loword(d_tight)
  ldx #19*MENU_COLUMNS          ; row 19
  jsr .loword(display_put)
:
  jmp .loword(@next)
@advanced:
  cmp #MP_HORIZONTAL
  beq @hvalue
  cmp #MP_VERTICAL
  bne @next
  lda a:.loword(display_index)
  cmp #V_BACK
  bcs @next
  asl
  clc
  adc #DR_VTOTAL
  bra @loadvalue
@hvalue:
  lda a:.loword(display_index)
  cmp #H_BACK
  bcs @next
  cmp #0
  beq @clockvalue
  dec
  asl
  bra @loadvalue
@clockvalue:
  lda #DR_CLOCK
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
  adc #VALUE_COLUMN
  tax
  lda a:.loword(display_field_draw)
  cmp #DR_CLOCK
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

; display_draw_edit: MP_EDIT: the heading and the value (not for a choice),
; INVALID TIMING after a bad APPLY, and the EDIT_CHOICES choices. JSL tail.
display_draw_edit:
  ldy a:.loword(display_heading)
  ldx #0
  jsr .loword(display_put)
  lda a:.loword(display_field)
  cmp #DR_CLOCK
  beq @value_done
  cmp #DR_POLARITY
  beq @value_done
  lda a:.loword(display_edit)
  ldx #VALUE_COLUMN
  jsr .loword(display_number)
@value_done:
  lda a:.loword(display_invalid)
  beq :+
  ldy #.loword(display_invalid_text)
  ldx #MENU_COLUMNS             ; row 1
  jsr .loword(display_put)
:
  stz a:.loword(display_index)
@row:
  lda a:.loword(display_index)
  asl
  tay
  lda a:.loword(display_field)
  cmp #DR_CLOCK
  beq @clock_labels
  cmp #DR_POLARITY
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
  a8
  lda #MENU_MARK
  sta f:MENU_TEXT,x
  a16
:
  inc a:.loword(display_index)
  lda a:.loword(display_index)
  cmp #EDIT_CHOICES
  bcc @row
  plb
  rtl

; display_row: X = the MENU_TEXT offset of the row of the choice A. JSR.
display_row:
  sta a:.loword(display_tmp)
  asl
  asl
  asl
  sec
  sbc a:.loword(display_tmp)
  asl
  asl
  asl                           ; times MENU_PITCH
  clc
  adc #MENU_LIST
  tax
  rts
; display_put: the zero-ended text at Y to MENU_TEXT+X. JSR.
display_put:
  a8
@char:
  lda a:0,y
  beq @done
  sta f:MENU_TEXT,x
  iny
  inx
  bra @char
@done:
  a16
  rts
; display_number: A as DIGITS decimal digits with leading zeros at
; MENU_TEXT+X (the values are below 10000). JSR.
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
  a8
  sta f:MENU_TEXT,x
  a16
  inx
  iny
  iny
  cpy #2*DIGITS
  bcc @digit
  rts

; display_apply: write the timing of the monitor into the mode table of the
; card while it is stopped (mirror_open): the factory profile of the
; monitor and its thresholds, then an edited or selected record when it is
; good (else the profile stays). Then the game clock rate. JSL.
display_apply:
  php
  ax16
  phx
  phy
  phb
  phk
  plb
  jsr .loword(display_init)
  stz a:.loword(display_monitor)
  a8
  lda f:DISPLAY_MODE+DISPLAY_PIXEL_CLOCK
  cmp #PIXEL_CLOCK_RGB
  a16
  bne :+
  lda #MONITOR_RGB
  sta a:.loword(display_monitor)
:
  lda a:.loword(display_monitor)
  beq :+
  ldy #DISPLAY_N
  bra :++
:
  ldy #0
:
  ldx #MODE_DATA
  a8
@copy:
  lda a:.loword(display_profiles),y
  sta f:DISPLAY_MODE,x
  iny
  inx
  inx
  inx
  inx                           ; MODE_ENTRY
  cpx #DISPLAY_N*MODE_ENTRY+MODE_DATA
  bne @copy
  a16
  lda a:.loword(display_monitor)
  asl
  asl                           ; two words for each monitor
  tax
  lda a:.loword(display_thresholds),x
  sta f:DISPLAY_FIRST
  lda a:.loword(display_thresholds+2),x
  sta f:DISPLAY_HALF
  jsr .loword(display_get_preset)
  bne @selected_record
  jsr .loword(display_dirty_mask)
  and f:DSET+SET_DISPLAY_EDITED
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
  cpy #DISPLAY_RECORD_SIZE
  bcc @custom_loop
@work_ready:
  ldx #0
  ; The H total, the blanking start and end, the sync start and end.
  lda a:.loword(display_work),x
  sec
  sbc #HTOTAL_BIAS
  a8
  sta f:DISPLAY_MODE+DISPLAY_CRTC_00
  a16
  lda a:.loword(display_work)+DR_HBLANK_START,x
  a8
  sta f:DISPLAY_MODE+DISPLAY_CRTC_02
  a16
  lda a:.loword(display_work)+DR_HBLANK_END,x
  and #END_LOW_BITS
  ora #CRTC3_FIXED
  a8
  sta f:DISPLAY_MODE+DISPLAY_CRTC_03
  a16
  lda a:.loword(display_work)+DR_HSYNC_START,x
  a8
  sta f:DISPLAY_MODE+DISPLAY_CRTC_04
  a16
  lda a:.loword(display_work)+DR_HBLANK_END,x
  and #END_LOW_BITS+1           ; the blanking end bit 5 goes to CRTC 5 bit 7
  asl
  asl
  sta a:.loword(display_tmp)
  lda a:.loword(display_work)+DR_HSYNC_END,x
  and #END_LOW_BITS
  ora a:.loword(display_tmp)
  a8
  sta f:DISPLAY_MODE+DISPLAY_CRTC_05
  a16
  ; CRTC 6 and the overflow bits of CRTC 7 (bit 0 and 5: the total bits 8
  ; and 9; bit 2 and 7: the sync start; bit 3: the blanking start bit 8);
  ; the fixed visible height bits stay.
  lda a:.loword(display_work)+DR_VTOTAL,x
  sec
  sbc #VTOTAL_BIAS
  sta a:.loword(display_total)
  a8
  sta f:DISPLAY_MODE+DISPLAY_CRTC_06
  lda f:DISPLAY_MODE+DISPLAY_CRTC_07
  and #OVERFLOW_KEEP
  sta a:.loword(display_bits)
  a16
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
  lda a:.loword(display_work)+DR_VSYNC_START,x
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
  lda a:.loword(display_work)+DR_VBLANK_START,x
  xba
  and #1
  asl
  asl
  asl
  ora a:.loword(display_bits)
  a8
  sta f:DISPLAY_MODE+DISPLAY_CRTC_07
  lda f:DISPLAY_MODE+DISPLAY_CRTC_09
  and #MAX_SCAN_KEEP
  sta a:.loword(display_bits)
  a16
  lda a:.loword(display_work)+DR_VBLANK_START,x
  xba
  and #2
  asl
  asl
  asl
  asl
  ora a:.loword(display_bits)
  a8
  sta f:DISPLAY_MODE+DISPLAY_CRTC_09
  a16
  lda a:.loword(display_work)+DR_VSYNC_START,x
  a8
  sta f:DISPLAY_MODE+DISPLAY_CRTC_10
  a16
  lda a:.loword(display_work)+DR_VSYNC_END,x
  and #VSYNC_END_BITS
  ora #VSYNC_IRQ_OFF
  a8
  sta f:DISPLAY_MODE+DISPLAY_CRTC_11
  a16
  lda a:.loword(display_work)+DR_VBLANK_START,x
  a8
  sta f:DISPLAY_MODE+DISPLAY_CRTC_15
  a16
  lda a:.loword(display_work)+DR_VBLANK_END,x
  dec
  a8
  sta f:DISPLAY_MODE+DISPLAY_CRTC_16
  a16
  lda a:.loword(display_work)+DR_CLOCK,x
  a8
  sta f:DISPLAY_MODE+DISPLAY_CLOCK
  a16
  and #3                        ; MISC bits 2-3: the clock select
  asl
  asl
  ora #MISC_FIXED
  sta a:.loword(display_bits)
  lda a:.loword(display_work)+DR_POLARITY,x
  and #POLARITIES-1             ; MISC bits 6-7: the sync polarities
  asl
  asl
  asl
  asl
  asl
  asl
  ora a:.loword(display_bits)
  a8
  sta f:DISPLAY_MODE+DISPLAY_MISC
  a16
  ; A custom record sends each finished picture at once; it still latches
  ; at the retrace: no division and no host work for each picture.
  lda #NO_THRESHOLD
  sta f:DISPLAY_FIRST
@default_done:
@done:
  jsl game_clock_display_rate
  plb
  ply
  plx
  plp
  rtl

; display_boot_apply: at the start, display_apply with the card stopped, also
; for the factory timing, so that the game clock has its rate; the next
; update is due now. JSL.
display_boot_apply:
  php
  ax16
  phb
  phk
  plb
  jsr .loword(display_init)
  ; Apply even factory timing at boot so its game deadline uses that rate.
  jsl mirror_open
  jsl display_apply
  jsl mirror_close
  a16
  lda f:GAME_CLOCK
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
display_clock_words: .word 0,1,5,6,12  ; the DR_CLOCK values (display_clock_select)
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
display_dirty_bits: .word 1,2,4,8,16,32,64,128,256  ; the SET_DISPLAY_EDITED bit of each record
display_steps: .word .loword(-10),.loword(-1),1,10  ; the steps of the MP_EDIT choices
display_divisors: .word 1000,100,10,1
; The display state.
display_work: .res DISPLAY_RECORD_SIZE  ; display_apply: the record
display_heading: .word 0        ; MP_EDIT: the name of the field
display_slot: .word 0           ; the record of the preset
display_keycode: .word 0        ; display_key: the key
display_monitor: .word 0        ; MONITOR_VGA or MONITOR_RGB (display_apply)
display_parent: .word 0         ; MP_EDIT: the page that it came from
display_field: .word 0          ; MP_EDIT: the DR_* field
display_field_draw: .word 0     ; display_draw: the DR_* field
display_edit: .word 0           ; MP_EDIT: the value
display_old: .word 0            ; display_edit_key: the value before
display_invalid: .word 0        ; 1: show INVALID TIMING
display_index: .word 0          ; display_draw: the row
display_count: .word 0          ; display_draw: the rows
display_item_table: .word 0     ; display_draw: the names of the rows
display_tmp: .word 0
display_bound: .word 0          ; display_validate: a limit
display_total: .word 0          ; display_validate, display_apply: a total
display_bits: .word 0           ; display_apply: a register
display_value: .word 0          ; display_number: the rest
display_digit: .word 0          ; display_number: the digit
.include "display-control.inc"
