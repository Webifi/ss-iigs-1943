; The world sections: the choice of the next region, and the inflate of the
; LZ-packed world records into WORLD_LZ_OUTPUT (bank 1) in idle time. A token:
; below LZ_SHORT a literal run of token + 1 bytes; below LZ_LONG a short
; dictionary match (WORLD_LZ_SHORT); else a long match: from the dictionary,
; or with LZ_BACK from the output already made.
LZ_SHORT = $80
LZ_LONG = $c0
LZ_SHORT_LENGTH = $38        ; a short match: bits 3-5, + LZ_SHORT_MIN bytes
LZ_SHORT_MIN = 4
LZ_LONG_MIN = 3              ; a long match: bits 0-5, + LZ_LONG_MIN bytes
LZ_BACK = $8000              ; a long match distance: back in the output
FORCE_SHARE_MIN = 24         ; world_inflate_force: tokens always done
LOGIC_TICKS = 6              ; more tokens only while this many ticks are left
FORCE_NEAR = 16              ; rows before a region's ceiling: urgent
DECK_JUMP_ROW = $d5          ; the deck row of the scripted jump

; world_inflate_cancel: no inflate (game_world_init, a cancelled load). JSL.
world_inflate_cancel:
.a8
  lda #0
  sta f:WORLD_LZ_STATE
  rtl

; world_choose_region: A = the next region to load, or WORLD_NONE. During the
; result: a retry loads the region of the stage start (stage * 2048), the
; next stage its intro route, never the section under the text. In play: the
; route of the current region (two candidates), as cabinet_world_request
; allows. JSL.
world_choose_region:
.a8
.i16
  lda CAB_RESULT_ACTIVE
  bne @result
  ; The result ends one update before the stage counts up: the next region
  ; stays chosen until then.
  lda GAME_STAGE_EXIT
  cmp #EXIT_REFILL
  beq @next_stage
  bra @ordinary
@result:
  lda GAME_STAGE_EXIT
  cmp #EXIT_REFILL
  beq @next_stage
  cmp #EXIT_RETRY
  beq :+
  lda #WORLD_NONE
  rtl
:
  a16
  lda CAMERA_STAGE
  and #STAGES-1
  asl
  asl
  asl                           ; the map of the stage start: stage * 2048 / 256
  tax
  a8
  lda f:WORLD_REGION_MAP,x
  bra @result_candidate
@next_stage:
  lda CAMERA_STAGE
  cmp #LAST_STAGE
  bcc :+
  lda #WORLD_NONE
  rtl
:
  inc
  a16
  and #STAGES-1
  xba
  lsr
  lsr                           ; the route row of the stage: 64 bytes
  ora #(WORLD_INTRO_ID*2)
  tax
  a8
  lda f:WORLD_ROUTES,x
@result_candidate:
  cmp #WORLD_NONE
  beq @none
  cmp WORLD_TAGS
  beq @none
  cmp WORLD_TAGS+1
  beq @none
  sta W_SCRATCH
  lda WORLD_CURRENT
  cmp #WORLD_INTRO_ID
  beq @result_ready
  a16
  lda W_SCRATCH
  and #WORLD_REGIONS-1
  tax
  a8
  lda f:WORLD_REGION_SIDE,x
  a16
  and #1
  tax
  a8
  lda WORLD_TAGS,x
  cmp WORLD_CURRENT
  beq @none
@result_ready:
  lda W_SCRATCH
  rtl
@ordinary:
  a16
  lda CAMERA_STAGE
  and #STAGES-1
  xba
  lsr
  lsr
  sta ROUTE_ROW
  lda WORLD_CURRENT
  and #WORLD_REGIONS-1
  asl                           ; two route candidates for each region
  ora ROUTE_ROW
  tay
  a8
  lda #2
  sta WORLD_SKIPS
@candidate:
  tyx
  lda f:WORLD_ROUTES,x
  jsl cabinet_world_request
  cmp #WORLD_NONE
  beq @none
  cmp WORLD_TAGS
  beq @next_candidate
  cmp WORLD_TAGS+1
  bne @return
@next_candidate:
  iny
  dec WORLD_SKIPS
  bne @candidate
@none:
  lda #WORLD_NONE
@return:
  rtl

; world_inflate_begin: start the inflate of the record WORLD_SOURCE of
; WORLD_LENGTH bytes. JSL; A16.
world_inflate_begin:
.a16
.i16
  lda WORLD_SOURCE
  sta f:WL_SOURCE
  lda WORLD_SOURCE+2
  sta f:WL_SOURCE+2
  lda WORLD_LENGTH
  sta f:WL_FINAL
  lda #0
  sta f:WL_IN
  sta f:WL_OUT
  a8
  lda #WLS_INFLATE
  sta f:WORLD_LZ_STATE
  a16
  rtl

; world_inflate_pump: inflate one token (the clock wait, with PUMP_TICKS to
; spare, and world_inflate_force); at the end WLS_READY. JSL; A16;
; registers and the direct page pointers kept.
world_inflate_pump:
.a16
.i16
  a8
  lda f:WORLD_LZ_STATE
  cmp #WLS_INFLATE
  a16
  beq :+
  rtl
:
  pha
  phx
  phy
  lda WORLD_POINTER
  pha
  lda WORLD_POINTER+2
  pha
  lda WORLD_SOURCE
  pha
  lda WORLD_SOURCE+2
  pha
  lda f:WL_SOURCE
  sta WORLD_SOURCE
  lda f:WL_SOURCE+2
  sta WORLD_SOURCE+2
  lda #.loword(WORLD_LZ_DICT)
  sta WORLD_POINTER
  a8
  lda #^WORLD_LZ_DICT
  sta WORLD_POINTER+2
  a16
  lda f:WL_IN
  tay
  lda f:WL_OUT
  tax
  a8
  lda [WORLD_SOURCE],y
  iny
  cmp #LZ_SHORT
  bcs @match
  inc                           ; a literal run
  sta W_LEN
  stz W_LEN+1
  a16
  txa
  clc
  adc W_LEN
  sta W_END
  a8
@literal:
  lda [WORLD_SOURCE],y
  iny
  sta f:WORLD_LZ_OUTPUT,x
  inx
  cpx W_END
  bcc @literal
  jmp @next
@match:
  cmp #LZ_LONG
  bcs @long
  sta W_SCRATCH+1
  and #LZ_SHORT_LENGTH
  lsr
  lsr
  lsr
  clc
  adc #LZ_SHORT_MIN
  sta W_LEN
  stz W_LEN+1
  lda W_SCRATCH+1
  and #7                        ; the high bits of the WORLD_LZ_SHORT index
  sta W_SCRATCH+1
  lda [WORLD_SOURCE],y
  iny
  sta W_SCRATCH
  a16
  lda W_SCRATCH
  asl
  phx
  tax
  lda f:WORLD_LZ_SHORT,x
  plx
  sta W_DIST
  bra @dictionary
@long:
.a8
  and #<~LZ_LONG
  clc
  adc #LZ_LONG_MIN
  sta W_LEN
  stz W_LEN+1
  a16
  lda [WORLD_SOURCE],y
  iny
  iny
  sta W_DIST
  cmp #LZ_BACK
  bcc @dictionary
  and #LZ_BACK-1
  sta W_DIST
  sty W_INPUT
  txa
  clc
  adc #.loword(WORLD_LZ_OUTPUT)
  tay
  txa
  sec
  sbc W_DIST
  clc
  adc #.loword(WORLD_LZ_OUTPUT)
  tax
  lda W_LEN
  dec
  phb
  mvn #^WORLD_LZ_OUTPUT,#^WORLD_LZ_OUTPUT
  plb
  tya
  sec
  sbc #.loword(WORLD_LZ_OUTPUT)
  tax
  ldy W_INPUT
  a8
  bra @next
@dictionary:
  sty W_INPUT
  txa
  clc
  adc W_LEN
  sta W_END
  ldy W_DIST
  a8
@dict_copy:
  lda [WORLD_POINTER],y
  sta f:WORLD_LZ_OUTPUT,x
  iny
  inx
  cpx W_END
  bcc @dict_copy
  ldy W_INPUT
@next:
  a16
  tya
  sta f:WL_IN
  txa
  sta f:WL_OUT
  cmp f:WL_FINAL
  bcc :+
  a8
  lda #WLS_READY
  sta f:WORLD_LZ_STATE
  a16
:
  pla
  sta WORLD_SOURCE+2
  pla
  sta WORLD_SOURCE
  pla
  sta WORLD_POINTER+2
  pla
  sta WORLD_POINTER
  ply
  plx
  pla
  rtl

; world_inflate_prefetch: when no inflate runs, start the next list entry
; if it is packed and its slot does not hold its tile already, while this
; packet goes out. JSL; A16.
world_inflate_prefetch:
.a16
.i16
  phx
  a8
  lda f:WORLD_LZ_STATE
  bne @done8
  lda WORLD_LOADING
  cmp #WORLD_NONE
  beq @done8
  a16
  lda WORLD_LIST
  sta WORLD_POINTER
  lda WORLD_LIST+2
  sta WORLD_POINTER+2
  ldy WORLD_OFFSET
  lda [WORLD_POINTER],y
  cmp #WORLD_LIST_END
  beq @done16
  sta W_SCRATCH
  iny
  iny
  lda [WORLD_POINTER],y
  sta W_DIST
  iny
  iny
  lda [WORLD_POINTER],y
  bpl @done16
  and #$7fff
  sta W_LEN
  lda W_SCRATCH
  cmp #WORLD_NO_SLOT
  beq @claim
  asl
  tax
  lda f:WORLD_SLOTS,x
  cmp W_DIST
  beq @done16
@claim:
  lda W_SCRATCH
  sta WORLD_SLOT
  lda W_DIST
  sta WORLD_TILE
  lda W_LEN
  sta WORLD_LENGTH
  iny
  iny
  lda [WORLD_POINTER],y
  sta WORLD_SOURCE
  iny
  iny
  lda [WORLD_POINTER],y
  sta WORLD_SOURCE+2
  iny
  iny
  sty WORLD_OFFSET
  jsl world_inflate_begin
@done16:
  plx
  rtl
@done8:
  a16
  plx
  rtl

; world_inflate_force: a share of tokens each update, also without idle
; time: more when the region is needed soon; on the deck the intro script
; can jump to the stage's first area (DECK_JUMP_ROW). After FORCE_SHARE_MIN
; tokens it goes on only while LOGIC_TICKS ticks are left. JSL; A16.
world_inflate_force:
.a16
.i16
  phx
  phy
  a8
  lda f:WORLD_LZ_STATE
  cmp #WLS_INFLATE
  beq :+
  a16
  ply
  plx
  rtl
:
.a8
  lda CAMERA_BG1_SCROLL+1
  cmp #DECK_ROWS_FIRST
  bcc @normal
  cmp #DECK_ROWS_END
  bcs @normal
  ; On the deck: the first region of the stage before the scripted jump
  ; gets the larger share; another region a moderate one.
  a16
  lda CAMERA_STAGE
  and #STAGES-1
  xba
  lsr
  lsr
  ora #(WORLD_INTRO_ID*2)
  tax
  a8
  lda f:WORLD_ROUTES,x
  jsl cabinet_world_request
  cmp WORLD_LOADING
  bne @moderate
  lda CAMERA_BG1_SCROLL+1
  cmp #DECK_JUMP_ROW
  bcc @first
  bne @last_resort
  lda CAMERA_BG1_SCROLL
  cmp #$f0                      ; near the jump: all that it needs
  bcs @last_resort
  cmp #$c0
  bcs @urgent
@first:
  a16
  ldx #32
  bra @loop
@moderate:
  a16
  ldx #16
  bra @loop
@normal:
  a16
  lda WORLD_LOADING
  and #WORLD_REGIONS-1
  tax
  a8
  lda f:WORLD_REGION_CEILING,x
  sta W_SCRATCH
  lda CAMERA_BG1_SCROLL+1
  sec
  sbc W_SCRATCH
  bcc @urgent
  cmp #FORCE_NEAR
  bcc @urgent
  a16
  ldx #8
  bra @loop
@urgent:
  a16
  ldx #32
  bra @loop
@last_resort:
  a16
  ldx #64
  ldy #$8000                    ; the jump comes: no time limit
  bra @token
@loop:
  ldy #0
@token:
  jsl world_inflate_pump
  iny
  dex
  beq @none16
  a8
  lda f:WORLD_LZ_STATE
  cmp #WLS_INFLATE
  a16
  bne @none16
  cpy #$8000
  bcs @token
  cpy #FORCE_SHARE_MIN
  bcc @token
  lda GAME_DUE
  sec
  sbc GAME_CLOCK
  bmi @none16
  cmp #LOGIC_TICKS
  bcs @token
@none16:
  ply
  plx
  rtl
; world_inflate_finish: the inflated record at X of the packet, words high
; byte first; the inflate ends. JSL; A16; X = the packet end.
world_inflate_finish:
.a16
.i16
  txy
  ldx #0
@copy:
  lda f:WORLD_LZ_OUTPUT,x
  xba
  sta a:0,y
  inx
  inx
  iny
  iny
  txa
  cmp f:WL_FINAL
  bcc @copy
  tyx
  a8
  lda #0
  sta f:WORLD_LZ_STATE
  a16
  rtl
