; Objects that a ship starts: the planes that a carrier launches (SHIP_REQUEST
; 1-4, from LARGE_AI_FIRE) and the fragments of a secondary explosion
; (LA_EXPLOSION). Each request is used at once, so a later decision cannot
; overwrite it. The templates are ship_launch_templates (OBJECT_SIZE each).
.a8
.i16
SHIP_REQUEST_LARGE = 2       ; SHIP_REQUEST: a large plane (a core slot); else a fighter
FRAGMENT_TEMPLATE = 4        ; ship_launch_templates entry of a fragment
SURPRISE_TEMPLATE = 5        ; the entry of the extra object, 1 time in 16

; ship_launch: launch the plane SHIP_REQUEST at SHIP_REQUEST_CROSS/ALONG.
; A large plane starts half a sprite to the left and lower; its upper piece
; above it. No free slot: no plane. JSL.
ship_launch:
  lda SHIP_REQUEST
  cmp #SHIP_REQUEST_LARGE
  beq @large
  jsr .loword(ship_allocate_fighter)
  bcs @small_found
  rtl
@small_found:
  a16
  txa
  clc
  adc #ENEMY_POOL
  sta SHIP_DEST
  bra @template
@large:
.a8
  jsr .loword(large_allocate_core)
  bcs :+
  rtl
:
  a16
  txa
  clc
  adc #LARGE_POOL
  sta SHIP_DEST
@template:
.a16
  lda SHIP_REQUEST
  and #255
  dec
  asl
  asl
  asl
  asl
  asl                           ; times OBJECT_SIZE
  sta SHIP_TEMPLATE
  jsr .loword(ship_copy_template)
.a8
  lda SHIP_REQUEST
  cmp #SHIP_REQUEST_LARGE
  beq @large_position
  lda SHIP_REQUEST_CROSS
  sta a:SPR_CROSS,x
  lda SHIP_REQUEST_ALONG
  sta a:SPR_ALONG,x
  rtl
@large_position:
  lda SHIP_REQUEST_CROSS
  sec
  sbc #SPRITE_HALF
  sta a:SPR_CROSS,x
  lda SHIP_REQUEST_ALONG
  clc
  adc #SPRITE_HALF
  sta a:SPR_ALONG,x
  sec
  sbc #PIECE_RISE
  sta a:2*SPRITE_SIZE+SPR_ALONG,x
  lda a:SPR_ATTR,x
  sta a:2*SPRITE_SIZE+SPR_ATTR,x
  rtl

; ship_secondary_ready: a secondary explosion at SHIP_REQUEST_CROSS/ALONG:
; the four fragments, and 1 time in 16 (random stream 1) the extra object.
; ship_core_explode stepped stream 1 already (arcade $832E). JSL.
ship_secondary_ready:
  a16
  stz SHIP_FRAGMENT
@fragment:
  lda #FRAGMENT_TEMPLATE*OBJECT_SIZE
  sta SHIP_TEMPLATE
  a8
  jsr .loword(ship_fragment_spawn)
  a16
  inc SHIP_FRAGMENT
  inc SHIP_FRAGMENT
  lda SHIP_FRAGMENT
  cmp #4*2                      ; four word entries of ship_fragment_paths
  bne @fragment
  a8
  lda RANDOM_STATE+1
  and #15
  bne @done
  a16
  lda #SURPRISE_TEMPLATE*OBJECT_SIZE
  sta SHIP_TEMPLATE
  a8
  jsr .loword(ship_fragment_spawn)
@done:
  rtl

; ship_fragment_spawn: one object from SHIP_TEMPLATE at the request place,
; on the motion ship_fragment_paths[SHIP_FRAGMENT].
ship_fragment_spawn:
.a8
  jsr .loword(ship_allocate_fighter)
  bcc @done
  a16
  txa
  clc
  adc #ENEMY_POOL
  sta SHIP_DEST
  jsr .loword(ship_copy_template)
.a8
  lda SHIP_REQUEST_CROSS
  sta a:SPR_CROSS,x
  lda SHIP_REQUEST_ALONG
  sta a:SPR_ALONG,x
  a16
  phx
  ldx SHIP_FRAGMENT
  lda f:ship_fragment_paths,x
  plx
  sta a:OBJ_MOTION,x
  a8
@done:
  rts
; The motion records of the five destruction fragments (bank 4).
MOTION_SHIP_FRAGMENT1 = $83cb
MOTION_SHIP_FRAGMENT2 = $8435
MOTION_SHIP_FRAGMENT3 = $849f
MOTION_SHIP_FRAGMENT4 = $8509
MOTION_SHIP_FRAGMENT5 = $8573
ship_fragment_paths:
  .word MOTION_SHIP_FRAGMENT1,MOTION_SHIP_FRAGMENT2,MOTION_SHIP_FRAGMENT3
  .word MOTION_SHIP_FRAGMENT4,MOTION_SHIP_FRAGMENT5

; ship_copy_template: copy the ship_launch_templates entry at SHIP_TEMPLATE
; to the record at SHIP_DEST. Returns X = SHIP_DEST, A8. A16 on entry.
ship_copy_template:
.a16
  ldy SHIP_DEST
  ldx SHIP_TEMPLATE
  .repeat OBJECT_SIZE/2
    lda f:ship_launch_templates,x
    sta a:0,y                   ; Y holds the record address
    inx
    inx
    iny
    iny
  .endrepeat
  ldx SHIP_DEST
  a8
  rts

; ship_allocate_fighter: a free record among the first STAGE_SPAWN_SLOTS of
; ENEMY_POOL. Returns carry 1 and X = its offset, or carry 0.
ship_allocate_fighter:
.a8
  lda STAGE_SPAWN_SLOTS
  bne :+
  clc
  rts
:
  a16
  and #255
  asl
  asl
  asl
  asl
  asl                           ; times OBJECT_SIZE
  sta SHIP_SEARCH_END
  ldx #0
@slot:
  a8
  lda ENEMY_POOL+OBJ_TYPE,x
  beq @found
  a16
  txa
  clc
  adc #OBJECT_SIZE
  tax
  cpx SHIP_SEARCH_END
  bne @slot
  a8
  clc
  rts
@found:
  sec
  rts
.assert OBJECT_SIZE = 32, error
