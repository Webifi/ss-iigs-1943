; The ship finish: the timed explosions over a destroyed ship (US arcade
; $32E2-$343E). A pattern (STAGE_BLAST_PATTERN) is a list of explosion
; pieces around the destroyed core (SHIP_FINISH_OWNER): each a cross and an
; along offset and the wait before the next piece. The looping finish
; (SF_LOOP) repeats its list; the final one (SF_FINAL) ends with a giant
; explosion (SF_GIANT) on most stages, then the ship explosion sounds and
; the players leave. A full pool waits for the next tick.
.a8
.i16
; A piece of ship_finish_paths: FINISH_STEP_SIZE bytes; FINISH_END ends a list.
FS_CROSS = 0                 ; the cross offset from the core
FS_ALONG = 1                 ; the signed along offset from the core
FS_WAIT = 2                  ; ticks before the next piece; 0: at once
FINISH_STEP_SIZE = 3
FINISH_END = 255
FINISH_FOUR = 0              ; SHIP_FINISH_KIND: an explosion of four pieces
FINISH_GIANT = 1             ; SHIP_FINISH_KIND: a giant explosion of sixteen

; ship_finish_begin: start the finish SF_LOOP or SF_FINAL (A) of the core
; STAGE_BLAST_SOURCE with STAGE_BLAST_PATTERN; no special until the takeoff.
ship_finish_begin:
  sta SHIP_FINISH_ACTIVE
  stz SHIP_FINISH_WAIT
  stz SHIP_FINISH_INDEX
  lda STAGE_BLAST_PATTERN
  sta SHIP_FINISH_PATTERN
  lda #1
  sta STAGE_FINISH
  a16
  lda STAGE_BLAST_SOURCE
  sta SHIP_FINISH_OWNER
  a8
  rtl

; ship_finish_tick: one tick of the finish (large_loop_tick). JSL.
ship_finish_tick:
  lda SHIP_FINISH_ACTIVE
  bne :+
  rtl
:
  lda SHIP_FINISH_WAIT
  beq @ready
  dec SHIP_FINISH_WAIT
  beq :+
  rtl
:
  lda #SND_BULLET_HIT
  jsl game_sound_request        ; arcade $337C
@ready:
  lda SHIP_FINISH_ACTIVE
  cmp #SF_GIANT
  bne @piece
  jmp .loword(ship_finish_giant)
@piece:
  jsr .loword(ship_finish_select_path)
  jsr .loword(ship_finish_read)
  cmp #FINISH_END
  bne @spawn
  ; The end of the list: the looping finish starts again; the final finish
  ; goes on to the giant explosion, except on the air boss stages.
  lda SHIP_FINISH_ACTIVE
  cmp #SF_LOOP
  bne @end
  stz SHIP_FINISH_INDEX
  bra @piece
@end:
  lda CAMERA_STAGE
  cmp #AIR_STAGE_1
  beq ship_finish_done
  cmp #AIR_STAGE_2
  beq ship_finish_done
  cmp #AIR_STAGE_3
  beq ship_finish_done
  lda #SF_GIANT
  sta SHIP_FINISH_ACTIVE
  jmp .loword(ship_finish_giant)
@spawn:
  stz SHIP_FINISH_KIND          ; FINISH_FOUR
  jsl ship_finish_spawn
  bcs :+
  rtl
:
  inc SHIP_FINISH_INDEX
  ldx SHIP_FINISH_PATH
  inx
  inx                           ; FS_WAIT
  jsr .loword(ship_finish_read)
  sta SHIP_FINISH_WAIT
  bne @return
  lda #SND_BULLET_HIT
  jsl game_sound_request        ; arcade $337C
  bra @piece
@return:
  rtl
; ship_finish_giant: the giant explosion; then the players leave.
ship_finish_giant:
.a8
  lda #FINISH_GIANT
  sta SHIP_FINISH_KIND
  jsl ship_finish_spawn
  bcs :+
  rtl
:
  lda #PS_LEAVE
  sta STAGE_PLAYER_REQUEST
; ship_finish_done: the finish ends: the camera runs again, the ship
; explosion and the finish sounds play.
ship_finish_done:
.a8
  stz CAMERA_HOLD
  stz SHIP_FINISH_ACTIVE
  lda #SND_SHIP_EXPLODE         ; arcade $33B0
  jsl game_sound_request
  lda #SND_SHIP_FINISH
  jsl game_sound_request
  rtl
.assert FS_WAIT = 2, error      ; the two INXs above

; ship_finish_select_path: SHIP_FINISH_PATH = X = the piece SHIP_FINISH_INDEX
; of the pattern's list.
ship_finish_select_path:
.a8
  a16
  lda SHIP_FINISH_PATTERN
  and #255
  asl
  tax
  lda f:ship_finish_paths,x
  sta SHIP_FINISH_PATH
  lda SHIP_FINISH_INDEX
  and #255
  sta SHIP_FINISH_OFFSET
  asl
  clc
  adc SHIP_FINISH_OFFSET        ; times FINISH_STEP_SIZE
  clc
  adc SHIP_FINISH_PATH
  sta SHIP_FINISH_PATH
  tax
  a8
  rts
; The finish data (ship_finish_offsets and the lists) share one bank.
SHIP_FINISH_BANK = .bankbyte(ship_finish_offsets) << 16
; ship_finish_read: A = the finish data byte at X.
ship_finish_read:
  lda f:SHIP_FINISH_BANK,x
  rts

; ship_finish_spawn: one explosion of SHIP_FINISH_KIND: a four-piece one in
; a turret slot at the list piece, or a giant one (giant_allocate) at the
; pattern's ship_finish_offsets entry. The place is the core's place plus the
; offsets, with a 9-bit along (SPR_ALONG_HIGH). Returns carry 0 when the pool
; is full. JSL.
ship_finish_spawn:
.a8
  lda SHIP_FINISH_KIND
  bne @giant
  jsr .loword(large_allocate_turret)
  bra @allocated
@giant:
  jsr .loword(giant_allocate)
@allocated:
  bcs @found
  clc
  rtl
@found:
  a16
  txa
  clc
  adc #LARGE_POOL
  sta SHIP_FINISH_DEST
  tay
  lda SHIP_FINISH_KIND
  and #255
  asl
  asl
  asl
  asl
  asl                           ; times OBJECT_SIZE: the template
  tax
  .repeat OBJECT_SIZE/2
    lda f:ship_finish_templates,x
    sta a:0,y                   ; Y holds the record address
    inx
    inx
    iny
    iny
  .endrepeat
  a8
  lda SHIP_FINISH_KIND
  bne @giant_offset
  jsr .loword(ship_finish_select_path)
  bra @position
@giant_offset:
  a16
  lda SHIP_FINISH_PATTERN
  and #255
  asl
  clc
  adc #.loword(ship_finish_offsets)
  tax
  a8
@position:
.a8
  jsr .loword(ship_finish_read) ; FS_CROSS
  ldy SHIP_FINISH_OWNER
  clc
  adc a:SPR_CROSS,y
  ldy SHIP_FINISH_DEST
  sta a:SPR_CROSS,y
  inx
  jsr .loword(ship_finish_read) ; FS_ALONG, signed
  a16
  and #255
  cmp #128
  bcc :+
  ora #$ff00
:
  sta SHIP_FINISH_OFFSET
  ; SHIP_FINISH_Y = the core's 9-bit along (SPR_ALONG_HIGH is bit 8) + offset.
  ldx SHIP_FINISH_OWNER
  lda a:SPR_ATTR,x
  and #SPR_ALONG_HIGH
  asl
  asl
  asl
  asl
  sta SHIP_FINISH_Y
  lda a:SPR_ALONG,x
  and #255
  ora SHIP_FINISH_Y
  clc
  adc SHIP_FINISH_OFFSET
  sta SHIP_FINISH_Y
  ldx SHIP_FINISH_DEST
  a8
  sta a:SPR_ALONG,x
  sec
  sbc #PIECE_RISE
  sta a:2*SPRITE_SIZE+SPR_ALONG,x
  lda SHIP_FINISH_KIND
  beq @attr
  lda SHIP_FINISH_Y             ; a giant: records 8 and 10 further up
  sec
  sbc #2*PIECE_RISE
  sta a:8*SPRITE_SIZE+SPR_ALONG,x
  sec
  sbc #PIECE_RISE
  sta a:10*SPRITE_SIZE+SPR_ALONG,x
@attr:
  lda SHIP_FINISH_Y+1           ; bit 8 of the along
  beq @inside
  lda a:SPR_ATTR,x
  ora #SPR_ALONG_HIGH
  bra @write
@inside:
  lda a:SPR_ATTR,x
  and #<~SPR_ALONG_HIGH
@write:
  sta a:SPR_ATTR,x
  sta a:2*SPRITE_SIZE+SPR_ATTR,x
  pha
  lda SHIP_FINISH_KIND
  beq @four
  pla
  sta a:8*SPRITE_SIZE+SPR_ATTR,x
  sta a:10*SPRITE_SIZE+SPR_ATTR,x
  sec
  rtl
@four:
  pla
  sec
  rtl
.assert SPR_ALONG_HIGH = $10 .and OBJECT_SIZE = 32, error

; giant_allocate: four free large slots from slot 4n. Returns carry 1 and
; X = the offset of the giant's head (GIANT_HEAD), or carry 0.
giant_allocate:
.a8
  ldx #0
@group:
  lda LARGE_POOL+OBJ_TYPE,x
  ora LARGE_POOL+LARGE_SIZE+OBJ_TYPE,x
  ora LARGE_POOL+2*LARGE_SIZE+OBJ_TYPE,x
  ora LARGE_POOL+3*LARGE_SIZE+OBJ_TYPE,x
  beq @found
  a16
  txa
  clc
  adc #4*LARGE_SIZE
  tax
  a8
  cpx #LARGE_COUNT*LARGE_SIZE
  bne @group
  clc
  rts
@found:
  a16
  txa
  clc
  adc #GIANT_HEAD
  tax
  a8
  sec
  rts
