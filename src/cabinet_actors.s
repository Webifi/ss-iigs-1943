; The actors of the ending: the flag (ENEMY_POOL), the plane that flies
; across and the dog (BULLETS records); the art is in the cache. The times
; are arcade frames: UPDATE_FRAMES each update.
ACTOR_IDLE = $ffff           ; CAB_FLAG_TIME, CAB_FLY_TIME, CAB_DOG_INDEX: not started
ENDING_FLAG_STEP = 1         ; CAB_ENDING_STEP of the flag
ENDING_FLY_STEP = 4          ; the plane flies from this step
ENDING_DOG_STEP = 11         ; the dog walks from this step
FLAG_RISE_MAX = 150          ; the flag rises a quarter pixel a frame, up to this
FLAG_BASE = 6                ; FLAG_ALONG at the start
FLAG_CYCLE = 40              ; frames of the flag's pose cycle
FLAG_POSE_FRAMES = 10        ; frames of each pose
FLAG_POSE_SIZE = 64          ; cabinet_flag_poses: ENEMY_COUNT records of 4 bytes a pose
FLAG_RECORD = 4              ; code, attributes, cross, rise
FLY_SPEED = 56               ; CAB_FLY_X (8.8) each frame
FLY_ATTR = $a9
FLY_ALONG = 200
DOG_ATTR = 9
DOG_ALONG = 128

; cabinet_actors_init: no actor yet. JSL.
cabinet_actors_init:
.a8
  a16
  lda #ACTOR_IDLE
  sta CAB_FLAG_TIME
  sta CAB_FLY_TIME
  sta CAB_DOG_INDEX
  stz CAB_FLY_X
  stz CAB_FLAG_PHASE
  a8
  rtl

; cabinet_actors_tick: one update of the ending actors (cabinet). JSL.
cabinet_actors_tick:
.a8
.i16
  ; The flag rises after the first paragraph, before its pause.
  lda CAB_ENDING_STEP
  cmp #ENDING_FLAG_STEP
  bne @flag_ready
  a16
  lda CAB_TEXT_CLOCK
  cmp #CAB_FLAG_START_TICKS
  bcc @flag_ready16
  lda CAB_FLAG_TIME
  bpl :+
  stz CAB_FLAG_TIME
:
  a8
@flag_ready:
  a16
@flag_ready16:
  lda CAB_FLAG_TIME
  bpl :+
  jmp @fly
:
  clc
  adc #UPDATE_FRAMES
  sta CAB_FLAG_TIME
  lsr
  lsr
  ; The arcade tests $98 only after a whole pose cycle: FLAG_BASE + 15
  ; cycles of FLAG_CYCLE / 4 stops at 156, not at 152 in a cycle.
  cmp #FLAG_RISE_MAX
  bcc :+
  lda #FLAG_RISE_MAX
:
  clc
  adc #FLAG_BASE
  sta FLAG_ALONG
  lda CAB_FLAG_PHASE
  clc
  adc #UPDATE_FRAMES
  cmp #FLAG_CYCLE
  bcc :+
  sbc #FLAG_CYCLE
:
  sta CAB_FLAG_PHASE
  ldx #0
@divide:
  ; X = the pose: FLAG_POSE_SIZE for each FLAG_POSE_FRAMES of the phase.
  cmp #FLAG_POSE_FRAMES
  bcc @records
  sec
  sbc #FLAG_POSE_FRAMES
  pha
  txa
  clc
  adc #FLAG_POSE_SIZE
  tax
  pla
  bra @divide
@records:
  ldy #0
  a8
@flag_record:
  lda f:cabinet_flag_poses,x
  sta ENEMY_POOL,y
  lda f:cabinet_flag_poses+1,x
  sta FLAG_ATTR
  lda f:cabinet_flag_poses+2,x
  sta ENEMY_POOL+SPR_CROSS,y
  a16
  lda f:cabinet_flag_poses+3,x
  and #255
  sta FLAG_RISE
  lda FLAG_ALONG
  sec
  sbc FLAG_RISE
  a8
  sta ENEMY_POOL+SPR_ALONG,y
  lda FLAG_ATTR
  bcs :+
  ora #SPR_ALONG_HIGH           ; below the field
:
  sta ENEMY_POOL+SPR_ATTR,y
  lda #1                        ; an object that shows
  sta ENEMY_POOL+OBJ_TYPE,y
  a16
  txa
  clc
  adc #FLAG_RECORD
  tax
  tya
  clc
  adc #OBJECT_SIZE
  tay
  cpy #ENEMY_COUNT*OBJECT_SIZE
  bcc :+
  bra @fly
:
  a8
  bra @flag_record
@fly:
.a16
  ; The plane flies across once (a pose each 16 frames).
  a8
  lda CAB_ENDING_STEP
  cmp #ENDING_FLY_STEP
  bcc @dog
  a16
  lda CAB_FLY_TIME
  bpl :+
  lda #0
:
  clc
  adc #UPDATE_FRAMES
  sta CAB_FLY_TIME
  lsr
  lsr
  lsr
  lsr
  and #3
  tax
  lda CAB_FLY_X
  cmp #ACTOR_IDLE               ; across: done
  beq @fly_done
  clc
  adc #FLY_SPEED
  bcc :+
  lda #ACTOR_IDLE
:
  sta CAB_FLY_X
  cmp #ACTOR_IDLE
  beq @fly_done
  a8
  lda f:cabinet_fly_poses,x
  sta BULLETS+SPR_CODE
  lda #FLY_ATTR
  sta BULLETS+SPR_ATTR
  lda CAB_FLY_X+1
  sta BULLETS+SPR_CROSS
  lda #FLY_ALONG
  sta BULLETS+SPR_ALONG
  lda #1
  sta BULLETS+OBJ_TYPE
  bra @dog
@fly_done:
.a16
  a8
  stz BULLETS+OBJ_TYPE
@dog:
  ; The dog walks (cabinet_dog_poses: code, cross).
  lda CAB_ENDING_STEP
  cmp #ENDING_DOG_STEP
  bcc @done
  bne @dog_started
  a16
  lda CAB_TEXT_CLOCK
  cmp #CAB_DOG_START_TICKS
  bcs @dog_ready
  a8
  rtl
@dog_started:
  a16
@dog_ready:
  lda CAB_DOG_INDEX
  bpl :+
  lda #0
:
  cmp #CABINET_DOG_BYTES-2
  bcs @dog_done
  tax
  clc
  adc #2
  sta CAB_DOG_INDEX
  a8
  lda f:cabinet_dog_poses,x
  sta BULLETS+OBJECT_SIZE+SPR_CODE
  lda #DOG_ATTR
  sta BULLETS+OBJECT_SIZE+SPR_ATTR
  lda f:cabinet_dog_poses+1,x
  sta BULLETS+OBJECT_SIZE+SPR_CROSS
  lda #DOG_ALONG
  sta BULLETS+OBJECT_SIZE+SPR_ALONG
  lda #1
  sta BULLETS+OBJECT_SIZE+OBJ_TYPE
@done:
  rtl
@dog_done:
  a8
  stz BULLETS+OBJECT_SIZE+OBJ_TYPE
  rtl
