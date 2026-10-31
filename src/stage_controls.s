; Original US fixed-ROM stage controls. Data-only callbacks share native
; handlers. The live player/camera records are updated in place.
.a8
.i16
STAGE_FLAGS = $1b00          ; original E140..E17F
STAGE_DIFFICULTY = $1b40     ; original E1D0..E1D7
STAGE_BOSS_COUNT = $1b48     ; original E430
STAGE_CONTROL_INDEX = $1b4a  ; build-selected index, 255 for other handlers
STAGE_WORLD_PHASE = $1b4c    ; original E130

stage_control_fast:
  lda STAGE_CONTROL_INDEX
  cmp #STAGE_CONTROL_COUNT
  bcc :+
  clc
  rtl
:
  rep #$20
  and #255
  asl
  tax
  bra stage_control_found

stage_control:
  rep #$20
  lda STAGE_CALLBACK
  ldx #0
@find:
  cmp f:stage_control_ids,x
  beq @found
  inx
  inx
  cpx #STAGE_CONTROL_COUNT*2
  bne @find
  sep #$20
  clc
  rtl
@found:
stage_control_found:
  lda f:stage_control_values,x
  sep #$20
  jmp (.loword(stage_control_targets),x)
stage_control_done:
  sec
  rtl
stage_control_pan:
  sta CAMERA_PAN_ON
  bra stage_control_done
stage_control_flag:
  rep #$20
  and #255
  tax
  sep #$20
  lda #1
  sta STAGE_FLAGS,x
  bra stage_control_done
stage_control_scroll:
  sta CAMERA+$15
  sta CAMERA+$16
  bra stage_control_done
stage_control_boss_hold:
  lda STAGE_BOSS_COUNT
  bne :+
  jmp .loword(stage_control_done)
:
  lda #255
  bra stage_control_scroll
stage_control_end:
  lda #255
  sta CAMERA+$15
  sta CAMERA+$16
  lda #12
  sta STAGE_FLAGS+9
  stz STAGE_FLAGS+11
  bra stage_control_done
stage_control_difficulty:
  clc
  adc STAGE_DIFFICULTY
  cmp #17
  bcc @store
  lda STAGE_DIFFICULTY
  bmi @zero
  lda #16
  bra @store
@zero:
  lda #0
@store:
  sta STAGE_DIFFICULTY+4
  bra stage_control_done
stage_control_capacity:
  sta STAGE_DIFFICULTY+6
  bra stage_control_done
stage_control_modifier:
  sta WAVE_MODIFIER
  bra stage_control_done
stage_control_land_camera:
  rep #$20
  and #255
  asl
  tax
  lda f:stage_land_foreground,x
  sta CAMERA+$0f
  lda CAMERA
  and #255
  ora f:stage_land_sea,x
  sta CAMERA
  sep #$20
  stz CAMERA+$13
  stz STAGE_FLAGS+5
  stz STAGE_WORLD_PHASE
  jmp .loword(stage_control_done)
stage_control_ship_camera:
  rep #$20
  and #255
  tax
  xba
  asl
  asl
  asl
  sta CAMERA+$0f
  sep #$20
  lda f:stage_ship_layer,x
  sta STAGE_FLAGS+5
  lda #255
  jmp .loword(stage_control_player_lock)
stage_control_final_camera:
  rep #$20
  lda #$c400
  sta CAMERA+$0f
  sep #$20
  lda #1
  sta STAGE_FLAGS+5
  jmp .loword(stage_control_done)
stage_control_player_2_to_10:
  ldx #0
@player:
  lda PLAYER+8,x
  cmp #2
  bne @next
  lda #10
  sta PLAYER+8,x
@next:
  cpx #128
  bne :+
  jmp .loword(stage_control_done)
:
  ldx #128
  bra @player
stage_control_player_active_6:
  ldx #0
@player:
  lda PLAYER+8,x
  beq @next
  lda #6
  sta PLAYER+8,x
@next:
  cpx #128
  bne :+
  jmp .loword(stage_control_done)
:
  ldx #128
  bra @player
stage_control_player_lock:
  sta $d0
  ldx #0
@player:
  lda PLAYER+8,x
  beq @next
  lda $d0
  sta PLAYER+$55,x
@next:
  cpx #128
  beq @done
  ldx #128
  bra @player
@done:
  jmp .loword(stage_control_done)
stage_land_foreground:
  .word $9000,$a000,$b000,$c000
stage_land_sea:
  .word $0000,$3000,$4000,$5000
stage_ship_layer:
  .byte 1,1,0,1,1,0,1,1,0,1,0,1,1,0,1,1
