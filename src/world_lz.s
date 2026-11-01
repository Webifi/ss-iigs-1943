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
; WORLD_LENGTH bytes: WL_RECORD points at it, and the literal block move
; takes its bank. JSL; A16; D = 0.
world_inflate_begin:
.a16
.i16
  lda WORLD_SOURCE
  sta z:WL_RECORD
  a8
  lda WORLD_SOURCE+2
  sta z:WL_RECORD+2
  sta f:inflate_literal_move+2  ; the source bank of the MVN
  a16
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

; world_inflate_pump: inflate up to PUMP_BATCH tokens while PUMP_TICKS
; ticks are left (the clock wait); at the end WLS_READY. JSL; A16; D = 0;
; registers kept.
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
  lda #PUMP_BATCH
  sta W_LEFT
  lda f:WL_IN
  tay
  lda f:WL_OUT
  tax
@token:
  jsr .loword(inflate_token)
  txa
  cmp f:WL_FINAL
  bcs @ready
  dec W_LEFT
  beq @stop
  lda GAME_DUE
  sec
  sbc GAME_CLOCK
  bmi @stop
  cmp #PUMP_TICKS
  bcs @token
  bra @stop
@ready:
  a8
  lda #WLS_READY
  sta f:WORLD_LZ_STATE
  a16
@stop:
  tya
  sta f:WL_IN
  txa
  sta f:WL_OUT
  ply
  plx
  pla
  rtl

; inflate_token: decode the next token of the record at WL_RECORD into
; WORLD_LZ_OUTPUT. Y = the input offset and X = the output offset; both move
; on. Each token is one block move. JSR; A16; D = 0; DBR = 0.
inflate_token:
.a16
.i16
  lda [WL_RECORD],y
  iny
  and #$00ff
  cmp #LZ_SHORT
  bcs inflate_match
  ; A literal run of A + 1 bytes from the record.
  pha                           ; the bytes - 1 (MVN)
  txa
  clc
  adc #.loword(WORLD_LZ_OUTPUT)
  sta W_SCRATCH
  tya
  clc
  adc z:WL_RECORD
  tax
  ldy W_SCRATCH
  pla
  phb
inflate_literal_move:
  mvn #0,#^WORLD_LZ_OUTPUT      ; world_inflate_begin sets the source bank
  plb
  txa
  sec
  sbc z:WL_RECORD
  pha                           ; the input offset
; inflate_output: the stack holds the input offset; Y = the end of the
; output: X = the output offset, Y = the input offset.
inflate_output:
  tya
  sec
  sbc #.loword(WORLD_LZ_OUTPUT)
  tax
  ply
  rts
inflate_match:
  cmp #LZ_LONG
  bcs inflate_long
  ; A short match: bits 3-5 + LZ_SHORT_MIN bytes, from the WORLD_LZ_SHORT
  ; entry of bits 0-2 and the next byte.
  sta W_SCRATCH
  and #LZ_SHORT_LENGTH
  lsr
  lsr
  lsr                           ; carry 0: bits 0-2 were 0
  adc #LZ_SHORT_MIN-1
  sta W_LEN                     ; the bytes - 1 (MVN)
  lda W_SCRATCH
  and #7
  xba
  sta W_SCRATCH
  lda [WL_RECORD],y
  iny
  and #$00ff
  ora W_SCRATCH
  asl
  phx
  tax
  lda f:WORLD_LZ_SHORT,x
  plx
  bra inflate_dictionary
inflate_long:
  ; A long match: bits 0-5 + LZ_LONG_MIN bytes; a distance word follows,
  ; with LZ_BACK: back in the output.
  and #<~LZ_LONG
  clc
  adc #LZ_LONG_MIN-1
  sta W_LEN                     ; the bytes - 1 (MVN)
  lda [WL_RECORD],y
  iny
  iny
  cmp #LZ_BACK
  bcc inflate_dictionary
  and #LZ_BACK-1
  sta W_DIST
  phy                           ; the input offset
  txa
  clc
  adc #.loword(WORLD_LZ_OUTPUT)
  tay
  sec
  sbc W_DIST
  tax
  lda W_LEN
  phb
  mvn #^WORLD_LZ_OUTPUT,#^WORLD_LZ_OUTPUT
  plb
  jmp .loword(inflate_output)
; inflate_dictionary: W_LEN + 1 bytes from WORLD_LZ_DICT + A.
inflate_dictionary:
  phy                           ; the input offset
  clc
  adc #.loword(WORLD_LZ_DICT)
  sta W_SCRATCH
  txa
  clc
  adc #.loword(WORLD_LZ_OUTPUT)
  tay
  ldx W_SCRATCH
  lda W_LEN
  phb
  mvn #^WORLD_LZ_DICT,#^WORLD_LZ_OUTPUT
  plb
  jmp .loword(inflate_output)
.assert LZ_SHORT_MIN = 4 .and LZ_SHORT_LENGTH = $38, error  ; the three LSRs above

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
  lda #$8000                    ; the jump comes: no time limit
  bra @start
@loop:
  lda #0
@start:
  ; W_DONE: the tokens done ($8000 up: no time limit); W_LEFT: allowed.
  sta W_DONE
  stx W_LEFT
  lda f:WL_IN
  tay
  lda f:WL_OUT
  tax
@token:
  jsr .loword(inflate_token)
  txa
  cmp f:WL_FINAL
  bcs @ready
  inc W_DONE
  dec W_LEFT
  beq @stop
  lda W_DONE
  bmi @token
  cmp #FORCE_SHARE_MIN
  bcc @token
  lda GAME_DUE
  sec
  sbc GAME_CLOCK
  bmi @stop
  cmp #LOGIC_TICKS
  bcs @token
  bra @stop
@ready:
  a8
  lda #WLS_READY
  sta f:WORLD_LZ_STATE
  a16
@stop:
  tya
  sta f:WL_IN
  txa
  sta f:WL_OUT
@none16:
  ply
  plx
  rtl
; world_inflate_finish: the inflated record at X of the packet, words high
; byte first; the inflate ends. JSL; A16; X = the packet end.
world_inflate_finish:
.a16
.i16
  a8
  lda #^WORLD_LZ_OUTPUT
  sta f:packet_copy_bank
  a16
  lda f:WL_FINAL
  ldy #.loword(WORLD_LZ_OUTPUT)
  jsl packet_copy
  a8
  lda #0
  sta f:WORLD_LZ_STATE
  a16
  rtl
