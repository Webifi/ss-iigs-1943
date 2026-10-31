; Six resident native SSG lists (scripts/ssg_writes.py): per record a delay
; header, a slot mask and the exact DOC writes resolved at build time, on
; sound ticks. No YM bytecode, pitch division, waveform synthesis, change
; tracking, disk read or table upload in the tick.
; Callers: D=$1E00, DBR=0, A8/X16. Inside, DBR=$01 for the part states.
.a8
.i16
SSG_STATES = $8500             ; bank $01: six parts x 32 bytes
SSG_PTR = $d0
SSG_COMMAND_PTR = $d4
SSG_TEMP = $b0                 ; direct page, D=$1E00
SSG_SLOT = $b4
SSG_MASK = $b6
SSG_ACTIVE_D = $ba             ; SSG_ACTIVE ($1eba)
SSG_PENDING_D = $b8            ; SSG_PENDING ($1eb8)
SSG_ODD = $bc
SSG_EVEN = $bd
SSG_NEXT = $be                 ; empty ticks before the next pending record
SSG_TIME = $bf                 ; low byte of the active SSG tick clock
SSG_ACTIVE = $1eba
SSG_HEAD = 24                  ; record: type, tone size, table ids
SSG_FILLER = $40               ; list record that only waits

T_BASE = 0                     ; list start (3)
T_PC = 3                       ; fields of the pending record
T_WAIT = 5                     ; ticks to the pending record
T_MASK = 6                     ; its change mask
T_REPEAT = 7                   ; repeat record in progress; $ffff none
T_LEFT = 9                     ; repetitions left
T_ACTIVE = 10
T_TONE = 11
T_NOISE = 13
T_SEL = 15
T_FLAGS = 16                   ; noise, ultrasonic, square rotation
T_TSIZE = 17                   ; tone table size
T_ODD = 18
T_EVEN = 19
T_EVENF = 20                   ; last written even frequency
T_ODDP = 22                    ; last written odd table,
T_EVENP = 23                   ; even table,
T_EVENS = 24                   ; even size
T_ODDC = 25                    ; and odd control
T_ALONE = 26                   ; tone alone: the even oscillator plays tone

; A8 = value; register = oscillator (direct page byte) | group.
.macro ssg_out osc, group
  xba
  lda f:$e0c03c
  bmi *-4
  lda z:osc
  ora #group
  sta f:$e0c03e
  xba
  sta f:$e0c03d
.endmacro

; X = part*32, SSG_PTR = record address. Both voices silent and halted,
; their sizes, then the start tick's own records and the even run. The
; first count of the pending record falls on this tick's audio_ssg_tick.
ssg_start:
  lda SSG_STATES+T_ACTIVE,x
  bne :+
  inc z:SSG_ACTIVE_D
:
  ldy #1
  lda [SSG_PTR],y
  sta SSG_STATES+T_TSIZE,x
  rep #$20
  lda #$ffff
  sta SSG_STATES+T_REPEAT,x
  sta SSG_STATES+T_EVENF,x
  sta SSG_STATES+T_ODDP,x
  lda z:SSG_PTR
  clc
  adc #SSG_HEAD
  sta SSG_STATES+T_BASE,x
  sta z:SSG_PTR
  sep #$20
  lda z:SSG_PTR+2
  adc #0
  sta SSG_STATES+T_BASE+2,x
  sta z:SSG_PTR+2
  stz SSG_STATES+T_ALONE,x
  lda #1
  sta SSG_STATES+T_ACTIVE,x
  rep #$20
  txa
  lsr
  lsr
  lsr
  lsr
  clc
  adc #13
  sep #$20
  sta SSG_STATES+T_ODD,x
  sta z:SSG_ODD
  inc
  sta SSG_STATES+T_EVEN,x
  sta z:SSG_EVEN
  lda #0
  ssg_out SSG_ODD, $40
  lda #3
  ssg_out SSG_ODD, $a0
  lda #0
  ssg_out SSG_EVEN, $40
  lda #3
  ssg_out SSG_EVEN, $a0
  lda SSG_STATES+T_TSIZE,x
  ssg_out SSG_ODD, $c0
  lda #SSG_NOISE_SIZE
  sta SSG_STATES+T_EVENS,x
  ssg_out SSG_EVEN, $c0
  lda #3
  sta SSG_STATES+T_ODDC,x
  ldy #0
  jsr .loword(ssg_header)
  lda SSG_STATES+T_ACTIVE,x
  beq :+
  lda SSG_STATES+T_WAIT,x
  bne :+
  jsr .loword(ssg_record)       ; records on the start tick
:
  lda #0
  ssg_out SSG_EVEN, $a0
  lda SSG_STATES+T_ACTIVE,x
  beq :+
  inc SSG_STATES+T_WAIT,x
  lda SSG_STATES+T_WAIT,x
  clc
  adc z:SSG_TIME
  sta SSG_STATES+T_WAIT,x       ; absolute deadline, including start tick
:
  rts

; The pending record and every record after it with no delay. Y = its
; fields, SSG_PTR = list, SSG_ODD/SSG_EVEN = this part's oscillators.
; scripts/ssg_writes.py resolved each record to its exact DOC writes at
; build time. Its mask (the header code's SSG_MASKS entry, or the byte after
; header code 15) selects them in this order: odd frequency (kept as the
; part's tone), even frequency, even frequency = tone, odd page, even
; control 3 then 0, even page, even size, odd control. Of the last five,
; one page/size/control value is stored inline; two or more come from one
; SSG_FIELDS entry (odd page, even page, even size, odd control).
ssg_record:
  lda SSG_STATES+T_MASK,x
  cmp #SSG_FILLER
  bne :+
  jmp .loword(ssg_header)
:
  cmp #15
  bne @coded
  lda [SSG_PTR],y
  iny
  bra @mask
@coded:
  phx
  rep #$20
  and #$00ff
  tax
  sep #$20
  lda f:SSG_MASKS-1,x
  plx
@mask:
  sta z:SSG_MASK
  lsr z:SSG_MASK
  bcc @even_value
  rep #$20
  lda [SSG_PTR],y
  iny
  iny
  sta SSG_STATES+T_TONE,x
  sep #$20
  ssg_out SSG_ODD, $00
  lda SSG_STATES+T_TONE+1,x
  ssg_out SSG_ODD, $20
@even_value:
  lsr z:SSG_MASK
  bcc @even_tone
  lsr z:SSG_MASK                ; bit 2 is never set with bit 1
  rep #$20
  lda [SSG_PTR],y
  iny
  iny
  bra @even_write
@even_tone:
  lsr z:SSG_MASK
  bcc @state
  rep #$20
  lda SSG_STATES+T_TONE,x
@even_write:
  sta z:SSG_TEMP
  sep #$20
  ssg_out SSG_EVEN, $00
  lda z:SSG_TEMP+1
  ssg_out SSG_EVEN, $20
@state:
  lda z:SSG_MASK
  bne :+
  jmp .loword(ssg_header)
:
  phx
  rep #$20
  and #$001f
  tax
  sep #$20
  lda f:SSG_KINDS,x
  cmp #2
  beq :+
  jmp .loword(@direct)
:
  lda [SSG_PTR],y               ; shared entry
  iny
  rep #$20
  and #$00ff
  asl
  asl
  tax
  sep #$20
  lsr z:SSG_MASK
  bcc :+
  lda f:SSG_FIELDS,x
  ssg_out SSG_ODD, $80
:
  lsr z:SSG_MASK
  bcc :+
  lda #3
  ssg_out SSG_EVEN, $a0
  lda #0
  ssg_out SSG_EVEN, $a0
:
  lsr z:SSG_MASK
  bcc :+
  lda f:SSG_FIELDS+1,x
  ssg_out SSG_EVEN, $80
:
  lsr z:SSG_MASK
  bcc :+
  lda f:SSG_FIELDS+2,x
  ssg_out SSG_EVEN, $c0
:
  lsr z:SSG_MASK
  bcc :+
  lda f:SSG_FIELDS+3,x
  ssg_out SSG_ODD, $a0
:
  plx
  jmp .loword(ssg_header)
@direct:
  cmp #1
  bne @fields_none
  lda [SSG_PTR],y               ; the one page/size/control value
  iny
  sta z:SSG_TEMP
@fields_none:
  plx
  lsr z:SSG_MASK
  bcc :+
  lda z:SSG_TEMP
  ssg_out SSG_ODD, $80
:
  lsr z:SSG_MASK
  bcc :+
  lda #3
  ssg_out SSG_EVEN, $a0
  lda #0
  ssg_out SSG_EVEN, $a0
:
  lsr z:SSG_MASK
  bcc :+
  lda z:SSG_TEMP
  ssg_out SSG_EVEN, $80
:
  lsr z:SSG_MASK
  bcc :+
  lda z:SSG_TEMP
  ssg_out SSG_EVEN, $c0
:
  lsr z:SSG_MASK
  bcc ssg_header
  lda z:SSG_TEMP
  ssg_out SSG_ODD, $a0
; The next record: its delay and mask. A zero delay runs it now; repeats
; jump back; a zero mask ends the list and silences the part.
ssg_header:
  lda [SSG_PTR],y
  iny
  pha
  and #15
  beq @special
  sta SSG_STATES+T_MASK,x
  pla
  lsr
  lsr
  lsr
  lsr
  cmp #15
  beq @long_delay
  asl
  asl
  asl
  bra @wait
@long_delay:
  lda [SSG_PTR],y
  iny
@wait:
  sta SSG_STATES+T_WAIT,x
  cmp #0
  bne :+
  jmp .loword(ssg_record)
:
  rep #$20
  tya
  sta SSG_STATES+T_PC,x
  sep #$20
  rts
@special:
  pla
  beq @end
  cmp #$10
  beq @repeat
  ; A filler only waits. The compiler emits $20 followed by its delay.
  lda #SSG_FILLER
  sta SSG_STATES+T_MASK,x
  lda [SSG_PTR],y
  iny
  bra @wait
@end:
  stz SSG_STATES+T_ACTIVE,x
  dec z:SSG_ACTIVE_D
  jmp .loword(ssg_silence)
@repeat:
  ; Packed repeat marker, repetitions, target; Y-1 is this record.
  rep #$20
  tya
  dec
  cmp SSG_STATES+T_REPEAT,x
  beq @again
  sta SSG_STATES+T_REPEAT,x
  sep #$20
  lda [SSG_PTR],y
  sta SSG_STATES+T_LEFT,x
@again:
  sep #$20
  lda SSG_STATES+T_LEFT,x
  beq @finished
  dec
  sta SSG_STATES+T_LEFT,x
  rep #$20
  iny
  lda [SSG_PTR],y
  tay
  sep #$20
  bra ssg_header
@finished:
  rep #$20
  lda #$ffff
  sta SSG_STATES+T_REPEAT,x
  iny
  iny
  iny
  sep #$20
  bra ssg_header

; The list ends silent: AM off and both levels zero; counters keep running.
ssg_silence:
  lda #0
  sta SSG_STATES+T_ODDC,x
  ssg_out SSG_ODD, $a0
  lda #0
  ssg_out SSG_ODD, $40
  lda #0
  ssg_out SSG_EVEN, $40
  rts

; Pending commands are put here by the game's sound queue. The selected
; command replaces only the SSG parts its original program owns.
audio_ssg_command:
  lda z:SSG_PENDING_D
  bne :+
  rtl
:
  stz z:SSG_PENDING_D
  stz z:SSG_NEXT
  phb
  pha
  lda #$01
  pha
  plb
  pla
  rep #$20
  and #255
  cmp #64
  bcs @return16
  tax
  sep #$20
  lda f:SSG_COMMAND_INDEX,x
  cmp #255
  beq @return
  rep #$20
  and #255
  sta z:SSG_TEMP
  asl
  asl
  asl
  asl
  sec
  sbc z:SSG_TEMP                ; entry*15, then *2 = six five-byte records
  asl
  tay
  lda #.loword(SSG_COMMAND_ENTRIES)
  sta z:SSG_COMMAND_PTR
  sep #$20
  lda #^SSG_COMMAND_ENTRIES
  sta z:SSG_COMMAND_PTR+2
  rep #$20
  ldx #0
@part:
  stx z:SSG_SLOT
  lda [SSG_COMMAND_PTR],y
  sta z:SSG_PTR
  sep #$20
  iny
  iny
  lda [SSG_COMMAND_PTR],y
  sta z:SSG_PTR+2
  ora z:SSG_PTR
  ora z:SSG_PTR+1
  beq @skip
  iny
  rep #$20
  phy
  sep #$20
  jsr .loword(ssg_start)
  rep #$20
  ply
@skip16:
  ldx z:SSG_SLOT
  tya
  clc
  adc #2
  tay
  txa
  clc
  adc #32
  tax
  cmp #192
  bne @part
@return16:
  sep #$20
@return:
  plb
  rtl
@skip:
  iny
  rep #$20
  bra @skip16

; The six fixed slots do not need index arithmetic or a loop test per part.
audio_ssg_tick:
.a8
.i16
  lda z:SSG_ACTIVE_D
  bne :+
  rtl
:
  inc z:SSG_TIME
  lda z:SSG_NEXT
  beq @due
  dec z:SSG_NEXT
  rtl
@due:
  phb
  lda #$01
  pha
  plb
  lda #$ff
  sta z:SSG_NEXT
  .repeat 6,I
    ldx #I*32
    lda SSG_STATES+T_ACTIVE,x
    beq :+
    lda SSG_STATES+T_WAIT,x
    cmp z:SSG_TIME
    bne :+
    jsr .loword(ssg_due_record)
:
  .endrepeat
  ldx #0
@minimum:
  lda SSG_STATES+T_ACTIVE,x
  beq :+
  lda SSG_STATES+T_WAIT,x
  sec
  sbc z:SSG_TIME
  dec
  cmp z:SSG_NEXT
  bcs :+
  sta z:SSG_NEXT
:
  rep #$20
  txa
  clc
  adc #32
  tax
  sep #$20
  cpx #192
  bne @minimum
  plb
  rtl

; A due part consumes its record now; its next nonzero delay becomes an
; absolute deadline on the same SSG clock used by the fast path.
ssg_due_record:
  stx z:SSG_SLOT
  rep #$20
  lda SSG_STATES+T_BASE,x
  sta z:SSG_PTR
  lda SSG_STATES+T_PC,x
  tay
  sep #$20
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

