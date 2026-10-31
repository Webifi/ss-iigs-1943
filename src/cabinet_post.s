; Post-ending game-over and initials. This state occupies otherwise unused
; bank-zero cabinet bytes $1578-$159b; the ranking remains at CAB_SCORES.
.a8
.i16
CAB_POST_MASK = $1578
CAB_POST_PHASE = $1579
CAB_POST_REMAIN = $157a
CAB_POST_BLINK = $157c
CAB_POST_LAYOUT = $157d
CAB_POST_ACTIVE = $157e
CAB_POST_SLOT = $157f
CAB_POST_POS = $1581
CAB_POST_CURSOR = $1583
CAB_POST_MOVE = $1585
CAB_POST_FIRE = $1587
CAB_POST_NAMES = $1589
CAB_POST_QUALIFIED = $158f
CAB_POST_PLAYER = $1590
CAB_POST_RANK = $1592
CAB_POST_TEMP = $1594
CAB_POST_DIRTY = $1595
CAB_POST_HISTORY = $1596
; Ordinary game-over entry runs beside gameplay and uses independent timers.
CAB_LIVE_STATE = $159c       ; 0 idle, 1 initials, 2 finished-rank blink
CAB_LIVE_TIMER = $159e       ; two 16-bit update counts
CAB_LIVE_CLOCK = $15a2       ; two independent display clocks
CAB_LIVE_LAYOUT = $15a4      ; first state + three times second state
CAB_LIVE_VALUES = $15a5      ; six selected glyphs per player
CAB_LIVE_SAVE = $15b1        ; preserves simultaneous stage-result fields
CAB_LIVE_NEW_RANK = $15bd

cabinet_post_begin:
  ldx #34
@clear:
  stz CAB_POST_PHASE,x
  dex
  bpl @clear
  lda #2
  sta CAB_ENDING
  lda #1
  sta CAB_POST_PHASE
  lda #255
  sta CAB_POST_LAYOUT
  rep #$20
  lda #263                    ; seven 45/30-frame GAME OVER blinks
  sta CAB_POST_REMAIN
  sep #$20
  lda #$28
  jsl game_sound_request
  lda #$2e
  jsl game_sound_request
  lda CAB_POST_MASK
  clc
  adc #74
  jsr .loword(cabinet_post_show)
  rtl

cabinet_post_tick:
  lda CAB_POST_PHASE
  cmp #1
  bne @initials
  rep #$20
  dec CAB_POST_REMAIN
  bne @blink16
  sep #$20
  jsr .loword(cabinet_post_qualify)
  lda CAB_POST_ACTIVE
  bne :+
  jmp .loword(@leave)
:
  lda #2
  sta CAB_POST_PHASE
  stz CAB_POST_BLINK
  rep #$20
  lda #250                    ; original timeout: 500 arcade frames
  sta CAB_POST_REMAIN
  sep #$20
  lda #$37                    ; empty entry positions, as in the arcade
  .repeat 6,I
    sta CAB_POST_NAMES+I
  .endrepeat
  jsr .loword(cabinet_post_fields)
  lda CAB_POST_ACTIVE
  clc
  adc #77
  jsr .loword(cabinet_post_show)
  rtl
@blink16:
  sep #$20
  lda CAB_POST_BLINK
  clc
  adc #2
  cmp #75
  bcc :+
  sbc #75
:
  sta CAB_POST_BLINK
  cmp #45
  bcs @blank
  lda CAB_POST_MASK
  clc
  adc #74
  bra @show
@blank:
  lda #74
@show:
  jsr .loword(cabinet_post_show)
  rtl
@initials:
  cmp #2
  bne @rank_hold
  rep #$20
  dec CAB_POST_REMAIN
  bne @input16
  sep #$20
  ldx #0
  jsr .loword(cabinet_post_commit)
  ldx #1
  jsr .loword(cabinet_post_commit)
  bra @start_rank
@input16:
  sep #$20
  inc CAB_POST_BLINK           ; two updates per 8-frame color cycle
  ldx #0
  jsr .loword(cabinet_post_input)
  ldx #1
  jsr .loword(cabinet_post_input)
  lda CAB_POST_ACTIVE
  beq @start_rank
  jsr .loword(cabinet_post_fields)
  lda CAB_POST_ACTIVE
  clc
  adc #77
  jsr .loword(cabinet_post_show)
  rtl
@start_rank:
  lda #3
  sta CAB_POST_PHASE
  stz CAB_POST_BLINK
  rep #$20
  lda #192                    ; original rank flash lasts about 6.4 s
  sta CAB_POST_REMAIN
  sep #$20
  jsr .loword(cabinet_post_rank_fields)
  lda #255
  sta CAB_POST_LAYOUT
  lda CAB_POST_QUALIFIED
  clc
  adc #81
  jsr .loword(cabinet_post_show)
  rtl
@rank_hold:
  rep #$20
  dec CAB_POST_REMAIN
  bne @rank_wait16
  sep #$20
@leave:
  stz CAB_ENDING
  stz CAB_POST_PHASE
  lda #4
  jsl cabinet_select
  rtl
@rank_wait16:
  sep #$20
  inc CAB_POST_BLINK
  lda CAB_POST_BLINK
  and #15
  cmp #10
  bcs @rank_blank
  lda CAB_POST_QUALIFIED
  clc
  adc #81
  jsr .loword(cabinet_post_show)
  rtl
@rank_blank:
  lda #81
  jsr .loword(cabinet_post_show)
  rtl

; Select a prepared post-ending overlay. Alternating two existing ending
; modes rebuilds the cached tableau only when text or a blink changes.
cabinet_post_show:
  cmp CAB_POST_LAYOUT
  beq @done
  sta CAB_POST_LAYOUT
  pha
  lda #1
  sta CAB_POST_DIRTY
  lda GAME_FLOW
  cmp #20
  beq :+
  lda #20
  bra @select
:
  lda #21
@select:
  jsl cabinet_select
  pla
  rep #$20
  and #255
  sec
  sbc #74
  tax
  sep #$20
  lda f:cabinet_post_counts,x
  sta CAB_ENDING_TEXT
@done:
  rts

; The last credit layout stays resident. Each prepared job replaces only its
; suffix in that same SRAM allocation, never the retained credit prefix.
cabinet_post_append:
  lda CAB_POST_DIRTY
  bne :+
  rep #$20
  ldx WORLD_OUTPUT
  clc
  rtl
:
  stz CAB_POST_DIRTY
  rep #$20
  lda CAB_POST_LAYOUT
  and #255
  sec
  sbc #74
  asl
  sta $d4
  asl
  clc
  adc $d4
  tax
  lda f:cabinet_post_jobs,x
  sta CAB_LENGTH
  lda f:cabinet_post_jobs+2,x
  sta $d4
  lda f:cabinet_post_jobs+4,x
  sta $d6
  ldx WORLD_OUTPUT
  ldy #0
@copy:
  lda [$d4],y
  xba
  sta a:0,x
  inx
  inx
  iny
  iny
  cpy CAB_LENGTH
  bcc @copy
  sec
  rtl

; A newly earned score goes before an equal score, matching the arcade.
; Both players can qualify; a later insertion updates the first player's rank.
cabinet_post_qualify:
.a8
.i16
  stz CAB_POST_ACTIVE
  stz CAB_POST_QUALIFIED
  lda #255
  sta CAB_POST_SLOT
  sta CAB_POST_SLOT+1
  lda CAB_POST_MASK
  and #1
  beq @second
  ldx #0
  jsr .loword(cabinet_post_insert)
  sta CAB_POST_SLOT
  cmp #255
  beq @second
  lda #1
  sta CAB_POST_ACTIVE
@second:
  lda CAB_POST_MASK
  and #2
  beq @done
  ldx #128
  jsr .loword(cabinet_post_insert)
  sta CAB_POST_SLOT+1
  cmp #255
  beq @done
  lda CAB_POST_SLOT
  cmp #255
  beq @second_active
  lda CAB_POST_SLOT+1
  cmp CAB_POST_SLOT
  bcc @shift_first
  beq @shift_first
  bra @second_active
@shift_first:
  inc CAB_POST_SLOT
  lda CAB_POST_SLOT
  cmp #5
  bcc @second_active
  lda #255
  sta CAB_POST_SLOT
  stz CAB_POST_ACTIVE
@second_active:
  lda CAB_POST_ACTIVE
  ora #2
  sta CAB_POST_ACTIVE
@done:
  lda CAB_POST_ACTIVE
  sta CAB_POST_QUALIFIED
  rts

; X is the player offset (0 or 128). Returns a ranking index or $FF.
cabinet_post_insert:
  stx CAB_POST_PLAYER
  rep #$20
  stz CAB_POST_RANK
  sep #$20
@rank:
  ldx CAB_POST_RANK
  ldy CAB_POST_PLAYER
  lda #8
  sta CAB_POST_TEMP
@compare:
  lda PLAYER+$38,y
  cmp f:CAB_SCORES,x
  bcc @next
  bne @insert
  inx
  iny
  dec CAB_POST_TEMP
  bne @compare
  bra @insert
@next:
  rep #$20
  lda CAB_POST_RANK
  clc
  adc #16
  sta CAB_POST_RANK
  cmp #80
  sep #$20
  bcc @rank
  lda #255
  rts
@insert:
  rep #$20
  lda CAB_POST_RANK
  clc
  adc #16
  sta $d4
  ldx #79
  cpx $d4
  bcc @copy16
  sep #$20
@shift:
  lda f:CAB_SCORES-16,x
  sta f:CAB_SCORES,x
  dex
  cpx $d4
  bcs @shift
  rep #$20
@copy16:
  ldx CAB_POST_RANK
  ldy CAB_POST_PLAYER
  sep #$20
  lda #8
  sta CAB_POST_TEMP
@copy:
  lda PLAYER+$38,y
  sta f:CAB_SCORES,x
  inx
  iny
  dec CAB_POST_TEMP
  bne @copy
  lda #$24
  sta f:CAB_SCORES,x
  inx
  sta f:CAB_SCORES,x
  inx
  sta f:CAB_SCORES,x
  rep #$20
  lda CAB_POST_RANK
  lsr
  lsr
  lsr
  lsr
  sep #$20
  rts

cabinet_post_input:
  lda f:cabinet_post_bits,x
  and CAB_POST_ACTIVE
  bne :+
  rts
:
  cpx #0
  bne :+
  lda INPUT_P1
  bra @sample
:
  lda INPUT_P2
@sample:
  eor #255
  sta CAB_POST_TEMP
  and #3
  beq @move_up
  cmp #3
  beq @move_up
  lda CAB_POST_MOVE,x
  beq @move
  dec CAB_POST_MOVE,x
  bra @fire
@move_up:
  stz CAB_POST_MOVE,x
  bra @fire
@move:
  lda #1                     ; direction repeats every four arcade frames
  sta CAB_POST_MOVE,x
  lda CAB_POST_TEMP
  and #1
  beq @left
  inc CAB_POST_CURSOR,x
  lda CAB_POST_POS,x
  cmp #3
  bne :+
  lda CAB_POST_CURSOR,x
  cmp #2
  bcc @letter
  stz CAB_POST_CURSOR,x
  bra @letter
:
  lda CAB_POST_CURSOR,x
  cmp #46
  bcc @letter
  stz CAB_POST_CURSOR,x
  bra @letter
@left:
  lda CAB_POST_CURSOR,x
  bne :+
  lda CAB_POST_POS,x
  cmp #3
  beq @left_end_choice
  lda #46
  bra @left_wrap
@left_end_choice:
  lda #2
@left_wrap:
  sta CAB_POST_CURSOR,x
:
  dec CAB_POST_CURSOR,x
@letter:
  jsr .loword(cabinet_post_letter)
  lda #255
  sta CAB_POST_LAYOUT
@fire:
  lda CAB_POST_TEMP
  and #16
  bne @pressed
  stz CAB_POST_FIRE,x
  rts
@pressed:
  lda CAB_POST_FIRE,x
  beq :+
  dec CAB_POST_FIRE,x
  rts
:
  lda #7                     ; held fire repeats every 16 arcade frames
  sta CAB_POST_FIRE,x
  lda CAB_POST_POS,x
  cmp #3
  bne @advance
  lda CAB_POST_CURSOR,x
  beq @commit
  bra @back
@advance:
  jsr .loword(cabinet_post_index)
  lda CAB_POST_NAMES,y
  cmp #$29                   ; BACK is also in the ordinary alphabet
  bne :+
  lda #$37
  sta CAB_POST_NAMES,y
  lda #0
  sta CAB_POST_HISTORY,y
  bra @back
:
  inc CAB_POST_POS,x
  stz CAB_POST_CURSOR,x
  bra @changed
@back:
  lda CAB_POST_POS,x
  beq @changed
  dec CAB_POST_POS,x
  jsr .loword(cabinet_post_index)
  lda CAB_POST_HISTORY,y
  sta CAB_POST_CURSOR,x
@changed:
  lda #255
  sta CAB_POST_LAYOUT
@done:
  rts
@commit:
  jsr .loword(cabinet_post_commit)
  bra @changed

; Store the displayed alphabet choice in this player's current character.
cabinet_post_letter:
  lda CAB_POST_POS,x
  cmp #3
  bcs @done
  jsr .loword(cabinet_post_index)
  lda CAB_POST_CURSOR,x
  sta CAB_POST_HISTORY,y
  phx
  rep #$20
  and #255
  tax
  sep #$20
  lda f:cabinet_post_alphabet,x
  sta CAB_POST_NAMES,y
  plx
@done:
  rts

; Return the selected player's current character index in Y.
cabinet_post_index:
  lda CAB_POST_POS,x
  sta $d4
  txa
  beq :+
  lda #3
:
  clc
  adc $d4
  rep #$20
  and #255
  tay
  sep #$20
  rts

; Finish one player, preserving the other player's independent input.
cabinet_post_commit:
  lda f:cabinet_post_bits,x
  and CAB_POST_ACTIVE
  beq @done
  phx
  lda CAB_POST_SLOT,x
  rep #$20
  and #255
  asl
  asl
  asl
  asl
  sta $d4
  txa
  and #255
  beq :+
  lda #3
:
  tay
  ldx $d4
  sep #$20
  .repeat 3,I
    lda CAB_POST_NAMES,y
    cmp #$37
    beq :+
    cmp #$29
    bne :++
:
    lda #$24
:
    sta f:CAB_SCORES+8+I,x
    iny
  .endrepeat
  plx
  lda f:cabinet_post_bits,x
  eor #255
  and CAB_POST_ACTIVE
  sta CAB_POST_ACTIVE
@done:
  rts

; Eight entry glyphs, or twelve rank/name glyphs, reuse the existing fields.
cabinet_post_fields:
  ldy #0
  ldx #0
@player:
  .repeat 3,I
    lda CAB_POST_NAMES+I,x
    jsr .loword(cabinet_post_glyph)
    jsr .loword(cabinet_post_flash)
    sta CAB_RESULT_DIGITS,y
    iny
  .endrepeat
  phx
  tya
  cmp #4
  lda CAB_POST_POS
  bcc :+
  lda CAB_POST_POS+1
:
  cmp #3
  beq @end_choice
  lda #$24
  bra @choice_ready
@end_choice:
  tya
  cmp #4
  lda CAB_POST_CURSOR
  bcc :+
  lda CAB_POST_CURSOR+1
:
  beq :+
  lda #$29
  bra @choice_ready
:
  lda #$28
@choice_ready:
  jsr .loword(cabinet_post_glyph)
  jsr .loword(cabinet_post_flash)
  sta CAB_RESULT_DIGITS,y
  iny
  plx
  cpy #4
  bne @done
  ldx #3
  bra @player
@done:
  rts

; X selects player (0 or 3), Y selects that player's field. The original
; alternates the selected character's colors 0/15 every four arcade frames.
cabinet_post_flash:
  sta CAB_POST_TEMP
  lda CAB_ENDING
  cmp #2
  beq @ending_clock
  cpx #0
  bne :+
  lda CAB_LIVE_CLOCK
  bra @clock_ready
:
  lda CAB_LIVE_CLOCK+1
  bra @clock_ready
@ending_clock:
  lda CAB_POST_BLINK
@clock_ready:
  and #2
  beq @normal
  cpx #0
  bne @second
  lda CAB_POST_ACTIVE
  and #1
  beq @normal
  tya
  and #3
  cmp CAB_POST_POS
  bra @compare
@second:
  lda CAB_POST_ACTIVE
  and #2
  beq @normal
  tya
  and #3
  cmp CAB_POST_POS+1
@compare:
  bne @normal
  lda CAB_POST_TEMP
  clc
  adc #CAB_POST_FONT_FLASH
  rts
@normal:
  lda CAB_POST_TEMP
  rts

cabinet_post_rank_fields:
  ; Rank and initials are reconstructed from the retained ranking records.
  ldx #0
  jsr .loword(cabinet_post_rank_one)
  ldx #1
  jmp .loword(cabinet_post_rank_one)

cabinet_post_rank_one:
  lda f:cabinet_post_bits,x
  and CAB_POST_QUALIFIED
  bne :+
  rts
:
  lda CAB_POST_SLOT,x
  clc
  adc #1
  jsr .loword(cabinet_post_glyph)
  cpx #0
  bne @second
  ldy #0
  bra @write
@second:
  ldy #6
@write:
  sta CAB_RESULT_DIGITS,y
  iny
  lda CAB_POST_SLOT,x
  beq @first
  cmp #1
  beq @second_rank
  cmp #2
  beq @third
  lda #$1d                   ; T
  bra @ordinal
@first:
  lda #$1c                   ; S
  bra @ordinal
@second_rank:
  lda #$17                   ; N
  bra @ordinal
@third:
  lda #$1b                   ; R
@ordinal:
  jsr .loword(cabinet_post_glyph)
  sta CAB_RESULT_DIGITS,y
  iny
  lda CAB_POST_SLOT,x
  cmp #1
  beq @d
  cmp #2
  beq @d
  lda CAB_POST_SLOT,x
  beq @t
  lda #$11                   ; H
  bra @last_ordinal
@d:
  lda #$0d                   ; D
  bra @last_ordinal
@t:
  lda #$1d
@last_ordinal:
  jsr .loword(cabinet_post_glyph)
  sta CAB_RESULT_DIGITS,y
  iny
  phx
  txa
  beq :+
  lda #3
:
  rep #$20
  and #255
  tax
  sep #$20
  .repeat 3,I
    lda CAB_POST_NAMES+I,x
    cmp #$37
    beq :+
    cmp #$29
    bne :++
:
    lda #$24
:
    jsr .loword(cabinet_post_glyph)
    sta CAB_RESULT_DIGITS,y
    iny
  .endrepeat
  plx
@done:
  rts

cabinet_post_glyph:
  phx
  rep #$20
  and #255
  tax
  sep #$20
  lda f:cabinet_post_glyphs,x
  plx
  rts

; Keep both scores when live records are cleared for the cabinet screens.
cabinet_save_scores:
.a8
.i16
  phx
  rep #$20
  ldx #6
@copy:
  lda PLAYER+$38,x
  sta CAB_ENDING_SCORES,x
  lda PLAYER+$b8,x
  sta CAB_ENDING_SCORES+8,x
  dex
  dex
  bpl @copy
  sep #$20
  plx
  rtl

; Replace the literal job's fields with ranking and last-game score glyphs.
; The packet is stored word-swapped, so each byte's physical offset is xor 1.
cabinet_rank_packet:
.a8
.i16
  ldx #0
  ldy #0
  stz $d7                     ; ranking fields use the white font
@rank:
  jsr .loword(cabinet_rank_score)
  lda #3
  sta $d9
@initial:
  lda f:CAB_SCORES,x
  jsr .loword(cabinet_rank_emit)
  inx
  dec $d9
  bne @initial
  .repeat 5
    inx
  .endrepeat
  cpx #80
  bcc @rank
  lda #1                      ; red high score from the ranking leader
  sta $d7
  ldx #0
  jsr .loword(cabinet_rank_score)
  inc $d7                     ; both players' preserved white score font
  ldx #0
  jsr .loword(cabinet_rank_score)
  jsr .loword(cabinet_rank_score)
  rtl

cabinet_rank_score:
  lda #1
  sta $d8                     ; suppress leading zeroes, except the last digit
  lda #8
  sta $d9
@digit:
  lda $d7
  cmp #2
  bne @rank_value
  lda CAB_ENDING_SCORES,x
  bra @value
@rank_value:
  lda f:CAB_SCORES,x
@value:
  bne @significant
  lda $d8
  beq @zero
  lda $d9
  cmp #1
  beq @zero
  lda #$24
  bra @digit_ready
@zero:
  lda #0
  bra @digit_ready
@significant:
  stz $d8
@digit_ready:
  jsr .loword(cabinet_rank_emit)
  inx
  dec $d9
  bne @digit
  rts

cabinet_rank_emit:
  phx
  rep #$20
  and #255
  tax
  sep #$20
  lda f:cabinet_post_glyphs,x
  sta $da
  lda $d7
  beq @mapped
  lda $da
  cmp #36                     ; blank is shared by all three font colours
  beq @mapped
  lda $d7
  cmp #1
  beq @high
  lda $da
  clc
  adc #CAB_POST_FONT_PLAYER
  bra @color
@high:
  lda $da
  clc
  adc #CAB_POST_FONT_HIGH
@color:
  sta $da
@mapped:
  rep #$20
  tya
  clc
  adc WORLD_OUTPUT
  clc
  adc #CAB_RANK_PACKET_FIELDS
  eor #1
  tax
  sep #$20
  lda $da
  sta a:0,x
  plx
  iny
  rts

cabinet_post_bits: .byte 1,2

; Clear only ordinary-entry state; the ranking survives a new game.
cabinet_live_reset:
.a8
.i16
  phx
  rep #$20
  ldx #32
@clear:
  stz CAB_LIVE_STATE,x
  dex
  dex
  bpl @clear
  sep #$20
  stz CAB_POST_ACTIVE
  stz CAB_POST_QUALIFIED
  plx
  rtl

; X is 0/128 and Y is the player number. Preserve both for the death path.
; Insertion occurs once, as the player's GAME OVER blink completes.
cabinet_live_begin:
.a8
.i16
  phx
  phy
  jsr .loword(cabinet_post_insert)
  cmp #255
  bne :+
  jmp .loword(@done)
:
  sta CAB_LIVE_NEW_RANK
  ldx PLAYER_CURSOR
  ldy #0
  cpx #0
  beq :+
  iny
:
  lda CAB_LIVE_NEW_RANK
  sta CAB_POST_SLOT,y
  ; A later player's insertion can move or evict the other pending entry.
  tya
  eor #1
  rep #$20
  and #255
  tax
  sep #$20
  lda CAB_LIVE_STATE,x
  beq @new_player
  lda CAB_POST_SLOT,x
  cmp CAB_LIVE_NEW_RANK
  bcc @new_player
  inc CAB_POST_SLOT,x
  lda CAB_POST_SLOT,x
  cmp #5
  bcc @new_player
  stz CAB_LIVE_STATE,x
  lda f:cabinet_post_bits,x
  eor #255
  and CAB_POST_ACTIVE
  sta CAB_POST_ACTIVE
@new_player:
  tyx
  lda #1
  sta CAB_LIVE_STATE,x
  lda f:cabinet_post_bits,x
  ora CAB_POST_ACTIVE
  sta CAB_POST_ACTIVE
  stz CAB_POST_POS,x
  stz CAB_POST_CURSOR,x
  stz CAB_POST_MOVE,x
  stz CAB_POST_FIRE,x
  stz CAB_LIVE_CLOCK,x
  txa
  rep #$20
  and #255
  asl
  tax
  lda #250                    ; 500 arcade frames to enter initials
  sta CAB_LIVE_TIMER,x
  sep #$20
  ldx #0
  cpy #0
  beq :+
  ldx #3
:
  ldy #3
@names:
  lda #$37
  sta CAB_POST_NAMES,x
  stz CAB_POST_HISTORY,x
  inx
  dey
  bne @names
@done:
  ply
  plx
  rtl

; Called once per two-raster game update, even during a stage report.
cabinet_live_tick:
.a8
.i16
  lda CAB_LIVE_STATE
  ora CAB_LIVE_STATE+1
  bne :+
  stz CAB_LIVE_LAYOUT
  rtl
:
  phx
  phy
  ldx #0
@player:
  lda CAB_LIVE_STATE,x
  beq @next
  cmp #1
  bne @rank_clock
  inc CAB_LIVE_CLOCK,x
  bra @timer
@rank_clock:
  lda CAB_LIVE_CLOCK,x
  clc
  adc #2
  cmp #15                    ; arcade rank blink: 12 frames on, 3 off
  bcc :+
  sbc #15
:
  sta CAB_LIVE_CLOCK,x
@timer:
  phx
  rep #$20
  txa
  and #255
  asl
  tay
  lda CAB_LIVE_TIMER,y
  beq @expired16
  dec
  sta CAB_LIVE_TIMER,y
  beq @expired16
  sep #$20
  plx
  lda CAB_LIVE_STATE,x
  cmp #1
  bne @next
  jsr .loword(cabinet_post_input)
  bra @after_input
@expired16:
  sep #$20
  plx
  lda CAB_LIVE_STATE,x
  cmp #1
  beq :+
  stz CAB_LIVE_STATE,x
  bra @next
:
  jsr .loword(cabinet_post_commit)
@after_input:
  lda f:cabinet_post_bits,x
  and CAB_POST_ACTIVE
  bne @next
  lda #2
  sta CAB_LIVE_STATE,x
  stz CAB_LIVE_CLOCK,x
  phx
  rep #$20
  txa
  and #255
  asl
  tax
  lda #180                   ; 24 repetitions of 12 on / 3 off
  sta CAB_LIVE_TIMER,x
  sep #$20
  plx
@next:
  inx
  cpx #2
  bne @player
  jsr .loword(cabinet_live_fields)
  ply
  plx
  rtl

; Keep result-screen data intact when the other player finishes a stage.
cabinet_live_fields:
  rep #$20
  ldx #10
@save:
  lda CAB_RESULT_DIGITS,x
  sta CAB_LIVE_SAVE,x
  dex
  dex
  bpl @save
  sep #$20
  jsr .loword(cabinet_post_fields)
  rep #$20
  .repeat 2,I
    lda CAB_RESULT_DIGITS+I*2
    sta CAB_LIVE_VALUES+I*2
    lda CAB_RESULT_DIGITS+4+I*2
    sta CAB_LIVE_VALUES+6+I*2
  .endrepeat
  sep #$20
  stz CAB_POST_QUALIFIED
  lda CAB_LIVE_STATE
  cmp #2
  bne :+
  inc CAB_POST_QUALIFIED
:
  lda CAB_LIVE_STATE+1
  cmp #2
  bne :+
  lda CAB_POST_QUALIFIED
  ora #2
  sta CAB_POST_QUALIFIED
:
  jsr .loword(cabinet_post_rank_fields)
  lda CAB_POST_QUALIFIED
  and #1
  beq @second_rank
  rep #$20
  .repeat 3,I
    lda CAB_RESULT_DIGITS+I*2
    sta CAB_LIVE_VALUES+I*2
  .endrepeat
  sep #$20
@second_rank:
  lda CAB_POST_QUALIFIED
  and #2
  beq @restore
  rep #$20
  .repeat 3,I
    lda CAB_RESULT_DIGITS+6+I*2
    sta CAB_LIVE_VALUES+6+I*2
  .endrepeat
  sep #$20
@restore:
  rep #$20
  ldx #10
@restore_word:
  lda CAB_LIVE_SAVE,x
  sta CAB_RESULT_DIGITS,x
  dex
  dex
  bpl @restore_word
  sep #$20
  lda CAB_LIVE_STATE
  cmp #2
  bne @first_visible
  lda CAB_LIVE_CLOCK
  cmp #12
  bcc :+
  lda #0
  bra @first_visible
:
  lda #2
@first_visible:
  sta CAB_LIVE_LAYOUT
  lda CAB_LIVE_STATE+1
  cmp #2
  bne @second_visible
  lda CAB_LIVE_CLOCK+1
  cmp #12
  bcc :+
  lda #0
  bra @second_visible
:
  lda #2
@second_visible:
  sta CAB_LIVE_NEW_RANK
  asl
  clc
  adc CAB_LIVE_NEW_RANK
  clc
  adc CAB_LIVE_LAYOUT
  sta CAB_LIVE_LAYOUT
  rts
