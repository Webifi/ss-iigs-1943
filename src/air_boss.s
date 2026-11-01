; The air bosses: the boss is in the foreground (BG1), so its moves move the
; camera; its path is build data (air_motion_starts). A destroyed boss shakes
; the camera, then the stage scroll goes back (STAGE_SAVED_CAMERA).
.a8
.i16
; The air boss state (AIR_BOSS, game_ram.s): AIR_BOSS = the boss 1-3 (bit 7:
; destroyed), then:
AIR_FRAME = AIR_BOSS+1       ; updates in this second
AIR_SECONDS = AIR_BOSS+2     ; seconds of the fight
AIR_WAIT = AIR_BOSS+3        ; updates left of this path step
AIR_PATH = AIR_BOSS+4        ; 2 bytes: the next path step
AIR_DX = AIR_BOSS+6          ; 2 bytes: the cross move each update, 8.8
AIR_DY = AIR_BOSS+8          ; 2 bytes: the along move each update, 8.8
AIR_XFRAC = AIR_BOSS+10      ; the cross fraction
AIR_YFRAC = AIR_BOSS+11      ; the along fraction
AIR_SHAKE = AIR_BOSS+12      ; updates of the shake
AIR_LIFE = AIR_BOSS+13       ; the hits the core takes
AIR_LOOPS = AIR_BOSS+14      ; the turns of the path loop
AIR_RESULT = AIR_BOSS+15     ; the boss result: AR_*
AR_PASS = 0                  ; AIR_RESULT: passed
AR_RETRY = 1                 ; AIR_RESULT: failed: the boss pass again
AR_FAILED = 3                ; AIR_RESULT: failed: the game goes on
AIR_PERCENT = AIR_BOSS+16    ; 2 bytes: the result percent
AIR_CORE = AIR_BOSS+18       ; 2 bytes: the core record
AIR_TEMP = AIR_BOSS+20       ; 2 bytes: work
AIR_TEMP2 = AIR_BOSS+22      ; 2 bytes: work
AIR_BOSS_SIZE = 24
AIR_FRAMES = 60              ; updates in a second
SHAKE_STEP = 256             ; CAMERA_BG1_SCROLL up and down by this each update
SHAKE_TIME = 50              ; updates of the shake

; Stage event routines (STAGE_CALLBACK).
EVENT_AIR_RESET = $46da      ; fixed
EVENT_AIR_BOSS1 = $a6f3      ; the bank from STAGE_BANK
EVENT_AIR_BOSS2 = $a704
EVENT_AIR_BOSS3 = $a715
; A path step of the air boss (air_motion_starts, AIR_PATH).
AIR_STEP_WAIT = 0            ; a move: its updates; a loop: the loop count
AIR_STEP_KIND = 1            ; AK_MOVE, AK_JUMP, AK_LOOP, else the end
AK_MOVE = 0
AK_JUMP = 1
AK_LOOP = 2                  ; AIR_STEP_DY: the step after the last loop
AIR_STEP_DX = 2              ; a move: the cross step; a jump or loop: the target step
AIR_STEP_DY = 4              ; a move: the along step
AIR_STEP_NEXT = 6            ; a move: the next step
; The paths: air_motion_starts gives offsets in its bank.
AIR_PATH_BANK = .bankbyte(air_motion_starts) << 16

; game_airboss_event: the air boss events (stage_dispatch): EVENT_AIR_RESET
; ends the boss (the first stage also sets ENERGY_MAX); EVENT_AIR_BOSS1-3
; start the boss with AIR_BOSS + 2 lives, its path, its core (an extended
; object) and a stopped scroll. Returns carry 1 for a boss start. JSL.
game_airboss_event:
  a16
  lda STAGE_CALLBACK
  cmp #EVENT_AIR_RESET
  bne @other_event
  a8
  stz AIR_BOSS
  stz AIR_LIFE
  lda CAMERA_STAGE
  bne :+
  lda #ENERGY_START
  sta ENERGY_MAX
:
  clc
  rtl
@other_event:
.a16
  ldx #0
  cmp #EVENT_AIR_BOSS1
  beq @start
  ldx #1
  cmp #EVENT_AIR_BOSS2
  beq @start
  ldx #2
  cmp #EVENT_AIR_BOSS3
  beq @start
  a8
  clc
  rtl
@start:
.a16
  txa
  pha
  ldx #AIR_BOSS_SIZE-2
@clear:
  stz AIR_BOSS,x
  dex
  dex
  bpl @clear
  pla
  asl
  tax
  lda f:air_motion_starts,x
  sta AIR_PATH
  lda #SCROLL_STOP<<8|SCROLL_STOP
  sta CAMERA_BG1_GATE
  txa
  lsr
  inc
  a8
  sta AIR_BOSS
  clc
  adc #2
  sta AIR_LIFE
  jsr .loword(extended_allocate)
  bcc @done
  a16
  stx AIR_CORE
  .repeat OBJECT_SIZE/2,I
    lda f:air_core_template+I*2
    sta a:I*2,x
  .endrepeat
  a8
  lda AIR_LIFE
  sta a:AIR_CORE_LIFE,x
@done:
  sec
  rtl

; game_airboss_tick: one update of the air boss (stage_event): the clock;
; a live boss follows its path; a destroyed one shakes the camera for
; SHAKE_TIME, then the fight ends. JSL.
game_airboss_tick:
.a8
  lda AIR_BOSS
  bne :+
  rtl
:
  inc AIR_FRAME
  lda AIR_FRAME
  cmp #AIR_FRAMES
  bne :+
  stz AIR_FRAME
  inc AIR_SECONDS
:
  lda AIR_BOSS
  bpl @alive
  a16
  lda AIR_FRAME
  and #1
  beq @even
  lda CAMERA_BG1_SCROLL
  sec
  sbc #SHAKE_STEP
  bra @shake
@even:
  lda CAMERA_BG1_SCROLL
  clc
  adc #SHAKE_STEP
@shake:
  sta CAMERA_BG1_SCROLL
  a8
  inc AIR_SHAKE
  lda AIR_SHAKE
  cmp #SHAKE_TIME
  bcs :+
  rtl
:
  jmp .loword(game_airboss_finish)
@alive:
  lda AIR_WAIT
  bne @move
@next:
  ; The next path step.
  ldx AIR_PATH
  lda f:AIR_PATH_BANK+AIR_STEP_KIND,x
  beq @motion                   ; AK_MOVE
  cmp #AK_JUMP
  beq @jump
  cmp #AK_LOOP
  beq @loop
  jmp .loword(game_airboss_finish)
@loop:
  inc AIR_LOOPS
  lda AIR_LOOPS
  cmp f:AIR_PATH_BANK+AIR_STEP_WAIT,x
  bne @jump
  inx
  inx                           ; the last loop: AIR_STEP_DY is the target
@jump:
  a16
  lda f:AIR_PATH_BANK+AIR_STEP_DX,x
  sta AIR_PATH
  a8
  bra @next
@motion:
  lda f:AIR_PATH_BANK+AIR_STEP_WAIT,x
  sta AIR_WAIT
  a16
  lda f:AIR_PATH_BANK+AIR_STEP_DX,x
  sta AIR_DX
  lda f:AIR_PATH_BANK+AIR_STEP_DY,x
  sta AIR_DY
  lda f:AIR_PATH_BANK+AIR_STEP_NEXT,x
  sta AIR_PATH
  a8
@move:
  ; The boss moves: the camera moves the same, the objects the other way.
  a16
  lda AIR_XFRAC
  and #255
  clc
  adc AIR_DX
  sta AIR_MOVE
  a8
  sta AIR_XFRAC
  lda AIR_MOVE+1
  clc
  adc CAMERA_CROSS
  sta CAMERA_CROSS
  lda AIR_MOVE+1
  eor #$ff
  inc
  sta CAMERA_OBJECT_CROSS
  a16
  lda AIR_YFRAC
  and #255
  clc
  adc AIR_DY
  sta AIR_MOVE
  a8
  sta AIR_YFRAC
  lda AIR_MOVE+1
  eor #$ff
  inc
  sta CAMERA_OBJECT_ALONG
  a16
  lda AIR_MOVE
  xba
  and #255
  cmp #128                      ; signed: the high byte
  bcc :+
  ora #$ff00
:
  clc
  adc CAMERA_BG1_SCROLL
  sta CAMERA_BG1_SCROLL
  a8
  dec AIR_WAIT
@return:
  rtl

; game_airboss_finish: the fight ends: the stage scroll goes back and runs;
; SND_SHAKE_END. JSL.
game_airboss_finish:
.a8
  stz AIR_BOSS
  stz AIR_LIFE
  stz CAMERA_CROSS
  a16
  lda STAGE_SAVED_CAMERA
  sta CAMERA_BG1_SCROLL
  stz CAMERA_BG1_GATE
  a8
  lda #SND_SHAKE_END
  jsl game_sound_request
  rtl
