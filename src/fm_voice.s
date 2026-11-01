; The FM voices: the integer model of scripts/fm_voice.py. Each of the
; FM_PARTS parts plays its notes on a DOC oscillator pair: two voices that
; cross-fade between the captured stages of the arcade FM sound. Each tick
; adds ready slopes; the cross-fade levels and the volumes update at the
; part's visits. No multiply or divide runs. The records, the tables and the
; capture choice come from scripts/fm_native.py; the captures load into DOC
; RAM in the main loop (fm_upload_service). Levels are attenuations: 0 is
; loudest, FM_SILENT is silent. Callers: D = MUSIC_PAGE, DBR = 0, A8, X16.
; Inside, DBR = the bank of FM_STATES for short indexed addresses.
.a8
.i16
FM_SILENT = 1023
FM_LOW = 64                    ; register table offset: levels down to -64
FM_MUTE = $4000                ; an EG level so low that each voice is 0
FM_NO_CAPTURE = $ff            ; S_BUFM: an empty buffer
FM_PART_PAGES = 24             ; DOC RAM pages of a part: 6,144 bytes
FM_VOICES = FM_PART_VOICES*FM_PARTS ; the FM oscillators, from oscillator 0
FM_HELD_SIZE = 8               ; FM_HELD bytes of a part: two voices of four
FM_PART_VOICES = 2             ; the voices (oscillators) of a part
FM_PRI_UNKNOWN = $ffff         ; S_PRIA, S_PRIB: the volume register is not known
; A stage of a record (R_STGOFF): FM_STAGE_SIZE bytes.
STG_TICK = 0                   ; 2 bytes: the EG time of the stage
STG_PAGE = 2                   ; the DOC page of its table
STG_BOOST = 3                  ; its boost row
STG_ATT = 4                    ; 2 bytes: its level
STG_STEP = 6                   ; 2 bytes: the alpha step to the next stage
FM_STAGE_SIZE = 8
; A curve point (R_ENVOFF, release points): FM_POINT_SIZE bytes.
PT_TICKS = 0                   ; the ticks of the point
PT_SLOPE = 2                   ; 2 bytes: the level step each tick, 10.6
PT_GOAL = 4                    ; 2 bytes: the level at its end, 10.6
FM_POINT_SIZE = 6
; A release curve head (R_RELOFF): FM_RELEASE_SIZE bytes.
RL_START = 0                   ; 2 bytes: the first level, 10.6
RL_POINTS = 2                  ; the number of points
RL_LENGTH = 4                  ; 2 bytes: the release ticks
RL_OFFSET = 6                  ; 2 bytes: the record offset of the points
FM_RELEASE_SIZE = 8
; A hold (R_HOLDOFF): FM_HOLD_SIZE bytes: the EG time, the release curve.
FM_HOLD_SIZE = 3
FM_CHUNK = 64                  ; the bytes of one upload call (fm_native.pack_capture)
FM_BLOCK = 16                  ; a packed chunk: four blocks, raw or nibble deltas
FM_SHORT_BYTES = 2048          ; a shortened copy of capture 35 or 67
; FM_SONG entries (FM_ACTIVE_SONG, FM_PRESERVED_OLD): (command - SND_FM_FIRST)
; * 4; bit 1 is the phase, ENTRY_SONG keeps the song. The songs with their
; own capture plans (scripts/fm_native.py):
ENTRY_SONG = $fc
ENTRY_22 = ($22-SND_FM_FIRST)*4 ; stage music
ENTRY_24 = ($24-SND_FM_FIRST)*4 ; stage music
ENTRY_28 = (SND_GAME_OVER-SND_FM_FIRST)*4
ENTRY_29 = (SND_BOSS_RESULT-SND_FM_FIRST)*4
ENTRY_2A = (SND_BOSS_MUSIC-SND_FM_FIRST)*4
ENTRY_2E = (SND_CONTINUE_MUSIC-SND_FM_FIRST)*4
ENTRY_2F = ($2F-SND_FM_FIRST)*4 ; the ending music
ENTRY_30 = ($30-SND_FM_FIRST)*4 ; stage music
; The captures with special places in those plans:
CAP_23 = 23                    ; $29: capture 44 overwrites it; restored later
CAP_35 = 35                    ; shortened (FM_SHORT_BYTES) in some plans
CAP_37 = 37                    ; the ending, $28, $2E hand-off: at FM_PAGE_CAP37
CAP_65 = 65                    ; $29/$2E: uses the page of capture 67 after it
CAP_67 = 67                    ; shortened in some plans; stable at FM_PAGE_CAP67
SHORT_35 = 1                   ; FM_SHORT_FLAGS: capture 35 is the short copy
SHORT_67 = 2                   ; FM_SHORT_FLAGS: capture 67 is the short copy
; FM_UP_KIND: what the running upload is for. LOOK_* are also FM_LOOK_HINT.
UP_PLAN = 0                    ; the next FM_CACHE_LIST entry of the song
LOOK_BOSS = 1                  ; stage music $30: the $29 boss captures
LOOK_ENDING = 2                ; the ending music $2F: the next captures
LOOK_CAMERA = 3                ; stage music $22/$24: capture 67 for $2A
LOOK_BOSS2E = 4                ; $29: the $2E captures (the gate)
UP_RESTORE = 5                 ; $29 to $2E: the old $29 captures back
UP_RESTORE23 = 6               ; $29 to $2E: capture 23 back
UP_POST28 = 7                  ; $28 to $2E: the old $28 captures back
PHASE_DELAY = 800              ; MUSIC_TICKs to FM_PHASE_DUE: score tick 768 ended capture 67
RESTORE_DELAY = 520            ; MUSIC_TICKs after FM_PHASE_DUE before capture 23 returns

; An FM part record (FM_STATES, FM_PART_SIZE bytes; X = part * FM_PART_SIZE)
S_ACTIVE = 0                   ; nonzero while a note sounds
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
S_OFFATT = 22                  ; key-off level; 0 while the note is held
S_ALPHA = 24                   ; 2 bytes: the cross-fade, 8.8 (a = the high byte)
S_STEP = 26                    ; alpha step of the current stage; 0 on the last
S_NEXT = 28                    ; tick of the next stage; $ffff on the last
S_RLEFT = 28                   ; after key-off: release ticks before the stop
S_ATTA = 30                    ; level of the current stage
S_ATTB = 32                    ; level of the next stage
S_BROW = 34                    ; boost table row: stage boost * 64
S_WA = 36                      ; voice levels; voice A plays the current stage
S_WB = 38                      ; voice B plays the next stage
S_PRIA = 40                    ; last volume written, or FM_PRI_UNKNOWN
S_PRIB = 42
S_PEAK = 44                    ; 2 bytes: R_PEAK of the record
S_STGOFF = 46                  ; 2 bytes: R_STGOFF of the record
S_CUR = 48                     ; the current stage
S_COUNT = 49                   ; R_STAGES of the record
S_REL = 50                     ; nonzero after the key-off: the release
S_BUFM = 52                    ; capture in buffer 0 and 1, $ff empty
S_READY = 54                   ; buffer 0 and 1 hold that capture
S_SLOT = 56                    ; DOC page of buffer 0
S_OSC = 57                     ; the first oscillator of the pair: part * 2
S_SYNC = 58                    ; nonzero: start both oscillators at the visit
S_OFF = 59                     ; nonzero: a key-off waits for S_OFFT
S_VA = 60                      ; voice A = S_CUR & 1
S_TBASE = 8                    ; held-volume table offset in the record; 0 = stepping
S_BEGIN = 63                   ; attack tick the note started on

; A capture record (fm_records; scripts/fm_native.py record() builds it)
R_SIZE = 0                     ; the DOC table size register value
R_STAGES = 1                   ; the number of stages
R_HOLD = 2                     ; 2 bytes: the EG time of the hold
R_PEAK = 4                     ; 2 bytes: the peak level, signed
R_EVERY = 6                    ; visit interval in ticks
R_ENVN = 8                     ; the hold curve points
R_ATTN = 9                     ; the attack entries
R_RELN = 10                    ; the release curves
R_HOLDN = 11                   ; the holds
R_BYTES = 12                   ; 2 bytes: the table bytes; bit 15: packed
R_SOURCE = 14                  ; 3 bytes: the table data
R_STGOFF = 17                  ; 2 bytes each: the record offsets of the
R_ENVOFF = 19                  ; stages, the hold curve points,
R_ATTOFF = 21                  ; the attack entries,
R_RELOFF = 23                  ; the release curve heads
R_HOLDOFF = 25                 ; and the holds
R_TABOFF = 27                  ; held-note volumes (voice A, B) by EG time; 0 none
R_TLEN = 29                    ; last EG time in that table
R_RBKT = 31                    ; key-off scan start per 16 EG ticks, 0..R_TLEN

; Attack entry: state of the note when it starts on that attack tick.
A_VALUE = 0                    ; hold-curve attenuation (scan key)
A_LEVEL = 2                    ; S_CL of the note, 10.6
A_POINT = 4                    ; current point and its ticks left
A_STAGE = 6                    ; S_CUR
A_ALPHA = 7                    ; S_ALPHA
A_BYTES = 9                    ; the size of an entry

; fm_held: write A8 to the register FM_V (oscillator) | reg when it is not
; the value at FM_HELD+slot,y.
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

; fm_put: write A8 to the DOC register of group FM_G (0 frequency low, 1
; high, 2 volume, 4 wave page, 5 control, 6 table size; the register is
; FM_G * $20) of voice FM_V of the part X. The GLU is in register mode. JSR;
; X kept.
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
; fm_wr: write FM_VAL to the DOC register A8. JSR.
fm_wr:
  sta FM_T2
@busy:
  lda f:SOUNDCTL
  bmi @busy
  lda FM_T2
  sta f:SOUNDADRL
  lda FM_VAL
  sta f:SOUNDDATA
  rts

; fm_mode: the GLU goes to register mode. JSR.
fm_mode:
@busy:
  lda f:SOUNDCTL
  bmi @busy
  lda f:DOC_MASTER
  sta f:SOUNDCTL
  rts

.segment "SOUND_EXTRA"          ; startup only
; fm_voice_init: the FM start-up (music_irq_install). The part records and
; the capture state are cleared; each part gets its oscillator pair and its
; FM_PART_PAGES of DOC RAM from FM_BASE_PAGE; the frequency, wave and table
; registers of the FM voices start at 0, as FM_HELD says. JSL.
fm_voice_init:
.a8
  phb
  lda #^FM_STATES
  pha
  plb
  a16
  ldx #FM_PARTS*FM_PART_SIZE-2
  lda #0
@clear:
  sta FM_STATES,x
  dex
  dex
  bpl @clear
  ldx #FM_PAGE_OWNER_END-FM_RESIDENT-2 ; with FM_PAGE_OWNER
@clear_cache:
  stz FM_RESIDENT,x
  dex
  dex
  bpl @clear_cache
  ldx #FM_CAPTURES-2
@clear_end:
  stz FM_RESIDENT_END,x
  dex
  dex
  bpl @clear_end
  a8
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
  lda #FM_NO_CAPTURE
  sta FM_STATES+S_BUFM,x
  sta FM_STATES+S_BUFM+1,x
  lda FM_VAL
  sta FM_STATES+S_SLOT,x
  clc
  adc #FM_PART_PAGES
  sta FM_VAL
  a16
  txa
  clc
  adc #FM_PART_SIZE
  tax
  a8
  iny
  cpy #FM_PARTS
  bne @part
  ; The frequency, size and table registers of the FM voices start at 0, so
  ; FM_HELD can skip unchanged writes from the first note on.
  ldx #FM_PARTS*FM_HELD_SIZE-2
  lda #0
@held:
  sta FM_HELD,x
  sta FM_HELD+1,x
  dex
  dex
  bpl @held
@mode:
  lda f:SOUNDCTL
  bmi @mode
  lda f:DOC_MASTER
  sta f:SOUNDCTL
  ldx #0
@reg:
  txa
  ora #DOC_FREQ_LOW
  jsr .loword(@zero)
  txa
  ora #DOC_FREQ_HIGH
  jsr .loword(@zero)
  txa
  ora #DOC_WAVE
  jsr .loword(@zero)
  txa
  ora #DOC_TABLE
  jsr .loword(@zero)
  inx
  cpx #FM_VOICES
  bne @reg
  plb
  rtl
@zero:
  sta FM_T2                     ; the register A gets 0 (as fm_wr)
@busy:
  lda f:SOUNDCTL
  bmi @busy
  lda FM_T2
  sta f:SOUNDADRL
  lda #0
  sta f:SOUNDDATA
  rts

.segment "SOUND"

; fm_upload_register_mode: after an upload chunk, register mode again: RAM
; mode tells music_irq_entry that an upload runs. JSR.
fm_upload_register_mode:
.a8
  lda f:SOUNDCTL
  bmi fm_upload_register_mode
  lda f:DOC_MASTER
  sta f:SOUNDCTL
  rts

; fm_load_ptr: FM_PTR = the record of the part X. JSR.
fm_load_ptr:
.a8
  a16
  lda FM_STATES+S_PTR,x
  sta FM_PTR
  a8
  lda FM_STATES+S_PTR+2,x
  sta FM_PTR+2
  rts

; fm_value: A16 = A16 >> 6: a 10.6 level to its integer part. An unsigned
; 16-bit value cannot be more than 1023 after it. JSR.
fm_value:
.a16
  lsr
  lsr
  lsr
  lsr
  lsr
  lsr
  rts

; fm_curve_step: one tick of the current curve of the part X: the hold EG,
; or the release after the key-off. At the end of a point the next point
; starts. JSR.
fm_curve_step:
.a8
  lda FM_STATES+S_CLEFT,x
  beq @done
  rep #P_M8|P_CARRY       ; A 16 bits; clear carry
  lda FM_STATES+S_CL,x
  adc FM_STATES+S_CS,x
  sta FM_STATES+S_CL,x
  a8
  dec FM_STATES+S_CLEFT,x
  bne @done
  a16
  lda FM_STATES+S_CG,x
  sta FM_STATES+S_CL,x
  a8
  lda FM_STATES+S_CREM,x
  beq @done
  dec FM_STATES+S_CREM,x
  jsr .loword(fm_load_ptr)
  rep #P_M8|P_CARRY       ; A 16 bits; clear carry
  lda FM_STATES+S_CP,x
  adc #FM_POINT_SIZE
  sta FM_STATES+S_CP,x
  tay
  lda [FM_PTR],y                ; PT_TICKS
  a8
  sta FM_STATES+S_CLEFT,x
  a16
  iny
  iny
  lda [FM_PTR],y                ; PT_SLOPE
  sta FM_STATES+S_CS,x
  iny
  iny
  lda [FM_PTR],y                ; PT_GOAL
  sta FM_STATES+S_CG,x
  a8
@done:
  rts

; fm_base: A16 = the carrier EG level now (the release adds its key-off
; level). JSR.
fm_base:
.a8
  a16
  lda FM_STATES+S_CL,x
  jsr .loword(fm_value)
  clc
  adc FM_STATES+S_OFFATT,x
  rts

; fm_stage_load: the part fields of the stage S_CUR (S_VA, S_BROW, S_ATTA,
; S_STEP) and of the next stage (S_NEXT, S_ATTB). Returns carry 1 on the
; last stage, whose voice levels are then fixed; else carry 0 and Y = the
; record offset of the next stage. JSR.
fm_stage_load:
.a8
  lda FM_STATES+S_CUR,x
  and #1
  sta FM_STATES+S_VA,x
  a16
  lda FM_STATES+S_CUR,x
  and #$ff
  asl
  asl
  asl                           ; times FM_STAGE_SIZE
  clc
  adc FM_STATES+S_STGOFF,x
  tay
  iny
  iny
  iny
  lda [FM_PTR],y                ; STG_BOOST
  and #$ff
  xba
  lsr
  lsr                           ; times 64: a fm_boost_table row
  sta FM_STATES+S_BROW,x
  iny
  lda [FM_PTR],y                ; STG_ATT
  sta FM_STATES+S_ATTA,x
  iny
  iny
  lda [FM_PTR],y                ; STG_STEP
  sta FM_STATES+S_STEP,x
  iny
  iny
  a8
  lda FM_STATES+S_CUR,x
  inc
  cmp FM_STATES+S_COUNT,x
  a16
  bcs @last
  lda [FM_PTR],y                ; the next STG_TICK
  sta FM_STATES+S_NEXT,x
  iny
  iny
  iny
  iny
  lda [FM_PTR],y                ; the next STG_ATT
  sta FM_STATES+S_ATTB,x
  dey
  dey
  dey
  dey
  a8
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
  a8
  sec
  rts

; fm_weights: the cross-fade levels of the part X: S_WA = att[cur] +
; WEIGHT[256-a] - boost, S_WB = att[cur+1] + WEIGHT[a] - boost, a = alpha >> 8;
; the boost comes from the S_BROW row at a / 4. JSR; X kept.
fm_weights:
.a8
  a16
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
  asl                           ; two words an entry
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
  a8
  rts

; fm_volumes: the volume registers of the part X from the EG and the voice
; levels; each is written only when it changes. A silent EG makes both 0.
; JSR; X kept.
fm_volumes:
.a8
  a16
  txy
  lda FM_STATES+S_CL,y
  lsr
  lsr
  lsr
  lsr
  lsr
  lsr                           ; as fm_value
  clc
  adc FM_STATES+S_OFFATT,y
  cmp #FM_SILENT
  bcs @silent
  adc #FM_LOW
  bra :+
@silent:
  lda #FM_MUTE
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
  a8
  sta FM_VAL
@busy_a:
  lda f:SOUNDCTL
  bmi @busy_a
  lda FM_STATES+S_VA,y
  ora FM_STATES+S_OSC,y
  ora #DOC_VOLUME
  sta f:SOUNDADRL
  lda FM_VAL
  sta f:SOUNDDATA
  a16
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
  a8
  sta FM_VAL
@busy_b:
  lda f:SOUNDCTL
  bmi @busy_b
  lda FM_STATES+S_VA,y
  eor #1
  ora FM_STATES+S_OSC,y
  ora #DOC_VOLUME
  sta f:SOUNDADRL
  lda FM_VAL
  sta f:SOUNDDATA
  tyx
  rts
@done:
  a8
  tyx
  rts

; fm_stop: halt both oscillators of the part X; the note ends. A halted
; oscillator is silent: its volume register need not change. JSR.
fm_stop:
.a8
  lda #DOC_HALT|DOC_ONE_SHOT
  sta FM_VAL
  lda #DOC_CONTROL
  ora FM_STATES+S_OSC,x
  jsr .loword(fm_wr)
  lda #DOC_CONTROL+1             ; the second oscillator
  ora FM_STATES+S_OSC,x
  jsr .loword(fm_wr)
  stz FM_STATES+S_ACTIVE,x
  rts

; fm_put_held: as fm_put for the frequency, wave page and table size
; registers (FM_G 0, 1, 4 or 6), which keep their value while a voice is
; halted: the write happens only when FM_HELD has another value. FM_HELD
; entry: part * FM_HELD_SIZE + voice * 4 + (0, 1, 2 or 3). JSR; X kept.
fm_put_held:
.a8
  sta FM_VAL
  a16
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
  lsr                           ; part * FM_HELD_SIZE
  ora FM_T2
  phx
  tax
  a8
  lda FM_VAL
  cmp FM_HELD,x
  beq @same
  sta FM_HELD,x
  plx
  jmp .loword(fm_put)
@same:
  plx
  rts

; fm_release_start: the key-off of the part X: the release curve measured
; for the hold nearest to S_ET (the first of equals) starts from the level
; of the hold curve. JSR.
fm_release_start:
.a8
  jsr .loword(fm_load_ptr)
  a16
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
  lsr                           ; the bucket of 16 EG ticks
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
  adc FM_T2                     ; times FM_HOLD_SIZE
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
  ; The release head at R_RELOFF + curve * FM_RELEASE_SIZE.
  lda FM_T2
  asl
  asl
  asl
  ldy #R_RELOFF
  clc
  adc [FM_PTR],y
  tay
  lda [FM_PTR],y                ; RL_START
  sta FM_STATES+S_CL,x
  iny
  iny
  lda [FM_PTR],y                ; RL_POINTS
  and #$ff
  sta FM_T0
  iny
  iny
  lda [FM_PTR],y                ; RL_LENGTH
  sta FM_STATES+S_RLEFT,x
  iny
  iny
  lda [FM_PTR],y                ; RL_OFFSET
  sta FM_STATES+S_CP,x
  tay
  a8
  stz FM_STATES+S_CLEFT,x
  lda FM_T0
  beq @flat
  dec
  sta FM_STATES+S_CREM,x
  lda [FM_PTR],y
  sta FM_STATES+S_CLEFT,x
  a16
  iny
  iny
  lda [FM_PTR],y
  sta FM_STATES+S_CS,x
  iny
  iny
  lda [FM_PTR],y
  sta FM_STATES+S_CG,x
  a8
@flat:
  lda #1
  sta FM_STATES+S_REL,x
  ; The voice levels stay as they are at the key-off.
  lda FM_STATES+S_CUR,x
  inc
  cmp FM_STATES+S_COUNT,x
  bcs :+
  jsr .loword(fm_weights)
:
  rts

; fm_visit: the visit of the part X (fm_voice_tick): the ticks after S_LAST
; up to FM_TICK in order, then the volumes. The writes of those ticks (a
; stage change, the release end) happen now. A table record (S_TBASE) goes
; to fm_tab_visit. JSR.
fm_visit:
.a8
  lda FM_STATES+S_SYNC,x
  beq :+
  stz FM_STATES+S_SYNC,x
  stz FM_VAL
  lda #DOC_CONTROL
  ora FM_STATES+S_OSC,x
  jsr .loword(fm_wr)
:
  a16
  lda FM_STATES+S_TBASE,x
  a8
  beq fm_visit_generic
  jmp .loword(fm_tab_visit)
fm_visit_generic:
  ; A full window of FM_VISIT ticks with no key-off, curve point end, stage
  ; change or release end: one pass.
  lda FM_TICK
  sec
  sbc FM_STATES+S_LAST,x
  sta FM_T1
  cmp #FM_VISIT
  bne @slow
  lda FM_STATES+S_OFF,x
  bne @slow
  lda FM_STATES+S_CLEFT,x
  beq :+
  cmp FM_T1
  beq @slow
  bcc @slow
:
  jmp .loword(@window8)
@slow:
  jmp .loword(@tick)
@slow16:
  a8
  jmp .loword(@tick)
@window8:
  lda FM_STATES+S_REL,x
  bne @release8
  rep #P_M8|P_CARRY             ; A 16 bits; clear carry
  lda FM_STATES+S_ET,x
  adc #FM_VISIT
  cmp FM_STATES+S_NEXT,x
  bcc :+
  jmp .loword(@slow16)          ; a stage change in the window
:
  sta FM_STATES+S_ET,x
  ; FM_VISIT saturating steps: full when the true sum reaches $10000.
  lda FM_STATES+S_STEP,x
  cmp #$10000/FM_VISIT
  bcs @full8
  asl
  asl
  asl                           ; times FM_VISIT
  clc
  adc FM_STATES+S_ALPHA,x
  bcc @alpha8
@full8:
  lda #$ffff
@alpha8:
  sta FM_STATES+S_ALPHA,x
  a8
  bra @curve8
@release8:
  a16
  lda FM_STATES+S_RLEFT,x
  sec
  sbc #FM_VISIT
  beq :+
  bpl :++
:
  jmp .loword(@slow16)          ; the release ends in the window
:
  sta FM_STATES+S_RLEFT,x
  a8
@curve8:
  lda FM_STATES+S_CLEFT,x
  beq @done8
  sec
  sbc #FM_VISIT
  sta FM_STATES+S_CLEFT,x
  a16
  lda FM_STATES+S_CS,x
  asl
  asl
  asl                           ; times FM_VISIT
  clc
  adc FM_STATES+S_CL,x
  sta FM_STATES+S_CL,x
  a8
@done8:
  lda FM_TICK
  sta FM_STATES+S_LAST,x
  jmp .loword(@visited)
@tick:
  ; FM_T1 = the ticks before the next event (key-off, curve point end, stage
  ; change, release end), at most the ticks left; two or more go in one run.
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
  a16
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
  cmp #FM_VISIT
  a8
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
  ; The cross-fade levels: frozen after the key-off, fixed on the last stage.
  lda FM_STATES+S_REL,x
  bne @volumes
  lda FM_STATES+S_CUR,x
  inc
  cmp FM_STATES+S_COUNT,x
  bcs @volumes
@weights:
  jsr .loword(fm_weights)
@volumes:
  jmp .loword(fm_volumes)
@stopped:
  rts
@run:
.a8
  ; FM_T1 ticks with no event: the same sums as that many fm_step calls.
  lda FM_STATES+S_LAST,x
  clc
  adc FM_T1
  sta FM_STATES+S_LAST,x
  a16
  lda FM_T1
  and #$ff
  clc
  adc FM_STATES+S_ET,x
  sta FM_STATES+S_ET,x
  a8
  lda FM_STATES+S_CLEFT,x
  beq @run_level
  sec
  sbc FM_T1
  sta FM_STATES+S_CLEFT,x
  a16
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
  a8
@run_level:
  lda FM_STATES+S_REL,x
  bne @run_release
  a16
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
  a8
  bra @run_end
@run_release:
  a16
  lda FM_T1
  and #$ff
  eor #$ffff
  sec
  adc FM_STATES+S_RLEFT,x
  sta FM_STATES+S_RLEFT,x
  a8
@run_end:
  lda FM_STATES+S_LAST,x
  cmp FM_TICK
  beq :+
  jmp .loword(@tick)
:
  jmp .loword(@visited)

; fm_step: one tick of a held or released note of the part X (not its
; key-off tick). Returns carry 1 when the release ends and the note stops.
; JSR.
fm_step:
.a8
  a16
  inc FM_STATES+S_ET,x
  a8
  lda FM_STATES+S_REL,x
  beq @hold
  jsr .loword(fm_curve_step)
  a16
  dec FM_STATES+S_RLEFT,x
  a8
  beq @end
  bmi @end
  clc
  rts
@end:
  jsr .loword(fm_stop)
  sec
  rts
@hold:
  ; The hold curve ends at the hold tick (scripts/fm_voice.py _cut).
  jsr .loword(fm_curve_step)
  a16
  lda FM_STATES+S_ET,x
  cmp FM_STATES+S_NEXT,x
  bcs fm_move
  lda FM_STATES+S_ALPHA,x
  adc FM_STATES+S_STEP,x        ; carry clear from the compare
  bcc :+
  lda #$ffff
:
  sta FM_STATES+S_ALPHA,x
  a8
  clc
  rts
; fm_move: the stage change. Stages are at least two ticks apart, so the
; fade starts again at 0 on the stage tick; the voices change roles: the new
; next-stage voice is silent, then gets its table. Returns carry 0.
fm_move:
  a8
  jsr .loword(fm_load_ptr)
  inc FM_STATES+S_CUR,x
  a16
  stz FM_STATES+S_ALPHA,x
  lda FM_STATES+S_PRIA,x
  ldy FM_STATES+S_PRIB,x
  sta FM_STATES+S_PRIB,x
  tya
  sta FM_STATES+S_PRIA,x
  a8
  jsr .loword(fm_stage_load)
  bcs @moved
  a16
  stz FM_STATES+S_PRIB,x
  a8
  stz FM_VAL
  lda FM_STATES+S_VA,x
  eor #1
  sta FM_V
  ora FM_STATES+S_OSC,x
  ora #DOC_VOLUME
  jsr .loword(fm_wr)
  iny
  iny
  lda [FM_PTR],y                ; the next STG_PAGE
  clc
  adc FM_STATES+S_BUFPAGE,x
  pha
  lda #DOC_WAVE/$20
  sta FM_G
  pla
  jsr .loword(fm_put_held)
@moved:
  clc
  rts

; fm_off_step: the key-off tick of the part X: the hold EG steps, the fade
; moves, then the release starts from that level. JSR.
fm_off_step:
.a8
  a16
  inc FM_STATES+S_ET,x
  a8
  jsr .loword(fm_curve_step)
  rep #P_M8|P_CARRY       ; A 16 bits; clear carry
  lda FM_STATES+S_ALPHA,x
  adc FM_STATES+S_STEP,x
  bcc :+
  lda #$ffff
:
  sta FM_STATES+S_ALPHA,x
  a8
  jmp .loword(fm_release_start)

; fm_tab_visit: the visit of a held note in table mode (part X): add the
; ticks, run the stage changes, write the table's volumes for this EG time.
; A waiting key-off or a time past the table rebuilds the stepped state at
; the last visit, and the stepped visit plays this visit. JSR.
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
  rep #P_M8|P_CARRY       ; A 16 bits; clear carry
  and #$ff
  adc FM_STATES+S_ET,x
  ldy #R_TLEN
  cmp [FM_PTR],y
  a8
  beq :+
  bcs @exit
:
  a16
  sta FM_STATES+S_ET,x
  a8
  lda FM_TICK
  sta FM_STATES+S_LAST,x
@stage:
  a16
  lda FM_STATES+S_ET,x
  cmp FM_STATES+S_NEXT,x
  a8
  bcc @volumes
  jsr .loword(fm_move)
  bra @stage
@volumes:
  rep #P_M8|P_CARRY       ; A 16 bits; clear carry
  lda FM_STATES+S_ET,x
  asl                           ; two bytes an EG time
  adc FM_STATES+S_TBASE,x
  tay
  lda [FM_PTR],y                ; voice A, voice B
  sta FM_T0
  and #$ff
  cmp FM_STATES+S_PRIA,x
  beq @b
  sta FM_STATES+S_PRIA,x
  a8
  sta FM_VAL
  lda FM_STATES+S_VA,x
  ora FM_STATES+S_OSC,x
  ora #DOC_VOLUME
  jsr .loword(fm_wr)
  a16
@b:
  lda FM_T0
  xba
  and #$ff
  cmp FM_STATES+S_PRIB,x
  beq @done
  sta FM_STATES+S_PRIB,x
  a8
  sta FM_VAL
  lda FM_STATES+S_VA,x
  eor #1
  ora FM_STATES+S_OSC,x
  ora #DOC_VOLUME
  jmp .loword(fm_wr)
@done:
  a8
  rts

; fm_rebuild: the stepped state of a table-mode note of the part X at S_ET
; (its last visit); then the note is stepped. The hold curve goes from its
; start entry by whole points and one multiply (the same 16-bit sums as that
; many steps); the fade is (S_ET - stage tick) * step, saturated as the
; steps saturate. JSR.
fm_rebuild:
.a8
  jsr .loword(fm_load_ptr)
  a16
  stz FM_STATES+S_TBASE,x
  lda FM_STATES+S_BEGIN,x
  and #$ff
  sta FM_T1
  lda FM_STATES+S_ET,x
  sec
  sbc FM_T1
  sta FM_T1                     ; ticks to step
@point:
  a8
  lda FM_STATES+S_CLEFT,x
  beq @fade                     ; the curve is done
  a16
  and #$ff
  sta FM_T2
  lda FM_T1
  beq @fade
  cmp FM_T2
  bcc @inside
  sbc FM_T2
  sta FM_T1
  a8
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
  a8
  lda FM_STATES+S_CLEFT,x
  sec
  sbc FM_T1
  sta FM_STATES+S_CLEFT,x
@fade:
  a8
  lda FM_STATES+S_CUR,x
  inc
  cmp FM_STATES+S_COUNT,x
  bcs @done                     ; the last stage keeps its fade at 0
  a16
  lda FM_STATES+S_CUR,x
  and #$ff
  asl
  asl
  asl                           ; times FM_STAGE_SIZE
  adc FM_STATES+S_STGOFF,x      ; carry clear
  tay
  lda FM_STATES+S_ET,x
  sec
  sbc [FM_PTR],y                ; ticks since STG_TICK
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
  a8
  rts

; fm_part_x: X = the MUSIC_STATES part in the selected slot; returns X =
; the FM part record of the same part. JSR.
fm_part_x:
.a8
  a16
  txa
  sec
  sbc f:MUSIC_SLOT
  asl                           ; MUSIC_PART_SIZE to FM_PART_SIZE
  tax
  a8
  rts

; music_voice_on: the note of the music part X (music_event): a new note
; starts (fm_start); a tied note only changes its pitch. JSL.
; music_voice_resume: the note of the part X sounds again after a slot
; change (music_player_tick): music_all_off stopped every part, so it starts
; again, tied or not. JSL.
music_voice_resume:
.a8
  sec
  bra music_voice_start
music_voice_on:
.a8
  clc
music_voice_start:
  phb
  lda #^FM_STATES
  pha
  plb
  lda MUSIC_STATES+MS_TIE,x
  bcc :+
  lda #0                        ; a resumed note starts again
:
  sta FM_T2
  lda MUSIC_STATES+MS_CAPTURE,x
  sta FM_T2+1
  a16
  lda MUSIC_STATES+MS_FREQUENCY,x
  sta FM_T1
  a8
  lda MUSIC_STATES+MS_NEXT_CAPTURE,x
  sta FM_PRE
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
  a16
  lda FM_T1
  pha
  a8
  jsr .loword(fm_start)
  a16
  pla
  a8
  pla
  plb
  rtl

; fm_pitch: the pitch change of a tied note: both voices of the part X get
; the frequency word FM_T1. JSR.
fm_pitch:
.a8
  stz FM_V
@voice:
  lda #DOC_FREQ_LOW/$20
  sta FM_G
  lda FM_T1
  jsr .loword(fm_put_held)
  lda #DOC_FREQ_HIGH/$20
  sta FM_G
  lda FM_T1+1
  jsr .loword(fm_put_held)
  inc FM_V
  lda FM_V
  cmp #FM_PART_VOICES
  bcc @voice
  rts

; fm_start: a new note on the part X: 5,s = the capture, 3,s and 4,s = the
; frequency word (the caller pushes them). The attack starts from the level
; of the note before, which then stops. JSR.
fm_start:
.a8
  ; The carrier level of the note before, then it stops.
  a16
  lda #FM_SILENT
  sta FM_T0
  a8
  lda FM_STATES+S_ACTIVE,x
  beq @silent
  a16
  lda FM_STATES+S_TBASE,x
  a8
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
  a8
  jsr .loword(fm_stop)
@silent:
  ; The record and the buffer that holds this capture.
  lda 5,s
  sta FM_VAL
  a16
  and #$ff
  sta FM_T1
  asl
  adc FM_T1                     ; three bytes a fm_records entry
  phx
  tax
  lda f:fm_records,x
  sta FM_PTR
  a8
  lda f:fm_records+2,x
  sta FM_PTR+2
  plx
  a16
  lda FM_PTR
  sta FM_STATES+S_PTR,x
  a8
  lda FM_PTR+2
  sta FM_STATES+S_PTR+2,x
  jsr .loword(fm_buffer)
  a16
  ldy #R_PEAK
  lda [FM_PTR],y
  sta FM_STATES+S_PEAK,x
  ldy #R_STGOFF
  lda [FM_PTR],y
  sta FM_STATES+S_STGOFF,x
  stz FM_STATES+S_OFFATT,x
  lda #FM_PRI_UNKNOWN
  sta FM_STATES+S_PRIA,x
  sta FM_STATES+S_PRIB,x
  ; The attack starts at the first attack tick at or below the level before;
  ; else at the last entry. After a silent note it starts at tick 0.
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
  ; The entry holds the hold curve, the stage and the fade at that tick.
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
  a8
  sta FM_STATES+S_CUR,x
  a16
  iny
  lda [FM_PTR],y
  sta FM_STATES+S_ALPHA,x
  a8
  lda FM_T1+1
  sta FM_STATES+S_CLEFT,x
  beq @curve_done
  ldy #R_ENVN
  lda [FM_PTR],y
  clc
  sbc FM_T1                     ; points after the current: n - 1 - point
  sta FM_STATES+S_CREM,x
  a16
  lda FM_T1
  and #$ff
  asl
  sta FM_T1
  asl
  adc FM_T1                     ; point * FM_POINT_SIZE
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
  a8
@curve_done:
  ldy #R_STAGES
  lda [FM_PTR],y
  sta FM_STATES+S_COUNT,x
  stz FM_STATES+S_REL,x
  stz FM_STATES+S_OFF,x
  ; The table pages: voice A (S_CUR & 1) plays stage cur, voice B the next
  ; stage (cur on the last).
  a16
  lda FM_STATES+S_CUR,x
  and #$ff
  asl
  asl
  asl                           ; times FM_STAGE_SIZE
  clc
  adc FM_STATES+S_STGOFF,x
  tay
  a8
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
  rep #P_M8|P_CARRY             ; A 16 bits; clear carry
  tya
  adc #FM_STAGE_SIZE
  tay
  a8
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
  ; Both voices are halted already: by the stop of the note before, its
  ; release end, or the song start. FM_HELD + part * FM_HELD_SIZE + voice *
  ; 4 holds the frequency low, high, table and size.
  a16
  txa
  lsr
  lsr
  lsr                           ; part * FM_HELD_SIZE
  tay
  a8
  lda 3,s                       ; return, frequency word, capture
  fm_held 0, DOC_FREQ_LOW
  lda 4,s
  fm_held 1, DOC_FREQ_HIGH
  lda FM_G
  fm_held 3, DOC_TABLE
  lda FM_T1
  fm_held 2, DOC_WAVE
  lda 3,s
  fm_held 4, DOC_FREQ_LOW+1
  lda 4,s
  fm_held 5, DOC_FREQ_HIGH+1
  lda FM_G
  fm_held 7, DOC_TABLE+1
  lda FM_T1+1
  fm_held 6, DOC_WAVE+1
  ; The even voice syncs its partner until the visit (S_SYNC).
  lda #DOC_SYNC
  sta FM_VAL
  lda #DOC_CONTROL
  ora FM_STATES+S_OSC,x
  jsr .loword(fm_wr)
  stz FM_VAL
  lda #DOC_CONTROL+1             ; the second oscillator
  ora FM_STATES+S_OSC,x
  jsr .loword(fm_wr)
  lda #1
  sta FM_STATES+S_SYNC,x
  sta FM_STATES+S_ACTIVE,x
  lda FM_TICK
  sta FM_STATES+S_LAST,x
  lda FM_STATES+S_ET,x
  sta FM_STATES+S_BEGIN,x
  a16
  ldy #R_TABOFF
  lda [FM_PTR],y
  sta FM_STATES+S_TBASE,x
  a8
  jsr .loword(fm_stage_load)
  bcs :+
  jsr .loword(fm_weights)
:
  jmp .loword(fm_volumes)

; fm_buffer: S_BUFPAGE of the part X = the page of capture FM_VAL in the
; song's plan (FM_CACHE_PTR). The plan loads each capture before its first
; note. FM_PTR is kept: fm_start uses it after this call. JSR.
fm_buffer:
.a8
  a16
  lda FM_PTR
  pha
  lda FM_CACHE_PTR
  sta FM_PTR
  a8
  lda FM_PTR+2
  pha
  lda FM_CACHE_PTR+2
  sta FM_PTR+2
  ldy #2                        ; past the plan header
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
  bra @restore
@found:
  iny
  lda [FM_PTR],y
  sta FM_STATES+S_BUFPAGE,x
@restore:
  pla
  sta FM_PTR+2
  a16
  pla
  sta FM_PTR
  a8
  rts

.segment "SOUND_EXTRA"
; fm_song_start: start the capture plan of the song FM_SONG (music_start,
; a slot change, the title preload). Most songs use their fm_cache_plans
; directory; $2E after $28, $29, $2A or $30 uses a plan that keeps the old
; song's captures (FM_PRESERVED_OLD), as fm_native.py lays them out. The
; plan is copied to FM_CACHE_LIST; a resumed slot moves its sounding
; captures to the front. FM_WAIT holds the score until the first captures
; are loaded. JSL.
fm_song_start:
.a8
  phb
  lda #^FM_STATES
  pha
  plb
  stz FM_PHASE_WAIT
  ; The shortened copies of captures 35 and 67 stay valid only for the songs
  ; that use them; else they are not resident.
  lda FM_SONG
  and #ENTRY_SONG
  cmp #ENTRY_2E
  beq @short_valid
  cmp #ENTRY_30                 ; $30 uses only short 35/67 in its score
  beq @short_valid
  cmp #ENTRY_29                 ; keep them while $29 prepares $2E
  beq @short_valid
  cmp #ENTRY_28                 ; keep the short $2E wave the ending loaded
  bne :+
  lda FM_ACTIVE_SONG
  cmp #ENTRY_2F
  beq @short_valid
:
  lda FM_SHORT_FLAGS
  and #SHORT_35
  beq :+
  stz FM_RESIDENT+CAP_35
:
  lda FM_SHORT_FLAGS
  and #SHORT_67
  beq :+
  stz FM_RESIDENT+CAP_67
:
  stz FM_SHORT_FLAGS
@short_valid:
  lda FM_SONG
  and #ENTRY_SONG
  cmp #ENTRY_2E
  beq @maybe_repeat
  stz FM_PRESERVED_OLD
  bra @read_old
@maybe_repeat:
  lda FM_ACTIVE_SONG
  cmp #ENTRY_2E
  bne @read_old
  lda FM_PRESERVED_OLD          ; $2E again: the same old song
  bra @dispatch_old
@read_old:
  lda FM_ACTIVE_SONG
@dispatch_old:
  cmp #ENTRY_28
  beq @from_28
  cmp #ENTRY_29
  beq @from_29
  cmp #ENTRY_30
  bne :+
  jmp .loword(@from_30)
:
  cmp #ENTRY_2A
  beq :+
  jmp .loword(@ordinary_plan)
:
  lda FM_SONG
  and #ENTRY_SONG
  cmp #ENTRY_2E                 ; song $2E interrupting $2A
  beq :+
  jmp .loword(@ordinary_plan)
:
  lda #ENTRY_2A
  sta FM_PRESERVED_OLD
  lda #ENTRY_2E
  sta FM_ACTIVE_SONG
  a16
  lda #.loword(fm_alt_2a_2e)
  sta FM_CACHE_PTR
  sta FM_PTR
  a8
  lda #^fm_alt_2a_2e
  sta FM_CACHE_PTR+2
  sta FM_PTR+2
  jmp .loword(@plan_ready)
@from_28:
  lda FM_SONG
  and #ENTRY_SONG
  cmp #ENTRY_2E
  bne @ordinary_plan
  lda #ENTRY_28
  sta FM_PRESERVED_OLD
  lda #ENTRY_2E
  sta FM_ACTIVE_SONG
  a16
  lda #.loword(fm_post28_2e)
  sta FM_CACHE_PTR
  sta FM_PTR
  a8
  lda #^fm_post28_2e
  sta FM_CACHE_PTR+2
  sta FM_PTR+2
  jmp .loword(@plan_ready)
@from_29:
  lda FM_SONG
  and #ENTRY_SONG
  cmp #ENTRY_2E                 ; song $2E interrupting $29
  bne @ordinary_plan
  lda #ENTRY_29
  sta FM_PRESERVED_OLD
  lda #ENTRY_2E
  sta FM_ACTIVE_SONG
  lda #PHASE_ARM
  sta FM_PHASE_WAIT
  a16
  lda #.loword(fm_boss2e)
  sta FM_CACHE_PTR
  sta FM_PTR
  a8
  lda #^fm_boss2e
  sta FM_CACHE_PTR+2
  sta FM_PTR+2
  bra @plan_ready
@from_30:
  lda FM_SONG
  and #ENTRY_SONG
  cmp #ENTRY_2E                 ; song $2E interrupting $30
  bne @ordinary_plan
  lda #ENTRY_30
  sta FM_PRESERVED_OLD
  lda #ENTRY_2E
  sta FM_ACTIVE_SONG
  a16
  lda #.loword(fm_alt_30_2e)
  sta FM_CACHE_PTR
  sta FM_PTR
  a8
  lda #^fm_alt_30_2e
  sta FM_CACHE_PTR+2
  sta FM_PTR+2
  bra @plan_ready
@ordinary_plan:
  lda FM_SONG
  and #ENTRY_SONG
  sta FM_ACTIVE_SONG
  cmp #ENTRY_29
  bne :+
  lda #LOOK_BOSS2E
  sta FM_LOOK_HINT
:
  a16
  lda FM_SONG
  lsr                           ; the song/phase number
  sta FM_T0
  asl
  clc
  adc FM_T0                     ; three bytes a fm_cache_plans entry
  tax
  lda f:fm_cache_plans,x
  sta FM_CACHE_PTR
  sta FM_PTR
  a8
  lda f:fm_cache_plans+2,x
  sta FM_CACHE_PTR+2
  sta FM_PTR+2
@plan_ready:
  ; Copy the plan (the count, the initial count, then capture and page
  ; pairs) to FM_CACHE_LIST, so that a resumed song can put its sounding
  ; captures first.
  ldy #0
  lda [FM_PTR],y
  sta FM_CACHE_COUNT
  a16
  and #$ff
  asl
  clc
  adc #2                        ; the header
  sta FM_T0
  a8
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
  a16
  lda f:MUSIC_SLOT
  tax
  a8
@resume_part:
  lda f:MUSIC_STATES+MS_SOUNDING,x
  beq @resume_next
  lda f:MUSIC_STATES+MS_CAPTURE,x
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
  a16
  lda FM_CACHE_LIST+2,x
  sta FM_T1
  a8
  lda FM_CACHE_INITIAL
  a16
  and #$ff
  asl
  tay
  lda FM_CACHE_LIST+2,y
  sta FM_CACHE_LIST+2,x
  lda FM_T1
  sta FM_CACHE_LIST+2,y
  a8
  inc FM_CACHE_INITIAL
@resume_skip:
  plx
@resume_next:
  a16
  txa
  clc
  adc #MUSIC_PART_SIZE
  tax
  sec
  sbc f:MUSIC_SLOT
  cmp #MUSIC_SLOT_SIZE
  a8
  bne @resume_part
@directory_ready:
  a16
  lda #.loword(FM_CACHE_LIST)
  sta FM_CACHE_PTR
  a8
  lda #^FM_CACHE_LIST
  sta FM_CACHE_PTR+2
  stz FM_CACHE_DONE
  inc FM_CACHE_GEN
  ; When each initial capture is at its planned page already and no copy
  ; runs, the score need not wait.
  lda FM_UP_ACTIVE
  beq @ready_initial
  ; In the ending, $28, $2E hand-off, capture 37 is in a place that the
  ; build checks against every $2E capture. If its old $28 upload was
  ; stopped, the active chunk can end safely; the new generation stops the
  ; rest at the next service call.
  lda FM_ACTIVE_SONG
  cmp #ENTRY_2E
  bne @must_wait
  lda FM_PRESERVED_OLD
  cmp #ENTRY_28
  bne @must_wait
  lda FM_UP_KIND
  bne @must_wait                ; UP_PLAN
  lda FM_UP_CAP
  cmp #CAP_37
  bne @must_wait
  lda FM_UP_PAGE
  cmp #FM_PAGE_CAP37
  bne @must_wait
@ready_initial:
  lda FM_CACHE_DONE
  cmp FM_CACHE_INITIAL
  bcs @all_ready
  a16
  and #$00ff
  asl
  tay
  a8
  lda FM_CACHE_LIST+2,y
  a16
  and #$00ff
  tax
  a8
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
  lda #$ff                      ; the first FM tick is 0
  sta FM_TICK
  plb
  rtl

; fm_song_wait: one FM tick while a song starts (music_player_tick). While
; FM_WAIT holds and the initial captures are not loaded, returns carry 1:
; the score waits. PHASE_ARM sets FM_PHASE_DUE. Else FM_TICK counts and
; carry 0. JSL.
fm_song_wait:
.a8
  phb
  lda #^FM_STATES
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
  cmp #PHASE_ARM
  bne :+
  lda #PHASE_DUE
  sta FM_PHASE_WAIT
  a16
  lda f:MUSIC_TICK
  clc
  adc #PHASE_DELAY
  sta FM_PHASE_DUE
  a8
:
  inc FM_TICK
  plb
  clc
  rtl
@hold:
  plb
  sec
  rtl

.segment "SOUND"
; fm_upload_service: one call of the FM upload (audio_game_upload, the main
; loop, any D and DBR): copy at most FM_CHUNK bytes of the current capture
; to its DOC pages. The next upload comes from the song's plan
; (FM_CACHE_LIST), else from the lookahead. The sound interrupt keeps the
; GLU mode and address, so a copy can stop at any byte. FM_CACHE_GEN changes
; with each song: an upload of an old generation stops. JSL; registers kept.
fm_upload_service:
.a8
  php
  ax16
  pha
  phx
  phy
  phb
  phd
  lda #ZERO_PAGE
  tcd
  a8
  lda #^FM_STATES
  pha
  plb
  lda FM_CACHE_GEN
  cmp FM_CACHE_UPGEN
  beq fm_upload_generation_ready
  ; A running $29 to $2E gate preload continues when it is the same entry of
  ; the new plan: the entries before it are complete, and the lookahead pages
  ; do not touch the old song.
  php
  sei
  lda FM_CACHE_GEN
  cmp FM_CACHE_UPGEN
  beq fm_upload_generation_done
  lda FM_UP_ACTIVE
  beq fm_upload_generation_reset
  lda FM_UP_KIND
  cmp #LOOK_BOSS2E
  bne fm_upload_generation_reset
  lda FM_ACTIVE_SONG
  cmp #ENTRY_2E
  bne fm_upload_generation_reset
  lda FM_PRESERVED_OLD
  cmp #ENTRY_29
  bne fm_upload_generation_reset
  lda FM_LOOK_INDEX
  cmp FM_CACHE_INITIAL
  bcs fm_upload_generation_reset
  a16
  and #$00ff
  asl
  tax
  a8
  lda FM_CACHE_LIST+2,x
  cmp FM_UP_CAP
  bne fm_upload_generation_reset
  lda FM_CACHE_LIST+3,x
  cmp FM_UP_PAGE
  bne fm_upload_generation_reset
  lda FM_LOOK_INDEX
  sta FM_CACHE_DONE
  stz FM_LOOK_INDEX             ; the restore of the old song starts again
  stz FM_UP_KIND                ; UP_PLAN
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
  ; A running upload continues while its reason holds.
  lda FM_UP_ACTIVE
  beq fm_upload_local_idle_copy
  lda FM_UP_KIND
  beq fm_upload_local_continue_copy ; UP_PLAN
  cmp #UP_POST28
  beq fm_upload_local_post28_copy
  cmp #UP_RESTORE
  beq fm_upload_local_restore_copy
  cmp #UP_RESTORE23
  bne fm_upload_local_normal_copy
fm_upload_local_restore_copy:
  lda FM_ACTIVE_SONG
  cmp #ENTRY_2E
  bne fm_upload_local_cancel_copy
  lda FM_PRESERVED_OLD
  cmp #ENTRY_29
  beq fm_upload_local_continue_copy
  bra fm_upload_local_cancel_copy
fm_upload_local_post28_copy:
  lda FM_ACTIVE_SONG
  cmp #ENTRY_2E
  bne fm_upload_local_cancel_copy
  lda FM_PRESERVED_OLD
  cmp #ENTRY_28
  beq fm_upload_local_continue_copy
fm_upload_local_cancel_copy:
  stz FM_UP_ACTIVE
  jmp .loword(fm_upload_return)
fm_upload_local_normal_copy:
  lda FM_LOOK_HINT
  cmp FM_UP_KIND
  beq fm_upload_local_continue_copy
  stz FM_UP_ACTIVE              ; a stopped table is never resident
  jmp .loword(fm_upload_return)
fm_upload_local_continue_copy:
  jmp .loword(fm_upload_local_copy)
fm_upload_local_idle_copy:
  lda FM_CACHE_DONE
  cmp FM_CACHE_COUNT
  bcc :+
  jmp .loword(fm_upload_local_lookahead)
:
  stz FM_UP_KIND                ; UP_PLAN
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
  ; The next entry of the plan. Its pages are reserved below, with
  ; interrupts off, before the upload becomes active.
  lda FM_CACHE_DONE
  a16
  and #$ff
  asl
  clc
  adc #2
  tay
  lda FM_CACHE_PTR
  sta FM_UP_PTR
  a8
  lda FM_CACHE_PTR+2
  sta FM_UP_PTR+2
  lda [FM_UP_PTR],y
  sta FM_UP_CAP
  iny
  lda [FM_UP_PTR],y
  sta FM_UP_DST+1
  sta FM_UP_PAGE
  stz FM_UP_DST
; fm_upload_check_resident: FM_UP_CAP to FM_UP_PAGE (FM_UP_KIND): skip it
; when it is there already, else start its upload. Capture 65 waits for
; FM_PHASE_DUE: it takes the page of capture 67. Interrupts are off.
fm_upload_check_resident:
  lda FM_PHASE_WAIT
  beq fm_upload_local_phase_ready
  lda FM_UP_CAP
  cmp #CAP_65
  bne fm_upload_local_phase_ready
  lda FM_PHASE_WAIT
  cmp #PHASE_DUE
  bne fm_upload_local_phase_defer
  a16
  lda f:MUSIC_TICK
  sec
  sbc FM_PHASE_DUE
  bmi fm_upload_local_phase_defer16
  a8
  bra fm_upload_local_phase_ready
fm_upload_local_phase_defer16:
  a8
fm_upload_local_phase_defer:
  plp
  jml fm_lookahead_extra
fm_upload_local_phase_ready:
  phx
  a16
  lda FM_UP_CAP
  and #$ff
  tax
  a8
  lda FM_RESIDENT,x
  plx
  cmp FM_UP_PAGE                ; the capture is at this page already
  bne :+
  lda FM_UP_KIND
  bne fm_upload_local_skip_lookahead
  inc FM_CACHE_DONE             ; it stayed from the song before
  bra fm_upload_local_skipped
fm_upload_local_skip_lookahead:
  cmp #UP_RESTORE23
  beq fm_upload_local_skipped
  inc FM_LOOK_INDEX
fm_upload_local_skipped:
  plp
  jmp .loword(fm_upload_return)
:
  plp
  ; The source and the size from the capture's record.
  lda FM_UP_CAP
  a16
  and #$ff
  sta FM_UP_LEFT
  asl
  adc FM_UP_LEFT                ; three bytes a fm_records entry
  tax
  lda f:fm_records,x
  sta FM_UP_PTR
  a8
  lda f:fm_records+2,x
  sta FM_UP_PTR+2
  a16
  ldy #R_SOURCE
  lda [FM_UP_PTR],y
  sta FM_UP_SRC
  ldy #R_SOURCE+1
  lda [FM_UP_PTR],y
  sta FM_UP_SRC+1
  ldy #R_BYTES
  lda [FM_UP_PTR],y
  bpl fm_upload_local_raw_source
  and #$7fff                    ; bit 15: packed
  sta FM_UP_LEFT
  a8
  lda #1
  sta FM_UP_PACKED
  lda #DOC_SILENCE              ; the first delta starts from the zero level
  sta FM_UP_PREV
  bra fm_upload_local_source_ready
fm_upload_local_raw_source:
  sta FM_UP_LEFT
  a8
  stz FM_UP_PACKED
fm_upload_local_source_ready:
  ; The interrupt can change the song while the record is read: the short
  ; flags and the page reservation follow the generation check.
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
  ; Reserve each DOC page before the copy; the capture that had the page is
  ; no longer resident. Interrupts stay off from the generation check.
  a16
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
  a8
fm_upload_local_reserve_page:
  lda FM_PAGE_OWNER,x
  beq fm_upload_local_free_page
  dec
  phx
  a16
  and #$ff
  tax
  a8
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
  lda FM_PAGE_OWNER,x           ; an old tag outside the owner's range must
  dec                           ; not remove a copy that moved
  phx
  a16
  and #$ff
  tax
  a8
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
  a16
  lda FM_UP_LEFT
  cmp #FM_CHUNK
  bcc :+
  lda #FM_CHUNK
:
  tax
  lda FM_UP_SRC
  sta FM_UP_PTR
  a8
  lda FM_UP_SRC+2
  sta FM_UP_PTR+2
fm_upload_local_ready:
  lda f:SOUNDCTL
  bmi fm_upload_local_ready
  lda f:DOC_MASTER
  ora #SOUNDCTL_RAM|SOUNDCTL_INC
  sta f:SOUNDCTL
  lda FM_UP_DST
  sta f:SOUNDADRL
  lda FM_UP_DST+1
  sta f:SOUNDADRH
  ldy #0
  lda FM_UP_PACKED
  beq fm_upload_local_byte
  jsl fm_unpack_chunk
  jsr .loword(fm_upload_register_mode)
  a16
  lda #FM_CHUNK
  bra fm_upload_local_advance
fm_upload_local_byte:
  lda f:SOUNDCTL
  bmi fm_upload_local_byte
  lda [FM_UP_PTR],y
  sta f:SOUNDDATA
  iny
  dex
  bne fm_upload_local_byte
  jsr .loword(fm_upload_register_mode)
  a16
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
  a8
  bcc :+
  inc FM_UP_SRC+2
:
  a16
  lda FM_UP_AMOUNT
  eor #$ffff
  sec
  adc FM_UP_LEFT
  sta FM_UP_LEFT
  a8
  bne fm_upload_return
  stz FM_UP_ACTIVE
  ; A song can change in an interrupt during the final chunk.
  php
  sei
  a16
  lda FM_UP_CAP
  and #$ff
  tax
  a8
  lda FM_UP_PAGE
  sta FM_RESIDENT,x
  lda FM_UP_END
  sta FM_RESIDENT_END,x
  lda FM_CACHE_GEN
  cmp FM_CACHE_UPGEN
  bne :+
  lda FM_UP_KIND
  bne fm_upload_local_done_lookahead
  inc FM_CACHE_DONE             ; UP_PLAN
  bra :+
fm_upload_local_done_lookahead:
  cmp #UP_RESTORE23
  beq :+
  inc FM_LOOK_INDEX
:
  plp
fm_upload_return:
  ax16
  pld
  plb
  ply
  plx
  pla
  plp
  rtl
fm_upload_local_lookahead:
  jml fm_lookahead_extra
.segment "SOUND_EXTRA"
; fm_short_extra: the plans that keep only the first FM_SHORT_BYTES of
; captures 35 and 67 (four stages): FM_UP_LEFT gets that size and
; FM_SHORT_FLAGS marks the short copy. Then the pages are reserved.
fm_short_extra:
.a8
  lda FM_ACTIVE_SONG
  cmp #ENTRY_30                 ; all $30 copies of 35/67 use four stages
  beq fm_upload_local_short_check_cap
  cmp #ENTRY_2F
  bne :+
  lda FM_UP_KIND                ; the ending preload of capture 35
  cmp #LOOK_ENDING
  bne fm_short_done
  lda FM_UP_CAP
  cmp #CAP_35
  beq fm_upload_local_short_check_cap
  bra fm_short_done
:
  cmp #ENTRY_29
  bne fm_upload_local_short_maybe_cue
  lda FM_UP_KIND
  cmp #LOOK_BOSS2E
  beq fm_upload_local_short_check_cap
  bra fm_short_done
fm_upload_local_short_maybe_cue:
  cmp #ENTRY_2E
  bne fm_short_done
  lda FM_PRESERVED_OLD
  cmp #ENTRY_29
  beq fm_upload_local_short_check_cap
  cmp #ENTRY_30
  beq fm_upload_local_short_check_cap
  cmp #ENTRY_28
  bne fm_short_done
  lda FM_UP_CAP
  cmp #CAP_35
  bne fm_short_done
fm_upload_local_short_check_cap:
  lda FM_UP_CAP
  cmp #CAP_35
  bne :+
  lda #SHORT_35
  bra fm_upload_local_short_mark
:
  cmp #CAP_67
  bne fm_short_done
  lda #SHORT_67
fm_upload_local_short_mark:
  ora FM_SHORT_FLAGS
  sta FM_SHORT_FLAGS
  a16
  lda #FM_SHORT_BYTES
  sta FM_UP_LEFT
  a8
fm_short_done:
  jml fm_upload_local_whole_capture

; fm_lookahead_extra: the upload when the plan is complete: in $2E after $28
; or $29, the old song's captures go back; else the FM_LOOK_HINT lookahead.
; Interrupts are on.
fm_lookahead_extra:
.a8
  lda FM_ACTIVE_SONG
  cmp #ENTRY_2E
  beq :+
  jmp .loword(fm_lookahead_local_look_regular)
:
  lda FM_PRESERVED_OLD
  cmp #ENTRY_28
  bne :+
  jmp .loword(fm_lookahead_local_post28_backfill)
:
  cmp #ENTRY_29
  beq :+
  jmp .loword(fm_lookahead_local_look_regular)
:
  ; Capture 23 goes back first, RESTORE_DELAY after the late cue released
  ; its page; before that, the other $29 captures go back.
  lda FM_PHASE_WAIT
  cmp #PHASE_DUE
  bne fm_lookahead_local_backfill
  a16
  lda f:MUSIC_TICK
  sec
  sbc FM_PHASE_DUE
  bmi fm_lookahead_local_backfill16
  cmp #RESTORE_DELAY
  a8
  bcc fm_lookahead_local_backfill
  lda FM_RESIDENT+CAP_23
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
  a16
  txa
  clc
  adc #FM_PART_SIZE
  tax
  cpx #FM_PARTS*FM_PART_SIZE
  a8
  bne fm_lookahead_local_restore_voice
  lda #UP_RESTORE23
  sta FM_UP_KIND
  lda #CAP_23
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
  a8
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
  a16
  and #$00ff
  asl
  tax
  a8
  lda f:fm_restore_boss,x
  sta FM_UP_CAP
  lda f:fm_restore_boss+1,x
  sta FM_UP_PAGE
  sta FM_UP_DST+1
  stz FM_UP_DST
  lda #UP_RESTORE
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
  a16
  and #$00ff
  asl
  tax
  a8
  lda f:fm_restore_post28,x
  sta FM_UP_CAP
  lda f:fm_restore_post28+1,x
  sta FM_UP_PAGE
  sta FM_UP_DST+1
  stz FM_UP_DST
  lda #UP_POST28
  sta FM_UP_KIND
  jml fm_upload_check_resident
fm_lookahead_local_post28_cancel:
  plp
  jml fm_upload_return
; fm_lookahead_local_look_regular: the lookahead FM_LOOK_HINT (a new hint
; starts at its first entry) while its song plays: the next capture of its
; preload list.
fm_lookahead_local_look_regular:
  lda FM_LOOK_HINT
  beq fm_lookahead_local_look_return
  cmp FM_LOOK_KIND
  beq :+
  sta FM_LOOK_KIND
  stz FM_LOOK_INDEX
:
  cmp #LOOK_BOSS
  beq fm_lookahead_local_check_boss
  cmp #LOOK_ENDING
  beq fm_lookahead_local_check_ending
  cmp #LOOK_CAMERA
  beq fm_lookahead_local_check_camera
  cmp #LOOK_BOSS2E
  beq fm_lookahead_local_check_boss2e
  bra fm_lookahead_local_look_return
fm_lookahead_local_look_return:
  jml fm_upload_return
fm_lookahead_local_check_boss:
  lda FM_ACTIVE_SONG
  cmp #ENTRY_30                 ; stage music $30, either phase
  bne fm_lookahead_local_look_return
  lda FM_LOOK_INDEX
  cmp #FM_PRELOAD_COUNT
  bcs fm_lookahead_local_look_return
  bra fm_lookahead_local_look_lock
fm_lookahead_local_check_ending:
  lda FM_ACTIVE_SONG
  cmp #ENTRY_2F                 ; the ending music, either phase
  bne fm_lookahead_local_look_return
  lda FM_LOOK_INDEX
  cmp #FM_ENDING_PRELOAD_COUNT
  bcs fm_lookahead_local_look_return
  bra fm_lookahead_local_look_lock
fm_lookahead_local_check_boss2e:
  lda FM_ACTIVE_SONG
  cmp #ENTRY_29
  bne fm_lookahead_local_look_return
  lda FM_LOOK_INDEX
  cmp #FM_BOSS_GATE_COUNT
  bcs fm_lookahead_local_look_return
  bra fm_lookahead_local_look_lock
fm_lookahead_local_check_camera:
  lda FM_ACTIVE_SONG
  cmp #ENTRY_22
  beq :+
  cmp #ENTRY_24
  bne fm_lookahead_local_look_return
:
  lda FM_LOOK_INDEX
  bne fm_lookahead_local_look_return ; one capture only: 67
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
  a16
  and #$ff
  asl
  tax
  a8
  lda FM_LOOK_KIND
  cmp #LOOK_ENDING
  beq fm_lookahead_local_load_ending
  cmp #LOOK_CAMERA
  beq fm_lookahead_local_load_camera
  cmp #LOOK_BOSS2E
  beq fm_lookahead_local_load_boss2e
  lda FM_ACTIVE_SONG
  cmp #ENTRY_30
  bne fm_lookahead_local_look_cancel
  lda f:fm_preload_boss,x
  sta FM_UP_CAP
  lda f:fm_preload_boss+1,x
  bra fm_lookahead_local_look_selected
fm_lookahead_local_load_boss2e:
  lda FM_ACTIVE_SONG
  cmp #ENTRY_29
  bne fm_lookahead_local_look_cancel
  lda f:fm_preload_boss2e,x
  sta FM_UP_CAP
  lda f:fm_preload_boss2e+1,x
  bra fm_lookahead_local_look_selected
fm_lookahead_local_load_ending:
  lda FM_ACTIVE_SONG
  cmp #ENTRY_2F
  bne fm_lookahead_local_look_cancel
  lda f:fm_preload_ending,x
  sta FM_UP_CAP
  lda f:fm_preload_ending+1,x
  bra fm_lookahead_local_look_selected
fm_lookahead_local_load_camera:
  lda FM_ACTIVE_SONG
  cmp #ENTRY_22
  beq :+
  cmp #ENTRY_24
  bne fm_lookahead_local_look_cancel
:
  lda #CAP_67
  sta FM_UP_CAP
  lda #FM_PAGE_CAP67
fm_lookahead_local_look_selected:
  sta FM_UP_DST+1
  sta FM_UP_PAGE
  stz FM_UP_DST
  jml fm_upload_check_resident
fm_lookahead_local_look_cancel:
  plp
  jml fm_upload_return

.segment "SOUND_EXTRA"
; fm_ending_hint: from the third ending step on, preload the next ending
; captures in quiet time (cabinet.s). JSL.
ENDING_HINT_STEP = 3
fm_ending_hint:
.a8
  lda CAB_ENDING_STEP
  cmp #ENDING_HINT_STEP
  bcc :+
  lda #LOOK_ENDING
  sta f:FM_LOOK_HINT
:
  rtl
; fm_ending_hint_clear: the ending preload stops at the hand-off after the
; game (cabinet.s). JSL.
fm_ending_hint_clear:
.a8
  lda #0
  sta f:FM_LOOK_HINT
  rtl

; fm_stage_hint: the lookahead of each stage event check (stage_event). In
; $29 the $2E gate preload runs. Stages 6 and 11 have a song $30 to $29 boss
; result cue, stages 3, 9 and 14 a $2A boss camera: in the window before the
; cue (FM_HINT_*, from fm_native.py) the cue's captures preload; other stages
; have no hint. JSL.
fm_stage_hint:
.a8
  php
  phx
  lda f:FM_ACTIVE_SONG
  cmp #ENTRY_29
  bne :+
  lda #LOOK_BOSS2E
  sta f:FM_LOOK_HINT
  plx
  plp
  rtl
:
  a16
  lda CAMERA_STAGE_OFFSET
  tax
  a8
  lda CAMERA_STAGE
  and #STAGES-1
  cmp #FM_HINT_CAMERA3_STAGE
  beq @camera3
  cmp #FM_HINT_CAMERA9_STAGE
  beq @camera9
  cmp #FM_HINT_CAMERA14_STAGE
  beq @camera14
  cmp #FM_HINT_RESULT6_STAGE
  bne @stage11
  cpx #FM_HINT_RESULT6_FIRST
  bcc @no_hint
  cpx #FM_HINT_RESULT6_END
  bcs @no_hint
  bra @set_hint
@stage11:
  cmp #FM_HINT_RESULT11_STAGE
  bne @no_hint
  cpx #FM_HINT_RESULT11_FIRST
  bcc @no_hint
  cpx #FM_HINT_RESULT11_END
  bcs @no_hint
@set_hint:
  lda #LOOK_BOSS
  sta f:FM_LOOK_HINT
  bra @hint_done
@camera3:
  cpx #FM_HINT_CAMERA3_FIRST
  bcc @no_hint
  cpx #FM_HINT_CAMERA3_END
  bcs @no_hint
  bra @set_camera
@camera9:
  cpx #FM_HINT_CAMERA9_FIRST
  bcc @no_hint
  cpx #FM_HINT_CAMERA9_END
  bcs @no_hint
  bra @set_camera
@camera14:
  cpx #FM_HINT_CAMERA14_FIRST
  bcc @no_hint
  cpx #FM_HINT_CAMERA14_END
  bcs @no_hint
@set_camera:
  lda #LOOK_CAMERA
  sta f:FM_LOOK_HINT
  bra @hint_done
@no_hint:
  lda #0
  sta f:FM_LOOK_HINT
@hint_done:
  plx
  plp
  rtl
.segment "SOUND"

; music_voice_off: the key-off of the music part X (music_event): it acts at
; the visit; only the first key-off of a held note counts. JSL.
music_voice_off:
.a8
  phb
  lda #^FM_STATES
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

; music_all_off: all FM notes stop at once. JSL.
music_all_off:
.a8
  phb
  lda #^FM_STATES
  pha
  plb
  jsr .loword(fm_mode)
  ldx #0
@part:
  lda FM_STATES+S_ACTIVE,x
  beq :+
  jsr .loword(fm_stop)
:
  a16
  txa
  clc
  adc #FM_PART_SIZE
  tax
  a8
  cpx #FM_PARTS*FM_PART_SIZE
  bne @part
  plb
  rtl

; fm_voice_tick: the visit of this tick, after the score (music_irq_entry):
; each part is visited every FM_VISIT ticks, part (-FM_TICK) mod FM_VISIT.
; JSL.
fm_voice_tick:
.a8
  ; FM_VISIT - FM_PARTS ticks of each FM_VISIT have no part to visit.
  lda f:FM_TICK
  eor #$ff
  inc
  and #FM_VISIT-1
  cmp #FM_PARTS
  bcc :+
  rtl
:
  a16
  and #$ff
  asl
  asl
  asl
  asl
  asl
  asl                           ; times FM_PART_SIZE
  tax
  a8
  phb
  lda #^FM_STATES
  pha
  plb
  lda FM_STATES+S_ACTIVE,x
  beq @none
  lda FM_TICK
  cmp FM_STATES+S_LAST,x
  beq @none                     ; the note started this tick
  ; The interrupt left the GLU in register mode.
  jsr .loword(fm_visit)
@none:
  plb
  rtl

.segment "SOUND_EXTRA"
; fm_unpack_chunk: expand one packed chunk at FM_UP_PTR+Y into DOC RAM: a
; byte of block bits (bit 0 first; 1: deltas), then FM_CHUNK / FM_BLOCK
; blocks, each FM_BLOCK raw bytes or FM_BLOCK / 2 bytes of two signed
; nibble deltas from the byte before (fm_delta_low, fm_delta_high). JSL.
fm_unpack_chunk:
.a8
  ; TAX moves the hidden B byte when X is 16-bit: clear B once.
  a16
  and #$00ff
  a8
  lda [FM_UP_PTR],y
  iny
  sta FM_UP_BITS
  lda #FM_CHUNK/FM_BLOCK
  sta FM_UP_BLOCKS
@block:
  lsr FM_UP_BITS
  bcs @delta_block
  ldx #FM_BLOCK
@raw_byte:
  lda f:SOUNDCTL
  bmi @raw_byte
  lda [FM_UP_PTR],y
  iny
  sta f:SOUNDDATA
  dex
  bne @raw_byte
  sta FM_UP_PREV
  bra @block_done
@delta_block:
  lda #FM_BLOCK/2
  sta FM_UP_PAIRS
@delta_pair:
  lda [FM_UP_PTR],y
  iny
  tax                         ; hidden B was cleared at chunk entry
@ready_low:
  lda f:SOUNDCTL
  bmi @ready_low
  lda f:fm_delta_low,x
  clc
  adc FM_UP_PREV
  sta FM_UP_PREV
  sta f:SOUNDDATA
@ready_high:
  lda f:SOUNDCTL
  bmi @ready_high
  lda f:fm_delta_high,x
  clc
  adc FM_UP_PREV
  sta FM_UP_PREV
  sta f:SOUNDDATA
  dec FM_UP_PAIRS
  bne @delta_pair
@block_done:
  dec FM_UP_BLOCKS
  bne @block
  rtl
.segment "SOUND"
.assert FM_HELD_SIZE*FM_PARTS = .sizeof(FM_HELD) .and FM_PART_SIZE = 64, error
.assert FM_STAGE_SIZE = 8 .and FM_RELEASE_SIZE = 8 .and FM_HOLD_SIZE = 3, error
.assert STG_BOOST = 3 .and STG_ATT = 4 .and STG_STEP = 6 .and PT_SLOPE = 2 .and PT_GOAL = 4, error
.assert RL_POINTS = 2 .and RL_LENGTH = 4 .and RL_OFFSET = 6, error
.assert FM_VISIT = 8 .and DOC_WAVE/$20 = 4, error ; the ASLs above; FM_G of the wave page
.assert FM_PART_SIZE = 2*MUSIC_PART_SIZE .and DOC_FREQ_HIGH/$20 = 1, error
.assert FM_CHUNK = 64 .and FM_BLOCK = 16 .and ENTRY_2E = $38 .and ENTRY_29 = $24, error
