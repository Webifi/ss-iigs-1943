; random_step: one step of the eight random streams (US arcade $2553-$2596):
; RANDOM_STATE counts up; each next stream adds the one before and its prime
; step (3, 5, 7, 11, 13, 17, 19). JSR; A8.
.a8
.i16
random_step:
  inc RANDOM_STATE
  lda RANDOM_STATE
  clc
  adc RANDOM_STATE+1
  clc
  adc #3
  sta RANDOM_STATE+1
  clc
  adc RANDOM_STATE+2
  clc
  adc #5
  sta RANDOM_STATE+2
  clc
  adc RANDOM_STATE+3
  clc
  adc #7
  sta RANDOM_STATE+3
  clc
  adc RANDOM_STATE+4
  clc
  adc #11
  sta RANDOM_STATE+4
  clc
  adc RANDOM_STATE+5
  clc
  adc #13
  sta RANDOM_STATE+5
  clc
  adc RANDOM_STATE+6
  clc
  adc #17
  sta RANDOM_STATE+6
  clc
  adc RANDOM_STATE+7
  clc
  adc #19
  sta RANDOM_STATE+7
  rts
