; DOC-clocked score service. No disk call, Toolbox call or card transfer.
; Main DOC register transactions are atomic. IRQ saves the GLU mode/pointer
; around its own writes, so interruptible waveform uploads keep their place.
; The game calls this only after startup loading and doc_init have finished.
.a8
.i16
MUSIC_IRQ_PHASE = $1e90
MUSIC_IRQ_CONTROL = $1e92
MUSIC_IRQ_SHADOW = $1e93
MUSIC_IRQ_OLD_VECTOR = $1e94
MUSIC_IRQ_COUNT = $1e96
MUSIC_IRQ_PERIODS = $1e98
MUSIC_IRQ_OLD_INTEN = $1e9a
MUSIC_IRQ_OLD_VGC = $1e9b
MUSIC_IRQ_OLD_KM = $1e9c
.ifndef MUSIC_TIMER_VOICE
MUSIC_TIMER_VOICE = 31
.endif
MUSIC_IRQ_VOICE = MUSIC_TIMER_VOICE

music_irq_install:
  php
  sei
  ldx #$e1
  lda #(MUSIC_IRQ_VOICE*2)
  jsr doc_write
  lda f:$e0c035
  sta MUSIC_IRQ_SHADOW
  rep #$20
  stz MUSIC_IRQ_PHASE
  stz MUSIC_IRQ_COUNT
  sep #$20
  ; The only IRQ source enabled by this path is the DOC clock. Existing input
  ; polling continues; later input IRQ support must dispatch its own source.
  lda MUSIC_IRQ_SHADOW
  ora #$40
  sta f:$e0c035
  rep #$20
  lda f:$00ffee
  sta MUSIC_IRQ_OLD_VECTOR
  .ifdef AUDIO_GAME
  lda #music_irq_vector
  .else
  lda #music_irq_entry
  .endif
  sta f:$00ffee
  sep #$20
  lda f:$e0c041
  sta MUSIC_IRQ_OLD_INTEN
  lda #0
  sta f:$e0c041
  lda f:$e0c023
  and #7
  sta MUSIC_IRQ_OLD_VGC
  lda #0
  sta f:$e0c023
  sta f:$e0c032
  lda f:$e0c027
  sta MUSIC_IRQ_OLD_KM
  and #$ab
  sta f:$e0c027
  jsl audio_init
.ifdef AUDIO_FAST
  phd
  rep #$20
  lda #$1e00
  tcd
  sep #$20
  jsl audio_fast_init
  pld
.endif
.if MUSIC_ENABLED
  phd
  rep #$20
  lda #$1e00
  tcd
  sep #$20
  jsl music_player_init
 .ifdef AUDIO_FM
  jsl fm_voice_init
 .ifdef CONTINUOUS_GAME
  ; Prepare the identical two phases of the opening cue while the title
  ; is displayed. A later song may replace these buffers normally.
  rep #$20
  stz z:FM_SONG
  sep #$20
  jsl fm_song_start
 .endif
 .endif
  pld
.endif
@ready:
  lda f:$e0c03c
  bmi @ready
  lda DOC_MASTER
  ora #$60
  sta f:$e0c03c
  lda #0
  sta f:$e0c03e
  lda #$ff
  sta f:$e0c03f
  ldx #256
@silence:
  lda f:$e0c03c
  bmi @silence
  lda #128
  sta f:$e0c03d
  dex
  bne @silence
  ldx #$40+MUSIC_IRQ_VOICE
  lda #0
  jsr doc_write
  ldx #$80+MUSIC_IRQ_VOICE
  lda #$ff
  jsr doc_write
  ldx #$c0+MUSIC_IRQ_VOICE
  lda #0
  jsr doc_write
  .ifdef MUSIC_TIMER_HIGH_CONSTANT
  ldx #$20+MUSIC_IRQ_VOICE
  lda #MUSIC_TIMER_HIGH_CONSTANT
  jsr doc_write
  lda #$ff
  sta MUSIC_IRQ_PERIODS
  .endif
  jsr music_irq_period
  ldx #$a0+MUSIC_IRQ_VOICE
  lda #8
  jsr doc_write
  plp
  cli
  rts

music_irq_remove:
  sei
  ldx #$a0+MUSIC_IRQ_VOICE
  lda #3
  jsr doc_write
  rep #$20
  lda MUSIC_IRQ_OLD_VECTOR
  sta f:$00ffee
  sep #$20
  lda MUSIC_IRQ_SHADOW
  sta f:$e0c035
  lda MUSIC_IRQ_OLD_INTEN
  sta f:$e0c041
  lda MUSIC_IRQ_OLD_VGC
  sta f:$e0c023
  lda MUSIC_IRQ_OLD_KM
  sta f:$e0c027
  rts

music_irq_period:
.ifdef MUSIC_TIMER_HIGH_CONSTANT
  ; The build proves the high byte is constant for this DOC scan rate.
  ; Only a changed low byte crosses the slow GLU bus.
  ldx MUSIC_IRQ_PHASE
  lda f:music_irq_frequencies,x
  inc MUSIC_IRQ_PHASE
  cmp MUSIC_IRQ_PERIODS
  beq @same
  sta MUSIC_IRQ_PERIODS
@ready:                       ; callers leave the GLU in register mode
  lda f:$e0c03c
  bmi @ready
  lda #MUSIC_IRQ_VOICE
  sta f:$e0c03e
  lda MUSIC_IRQ_PERIODS
  sta f:$e0c03d
@same:
  rts
.else
  rep #$20
  ldx MUSIC_IRQ_PHASE
  lda f:music_irq_frequencies,x
  sta MUSIC_IRQ_PERIODS
  txa
  inc
  inc
  and #511
  sta MUSIC_IRQ_PHASE
  sep #$20
  ldx #MUSIC_IRQ_VOICE
  lda MUSIC_IRQ_PERIODS
  jsr doc_write
  ldx #$20+MUSIC_IRQ_VOICE
  lda MUSIC_IRQ_PERIODS+1
  jmp doc_write
.endif

music_irq_entry:
  rep #$30
  pha
  phx
  phy
  phd
  phb
  sep #$20
  lda #0
  pha
  plb
  rep #$20
  lda #$1e00
  tcd
  sep #$20
@pending:
  lda f:$e0c03c
  bmi @pending
  ; Main-loop DOC register transactions mask interrupts; only a main-loop
  ; upload leaves the GLU in RAM mode with interrupts on. Keep its mode and
  ; pointer then; a 0 marker otherwise.
  bit #$40
  beq @lean
  and #$60
  ora DOC_MASTER
  pha
  lda f:$e0c03e
  pha
  lda f:$e0c03f
  pha
  lda #1
  bra @marked
@lean:
  lda #0
@marked:
  pha
@dispatch:
  ; E0 acknowledges each reported oscillator. Timer ticks step the score;
  ; table completions service their waiting chain without advancing music.
  ; The GLU is idle here. C03D returns the preceding fetch and posts another
  ; one (Apple Hardware Reference p.107): the second read returns E0 and
  ; posts a harmless read of register 0.
  lda DOC_MASTER
  sta f:$e0c03c
  lda #$e0
  sta f:$e0c03e
  lda f:$e0c03d
@fetch:
  lda f:$e0c03c
  bmi @fetch
  lda #0
  sta f:$e0c03e
  lda f:$e0c03d
  cmp #$80
  bcs @restore
  lsr
  and #31
  cmp #MUSIC_IRQ_VOICE
  beq @timer
  jsl audio_completed
  bra @restore
@timer:
.ifdef AUDIO_PROFILE
  lda #1
  sta f:$050509
.endif
  rep #$20
  inc MUSIC_IRQ_COUNT
  sep #$20
  jsr music_irq_period
.ifdef CONTINUOUS_GAME
  jsl native_input_doc_tick
.endif
.ifdef CONTINUOUS_GAME
  ; The queue is serviced on one of every four timer ticks.
  lda MUSIC_IRQ_COUNT
  and #3
  bne :+
  jsl audio_request_tick
:
.endif
.ifdef AUDIO_FAST
  jsl audio_fast_tick
.elseif .not .defined(AUDIO_FM)
  jsl audio_envelopes_tick
.endif
.ifdef AUDIO_COMPACT_SSG
 .ifdef SSG_FEATURE_TICK
  rep #$20
  lda MUSIC_IRQ_COUNT
  cmp #SSG_FEATURE_TICK
  sep #$20
  bne :+
  lda #SSG_FEATURE_COMMAND_A
  sta SSG_PENDING
  jsl audio_ssg_command
  lda #SSG_FEATURE_COMMAND_B
  sta SSG_PENDING
  jsl audio_ssg_command
:
 .endif
  lda z:SSG_PENDING_D
  beq :+
  jsl audio_ssg_command
:
  lda z:SSG_ACTIVE_D
  beq :+
  jsl audio_ssg_tick
:
.endif
.ifdef AUDIO_PROFILE
  lda #30
  sta f:$050509
.endif
.if MUSIC_ENABLED
 .ifdef MUSIC_FEATURE_TICK
  rep #$20
  lda MUSIC_IRQ_COUNT
  cmp #MUSIC_FEATURE_TICK
  sep #$20
  bne :+
  lda #MUSIC_FEATURE_COMMAND
  sta MUSIC_PENDING
:
 .endif
  jsl music_player_tick
.endif
.ifdef AUDIO_PROFILE
  lda #31
  sta f:$050509
.endif
.ifdef AUDIO_FM
  jsl fm_voice_tick
.endif
.ifdef AUDIO_PROFILE
  lda #2
  sta f:$050509
.endif
.if .defined(AUDIO_FAST) .or .defined(AUDIO_FM)
  bra @restore
.else
@again:
  lda f:$e0c03c
  bmi @again
  jmp @dispatch
.endif
@restore:
  pla
  beq @restored
@ready:
  lda f:$e0c03c
  bmi @ready
  pla
  sta f:$e0c03f
  pla
  sta f:$e0c03e
  pla
  sta f:$e0c03c
@restored:
 .ifdef CONTINUOUS_GAME
  jsl native_input_capture
 .endif
  rep #$30
  plb
  pld
  ply
  plx
  pla
  rti
