; Game-facing sound requests. Bank-zero entry points never touch the GLU.
; The timer owns DOC transactions. Uploads run in the main loop.
.a8
.i16
DOC_MASTER = $17f4
DOC_STREAM_ACTIVE = $17e0
DOC_STREAM_REFILLS = $17e6
DOC_STREAM_UNDERRUNS = $17e8
START_MUSIC_FLAGS = $0187d3  ; bits 7: timer, 6: smooth restart, 5: title preload
START_MUSIC_DUE = $0187d4    ; DOC tick at which the opening cue repeats

doc_init:
  jsl audio_game_init
  rts
doc_play_gun:
  lda #1
  bra doc_play_weapon
doc_play_hit:
  cmp #14
  beq doc_play_weapon
  lda #19
  bra doc_play_weapon
doc_play_player_hurt:
  lda #2
  bra doc_play_weapon
doc_play_player_death:
  lda #5
doc_play_weapon:
.ifdef CONTINUOUS_GAME
  jsl game_sound_request
.else
  sta SSG_PENDING
.endif
  rts
; Read the new channel's control without changing game logic.
doc_weapon_control:
  ldx #$ad
doc_read:
  jsl audio_game_doc_read
  rts
doc_stream_update:
  jsl audio_game_upload
  rts
.ifdef CONTINUOUS_GAME
; Main-thread producers publish the index last. The IRQ takes one command
; per arcade frame; its pending byte is only the final hand-off to the player.
game_sound_request:
  ; The arcade permits demo audio only with DSWB bit 7. Coin/title sounds
  ; remain audible once a credit exists, as do all real-game requests.
  pha
  lda CAB_START_PENDING
  bne @audible
  lda GAME_CREDITS
  bne @audible
  lda CAB_DEMO
  bne @demo
  lda GAME_FLOW
  cmp #3
  bcc @audible
  lda CAB_ENDING
  bne @audible
@demo:
  lda GAME_DIP_B
  bmi @audible
  pla
  cmp #0                      ; stop is always effective
  beq @enqueue
  rtl
@audible:
  pla
@enqueue:
  phx
  pha
  rep #$20
  lda STAGE_SOUND_WRITE
  and #31
  tax
  sep #$20
  pla
  sta STAGE_SOUND_QUEUE,x
  txa
  inc
  and #31
  cmp STAGE_SOUND_READ
  bne :+
  lda #$d8
  sta f:$050301
  plx
  rtl
:
  sta STAGE_SOUND_WRITE
  plx
  rtl
.endif
music_irq_vector:
  jml music_irq_entry

.segment "SOUND"
audio_game_doc_read:
  jsr .loword(audio_doc_read)
  rtl

audio_game_init:
.ifdef CONTINUOUS_GAME
  stz STAGE_SOUND_READ
  stz STAGE_SOUND_WRITE
  lda #0
  sta f:START_MUSIC_FLAGS
.endif
  lda f:$e100ca
  and #15
  sta DOC_MASTER
  sta f:$050500
  ldx #$a0
@halt:
  lda #3
  jsr .loword(audio_doc_write)
  inx
  cpx #$c0
  bne @halt
  rep #$20
  stz MUSIC_IRQ_COUNT
  stz DOC_STREAM_REFILLS
  stz DOC_STREAM_UNDERRUNS
  sep #$20
  stz DOC_STREAM_ACTIVE
  jsl audio_bank_init
  jsl wave_upload_init
  ldx #2048
@initial:
  phx
  jsl wave_upload_service
  plx
  dex
  bne @initial
  jsr .loword(music_irq_install)
  rtl

audio_game_upload:
  php
  rep #$30
  pha
  phx
  phy
  phd
  lda #0
  tcd
  sep #$20
  jsl wave_upload_service
  jsl fm_upload_service
.ifdef CONTINUOUS_GAME
  ; Service the start-cue deadline in idle time between game updates too;
  ; the arcade repeat is timed to the sound clock, not to a picture.
  lda f:START_MUSIC_FLAGS
  bpl :+
  jsl audio_start_music_service
:
.endif
  rep #$30
  pld
  ply
  plx
  pla
  plp
  rtl

audio_game_remove:
  jsr .loword(music_irq_remove)
  rtl
.ifdef CONTINUOUS_GAME
; A title credit can follow an earlier song. Request a fresh opening preload;
; the IRQ performs it only once the title and FM upload queue are idle.
audio_title_preload_request:
.a8
  php
  sei
  lda f:START_MUSIC_FLAGS
  ora #$20
  sta f:START_MUSIC_FLAGS
  plp
  rtl

; Start the opening cue as soon as the paid start is accepted, even when
; the stage picture is still loading. Reissue it after 596 DOC interrupts
; (2.498 s at the 238.548 Hz music clock), independently of picture loading.
audio_start_music_begin:
.a8
  lda #$82
  sta f:START_MUSIC_FLAGS
  rep #$20
  lda MUSIC_IRQ_COUNT
  clc
  adc #596
  sta f:START_MUSIC_DUE
  sep #$20
  bra audio_start_music_commands

audio_start_music_service:
  lda f:START_MUSIC_FLAGS
  bpl @done
  rep #$20
  lda MUSIC_IRQ_COUNT
  sec
  sbc f:START_MUSIC_DUE
  bmi @not_due
  sep #$20
  lda f:START_MUSIC_FLAGS
  and #$7f
  sta f:START_MUSIC_FLAGS
  ; Keep the current FM notes sounding until the replacement score starts.
  ; $3e is an internal queued transition, not an arcade sound command.
  lda #$3e
  jsl game_sound_request
  lda #$19
  jsl game_sound_request
  lda #$20
  jsl game_sound_request
  rtl
@not_due:
  sep #$20
@done:
  rtl

audio_start_music_commands:
  lda #0
  jsl game_sound_request
  lda #$19
  jsl game_sound_request
  lda #$20
  jsl game_sound_request
  rtl

; The first two stage-zero $20 events correspond to the cues already
; scheduled above. Keep the rest of stage_control_music's work unchanged.
audio_start_music_stage:
  lda STAGE_MUSIC
  cmp #$20
  bne @keep
  lda CAMERA_STAGE
  bne @keep
  phb
  lda #$01
  pha
  plb
  lda a:.loword(START_MUSIC_FLAGS)
  and #3
  beq @restore_keep
  ; One atomic read-modify-write preserves the IRQ's smooth-restart bit.
  dec a:.loword(START_MUSIC_FLAGS)
  plb
  sec
  rtl
@restore_keep:
  plb
@keep:
  clc
  rtl

audio_request_tick:
.a8
.i16
  lda STAGE_SOUND_READ
  cmp STAGE_SOUND_WRITE
  beq @done
  rep #$20
  and #31
  tax
  sep #$20
  lda STAGE_SOUND_QUEUE,x
  beq @stop
  cmp #$1f
  beq @effects_stop
  cmp #$3f
  beq @music_stop
  cmp #$3e
  beq @smooth_stop
  cmp #$20
  bcs @music
  lda SSG_PENDING
  bne @done
  lda STAGE_SOUND_QUEUE,x
  sta SSG_PENDING
  bra @advance
@effects_stop:
  jsr .loword(audio_effects_stop)
  bra @advance
@smooth_stop:
  jsr .loword(audio_effects_stop)
  lda f:START_MUSIC_FLAGS
  ora #$40
  sta f:START_MUSIC_FLAGS
  bra @advance
@stop:
  jsr .loword(audio_effects_stop)
@music_stop:
  lda #$ff
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
  and #31
  sta STAGE_SOUND_READ
@done:
  rtl
; Stop all six AM pairs without changing the timer or the FM voices.
audio_effects_stop:
  phx
  stz SSG_PENDING
  stz SSG_ACTIVE
  stz a:$1ebe
  stz a:$1ebf
  ldx #0
  lda #0
@states:
  sta f:$01850a,x
  rep #$21
  txa
  adc #32
  tax
  sep #$20
  lda #0
  cpx #192
  bcc @states
  ldx #$ad
@halt:
  lda #3
  jsr .loword(audio_doc_write)
  inx
  cpx #$b9
  bcc @halt
  plx
  rts
.endif
; No completion-timed sample operation exists on the snapshot/AM path.
audio_init:
  rtl
audio_completed:
  rtl
