; The music player: one tick of the native score (MUSIC_SCORE) for each
; sound interrupt. scripts/music_score.py and fm_native.py make the score:
; the arcade decoding, the pitches, the captures and the repeats are done in
; the build. A song plays in the MUSIC_STATES slot of its priority; the
; highest slot with a song plays, the lower slots wait. Each slot has six
; parts. The FM voices (fm_voice.s) sound the notes. Called with
; D = MUSIC_PAGE, DBR = 0, A8, X16.
.a8
.i16
; The music part record (MUSIC_STATES, src/game_ram.s)
MS_BASE = 0                  ; 2 bytes: the part start in MUSIC_SCORE; loop jumps add to it
MS_PC = 2                    ; 2 bytes: the next event in MUSIC_SCORE
MS_WAIT = 4                  ; 2 bytes: ticks to the next event
MS_REPEAT = 6                ; 2 bytes: the event after the running repeat; MUSIC_NONE none
MS_REPEAT_LEFT = 8           ; repetitions left
MS_ACTIVE = 9                ; nonzero while the part plays; in the first part, the slot
MS_EVENT = 10                ; the token of the next event (SCORE_*)
MS_CAPTURE = 11              ; the capture of the note
MS_FREQUENCY = 12            ; 2 bytes: the DOC frequency word
MS_NEXT_CAPTURE = 14         ; the next different capture of this part
MS_SOUNDING = 15             ; nonzero while the note sounds
MS_TIE = 19                  ; SCORE_TIE: the note keeps the envelope of the note before
MS_SONG = 22                 ; 2 bytes, first part of a slot: the song/phase entry (FM_SONG)
MS_RESUME = 24               ; first part of a slot: FM_CACHE_RESUME of the slot
MS_PREFETCH = 25             ; the next capture of the last untied note; $ff none
; A score token: SCORE_* in bits 5-7, the delay in bits 0-4 (SCORE_DELAY_LONG:
; the delay is in the next word). A note body (fm_native.py):
NOTE_CAPTURE = 0             ; the capture, SCORE_TIE in bit 7
NOTE_FREQUENCY = 1           ; 2 bytes: the DOC frequency word
NOTE_NEXT = 3                ; the next different capture of the part
NOTE_SIZE = 4                ; also a music_note_dictionary entry
SCORE_KIND = $e0
SCORE_TIE = $80
PREFETCH_NONE = $ff

; music_player_init: no song: all slots and the music state are cleared.
; JSL.
music_player_init:
  a16
  stz MUSIC_TICK
  lda #MUSIC_NONE
  sta MUSIC_SELECTED
  lda #0
  ldx #MUSIC_SLOTS*MUSIC_SLOT_SIZE-2
@clear:
  sta f:MUSIC_STATES,x
  dex
  dex
  bpl @clear
  lda #MUSIC_NONE
  sta MUSIC_NEXT
  stz MUSIC_FAST
  lda #.loword(MUSIC_SCORE)
  sta MUSIC_POOL_PTR
  a8
  lda #^MUSIC_SCORE
  sta MUSIC_POOL_PTR+2
  stz MUSIC_PENDING
  rtl

; music_player_tick: one music tick (the sound interrupt). It starts the
; MUSIC_PENDING command, moves the FM tick, and plays the due events of the
; selected slot. While no event is due (MUSIC_NEXT of 2 or more) it only
; counts: MUSIC_FAST holds the ticks that the part waits did not get yet.
; JSL.
music_player_tick:
  a16
  inc MUSIC_TICK
  a8
  lda f:START_MUSIC_FLAGS
  and #SMF_PRELOAD
  beq :+
  jsl music_title_preload
:
  lda MUSIC_PENDING
  beq @select
  stz MUSIC_PENDING
  cmp #MUSIC_STOP
  bne :+
  jsl music_all_off
  jsl music_player_init
  rtl
:
  ; The start music after SND_SMOOTH_STOP: the old notes stop only now.
  pha
  cmp #SND_START_MUSIC
  bne @start_ordinary
  lda f:START_MUSIC_FLAGS
  and #SMF_SMOOTH
  beq @start_ordinary
  lda f:START_MUSIC_FLAGS
  and #<~SMF_SMOOTH
  sta f:START_MUSIC_FLAGS
  jsl music_all_off
  jsl music_player_init
@start_ordinary:
  jsr .loword(music_catch_up)   ; music_start may replace the running slot
  pla
  jsr .loword(music_start)
  a16
  stz MUSIC_NEXT                ; find the slot again
  a8
@select:
  ; The FM tick. Most ticks have no song wait: move FM_TICK here, without
  ; the far call to fm_song_wait, which does the same and the song starts.
  lda f:FM_WAIT
  bne @song_wait
  lda f:FM_PHASE_WAIT
  cmp #PHASE_ARM
  beq @song_wait
  lda f:FM_TICK
  inc
  sta f:FM_TICK
  bra :+
@song_wait:
  jsl fm_song_wait
  bcc :+
  rtl                           ; the first captures are not loaded yet
:
  ; No event due: only the count moves.
  a16
  lda MUSIC_NEXT
  cmp #2
  bcc @full
  dec
  sta MUSIC_NEXT
  inc MUSIC_FAST
  a8
  rtl
@full:
  ; The highest slot with a song plays.
  a8
  ldx #(MUSIC_SLOTS-1)*MUSIC_SLOT_SIZE
@priority:
  lda f:MUSIC_STATES+MS_ACTIVE,x
  bne @found
  a16
  txa
  sec
  sbc #MUSIC_SLOT_SIZE
  tax
  a8
  bpl @priority
  ; No song: the voices stop.
  jsr .loword(music_catch_up)
  jsl music_all_off
  a16
  lda #MUSIC_NONE
  sta MUSIC_SELECTED
  sta MUSIC_NEXT
  a8
  rtl
@found:
  stx MUSIC_SLOT
  cpx MUSIC_SELECTED
  bne :+
  jmp .loword(music_step_selected)
:
  ; A different slot plays now.
  jsr .loword(music_catch_up)   ; the previous selection keeps its delays
  ldx MUSIC_SLOT
  stx MUSIC_SELECTED
  jsl music_all_off
  ; Start the FM captures of the slot's song. A resumed slot must have its
  ; earlier captures loaded before its score continues.
  ldx MUSIC_SLOT
  a16
  lda f:MUSIC_STATES+MS_SONG,x
  sta z:FM_SONG
  a8
  lda f:MUSIC_STATES+MS_RESUME,x
  sta f:FM_CACHE_RESUME
  lda #1
  sta f:MUSIC_STATES+MS_RESUME,x
  jsl fm_song_start
  jsl fm_song_wait
  bcc :+
  rtl
:
  ; The notes that sounded when the slot stopped sound again.
  ldx MUSIC_SLOT
@resume:
  lda f:MUSIC_STATES+MS_SOUNDING,x
  beq :+
  phx
  jsl music_voice_resume
  plx
:
  a16
  txa
  clc
  adc #MUSIC_PART_SIZE
  tax
  sec
  sbc MUSIC_SLOT
  cmp #MUSIC_SLOT_SIZE
  a8
  bne @resume
@parts:
  ; Each active part counts down its wait; at 0 its events play.
  ldx MUSIC_SLOT
@part:
  stx MUSIC_PART
  lda f:MUSIC_STATES+MS_ACTIVE,x
  beq @next
  a16
  lda f:MUSIC_STATES+MS_WAIT,x
  beq @due
  dec
  sta f:MUSIC_STATES+MS_WAIT,x
  bne @next16
@due:
  a8
  jsr .loword(music_event)
@next:
  a16
@next16:
  ldx MUSIC_PART
  txa
  clc
  adc #MUSIC_PART_SIZE
  tax
  sec
  sbc MUSIC_SLOT
  cmp #MUSIC_SLOT_SIZE
  a8
  bne @part
  jmp .loword(music_next)

; music_step_selected: the selected slot again: catch up MUSIC_FAST ticks,
; step each part (its events when due) and find the next event in one pass;
; the same results as music_catch_up, the part loop and music_next in turn.
; X = MUSIC_SLOT.
music_step_selected:
.a8
  a16
  lda #MUSIC_NONE
  sta MUSIC_NEXT
  a8
@part:
  stx MUSIC_PART
  lda f:MUSIC_STATES+MS_ACTIVE,x
  beq @next
  a16
  lda f:MUSIC_STATES+MS_WAIT,x
  sec
  sbc MUSIC_FAST
  beq @zero
  dec
  sta f:MUSIC_STATES+MS_WAIT,x
  bne @wait
  bra @due
@zero:
  sta f:MUSIC_STATES+MS_WAIT,x
@due:
  a8
  jsr .loword(music_event)
  ldx MUSIC_PART
  lda f:MUSIC_STATES+MS_ACTIVE,x
  beq @next
  a16
  lda f:MUSIC_STATES+MS_WAIT,x
@wait:
  cmp MUSIC_NEXT
  bcs @next16
  sta MUSIC_NEXT
  bra @next16
@next:
  a16
@next16:
  ldx MUSIC_PART
  txa
  clc
  adc #MUSIC_PART_SIZE
  tax
  sec
  sbc MUSIC_SLOT
  cmp #MUSIC_SLOT_SIZE
  a8
  bne @part
  a16
  stz MUSIC_FAST
  a8
  ; The end of the slot's first part can change the selection: find the
  ; slot again at the next tick.
  ldx MUSIC_SLOT
  lda f:MUSIC_STATES+MS_ACTIVE,x
  bne :+
  a16
  lda #1
  sta MUSIC_NEXT
  a8
:
  rtl

; music_catch_up: the active parts of the selected slot count down the
; MUSIC_FAST ticks; then MUSIC_FAST = 0. JSR.
music_catch_up:
  a16
  lda MUSIC_FAST
  beq @done
  ldx MUSIC_SELECTED
  bmi @clear                    ; MUSIC_NONE
@part:
  a8
  lda f:MUSIC_STATES+MS_ACTIVE,x
  a16
  beq @next
  lda f:MUSIC_STATES+MS_WAIT,x
  sec
  sbc MUSIC_FAST
  sta f:MUSIC_STATES+MS_WAIT,x
@next:
  txa
  clc
  adc #MUSIC_PART_SIZE
  tax
  sec
  sbc MUSIC_SELECTED
  cmp #MUSIC_SLOT_SIZE
  bne @part
@clear:
  stz MUSIC_FAST
@done:
  a8
  rts

; music_next: MUSIC_NEXT = the earliest part wait of the slot MUSIC_SLOT.
; The end of the slot's first part can change the selection: then
; MUSIC_NEXT = 1, and the next tick finds the slot again. JSL end.
music_next:
  a16
  lda #MUSIC_NONE
  sta MUSIC_NEXT
  ldx MUSIC_SLOT
  a8
  lda f:MUSIC_STATES+MS_ACTIVE,x
  bne @part
  a16
  lda #1
  sta MUSIC_NEXT
  a8
  rtl
@part:
  lda f:MUSIC_STATES+MS_ACTIVE,x
  beq @next
  a16
  lda f:MUSIC_STATES+MS_WAIT,x
  cmp MUSIC_NEXT
  bcs @next16
  sta MUSIC_NEXT
  bra @next16
@next:
  a16
@next16:
  txa
  clc
  adc #MUSIC_PART_SIZE
  tax
  sec
  sbc MUSIC_SLOT
  cmp #MUSIC_SLOT_SIZE
  a8
  bne @part
  rtl

; music_start: start the song of the FM command A (SND_FM_FIRST up to
; MUSIC_SONGS songs; other commands do nothing) in the slot of its priority.
; Each song has two phases, as the two arcade interrupt phases: the tick
; parity picks one. The parts start at their first event. JSR.
music_start:
  a16
  and #255
  sec
  sbc #SND_FM_FIRST
  cmp #MUSIC_SONGS
  bcc :+
  a8
  rts
:
  sta MUSIC_TEMP                ; the song
  tax
  a8
  lda f:music_priority,x
  a16
  and #255
  tax
  lda f:music_slot_offsets,x
  sta MUSIC_SLOT
  lda MUSIC_TICK
  and #1
  asl
  sta MUSIC_PART                ; the phase entry: 0 or 2
  lda MUSIC_TEMP
  asl
  asl                           ; two phase entries of 2 bytes
  clc
  adc MUSIC_PART
  sta z:FM_SONG                 ; the song/phase entry
  tax
  lda f:music_entries,x
  sta MUSIC_TEMP                ; the phase's part offsets
  ldx MUSIC_SLOT
  lda z:FM_SONG
  sta f:MUSIC_STATES+MS_SONG,x
  lda #0
  sta f:MUSIC_STATES+MS_RESUME,x
  lda MUSIC_SLOT
  cmp MUSIC_SELECTED
  bne :+
  lda #MUSIC_NONE               ; the new song of the playing slot starts its captures
  sta MUSIC_SELECTED
:
@part:
  phx
  ldx MUSIC_TEMP
  lda f:music_part_offsets,x
  plx
  sta f:MUSIC_STATES+MS_BASE,x
  sta f:MUSIC_STATES+MS_PC,x
  inc MUSIC_TEMP
  inc MUSIC_TEMP
  lda #0
  sta f:MUSIC_STATES+MS_REPEAT,x
  sta f:MUSIC_STATES+MS_REPEAT_LEFT,x    ; and MS_ACTIVE
  sta f:MUSIC_STATES+MS_NEXT_CAPTURE,x   ; and MS_SOUNDING
  a8
  lda #PREFETCH_NONE
  sta f:MUSIC_STATES+MS_PREFETCH,x
  lda #1
  sta f:MUSIC_STATES+MS_ACTIVE,x
  jsr .loword(music_prime)
  a16
  lda f:MUSIC_STATES+MS_WAIT,x
  inc                           ; the part loop of this tick counts one
  sta f:MUSIC_STATES+MS_WAIT,x
  txa
  clc
  adc #MUSIC_PART_SIZE
  tax
  sec
  sbc MUSIC_SLOT
  cmp #MUSIC_SLOT_SIZE
  bne @part
  a8
  rts
.assert MS_ACTIVE = MS_REPEAT_LEFT+1 .and MS_SOUNDING = MS_NEXT_CAPTURE+1, error

.segment "SOUND_EXTRA"
; music_title_preload: load the captures of the title music (SMF_PRELOAD)
; when the sound is idle: a cabinet page shows, no command waits, no song
; plays and no FM upload runs. It runs in the sound interrupt, so it cannot
; collide with the FM requests. JSL.
music_title_preload:
.a8
  lda f:START_MUSIC_FLAGS
  and #SMF_PRELOAD
  beq @done
  lda CAB_START_PENDING
  bne @done
  lda GAME_FLOW
  cmp #CAB_PAGE_FIRST
  bcc @done
  lda MUSIC_PENDING
  bne @done
  lda SOUND_READ
  cmp SOUND_WRITE
  bne @done
  a16
  lda MUSIC_SELECTED
  cmp #MUSIC_NONE
  a8
  bne @done
  lda f:FM_UP_ACTIVE
  bne @done
  lda #0
  sta f:FM_CACHE_RESUME         ; a new capture plan
  lda f:START_MUSIC_FLAGS
  and #<~SMF_PRELOAD
  sta f:START_MUSIC_FLAGS
  a16
  stz z:FM_SONG                 ; the start music; both phases use the same captures
  a8
  jsl fm_song_start
@done:
  rtl
.segment "SOUND"

; music_prime: read the token at MS_PC of the part X: MS_EVENT = its kind,
; MS_WAIT = its delay; MS_PC = its body. JSR.
music_prime:
  a16
  lda f:MUSIC_STATES+MS_PC,x
  tay
  a8
  lda [MUSIC_POOL_PTR],y
  pha
  and #SCORE_KIND
  sta f:MUSIC_STATES+MS_EVENT,x
  pla
  and #SCORE_DELAY_LONG
  iny
  cmp #SCORE_DELAY_LONG
  beq @long
  a16
  and #255
  bra @delay
@long:
  a16
  lda [MUSIC_POOL_PTR],y
  iny
  iny
@delay:
  sta f:MUSIC_STATES+MS_WAIT,x
  tya
  sta f:MUSIC_STATES+MS_PC,x
  a8
  rts

; music_event: play the event MS_EVENT of the part X (its body at MS_PC),
; then read the next token; continue while the next delay is 0. JSR.
music_event:
  a16
  lda f:MUSIC_STATES+MS_PC,x
  tay
  a8
  lda f:MUSIC_STATES+MS_EVENT,x
  bne :+
  jmp .loword(@note)            ; SCORE_NOTE
:
  cmp #SCORE_SHARED
  bne :+
  jmp .loword(@shared_note)
:
  cmp #SCORE_OFF
  bne :+
  jmp .loword(@off)
:
  cmp #SCORE_LOOP
  bne :+
  jmp .loword(@loop)
:
  ; SCORE_END: the part stops.
  lda #0
  sta f:MUSIC_STATES+MS_ACTIVE,x
  rts
@note:
  ; A note: its body follows the token.
  lda [MUSIC_POOL_PTR],y
  pha
  and #<~SCORE_TIE
  sta f:MUSIC_STATES+MS_CAPTURE,x
  pla
  and #SCORE_TIE
  sta f:MUSIC_STATES+MS_TIE,x
  iny
  a16
  lda [MUSIC_POOL_PTR],y
  sta f:MUSIC_STATES+MS_FREQUENCY,x
  iny
  iny
  a8
  lda [MUSIC_POOL_PTR],y
  sta f:MUSIC_STATES+MS_NEXT_CAPTURE,x
  iny
@note_ready:
  lda f:MUSIC_STATES+MS_TIE,x
  bne :+                        ; a tied note keeps the prefetch of the note before
  lda f:MUSIC_STATES+MS_NEXT_CAPTURE,x
  sta f:MUSIC_STATES+MS_PREFETCH,x
:
  lda #1
  sta f:MUSIC_STATES+MS_SOUNDING,x
  phy
  phx
  jsl music_voice_on
  plx
  ply
  jmp .loword(@advance)
@shared_note:
  ; A shared note: the body is the music_note_dictionary entry of the byte.
  ; NOTE_ENTRY is FM work space; music_voice_on has not started yet.
  lda [MUSIC_POOL_PTR],y
  iny
  phy
  phx
  a16
  and #255
  asl
  asl                           ; times NOTE_SIZE
  tax
  lda f:music_note_dictionary,x
  sta NOTE_ENTRY
  lda f:music_note_dictionary+2,x
  sta NOTE_ENTRY+2
  plx
  ply
  a8
  lda NOTE_ENTRY+NOTE_CAPTURE
  and #<~SCORE_TIE
  sta f:MUSIC_STATES+MS_CAPTURE,x
  lda NOTE_ENTRY+NOTE_CAPTURE
  and #SCORE_TIE
  sta f:MUSIC_STATES+MS_TIE,x
  a16
  lda NOTE_ENTRY+NOTE_FREQUENCY
  sta f:MUSIC_STATES+MS_FREQUENCY,x
  a8
  lda NOTE_ENTRY+NOTE_NEXT
  sta f:MUSIC_STATES+MS_NEXT_CAPTURE,x
  bra @note_ready
@off:
  lda #0
  sta f:MUSIC_STATES+MS_SOUNDING,x
  phy
  phx
  jsl music_voice_off
  plx
  ply
  bra @advance
@loop:
  ; A loop: the repetitions (0: always), then the target from MS_BASE.
  ; Y after the count byte tells this loop from others (MS_REPEAT).
  lda [MUSIC_POOL_PTR],y
  iny
  beq @jump
  sta MUSIC_TEMP
  a16
  tya
  cmp f:MUSIC_STATES+MS_REPEAT,x
  a8
  beq @repeat
  a16
  tya
  sta f:MUSIC_STATES+MS_REPEAT,x
  a8
  lda MUSIC_TEMP
  bra @decrement
@repeat:
  lda f:MUSIC_STATES+MS_REPEAT_LEFT,x
  beq @finished_loop
@decrement:
  dec
  sta f:MUSIC_STATES+MS_REPEAT_LEFT,x
@jump:
  a16
  lda [MUSIC_POOL_PTR],y
  clc
  adc f:MUSIC_STATES+MS_BASE,x
  tay
  a8
  bra @advance
@finished_loop:
  a16
  lda #MUSIC_NONE
  sta f:MUSIC_STATES+MS_REPEAT,x
  a8
  iny
  iny                           ; past the target
@advance:
  a16
  tya
  sta f:MUSIC_STATES+MS_PC,x
  a8
  jsr .loword(music_prime)
  a16
  lda f:MUSIC_STATES+MS_WAIT,x
  a8
  bne @return
  jmp .loword(music_event)
@return:
  rts
.assert SCORE_NOTE = 0 .and SCORE_KIND = SCORE_SHARED .and NOTE_SIZE = 4, error
.assert SCORE_DELAY_LONG = <~SCORE_KIND, error
