; Clear the decoder state from either world initialization or a cancelled load.
world_inflate_cancel:
.a8
  lda #0
  sta f:$018d10
  rtl

; Incremental expansion into startup scratch, after startup is finished.
; Each encoded token expands at most 32 bytes. $018900-$018d1b is reserved
; for this staging buffer and its state while the game is running.
W_INPUT = $14bc
W_SCRATCH = $14be
W_LEN = $14f6
W_DIST = $14f8
W_END = $14fa
WL_STATE = $018d10
WL_SOURCE = $018d12
WL_IN = $018d16
WL_OUT = $018d18
WL_FINAL = $018d1a

; Select the first required region while the result text is visible. A retry
; resumes at stage*2048; a successful stage starts from the next intro route.
; During a retry, never replace the section currently drawn beneath the text.
world_choose_region:
.a8
.i16
  lda CAB_RESULT_ACTIVE
  bne @result
  ; The result flag clears one update before the stage counter advances.
  ; Keep the new region selected throughout that handoff.
  lda GAME_STAGE_EXIT
  cmp #2
  beq @next_stage
  bra @ordinary
@result:
  lda GAME_STAGE_EXIT
  cmp #2
  beq @next_stage
  cmp #3
  beq :+
  lda #255
  rtl
:
  rep #$20
  lda CAMERA_STAGE
  and #15
  asl
  asl
  asl
  tax
  sep #$20
  lda f:WORLD_REGION_MAP,x
  bra @result_candidate
@next_stage:
  lda CAMERA_STAGE
  cmp #15
  bcc :+
  lda #255
  rtl
:
  inc
  rep #$20
  and #15
  xba
  lsr
  lsr
  ora #(WORLD_INTRO_ID*2)
  tax
  sep #$20
  lda f:WORLD_ROUTES,x
@result_candidate:
  cmp #255
  beq @none
  cmp WORLD_TAGS
  beq @none
  cmp WORLD_TAGS+1
  beq @none
  sta W_SCRATCH
  lda WORLD_CURRENT
  cmp #WORLD_INTRO_ID
  beq @result_ready
  rep #$20
  lda W_SCRATCH
  and #31
  tax
  sep #$20
  lda f:WORLD_REGION_SIDE,x
  rep #$20
  and #1
  tax
  sep #$20
  lda WORLD_TAGS,x
  cmp WORLD_CURRENT
  beq @none
@result_ready:
  lda W_SCRATCH
  rtl
@ordinary:
  rep #$20
  lda CAMERA_STAGE
  and #15
  xba
  lsr
  lsr
  sta $d0
  lda WORLD_CURRENT
  and #31
  asl
  ora $d0
  tay
  tax
  sep #$20
  lda f:WORLD_ROUTES,x
  jsl cabinet_world_request
  sta $d4
  lda #2
  sta WORLD_SKIPS
@candidate:
  tyx
  lda f:WORLD_ROUTES,x
  jsl cabinet_world_request
  cmp #255
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
  lda #255
@return:
  rtl

world_inflate_begin:
.a16
.i16
.ifdef WORLD_LZ_PROFILE
  php
  sep #$20
  lda #1
  sta f:$05050a
  plp
.a16
.endif
  lda $d4
  sta f:WL_SOURCE
  lda $d6
  sta f:WL_SOURCE+2
  lda WORLD_LENGTH
  sta f:WL_FINAL
  lda #0
  sta f:WL_IN
  sta f:WL_OUT
  sep #$20
  lda #1
  sta f:WL_STATE
  rep #$20
  rtl

; Called only while the logic clock has at least three ticks remaining.
; Preserves the wait loop's registers and direct-page scratch pointers.
world_inflate_pump:
.a16
.i16
  sep #$20
  lda f:WL_STATE
  cmp #1
  rep #$20
  beq :+
  rtl
:
  pha
  phx
  phy
.ifdef WORLD_LZ_PROFILE
  sep #$20
  lda #3
  sta f:$05050a
  rep #$20
.endif
  lda $d0
  pha
  lda $d2
  pha
  lda $d4
  pha
  lda $d6
  pha
  lda f:WL_SOURCE
  sta $d4
  lda f:WL_SOURCE+2
  sta $d6
  lda #.loword(WORLD_LZ_DICT)
  sta $d0
  sep #$20
  lda #^WORLD_LZ_DICT
  sta $d2
  rep #$20
  lda f:WL_IN
  tay
  lda f:WL_OUT
  tax
  sep #$20
  lda [$d4],y
  iny
  cmp #$80
  bcs @match
  inc
  sta W_LEN
  stz W_LEN+1
  rep #$20
  txa
  clc
  adc W_LEN
  sta W_END
  sep #$20
@literal:
  lda [$d4],y
  iny
  sta f:$018900,x
  inx
  cpx W_END
  bcc @literal
  jmp @next
@match:
  cmp #$c0
  bcs @long
  sta W_SCRATCH+1
  and #$38
  lsr
  lsr
  lsr
  clc
  adc #4
  sta W_LEN
  stz W_LEN+1
  lda W_SCRATCH+1
  and #7
  sta W_SCRATCH+1
  lda [$d4],y
  iny
  sta W_SCRATCH
  rep #$20
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
  and #$3f
  clc
  adc #3
  sta W_LEN
  stz W_LEN+1
  rep #$20
  lda [$d4],y
  iny
  iny
  sta W_DIST
  cmp #$8000
  bcc @dictionary
  and #$7fff
  sta W_DIST
  sty W_INPUT
  txa
  clc
  adc #$8900
  tay
  txa
  sec
  sbc W_DIST
  clc
  adc #$8900
  tax
  lda W_LEN
  dec
  phb
  mvn #$01,#$01
  plb
  tya
  sec
  sbc #$8900
  tax
  ldy W_INPUT
  sep #$20
  bra @next
@dictionary:
  sty W_INPUT
  txa
  clc
  adc W_LEN
  sta W_END
  ldy W_DIST
  sep #$20
@dict_copy:
  lda [$d0],y
  sta f:$018900,x
  iny
  inx
  cpx W_END
  bcc @dict_copy
  ldy W_INPUT
@next:
  rep #$20
  tya
  sta f:WL_IN
  txa
  sta f:WL_OUT
  cmp f:WL_FINAL
  bcc :+
  sep #$20
  lda #2
  sta f:WL_STATE
  rep #$20
:
  pla
  sta $d6
  pla
  sta $d4
  pla
  sta $d2
  pla
  sta $d0
  ply
  plx
  pla
.ifdef WORLD_LZ_PROFILE
  php
  sep #$20
  lda #4
  sta f:$05050a
  plp
.endif
  rtl

; Begin the next compressed record while this picture's packet is sent.
; Uncompressed and already-resident records stay on the ordinary path.
world_inflate_prefetch:
.a16
.i16
  phx
  sep #$20
  lda f:WL_STATE
  bne @done8
  lda WORLD_LOADING
  cmp #255
  beq @done8
  rep #$20
  lda WORLD_LIST
  sta $d0
  lda WORLD_LIST+2
  sta $d2
  ldy WORLD_OFFSET
  lda [$d0],y
  cmp #$fffe
  beq @done16
  sta W_SCRATCH
  iny
  iny
  lda [$d0],y
  sta W_DIST
  iny
  iny
  lda [$d0],y
  bpl @done16
  and #$7fff
  sta W_LEN
  lda W_SCRATCH
  cmp #$ffff
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
  lda [$d0],y
  sta $d4
  iny
  iny
  lda [$d0],y
  sta $d6
  iny
  iny
  sty WORLD_OFFSET
  jsl world_inflate_begin
@done16:
  plx
  rtl
@done8:
  rep #$20
  plx
  rtl

; One minimum share per logic update, even when no idle time is available.
; Intro camera scripts can jump directly to the selected stage's first area.
world_inflate_force:
.a16
.i16
  phx
  phy
  sep #$20
  lda f:WL_STATE
  cmp #1
  beq :+
  rep #$20
  ply
  plx
  rtl
:
.a8
.ifdef WORLD_LZ_PROFILE
  lda #7
  sta f:$05050a
.endif
  lda CAMERA+$10
  cmp #$d0
  bcc @normal
  cmp #$d8
  bcs @normal
  ; The second queued region may be needed much later than the jump.
  ; Size the first region's share against the approaching scripted jump.
  rep #$20
  lda CAMERA_STAGE
  and #15
  xba
  lsr
  lsr
  ora #(WORLD_INTRO_ID*2)
  tax
  sep #$20
  lda f:WORLD_ROUTES,x
  jsl cabinet_world_request
  cmp WORLD_LOADING
  bne @moderate
  lda CAMERA+$10
  cmp #$d5
  bcc @first
  bne @last_resort
  lda CAMERA+$0f
  cmp #$f0
  bcs @last_resort
  cmp #$c0
  bcs @urgent
@first:
  rep #$20
  ldx #32
  bra @loop
@moderate:
  rep #$20
  ldx #16
  bra @loop
@normal:
  rep #$20
  lda WORLD_LOADING
  and #31
  tax
  sep #$20
  lda f:WORLD_REGION_CEILING,x
  sta W_SCRATCH
  lda CAMERA+$10
  sec
  sbc W_SCRATCH
  bcc @urgent
  cmp #16
  bcc @urgent
  rep #$20
  ldx #8
  bra @loop
@urgent:
  rep #$20
  ldx #32
  bra @loop
@last_resort:
  rep #$20
  ldx #64
  ldy #$8000
  bra @token
@loop:
  ldy #0
@token:
  jsl world_inflate_pump
  iny
  dex
  beq @none16
  sep #$20
  lda f:WL_STATE
  cmp #1
  rep #$20
  bne @none16
  cpy #$8000
  bcs @token                 ; imminent scripted jump: force the larger share
  ; A small share always makes progress. Beyond that, use the beginning of
  ; the update only while six clock ticks remain for game logic and sound.
  cpy #24
  bcc @token
  lda GAME_DUE
  sec
  sbc GAME_CLOCK
  bmi @none16
  cmp #6
  bcs @token
@none16:
.ifdef WORLD_LZ_PROFILE
  php
  sep #$20
  lda #8
  sta f:$05050a
  plp
.a16
.endif
  ply
  plx
  rtl
; Write the original word-swapped packet into the live send buffer.
world_inflate_finish:
.a16
.i16
.ifdef WORLD_LZ_PROFILE
  php
  sep #$20
  lda #5
  sta f:$05050a
  plp
.a16
.endif
  txy
  ldx #0
@copy:
  lda f:$018900,x
  xba
  sta a:$0000,y
  inx
  inx
  iny
  iny
  txa
  cmp f:WL_FINAL
  bcc @copy
  tyx
  sep #$20
  lda #0
  sta f:WL_STATE
  rep #$20
.ifdef WORLD_LZ_PROFILE
  php
  sep #$20
  lda #6
  sta f:$05050a
  lda #2
  sta f:$05050a
  plp
.a16
.endif
  rtl
