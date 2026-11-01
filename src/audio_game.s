; The game side of the sound: the sound command queue, the sound start-up and
; the start music. The game queues arcade sound commands (sounds.inc) with
; game_sound_request; the sound interrupt (music_irq.s) takes one command
; each arcade frame with audio_request_tick. Only the sound interrupt and its
; start-up touch the DOC; uploads run in the main loop (audio_game_upload).
.a8
.i16
START_MUSIC_REPEAT = 596     ; DOC timer ticks: 2.498 s at 238.548 Hz

; game_sound_request: queue the sound command A. With no credit, in the demo
; play and on the cabinet pages (not the ending), a sound plays only with the
; demo sound switch (GAME_DIP_B bit 7), as in the arcade; SND_STOP_ALL always
; goes. A full queue drops the command. JSL; A8, X16; X kept.
game_sound_request:
  pha
  lda CAB_START_PENDING
  bne @audible
  lda GAME_CREDITS
  bne @audible
  lda CAB_DEMO
  bne @demo
  lda GAME_FLOW
  cmp #CAB_PAGE_FIRST
  bcc @audible                  ; the play of a game
  lda CAB_ENDING
  bne @audible
@demo:
  lda GAME_DIP_B
  bmi @audible                  ; bit 7: demo sounds
  pla
  cmp #SND_STOP_ALL
  beq @enqueue
  rtl
@audible:
  pla
@enqueue:
  phx
  pha
  a16
  lda SOUND_WRITE
  and #SOUND_QUEUE_SIZE-1
  tax
  a8
  pla
  sta SOUND_QUEUE,x
  txa
  inc
  and #SOUND_QUEUE_SIZE-1
  cmp SOUND_READ
  bne :+
  plx                           ; full: the command is not published
  rtl
:
  sta SOUND_WRITE
  plx
  rtl
; music_irq_vector: the IRQ vector (bank 0) jumps to the sound interrupt.
music_irq_vector:
  jml music_irq_entry

.segment "SOUND"
; audio_game_init: the sound start-up (game.s, once). The queue is empty, the
; DOC volume comes from the Control Panel, all oscillators halt, GAME_CLOCK
; starts at 0, then the sound bank and the music interrupt start. JSL.
audio_game_init:
  stz SOUND_READ
  stz SOUND_WRITE
  lda #0
  sta f:START_MUSIC_FLAGS
  lda f:CP_VOLUME
  and #CP_VOLUME_BITS
  sta DOC_MASTER
  ldx #DOC_CONTROL
@halt:
  lda #DOC_HALT|DOC_ONE_SHOT
  jsr .loword(audio_doc_write)
  inx
  cpx #DOC_CONTROL+DOC_OSCILLATORS
  bne @halt
  a16
  stz GAME_CLOCK
  a8
  jsl audio_bank_init
  jsr .loword(music_irq_install)
  rtl

; audio_game_upload: the sound work of the main loop between updates (the
; game clock wait, the menus and the card stream): the FM uploads, and the
; start music repeat when it is due. JSL; all registers, P and D kept.
audio_game_upload:
  php
  ax16
  pha
  phx
  phy
  phd
  lda #ZERO_PAGE
  tcd
  a8
  jsl fm_upload_service
  ; The start music repeat follows the sound clock, not a picture.
  lda f:START_MUSIC_FLAGS
  bpl :+                        ; SMF_DUE
  jsl audio_start_music_service
:
  ax16
  pld
  ply
  plx
  pla
  plp
  rtl
.assert SMF_DUE = $80, error ; the BPL above

; audio_title_preload_request: load the title music again when the sound is
; idle (a credit after an earlier song; music_title_preload). JSL.
audio_title_preload_request:
.a8
  php
  sei                           ; the interrupt changes START_MUSIC_FLAGS too
  lda f:START_MUSIC_FLAGS
  ora #SMF_PRELOAD
  sta f:START_MUSIC_FLAGS
  plp
  rtl

; audio_start_music_begin: a paid start (cabinet.s) starts the start music at
; once, also while the stage picture loads, and again START_MUSIC_REPEAT DOC
; ticks later. The two start music events of stage 0 are then skipped
; (audio_start_music_stage). JSL.
audio_start_music_begin:
.a8
  lda #SMF_DUE|2
  sta f:START_MUSIC_FLAGS
  a16
  lda GAME_CLOCK
  clc
  adc #START_MUSIC_REPEAT
  sta f:START_MUSIC_DUE
  a8
  bra audio_start_music_commands

; audio_start_music_service: when START_MUSIC_DUE comes, start the start
; music again; SND_SMOOTH_STOP keeps the FM notes until the new score starts.
audio_start_music_service:
  lda f:START_MUSIC_FLAGS
  bpl @done                     ; SMF_DUE
  a16
  lda GAME_CLOCK
  sec
  sbc f:START_MUSIC_DUE
  bmi @not_due
  a8
  lda f:START_MUSIC_FLAGS
  and #<~SMF_DUE
  sta f:START_MUSIC_FLAGS
  lda #SND_SMOOTH_STOP
  jsl game_sound_request
  lda #SND_START_EFFECT
  jsl game_sound_request
  lda #SND_START_MUSIC
  jsl game_sound_request
  rtl
@not_due:
  a8
@done:
  rtl

; audio_start_music_commands: stop the sound, then start the start music.
audio_start_music_commands:
  lda #SND_STOP_ALL
  jsl game_sound_request
  lda #SND_START_EFFECT
  jsl game_sound_request
  lda #SND_START_MUSIC
  jsl game_sound_request
  rtl

; audio_start_music_stage: stage_control_music asks with STAGE_MUSIC. Returns
; carry 1 for a start music event of stage 0 that audio_start_music_begin has
; played already (SMF_SKIPS counts them down), else carry 0. JSL.
audio_start_music_stage:
  lda STAGE_MUSIC
  cmp #SND_START_MUSIC
  bne @keep
  lda CAMERA_STAGE
  bne @keep
  phb
  lda #^START_MUSIC_FLAGS
  pha
  plb
  lda a:.loword(START_MUSIC_FLAGS)
  and #SMF_SKIPS
  beq @restore_keep
  ; One read-modify-write keeps the SMF_SMOOTH bit of the interrupt.
  dec a:.loword(START_MUSIC_FLAGS)
  plb
  sec
  rtl
@restore_keep:
  plb
@keep:
  clc
  rtl

; audio_request_tick: the sound interrupt takes the next queued command.
; An SSG effect waits while SSG_PENDING holds one; an FM command waits while
; MUSIC_PENDING holds one. SND_STOP_ALL stops the effects and the music;
; SND_SMOOTH_STOP stops the effects and sets SMF_SMOOTH. JSL; X changed.
audio_request_tick:
.a8
.i16
  lda SOUND_READ
  cmp SOUND_WRITE
  beq @done
  a16
  and #SOUND_QUEUE_SIZE-1
  tax
  a8
  lda SOUND_QUEUE,x
  beq @stop                     ; SND_STOP_ALL
  cmp #SND_STOP_EFFECTS
  beq @effects_stop
  cmp #SND_STOP_MUSIC
  beq @music_stop
  cmp #SND_SMOOTH_STOP
  beq @smooth_stop
  cmp #SND_FM_FIRST
  bcs @music
  lda MUSIC_PAGE+SSG_PENDING
  bne @done
  lda SOUND_QUEUE,x
  sta MUSIC_PAGE+SSG_PENDING
  bra @advance
@effects_stop:
  jsr .loword(audio_effects_stop)
  bra @advance
@smooth_stop:
  jsr .loword(audio_effects_stop)
  lda f:START_MUSIC_FLAGS
  ora #SMF_SMOOTH
  sta f:START_MUSIC_FLAGS
  bra @advance
@stop:
  jsr .loword(audio_effects_stop)
@music_stop:
  lda #MUSIC_STOP
@music:
  pha
  lda MUSIC_PENDING
  beq :+
  pla
  rtl
:
  pla
  sta MUSIC_PENDING
@advance:
  txa
  inc
  and #SOUND_QUEUE_SIZE-1
  sta SOUND_READ
@done:
  rtl
.assert SND_STOP_ALL = 0, error ; the BEQ above

; audio_effects_stop: stop the SSG effects: the SSG_PARTS part records and
; their DOC oscillators (DOC_SSG_FIRST up to the music timer). The timer and
; the FM voices continue. JSR; X kept.
audio_effects_stop:
  phx
  stz MUSIC_PAGE+SSG_PENDING
  stz MUSIC_PAGE+SSG_ACTIVE
  stz MUSIC_PAGE+SSG_NEXT
  stz MUSIC_PAGE+SSG_TIME
  ldx #0
  lda #0
@states:
  sta f:SSG_STATES+T_ACTIVE,x
  rep #P_M8|P_CARRY             ; A 16 bits; clear carry
  txa
  adc #SSG_PART_SIZE
  tax
  a8
  lda #0
  cpx #SSG_PARTS*SSG_PART_SIZE
  bcc @states
  ldx #DOC_CONTROL+DOC_SSG_FIRST
@halt:
  lda #DOC_HALT|DOC_ONE_SHOT
  jsr .loword(audio_doc_write)
  inx
  cpx #DOC_CONTROL+MUSIC_TIMER_VOICE
  bcc @halt
  plx
  rts
