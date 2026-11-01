; The decisions of the four-piece carrier aircraft (US arcade bank 4
; $B366-$B4FD). D = the head record. Each decision returns its next motion
; record through large_ai_selected; a shot sets LA_BULLET.
; The family bytes of the object record for these aircraft.
LARGE_PLANE_HEADING = $10    ; the heading, 0-31
LARGE_PLANE_STEP = $10       ; large_plane_wrap: the next large_plane_sequence entry
LARGE_PLANE_TIME = $11       ; decisions left of this step
; Bank-4 motion records (large_ai_selected).
MOTION_LARGE_PLANE_BEGIN = $b526
MOTION_LARGE_PLANE_WRAP = $b583
MOTION_LARGE_PLANE_WAIT = $b58d
MOTION_LARGE_PLANE_LEAVE = $b797      ; LARGE_PLANE_HEADING below 16
MOTION_LARGE_PLANE_LEAVE_HIGH = $b6bf ; LARGE_PLANE_HEADING 16 or more
LARGE_PLANE_WRAP = 16        ; after the wrap: SPR_ALONG and LARGE_PLANE_STEP
HEADING_MIN = 8              ; the aim keeps the heading in HEADING_MIN..HEADING_MAX-1
HEADING_MAX = 24
LEAVE_DISTANCE = 50          ; closer along to the player than this: the plane leaves
.a8
.i16

; large_plane_begin: the plane starts with no contacts.
large_plane_begin:
.a16
  a8
  stz OBJ_FLAGS
  a16
  lda #MOTION_LARGE_PLANE_BEGIN
  jmp .loword(large_ai_selected)

; large_plane_wrap: when the plane has passed the field (SPR_ALONG_HIGH) it
; comes back at the top at one of 16 places (large_plane_positions, random
; stream 2, step $99), which also gives its first wait. Else it follows
; large_plane_sequence: 3-byte entries of (decisions, motion record).
large_plane_wrap:
.a16
  a8
  lda SPR_ATTR
  and #SPR_ALONG_HIGH
  beq @sequence
  sta 2*SPRITE_SIZE+SPR_ATTR    ; the upper piece: SPR_ALONG_HIGH only
  lda #LARGE_PLANE_WRAP
  sta SPR_ALONG
  sta LARGE_PLANE_STEP
  stz 2*SPRITE_SIZE+SPR_ALONG
  stz OBJ_DURATION
  stz LARGE_PLANE_TIME
  lda RANDOM_STATE+2
  pha
  clc
  adc #$99
  sta RANDOM_STATE+2
  pla
  and #15
  asl                           ; two bytes for each place
  a16
  and #255
  tax
  a8
  lda f:large_plane_positions,x
  sta SPR_CROSS
  lda f:large_plane_positions+1,x
  sta LARGE_PLANE_TIME
  a16
  lda #MOTION_LARGE_PLANE_WRAP
  jmp .loword(large_ai_selected)
@sequence:
.a8
  lda LARGE_PLANE_TIME
  beq @new
  dec LARGE_PLANE_TIME
  lda LARGE_PLANE_STEP
  jsr .loword(large_plane_index)
  bra @pointer
@new:
  lda LARGE_PLANE_STEP
  inc LARGE_PLANE_STEP
  jsr .loword(large_plane_index)
  lda f:large_plane_sequence,x
  sta LARGE_PLANE_TIME
@pointer:
  a16
  lda f:large_plane_sequence+1,x
  jmp .loword(large_ai_selected)
; large_plane_index: X = A * 3 (a large_plane_sequence entry).
large_plane_index:
.a8
  a16
  and #255
  sta a:LARGE_PLANE_OFFSET
  asl
  clc
  adc a:LARGE_PLANE_OFFSET
  tax
  a8
  rts

; large_plane_wait: wait LARGE_PLANE_TIME decisions, then maybe shoot (1 in 2,
; random stream 5, step $88) and choose the next path.
large_plane_wait:
.a16
  a8
  lda LARGE_PLANE_TIME
  bne @waiting
  lda RANDOM_STATE+5
  pha
  clc
  adc #$88
  sta RANDOM_STATE+5
  pla
  lsr
  bcc large_plane_select
  jsr .loword(large_plane_shot)
  bra large_plane_select
@waiting:
  dec LARGE_PLANE_TIME
  a16
  lda #MOTION_LARGE_PLANE_WAIT
  jmp .loword(large_ai_selected)

; large_plane_enable: from now on shots and players can hit the plane.
large_plane_enable:
.a16
  a8
  lda #OF_CONTACT|OF_SHOT
  sta OBJ_FLAGS
  a16
  lda #MOTION_LARGE_PLANE_WAIT
  jmp .loword(large_ai_selected)

; large_plane_aim: turn the heading one step towards the target player,
; inside HEADING_MIN..HEADING_MAX-1, then choose the path.
large_plane_aim:
.a16
  a8
  jsl ai_target_far             ; A = the direction to the target
  cmp LARGE_PLANE_HEADING
  beq large_plane_select
  bcc @decrease
  lda LARGE_PLANE_HEADING
  inc
  and #31
  cmp #HEADING_MAX
  bcs large_plane_select
  sta LARGE_PLANE_HEADING
  bra large_plane_select
@decrease:
  lda LARGE_PLANE_HEADING
  dec
  and #31
  cmp #HEADING_MIN
  bcc large_plane_select
  sta LARGE_PLANE_HEADING
; large_plane_select: the path of the heading (large_plane_paths), or leave
; when the plane is below the target or within LEAVE_DISTANCE above it.
large_plane_select:
.a8
  jsl ai_target_far             ; Y = the target player record
  lda SPR_ALONG
  sec
  sbc PLAYER+SPR_ALONG,y
  bcc @leave
  cmp #LEAVE_DISTANCE
  bcc @leave
  lda LARGE_PLANE_HEADING
  sec
  sbc #HEADING_MIN
  asl
  a16
  and #255
  tax
  lda f:large_plane_paths,x
  jmp .loword(large_ai_selected)
@leave:
.a8
  lda LARGE_PLANE_HEADING
  cmp #16
  a16
  lda #MOTION_LARGE_PLANE_LEAVE_HIGH
  bcs :+
  lda #MOTION_LARGE_PLANE_LEAVE
:
  jmp .loword(large_ai_selected)

; large_plane_fire: shoot 1 time in 4 (random stream 5, step $99), then the
; step after the code tail.
large_plane_fire:
.a16
  a8
  lda RANDOM_STATE+5
  pha
  clc
  adc #$99
  sta RANDOM_STATE+5
  pla
  and #3
  bne @continue
  jsr .loword(large_plane_shot)
@continue:
  a16
  lda LARGE_SOURCE
  clc
  adc #STEP_TAIL_SIZE
  jmp .loword(large_ai_selected)

; large_plane_shot: an aimed bullet from below the plane's nose.
large_plane_shot:
.a8
  jsl ai_target_far
  lda #LA_BULLET
  sta LARGE_AI_ACTION
  lda SPR_CROSS
  clc
  adc #SPRITE_HALF
  sta LARGE_AI_X
  lda SPR_ALONG
  sec
  sbc #SPRITE_HALF
  sta LARGE_AI_Y
  rts
