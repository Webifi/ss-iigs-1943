; The game over and the initials, after the ending (cabinet_post_*) and
; during the play when a player is out (cabinet_live_*): GAME OVER blinks,
; a player whose score enters the ranking (CAB_SCORES) types three initials,
; then the new ranks flash. The arcade text codes and the glyphs come from
; scripts/cabinet_video.py.
.a8
.i16
POST_OVER = 1                ; CAB_POST_PHASE: GAME OVER blinks
POST_ENTRY = 2               ; CAB_POST_PHASE: the players enter the initials
POST_RANK = 3                ; CAB_POST_PHASE: the new ranks flash
POST_P1 = 1                  ; CAB_POST_MASK, CAB_POST_ACTIVE, CAB_POST_QUALIFIED
POST_P2 = 2
NO_LAYOUT = 255              ; CAB_POST_LAYOUT: the next cabinet_post_show draws
POST_PAGE_A = 20             ; cabinet_post_show: two ending pages in turn, so
POST_PAGE_B = 21             ; that each change draws a new tableau
POST_JOB_SIZE = 6            ; a cabinet_post_jobs entry: the length, the long address
GAME_OVER_TICKS = 263        ; seven GAME OVER blinks of 45/30 frames
OVER_BLINK = 75              ; GAME OVER: 2 for each update; on under OVER_BLINK_ON
OVER_BLINK_ON = 45
ENTRY_TICKS = 250            ; the initials: 500 arcade frames
RANK_FLASH_TICKS = 192       ; the new ranks flash for about 6.4 s
RANK_BLINK = 16              ; the new ranks: on for RANK_BLINK_ON of each 16
RANK_BLINK_ON = 10
LIVE_RANK_BLINK = 15         ; the live rank blink: 12 frames on, 3 off (2 for
LIVE_RANK_ON = 12            ; each update)
LIVE_RANK_TICKS = 180        ; 24 times 12 on, 3 off
LIVE_SHOW = 2                ; CAB_LIVE_LAYOUT: the rank of a player shows
MOVE_REPEAT = 1              ; a held direction repeats each four arcade frames
FIRE_REPEAT = 7              ; held fire repeats each 16 arcade frames
NO_SLOT = 255                ; CAB_POST_SLOT: no rank
RANKS = CAB_SCORES_SIZE/CAB_SCORE_ENTRY
NAME_LENGTH = 3              ; the initials
POS_END = NAME_LENGTH        ; CAB_POST_POS: after the initials: END or BACK
END_CHOICES = 2              ; CAB_POST_CURSOR at POS_END: 0 END, 1 BACK
ALPHABET = 46                ; cabinet_post_alphabet: the choices of a letter
FIELDS = NAME_LENGTH+1       ; the entry fields of a player in CAB_RESULT_DIGITS
RANK_FIELDS = 6              ; the rank fields of a player: the rank, two
                             ; ordinal letters, the initials
; The arcade text codes.
GLYPH_BLANK = $24
GLYPH_END = $28
GLYPH_BACK = $29             ; also in the alphabet
GLYPH_EMPTY = $37            ; an initial not entered yet
TEXT_A = $0a                 ; A (B-Z follow)
; RANK_FONT: the font of a rank field.
RANK_WHITE = 0               ; the ranking
RANK_HIGH = 1                ; the high score, red
RANK_PLAYERS = 2             ; the scores of the last game, white

; cabinet_post_begin: after the ending: clear the post state, then GAME OVER
; of the players in the game (CAB_POST_MASK) for GAME_OVER_TICKS, with the
; game over sounds. JSL.
cabinet_post_begin:
  ldx #CAB_LIVE_STATE-CAB_POST_PHASE-1
@clear:
  stz CAB_POST_PHASE,x
  dex
  bpl @clear
  lda #ENDING_POST
  sta CAB_ENDING
  lda #POST_OVER
  sta CAB_POST_PHASE
  lda #NO_LAYOUT
  sta CAB_POST_LAYOUT
  a16
  lda #GAME_OVER_TICKS
  sta CAB_POST_REMAIN
  a8
  lda #SND_GAME_OVER
  jsl game_sound_request
  lda #SND_CONTINUE_MUSIC
  jsl game_sound_request
  lda CAB_POST_MASK
  clc
  adc #LAYOUT_POST_OVER
  jsr .loword(cabinet_post_show)
  rtl

; cabinet_post_tick: one update after the ending. POST_OVER: GAME OVER
; blinks; at its end the qualified players enter their initials, or the
; title comes back. POST_ENTRY: the input of both players, until they finish
; or ENTRY_TICKS ends. POST_RANK: the new ranks flash, then the title. JSL.
cabinet_post_tick:
  lda CAB_POST_PHASE
  cmp #POST_OVER
  bne @initials
  a16
  dec CAB_POST_REMAIN
  bne @blink16
  a8
  jsr .loword(cabinet_post_qualify)
  lda CAB_POST_ACTIVE
  bne :+
  jmp .loword(@leave)
:
  lda #POST_ENTRY
  sta CAB_POST_PHASE
  stz CAB_POST_BLINK
  a16
  lda #ENTRY_TICKS
  sta CAB_POST_REMAIN
  a8
  lda #GLYPH_EMPTY              ; the empty initials, as in the arcade
  .repeat 2*NAME_LENGTH,I
    sta CAB_POST_NAMES+I
  .endrepeat
  jsr .loword(cabinet_post_fields)
  lda CAB_POST_ACTIVE
  clc
  adc #LAYOUT_POST_ENTRY
  jsr .loword(cabinet_post_show)
  rtl
@blink16:
  a8
  lda CAB_POST_BLINK
  clc
  adc #2
  cmp #OVER_BLINK
  bcc :+
  sbc #OVER_BLINK
:
  sta CAB_POST_BLINK
  cmp #OVER_BLINK_ON
  bcs @blank
  lda CAB_POST_MASK
  clc
  adc #LAYOUT_POST_OVER
  bra @show
@blank:
  lda #LAYOUT_POST_OVER
@show:
  jsr .loword(cabinet_post_show)
  rtl
@initials:
  cmp #POST_ENTRY
  bne @rank_hold
  a16
  dec CAB_POST_REMAIN
  bne @input16
  a8
  ldx #0
  jsr .loword(cabinet_post_commit)
  ldx #1
  jsr .loword(cabinet_post_commit)
  bra @start_rank
@input16:
  a8
  inc CAB_POST_BLINK            ; two updates for each 8-frame colour cycle
  ldx #0
  jsr .loword(cabinet_post_input)
  ldx #1
  jsr .loword(cabinet_post_input)
  lda CAB_POST_ACTIVE
  beq @start_rank
  jsr .loword(cabinet_post_fields)
  lda CAB_POST_ACTIVE
  clc
  adc #LAYOUT_POST_ENTRY
  jsr .loword(cabinet_post_show)
  rtl
@start_rank:
  lda #POST_RANK
  sta CAB_POST_PHASE
  stz CAB_POST_BLINK
  a16
  lda #RANK_FLASH_TICKS
  sta CAB_POST_REMAIN
  a8
  jsr .loword(cabinet_post_rank_fields)
  lda #NO_LAYOUT
  sta CAB_POST_LAYOUT
  lda CAB_POST_QUALIFIED
  clc
  adc #LAYOUT_POST_RANK
  jsr .loword(cabinet_post_show)
  rtl
@rank_hold:
  a16
  dec CAB_POST_REMAIN
  bne @rank_wait16
  a8
@leave:
  stz CAB_ENDING
  stz CAB_POST_PHASE
  lda #PAGE_TITLE
  jsl cabinet_select
  rtl
@rank_wait16:
  a8
  inc CAB_POST_BLINK
  lda CAB_POST_BLINK
  and #RANK_BLINK-1
  cmp #RANK_BLINK_ON
  bcs @rank_blank
  lda CAB_POST_QUALIFIED
  clc
  adc #LAYOUT_POST_RANK
  jsr .loword(cabinet_post_show)
  rtl
@rank_blank:
  lda #LAYOUT_POST_RANK
  jsr .loword(cabinet_post_show)
  rtl

; cabinet_post_show: show the post layout A. A new layout selects the other
; of POST_PAGE_A and POST_PAGE_B, so the cached tableau is drawn again only
; when a text or a blink changes. JSR.
cabinet_post_show:
  cmp CAB_POST_LAYOUT
  beq @done
  sta CAB_POST_LAYOUT
  pha
  lda #1
  sta CAB_POST_DIRTY
  lda GAME_FLOW
  cmp #POST_PAGE_A
  beq :+
  lda #POST_PAGE_A
  bra @select
:
  lda #POST_PAGE_B
@select:
  jsl cabinet_select
  pla
  a16
  and #255
  sec
  sbc #LAYOUT_POST_OVER
  tax
  a8
  lda f:cabinet_post_counts,x
  sta CAB_ENDING_TEXT
@done:
  rts

; cabinet_post_append: after a change, the job of the post layout in the
; packet. The last ending layout stays in the card: each job replaces only
; its own part after that layout. Carry 1: the packet has a job; X = the
; packet end. JSL; returns A16.
cabinet_post_append:
  lda CAB_POST_DIRTY
  bne :+
  a16
  ldx WORLD_OUTPUT
  clc
  rtl
:
  stz CAB_POST_DIRTY
  a16
  lda CAB_POST_LAYOUT
  and #255
  sec
  sbc #LAYOUT_POST_OVER
  asl
  sta POST_JOB                  ; the job times 2, then times POST_JOB_SIZE
  asl
  clc
  adc POST_JOB
  tax
  lda f:cabinet_post_jobs,x
  sta CAB_LENGTH
  lda f:cabinet_post_jobs+2,x
  sta POST_JOB
  lda f:cabinet_post_jobs+4,x
  sta POST_JOB+2
  ldx WORLD_OUTPUT
  ldy #0
@copy:
  lda [POST_JOB],y
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
.assert POST_JOB_SIZE = 6, error

; cabinet_post_qualify: put the score of each player in the game into the
; ranking (CAB_POST_SLOT, NO_SLOT: none). A new score goes before an equal
; score, as in the arcade. When both qualify, the later entry moves the
; first player's rank down (out of the ranking: no entry). JSR.
cabinet_post_qualify:
.a8
.i16
  stz CAB_POST_ACTIVE
  stz CAB_POST_QUALIFIED
  lda #NO_SLOT
  sta CAB_POST_SLOT
  sta CAB_POST_SLOT+1
  lda CAB_POST_MASK
  and #POST_P1
  beq @second
  ldx #0
  jsr .loword(cabinet_post_insert)
  sta CAB_POST_SLOT
  cmp #NO_SLOT
  beq @second
  lda #POST_P1
  sta CAB_POST_ACTIVE
@second:
  lda CAB_POST_MASK
  and #POST_P2
  beq @done
  ldx #PLAYER_SIZE
  jsr .loword(cabinet_post_insert)
  sta CAB_POST_SLOT+1
  cmp #NO_SLOT
  beq @done
  lda CAB_POST_SLOT
  cmp #NO_SLOT
  beq @second_active
  lda CAB_POST_SLOT+1
  cmp CAB_POST_SLOT
  bcc @shift_first
  beq @shift_first
  bra @second_active
@shift_first:
  inc CAB_POST_SLOT
  lda CAB_POST_SLOT
  cmp #RANKS
  bcc @second_active
  lda #NO_SLOT
  sta CAB_POST_SLOT
  stz CAB_POST_ACTIVE
@second_active:
  lda CAB_POST_ACTIVE
  ora #POST_P2
  sta CAB_POST_ACTIVE
@done:
  lda CAB_POST_ACTIVE
  sta CAB_POST_QUALIFIED
  rts

; cabinet_post_insert: put the score of the player X (0 or PLAYER_SIZE) into
; the ranking before the first lower or equal score, with blank initials;
; the lower ranks move down. Returns A = the rank, or NO_SLOT. JSR.
cabinet_post_insert:
  stx CAB_POST_PLAYER
  a16
  stz CAB_POST_RANK
  a8
@rank:
  ldx CAB_POST_RANK
  ldy CAB_POST_PLAYER
  lda #SCORE_DIGITS
  sta CAB_POST_TEMP
@compare:
  lda PLAYER+PL_SCORE,y
  cmp f:CAB_SCORES,x
  bcc @next
  bne @insert
  inx
  iny
  dec CAB_POST_TEMP
  bne @compare
  bra @insert
@next:
  a16
  lda CAB_POST_RANK
  clc
  adc #CAB_SCORE_ENTRY
  sta CAB_POST_RANK
  cmp #CAB_SCORES_SIZE
  a8
  bcc @rank
  lda #NO_SLOT
  rts
@insert:
  a16
  lda CAB_POST_RANK
  clc
  adc #CAB_SCORE_ENTRY
  sta POST_INSERT_END
  ldx #CAB_SCORES_SIZE-1
  cpx POST_INSERT_END
  bcc @copy16
  a8
@shift:
  lda f:CAB_SCORES-CAB_SCORE_ENTRY,x
  sta f:CAB_SCORES,x
  dex
  cpx POST_INSERT_END
  bcs @shift
  a16
@copy16:
  ldx CAB_POST_RANK
  ldy CAB_POST_PLAYER
  a8
  lda #SCORE_DIGITS
  sta CAB_POST_TEMP
@copy:
  lda PLAYER+PL_SCORE,y
  sta f:CAB_SCORES,x
  inx
  iny
  dec CAB_POST_TEMP
  bne @copy
  lda #GLYPH_BLANK              ; the initials
  sta f:CAB_SCORES,x
  inx
  sta f:CAB_SCORES,x
  inx
  sta f:CAB_SCORES,x
  a16
  lda CAB_POST_RANK
  lsr
  lsr
  lsr
  lsr                           ; / CAB_SCORE_ENTRY
  a8
  rts
.assert CAB_SCORE_ENTRY = 16 .and NAME_LENGTH = 3, error

; cabinet_post_input: the input of the player X (0 or 1) at the initials:
; right and left choose the letter (MOVE_REPEAT), fire takes it and goes to
; the next position (FIRE_REPEAT); at POS_END, fire on END finishes the
; entry and on BACK goes back. JSR.
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
  eor #INPUT_NONE               ; 1 = pressed
  sta CAB_POST_TEMP
  and #INPUT_RIGHT|INPUT_LEFT
  beq @move_up
  cmp #INPUT_RIGHT|INPUT_LEFT
  beq @move_up
  lda CAB_POST_MOVE,x
  beq @move
  dec CAB_POST_MOVE,x
  bra @fire
@move_up:
  stz CAB_POST_MOVE,x
  bra @fire
@move:
  lda #MOVE_REPEAT
  sta CAB_POST_MOVE,x
  lda CAB_POST_TEMP
  and #INPUT_RIGHT
  beq @left
  inc CAB_POST_CURSOR,x
  lda CAB_POST_POS,x
  cmp #POS_END
  bne :+
  lda CAB_POST_CURSOR,x
  cmp #END_CHOICES
  bcc @letter
  stz CAB_POST_CURSOR,x
  bra @letter
:
  lda CAB_POST_CURSOR,x
  cmp #ALPHABET
  bcc @letter
  stz CAB_POST_CURSOR,x
  bra @letter
@left:
  lda CAB_POST_CURSOR,x
  bne :+
  lda CAB_POST_POS,x
  cmp #POS_END
  beq @left_end_choice
  lda #ALPHABET
  bra @left_wrap
@left_end_choice:
  lda #END_CHOICES
@left_wrap:
  sta CAB_POST_CURSOR,x
:
  dec CAB_POST_CURSOR,x
@letter:
  jsr .loword(cabinet_post_letter)
  lda #NO_LAYOUT
  sta CAB_POST_LAYOUT
@fire:
  lda CAB_POST_TEMP
  and #INPUT_FIRE
  bne @pressed
  stz CAB_POST_FIRE,x
  rts
@pressed:
  lda CAB_POST_FIRE,x
  beq :+
  dec CAB_POST_FIRE,x
  rts
:
  lda #FIRE_REPEAT
  sta CAB_POST_FIRE,x
  lda CAB_POST_POS,x
  cmp #POS_END
  bne @advance
  lda CAB_POST_CURSOR,x
  beq @commit                   ; END
  bra @back
@advance:
  jsr .loword(cabinet_post_index)
  lda CAB_POST_NAMES,y
  cmp #GLYPH_BACK
  bne :+
  lda #GLYPH_EMPTY
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
  lda #NO_LAYOUT
  sta CAB_POST_LAYOUT
@done:
  rts
@commit:
  jsr .loword(cabinet_post_commit)
  bra @changed

; cabinet_post_letter: the alphabet choice of the player X becomes its
; initial at the position (CAB_POST_HISTORY keeps the choice). JSR.
cabinet_post_letter:
  lda CAB_POST_POS,x
  cmp #POS_END
  bcs @done
  jsr .loword(cabinet_post_index)
  lda CAB_POST_CURSOR,x
  sta CAB_POST_HISTORY,y
  phx
  a16
  and #255
  tax
  a8
  lda f:cabinet_post_alphabet,x
  sta CAB_POST_NAMES,y
  plx
@done:
  rts

; cabinet_post_index: Y = the CAB_POST_NAMES index of the position of the
; player X. JSR.
cabinet_post_index:
  lda CAB_POST_POS,x
  sta POST_CHAR_POS
  txa
  beq :+
  lda #NAME_LENGTH
:
  clc
  adc POST_CHAR_POS
  a16
  and #255
  tay
  a8
  rts

; cabinet_post_commit: the initials of the player X go into its rank (an
; empty or BACK initial as a blank); the entry of the other player goes on.
; JSR.
cabinet_post_commit:
  lda f:cabinet_post_bits,x
  and CAB_POST_ACTIVE
  beq @done
  phx
  lda CAB_POST_SLOT,x
  a16
  and #255
  asl
  asl
  asl
  asl                           ; times CAB_SCORE_ENTRY
  sta POST_SLOT_OFFSET
  txa
  and #255
  beq :+
  lda #NAME_LENGTH
:
  tay
  ldx POST_SLOT_OFFSET
  a8
  .repeat NAME_LENGTH,I
    lda CAB_POST_NAMES,y
    cmp #GLYPH_EMPTY
    beq :+
    cmp #GLYPH_BACK
    bne :++
:
    lda #GLYPH_BLANK
:
    sta f:CAB_SCORES+SCORE_DIGITS+I,x
    iny
  .endrepeat
  plx
  lda f:cabinet_post_bits,x
  eor #$ff
  and CAB_POST_ACTIVE
  sta CAB_POST_ACTIVE
@done:
  rts

; cabinet_post_fields: the FIELDS entry glyphs of each player in
; CAB_RESULT_DIGITS (the fields of the stage result): the initials, then at
; POS_END END or BACK, else a blank. JSR.
cabinet_post_fields:
  ldy #0
  ldx #0
@player:
  .repeat NAME_LENGTH,I
    lda CAB_POST_NAMES+I,x
    jsr .loword(cabinet_post_glyph)
    jsr .loword(cabinet_post_flash)
    sta CAB_RESULT_DIGITS,y
    iny
  .endrepeat
  phx
  tya
  cmp #FIELDS
  lda CAB_POST_POS
  bcc :+
  lda CAB_POST_POS+1
:
  cmp #POS_END
  beq @end_choice
  lda #GLYPH_BLANK
  bra @choice_ready
@end_choice:
  tya
  cmp #FIELDS
  lda CAB_POST_CURSOR
  bcc :+
  lda CAB_POST_CURSOR+1
:
  beq :+
  lda #GLYPH_BACK
  bra @choice_ready
:
  lda #GLYPH_END
@choice_ready:
  jsr .loword(cabinet_post_glyph)
  jsr .loword(cabinet_post_flash)
  sta CAB_RESULT_DIGITS,y
  iny
  plx
  cpy #FIELDS
  bne @done
  ldx #NAME_LENGTH
  bra @player
@done:
  rts

; cabinet_post_flash: A = the glyph A, in CAB_POST_FONT_FLASH colours when
; it is the field Y of the position of the player X (0 or NAME_LENGTH) and
; the clock is in its flash half: the arcade changes the colours of the
; selected character each four frames. JSR.
cabinet_post_flash:
  sta CAB_POST_TEMP
  lda CAB_ENDING
  cmp #ENDING_POST
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
  and #2                        ; the flash half
  beq @normal
  cpx #0
  bne @second
  lda CAB_POST_ACTIVE
  and #POST_P1
  beq @normal
  tya
  and #FIELDS-1
  cmp CAB_POST_POS
  bra @compare
@second:
  lda CAB_POST_ACTIVE
  and #POST_P2
  beq @normal
  tya
  and #FIELDS-1
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
.assert FIELDS = 4, error

; cabinet_post_rank_fields: the rank fields of the qualified players from
; the ranking: the rank, its ordinal (ST, ND, RD, TH) and the initials.
; cabinet_post_rank_one: the same for the player X (0 or 1). JSR.
cabinet_post_rank_fields:
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
  ldy #RANK_FIELDS
@write:
  sta CAB_RESULT_DIGITS,y
  iny
  lda CAB_POST_SLOT,x
  beq @first
  cmp #1
  beq @second_rank
  cmp #2
  beq @third
  lda #TEXT_A+'T'-'A'
  bra @ordinal
@first:
  lda #TEXT_A+'S'-'A'
  bra @ordinal
@second_rank:
  lda #TEXT_A+'N'-'A'
  bra @ordinal
@third:
  lda #TEXT_A+'R'-'A'
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
  lda #TEXT_A+'H'-'A'
  bra @last_ordinal
@d:
  lda #TEXT_A+'D'-'A'
  bra @last_ordinal
@t:
  lda #TEXT_A+'T'-'A'
@last_ordinal:
  jsr .loword(cabinet_post_glyph)
  sta CAB_RESULT_DIGITS,y
  iny
  phx
  txa
  beq :+
  lda #NAME_LENGTH
:
  a16
  and #255
  tax
  a8
  .repeat NAME_LENGTH,I
    lda CAB_POST_NAMES+I,x
    cmp #GLYPH_EMPTY
    beq :+
    cmp #GLYPH_BACK
    bne :++
:
    lda #GLYPH_BLANK
:
    jsr .loword(cabinet_post_glyph)
    sta CAB_RESULT_DIGITS,y
    iny
  .endrepeat
  plx
@done:
  rts

; cabinet_post_glyph: A = the glyph of the arcade text code A. JSR.
cabinet_post_glyph:
  phx
  a16
  and #255
  tax
  a8
  lda f:cabinet_post_glyphs,x
  plx
  rts

; cabinet_save_scores: CAB_ENDING_SCORES = the scores of both players, kept
; when the play records are cleared for the cabinet pages. JSL.
cabinet_save_scores:
.a8
.i16
  phx
  a16
  ldx #SCORE_DIGITS-2
@copy:
  lda PLAYER+PL_SCORE,x
  sta CAB_ENDING_SCORES,x
  lda PLAYER2+PL_SCORE,x
  sta CAB_ENDING_SCORES+SCORE_DIGITS,x
  dex
  dex
  bpl @copy
  a8
  plx
  rtl

; cabinet_rank_packet: fill the fields of the literal ranking job in the
; packet: each rank (its score and initials, RANK_WHITE), the high score
; (RANK_HIGH), then the scores of the last game (RANK_PLAYERS). The packet
; words are byte-swapped, so a byte is at its offset xor 1. JSL.
cabinet_rank_packet:
.a8
.i16
  ldx #0
  ldy #0
  stz RANK_FONT                 ; RANK_WHITE
@rank:
  jsr .loword(cabinet_rank_score)
  lda #NAME_LENGTH
  sta RANK_COUNT
@initial:
  lda f:CAB_SCORES,x
  jsr .loword(cabinet_rank_emit)
  inx
  dec RANK_COUNT
  bne @initial
  .repeat CAB_SCORE_ENTRY-SCORE_DIGITS-NAME_LENGTH
    inx
  .endrepeat
  cpx #CAB_SCORES_SIZE
  bcc @rank
  lda #RANK_HIGH                ; the high score of the first rank
  sta RANK_FONT
  ldx #0
  jsr .loword(cabinet_rank_score)
  inc RANK_FONT                 ; RANK_PLAYERS
  ldx #0
  jsr .loword(cabinet_rank_score)
  jsr .loword(cabinet_rank_score)
  rtl

; cabinet_rank_score: the SCORE_DIGITS digits at X (CAB_SCORES, or
; CAB_ENDING_SCORES for RANK_PLAYERS), the leading zeros blank except the
; last digit. JSR.
cabinet_rank_score:
  lda #1
  sta RANK_LEADING
  lda #SCORE_DIGITS
  sta RANK_COUNT
@digit:
  lda RANK_FONT
  cmp #RANK_PLAYERS
  bne @rank_value
  lda CAB_ENDING_SCORES,x
  bra @value
@rank_value:
  lda f:CAB_SCORES,x
@value:
  bne @significant
  lda RANK_LEADING
  beq @zero
  lda RANK_COUNT
  cmp #1                        ; the last digit
  beq @zero
  lda #GLYPH_BLANK
  bra @digit_ready
@zero:
  lda #0
  bra @digit_ready
@significant:
  stz RANK_LEADING
@digit_ready:
  jsr .loword(cabinet_rank_emit)
  inx
  dec RANK_COUNT
  bne @digit
  rts

; cabinet_rank_emit: the glyph of the text code A in the font RANK_FONT (a
; blank is the same in all fonts) to the rank field Y of the packet. JSR.
cabinet_rank_emit:
  phx
  a16
  and #255
  tax
  a8
  lda f:cabinet_post_glyphs,x
  sta RANK_GLYPH
  lda RANK_FONT
  beq @mapped
  lda RANK_GLYPH
  cmp #GLYPH_BLANK
  beq @mapped
  lda RANK_FONT
  cmp #RANK_HIGH
  beq @high
  lda RANK_GLYPH
  clc
  adc #CAB_POST_FONT_PLAYER
  bra @color
@high:
  lda RANK_GLYPH
  clc
  adc #CAB_POST_FONT_HIGH
@color:
  sta RANK_GLYPH
@mapped:
  a16
  tya
  clc
  adc WORLD_OUTPUT
  clc
  adc #CAB_RANK_PACKET_FIELDS
  eor #1                        ; the byte-swapped word
  tax
  a8
  lda RANK_GLYPH
  sta a:0,x
  plx
  iny
  rts

cabinet_post_bits: .byte POST_P1,POST_P2  ; the bit of each player

; cabinet_live_reset: no live initials; the ranking stays for a new game.
; JSL.
cabinet_live_reset:
.a8
.i16
  phx
  a16
  ldx #CAB_LIVE_END-CAB_LIVE_STATE-2
@clear:
  stz CAB_LIVE_STATE,x
  dex
  dex
  bpl @clear
  a8
  stz CAB_POST_ACTIVE
  stz CAB_POST_QUALIFIED
  plx
  rtl

; cabinet_live_begin: when the GAME OVER blink of a player in the play ends
; (X = 0 or PLAYER_SIZE, Y = the player number; both kept for the death
; code): a score that enters the ranking starts the live initials
; (LIVE_ENTRY, ENTRY_TICKS). A later entry can move or remove the other
; player's waiting entry. JSL.
cabinet_live_begin:
.a8
.i16
  phx
  phy
  jsr .loword(cabinet_post_insert)
  cmp #NO_SLOT
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
  tya
  eor #1
  a16
  and #255
  tax                           ; the other player
  a8
  lda CAB_LIVE_STATE,x
  beq @new_player
  lda CAB_POST_SLOT,x
  cmp CAB_LIVE_NEW_RANK
  bcc @new_player
  inc CAB_POST_SLOT,x
  lda CAB_POST_SLOT,x
  cmp #RANKS
  bcc @new_player
  stz CAB_LIVE_STATE,x
  lda f:cabinet_post_bits,x
  eor #$ff
  and CAB_POST_ACTIVE
  sta CAB_POST_ACTIVE
@new_player:
  tyx
  lda #LIVE_ENTRY
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
  a16
  and #255
  asl
  tax
  lda #ENTRY_TICKS
  sta CAB_LIVE_TIMER,x
  a8
  ldx #0
  cpy #0
  beq :+
  ldx #NAME_LENGTH
:
  ldy #NAME_LENGTH
@names:
  lda #GLYPH_EMPTY
  sta CAB_POST_NAMES,x
  stz CAB_POST_HISTORY,x
  inx
  dey
  bne @names
@done:
  ply
  plx
  rtl

; cabinet_live_tick: one game update of the live initials (also during a
; stage result): the input and the timer of each player in LIVE_ENTRY; a
; finished entry blinks its rank (LIVE_RANK, LIVE_RANK_TICKS); then the
; fields and CAB_LIVE_LAYOUT. JSL.
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
  cmp #LIVE_ENTRY
  bne @rank_clock
  inc CAB_LIVE_CLOCK,x
  bra @timer
@rank_clock:
  lda CAB_LIVE_CLOCK,x
  clc
  adc #2
  cmp #LIVE_RANK_BLINK
  bcc :+
  sbc #LIVE_RANK_BLINK
:
  sta CAB_LIVE_CLOCK,x
@timer:
  phx
  a16
  txa
  and #255
  asl
  tay
  lda CAB_LIVE_TIMER,y
  beq @expired16
  dec
  sta CAB_LIVE_TIMER,y
  beq @expired16
  a8
  plx
  lda CAB_LIVE_STATE,x
  cmp #LIVE_ENTRY
  bne @next
  jsr .loword(cabinet_post_input)
  bra @after_input
@expired16:
  a8
  plx
  lda CAB_LIVE_STATE,x
  cmp #LIVE_ENTRY
  beq :+
  stz CAB_LIVE_STATE,x
  bra @next
:
  jsr .loword(cabinet_post_commit)
@after_input:
  lda f:cabinet_post_bits,x
  and CAB_POST_ACTIVE
  bne @next
  lda #LIVE_RANK
  sta CAB_LIVE_STATE,x
  stz CAB_LIVE_CLOCK,x
  phx
  a16
  txa
  and #255
  asl
  tax
  lda #LIVE_RANK_TICKS
  sta CAB_LIVE_TIMER,x
  a8
  plx
@next:
  inx
  cpx #2                        ; two players
  bne @player
  jsr .loword(cabinet_live_fields)
  ply
  plx
  rtl

; cabinet_live_fields: CAB_LIVE_VALUES = the entry fields, or the rank
; fields of a player in LIVE_RANK; CAB_LIVE_LAYOUT = the rank of player 1
; (LIVE_SHOW in its on half) + 3 times that of player 2. The stage result
; fields in CAB_RESULT_DIGITS stay as they were. JSR.
cabinet_live_fields:
  a16
  ldx #RESULT_DIGITS_SIZE-2
@save:
  lda CAB_RESULT_DIGITS,x
  sta CAB_LIVE_SAVE,x
  dex
  dex
  bpl @save
  a8
  jsr .loword(cabinet_post_fields)
  a16
  .repeat 2,I
    lda CAB_RESULT_DIGITS+I*2
    sta CAB_LIVE_VALUES+I*2
    lda CAB_RESULT_DIGITS+FIELDS+I*2
    sta CAB_LIVE_VALUES+RANK_FIELDS+I*2
  .endrepeat
  a8
  stz CAB_POST_QUALIFIED
  lda CAB_LIVE_STATE
  cmp #LIVE_RANK
  bne :+
  inc CAB_POST_QUALIFIED
:
  lda CAB_LIVE_STATE+1
  cmp #LIVE_RANK
  bne :+
  lda CAB_POST_QUALIFIED
  ora #POST_P2
  sta CAB_POST_QUALIFIED
:
  jsr .loword(cabinet_post_rank_fields)
  lda CAB_POST_QUALIFIED
  and #POST_P1
  beq @second_rank
  a16
  .repeat RANK_FIELDS/2,I
    lda CAB_RESULT_DIGITS+I*2
    sta CAB_LIVE_VALUES+I*2
  .endrepeat
  a8
@second_rank:
  lda CAB_POST_QUALIFIED
  and #POST_P2
  beq @restore
  a16
  .repeat RANK_FIELDS/2,I
    lda CAB_RESULT_DIGITS+RANK_FIELDS+I*2
    sta CAB_LIVE_VALUES+RANK_FIELDS+I*2
  .endrepeat
  a8
@restore:
  a16
  ldx #RESULT_DIGITS_SIZE-2
@restore_word:
  lda CAB_LIVE_SAVE,x
  sta CAB_RESULT_DIGITS,x
  dex
  dex
  bpl @restore_word
  a8
  lda CAB_LIVE_STATE
  cmp #LIVE_RANK
  bne @first_visible
  lda CAB_LIVE_CLOCK
  cmp #LIVE_RANK_ON
  bcc :+
  lda #0
  bra @first_visible
:
  lda #LIVE_SHOW
@first_visible:
  sta CAB_LIVE_LAYOUT
  lda CAB_LIVE_STATE+1
  cmp #LIVE_RANK
  bne @second_visible
  lda CAB_LIVE_CLOCK+1
  cmp #LIVE_RANK_ON
  bcc :+
  lda #0
  bra @second_visible
:
  lda #LIVE_SHOW
@second_visible:
  sta CAB_LIVE_NEW_RANK
  asl
  clc
  adc CAB_LIVE_NEW_RANK
  clc
  adc CAB_LIVE_LAYOUT
  sta CAB_LIVE_LAYOUT
  rts
.assert LIVE_ENTRY = 1 .and LIVE_RANK = 2 .and RANK_FIELDS = 6, error
