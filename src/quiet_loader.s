; One packed item in a measured quiet camera window. X is packet output.
; A live object retaining the target image postpones the transfer.
.a16
.i16
QUIET_NEXT = $1d80
QUIET_OUT = $1d82
QUIET_SIZE = $1d84
QUIET_CODE = $1d86
QUIET_OWNER = $1d88
.ifndef QUIET_JOB_STRIDE
QUIET_JOB_STRIDE = 12
.endif
quiet_packet_append:
  stx QUIET_OUT
  ldx QUIET_NEXT
  cpx #QUIET_JOB_BYTES
  bcc quiet_candidate
quiet_empty:
  ldx QUIET_OUT
  lda #0
  sta a:$0000,x
  inx
  inx
  rtl
quiet_candidate:
  lda CAMERA+$0f
  cmp f:QUIET_JOBS,x
  bcc quiet_empty
  cmp f:QUIET_JOBS+2,x
  bcs quiet_deadline
.ifdef QUIET_GUARDED
  lda f:QUIET_JOBS+12,x
  sta ART_GUARD
  sep #$20
  lda f:QUIET_JOBS+14,x
  sta ART_GUARD+2
  lda f:QUIET_JOBS+15,x
  sta ART_GUARD_COUNT
  rep #$20
  phx
  jsl art_family_free
  plx
  bcc quiet_empty
.endif
  lda f:QUIET_JOBS+8,x
  sta QUIET_CODE
  bmi quiet_free               ; future foreground tile; camera owns its slot
  ldy #$801c
quiet_owners:
  cpy QUIET_OUT
  bcs quiet_free
  lda a:$0000,y
  and #$00e0
  asl
  asl
  asl
  sta QUIET_OWNER
  lda a:$0001,y
  and #255
  ora QUIET_OWNER
  cmp QUIET_CODE
  beq quiet_empty
quiet_next:
  iny
  iny
  iny
  iny
  bra quiet_owners
quiet_free:
  lda f:QUIET_JOBS+4,x
  sta f:quiet_read+1
  sep #$20
  lda f:QUIET_JOBS+6,x
  sta f:quiet_read+3
  lda f:QUIET_JOBS+7,x
  rep #$20
  and #255
  sta QUIET_SIZE
  ldy QUIET_OUT
  lda f:QUIET_JOBS+10,x         ; build-selected type and bounded block count
  sta a:$0000,y
  iny
  iny
  ldx #0
quiet_copy:
quiet_read:
  lda f:$000000,x
  sta a:$0000,y
  inx
  inx
  iny
  iny
  cpx QUIET_SIZE
  bne quiet_copy
  lda QUIET_NEXT
  clc
  adc #QUIET_JOB_STRIDE
  sta QUIET_NEXT
  tyx
  rtl
quiet_deadline:
  sep #$20
  lda #$e8
  sta f:$050301
quiet_fault:
  bra quiet_fault
