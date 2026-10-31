; Build-ready transactions for the two original SSG chips. Each command is
; already merged across its three parts. No per-part pitch/layout work here.
; D=$1E00, DBR=0, A8/X16. DOC mode is owned by the sound IRQ.
.a8
.i16
RUN_STATES = $18500
RUN_PTR = $d0
RUN_ALIAS = $d4
RUN_SLOT = $1eb4
RUN_ORIGIN = $1eb2
RUN_GROUPS = $1eb6
RUN_BYTES = $1eb7
RUN_TEMP = $1eb0
SSG_ACTIVE = $1eba
; State/32: base24, PC16, wait16, repeat-PC16, repeat-left8, active8.

audio_ssg_command:
  lda SSG_PENDING
  beq @return
  stz SSG_PENDING
  rep #$20
  and #63
  asl
  asl
  tax
  lda f:SSG_COMMAND_ENTRIES,x
  sta RUN_PTR
  sep #$20
  lda f:SSG_COMMAND_ENTRIES+2,x
  sta RUN_PTR+2
  ora RUN_PTR
  ora RUN_PTR+1
  beq @return
  lda f:SSG_COMMAND_ENTRIES+3,x
  rep #$20
  and #255
  tax
  lda RUN_PTR
  sta f:RUN_STATES,x
  lda #0
  sta f:RUN_STATES+3,x
  sta f:RUN_STATES+5,x
  lda #$ffff
  sta f:RUN_STATES+7,x
  sep #$20
  lda RUN_PTR+2
  sta f:RUN_STATES+2,x
  lda #1
  sta f:RUN_STATES+10,x
  jsr .loword(run_prime)
@return:
  rtl

run_pointer:
  rep #$20
  lda f:RUN_STATES,x
  sta RUN_PTR
  lda f:RUN_STATES+3,x
  tay
  sep #$20
  lda f:RUN_STATES+2,x
  sta RUN_PTR+2
  rts

run_prime:
  jsr .loword(run_pointer)
  lda [RUN_PTR],y
  iny
  sta RUN_TEMP
  stz RUN_TEMP+1
  lda RUN_TEMP
  bpl @short
  and #127
  sta RUN_TEMP
  lda [RUN_PTR],y
  iny
  rep #$20
  and #127
  xba
  lsr
  ora RUN_TEMP
  sta RUN_TEMP
  sep #$20
@short:
  rep #$20
  lda RUN_TEMP
  sta f:RUN_STATES+5,x
  tya
  sta f:RUN_STATES+3,x
  sep #$20
  rts

audio_ssg_tick:
@mode:
  lda f:$e0c03c
  bmi @mode
  lda DOC_MASTER
  ora #$20
  sta f:$e0c03c
  ldx #0
@part:
  stx RUN_SLOT
  lda f:RUN_STATES+10,x
  beq @next
  rep #$20
  lda f:RUN_STATES+5,x
  beq @due
  dec
  sta f:RUN_STATES+5,x
  bne @next16
@due:
  sep #$20
  jsr .loword(run_pointer)
  sty RUN_ORIGIN
  lda [RUN_PTR],y
  iny
  cmp #0
  beq @end
  cmp #128
  beq @repeat
  cmp #129
  beq @alias
  jsr .loword(run_write)
  bra @advance
@alias:
  rep #$20
  lda [RUN_PTR],y
  iny
  iny
  phy
  tay
  lda RUN_PTR
  sta RUN_ALIAS
  sep #$20
  lda RUN_PTR+2
  sta RUN_ALIAS+2
  rep #$20
  lda #.loword(SSG_RUN_POOL)
  sta RUN_PTR
  sep #$20
  lda #^SSG_RUN_POOL
  sta RUN_PTR+2
  lda [RUN_PTR],y
  iny
  jsr .loword(run_write)
  rep #$20
  ply
  lda RUN_ALIAS
  sta RUN_PTR
  sep #$20
  lda RUN_ALIAS+2
  sta RUN_PTR+2
@advance:
  rep #$20
  tya
  sta f:RUN_STATES+3,x
  sep #$20
  jsr .loword(run_prime)
  rep #$20
  lda f:RUN_STATES+5,x
  beq @due
@next16:
  sep #$20
@next:
  ldx RUN_SLOT
  cpx #32
  beq @return
  ldx #32
  jmp .loword(@part)
@return:
  rtl
@end:
  lda #0
  sta f:RUN_STATES+10,x
  bra @next
@repeat:
  lda [RUN_PTR],y
  iny
  sta RUN_TEMP
  rep #$20
  lda RUN_ORIGIN
  cmp f:RUN_STATES+7,x
  beq @left
  sta f:RUN_STATES+7,x
  sep #$20
  lda RUN_TEMP
  sta f:RUN_STATES+9,x
  rep #$20
@left:
  sep #$20
  lda f:RUN_STATES+9,x
  beq @repeat_end
  dec
  sta f:RUN_STATES+9,x
  rep #$20
  lda [RUN_PTR],y
  tay
  sep #$20
  bra @advance
@repeat_end:
  rep #$20
  lda #$ffff
  sta f:RUN_STATES+7,x
  iny
  iny
  sep #$20
  bra @advance

; A=run count, RUN_PTR/Y=ready start/count/bytes. Auto increment supplies
; every following register address. Keep the documented busy check.
run_write:
  sta RUN_GROUPS
@group:
  lda f:$e0c03c
  bmi @group
  lda [RUN_PTR],y
  iny
  sta f:$e0c03e
  lda [RUN_PTR],y
  iny
  sta RUN_BYTES
@byte:
  lda f:$e0c03c
  bmi @byte
  lda [RUN_PTR],y
  iny
  sta f:$e0c03d
  dec RUN_BYTES
  bne @byte
  dec RUN_GROUPS
  bne @group
  rts
