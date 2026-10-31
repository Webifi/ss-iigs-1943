; Own 65816 port of the US normal-flight movement and banking/roll animation.
; Reference: US bank 1 $8657-$8714 and $8741-$879A. Tables are ROM data,
; decoded/selected during the build. No Z80 code is executed by the port.
; PLAYER is a native object-state record; $40=input (active low), $41=speed.
; Enters/exits M=8, X=16, DBR=0. Sound, firing, collision and energy are separate.
PLAYER = $1000

flight_step:
  rep #$20
  lda $40
  eor #$ffff
  and #15
  sta $44
  lda $41
  and #255
  asl
  tax
  lda f:flight_speed_offsets,x
  sta $42
  lda PLAYER+$0d
  and #1
  bne @odd
  lda $42
  clc
  adc #48
  sta $42
@odd:
  lda $44
  asl
  clc
  adc $44
  adc $42
  tax
  sep #$20
  lda $44
  cmp PLAYER+$0c
  beq @direction_same
  sta PLAYER+$0c
  jsr flight_delay_reset
@direction_same:
  lda PLAYER+$02
  clc
  adc f:flight_moves,x
  cmp #$10
  bcs @left_inside
  lda #$10
@left_inside:
  cmp #$d0
  bcc @right_inside
  lda #$d0
@right_inside:
  sta PLAYER+$02
  clc
  adc #16
  sta PLAYER+$22
  inx
  lda PLAYER+$03
  clc
  adc f:flight_moves,x
  cmp #$12
  bcs @top_inside
  lda #$12
@top_inside:
  cmp #$d0
  bcc @bottom_inside
  lda #$d0
@bottom_inside:
  sta PLAYER+$03
  sta PLAYER+$23
  lda PLAYER+$0e
  bne flight_roll
  dec PLAYER+$0b
  bne flight_advance_phase
  jsr flight_delay_reset
  inx
  lda PLAYER+$0a
  cmp f:flight_moves,x
  beq flight_pose
  bcc @bank_up
  dec PLAYER+$0a
  bra flight_pose
@bank_up:
  inc PLAYER+$0a
flight_pose:
  lda PLAYER+$0a
  asl
  clc
  adc #$20
  sta PLAYER+$00
  inc
  sta PLAYER+$20
flight_advance_phase:
  inc PLAYER+$0d
  rts

flight_roll:
  stz PLAYER+$07
  lda PLAYER+$1c
  beq @roll_tick
  dec PLAYER+$1c
  bra flight_advance_phase
@roll_tick:
  lda #2
  sta PLAYER+$1c
  lda PLAYER+$0a
  cmp #4
  bne @roll_direction
  lda #$fe
  sta PLAYER+$1d
@roll_direction:
  lda PLAYER+$1d
  inc
  clc
  adc PLAYER+$0a
  sta PLAYER+$0a
  bne @roll_nonzero
  stz PLAYER+$1d
@roll_nonzero:
  dec PLAYER+$1c
  inc PLAYER+$1e
  lda PLAYER+$1e
  cmp #$18
  bne flight_pose
  stz PLAYER+$0e
  stz PLAYER+$1b
  stz PLAYER+$1c
  stz PLAYER+$1d
  stz PLAYER+$1e
  stz PLAYER+$1f
  lda #1
  sta PLAYER+$07
  bra flight_pose

flight_delay_reset:
  phx
  rep #$20
  lda PLAYER+$09
  and #255
  tax
  sep #$20
  lda f:flight_delays,x
  sta PLAYER+$0b
  plx
  rts

.include "flight_data.inc"
