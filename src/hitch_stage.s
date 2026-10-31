; Append a bounded quiet-time $D500 staging job to the ordinary world batch.
; M=16, X=16, DBR=0. Existing world bytes keep their original order.
D500_INDEX = $14e9
D500_FOLLOW = $14eb
D500_COPY_LENGTH = $14ed

d500_stage_world:
.a16
  lda WORLD_LENGTH
  sta D500_FOLLOW
  jmp .loword(d500_stage_append)

d500_stage_layout:
.a16
  lda CAB_LENGTH
  sta D500_FOLLOW
  jmp .loword(d500_stage_append)

d500_stage_empty:
.a16
  stz D500_FOLLOW

d500_stage_append:
.a16
  lda $d4
  pha
  lda $d6
  pha
  lda CAMERA+$0f
  cmp #$d500
  bne :+
  jmp .loword(@helper)
:
  lda D500_INDEX
  bpl @eligible16
  ; A consumed image must not be restaged in the launch animation. After
  ; a report use, first wait for that report to finish; then wait for the
  ; next report before starting another bounded transfer.
  bit #$4000
  beq @await_report
  sep #$20
  lda CAB_RESULT_ACTIVE
  beq :+
  jmp .loword(@return8)
:
  rep #$20
  lda #$8000
  sta D500_INDEX
  jmp .loword(@return16)
@await_report:
  sep #$20
  lda CAB_RESULT_ACTIVE
  bne :+
  jmp .loword(@return8)
:
  rep #$20
  stz D500_INDEX
@eligible16:
  sep #$20
@eligible:
  lda CAB_RESULT_ACTIVE
  bne @stage
  lda GAME_FLOW
  cmp #3
  bcc :+
  cmp #8                     ; ranking, warning, title, and credits
  bcc @stage
  jmp .loword(@return8)
:
  lda CAMERA+$10
  cmp #$d0
  beq @stage
  cmp #$d1
  beq @stage
  jmp .loword(@return8)
@stage:
  stz SPECIAL_WAVE_READY
  stz SPECIAL_LOADED          ; D500 uploads reuse the wave fragments
  rep #$20
  ldx D500_INDEX
  lda f:D500_STAGE_LIST,x
  bne :+
  jmp .loword(@return16)
:
  sta D500_COPY_LENGTH
  lda f:D500_STAGE_LIST+2,x
  sta $d4
  lda f:D500_STAGE_LIST+4,x
  sta $d6
  bra @check
@helper:
  lda D500_INDEX
  bpl :+
  jmp .loword(@return16)
:
  ldx D500_INDEX
  lda f:D500_STAGE_LIST,x
  beq :+                       ; all image jobs must precede the helper
  jmp .loword(@return16)
:
  lda GAME_PICTURE
  and #1
  bne @helper1
  lda #D500_HELPER0_LENGTH
  sta D500_COPY_LENGTH
  lda #.loword(D500_HELPER0_ADDRESS)
  sta $d4
  lda #.hiword(D500_HELPER0_ADDRESS)
  sta $d6
  bra @check
@helper1:
  lda #D500_HELPER1_LENGTH
  sta D500_COPY_LENGTH
  lda #.loword(D500_HELPER1_ADDRESS)
  sta $d4
  lda #.hiword(D500_HELPER1_ADDRESS)
  sta $d6
@check:
  lda WORLD_OUTPUT
  sec
  sbc #$8000
  clc
  adc D500_COPY_LENGTH
  adc D500_FOLLOW
  adc #2                         ; the terminating word
  cmp #1793
  bcs @return16                  ; leave the ordinary packet untouched
  ldx WORLD_OUTPUT
  ldy #0
@copy:
  lda [$d4],y
  xba
  sta a:0,x
  inx
  inx
  iny
  iny
  cpy D500_COPY_LENGTH
  bcc @copy
  stx WORLD_OUTPUT
  lda CAMERA+$0f
  cmp #$d500
  beq @sent_helper
  lda D500_INDEX
  clc
  adc #6
  sta D500_INDEX
  bra @return16
@sent_helper:
  sep #$20
  lda CAB_RESULT_ACTIVE
  beq :+
  rep #$20
  lda #$c000
  bra :++
:
  rep #$20
  lda #$8000
:
  sta D500_INDEX
@return8:
  rep #$20
@return16:
  pla
  sta $d6
  pla
  sta $d4
  rtl

d500_stage_return = @return16
d500_gate_site = d500_stage_append+6
d500_gate_stub:
  jsl special_stage_gate
  bcc @ordinary_gate
  pla                           ; discard JSR return before original epilogue
  jmp .loword(d500_stage_return)
@ordinary_gate:
  lda CAMERA+$0f                ; displaced instruction
  rts
