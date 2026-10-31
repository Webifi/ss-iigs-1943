; Native IIgs sprite command producer. Art-specific native writers and masks
; are build products. Inputs are the live eight-byte object list, not commands.
; $20..22 object pointer, $2a count, $2c sea start row, $2e page ($0000/$8000).
; Packet starts at bank 0 $8000; return length in $28. M=8/X=16, DBR=DP=0.
; Scratch $70..9f. Output words are byte-swapped for the PEI event sender.

planner_entry:
  rep #$30
  ldx $26                     ; append after restoration/background commands
  lda $2a
  sta $70
.if PLANNER_SAVE_BOUNDS
  stz $ce
  lda $2e
  beq :+
  lda #$0400
:
  clc
  adc #$5800
  sta $cc
.endif
planner_object:
  lda $70
  bne @have_object
  jmp planner_end
@have_object:
  ldy #0
  lda [$20],y
  asl
  tay
  phx
  tyx
  lda f:planner_code_table,x
  plx
  cmp #0
  bne @resident
  jmp planner_missing
@resident:
  sta $90
  ldy #2
  lda [$20],y
  and #31
  asl
  asl
  asl
  sta $72
  ldy #4
  lda [$20],y
  sta $74                    ; upright left
  and #3
  asl
  clc
  adc $72
  adc $90
  tay
  phx
  tyx
  lda f:PLANNER_BASE,x
  plx
  cmp #0
  bne @variant
  jmp planner_missing
@variant:
  sta $90
  ldy #6
  lda [$20],y
  sta $76                    ; upright top
  ; Reject wholly hidden objects before either clipping path. Signed wrapped
  ; coordinates outside these intervals cannot touch the display.
  clc
  adc #PLANNER_SIZE-1
  cmp #256+PLANNER_SIZE-1
  bcs @hidden
  lda $74
  clc
  adc #PLANNER_SIZE-1
  cmp #224+PLANNER_SIZE-1
  bcc @visible
@hidden:
  jmp @done
@visible:
  lda $76
  clc
  adc $2c
  clc
  adc #16                    ; row table includes -16 through 511
  asl
  tay
  phx
  tyx
  lda f:planner_row56,x
  plx
  sta $86
  lda $74
  cmp #$8000                 ; arithmetic right shift, including negative X
  ror
  cmp #$8000
  ror
  sta $78                    ; left in four-pixel groups
  clc
  adc $86
  clc
  adc $2e
  sta $86
  and #$f000
  xba
  lsr
  lsr
  lsr
  lsr
  clc
  adc #$92
  sta $88                    ; destination MMU CBR, low byte
  lda #1
  sta $8a
  lda $74
  cmp #225-PLANNER_SIZE
  bcs @clipped
  lda $76
  cmp #257-PLANNER_SIZE
  bcs @clipped
  bra @dispatch
@clipped:
  stz $8a
@dispatch:
.if PLANNER_SAVE_BOUNDS
  jsr .loword(planner_save_bounds)
.endif
  pea .loword(@done-1)
  jmp ($0090)
@done:
  lda $20
  clc
  adc #8
  sta $20
  bcc @same_bank
  sep #$20
  inc $22
  rep #$20
@same_bank:
  dec $70
  jmp planner_object

planner_end:
.if PLANNER_SAVE_BOUNDS
  phx
  lda $68
  and #1
  asl
  tax
  lda $ce
  sta a:$1518,x
  plx
.endif
  lda #Z_SCENE_END_BE
  sta a:$0000,x
  inx
  inx
  txa
  sec
  sbc #$8002
  sta $28
  xba
  sta a:$8000
  sep #$20
  rtl

planner_missing:
.if PLANNER_BANKED
  rep #$20
  ldy #0
  lda [$20],y
  phx
  tax
  sep #$20
  lda f:planner_bank_table,x
  plx
  cmp #0
  beq @missing
  cmp #^PLANNER_BASE
  beq @missing
  sta $92
  rep #$20
  lda #.loword(planner_object)
  sta $90
  jml [$0090]
@missing:
.endif
  sep #$20
  lda #$ee
  sta f:$050301
  rtl

; Exact screen/window clipping fallback. It emits one four-pixel group per
; command. Normal fully visible sprites use the compiled slab writers below.
; Descriptor in $98: width, source BBR/read-bank, source logical, masks.
planner_fallback:
  rep #$20
  phx
  ldx $98
  lda f:PLANNER_BASE,x
  pha
  and #255
  sta $7a                    ; trimmed width
  pla
  xba
  and #255
  sta $94                    ; trimmed rows
  lda f:PLANNER_BASE+2,x
  sta $7c                    ; source BBR low, read segment high
  lda f:PLANNER_BASE+4,x
  sta $7e                    ; logical source, at the first occupied group
  lda f:PLANNER_BASE+6,x
  clc
  adc $78
  sta $78                    ; trimmed left group
  lda f:PLANNER_BASE+8,x
  clc
  adc $76
  sta $92                    ; trimmed top row
  lda f:PLANNER_BASE+10,x
  clc
  adc $86
  sta $86
  lda f:PLANNER_BASE+12,x
  sta $6a                    ; source gap after a trimmed row
  txa
  clc
  adc #14
  sta $64
  sep #$20
  lda #^PLANNER_BASE
  sta $66
  rep #$20
  plx
@row:
  lda $92
  cmp #256
  bcc @visible_row
  lda $64
  clc
  adc $7a
  sta $64
  lda $7e
  clc
  adc $7a
  sta $7e
  jmp @row_done
@visible_row:
  lda $78
  sta $96                    ; column group
  lda $7a
  sta $9a                    ; columns left
  lda $86
  sta $9c                    ; running physical destination
@group:
  lda [$64]
  and #15
  sta $9e
  beq @skip
  lda $96
  cmp #56
  bcs @skip
  lda #Z_RECT_ONE_BE
  sta a:$0000,x
  lda $9c
  and #$f000
  xba
  lsr
  lsr
  lsr
  lsr
  clc
  adc #$92
  sta $8c
  lda $7c
  and #255
  xba
  ora $8c
  sta a:$0002,x
  lda $9e
  xba
  sta $8c
  lda $7c
  xba
  and #255
  ora $8c
  sta a:$0004,x
  lda $7e
  xba
  sta a:$0006,x
  lda $9c
  and #$0fff
  ora #$e000
  xba
  sta a:$0008,x
  lda #1                    ; swapped gap=0, height=1
  sta a:$000a,x
  txa
  clc
  adc #12
  tax
@skip:
  inc $64
  inc $7e
  inc $9c
  inc $96
  dec $9a
  beq @row_done
  jmp @group
@row_done:
  lda $7e
  clc
  adc $6a
  sta $7e
  lda $86
  clc
  adc #56
  sta $86
  inc $92
  dec $94
  beq @done
  jmp @row
@done:
  rts

.if PLANNER_SAVE_BOUNDS
; Reuse the sprite planner's physical base and visibility result. This is
; the restore command for this back page's next use, in event-wire order.
; $cc output, $ce count; $c8 temporary. No second pass over the object list.
planner_save_bounds:
  phx
  ldy $cc
  lda $8a
  beq @clipped
  lda $74
  and #3
  beq @aligned
  lda #Z_RESTORE_5_BE
  bra @entry
@aligned:
  lda #Z_RESTORE_4_BE
@entry:
  sta a:$0000,y
  lda #$1000
  sta a:$0004,y
  lda $86
  bra @base
@clipped:
  lda $74
  clc
  adc #16
  asl
  asl
  tax
  lda f:planner_restore_columns,x
  sta a:$0000,y
  lda f:planner_restore_columns+2,x
  sta $c8
  lda $76
  clc
  adc #16
  asl
  asl
  tax
  lda f:planner_restore_rows,x
  sta a:$0004,y
  lda f:planner_restore_rows+2,x
  clc
  adc $c8
  clc
  adc $86
@base:
  xba
  sta a:$0002,y
  tya
  clc
  adc #6
  sta $cc
  inc $ce
  plx
  rts
.endif
