; Final compact-score player. All arcade decoding, pitch conversion, sample
; selection and repeat discovery happen in scripts/music_score.py.
; Called with D=$1E00, DBR=0, A8/X16. No source ROM, disk, or pitch arithmetic.
.a8
.i16
.macro fm_mark value
.ifdef FM_DEBUG
  pha
  lda #value
  sta f:$050509
  pla
.endif
.endmacro
MUSIC_STATES = $018000
MUSIC_SELECTED = $1e80
MUSIC_TICK = $1e82
MUSIC_SLOT = $1e8a
MUSIC_PENDING = $1e8c
MUSIC_PART = $1e8e
MUSIC_TEMP = $1e84
MUSIC_NEXT = $1e86             ; ticks to the earliest event of the selected slot; 0 = rescan
MUSIC_FAST = $1e88             ; ticks the selected slot ran since its part delays were updated
MUSIC_POOL_PTR = $e8
; Per part (32 bytes): base, PC, wait, repeat-PC, repeat-count, active,
; opcode, sample, DOC frequency, volume, sounding; remaining bytes for envelopes.

music_player_init:
  rep #$20
  stz MUSIC_TICK
  lda #$ffff
  sta MUSIC_SELECTED
  lda #0
  ldx #766
@clear:
  sta f:MUSIC_STATES,x
  dex
  dex
  bpl @clear
  lda #$ffff
  sta MUSIC_NEXT
  stz MUSIC_FAST
  lda #.loword(MUSIC_SCORE)
  sta MUSIC_POOL_PTR
  sep #$20
  lda #^MUSIC_SCORE
  sta MUSIC_POOL_PTR+2
  stz MUSIC_PENDING
  rtl

music_player_tick:
  rep #$20
  inc MUSIC_TICK
  sep #$20
.ifdef CONTINUOUS_GAME
  lda f:START_MUSIC_FLAGS
  and #$20
  beq :+
  jsl music_title_preload
:
.endif
  lda MUSIC_PENDING
  beq @select
  stz MUSIC_PENDING
  cmp #$ff
  bne :+
  jsl music_all_off
  jsl music_player_init
  rtl
:
  pha
.ifdef CONTINUOUS_GAME
  cmp #$20
  bne @start_ordinary
  lda f:START_MUSIC_FLAGS
  and #$40
  beq @start_ordinary
  lda f:START_MUSIC_FLAGS
  and #$bf
  sta f:START_MUSIC_FLAGS
  jsl music_all_off
  jsl music_player_init
@start_ordinary:
.endif
  jsr .loword(music_catch_up)   ; music_start may replace the running slot
  pla
  jsr .loword(music_start)
  rep #$20
  stz MUSIC_NEXT
  sep #$20
@select:
.ifdef AUDIO_FM
  ; Most ticks have no table wait. Advance the same banked counter without
  ; switching DBR and making a far call; the slow path handles song starts.
  lda f:FM_WAIT|$010000
  bne @song_wait
  lda f:FM_PHASE_WAIT|$010000
  cmp #1
  beq @song_wait
  lda f:FM_TICK|$010000
  inc
  sta f:FM_TICK|$010000
  bra :+
@song_wait:
  jsl fm_song_wait
  bcc :+
  rtl
:
  fm_mark 20
.endif
  ; no part event due and no song change: only the countdown moves
  rep #$20
  lda MUSIC_NEXT
  cmp #2
  bcc @full
  dec
  sta MUSIC_NEXT
  inc MUSIC_FAST
  sep #$20
  rtl
@full:
  sep #$20
  ldx #576
@priority:
  lda f:MUSIC_STATES+9,x
  bne @found
  rep #$20
  txa
  sec
  sbc #192
  tax
  sep #$20
  bpl @priority
  jsr .loword(music_catch_up)
  jsl music_all_off
  rep #$20
  lda #$ffff
  sta MUSIC_SELECTED
  sta MUSIC_NEXT
  sep #$20
  rtl
@found:
  stx MUSIC_SLOT
  cpx MUSIC_SELECTED
  bne :+
  jmp .loword(music_step_selected)
:
  jsr .loword(music_catch_up)   ; the previous selection keeps its delays
  ldx MUSIC_SLOT
  stx MUSIC_SELECTED
  jsl music_all_off
.ifdef AUDIO_FM
  fm_mark 21
.endif
.ifdef AUDIO_FM
  ; Activate the cache for the selected priority slot. A resumed slot
  ; must have its earlier captures available before its score advances.
  ldx MUSIC_SLOT
  rep #$20
  lda f:MUSIC_STATES+22,x
  sta z:FM_SONG
  sep #$20
  lda f:MUSIC_STATES+24,x
  sta f:$018788
  lda #1
  sta f:MUSIC_STATES+24,x
  jsl fm_song_start
  jsl fm_song_wait
  bcc :+
  rtl
:
.endif
  ; A suspended score resumes from cached native note/envelope state.
  ldx MUSIC_SLOT
@resume:
  lda f:MUSIC_STATES+15,x
  beq :+
  phx
  jsl music_voice_resume
  plx
:
  rep #$20
  txa
  clc
  adc #32
  tax
  sec
  sbc MUSIC_SLOT
  cmp #192
  sep #$20
  bne @resume
@parts:
  ldx MUSIC_SLOT
@part:
  stx MUSIC_PART
  lda f:MUSIC_STATES+9,x
  beq @next
  rep #$20
  lda f:MUSIC_STATES+4,x
  beq @due
  dec
  sta f:MUSIC_STATES+4,x
  bne @next16
@due:
  sep #$20
  jsr .loword(music_event)
@next:
  rep #$20
@next16:
  ldx MUSIC_PART
  txa
  clc
  adc #32
  tax
  sec
  sbc MUSIC_SLOT
  cmp #192
  sep #$20
  bne @part
  jmp .loword(music_next)

; The selected slot again: catch up MUSIC_FAST ticks, step each part (its
; events when due) and find the next event in one pass; the same results as
; music_catch_up, the part loop and music_next in turn. X = MUSIC_SLOT.
music_step_selected:
.a8
  rep #$20
  lda #$ffff
  sta MUSIC_NEXT
  sep #$20
@part:
  stx MUSIC_PART
  lda f:MUSIC_STATES+9,x
  beq @next
  rep #$20
  lda f:MUSIC_STATES+4,x
  sec
  sbc MUSIC_FAST
  beq @zero
  dec
  sta f:MUSIC_STATES+4,x
  bne @wait
  bra @due
@zero:
  sta f:MUSIC_STATES+4,x
@due:
  sep #$20
  jsr .loword(music_event)
  ldx MUSIC_PART
  lda f:MUSIC_STATES+9,x
  beq @next
  rep #$20
  lda f:MUSIC_STATES+4,x
@wait:
  cmp MUSIC_NEXT
  bcs @next16
  sta MUSIC_NEXT
  bra @next16
@next:
  rep #$20
@next16:
  ldx MUSIC_PART
  txa
  clc
  adc #32
  tax
  sec
  sbc MUSIC_SLOT
  cmp #192
  sep #$20
  bne @part
  rep #$20
  stz MUSIC_FAST
  sep #$20
  ; the slot's first part ending can change the selection: rescan next tick
  ldx MUSIC_SLOT
  lda f:MUSIC_STATES+9,x
  bne :+
  rep #$20
  lda #1
  sta MUSIC_NEXT
  sep #$20
:
  rtl

; The selected slot's parts count down MUSIC_FAST more ticks.
music_catch_up:
  rep #$20
  lda MUSIC_FAST
  beq @done
  ldx MUSIC_SELECTED
  bmi @clear
@part:
  sep #$20
  lda f:MUSIC_STATES+9,x
  rep #$20
  beq @next
  lda f:MUSIC_STATES+4,x
  sec
  sbc MUSIC_FAST
  sta f:MUSIC_STATES+4,x
@next:
  txa
  clc
  adc #32
  tax
  sec
  sbc MUSIC_SELECTED
  cmp #192
  bne @part
@clear:
  stz MUSIC_FAST
@done:
  sep #$20
  rts

; MUSIC_NEXT = the selected slot's earliest part delay. The slot's first
; part ending can change the selection, so the next tick rescans then.
music_next:
  rep #$20
  lda #$ffff
  sta MUSIC_NEXT
  ldx MUSIC_SLOT
  sep #$20
  lda f:MUSIC_STATES+9,x
  bne @part
  rep #$20
  lda #1
  sta MUSIC_NEXT
  sep #$20
  rtl
@part:
  lda f:MUSIC_STATES+9,x
  beq @next
  rep #$20
  lda f:MUSIC_STATES+4,x
  cmp MUSIC_NEXT
  bcs @next16
  sta MUSIC_NEXT
  bra @next16
@next:
  rep #$20
@next16:
  txa
  clc
  adc #32
  tax
  sec
  sbc MUSIC_SLOT
  cmp #192
  sep #$20
  bne @part
  rtl

music_start:
  rep #$20
  and #255
  sec
  sbc #$20
  cmp #19
  bcc :+
  sep #$20
  rts
:
  sta MUSIC_TEMP                ; song index
  tax
  sep #$20
  lda f:music_priority,x
  rep #$20
  and #255
  tax
  lda f:music_slot_offsets,x
  sta MUSIC_SLOT
  lda MUSIC_TICK
  and #1
  asl
  sta MUSIC_PART
  lda MUSIC_TEMP
  asl
  asl
  clc
  adc MUSIC_PART                ; song/phase entry
.ifdef AUDIO_FM
  sta z:FM_SONG
.endif
  tax
  lda f:music_entries,x
  sta MUSIC_TEMP                ; this phase's part offsets
  ldx MUSIC_SLOT
.ifdef AUDIO_FM
  lda z:FM_SONG
  sta f:MUSIC_STATES+22,x
  lda #0
  sta f:MUSIC_STATES+24,x
  lda MUSIC_SLOT
  cmp MUSIC_SELECTED
  bne :+
  lda #$ffff
  sta MUSIC_SELECTED
:
.endif
@part:
  phx
  ldx MUSIC_TEMP
  lda f:music_part_offsets,x
  plx
  sta f:MUSIC_STATES,x
  sta f:MUSIC_STATES+2,x
  inc MUSIC_TEMP
  inc MUSIC_TEMP
  lda #0
  sta f:MUSIC_STATES+6,x
  sta f:MUSIC_STATES+8,x
  sta f:MUSIC_STATES+14,x
  sta f:MUSIC_STATES+16,x
  sep #$20
.ifdef AUDIO_FM
  lda #$ff
  sta f:MUSIC_STATES+25,x       ; no prefetch recorded for this part yet
.endif
  lda #1
  sta f:MUSIC_STATES+9,x
  jsr .loword(music_prime)
  rep #$20
  lda f:MUSIC_STATES+4,x
  inc
  sta f:MUSIC_STATES+4,x
  txa
  clc
  adc #32
  tax
  sec
  sbc MUSIC_SLOT
  cmp #192
  bne @part
  sep #$20
  rts

.ifdef CONTINUOUS_GAME
.segment "SOUND_EXTRA"
; Run only after the title's stop command and all prior FM uploads complete.
; This is an IRQ-side producer, so it cannot race the FM request ring.
music_title_preload:
.a8
  lda f:START_MUSIC_FLAGS
  and #$20
  beq @done
  lda CAB_START_PENDING
  bne @done
  lda GAME_FLOW
  cmp #3
  bcc @done
  lda MUSIC_PENDING
  bne @done
  lda STAGE_SOUND_READ
  cmp STAGE_SOUND_WRITE
  bne @done
  rep #$20
  lda MUSIC_SELECTED
  cmp #$ffff
  sep #$20
  bne @done
  lda f:$0187c4                ; FM_UP_ACTIVE
  bne @done
  ; A stopped score can be superseded when no main-loop upload is active.
  lda #0
  sta f:$018788                ; FM_CACHE_RESUME: prepare a fresh plan
  lda f:START_MUSIC_FLAGS
  and #$df
  sta f:START_MUSIC_FLAGS
  rep #$20
  stz z:FM_SONG                ; both opening phases use the same captures
  sep #$20
  jsl fm_song_start
@done:
  rtl
.segment "SOUND"
.endif

music_prime:
  rep #$20
  lda f:MUSIC_STATES+2,x
  tay
  sep #$20
  lda [MUSIC_POOL_PTR],y
  pha
  and #$e0
  sta f:MUSIC_STATES+10,x
  pla
  and #31
  iny
  cmp #31
  beq @long
  rep #$20
  and #255
  bra @delay
@long:
  rep #$20
  lda [MUSIC_POOL_PTR],y
  iny
  iny
@delay:
  sta f:MUSIC_STATES+4,x
  tya
  sta f:MUSIC_STATES+2,x
  sep #$20
  rts

music_event:
.ifdef AUDIO_FM
  fm_mark 22
.endif
  rep #$20
  lda f:MUSIC_STATES+2,x
  tay
  sep #$20
  lda f:MUSIC_STATES+10,x
  bne :+
  jmp .loword(@note)
:
.ifdef AUDIO_FM
  cmp #$e0
  bne :+
  jmp .loword(@shared_note)
:
.endif
  cmp #$20
  bne :+
  jmp .loword(@off)
:
  cmp #$40
  bne :+
  jmp .loword(@loop)
:
  cmp #$80
  beq @frequency
  cmp #$a0
  beq @volume
  cmp #$c0
  beq @table
  lda #0
  sta f:MUSIC_STATES+9,x
  rts
@frequency:
  rep #$20
  lda [MUSIC_POOL_PTR],y
  sta f:MUSIC_STATES+12,x
  iny
  iny
  sep #$20
  phy
  phx
  jsl music_voice_frequency
  plx
  ply
  jmp .loword(@advance)
@volume:
  lda [MUSIC_POOL_PTR],y
  sta f:MUSIC_STATES+14,x
  iny
  phy
  phx
  jsl music_voice_volume
  plx
  ply
  jmp .loword(@advance)
@table:
  rep #$20
  lda [MUSIC_POOL_PTR],y
  sta f:MUSIC_STATES+20,x       ; ready pointer and size/resolution
  iny
  iny
  sep #$20
  phy
  phx
  jsl music_voice_table
  plx
  ply
  jmp .loword(@advance)
@note:
  lda [MUSIC_POOL_PTR],y
  pha
  and #127
  sta f:MUSIC_STATES+11,x
  pla
  and #128
  sta f:MUSIC_STATES+19,x       ; preconverted legato: keep the existing envelope
  iny
  rep #$20
  lda [MUSIC_POOL_PTR],y
  sta f:MUSIC_STATES+12,x
  iny
  iny
  sep #$20
  lda [MUSIC_POOL_PTR],y
  sta f:MUSIC_STATES+14,x
  iny
@note_ready:
.ifdef AUDIO_FM
  lda f:MUSIC_STATES+19,x
  bne :+                       ; tied notes retain the prior next capture
  lda f:MUSIC_STATES+14,x
  sta f:MUSIC_STATES+25,x
:
.endif
  lda #1
  sta f:MUSIC_STATES+15,x
  phy
  phx
  jsl music_voice_on
  plx
  ply
  jmp .loword(@advance)
.ifdef AUDIO_FM
@shared_note:
  ; $f3-$f6 are the FM scratch bytes; the voice call has not begun yet.
  lda [MUSIC_POOL_PTR],y
  iny
  phy
  phx
  rep #$20
  and #255
  asl
  asl
  tax
  lda f:music_note_dictionary,x
  sta $f3
  lda f:music_note_dictionary+2,x
  sta $f5
  plx
  ply
  sep #$20
  lda $f3
  and #127
  sta f:MUSIC_STATES+11,x
  lda $f3
  and #128
  sta f:MUSIC_STATES+19,x
  rep #$20
  lda $f4
  sta f:MUSIC_STATES+12,x
  sep #$20
  lda $f6
  sta f:MUSIC_STATES+14,x
  bra @note_ready
.endif
@off:
  lda #0
  sta f:MUSIC_STATES+15,x
  phy
  phx
  jsl music_voice_off
  plx
  ply
  bra @advance
@loop:
  lda [MUSIC_POOL_PTR],y
  iny
  beq @jump
  sta MUSIC_TEMP
  rep #$20
  tya
  cmp f:MUSIC_STATES+6,x
  sep #$20
  beq @repeat
  rep #$20
  tya
  sta f:MUSIC_STATES+6,x
  sep #$20
  lda MUSIC_TEMP
  bra @decrement
@repeat:
  lda f:MUSIC_STATES+8,x
  beq @finished_loop
@decrement:
  dec
  sta f:MUSIC_STATES+8,x
@jump:
  rep #$20
  lda [MUSIC_POOL_PTR],y
  clc
  adc f:MUSIC_STATES,x
  tay
  sep #$20
  bra @advance
@finished_loop:
  rep #$20
  lda #$ffff
  sta f:MUSIC_STATES+6,x
  sep #$20
  iny
  iny
@advance:
  rep #$20
  tya
  sta f:MUSIC_STATES+2,x
  sep #$20
  jsr .loword(music_prime)
  rep #$20
  lda f:MUSIC_STATES+4,x
  sep #$20
  bne @return
  jmp .loword(music_event)
@return:
  rts
