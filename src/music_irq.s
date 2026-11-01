; The sound interrupt: the DOC timer oscillator (MUSIC_IRQ_VOICE) interrupts
; at the arcade sound rate (238.548 Hz) and runs the input, the sound queue,
; the SSG effects, the music and the FM voices. It makes no disk, Toolbox or
; card call. The main loop writes DOC registers with interrupts off; only a
; main-loop upload leaves the GLU in RAM mode with interrupts on, and the
; interrupt keeps its mode and address. audio_game_init installs it after the
; start-up loads.
.a8
.i16
MUSIC_IRQ_VOICE = MUSIC_TIMER_VOICE
FRAME_TICKS = 4              ; timer ticks of one arcade frame
TIMER_WAVE_PAGE = $ff        ; the DOC RAM page of the timer's silent wave
DOC_SILENCE = $80            ; the zero level of a DOC sample (0 halts it)
.assert UPDATE_TICKS = 2*FRAME_TICKS, error ; game_clock.s: two frames an update

; music_irq_install: start the music and the timer interrupt. The DOC
; enables the oscillators up to the timer; the other interrupt sources are
; off; the start music captures load while the title shows. The timer plays
; a silent wave with its interrupt on. JSR; interrupts on after it.
music_irq_install:
  php
  sei
  ldx #DOC_ENABLE
  lda #(MUSIC_IRQ_VOICE*2)
  jsr .loword(audio_doc_write)
  a16
  stz MUSIC_IRQ_PHASE
  stz GAME_CLOCK
  a8
  ; The DOC timer is the only interrupt source. The input code polls.
  lda f:SHADOW
  ora #SHADOW_IOLC
  sta f:SHADOW
  a16
  lda #music_irq_vector
  sta f:IRQ_VECTOR
  a8
  lda #0
  sta f:INTEN
  sta f:VGCINT
  sta f:SCANINT
  lda f:KMSTATUS
  and #<~(KM_MOUSE_IRQ|KM_DATA_IRQ|KM_KEY_IRQ)
  sta f:KMSTATUS
  phd
  a16
  lda #.loword(MUSIC_PAGE)
  tcd
  a8
  jsl music_player_init
  jsl fm_voice_init
  ; Load the captures of the start music (both phases are the same) while
  ; the title shows. A later song can replace them.
  a16
  stz z:FM_SONG
  a8
  jsl fm_song_start
  pld
  ; The timer's wave: one page of DOC_SILENCE at TIMER_WAVE_PAGE.
@ready:
  lda f:SOUNDCTL
  bmi @ready
  lda DOC_MASTER
  ora #SOUNDCTL_RAM|SOUNDCTL_INC
  sta f:SOUNDCTL
  lda #0
  sta f:SOUNDADRL
  lda #TIMER_WAVE_PAGE
  sta f:SOUNDADRH
  ldx #256
@silence:
  lda f:SOUNDCTL
  bmi @silence
  lda #DOC_SILENCE
  sta f:SOUNDDATA
  dex
  bne @silence
  ; The timer oscillator: no volume, a 256-byte table, the build's period.
  ldx #DOC_VOLUME+MUSIC_IRQ_VOICE
  lda #0
  jsr .loword(audio_doc_write)
  ldx #DOC_WAVE+MUSIC_IRQ_VOICE
  lda #TIMER_WAVE_PAGE
  jsr .loword(audio_doc_write)
  ldx #DOC_TABLE+MUSIC_IRQ_VOICE
  lda #0
  jsr .loword(audio_doc_write)
  ldx #DOC_FREQ_HIGH+MUSIC_IRQ_VOICE
  lda #MUSIC_TIMER_HIGH_CONSTANT
  jsr .loword(audio_doc_write)
  lda #$ff                      ; not a period: music_irq_period writes the first
  sta MUSIC_IRQ_PERIODS
  jsr .loword(music_irq_period)
  ldx #DOC_CONTROL+MUSIC_IRQ_VOICE
  lda #DOC_IRQ_ENABLE
  jsr .loword(audio_doc_write)
  plp
  cli
  rts

; music_irq_period: the timer frequency low byte of this tick from
; music_irq_frequencies (256 entries; their average gives the arcade rate).
; The build proves the high byte is constant; only a changed low byte goes to
; the DOC, as the GLU is slow. The GLU must be in register mode. JSR.
music_irq_period:
  ldx MUSIC_IRQ_PHASE
  lda f:music_irq_frequencies,x
  inc MUSIC_IRQ_PHASE           ; the low byte only: 256 entries
  cmp MUSIC_IRQ_PERIODS
  beq @same
  sta MUSIC_IRQ_PERIODS
@ready:
  lda f:SOUNDCTL
  bmi @ready
  lda #DOC_FREQ_LOW+MUSIC_IRQ_VOICE
  sta f:SOUNDADRL
  lda MUSIC_IRQ_PERIODS
  sta f:SOUNDDATA
@same:
  rts

; music_irq_entry: the IRQ (from music_irq_vector). D = MUSIC_PAGE, DBR = 0.
; A timer tick advances GAME_CLOCK and runs the sound work; the queue gets
; one command each arcade frame (FRAME_TICKS). Other DOC interrupts are only
; acknowledged. The input capture runs at the end of each interrupt.
music_irq_entry:
  ax16
  pha
  phx
  phy
  phd
  phb
  a8
  lda #^GAME_RAM
  pha
  plb
  a16
  lda #.loword(MUSIC_PAGE)
  tcd
  a8
@pending:
  lda f:SOUNDCTL
  bmi @pending
  ; A main-loop upload in RAM mode: keep the GLU mode and address on the
  ; stack, then the marker 1; else the marker 0.
  bit #SOUNDCTL_RAM
  beq @lean
  and #SOUNDCTL_RAM|SOUNDCTL_INC
  ora DOC_MASTER
  pha
  lda f:SOUNDADRL
  pha
  lda f:SOUNDADRH
  pha
  lda #1
  bra @marked
@lean:
  lda #0
@marked:
  pha
@dispatch:
  ; The read of DOC_IRQ acknowledges the oscillator it reports. SOUNDDATA
  ; returns the fetch before and posts a new one (Apple IIgs Hardware
  ; Reference p.107): the second read returns DOC_IRQ and posts a harmless
  ; read of register 0.
  lda DOC_MASTER
  sta f:SOUNDCTL
  lda #DOC_IRQ
  sta f:SOUNDADRL
  lda f:SOUNDDATA
@fetch:
  lda f:SOUNDCTL
  bmi @fetch
  lda #0
  sta f:SOUNDADRL
  lda f:SOUNDDATA
  cmp #DOC_IRQ_NONE
  bcs @restore
  lsr
  and #DOC_OSCILLATORS-1        ; the oscillator
  cmp #MUSIC_IRQ_VOICE
  bne @restore
@timer:
  a16
  inc GAME_CLOCK
  a8
  jsr .loword(music_irq_period)
  jsl native_input_doc_tick
  lda GAME_CLOCK
  and #FRAME_TICKS-1
  bne :+
  jsl audio_request_tick
:
  lda z:SSG_PENDING
  beq :+
  jsl audio_ssg_command
:
  lda z:SSG_ACTIVE
  beq :+
  jsl audio_ssg_tick
:
  jsl music_player_tick
  jsl fm_voice_tick
@restore:
  ; The GLU state of a main-loop upload goes back.
  pla
  beq @restored
@ready:
  lda f:SOUNDCTL
  bmi @ready
  pla
  sta f:SOUNDADRH
  pla
  sta f:SOUNDADRL
  pla
  sta f:SOUNDCTL
@restored:
  jsl native_input_capture
  ax16
  plb
  pld
  ply
  plx
  pla
  rti
.assert ^GAME_RAM = 0 .and FRAME_TICKS = 4 .and DOC_OSCILLATORS = 32, error
