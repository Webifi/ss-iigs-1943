; The SSG effects: up to SSG_PARTS effect lists play at once, one on each
; DOC oscillator pair from DOC_SSG_FIRST (the odd oscillator, then the even
; one). scripts/ssg_writes.py turns the arcade SSG programs into lists of the
; exact DOC writes, so a tick only waits and writes. A list (SSG_HEAD bytes of
; header, then records): each record is a header byte (the delay /
; SSG_DELAY_UNIT in bits 4-7, a mask code in bits 0-3), the mask byte for
; SSG_EXPLICIT, then the values of the mask. Code 0: SSG_END_HEADER ends the
; list; SSG_REPEAT_HEADER, the repetitions and a target repeat records.
; Callers: D = MUSIC_PAGE, DBR = 0, A8, X16. Inside, DBR = the bank of
; SSG_STATES.
.a8
.i16
; An SSG part record (SSG_STATES, SSG_PART_SIZE bytes; X = part * SSG_PART_SIZE)
T_BASE = 0                     ; 3 bytes: the first record of the list
T_PC = 3                       ; 2 bytes: the values of the pending record
T_WAIT = 5                     ; the SSG_TIME of the pending record
T_MASK = 6                     ; its mask code
T_REPEAT = 7                   ; 2 bytes: the repeat record in progress; $ffff none
T_LEFT = 9                     ; repetitions left
T_ACTIVE = 10                  ; nonzero while the list plays
T_TONE = 11                    ; 2 bytes: the last odd frequency (the part's tone)
T_TSIZE = 17                   ; the tone table size
T_ODD = 18                     ; the odd oscillator
T_PHASE = 19                   ; T_WAIT & (SSG_DELAY_UNIT-1): its SSG_PHASES entry
DOC_STOPPED = DOC_HALT|DOC_ONE_SHOT ; a halted oscillator
.assert SSG_PART_SIZE = 32, error ; ssg_start: X / 16 = part * 2

; ssg_out: write A8 to the DOC register group + the oscillator in the direct
; page byte osc. B is changed.
.macro ssg_out osc, group
  xba
  lda f:SOUNDCTL
  bmi *-4
  lda z:osc
  ora #group
  sta f:SOUNDADRL
  xba
  sta f:SOUNDDATA
.endmacro

; ssg_start: start the list at SSG_PTR in the part X. Both oscillators halt
; with no volume and take their table sizes; then the records of the start
; tick play. The first count of the pending record falls on this tick's
; audio_ssg_tick. JSR.
ssg_start:
  lda SSG_STATES+T_ACTIVE,x
  beq :+
  jsr .loword(ssg_phase_remove) ; the new list replaces the one that plays
  bra :++
:
  inc z:SSG_ACTIVE
:
  ldy #SSG_HEAD_TONE_SIZE
  lda [SSG_PTR],y
  sta SSG_STATES+T_TSIZE,x
  a16
  lda #$ffff
  sta SSG_STATES+T_REPEAT,x
  lda z:SSG_PTR
  clc
  adc #SSG_HEAD
  sta SSG_STATES+T_BASE,x
  sta z:SSG_PTR
  a8
  lda z:SSG_PTR+2
  adc #0
  sta SSG_STATES+T_BASE+2,x
  sta z:SSG_PTR+2
  lda #1
  sta SSG_STATES+T_ACTIVE,x
  ; The oscillators of the part: DOC_SSG_FIRST + part * 2, and the next.
  a16
  txa
  lsr
  lsr
  lsr
  lsr
  clc
  adc #DOC_SSG_FIRST
  a8
  sta SSG_STATES+T_ODD,x
  sta z:SSG_ODD
  inc
  sta z:SSG_EVEN
  lda #0
  ssg_out SSG_ODD, DOC_VOLUME
  lda #DOC_STOPPED
  ssg_out SSG_ODD, DOC_CONTROL
  lda #0
  ssg_out SSG_EVEN, DOC_VOLUME
  lda #DOC_STOPPED
  ssg_out SSG_EVEN, DOC_CONTROL
  lda SSG_STATES+T_TSIZE,x
  ssg_out SSG_ODD, DOC_TABLE
  lda #SSG_NOISE_SIZE
  ssg_out SSG_EVEN, DOC_TABLE
  ldy #0
  jsr .loword(ssg_header)
  lda SSG_STATES+T_ACTIVE,x
  beq :+
  lda SSG_STATES+T_WAIT,x
  bne :+
  jsr .loword(ssg_record)       ; the records of the start tick
:
  lda #0                        ; the even oscillator runs
  ssg_out SSG_EVEN, DOC_CONTROL
  lda SSG_STATES+T_ACTIVE,x
  beq :+
  inc SSG_STATES+T_WAIT,x
  lda SSG_STATES+T_WAIT,x
  clc
  adc z:SSG_TIME
  sta SSG_STATES+T_WAIT,x       ; the SSG_TIME of the record, with the start tick
  jsr .loword(ssg_phase_add)
:
  rts

; SSG_PHASES: every delay is a multiple of SSG_DELAY_UNIT ticks, so a part
; that plays is due only when SSG_TIME & (SSG_DELAY_UNIT-1) is its T_PHASE;
; the entry of each phase holds the bits of its parts (part 0: bit 0).
; ssg_phase_add: the part X joins the entry of its T_WAIT. ssg_phase_remove:
; it leaves the entry of its T_PHASE. JSR; DBR = the bank of SSG_STATES; X, Y
; kept.
ssg_phase_add:
  a16
  lda SSG_STATES+T_WAIT,x
  and #SSG_DELAY_UNIT-1         ; B = 0 for the TAY
  a8
  sta SSG_STATES+T_PHASE,x
  phy
  tay
  jsr .loword(ssg_part_bit)
  ora SSG_PHASES,y
  sta SSG_PHASES,y
  ply
  rts
ssg_phase_remove:
  phy
  a16
  lda SSG_STATES+T_PHASE,x
  and #SSG_DELAY_UNIT-1         ; B = 0 for the TAY
  a8
  tay
  jsr .loword(ssg_part_bit)
  eor #$ff
  and SSG_PHASES,y
  sta SSG_PHASES,y
  ply
  rts
; ssg_part_bit: A8 = the SSG_PHASES bit of the part X. JSR; X, Y kept.
ssg_part_bit:
  phx
  a16
  txa
  .repeat 5
  lsr                           ; / SSG_PART_SIZE
  .endrepeat
  tax
  a8
  lda f:ssg_part_bits,x
  plx
  rts
ssg_part_bits: .byte $01, $02, $04, $08, $10, $20
.assert SSG_PART_SIZE = 1 << 5 .and SSG_PARTS = 6, error
.assert SSG_PHASES = SSG_STATES + SSG_PARTS*SSG_PART_SIZE, error ; audio_bank_init clears both

; ssg_record: write the pending record, then each record after it with no
; delay. Y = its values, SSG_PTR = the list, SSG_ODD/SSG_EVEN = the part's
; oscillators. The mask (SSG_MASKS entry of the code, or the byte after code
; SSG_EXPLICIT) selects the writes in this order:
;   bit 0 odd frequency (a word; also the part's tone), bit 1 even frequency
;   (a word), bit 2 even frequency = the tone, bit 3 odd wave page, bit 4 even
;   control DOC_STOPPED then 0, bit 5 even wave page, bit 6 even table size,
;   bit 7 odd control.
; Of bits 3, 5, 6 and 7, one gives one value byte (SSG_KINDS 1); two or more
; give one byte that selects an SSG_FIELDS entry (SSG_KINDS 2: odd page, even
; page, even size, odd control).
ssg_record:
  lda SSG_STATES+T_MASK,x
  cmp #SSG_EXPLICIT
  bne @coded
  lda [SSG_PTR],y
  iny
  bra @mask
@coded:
  phx
  a16
  and #$00ff
  tax
  a8
  lda f:SSG_MASKS-1,x           ; codes start at 1
  plx
@mask:
  sta z:SSG_MASK
  lsr z:SSG_MASK
  bcc @even_value
  a16
  lda [SSG_PTR],y
  iny
  iny
  sta SSG_STATES+T_TONE,x
  a8
  ssg_out SSG_ODD, DOC_FREQ_LOW
  lda SSG_STATES+T_TONE+1,x
  ssg_out SSG_ODD, DOC_FREQ_HIGH
@even_value:
  lsr z:SSG_MASK
  bcc @even_tone
  lsr z:SSG_MASK                ; bit 2 is never set with bit 1
  a16
  lda [SSG_PTR],y
  iny
  iny
  bra @even_write
@even_tone:
  lsr z:SSG_MASK
  bcc @state
  a16
  lda SSG_STATES+T_TONE,x
@even_write:
  sta z:SSG_TEMP
  a8
  ssg_out SSG_EVEN, DOC_FREQ_LOW
  lda z:SSG_TEMP+1
  ssg_out SSG_EVEN, DOC_FREQ_HIGH
@state:
  ; Bits 3-7 are now bits 0-4 of SSG_MASK.
  lda z:SSG_MASK
  bne :+
  jmp .loword(ssg_header)
:
  phx
  a16
  and #$001f
  tax
  a8
  lda f:SSG_KINDS,x
  cmp #2
  beq :+
  jmp .loword(@direct)
:
  lda [SSG_PTR],y               ; the SSG_FIELDS entry
  iny
  a16
  and #$00ff
  asl
  asl                           ; four bytes an entry
  tax
  a8
  lsr z:SSG_MASK
  bcc :+
  lda f:SSG_FIELDS,x
  ssg_out SSG_ODD, DOC_WAVE
:
  lsr z:SSG_MASK
  bcc :+
  lda #DOC_STOPPED
  ssg_out SSG_EVEN, DOC_CONTROL
  lda #0
  ssg_out SSG_EVEN, DOC_CONTROL
:
  lsr z:SSG_MASK
  bcc :+
  lda f:SSG_FIELDS+1,x
  ssg_out SSG_EVEN, DOC_WAVE
:
  lsr z:SSG_MASK
  bcc :+
  lda f:SSG_FIELDS+2,x
  ssg_out SSG_EVEN, DOC_TABLE
:
  lsr z:SSG_MASK
  bcc :+
  lda f:SSG_FIELDS+3,x
  ssg_out SSG_ODD, DOC_CONTROL
:
  plx
  jmp .loword(ssg_header)
@direct:
  cmp #1
  bne @fields_none
  lda [SSG_PTR],y               ; the one page, size or control value
  iny
  sta z:SSG_TEMP
@fields_none:
  plx
  lsr z:SSG_MASK
  bcc :+
  lda z:SSG_TEMP
  ssg_out SSG_ODD, DOC_WAVE
:
  lsr z:SSG_MASK
  bcc :+
  lda #DOC_STOPPED
  ssg_out SSG_EVEN, DOC_CONTROL
  lda #0
  ssg_out SSG_EVEN, DOC_CONTROL
:
  lsr z:SSG_MASK
  bcc :+
  lda z:SSG_TEMP
  ssg_out SSG_EVEN, DOC_WAVE
:
  lsr z:SSG_MASK
  bcc :+
  lda z:SSG_TEMP
  ssg_out SSG_EVEN, DOC_TABLE
:
  lsr z:SSG_MASK
  bcc ssg_header
  lda z:SSG_TEMP
  ssg_out SSG_ODD, DOC_CONTROL
; ssg_header: read the next record header at Y. A delay of 0 plays the
; record now; a repeat goes back to its target; the end stops the part.
ssg_header:
  lda [SSG_PTR],y
  iny
  pha
  and #$0f
  beq @special
  sta SSG_STATES+T_MASK,x
  pla
  lsr
  lsr
  lsr
  lsr
  asl
  asl
  asl                           ; times SSG_DELAY_UNIT
  sta SSG_STATES+T_WAIT,x
  bne :+
  jmp .loword(ssg_record)
:
  a16
  tya
  sta SSG_STATES+T_PC,x
  a8
  rts
@special:
  pla
  cmp #SSG_REPEAT_HEADER
  beq @repeat
  ; SSG_END_HEADER: the part stops silent.
  jsr .loword(ssg_phase_remove)
  stz SSG_STATES+T_ACTIVE,x
  dec z:SSG_ACTIVE
  jmp .loword(ssg_silence)
@repeat:
  ; The repetitions and the target follow; Y-1 is this record.
  a16
  tya
  dec
  cmp SSG_STATES+T_REPEAT,x
  beq @again
  sta SSG_STATES+T_REPEAT,x
  a8
  lda [SSG_PTR],y
  sta SSG_STATES+T_LEFT,x
@again:
  a8
  lda SSG_STATES+T_LEFT,x
  beq @finished
  dec
  sta SSG_STATES+T_LEFT,x
  a16
  iny
  lda [SSG_PTR],y
  tay
  a8
  bra ssg_header
@finished:
  a16
  lda #$ffff
  sta SSG_STATES+T_REPEAT,x
  iny
  iny
  iny                           ; past the repetitions and the target
  a8
  bra ssg_header
.assert SSG_DELAY_UNIT = 8 .and SSG_END_HEADER = 0, error

; ssg_silence: the part ends silent: AM off and both volumes 0; the
; oscillators continue.
ssg_silence:
  lda #0
  ssg_out SSG_ODD, DOC_CONTROL
  lda #0
  ssg_out SSG_ODD, DOC_VOLUME
  lda #0
  ssg_out SSG_EVEN, DOC_VOLUME
  rts

; audio_ssg_command: start the effect SSG_PENDING (from audio_request_tick).
; It starts a list on each part that its arcade program uses; the other
; parts continue. SSG_COMMAND_ENTRIES has SSG_PARTS entries for each command
; (SSG_ENTRY_SIZE: the list address, its length); address 0: no list. JSL.
audio_ssg_command:
  lda z:SSG_PENDING
  bne :+
  rtl
:
  stz z:SSG_PENDING
  phb
  pha
  lda #^SSG_STATES
  pha
  plb
  pla
  a16
  and #255
  cmp #SSG_COMMANDS
  bcs @return16
  tax
  a8
  lda f:SSG_COMMAND_INDEX,x
  cmp #SSG_NO_COMMAND
  beq @return
  a16
  and #255
  sta z:SSG_TEMP
  asl
  asl
  asl
  asl
  sec
  sbc z:SSG_TEMP                ; entry * 15
  asl                           ; * 30: SSG_PARTS * SSG_ENTRY_SIZE
  tay
  lda #.loword(SSG_COMMAND_ENTRIES)
  sta z:SSG_COMMAND_PTR
  a8
  lda #^SSG_COMMAND_ENTRIES
  sta z:SSG_COMMAND_PTR+2
  a16
  ldx #0
@part:
  stx z:SSG_SLOT
  lda [SSG_COMMAND_PTR],y
  sta z:SSG_PTR
  a8
  iny
  iny
  lda [SSG_COMMAND_PTR],y
  sta z:SSG_PTR+2
  ora z:SSG_PTR
  ora z:SSG_PTR+1
  beq @skip
  iny
  a16
  phy
  a8
  jsr .loword(ssg_start)
  a16
  ply
@skip16:
  ldx z:SSG_SLOT
  tya
  clc
  adc #2                        ; past the length
  tay
  txa
  clc
  adc #SSG_PART_SIZE
  tax
  cmp #SSG_PARTS*SSG_PART_SIZE
  bne @part
@return16:
  a8
@return:
  plb
  rtl
@skip:
  iny
  a16
  bra @skip16
.assert SSG_PARTS*SSG_ENTRY_SIZE = 30, error

; audio_ssg_tick: one SSG tick. SSG_TIME counts; each part of the
; SSG_PHASES entry of this tick, in part order, plays its record when it is
; due at SSG_TIME. JSL.
audio_ssg_tick:
.a8
.i16
  lda z:SSG_ACTIVE
  bne :+
  rtl
:
  inc z:SSG_TIME
  a16
  lda z:SSG_TIME
  and #SSG_DELAY_UNIT-1         ; B = 0 for the TAX
  tax
  a8
  lda f:SSG_PHASES,x
  bne :+
  rtl                           ; no part has this phase
:
  sta z:SSG_DUE
  phb
  lda #^SSG_STATES
  pha
  plb
  .repeat SSG_PARTS,I
    lsr z:SSG_DUE
    bcc :+
    ldx #I*SSG_PART_SIZE
    lda SSG_STATES+T_WAIT,x
    cmp z:SSG_TIME
    bne :+
    jsr .loword(ssg_due_record)
:
  .endrepeat
  plb
  rtl

; ssg_due_record: the part X plays its due record; its next delay becomes
; an SSG_TIME. JSR.
ssg_due_record:
  stx z:SSG_SLOT
  a16
  lda SSG_STATES+T_BASE,x
  sta z:SSG_PTR
  lda SSG_STATES+T_PC,x
  tay
  a8
  lda SSG_STATES+T_BASE+2,x
  sta z:SSG_PTR+2
  lda SSG_STATES+T_ODD,x
  sta z:SSG_ODD
  inc
  sta z:SSG_EVEN
  jsr .loword(ssg_record)
  lda SSG_STATES+T_ACTIVE,x
  beq :+
  lda SSG_STATES+T_WAIT,x
  clc
  adc z:SSG_TIME
  sta SSG_STATES+T_WAIT,x
:
  rts
