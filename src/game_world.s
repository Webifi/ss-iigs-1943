; Complete ROM-world assets are prepared by the build. Quiet updates copy one
; bounded upload batch. There are no disk reads and no runtime art searches.
.a8
.i16
WORLD_TAGS = $14b4
WORLD_SIDE = $14b6
WORLD_LOADING = $14a2
WORLD_LIST = $14a4
WORLD_OFFSET = $14a8
WORLD_OUTPUT = $14aa
WORLD_SLOT = $14ac
WORLD_TILE = $14ae
WORLD_LENGTH = $14b0
WORLD_CURRENT = $14b2
WORLD_SKIPS = $14b3
WORLD_SLOTS = $01b400

.segment "INPUT"
game_world_init:
  jsl special_restore_tick
  rep #$20
  ldx #WORLD_SLOT_COUNT*2-2
@slot:
  lda f:WORLD_INITIAL_SLOTS,x
  sta f:WORLD_SLOTS,x
  dex
  dex
  bpl @slot
  stz WORLD_OFFSET
  stz D500_INDEX
  sep #$20
.ifdef WORLD_LZ
  jsl world_inflate_cancel
.endif
  ldx #1
@tags:
  lda f:WORLD_INITIAL_TAGS,x
  sta WORLD_TAGS,x
  dex
  bpl @tags
  stz SPECIAL_LOADED
  stz SPECIAL_HOOK
  stz SPECIAL_WAVE_READY
  stz SPECIAL_TIMER
  stz SPECIAL_TYPE
  lda #255
  sta WORLD_LOADING
  rtl

.segment "GAMEFLOW"
game_world_append:
.a16
  sep #$20
  lda CAMERA+$0e
  sta a:1,x
  jsl cabinet_wire_mode
  sta a:0,x
  stx $d8
  inx
  inx
  rep #$20
  .repeat 4,I
    lda PLAYER+$b8+I*2
    xba
    sta a:0+I*2,x
    lda ENERGY_HUD+28+I*2
    xba
    sta a:8+I*2,x
  .endrepeat
  sep #$20
  lda AIR_LIFE
  asl
  asl
  asl
  asl
  ora PLAYER_UI_MODE
  sta a:17,x
  lda PLAYER_UI_COUNT
  sta a:16,x
  lda PLAYER_UI_MODE+1
  sta a:19,x
  lda PLAYER_UI_COUNT+1
  sta a:18,x
  lda PLAYER+$d1
  sta a:21,x
  lda PLAYER+$d7
  sta a:20,x
  lda GAME_CREDITS
  sta a:23,x
  lda CAB_RESULT_DIGITS
  sta a:22,x
  .repeat 6,I
    lda CAB_RESULT_DIGITS+1+I*2
    sta a:25+I*2,x
    lda CAB_RESULT_DIGITS+2+I*2
    sta a:24+I*2,x
  .endrepeat
  lda GAME_FLOW
  cmp #3
  bcs :+
  lda SPECIAL_TIMER
  bra :++
:
  lda CAB_ENDING_TEXT
:
  sta a:34,x
special_packet_site:
  lda SPECIAL_FLAGS
  sta a:37,x
  lda CAB_ENDING
  cmp #2
  bne :+
  lda #1
  bra :++
:
  lda #0
:
  pha
  lda CAB_LIVE_LAYOUT
  beq :+
  pla
  ora #2                      ; extra fields follow the normal world trailer
  bra :++
:
  pla
:
  sta a:36,x
  rep #$20
  txa
  clc
  adc #38
  tax
  sep #$20
  lda CAB_LIVE_LAYOUT
  beq @no_live_fields
  rep #$20
  .repeat 6,I
    lda CAB_LIVE_VALUES+I*2
    xba
    sta a:I*2,x
  .endrepeat
  lda CAB_LIVE_LAYOUT
  and #255
  xba
  sta a:12,x
  txa
  clc
  adc #14
  tax
  sep #$20
@no_live_fields:
  lda GAME_FLOW
  stx WORLD_OUTPUT
  jsl cabinet_layout_append
  bcc :+
  rtl
:
  sep #$20
  lda GAME_FLOW
  cmp #16
  bne :+
  jmp .loword(world_no_upload)
:
  cmp #4
  beq @cabinet_static
  cmp #5
  beq @cabinet_static
  cmp #17
  bcc :+
  cmp #30
  bcs :+
@cabinet_static:
  ; A static page may borrow world-section slot 1. Its tile art survives;
  ; quiet intro loading must restore the overwritten row metadata.
  lda #255
  sta WORLD_TAGS+1
  lda WORLD_SIDE
  cmp #1
  bne @cabinet_no_cancel
  lda #255
  sta WORLD_LOADING
.ifdef WORLD_LZ
  jsl world_inflate_cancel
.endif
@cabinet_no_cancel:
  jsl cabinet_append
  phx
  ldx $d8
  sep #$20
  lda CAB_PACKET_MODE
  sta a:0,x
  plx
  rep #$20
  rtl
:
@live_world:
.a8
  rep #$20
  lda CAMERA+$10
  and #255
  tax
  sep #$20
  lda f:WORLD_REGION_MAP,x
  sta WORLD_CURRENT
  cmp #WORLD_INTRO_ID
  beq @route
  cmp WORLD_TAGS
  beq @route
  cmp WORLD_TAGS+1
  beq @route
  lda #$ea                    ; never read an unresident map section
  sta f:$050301
  jmp .loword(world_no_upload)
@route:
.ifdef WORLD_LZ
  lda f:$018d10
  beq :+
  cmp #2
  beq @ready_lz
  jmp .loword(world_no_upload)
@ready_lz:
  rep #$20
  ; The inflated world batch also needs the transition helper before it.
  ; Use the actual expanded size in the shared packet-cap check.
  lda CAMERA+$0f
  cmp #$d500
  bne @finish_lz
  lda D500_INDEX
  bmi @finish_lz
  lda f:WL_FINAL
  sta D500_FOLLOW
  jsl d500_stage_append
@finish_lz:
  ldx WORLD_OUTPUT
world_lz_finish_call = *
  jsl world_inflate_finish
  jmp @after_copy
.a8
:
.endif
  lda WORLD_LOADING
  cmp #255
  beq :+
  jmp .loword(@quiet)
:
.ifdef WORLD_LZ
  jsl world_choose_region
  cmp #255
  bne @load
  jmp .loword(world_no_upload)
.else
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
  bne @load
@next_candidate:
  iny
  dec WORLD_SKIPS
  bne @candidate
@none:
  jmp .loword(world_no_upload)
.endif
@load:
  sta WORLD_LOADING
  rep #$20
  and #31
  tax
  sep #$20
  lda f:WORLD_REGION_SIDE,x
  sta WORLD_SIDE
  rep #$20
  and #1
  asl
  asl
  sta $d0
  lda WORLD_LOADING
  and #31
  asl
  asl
  asl
  ora $d0
  tax
  lda f:WORLD_DIRECTORY,x
  sta WORLD_LIST
  lda f:WORLD_DIRECTORY+2,x
  sta WORLD_LIST+2
  stz WORLD_OFFSET
  sep #$20
@quiet:
.ifdef WORLD_LZ
  ; The report's next region has priority over stale object occupancy.
  lda CAB_RESULT_ACTIVE
  bne @work
.endif
  lda CAMERA+$10
  cmp #$d0
  bcc @objects
  cmp #$d8
  bcc @work
@objects:
  ; Bosses and crowded waves own the frame. Their art is already resident.
  ldx #8
@large:
  lda LARGE_POOL,x
  bne @busy
  rep #$20
  txa
  clc
  adc #128
  tax
  sep #$20
  cpx #1536
  bcc @large
  ldx #8
  stz $d0
@small:
  lda ENEMY_POOL,x
  beq :+
  inc $d0
  lda $d0
  cmp #5
  bcs @busy
:
  rep #$20
  txa
  clc
  adc #32
  tax
  sep #$20
  cpx #512
  bcc @small
  bra @work
@busy:
  ; A boss or crowded wave must not starve the next region forever.
  ; One packet every four submitted pictures keeps the transfer moving.
  rep #$20
  lda GAME_PICTURE
  and #3
  sep #$20
  beq @work
  jmp .loword(world_no_upload)
@work:
  lda #32
  sta WORLD_SKIPS
@entry:
  rep #$20
  lda WORLD_LIST
  sta $d0
  lda WORLD_LIST+2
  sta $d2
  ldy WORLD_OFFSET
  lda [$d0],y
  cmp #$fffe
  bne :+
  jmp @complete
:
  sta WORLD_SLOT
  iny
  iny
  rep #$20
  lda [$d0],y
  sta WORLD_TILE
  iny
  iny
  lda [$d0],y
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
  lda WORLD_SLOT
  cmp #$ffff
  beq @copy
  asl
  tax
  lda f:WORLD_SLOTS,x
  cmp WORLD_TILE
  bne @copy
  sep #$20
  dec WORLD_SKIPS
  bne @entry
  jmp .loword(world_no_upload)
@copy:
.a16
.ifdef WORLD_LZ
  lda WORLD_LENGTH
  bpl :+
  and #$7fff
  sta WORLD_LENGTH
  jsl world_inflate_begin
  jmp .loword(world_no_upload)
:
.endif
  jsl d500_stage_world
  ldx WORLD_OUTPUT
  ldy #0
@word:
  lda [$d4],y
  xba
  sta a:0,x
  inx
  inx
  iny
  iny
  cpy WORLD_LENGTH
  bcc @word
@after_copy:
  stx WORLD_OUTPUT
  lda WORLD_SLOT
  cmp #$ffff
  beq @copied
  asl
  tax
  lda WORLD_TILE
  sta f:WORLD_SLOTS,x
@copied:
.ifdef WORLD_LZ
  jsl world_inflate_prefetch
.endif
  ldx WORLD_OUTPUT
  rtl
@complete:
.a16
  rep #$20
  lda WORLD_SIDE
  and #1
  tax
  sep #$20
  lda WORLD_LOADING
  sta WORLD_TAGS,x
  lda #255
  sta WORLD_LOADING
world_no_upload:
.a8
  rep #$20
  jsl d500_stage_empty
  ldx WORLD_OUTPUT
  lda #0
  sta a:0,x
  inx
  inx
  rtl

.ifdef WORLD_LZ
.pushseg
.segment "INPUT"
.include "world_lz.s"
.popseg
.endif

; Same-bank trampoline is installed only while an attack/suppression runs.
.segment "GAMEFLOW"
special_packet_trampoline:
  jsl special_packet_flash
  rts
