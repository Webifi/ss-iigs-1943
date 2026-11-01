; The world: the build prepares all arcade world art; each packet carries
; one bounded upload batch of the next world section to the card. No disk
; read, no art search at run time.
.a8
.i16
WORLD_NONE = $ff             ; WORLD_LOADING, WORLD_TAGS: no section
WORLD_REGIONS = 32           ; WORLD_REGION_SIDE, WORLD_DIRECTORY entries
DECK_ROWS_FIRST = $d0        ; CAMERA_BG1_SCROLL high bytes of the carrier deck:
DECK_ROWS_END = $d8          ; the upload runs there whatever objects there are
BUSY_SMALL = 5               ; this many small enemies make an update busy
BUSY_PICTURES = 4            ; busy: one upload every BUSY_PICTURES pictures
WORLD_SKIPS_MAX = 32         ; list entries skipped at most in one packet
; A WORLD_LIST entry: the slot (WORLD_NO_SLOT: none), the tile, the length
; (bit 15: LZ-packed), the source (4 bytes). WORLD_LIST_END ends the list.
WORLD_NO_SLOT = $ffff
WORLD_LIST_END = $fffe

.segment "INPUT"
; game_world_init: the world state of a game start: the initial slots and
; tags, no inflate, no special, no section loading. JSL.
game_world_init:
  jsl special_restore_tick
  a16
  ldx #WORLD_SLOT_COUNT*2-2
@slot:
  lda f:WORLD_INITIAL_SLOTS,x
  sta f:WORLD_SLOTS,x
  dex
  dex
  bpl @slot
  stz WORLD_OFFSET
  stz D500_INDEX
  a8
  jsl world_inflate_cancel
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
  lda #WORLD_NONE
  sta WORLD_LOADING
  rtl

.segment "GAMEFLOW"
; game_world_append: the world trailer of the packet at X (state_packet):
; the camera cross, the wire mode, player 2's score, energy, weapon, the UI
; fields, the credits, the result digits, the count, the special flags and
; the trailer flags, the live fields; then the cabinet layout, a cabinet
; page, or the next world upload batch. JSL.
game_world_append:
.a16
  a8
  lda CAMERA_CROSS
  sta a:TRAILER_CROSS,x
  jsl cabinet_wire_mode
  sta a:TRAILER_MODE,x
  stx PACKET_HEADER
  inx
  inx
  a16
  .repeat (TRAILER_ENERGY2-TRAILER_SCORE2)/2,I
    lda PLAYER2+PL_SCORE+I*2
    xba
    sta a:TRAILER_SCORE2+I*2,x
    lda ENERGY_HUD+ENERGY_HUD_ROW+I*2
    xba
    sta a:TRAILER_ENERGY2+I*2,x
  .endrepeat
  a8
  lda AIR_LIFE
  asl
  asl
  asl
  asl                           ; bits 4-7
  ora PLAYER_UI_MODE
  sta a:TRAILER_UI_MODE,x
  lda PLAYER_UI_COUNT
  sta a:TRAILER_UI_COUNT,x
  lda PLAYER_UI_MODE+1
  sta a:TRAILER_UI_MODE2,x
  lda PLAYER_UI_COUNT+1
  sta a:TRAILER_UI_COUNT2,x
  lda PLAYER2+PL_WEAPON
  sta a:TRAILER_WEAPON2,x
  lda PLAYER2+PL_WEAPON_TIME
  sta a:TRAILER_TIME2,x
  lda GAME_CREDITS
  sta a:TRAILER_CREDITS,x
  ; The result digits 1-11 in byte pairs. The last pair puts digit 11 in
  ; byte 35; its byte 34 is TRAILER_COUNT, written below.
  lda CAB_RESULT_DIGITS
  sta a:TRAILER_RESULT,x
  .repeat 6,I
    lda CAB_RESULT_DIGITS+1+I*2
    sta a:TRAILER_RESULT_REST+1+I*2,x
    lda CAB_RESULT_DIGITS+2+I*2
    sta a:TRAILER_RESULT_REST+I*2,x
  .endrepeat
  ; TRAILER_COUNT: SPECIAL_TIMER in play; CAB_ENDING_TEXT on a cabinet page
  ; and for the stage result once no special uses the card.
  lda GAME_FLOW
  cmp #CAB_PAGE_FIRST
  bcs @typed
  lda CAB_RESULT_ACTIVE
  beq @special
  lda SPECIAL_TIMER
  ora SPECIAL_HOOK
  beq @typed
@special:
  lda SPECIAL_TIMER
  bra @count
@typed:
  lda CAB_ENDING_TEXT
@count:
  sta a:TRAILER_COUNT,x
special_packet_site:
  ; special_install_tick patches this LDA to JSR special_packet_trampoline.
  lda SPECIAL_FLAGS
  sta a:TRAILER_SPECIAL,x
  ; TRAILER_FLAGS: bit 0 CAB_ENDING 2, bit 1 the live fields follow.
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
  ora #2
  bra :++
:
  pla
:
  sta a:TRAILER_FLAGS,x
  a16
  txa
  clc
  adc #TRAILER_SIZE
  tax
  a8
  lda CAB_LIVE_LAYOUT
  beq @no_live_fields
  a16
  .repeat TRAILER_LIVE_LAYOUT/2,I
    lda CAB_LIVE_VALUES+I*2
    xba
    sta a:I*2,x
  .endrepeat
  lda CAB_LIVE_LAYOUT
  and #255
  xba
  sta a:TRAILER_LIVE_LAYOUT,x
  txa
  clc
  adc #TRAILER_LIVE_LAYOUT+2    ; the live fields
  tax
  a8
@no_live_fields:
  lda GAME_FLOW
  stx WORLD_OUTPUT
  jsl cabinet_layout_append
  bcc :+
  rtl
:
  a8
  lda GAME_FLOW
  cmp #PAGE_RANKING
  bne :+
  jmp .loword(world_no_upload)
:
  cmp #PAGE_TITLE
  beq @cabinet_static
  cmp #PAGE_POWER_ON
  beq @cabinet_static
  cmp #PAGE_ENDING_FIRST
  bcc :+
  cmp #PAGE_ENDING_END
  bcs :+
@cabinet_static:
  ; A static page can take world section slot 1. Its tile art stays; the
  ; quiet loading of the intro writes the row data again.
  lda #WORLD_NONE
  sta WORLD_TAGS+1
  lda WORLD_SIDE
  cmp #1
  bne @cabinet_no_cancel
  lda #WORLD_NONE
  sta WORLD_LOADING
  jsl world_inflate_cancel
@cabinet_no_cancel:
  jsl cabinet_append
  phx
  ldx PACKET_HEADER
  a8
  lda CAB_PACKET_MODE
  sta a:TRAILER_MODE,x
  plx
  a16
  rtl
:
@live_world:
.a8
  ; The play: the section under the camera must be resident.
  a16
  lda CAMERA_BG1_SCROLL+1
  and #255
  tax
  a8
  lda f:WORLD_REGION_MAP,x
  sta WORLD_CURRENT
  cmp #WORLD_INTRO_ID
  beq @route
  cmp WORLD_TAGS
  beq @route
  cmp WORLD_TAGS+1
  beq @route
  jmp .loword(world_no_upload)  ; the section is not resident: no upload
@route:
  lda f:WORLD_LZ_STATE
  beq :+
  cmp #WLS_READY
  beq @ready_lz
  jmp .loword(world_no_upload)
@ready_lz:
  ; The inflated batch goes now; on the deck the d500 helper goes first.
  a16
  lda CAMERA_BG1_SCROLL
  cmp #DECK_SCROLL
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
  ; No section loads: choose the next region and its list.
  lda WORLD_LOADING
  cmp #WORLD_NONE
  beq :+
  jmp .loword(@quiet)
:
  jsl world_choose_region
  cmp #WORLD_NONE
  bne @load
  jmp .loword(world_no_upload)
@load:
  sta WORLD_LOADING
  a16
  and #WORLD_REGIONS-1
  tax
  a8
  lda f:WORLD_REGION_SIDE,x
  sta WORLD_SIDE
  a16
  and #1
  asl
  asl                           ; the side: 4 bytes
  sta DIRECTORY_SIDE
  lda WORLD_LOADING
  and #WORLD_REGIONS-1
  asl
  asl
  asl                           ; the region: 2 sides of 4 bytes
  ora DIRECTORY_SIDE
  tax
  lda f:WORLD_DIRECTORY,x
  sta WORLD_LIST
  lda f:WORLD_DIRECTORY+2,x
  sta WORLD_LIST+2
  stz WORLD_OFFSET
  a8
@quiet:
  ; The stage result and the deck always upload.
  lda CAB_RESULT_ACTIVE
  bne @work
  lda CAMERA_BG1_SCROLL+1
  cmp #DECK_ROWS_FIRST
  bcc @objects
  cmp #DECK_ROWS_END
  bcc @work
@objects:
  ; A large object or BUSY_SMALL small enemies make the update busy.
  ldx #OBJ_TYPE
@large:
  lda LARGE_POOL,x
  bne @busy
  a16
  txa
  clc
  adc #LARGE_SIZE
  tax
  a8
  cpx #LARGE_COUNT*LARGE_SIZE
  bcc @large
  ldx #OBJ_TYPE
  stz BUSY_COUNT
@small:
  lda ENEMY_POOL,x
  beq :+
  inc BUSY_COUNT
  lda BUSY_COUNT
  cmp #BUSY_SMALL
  bcs @busy
:
  a16
  txa
  clc
  adc #OBJECT_SIZE
  tax
  a8
  cpx #ENEMY_COUNT*OBJECT_SIZE
  bcc @small
  bra @work
@busy:
  ; Busy: one upload every BUSY_PICTURES pictures, so the region still comes.
  a16
  lda GAME_PICTURE
  and #BUSY_PICTURES-1
  a8
  beq @work
  jmp .loword(world_no_upload)
@work:
  ; The next list entry whose slot does not hold its tile already.
  lda #WORLD_SKIPS_MAX
  sta WORLD_SKIPS
@entry:
  a16
  lda WORLD_LIST
  sta WORLD_POINTER
  lda WORLD_LIST+2
  sta WORLD_POINTER+2
  ldy WORLD_OFFSET
  lda [WORLD_POINTER],y
  cmp #WORLD_LIST_END
  bne :+
  jmp @complete
:
  sta WORLD_SLOT
  iny
  iny
  a16
  lda [WORLD_POINTER],y
  sta WORLD_TILE
  iny
  iny
  lda [WORLD_POINTER],y
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
  lda WORLD_SLOT
  cmp #WORLD_NO_SLOT
  beq @copy
  asl
  tax
  lda f:WORLD_SLOTS,x
  cmp WORLD_TILE
  bne @copy
  a8
  dec WORLD_SKIPS
  bne @entry
  jmp .loword(world_no_upload)
@copy:
.a16
  ; A packed entry inflates first (world_lz.s); a raw one goes now, words
  ; high byte first.
  lda WORLD_LENGTH
  bpl :+
  and #$7fff
  sta WORLD_LENGTH
  jsl world_inflate_begin
  jmp .loword(world_no_upload)
:
  jsl d500_stage_world
  ldx WORLD_OUTPUT
  ldy #0
@word:
  lda [WORLD_SOURCE],y
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
  cmp #WORLD_NO_SLOT
  beq @copied
  asl
  tax
  lda WORLD_TILE
  sta f:WORLD_SLOTS,x
@copied:
  jsl world_inflate_prefetch
  ldx WORLD_OUTPUT
  rtl
@complete:
.a16
  ; The section is resident: its tag, then no section loads.
  a16
  lda WORLD_SIDE
  and #1
  tax
  a8
  lda WORLD_LOADING
  sta WORLD_TAGS,x
  lda #WORLD_NONE
  sta WORLD_LOADING
; world_no_upload: no upload batch: a 0 word ends the packet.
world_no_upload:
.a8
  a16
  jsl d500_stage_empty
  ldx WORLD_OUTPUT
  lda #0
  sta a:0,x
  inx
  inx
  rtl

.pushseg
.segment "INPUT"
.include "world_lz.s"
.popseg

; special_packet_trampoline: special_install_tick patches special_packet_site
; to JSR here during a special attack and its quiet time.
.segment "GAMEFLOW"
special_packet_trampoline:
  jsl special_packet_flash
  rts
