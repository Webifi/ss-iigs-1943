; FM part engine: the integers of scripts/fm_voice.py. Each tick adds ready
; slopes; crossfade levels and volumes update every second tick, odd parts
; on odd ticks. No multiply or divide runs. Records, tables and the capture
; choice come from scripts/fm_native.py. Callers: D=$1E00, DBR=0, A8/X16.
; Inside, DBR=$01 so the part state uses short indexed addressing.
.a8
.i16
FM_STATES = $8600              ; bank $01: six parts x 64 bytes
FM_MISSES = $87c2              ; bank $01: notes whose tables were not ready
FM_CACHE_PTR = $8780           ; active song's shared capture directory (3)
FM_CACHE_GEN = $8783           ; changed by IRQ when song changes
FM_CACHE_UPGEN = $8784         ; generation owned by main upload
FM_CACHE_DONE = $8785          ; entries completely in DOC
FM_CACHE_COUNT = $8786
FM_CACHE_INITIAL = $8787
FM_CACHE_RESUME = $8788
FM_CACHE_LIST = $8790          ; 2-byte header and up to 16 capture/page pairs
FM_LOOK_HINT = $87b2           ; main-loop stage lookahead requested
FM_LOOK_INDEX = $87b3          ; next safe boss-preload capture
FM_UP_KIND = $87b4             ; 0 current song, 1 lookahead
FM_ACTIVE_SONG = $87b5         ; score entry with phase bit cleared
FM_LOOK_KIND = $87b6            ; lookahead identity when index was reset
FM_UP_PAGE = $87b7              ; actual start page of the current upload
FM_UP_END = $87b8               ; exclusive end page of the current upload
FM_OWNER_START = $87b9          ; main-loop owner lookup scratch
FM_OWNER_END = $87ba
FM_PHASE_WAIT = $87bb          ; 1: arm score delay, 2: waiting for due
FM_PHASE_DUE = $87bc           ; earliest safe $2E capture-65 upload tick
FM_PRESERVED_OLD = $87be       ; score retained across repeated $2E cues
FM_SHORT_FLAGS = $87bf          ; shortened $2E capture-35/67 residency
FM_RESIDENT = $8810            ; 76 capture-completion flags; after held voices
FM_PAGE_OWNER = $885c          ; 144 FM pages, capture ID + 1 (0 empty)
FM_RESIDENT_END = $8d1c        ; 76 end pages, after world staging $8900-$8d1b
.assert FM_PAGE_OWNER+144 <= $8900, error, "FM ownership overlaps world staging"
.assert FM_RESIDENT_END >= $8d1c .and FM_RESIDENT_END+76 <= $9000, error, "FM end pages overlap world staging"
FM_RING_HEAD = $87c0
FM_RING_TAIL = $87c1
FM_UP_ACTIVE = $87c4           ; main-loop upload in progress
FM_UP_SRC = $87c5
FM_UP_DST = $87c8
FM_UP_LEFT = $87ca
FM_UP_CAP = $87cc
FM_UP_PART = $87cd
FM_UP_BUF = $87cf
FM_WAIT = $87d0                ; song start: score held until first tables load
FM_TICK = $87d1                ; score tick (low byte): visit schedule
FM_MOVED = $87d2               ; a stage changed during this visit
FM_UP_PACKED = $87d6
FM_UP_PREV = $87d7
FM_UP_BITS = $87d8
FM_UP_BLOCKS = $87d9
FM_UP_BYTE = $87da
FM_UP_AMOUNT = $87db           ; word
FM_UP_PAIRS = $87dd            ; number of packed pairs remaining
FM_HELD = $87e0                ; bank $01: per part, voice: freq lo, hi, table, size
FM_UP_PTR = $e8                ; main loop, D=0: upload source pointer
FM_PRE = $fc                   ; prefetch capture of the note being started
FM_SONG = $fd                  ; music_start: song/phase entry offset
FM_PTR = $f0                   ; direct page: record pointer (3)
FM_T0 = $f3
FM_T1 = $f5
FM_T2 = $f7
FM_V = $f9                     ; voice 0/1
FM_G = $fa                     ; register group
FM_VAL = $fb
FM_SILENT = 1023
FM_LOW = 64                    ; register table offset: levels down to -64

S_ACTIVE = 0
S_LAST = 1                     ; FM_TICK of the start or the last visit
S_PTR = 2                      ; record pointer (3)
S_BUFPAGE = 5                  ; DOC page of the playing buffer
S_ET = 6                       ; EG time in ticks
S_CL = 10                      ; curve level (hold EG, then release), 10.6
S_CS = 12                      ; slope of the current point
S_CG = 14                      ; goal of the current point
S_CP = 16                      ; record offset of the current point
S_CLEFT = 18                   ; ticks left in the point; 0 = curve done
S_CREM = 19                    ; points after the current one
S_OFFT = 20                    ; key-off tick (FM_TICK), with S_OFF
S_MASK = 21                    ; visit interval - 1
S_OFFATT = 22                  ; key-off level; 0 while the note is held
S_ALPHA = 24
S_STEP = 26                    ; alpha step of the current stage; 0 on the last
S_NEXT = 28                    ; tick of the next stage; $ffff on the last
S_RLEFT = 28                   ; after key-off: release ticks before the stop
S_ATTA = 30                    ; level of the current stage
S_ATTB = 32                    ; level of the next stage
S_BROW = 34                    ; boost table row: stage boost * 64
S_WA = 36                      ; voice levels; voice A plays the current stage
S_WB = 38
S_PRIA = 40                    ; last volume written; $ffff unknown
S_PRIB = 42
S_PEAK = 44
S_STGOFF = 46
S_CUR = 48
S_COUNT = 49
S_REL = 50
S_PLAY = 51
S_BUFM = 52                    ; capture in buffer 0 and 1, $ff empty
S_READY = 54                   ; buffer 0 and 1 hold that capture
S_SLOT = 56                    ; DOC page of buffer 0
S_OSC = 57
S_SYNC = 58
S_OFF = 59
S_VA = 60                      ; voice A = S_CUR & 1
S_PART = 61                    ; visits when (FM_TICK + part) & S_MASK = 0
S_VISITS = 62
S_TBASE = 8                    ; held-volume table offset in the record; 0 = stepping
S_BEGIN = 63                   ; attack tick the note started on

R_SIZE = 0
R_STAGES = 1
R_HOLD = 2
R_PEAK = 4
R_EVERY = 6                    ; visit interval in ticks
R_ENVN = 8
R_ATTN = 9
R_RELN = 10
R_HOLDN = 11
R_BYTES = 12
R_SOURCE = 14
R_STGOFF = 17
R_ENVOFF = 19
R_ATTOFF = 21
R_RELOFF = 23
R_HOLDOFF = 25
R_TABOFF = 27                  ; held-note volumes (voice A, B) by EG time; 0 none
R_TLEN = 29                    ; last EG time in that table
R_RBKT = 31                    ; key-off scan start per 16 EG ticks, 0..R_TLEN

; Attack entry: state of the note when it starts on that attack tick.
A_VALUE = 0                    ; hold-curve attenuation (scan key)
A_LEVEL = 2
A_POINT = 4                    ; current point and its ticks left
A_STAGE = 6
A_ALPHA = 7
A_BYTES = 9

; A8 = value; register = FM_V (oscillator) | reg. Writes it when it differs
; from FM_HELD+slot,y.
.macro fm_held slot, reg
  cmp FM_HELD+slot,y
  beq :+
  sta FM_HELD+slot,y
  sta FM_VAL
  lda FM_V
  ora #reg
  jsr .loword(fm_wr)
:
.endmacro

; A8 = value; FM_G = group (0 freq lo, 1 hi, 2 vol, 4 ptr, 5 ctl, 6 size);
; FM_V = voice. X = part state, preserved. DOC mode already selected.
fm_put:
.a8
  sta FM_VAL
  lda FM_G
  asl
  asl
  asl
  asl
  asl
  ora FM_STATES+S_OSC,x
  ora FM_V
; A8 = DOC register, FM_VAL = value.
fm_wr:
  sta FM_T2
@busy:
  lda f:$e0c03c
  bmi @busy
  lda FM_T2
  sta f:$e0c03e
  lda FM_VAL
  sta f:$e0c03d
  rts

fm_mode:
@busy:
  lda f:$e0c03c
  bmi @busy
  lda f:DOC_MASTER
  sta f:$e0c03c
  rts

.ifdef CONTINUOUS_GAME
.segment "SOUND_EXTRA"          ; startup only
.endif
fm_voice_init:
.a8
  phb
  lda #$01
  pha
  plb
  rep #$20
  ldx #382
  lda #0
@clear:
  sta FM_STATES,x
  dex
  dex
  bpl @clear
  stz FM_MISSES
  ldx #218                      ; 76 start pages + 144 ownership pages
@clear_cache:
  stz FM_RESIDENT,x
  dex
  dex
  bpl @clear_cache
  ldx #74                       ; 76 end pages, separate from world scratch
@clear_end:
  stz FM_RESIDENT_END,x
  dex
  dex
  bpl @clear_end
  sep #$20
  stz FM_CACHE_GEN
  stz FM_CACHE_UPGEN
  stz FM_CACHE_DONE
  stz FM_CACHE_COUNT
  stz FM_CACHE_RESUME
  stz FM_PHASE_WAIT
  stz FM_SHORT_FLAGS
  stz FM_PRESERVED_OLD
  stz FM_LOOK_HINT
  stz FM_LOOK_INDEX
  stz FM_UP_KIND
  stz FM_ACTIVE_SONG
  stz FM_LOOK_KIND
  stz FM_UP_ACTIVE
  stz FM_WAIT
  stz FM_TICK
  ldx #0
  ldy #0
  lda #FM_BASE_PAGE
  sta FM_VAL
@part:
  tya
  asl
  sta FM_STATES+S_OSC,x
  tya
  sta FM_STATES+S_PART,x
  lda #$ff
  sta FM_STATES+S_BUFM,x
  sta FM_STATES+S_BUFM+1,x
  lda FM_VAL
  sta FM_STATES+S_SLOT,x
  clc
  adc #24                       ; 6,144 bytes per part
  sta FM_VAL
  rep #$20
  txa
  clc
  adc #64
  tax
  sep #$20
  iny
  cpy #6
  bne @part
  ; frequency, size and table registers of the FM voices start at 0, so the
  ; held-value cache can skip unchanged writes from the first note on
  ldx #46
  lda #0
@held:
  sta FM_HELD,x
  sta FM_HELD+1,x
  dex
  dex
  bpl @held
@mode:
  lda f:$e0c03c
  bmi @mode
  lda f:DOC_MASTER
  sta f:$e0c03c
  ldx #0
@reg:
  txa
  ora #$00
  jsr .loword(@zero)
  txa
  ora #$20
  jsr .loword(@zero)
  txa
  ora #$80
  jsr .loword(@zero)
  txa
  ora #$c0
  jsr .loword(@zero)
  inx
  cpx #12
  bne @reg
  plb
  rtl
@zero:
  sta FM_T2                     ; register, value 0 (fm_wr's sequence)
@busy:
  lda f:$e0c03c
  bmi @busy
  lda FM_T2
  sta f:$e0c03e
  lda #0
  sta f:$e0c03d
  rts

.ifdef CONTINUOUS_GAME
.segment "SOUND"
.endif

; After an upload chunk: register mode again, so RAM mode marks an upload in
; progress for music_irq_entry.
fm_upload_register_mode:
.a8
  lda f:$e0c03c
  bmi fm_upload_register_mode
  lda f:DOC_MASTER
  sta f:$e0c03c
  rts

fm_load_ptr:
.a8
  rep #$20
  lda FM_STATES+S_PTR,x
  sta FM_PTR
  sep #$20
  lda FM_STATES+S_PTR+2,x
  sta FM_PTR+2
  rts

; A16 = A16 >> 6. An unsigned 16-bit value cannot exceed 1023 afterward.
fm_value:
.a16
  lsr
  lsr
  lsr
  lsr
  lsr
  lsr
  rts

; One step of the current curve: the hold EG, or the release after key-off.
fm_curve_step:
.a8
  lda FM_STATES+S_CLEFT,x
  beq @done
  rep #$21
  lda FM_STATES+S_CL,x
  adc FM_STATES+S_CS,x
  sta FM_STATES+S_CL,x
  sep #$20
  dec FM_STATES+S_CLEFT,x
  bne @done
  rep #$20
  lda FM_STATES+S_CG,x
  sta FM_STATES+S_CL,x
  sep #$20
  lda FM_STATES+S_CREM,x
  beq @done
  dec FM_STATES+S_CREM,x
  jsr .loword(fm_load_ptr)
  rep #$21
  lda FM_STATES+S_CP,x
  adc #6
  sta FM_STATES+S_CP,x
  tay
  lda [FM_PTR],y                ; ticks
  sep #$20
  sta FM_STATES+S_CLEFT,x
  rep #$20
  iny
  iny
  lda [FM_PTR],y
  sta FM_STATES+S_CS,x
  iny
  iny
  lda [FM_PTR],y
  sta FM_STATES+S_CG,x
  sep #$20
@done:
  rts

; A16 = carrier EG attenuation now (the release adds its key-off level).
fm_base:
.a8
  rep #$20
  lda FM_STATES+S_CL,x
  jsr .loword(fm_value)
  clc
  adc FM_STATES+S_OFFATT,x
  rts

; Cached fields of stage S_CUR (record: tick, page, boost, att, step).
; Carry set on the last stage, whose voice levels are then fixed; otherwise
; Y = record offset of the next stage.
fm_stage_load:
.a8
  lda FM_STATES+S_CUR,x
  and #1
  sta FM_STATES+S_VA,x
  rep #$20
  lda FM_STATES+S_CUR,x
  and #$ff
  asl
  asl
  asl
  clc
  adc FM_STATES+S_STGOFF,x
  tay
  iny
  iny
  iny
  lda [FM_PTR],y                ; boost
  and #$ff
  xba
  lsr
  lsr
  sta FM_STATES+S_BROW,x
  iny
  lda [FM_PTR],y
  sta FM_STATES+S_ATTA,x
  iny
  iny
  lda [FM_PTR],y
  sta FM_STATES+S_STEP,x
  iny
  iny
  sep #$20
  lda FM_STATES+S_CUR,x
  inc
  cmp FM_STATES+S_COUNT,x
  rep #$20
  bcs @last
  lda [FM_PTR],y
  sta FM_STATES+S_NEXT,x
  iny
  iny
  iny
  iny
  lda [FM_PTR],y
  sta FM_STATES+S_ATTB,x
  dey
  dey
  dey
  dey
  sep #$20
  clc
  rts
@last:
.a16
  lda #$ffff
  sta FM_STATES+S_NEXT,x
  lda FM_STATES+S_ATTA,x
  sta FM_STATES+S_WA,x
  lda #FM_SILENT
  sta FM_STATES+S_WB,x
  sep #$20
  sec
  rts

; Crossfade levels: A = att[cur] + WEIGHT[256-a] - boost,
; B = att[cur+1] + WEIGHT[a] - boost, a = alpha >> 8.
fm_weights:
.a8
  rep #$20
  txy
  lda FM_STATES+S_ALPHA,y
  xba
  and #$ff
  sta FM_T0
  lsr
  lsr
  clc
  adc FM_STATES+S_BROW,y
  tax
  lda f:fm_boost_table,x
  and #$ff
  sta FM_T2
  lda FM_T0
  asl
  asl
  tax
  lda f:fm_pair_table,x         ; WEIGHT[256-a]
  clc
  adc FM_STATES+S_ATTA,y
  sec
  sbc FM_T2
  sta FM_STATES+S_WA,y
  lda f:fm_pair_table+2,x       ; WEIGHT[a]
  clc
  adc FM_STATES+S_ATTB,y
  sec
  sbc FM_T2
  sta FM_STATES+S_WB,y
  tyx
  sep #$20
  rts

; Volume registers from the EG and the voice levels; each is written only
; when it changes. A silent EG makes both 0. X = part state (kept).
fm_volumes:
.a8
  rep #$20
  txy
  lda FM_STATES+S_CL,y
  lsr
  lsr
  lsr
  lsr
  lsr
  lsr
  clc
  adc FM_STATES+S_OFFATT,y
  cmp #FM_SILENT
  bcs @silent
  adc #FM_LOW
  bra :+
@silent:
  lda #$4000
:
  sta FM_T0
  clc
  adc FM_STATES+S_WA,y
  cmp #FM_SILENT+FM_LOW
  bcs @zero_a
  tax
  lda f:fm_register_table,x
  and #$ff
  bra :+
@zero_a:
  lda #0
:
  cmp FM_STATES+S_PRIA,y
  beq @b
  sta FM_STATES+S_PRIA,y
  sep #$20
  sta FM_VAL
@busy_a:
  lda f:$e0c03c
  bmi @busy_a
  lda FM_STATES+S_VA,y
  ora FM_STATES+S_OSC,y
  ora #$40
  sta f:$e0c03e
  lda FM_VAL
  sta f:$e0c03d
  rep #$20
@b:
  lda FM_T0
  clc
  adc FM_STATES+S_WB,y
  cmp #FM_SILENT+FM_LOW
  bcs @zero_b
  tax
  lda f:fm_register_table,x
  and #$ff
  bra :+
@zero_b:
  lda #0
:
  cmp FM_STATES+S_PRIB,y
  beq @done
  sta FM_STATES+S_PRIB,y
  sep #$20
  sta FM_VAL
@busy_b:
  lda f:$e0c03c
  bmi @busy_b
  lda FM_STATES+S_VA,y
  eor #1
  ora FM_STATES+S_OSC,y
  ora #$40
  sta f:$e0c03e
  lda FM_VAL
  sta f:$e0c03d
  tyx
  rts
@done:
  sep #$20
  tyx
  rts

; A halted oscillator is silent; its volume register need not change.
fm_stop:
.a8
  lda #3
  sta FM_VAL
  lda #$a0
  ora FM_STATES+S_OSC,x
  jsr .loword(fm_wr)
  lda #$a1
  ora FM_STATES+S_OSC,x
  jsr .loword(fm_wr)
  stz FM_STATES+S_ACTIVE,x
  rts

; Frequency, size and table registers keep their value while a voice is
; halted; write one only when it changes. A8 = value, FM_G = group 0, 1,
; 4 or 6, FM_V = voice, X = part state (kept).
fm_put_held:
.a8
  sta FM_VAL
  rep #$20
  lda FM_G
  and #$ff
  cmp #4
  bcc :+
  lsr                           ; table 4 -> 2, size 6 -> 3
:
  sta FM_T2
  lda FM_V
  and #$ff
  asl
  asl
  ora FM_T2
  sta FM_T2
  txa
  lsr
  lsr
  lsr                           ; part * 8
  ora FM_T2
  phx
  tax
  sep #$20
  lda FM_VAL
  cmp FM_HELD,x
  beq @same
  sta FM_HELD,x
  plx
  jmp .loword(fm_put)
@same:
  plx
  rts

; Key-off: the release curve measured for the nearest played hold to S_ET
; (the first of equals) starts from the hold curve's level.
fm_release_start:
.a8
  jsr .loword(fm_load_ptr)
  rep #$20
  lda FM_STATES+S_CL,x
  jsr .loword(fm_value)
  sta FM_STATES+S_OFFATT,x
  lda #$ffff
  sta FM_T1                     ; best distance
  ; start at the nearest hold of S_ET's 16-tick bucket; past the table, at
  ; the first hold
  ldy #R_TLEN
  lda [FM_PTR],y
  cmp FM_STATES+S_ET,x
  lda #0
  bcc @first
  lda FM_STATES+S_ET,x
  lsr
  lsr
  lsr
  lsr
  ldy #R_RBKT
  clc
  adc [FM_PTR],y
  tay
  lda [FM_PTR],y
  and #$ff
@first:
  sta FM_T2                     ; start index (the first hold replaces it)
  ldy #R_HOLDN
  lda [FM_PTR],y
  and #$ff
  sec
  sbc FM_T2
  sta FM_T0                     ; entries left
  lda FM_T2
  asl
  adc FM_T2                     ; 3 bytes a hold
  ldy #R_HOLDOFF
  adc [FM_PTR],y
  tay
@hold:
  lda [FM_PTR],y
  sec
  sbc FM_STATES+S_ET,x
  bpl :+
  eor #$ffff
  inc
:
  cmp FM_T1
  bcc @closer
  ; Holds are strictly increasing and below $8000. For a nonnegative
  ; elapsed time, their distance cannot improve after it first increases.
  ; Long-lived notes keep the original wrapped 16-bit scan.
  lda FM_STATES+S_ET,x
  bpl @hold_done
  bra @hold_next
@closer:
  sta FM_T1
  iny
  iny
  lda [FM_PTR],y
  and #$ff
  sta FM_T2                     ; best curve
  dey
  dey
@hold_next:
  iny
  iny
  iny
  dec FM_T0
  bne @hold
@hold_done:
  ; header at RELOFF + 8 * curve: start, count, pad, length, points offset
  lda FM_T2
  asl
  asl
  asl
  ldy #R_RELOFF
  clc
  adc [FM_PTR],y
  tay
  lda [FM_PTR],y
  sta FM_STATES+S_CL,x
  iny
  iny
  lda [FM_PTR],y
  and #$ff
  sta FM_T0                     ; points
  iny
  iny
  lda [FM_PTR],y
  sta FM_STATES+S_RLEFT,x
  iny
  iny
  lda [FM_PTR],y
  sta FM_STATES+S_CP,x
  tay
  sep #$20
  stz FM_STATES+S_CLEFT,x
  lda FM_T0
  beq @flat
  dec
  sta FM_STATES+S_CREM,x
  lda [FM_PTR],y
  sta FM_STATES+S_CLEFT,x
  rep #$20
  iny
  iny
  lda [FM_PTR],y
  sta FM_STATES+S_CS,x
  iny
  iny
  lda [FM_PTR],y
  sta FM_STATES+S_CG,x
  sep #$20
@flat:
  lda #1
  sta FM_STATES+S_REL,x
  ; the voice levels stay as they are at key-off
  lda FM_STATES+S_CUR,x
  inc
  cmp FM_STATES+S_COUNT,x
  bcs :+
  jsr .loword(fm_weights)
:
  rts

; Visit: the ticks after S_LAST up to FM_TICK in order, then volumes. Writes
; made by those ticks (stage change, release end) happen now.
fm_visit:
.a8
  lda FM_STATES+S_SYNC,x
  beq :+
  stz FM_STATES+S_SYNC,x
  stz FM_VAL
  lda #$a0
  ora FM_STATES+S_OSC,x
  jsr .loword(fm_wr)
:
  rep #$20
  lda FM_STATES+S_TBASE,x
  sep #$20
  beq fm_visit_generic
  jmp .loword(fm_tab_visit)
fm_visit_generic:
  stz FM_MOVED
  ; a full window (S_MASK + 1 = 2 or 4 ticks) with no key-off, curve
  ; point end, stage change or release end: one pass
  lda FM_TICK
  sec
  sbc FM_STATES+S_LAST,x
  sta FM_T1
  dec
  cmp FM_STATES+S_MASK,x
  bne @slow
  lda FM_STATES+S_OFF,x
  bne @slow
  lda FM_STATES+S_CLEFT,x
  beq :+
  cmp FM_T1
  beq @slow
  bcc @slow
:
.ifndef FM_FIXED_VISIT
  lda FM_T1
  cmp #2
  beq @window2
  cmp #4
  bne :+
  jmp .loword(@window4)
:
.endif
  jmp .loword(@window8)
@slow:
  jmp .loword(@tick)
@slow16:
  sep #$20
  jmp .loword(@tick)
.ifndef FM_FIXED_VISIT            ; every part visits each 8th tick otherwise
@window2:
  lda FM_STATES+S_REL,x
  bne @release2
  rep #$21
  lda FM_STATES+S_ET,x
  adc #2
  cmp FM_STATES+S_NEXT,x
  bcc :+
  jmp .loword(@slow16)                   ; a stage change in the window
:
  sta FM_STATES+S_ET,x
  lda FM_STATES+S_ALPHA,x
  clc
  adc FM_STATES+S_STEP,x
  bcs @full2
  clc
  adc FM_STATES+S_STEP,x
  bcs @full2
  bra @alpha2
@full2:
  lda #$ffff
@alpha2:
  sta FM_STATES+S_ALPHA,x
  sep #$20
  bra @curve2
@release2:
  rep #$20
  lda FM_STATES+S_RLEFT,x
  sec
  sbc #2
  beq :+
  bpl :++
:
  jmp .loword(@slow16)                   ; the release ends in the window
:
  sta FM_STATES+S_RLEFT,x
  sep #$20
@curve2:
  lda FM_STATES+S_CLEFT,x
  beq @done2
  sec
  sbc #2
  sta FM_STATES+S_CLEFT,x
  rep #$20
  lda FM_STATES+S_CL,x
  clc
  adc FM_STATES+S_CS,x
  clc
  adc FM_STATES+S_CS,x
  sta FM_STATES+S_CL,x
  sep #$20
@done2:
  lda FM_TICK
  sta FM_STATES+S_LAST,x
  jmp .loword(@visited)
@window4:
  lda FM_STATES+S_REL,x
  bne @release4
  rep #$21
  lda FM_STATES+S_ET,x
  adc #4
  cmp FM_STATES+S_NEXT,x
  bcc :+
  jmp .loword(@slow16)                   ; a stage change in the window
:
  sta FM_STATES+S_ET,x
  lda FM_STATES+S_ALPHA,x
  clc
  adc FM_STATES+S_STEP,x
  bcs @full4
  clc
  adc FM_STATES+S_STEP,x
  bcs @full4
  clc
  adc FM_STATES+S_STEP,x
  bcs @full4
  clc
  adc FM_STATES+S_STEP,x
  bcs @full4
  bra @alpha4
@full4:
  lda #$ffff
@alpha4:
  sta FM_STATES+S_ALPHA,x
  sep #$20
  bra @curve4
@release4:
  rep #$20
  lda FM_STATES+S_RLEFT,x
  sec
  sbc #4
  beq :+
  bpl :++
:
  jmp .loword(@slow16)                   ; the release ends in the window
:
  sta FM_STATES+S_RLEFT,x
  sep #$20
@curve4:
  lda FM_STATES+S_CLEFT,x
  beq @done4
  sec
  sbc #4
  sta FM_STATES+S_CLEFT,x
  rep #$20
  lda FM_STATES+S_CL,x
  clc
  adc FM_STATES+S_CS,x
  clc
  adc FM_STATES+S_CS,x
  clc
  adc FM_STATES+S_CS,x
  clc
  adc FM_STATES+S_CS,x
  sta FM_STATES+S_CL,x
  sep #$20
@done4:
  lda FM_TICK
  sta FM_STATES+S_LAST,x
  jmp .loword(@visited)
.endif
@window8:
  lda FM_STATES+S_REL,x
  bne @release8
  rep #$21
  lda FM_STATES+S_ET,x
  adc #8
  cmp FM_STATES+S_NEXT,x
  bcc :+
  jmp .loword(@slow16)                   ; a stage change in the window
:
  sta FM_STATES+S_ET,x
  ; eight saturating steps: full when the true sum reaches $10000
  lda FM_STATES+S_STEP,x
  cmp #$2000
  bcs @full8
  asl
  asl
  asl
  clc
  adc FM_STATES+S_ALPHA,x
  bcc @alpha8
@full8:
  lda #$ffff
@alpha8:
  sta FM_STATES+S_ALPHA,x
  sep #$20
  bra @curve8
@release8:
  rep #$20
  lda FM_STATES+S_RLEFT,x
  sec
  sbc #8
  beq :+
  bpl :++
:
  jmp .loword(@slow16)                   ; the release ends in the window
:
  sta FM_STATES+S_RLEFT,x
  sep #$20
@curve8:
  lda FM_STATES+S_CLEFT,x
  beq @done8
  sec
  sbc #8
  sta FM_STATES+S_CLEFT,x
  rep #$20
  lda FM_STATES+S_CS,x
  asl
  asl
  asl
  clc
  adc FM_STATES+S_CL,x
  sta FM_STATES+S_CL,x
  sep #$20
@done8:
  lda FM_TICK
  sta FM_STATES+S_LAST,x
  jmp .loword(@visited)
@tick:
  ; FM_T1 = ticks before the next event (key-off, curve point end, stage
  ; change, release end), at most the ticks left; two or more advance together
  lda FM_TICK
  sec
  sbc FM_STATES+S_LAST,x
  sta FM_T1
  lda FM_STATES+S_OFF,x
  beq :+
  lda FM_STATES+S_OFFT,x
  clc
  sbc FM_STATES+S_LAST,x
  cmp FM_T1
  bcs :+
  sta FM_T1
:
  lda FM_STATES+S_CLEFT,x
  beq :+
  dec
  cmp FM_T1
  bcs :+
  sta FM_T1
:
  rep #$20
  lda FM_STATES+S_REL,x
  and #$ff
  beq @hold_room
  lda FM_STATES+S_RLEFT,x
  bra @room
@hold_room:
  lda FM_STATES+S_NEXT,x
  sec
  sbc FM_STATES+S_ET,x
@room:
  dec
  cmp #8
  sep #$20
  bcs :+
  cmp FM_T1
  bcs :+
  sta FM_T1
:
  lda FM_T1
  cmp #2
  bcc @one_tick
  jmp .loword(@run)
@one_tick:
  lda FM_STATES+S_LAST,x
  inc
  sta FM_STATES+S_LAST,x
  lda FM_STATES+S_OFF,x
  beq @step
  lda FM_STATES+S_LAST,x
  cmp FM_STATES+S_OFFT,x
  bne @step
  stz FM_STATES+S_OFF,x
  jsr .loword(fm_off_step)
  bra @ticked
@step:
  jsr .loword(fm_step)
  bcs @stopped
@ticked:
  lda FM_STATES+S_LAST,x
  cmp FM_TICK
  bne @tick
@visited:
.if FM_WEIGHT_VISITS > 1
  inc FM_STATES+S_VISITS,x
.endif
  ; crossfade levels: frozen after key-off, fixed on the last stage
  lda FM_STATES+S_REL,x
  bne @volumes
  lda FM_STATES+S_CUR,x
  inc
  cmp FM_STATES+S_COUNT,x
  bcs @volumes
.if FM_WEIGHT_VISITS > 1
  lda FM_MOVED
  bne @weights
  lda FM_STATES+S_VISITS,x
  and #FM_WEIGHT_VISITS-1
  bne @volumes
.endif
@weights:
  jsr .loword(fm_weights)
@volumes:
  jmp .loword(fm_volumes)
@stopped:
  rts
@run:
.a8
  ; FM_T1 ticks with no event: the same sums as that many fm_step calls
  lda FM_STATES+S_LAST,x
  clc
  adc FM_T1
  sta FM_STATES+S_LAST,x
  rep #$20
  lda FM_T1
  and #$ff
  clc
  adc FM_STATES+S_ET,x
  sta FM_STATES+S_ET,x
  sep #$20
  lda FM_STATES+S_CLEFT,x
  beq @run_level
  sec
  sbc FM_T1
  sta FM_STATES+S_CLEFT,x
  rep #$20
  lda FM_T1
  and #$ff
  tay
  lda FM_STATES+S_CL,x
@run_curve:
  clc
  adc FM_STATES+S_CS,x
  dey
  bne @run_curve
  sta FM_STATES+S_CL,x
  sep #$20
@run_level:
  lda FM_STATES+S_REL,x
  bne @run_release
  rep #$20
  lda FM_T1
  and #$ff
  tay
  lda FM_STATES+S_ALPHA,x
@run_alpha:
  clc
  adc FM_STATES+S_STEP,x
  bcc :+
  lda #$ffff
  bra @run_alpha_done
:
  dey
  bne @run_alpha
@run_alpha_done:
  sta FM_STATES+S_ALPHA,x
  sep #$20
  bra @run_end
@run_release:
  rep #$20
  lda FM_T1
  and #$ff
  eor #$ffff
  sec
  adc FM_STATES+S_RLEFT,x
  sta FM_STATES+S_RLEFT,x
  sep #$20
@run_end:
  lda FM_STATES+S_LAST,x
  cmp FM_TICK
  beq :+
  jmp .loword(@tick)
:
  jmp .loword(@visited)

; One tick of a held or released note (not its key-off tick). Carry set
; when the release ends and the note stops.
fm_step:
.a8
  rep #$20
  inc FM_STATES+S_ET,x
  sep #$20
  lda FM_STATES+S_REL,x
  beq @hold
  jsr .loword(fm_curve_step)
  rep #$20
  dec FM_STATES+S_RLEFT,x
  sep #$20
  beq @end
  bmi @end
  clc
  rts
@end:
  jsr .loword(fm_stop)
  sec
  rts
@hold:
  ; the hold curve ends at the hold tick (scripts/fm_voice.py _cut)
  jsr .loword(fm_curve_step)
  rep #$20
  lda FM_STATES+S_ET,x
  cmp FM_STATES+S_NEXT,x
  bcs fm_move
  lda FM_STATES+S_ALPHA,x
  adc FM_STATES+S_STEP,x        ; carry clear from the compare
  bcc :+
  lda #$ffff
:
  sta FM_STATES+S_ALPHA,x
  sep #$20
  clc
  rts
; Stage change: stages are at least two ticks apart, so the fade restarts at
; 0 on the stage tick; the voices swap roles. Carry clear out.
fm_move:
  sep #$20
  jsr .loword(fm_load_ptr)
  inc FM_STATES+S_CUR,x
  lda #1
  sta FM_MOVED
  rep #$20
  stz FM_STATES+S_ALPHA,x
  lda FM_STATES+S_PRIA,x
  ldy FM_STATES+S_PRIB,x
  sta FM_STATES+S_PRIB,x
  tya
  sta FM_STATES+S_PRIA,x
  sep #$20
  jsr .loword(fm_stage_load)
  bcs @moved
  ; the next stage's voice: silent, then its table
  rep #$20
  stz FM_STATES+S_PRIB,x
  sep #$20
  stz FM_VAL
  lda FM_STATES+S_VA,x
  eor #1
  sta FM_V
  ora FM_STATES+S_OSC,x
  ora #$40
  jsr .loword(fm_wr)
  iny
  iny
  lda [FM_PTR],y
  clc
  adc FM_STATES+S_BUFPAGE,x
  pha
  lda #4
  sta FM_G
  pla
  jsr .loword(fm_put_held)
@moved:
  clc
  rts

; The key-off tick: the hold EG steps, the fade moves, then the release
; starts from that level.
fm_off_step:
.a8
  rep #$20
  inc FM_STATES+S_ET,x
  sep #$20
  jsr .loword(fm_curve_step)
  rep #$21
  lda FM_STATES+S_ALPHA,x
  adc FM_STATES+S_STEP,x
  bcc :+
  lda #$ffff
:
  sta FM_STATES+S_ALPHA,x
  sep #$20
  jmp .loword(fm_release_start)

; Visit of a held note in table mode: add the ticks, run the stage changes,
; write the table's volumes for this EG time. A pending key-off or a time
; past the table rebuilds the stepped state at the last visit, and the
; stepping engine plays this visit.
fm_tab_visit:
.a8
  lda FM_STATES+S_OFF,x
  beq @held
@exit:
  jsr .loword(fm_rebuild)
  jmp .loword(fm_visit_generic)
@held:
  jsr .loword(fm_load_ptr)
  lda FM_TICK
  sec
  sbc FM_STATES+S_LAST,x
  rep #$21
  and #$ff
  adc FM_STATES+S_ET,x
  ldy #R_TLEN
  cmp [FM_PTR],y
  sep #$20
  beq :+
  bcs @exit
:
  rep #$20
  sta FM_STATES+S_ET,x
  sep #$20
  lda FM_TICK
  sta FM_STATES+S_LAST,x
@stage:
  rep #$20
  lda FM_STATES+S_ET,x
  cmp FM_STATES+S_NEXT,x
  sep #$20
  bcc @volumes
  jsr .loword(fm_move)
  bra @stage
@volumes:
  rep #$21
  lda FM_STATES+S_ET,x
  asl
  adc FM_STATES+S_TBASE,x
  tay
  lda [FM_PTR],y                ; voice A, voice B
  sta FM_T0
  and #$ff
  cmp FM_STATES+S_PRIA,x
  beq @b
  sta FM_STATES+S_PRIA,x
  sep #$20
  sta FM_VAL
  lda FM_STATES+S_VA,x
  ora FM_STATES+S_OSC,x
  ora #$40
  jsr .loword(fm_wr)
  rep #$20
@b:
  lda FM_T0
  xba
  and #$ff
  cmp FM_STATES+S_PRIB,x
  beq @done
  sta FM_STATES+S_PRIB,x
  sep #$20
  sta FM_VAL
  lda FM_STATES+S_VA,x
  eor #1
  ora FM_STATES+S_OSC,x
  ora #$40
  jmp .loword(fm_wr)
@done:
  sep #$20
  rts

; Stepped state of a table-mode note at S_ET (its last visit), then stepping
; mode: the hold curve from its start entry by whole points and one multiply
; (the same 16-bit sums as that many steps), the fade as (S_ET - stage tick)
; * step, saturated as the steps saturate.
fm_rebuild:
.a8
  jsr .loword(fm_load_ptr)
  rep #$20
  stz FM_STATES+S_TBASE,x
  lda FM_STATES+S_BEGIN,x
  and #$ff
  sta FM_T1
  lda FM_STATES+S_ET,x
  sec
  sbc FM_T1
  sta FM_T1                     ; ticks to step
@point:
  sep #$20
  lda FM_STATES+S_CLEFT,x
  beq @fade                     ; the curve is done
  rep #$20
  and #$ff
  sta FM_T2
  lda FM_T1
  beq @fade
  cmp FM_T2
  bcc @inside
  sbc FM_T2
  sta FM_T1
  sep #$20
  lda #1
  sta FM_STATES+S_CLEFT,x
  jsr .loword(fm_curve_step)    ; ends the point, loads the next
  bra @point
@inside:
.a16
  sta FM_T2                     ; fewer ticks than the point has left
  lda FM_STATES+S_CS,x
  sta FM_T0
  lda #0
@mul:
  lsr FM_T2
  bcc :+
  clc
  adc FM_T0
:
  asl FM_T0
  ldy FM_T2
  bne @mul
  clc
  adc FM_STATES+S_CL,x
  sta FM_STATES+S_CL,x
  sep #$20
  lda FM_STATES+S_CLEFT,x
  sec
  sbc FM_T1
  sta FM_STATES+S_CLEFT,x
@fade:
  sep #$20
  lda FM_STATES+S_CUR,x
  inc
  cmp FM_STATES+S_COUNT,x
  bcs @done                     ; the last stage keeps its fade at 0
  rep #$20
  lda FM_STATES+S_CUR,x
  and #$ff
  asl
  asl
  asl
  adc FM_STATES+S_STGOFF,x      ; carry clear
  tay
  lda FM_STATES+S_ET,x
  sec
  sbc [FM_PTR],y                ; ticks since the stage tick
  sta FM_T1
  lda FM_STATES+S_STEP,x
  sta FM_T0
  lda #0
@fmul:
  lsr FM_T1
  bcc :+
  clc
  adc FM_T0
  bcs @full
:
  ldy FM_T1
  beq @alpha
  asl FM_T0
  bcc @fmul
@full:
  lda #$ffff
@alpha:
  sta FM_STATES+S_ALPHA,x
@done:
  sep #$20
  rts

; X = MUSIC_STATES part offset (DBR=0). Returns X = FM part state (DBR=1).
fm_part_x:
.a8
  rep #$20
  txa
  sec
  sbc f:MUSIC_SLOT
  asl                           ; 32-byte music part -> 64-byte FM part
  tax
  sep #$20
  rts

; Note on from the score: capture index (bit 7 tie) at +11, frequency +12.
music_voice_on:
.a8
  fm_mark 3
  phb
  lda #$01
  pha
  plb
  lda MUSIC_STATES&$ffff+19,x
  sta FM_T2                     ; tie flag
  lda MUSIC_STATES&$ffff+11,x
  sta FM_T2+1                   ; capture
  rep #$20
  lda MUSIC_STATES&$ffff+12,x
  sta FM_T1                     ; DOC frequency word
  sep #$20
  lda MUSIC_STATES&$ffff+14,x
  sta FM_PRE                    ; next different capture of this part
  jsr .loword(fm_part_x)
  jsr .loword(fm_mode)
  lda FM_T2
  beq @note
  lda FM_STATES+S_ACTIVE,x
  beq @done
  jsr .loword(fm_pitch)
@done:
  plb
  rtl
@note:
  lda FM_T2+1
  pha
  rep #$20
  lda FM_T1
  pha
  sep #$20
  jsr .loword(fm_start)
  fm_mark 4
  rep #$20
  pla
  sep #$20
  pla
  plb
  rtl

; Pitch change of a tied note: FM_T1 = frequency word.
fm_pitch:
.a8
  stz FM_V
@voice:
  lda #0
  sta FM_G
  lda FM_T1
  jsr .loword(fm_put_held)
  lda #1
  sta FM_G
  lda FM_T1+1
  jsr .loword(fm_put_held)
  inc FM_V
  lda FM_V
  cmp #2
  bcc @voice
  rts

; New note: 5,s = capture, 3,s..4,s = frequency word (pushed by caller).
fm_start:
.a8
  ; previous carrier level, then stop the previous note
  rep #$20
  lda #FM_SILENT
  sta FM_T0
  sep #$20
  lda FM_STATES+S_ACTIVE,x
  beq @silent
  rep #$20
  lda FM_STATES+S_TBASE,x
  sep #$20
  beq :+
  jsr .loword(fm_rebuild)       ; its curve at the last visit
:
  jsr .loword(fm_base)
.a16
  clc
  adc FM_STATES+S_PEAK,x        ; signed absolute level
  bmi :+
  cmp #FM_SILENT
  bcc :+
  lda #FM_SILENT
:
  sta FM_T0
  sep #$20
  jsr .loword(fm_stop)
@silent:
  ; record pointer and the buffer that holds this capture
  lda 5,s
  sta FM_VAL
  rep #$20
  and #$ff
  sta FM_T1
  asl
  adc FM_T1
  phx
  tax
  lda f:fm_records,x
  sta FM_PTR
  sep #$20
  lda f:fm_records+2,x
  sta FM_PTR+2
  plx
  rep #$20
  lda FM_PTR
  sta FM_STATES+S_PTR,x
  sep #$20
  lda FM_PTR+2
  sta FM_STATES+S_PTR+2,x
  jsr .loword(fm_buffer)
  ; fixed record fields
  rep #$20
  ldy #R_PEAK
  lda [FM_PTR],y
  sta FM_STATES+S_PEAK,x
  ldy #R_STGOFF
  lda [FM_PTR],y
  sta FM_STATES+S_STGOFF,x
  stz FM_STATES+S_OFFATT,x
  lda #$ffff
  sta FM_STATES+S_PRIA,x
  sta FM_STATES+S_PRIB,x
  ; attack start: first attack tick at or below the previous level; the
  ; last entry otherwise. A silent previous note starts at tick 0.
  ldy #R_ATTN
  lda [FM_PTR],y
  and #$ff
  sta FM_T1                     ; entries left
  stz FM_T2                     ; attack tick
  ldy #R_ATTOFF
  lda [FM_PTR],y
  tay
  lda FM_T0
  bmi :+
  cmp #FM_SILENT
  bcs @begun
:
  sec
  sbc FM_STATES+S_PEAK,x
  sta FM_T0
@scan:
  lda FM_T0
  bmi @next                     ; below every attack value
  lda [FM_PTR],y
  cmp FM_T0
  bcc @begun
  beq @begun
@next:
  dec FM_T1
  beq @begun
  inc FM_T2
  tya
  clc
  adc #A_BYTES
  tay
  bra @scan
@begun:
  ; the entry holds the hold curve, stage and fade at that tick
  lda FM_T2
  sta FM_STATES+S_ET,x
  iny
  iny
  lda [FM_PTR],y
  sta FM_STATES+S_CL,x
  iny
  iny
  lda [FM_PTR],y                ; point, ticks left
  sta FM_T1
  iny
  iny
  lda [FM_PTR],y
  sep #$20
  sta FM_STATES+S_CUR,x
  rep #$20
  iny
  lda [FM_PTR],y
  sta FM_STATES+S_ALPHA,x
  sep #$20
  lda FM_T1+1
  sta FM_STATES+S_CLEFT,x
  beq @curve_done
  ldy #R_ENVN
  lda [FM_PTR],y
  clc
  sbc FM_T1                     ; points after the current: n - 1 - point
  sta FM_STATES+S_CREM,x
  rep #$20
  lda FM_T1
  and #$ff
  asl
  sta FM_T1
  asl
  adc FM_T1                     ; point * 6
  ldy #R_ENVOFF
  adc [FM_PTR],y
  sta FM_STATES+S_CP,x
  tay
  iny
  iny
  lda [FM_PTR],y
  sta FM_STATES+S_CS,x
  iny
  iny
  lda [FM_PTR],y
  sta FM_STATES+S_CG,x
  sep #$20
@curve_done:
  ldy #R_STAGES
  lda [FM_PTR],y
  sta FM_STATES+S_COUNT,x
  stz FM_STATES+S_REL,x
  stz FM_STATES+S_OFF,x
  ; table pages: voice A (S_CUR & 1) plays stage cur, voice B the next
  ; stage (cur on the last)
  rep #$20
  lda FM_STATES+S_CUR,x
  and #$ff
  asl
  asl
  asl
  clc
  adc FM_STATES+S_STGOFF,x
  tay
  sep #$20
  iny
  iny
  lda [FM_PTR],y
  clc
  adc FM_STATES+S_BUFPAGE,x
  sta FM_T1
  sta FM_T1+1
  lda FM_STATES+S_CUR,x
  inc
  cmp FM_STATES+S_COUNT,x
  bcs :+
  rep #$21
  tya
  adc #8
  tay
  sep #$20
  lda [FM_PTR],y
  clc
  adc FM_STATES+S_BUFPAGE,x
  sta FM_T1+1
:
  lda FM_STATES+S_CUR,x
  lsr
  bcc :+
  lda FM_T1                     ; odd stage: voice 1 is A
  xba
  lda FM_T1+1
  sta FM_T1
  xba
  sta FM_T1+1
:
  ldy #R_SIZE
  lda [FM_PTR],y
  sta FM_G
  lda FM_STATES+S_OSC,x
  sta FM_V
  ; both voices are already halted: by the previous note's stop, its
  ; release end, or the song start. FM_HELD + part * 8 + voice * 4 holds
  ; frequency low, high, table and size.
  rep #$20
  txa
  lsr
  lsr
  lsr
  tay
  sep #$20
  lda 3,s                       ; return, frequency word, capture
  fm_held 0, $00
  lda 4,s
  fm_held 1, $20
  lda FM_G
  fm_held 3, $c0
  lda FM_T1
  fm_held 2, $80
  lda 3,s
  fm_held 4, $01
  lda 4,s
  fm_held 5, $21
  lda FM_G
  fm_held 7, $c1
  lda FM_T1+1
  fm_held 6, $81
  ; even voice syncs its partner for one tick
  lda #4
  sta FM_VAL
  lda #$a0
  ora FM_STATES+S_OSC,x
  jsr .loword(fm_wr)
  stz FM_VAL
  lda #$a1
  ora FM_STATES+S_OSC,x
  jsr .loword(fm_wr)
  lda #1
  sta FM_STATES+S_SYNC,x
  sta FM_STATES+S_ACTIVE,x
  lda FM_TICK
  sta FM_STATES+S_LAST,x
.if FM_WEIGHT_VISITS > 1
  stz FM_STATES+S_VISITS,x
.endif
  lda FM_STATES+S_ET,x
  sta FM_STATES+S_BEGIN,x
  rep #$20
  ldy #R_TABOFF
  lda [FM_PTR],y
  sta FM_STATES+S_TBASE,x
  sep #$20
  ldy #R_EVERY
  lda [FM_PTR],y
  dec
  sta FM_STATES+S_MASK,x
  jsr .loword(fm_stage_load)
  bcs :+
  jsr .loword(fm_weights)
:
  jsr .loword(fm_volumes)
  jmp .loword(fm_prefetch)

; Find this song's shared capture and check that its upload finished.
; Preserve the record pointer, which fm_start uses after this call.
fm_buffer:
.a8
  rep #$20
  lda FM_PTR
  pha
  lda FM_CACHE_PTR
  sta FM_PTR
  sep #$20
  lda FM_PTR+2
  pha
  lda FM_CACHE_PTR+2
  sta FM_PTR+2
  ldy #2
@search:
  lda [FM_PTR],y
  cmp FM_VAL
  beq @found
  iny
  iny
  tya
  lsr
  dec
  cmp FM_CACHE_COUNT
  bcc @search
  rep #$20
  inc FM_MISSES
  sep #$20
  bra @restore
@found:
  iny
  lda [FM_PTR],y
  sta FM_STATES+S_BUFPAGE,x
  pha                           ; actual page required by this song's plan
  phx
  rep #$20
  lda FM_VAL
  and #$ff
  tax
  sep #$20
  lda FM_RESIDENT,x
  plx
  cmp 1,s                       ; PLX changed flags; compare the required page
  beq :+
  rep #$20
  inc FM_MISSES
  sep #$20
:
  pla
@restore:
  pla
  sta FM_PTR+2
  rep #$20
  pla
  sta FM_PTR
  sep #$20
  rts

; The per-song plan schedules every distinct capture before first use.
fm_prefetch:
  rts

.ifdef CONTINUOUS_GAME
.segment "SOUND_EXTRA"
.endif
fm_song_start:
.a8
  fm_mark 9
  phb
  lda #$01
  pha
  plb
  stz FM_PHASE_WAIT
  lda FM_SONG
  and #$fc
  cmp #$38
  beq @short_valid
  cmp #$40                    ; $30 uses only short 35/67 in its score
  beq @short_valid
  cmp #$24                    ; retain them while $29 prepares $2E
  beq @short_valid
  cmp #$20                       ; retain ending-preloaded short $2E wave
  bne :+
  lda FM_ACTIVE_SONG
  cmp #$3c
  beq @short_valid
:
  lda FM_SHORT_FLAGS
  and #1
  beq :+
  stz FM_RESIDENT+35
:
  lda FM_SHORT_FLAGS
  and #2
  beq :+
  stz FM_RESIDENT+67
:
  stz FM_SHORT_FLAGS
@short_valid:
  lda FM_SONG
  and #$fc
  cmp #$38
  beq @maybe_repeat
  stz FM_PRESERVED_OLD
  bra @read_old
@maybe_repeat:
  lda FM_ACTIVE_SONG
  cmp #$38
  bne @read_old
  lda FM_PRESERVED_OLD
  bra @dispatch_old
@read_old:
  lda FM_ACTIVE_SONG
@dispatch_old:
  cmp #$20
  beq @from_28
  cmp #$24
  beq @from_29
  cmp #$40
  bne :+
  jmp .loword(@from_30)
:
  cmp #$28
  beq :+
  jmp .loword(@ordinary_plan)
:
  lda FM_SONG
  and #$fc
  cmp #$38                      ; song $2E interrupting $2A
  beq :+
  jmp .loword(@ordinary_plan)
:
  lda #$28
  sta FM_PRESERVED_OLD
  lda #$38
  sta FM_ACTIVE_SONG
  rep #$20
  lda #.loword(fm_alt_2a_2e)
  sta FM_CACHE_PTR
  sta FM_PTR
  sep #$20
  lda #^fm_alt_2a_2e
  sta FM_CACHE_PTR+2
  sta FM_PTR+2
  jmp .loword(@plan_ready)
@from_28:
  lda FM_SONG
  and #$fc
  cmp #$38
  bne @ordinary_plan
  lda #$20
  sta FM_PRESERVED_OLD
  lda #$38
  sta FM_ACTIVE_SONG
  rep #$20
  lda #.loword(fm_post28_2e)
  sta FM_CACHE_PTR
  sta FM_PTR
  sep #$20
  lda #^fm_post28_2e
  sta FM_CACHE_PTR+2
  sta FM_PTR+2
  jmp .loword(@plan_ready)
@from_29:
  lda FM_SONG
  and #$fc
  cmp #$38                      ; song $2E interrupting $29
  bne @ordinary_plan
  lda #$24
  sta FM_PRESERVED_OLD
  lda #$38
  sta FM_ACTIVE_SONG
  lda #1
  sta FM_PHASE_WAIT
  rep #$20
  lda #.loword(fm_boss2e)
  sta FM_CACHE_PTR
  sta FM_PTR
  sep #$20
  lda #^fm_boss2e
  sta FM_CACHE_PTR+2
  sta FM_PTR+2
  bra @plan_ready
@from_30:
  lda FM_SONG
  and #$fc
  cmp #$38                      ; song $2E interrupting $30
  bne @ordinary_plan
  lda #$40
  sta FM_PRESERVED_OLD
  lda #$38
  sta FM_ACTIVE_SONG
  rep #$20
  lda #.loword(fm_alt_30_2e)
  sta FM_CACHE_PTR
  sta FM_PTR
  sep #$20
  lda #^fm_alt_30_2e
  sta FM_CACHE_PTR+2
  sta FM_PTR+2
  bra @plan_ready
@ordinary_plan:
  lda FM_SONG
  and #$fc                    ; phase is bit 1 of score byte offset
  sta FM_ACTIVE_SONG
  cmp #$24
  bne :+
  lda #4
  sta FM_LOOK_HINT
:
  rep #$20
  lda FM_SONG
  lsr                           ; score entry is a byte offset in a word table
  sta FM_T0
  asl
  clc
  adc FM_T0
  tax
  lda f:fm_cache_plans,x
  sta FM_CACHE_PTR
  sta FM_PTR
  sep #$20
  lda f:fm_cache_plans+2,x
  sta FM_CACHE_PTR+2
  sta FM_PTR+2
@plan_ready:
  ; Copy the directory into the old ring reservation so the initial
  ; captures can be reordered when a suspended song resumes.
  ldy #0
  lda [FM_PTR],y
  sta FM_CACHE_COUNT
  rep #$20
  and #$ff
  asl
  clc
  adc #2
  sta FM_T0
  sep #$20
@dir_copy:
  lda [FM_PTR],y
  sta FM_CACHE_LIST,y
  iny
  cpy FM_T0
  bne @dir_copy
  lda FM_CACHE_LIST+1
  sta FM_CACHE_INITIAL
  lda FM_CACHE_RESUME
  beq @directory_ready
  stz FM_CACHE_INITIAL
  rep #$20
  lda f:MUSIC_SLOT
  tax
  sep #$20
@resume_part:
  lda f:MUSIC_STATES+15,x
  beq @resume_next
  lda f:MUSIC_STATES+11,x
  sta FM_T2
  phx
  ldx #0
@resume_find:
  lda FM_CACHE_LIST+2,x
  cmp FM_T2
  beq @resume_found
  inx
  inx
  txa
  lsr
  cmp FM_CACHE_COUNT
  bcc @resume_find
  bra @resume_skip
@resume_found:
  txa
  lsr
  cmp FM_CACHE_INITIAL
  bcc @resume_skip
  rep #$20
  lda FM_CACHE_LIST+2,x
  sta FM_T1
  sep #$20
  lda FM_CACHE_INITIAL
  rep #$20
  and #$ff
  asl
  tay
  lda FM_CACHE_LIST+2,y
  sta FM_CACHE_LIST+2,x
  lda FM_T1
  sta FM_CACHE_LIST+2,y
  sep #$20
  inc FM_CACHE_INITIAL
@resume_skip:
  plx
@resume_next:
  rep #$20
  txa
  clc
  adc #32
  tax
  sec
  sbc f:MUSIC_SLOT
  cmp #192
  sep #$20
  bne @resume_part
@directory_ready:
  rep #$20
  lda #FM_CACHE_LIST
  sta FM_CACHE_PTR
  sep #$20
  lda #1
  sta FM_CACHE_PTR+2
  stz FM_CACHE_DONE
  inc FM_CACHE_GEN
  ; Retain the press-time start fix: if every initial capture already lives
  ; at its planned page and no copy is in flight, the score need not wait.
  lda FM_UP_ACTIVE
  beq @ready_initial
  ; During the ending -> $28 -> $2E handoff, capture 37 is in a
  ; build-checked area disjoint from every $2E capture. If its old $28
  ; upload was interrupted, the active chunk may finish safely while the
  ; new generation cancels the remaining work on the next service call.
  lda FM_ACTIVE_SONG
  cmp #$38
  bne @must_wait
  lda FM_PRESERVED_OLD
  cmp #$20
  bne @must_wait
  lda FM_UP_KIND
  bne @must_wait
  lda FM_UP_CAP
  cmp #37
  bne @must_wait
  lda FM_UP_PAGE
  cmp #$d0                    ; builder checks this full range against $2E
  bne @must_wait
@ready_initial:
  lda FM_CACHE_DONE
  cmp FM_CACHE_INITIAL
  bcs @all_ready
  rep #$20
  and #$00ff
  asl
  tay
  sep #$20
  lda FM_CACHE_LIST+2,y
  rep #$20
  and #$00ff
  tax
  sep #$20
  lda FM_RESIDENT,x
  cmp FM_CACHE_LIST+3,y
  bne @must_wait
  inc FM_CACHE_DONE
  bra @ready_initial
@all_ready:
  stz FM_WAIT
  bra @ready_done
@must_wait:
  lda #1
  sta FM_WAIT
@ready_done:
  lda #$ff
  sta FM_TICK
  plb
  rtl

fm_song_wait:
.a8
  phb
  lda #$01
  pha
  plb
  lda FM_WAIT
  beq @go
  lda FM_CACHE_DONE
  cmp FM_CACHE_INITIAL
  bcc @hold
  stz FM_WAIT
@go:
  lda FM_PHASE_WAIT
  cmp #1
  bne :+
  lda #2
  sta FM_PHASE_WAIT
  rep #$20
  lda f:MUSIC_TICK
  clc
  adc #800                     ; score tick 768 has ended capture 67
  sta FM_PHASE_DUE
  sep #$20
:
  inc FM_TICK
  plb
  clc
  rtl
@hold:
  plb
  sec
  rtl

.ifdef CONTINUOUS_GAME
.segment "SOUND"
.endif
; Main loop, any D/DBR: copy at most 64 bytes of the current table upload.
; The sound IRQ saves and restores the GLU mode and address around its own
; register writes, so this copy can be interrupted at any byte.
fm_upload_service:
.a8
  php
  rep #$30
  pha
  phx
  phy
  phb
  phd
  lda #0
  tcd
  sep #$20
  lda #$01
  pha
  plb
  lda FM_CACHE_GEN
  cmp FM_CACHE_UPGEN
  beq fm_upload_generation_ready
  ; Adopt an in-progress $29 -> $2E gate preload if it is exactly the
  ; corresponding new directory entry. Earlier entries were completed in
  ; order, and the lookahead pages are disjoint from the outgoing score.
  php
  sei
  lda FM_CACHE_GEN
  cmp FM_CACHE_UPGEN
  beq fm_upload_generation_done
  lda FM_UP_ACTIVE
  beq fm_upload_generation_reset
  lda FM_UP_KIND
  cmp #4
  bne fm_upload_generation_reset
  lda FM_ACTIVE_SONG
  cmp #$38
  bne fm_upload_generation_reset
  lda FM_PRESERVED_OLD
  cmp #$24
  bne fm_upload_generation_reset
  lda FM_LOOK_INDEX
  cmp FM_CACHE_INITIAL
  bcs fm_upload_generation_reset
  rep #$20
  and #$00ff
  asl
  tax
  sep #$20
  lda FM_CACHE_LIST+2,x
  cmp FM_UP_CAP
  bne fm_upload_generation_reset
  lda FM_CACHE_LIST+3,x
  cmp FM_UP_PAGE
  bne fm_upload_generation_reset
  lda FM_LOOK_INDEX
  sta FM_CACHE_DONE
  stz FM_LOOK_INDEX           ; reset the new cue's old-song backfill cursor
  stz FM_UP_KIND
  lda FM_CACHE_GEN
  sta FM_CACHE_UPGEN
  bra fm_upload_generation_done
fm_upload_generation_reset:
  lda FM_CACHE_GEN
  sta FM_CACHE_UPGEN
  stz FM_UP_ACTIVE
  stz FM_LOOK_INDEX
fm_upload_generation_done:
  plp
fm_upload_generation_ready:
  lda FM_UP_ACTIVE
  beq fm_upload_local_idle_copy
  lda FM_UP_KIND
  beq fm_upload_local_continue_copy
  cmp #7
  beq fm_upload_local_post28_copy
  cmp #5
  beq fm_upload_local_restore_copy
  cmp #6
  bne fm_upload_local_normal_copy
fm_upload_local_restore_copy:
  lda FM_ACTIVE_SONG
  cmp #$38
  bne fm_upload_local_cancel_copy
  lda FM_PRESERVED_OLD
  cmp #$24
  beq fm_upload_local_continue_copy
  bra fm_upload_local_cancel_copy
fm_upload_local_post28_copy:
  lda FM_ACTIVE_SONG
  cmp #$38
  bne fm_upload_local_cancel_copy
  lda FM_PRESERVED_OLD
  cmp #$20
  beq fm_upload_local_continue_copy
fm_upload_local_cancel_copy:
  stz FM_UP_ACTIVE
  jmp .loword(fm_upload_return)
fm_upload_local_normal_copy:
  lda FM_LOOK_HINT
  cmp FM_UP_KIND
  beq fm_upload_local_continue_copy
  stz FM_UP_ACTIVE              ; canceled partial table is never resident
  jmp .loword(fm_upload_return)
fm_upload_local_continue_copy:
  jmp .loword(fm_upload_local_copy)
fm_upload_local_idle_copy:
  lda FM_CACHE_DONE
  cmp FM_CACHE_COUNT
  bcc :+
  jmp .loword(fm_upload_local_lookahead)
:
  stz FM_UP_KIND
  php
  sei
  lda FM_CACHE_GEN
  cmp FM_CACHE_UPGEN
  beq :+
  plp
  jmp .loword(fm_upload_return)
:
  lda FM_CACHE_DONE
  cmp FM_CACHE_COUNT
  bcc :+
  plp
  jmp .loword(fm_upload_return)
:
  ; Consume the next entry from the active cache directory. Page ownership
  ; is reserved atomically below before the upload becomes active.
  lda FM_CACHE_DONE
  rep #$20
  and #$ff
  asl
  clc
  adc #2
  tay
  lda FM_CACHE_PTR
  sta FM_UP_PTR
  sep #$20
  lda FM_CACHE_PTR+2
  sta FM_UP_PTR+2
  lda [FM_UP_PTR],y
  sta FM_UP_CAP
  iny
  lda [FM_UP_PTR],y
  sta FM_UP_DST+1
  sta FM_UP_PAGE
  stz FM_UP_DST
fm_upload_check_resident:
  lda FM_PHASE_WAIT
  beq fm_upload_local_phase_ready
  lda FM_UP_CAP
  cmp #65
  bne fm_upload_local_phase_ready
  lda FM_PHASE_WAIT
  cmp #2
  bne fm_upload_local_phase_defer
  rep #$20
  lda f:MUSIC_TICK
  sec
  sbc FM_PHASE_DUE
  bmi fm_upload_local_phase_defer16
  sep #$20
  bra fm_upload_local_phase_ready
fm_upload_local_phase_defer16:
  sep #$20
fm_upload_local_phase_defer:
  plp
  jml fm_lookahead_extra
fm_upload_local_phase_ready:
  phx
  rep #$20
  lda FM_UP_CAP
  and #$ff
  tax
  sep #$20
  lda FM_RESIDENT,x
  plx
  cmp FM_UP_PAGE               ; matching capture at this exact DOC page
  bne :+
  lda FM_UP_KIND
  bne fm_upload_local_skip_lookahead
  inc FM_CACHE_DONE             ; this exact capture survived the last song
  bra fm_upload_local_skipped
fm_upload_local_skip_lookahead:
  cmp #6
  beq fm_upload_local_skipped
  inc FM_LOOK_INDEX
fm_upload_local_skipped:
  plp
  jmp .loword(fm_upload_return)
:
  plp
  ; source and size from the capture's record
  lda FM_UP_CAP
  rep #$20
  and #$ff
  sta FM_UP_LEFT
  asl
  adc FM_UP_LEFT
  tax
  lda f:fm_records,x
  sta FM_UP_PTR
  sep #$20
  lda f:fm_records+2,x
  sta FM_UP_PTR+2
  rep #$20
  ldy #R_SOURCE
  lda [FM_UP_PTR],y
  sta FM_UP_SRC
  ldy #R_SOURCE+1
  lda [FM_UP_PTR],y
  sta FM_UP_SRC+1
  ldy #R_BYTES
  lda [FM_UP_PTR],y
  bpl fm_upload_local_raw_source
  and #$7fff
  sta FM_UP_LEFT
  sep #$20
  lda #1
  sta FM_UP_PACKED
  lda #128
  sta FM_UP_PREV
  bra fm_upload_local_source_ready
fm_upload_local_raw_source:
  sta FM_UP_LEFT
  sep #$20
  stz FM_UP_PACKED
fm_upload_local_source_ready:
  ; The IRQ may change songs while source metadata is read. Protect the
  ; shortened-resident flags and reservation with the same generation check.
  php
  sei
  lda FM_CACHE_GEN
  cmp FM_CACHE_UPGEN
  beq :+
  plp
  jmp .loword(fm_upload_return)
:
  jml fm_short_extra
fm_upload_local_whole_capture:
  lda FM_UP_LEFT+1              ; capture sizes are multiples of 256
  clc
  adc FM_UP_PAGE
  sta FM_UP_END
  ; Reserve each DOC page before writing, invalidating its previous owner.
  ; The generation check and reservation stay atomic.
  rep #$20
  lda FM_UP_LEFT
  xba
  and #$ff
  tay
  lda FM_UP_DST
  xba
  and #$ff
  sec
  sbc #FM_BASE_PAGE
  tax
  sep #$20
fm_upload_local_reserve_page:
  lda FM_PAGE_OWNER,x
  beq fm_upload_local_free_page
  dec
  phx
  rep #$20
  and #$ff
  tax
  sep #$20
  lda FM_RESIDENT,x
  sta FM_OWNER_START
  lda FM_RESIDENT_END,x
  sta FM_OWNER_END
  plx
  lda FM_OWNER_START
  beq fm_upload_local_free_page
  txa
  clc
  adc #FM_BASE_PAGE
  cmp FM_OWNER_START
  bcc fm_upload_local_free_page
  cmp FM_OWNER_END
  bcs fm_upload_local_free_page
  lda FM_PAGE_OWNER,x           ; a stale tag outside the current range
  dec                           ; must not invalidate a relocated copy
  phx
  rep #$20
  and #$ff
  tax
  sep #$20
  stz FM_RESIDENT,x
  plx
fm_upload_local_free_page:
  lda FM_UP_CAP
  inc
  sta FM_PAGE_OWNER,x
  inx
  dey
  bne fm_upload_local_reserve_page
  lda #1
  sta FM_UP_ACTIVE
  plp
fm_upload_local_copy:
  rep #$20
  lda FM_UP_LEFT
  cmp #64
  bcc :+
  lda #64
:
  tax
  lda FM_UP_SRC
  sta FM_UP_PTR
  sep #$20
  lda FM_UP_SRC+2
  sta FM_UP_PTR+2
fm_upload_local_ready:
  lda f:$e0c03c
  bmi fm_upload_local_ready
  lda f:DOC_MASTER
  ora #$60
  sta f:$e0c03c
  lda FM_UP_DST
  sta f:$e0c03e
  lda FM_UP_DST+1
  sta f:$e0c03f
  ldy #0
  lda FM_UP_PACKED
  beq fm_upload_local_byte
  jsl fm_unpack_chunk
  jsr .loword(fm_upload_register_mode)
  rep #$20
  lda #64
  bra fm_upload_local_advance
fm_upload_local_byte:
  lda f:$e0c03c
  bmi fm_upload_local_byte
  lda [FM_UP_PTR],y
  sta f:$e0c03d
  iny
  dex
  bne fm_upload_local_byte
  jsr .loword(fm_upload_register_mode)
  rep #$20
  tya
fm_upload_local_advance:
  sta FM_UP_AMOUNT
  clc
  adc FM_UP_DST
  sta FM_UP_DST
  tya
  clc
  adc FM_UP_SRC
  sta FM_UP_SRC
  sep #$20
  bcc :+
  inc FM_UP_SRC+2
:
  rep #$20
  lda FM_UP_AMOUNT
  eor #$ffff
  sec
  adc FM_UP_LEFT
  sta FM_UP_LEFT
  sep #$20
  bne fm_upload_return
  stz FM_UP_ACTIVE
  ; A song can change in an interrupt during the final chunk.
  php
  sei
  rep #$20
  lda FM_UP_CAP
  and #$ff
  tax
  sep #$20
  lda FM_UP_PAGE
  sta FM_RESIDENT,x
  lda FM_UP_END
  sta FM_RESIDENT_END,x
  lda FM_CACHE_GEN
  cmp FM_CACHE_UPGEN
  bne :+
  lda FM_UP_KIND
  bne fm_upload_local_done_lookahead
  inc FM_CACHE_DONE
  bra :+
fm_upload_local_done_lookahead:
  cmp #6
  beq :+
  inc FM_LOOK_INDEX
:
  plp
fm_upload_return:
  rep #$30
  pld
  plb
  ply
  plx
  pla
  plp
  rtl
fm_upload_local_lookahead:
  jml fm_lookahead_extra
.ifdef CONTINUOUS_GAME
.segment "SOUND_EXTRA"
.endif
fm_short_extra:
.a8
  ; The ending preloader may also prepare shortened cue capture 35.
  lda FM_ACTIVE_SONG
  cmp #$40                    ; all $30 copies of 35/67 use four stages
  beq fm_upload_local_short_check_cap
  cmp #$3c
  bne :+
  lda FM_UP_KIND
  cmp #2
  bne fm_short_done
  lda FM_UP_CAP
  cmp #35
  beq fm_upload_local_short_check_cap
  bra fm_short_done
:
  cmp #$24
  bne fm_upload_local_short_maybe_cue
  lda FM_UP_KIND
  cmp #4
  beq fm_upload_local_short_check_cap
  bra fm_short_done
fm_upload_local_short_maybe_cue:
  cmp #$38
  bne fm_short_done
  lda FM_PRESERVED_OLD
  cmp #$24
  beq fm_upload_local_short_check_cap
  cmp #$40
  beq fm_upload_local_short_check_cap
  cmp #$20
  bne fm_short_done
  lda FM_UP_CAP
  cmp #35
  bne fm_short_done
fm_upload_local_short_check_cap:
  lda FM_UP_CAP
  cmp #35
  bne :+
  lda #1
  bra fm_upload_local_short_mark
:
  cmp #67
  bne fm_short_done
  lda #2
fm_upload_local_short_mark:
  ora FM_SHORT_FLAGS
  sta FM_SHORT_FLAGS
  rep #$20
  lda #2048
  sta FM_UP_LEFT
  sep #$20
fm_short_done:
  jml fm_upload_local_whole_capture

fm_lookahead_extra:
.a8
  lda FM_ACTIVE_SONG
  cmp #$38
  beq :+
  jmp .loword(fm_lookahead_local_look_regular)
:
  lda FM_PRESERVED_OLD
  cmp #$20
  bne :+
  jmp .loword(fm_lookahead_local_post28_backfill)
:
  cmp #$24
  beq :+
  jmp .loword(fm_lookahead_local_look_regular)
:
  ; Restore the one overlapped capture first once the late cue has
  ; released it; before then, backfill every other $29 capture.
  lda FM_PHASE_WAIT
  cmp #2
  bne fm_lookahead_local_backfill
  rep #$20
  lda f:MUSIC_TICK
  sec
  sbc FM_PHASE_DUE
  bmi fm_lookahead_local_backfill16
  cmp #520
  sep #$20
  bcc fm_lookahead_local_backfill
  lda FM_RESIDENT+23
  cmp #FM_BOSS_RESTORE_PAGE
  beq fm_lookahead_local_backfill
  php
  sei
  lda FM_CACHE_GEN
  cmp FM_CACHE_UPGEN
  bne fm_lookahead_local_restore_cancel
  ldx #0
fm_lookahead_local_restore_voice:
  lda FM_STATES+S_ACTIVE,x
  beq :+
  lda FM_STATES+S_BUFPAGE,x
  cmp #FM_BOSS_RESTORE_PAGE
  beq fm_lookahead_local_restore_busy
:
  rep #$20
  txa
  clc
  adc #64
  tax
  cpx #384
  sep #$20
  bne fm_lookahead_local_restore_voice
  lda #6
  sta FM_UP_KIND
  lda #23
  sta FM_UP_CAP
  lda #FM_BOSS_RESTORE_PAGE
  sta FM_UP_PAGE
  sta FM_UP_DST+1
  stz FM_UP_DST
  jml fm_upload_check_resident
fm_lookahead_local_restore_cancel:
  plp
  jml fm_upload_return
fm_lookahead_local_restore_busy:
  plp
  jmp .loword(fm_lookahead_local_backfill)
fm_lookahead_local_backfill16:
  sep #$20
fm_lookahead_local_backfill:
  lda FM_LOOK_INDEX
  cmp #FM_BOSS_RESTORE_COUNT
  bcs fm_lookahead_local_exit
  php
  sei
  lda FM_CACHE_GEN
  cmp FM_CACHE_UPGEN
  bne fm_lookahead_local_restore_cancel
  lda FM_LOOK_INDEX
  rep #$20
  and #$00ff
  asl
  tax
  sep #$20
  lda f:fm_restore_boss,x
  sta FM_UP_CAP
  lda f:fm_restore_boss+1,x
  sta FM_UP_PAGE
  sta FM_UP_DST+1
  stz FM_UP_DST
  lda #5
  sta FM_UP_KIND
  jml fm_upload_check_resident
fm_lookahead_local_exit:
  jml fm_upload_return
fm_lookahead_local_post28_backfill:
  lda FM_LOOK_INDEX
  cmp #FM_POST28_RESTORE_COUNT
  bcs fm_lookahead_local_exit
  php
  sei
  lda FM_CACHE_GEN
  cmp FM_CACHE_UPGEN
  bne fm_lookahead_local_post28_cancel
  lda FM_LOOK_INDEX
  rep #$20
  and #$00ff
  asl
  tax
  sep #$20
  lda f:fm_restore_post28,x
  sta FM_UP_CAP
  lda f:fm_restore_post28+1,x
  sta FM_UP_PAGE
  sta FM_UP_DST+1
  stz FM_UP_DST
  lda #7
  sta FM_UP_KIND
  jml fm_upload_check_resident
fm_lookahead_local_post28_cancel:
  plp
  jml fm_upload_return
fm_lookahead_local_look_regular:
  lda FM_LOOK_HINT
  beq fm_lookahead_local_look_return
  cmp FM_LOOK_KIND
  beq :+
  sta FM_LOOK_KIND
  stz FM_LOOK_INDEX
:
  cmp #1
  beq fm_lookahead_local_check_boss
  cmp #2
  beq fm_lookahead_local_check_ending
  cmp #3
  beq fm_lookahead_local_check_camera
  cmp #4
  beq fm_lookahead_local_check_boss2e
  bra fm_lookahead_local_look_return
fm_lookahead_local_look_return:
  jml fm_upload_return
fm_lookahead_local_check_boss:
  lda FM_ACTIVE_SONG
  cmp #$40                       ; stage music $30, either score phase
  bne fm_lookahead_local_look_return
  lda FM_LOOK_INDEX
  cmp #FM_PRELOAD_COUNT
  bcs fm_lookahead_local_look_return
  bra fm_lookahead_local_look_lock
fm_lookahead_local_check_ending:
  lda FM_ACTIVE_SONG
  cmp #$3c                       ; ending music $2F, either phase
  bne fm_lookahead_local_look_return
  lda FM_LOOK_INDEX
  cmp #FM_ENDING_PRELOAD_COUNT
  bcs fm_lookahead_local_look_return
  bra fm_lookahead_local_look_lock
fm_lookahead_local_check_boss2e:
  lda FM_ACTIVE_SONG
  cmp #$24
  bne fm_lookahead_local_look_return
  lda FM_LOOK_INDEX
  cmp #FM_BOSS_GATE_COUNT
  bcs fm_lookahead_local_look_return
  bra fm_lookahead_local_look_lock
fm_lookahead_local_check_camera:
  lda FM_ACTIVE_SONG
  cmp #$08                       ; stage $22
  beq :+
  cmp #$10                       ; stage $24
  bne fm_lookahead_local_look_return
:
  lda FM_LOOK_INDEX
  bne fm_lookahead_local_look_return                    ; one safe urgent capture: 67
fm_lookahead_local_look_lock:
  php
  sei
  lda FM_CACHE_GEN
  cmp FM_CACHE_UPGEN
  beq :+
  jmp .loword(fm_lookahead_local_look_cancel)
:
  lda FM_LOOK_HINT
  cmp FM_LOOK_KIND
  beq :+
  jmp .loword(fm_lookahead_local_look_cancel)
:
  sta FM_UP_KIND
  lda FM_LOOK_INDEX
  rep #$20
  and #$ff
  asl
  tax
  sep #$20
  lda FM_LOOK_KIND
  cmp #2
  beq fm_lookahead_local_load_ending
  cmp #3
  beq fm_lookahead_local_load_camera
  cmp #4
  beq fm_lookahead_local_load_boss2e
  lda FM_ACTIVE_SONG
  cmp #$40
  bne fm_lookahead_local_look_cancel
  lda f:fm_preload_boss,x
  sta FM_UP_CAP
  lda f:fm_preload_boss+1,x
  bra fm_lookahead_local_look_selected
fm_lookahead_local_load_boss2e:
  lda FM_ACTIVE_SONG
  cmp #$24
  bne fm_lookahead_local_look_cancel
  lda f:fm_preload_boss2e,x
  sta FM_UP_CAP
  lda f:fm_preload_boss2e+1,x
  bra fm_lookahead_local_look_selected
fm_lookahead_local_load_ending:
  lda FM_ACTIVE_SONG
  cmp #$3c
  bne fm_lookahead_local_look_cancel
  lda f:fm_preload_ending,x
  sta FM_UP_CAP
  lda f:fm_preload_ending+1,x
  bra fm_lookahead_local_look_selected
fm_lookahead_local_load_camera:
  lda FM_ACTIVE_SONG
  cmp #$08
  beq :+
  cmp #$10
  bne fm_lookahead_local_look_cancel
:
  lda #67
  sta FM_UP_CAP
  lda #$f0                      ; built checked stable capture page
fm_lookahead_local_look_selected:
  sta FM_UP_DST+1
  sta FM_UP_PAGE
  stz FM_UP_DST
  jml fm_upload_check_resident
fm_lookahead_local_look_cancel:
  plp
  jml fm_upload_return

.ifdef CONTINUOUS_GAME
.segment "SOUND_EXTRA"
; Quiet-time ending preload and its cancellation at postgame handoff.
fm_ending_hint:
.a8
  lda CAB_ENDING_STEP
  cmp #3
  bcc :+
  lda #2
  sta f:$0187b2
:
  rtl
fm_ending_hint_clear:
.a8
  lda #0
  sta f:$0187b2
  rtl

; Stage 6 and 11 have a direct song-$30 -> $29 boss-result event. Start
; 128 event records ahead, stop at the cue, and never affect other stages.
fm_stage_hint:
.a8
  php
  phx
  lda f:$0187b5
  cmp #$24
  bne :+
  lda #4
  sta f:$0187b2
  plx
  plp
  rtl
:
  rep #$20
  lda CAMERA+$11
  tax
  sep #$20
  lda CAMERA_STAGE
  and #15
  cmp #2
  beq @camera3
  cmp #8
  beq @camera9
  cmp #13
  beq @camera14
  cmp #5
  bne @stage11
  cpx #618
  bcc @no_hint
  cpx #1392
  bcs @no_hint
  bra @set_hint
@stage11:
  cmp #10
  bne @no_hint
  cpx #840
  bcc @no_hint
  cpx #1614
  bcs @no_hint
@set_hint:
  lda #1
  sta f:$0187b2
  bra @hint_done
@camera3:
  cpx #204
  bcc @no_hint
  cpx #978
  bcs @no_hint
  bra @set_camera
@camera9:
  cpx #888
  bcc @no_hint
  cpx #1662
  bcs @no_hint
  bra @set_camera
@camera14:
  cpx #996
  bcc @no_hint
  cpx #1770
  bcs @no_hint
@set_camera:
  lda #3
  sta f:$0187b2
  bra @hint_done
@no_hint:
  lda #0
  sta f:$0187b2
@hint_done:
  plx
  plp
  rtl
.segment "SOUND"
.endif

music_voice_off:
.a8
  fm_mark 23
  phb
  lda #$01
  pha
  plb
  jsr .loword(fm_part_x)
  lda FM_STATES+S_ACTIVE,x
  beq :+
  lda FM_STATES+S_REL,x
  bne :+
  lda FM_STATES+S_OFF,x
  bne :+                        ; the first key-off counts
  lda FM_TICK
  cmp FM_STATES+S_LAST,x
  beq :+                        ; a key-off on the start tick does not act
  sta FM_STATES+S_OFFT,x
  lda #1
  sta FM_STATES+S_OFF,x
:
  plb
  rtl

music_all_off:
.a8
  phb
  lda #$01
  pha
  plb
  jsr .loword(fm_mode)
  ldx #0
@part:
  lda FM_STATES+S_ACTIVE,x
  beq :+
  jsr .loword(fm_stop)
:
  rep #$20
  txa
  clc
  adc #64
  tax
  sep #$20
  cpx #384
  bne @part
  plb
  rtl

music_voice_resume:
music_voice_frequency:
music_voice_volume:
music_voice_table:
.a8
  rtl

; Per tick, after the score: the parts whose visit falls on this tick.
fm_voice_tick:
.a8
  fm_mark 5
.ifdef FM_FIXED_VISIT
  ; Two of eight ticks have no part to visit, so avoid the bank switch.
  lda f:FM_TICK|$010000
  eor #$ff
  inc
  and #7
  cmp #6
  bcc :+
  rtl
:
  ; Convert (-tick) & 7 to the fixed 64-byte part offset.
  rep #$20
  and #$ff
  asl
  asl
  asl
  asl
  asl
  asl
  tax
  sep #$20
.endif
  phb
  lda #$01
  pha
  plb
.ifdef FM_FIXED_VISIT
  lda FM_STATES+S_ACTIVE,x
  beq @none
  lda FM_TICK
  cmp FM_STATES+S_LAST,x
  beq @none                     ; the note started this tick
  fm_mark 7
  ; The IRQ acknowledged the DOC in register mode before servicing music.
  jsr .loword(fm_visit)
  fm_mark 8
@none:
  plb
  rtl
.else
  ; visits fall on ticks where tick + part is even: parts of this parity
  lda FM_TICK
  and #1
  beq :+
  lda #64
:
  rep #$20
  and #$ff
  tax
  sep #$20
@part:
  lda FM_STATES+S_ACTIVE,x
  beq @next
  lda FM_TICK
  cmp FM_STATES+S_LAST,x
  beq @next                     ; the note started this tick
  clc
  adc FM_STATES+S_PART,x
  and FM_STATES+S_MASK,x
  bne @next
  fm_mark 7
  jsr .loword(fm_visit)
  fm_mark 8
@next:
  rep #$21
  txa
  adc #128
  tax
  sep #$20
  cpx #384
  bcc @part
  plb
  rtl
.endif

.ifdef CONTINUOUS_GAME
.segment "SOUND_EXTRA"
.endif
fm_unpack_chunk:
.a8
  ; TAX transfers the hidden B byte when X is 16-bit, so clear B once.
  rep #$20
  and #$00ff
  sep #$20
  ; Every packed chunk expands to exactly 64 bytes. Its four 16-byte
  ; blocks are independently raw or signed-nibble deltas from the prior byte.
  lda [FM_UP_PTR],y
  iny
  sta FM_UP_BITS
  lda #4
  sta FM_UP_BLOCKS
@block:
  lsr FM_UP_BITS
  bcs @delta_block
  ldx #16
@raw_byte:
  lda f:$e0c03c
  bmi @raw_byte
  lda [FM_UP_PTR],y
  iny
  sta f:$e0c03d
  dex
  bne @raw_byte
  sta FM_UP_PREV
  bra @block_done
@delta_block:
  lda #8
  sta FM_UP_PAIRS
@delta_pair:
  lda [FM_UP_PTR],y
  iny
  tax                         ; hidden B was cleared at chunk entry
@ready_low:
  lda f:$e0c03c
  bmi @ready_low
  lda f:fm_delta_low,x
  clc
  adc FM_UP_PREV
  sta FM_UP_PREV
  sta f:$e0c03d
@ready_high:
  lda f:$e0c03c
  bmi @ready_high
  lda f:fm_delta_high,x
  clc
  adc FM_UP_PREV
  sta FM_UP_PREV
  sta f:$e0c03d
  dec FM_UP_PAIRS
  bne @delta_pair
@block_done:
  dec FM_UP_BLOCKS
  bne @block
  rtl
.ifdef CONTINUOUS_GAME
.segment "SOUND"
.endif

.ifdef CONTINUOUS_GAME
.segment "SOUND_EXTRA"
.endif
.ifdef CONTINUOUS_GAME
.segment "SOUND"
.endif
