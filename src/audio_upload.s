; Resident-RAM to inactive DOC snapshot bank. Main-loop service, never IRQ
; disk I/O. The build supplies due/deadline, source, destination and count.
; Each call copies at most 64 bytes. The sound IRQ saves/restores GLU state.
.a8
.i16
WAVE_QUEUE_PC = $18460
WAVE_REMAIN = $18464
WAVE_SOURCE = $18466
WAVE_DEST = $18469
WAVE_DEADLINE = $1846b
WAVE_LATE = $1846d
WAVE_PTR = $e8

wave_upload_init:
  rep #$20
  lda #.loword(WAVE_QUEUE)
  sta f:WAVE_QUEUE_PC
  lda #0
  sta f:WAVE_REMAIN
  sta f:WAVE_LATE
  sep #$20
  lda #^WAVE_QUEUE
  sta f:WAVE_QUEUE_PC+2
  rtl

wave_upload_service:
  rep #$20
  lda f:WAVE_REMAIN
  bne @copy
  lda f:WAVE_QUEUE_PC
  sta WAVE_PTR
  sep #$20
  lda f:WAVE_QUEUE_PC+2
  sta WAVE_PTR+2
  ldy #0
  rep #$20
  lda [WAVE_PTR],y
  cmp #$ffff
  bne :+
  sep #$20
  rtl
:
  cmp MUSIC_IRQ_COUNT
  beq @due
  bcc @due
  sep #$20
  rtl
@due:
  ldy #2
  lda [WAVE_PTR],y
  sta f:WAVE_DEADLINE
  ldy #4
  lda [WAVE_PTR],y
  sta f:WAVE_SOURCE
  ldy #7
  lda [WAVE_PTR],y
  sta f:WAVE_DEST
  ldy #9
  lda [WAVE_PTR],y
  sta f:WAVE_REMAIN
  sep #$20
  ldy #6
  lda [WAVE_PTR],y
  sta f:WAVE_SOURCE+2
  rep #$20
  lda f:WAVE_QUEUE_PC
  clc
  adc #11
  sta f:WAVE_QUEUE_PC
  bcc @copy
  sep #$20
  lda f:WAVE_QUEUE_PC+2
  inc
  sta f:WAVE_QUEUE_PC+2
  rep #$20
@copy:
  lda f:WAVE_REMAIN
  cmp #64
  bcc :+
  lda #64
:
  tax
  lda f:WAVE_SOURCE
  sta WAVE_PTR
  sep #$20
  lda f:WAVE_SOURCE+2
  sta WAVE_PTR+2
@ready:
  lda f:$e0c03c
  bmi @ready
  lda DOC_MASTER
  ora #$60
  sta f:$e0c03c
  lda f:WAVE_DEST
  sta f:$e0c03e
  lda f:WAVE_DEST+1
  sta f:$e0c03f
  ldy #0
@byte:
  lda f:$e0c03c
  bmi @byte
  lda [WAVE_PTR],y
  sta f:$e0c03d
  iny
  dex
  bne @byte
@idle:                        ; register mode again: RAM mode marks an upload
  lda f:$e0c03c               ; in progress for music_irq_entry
  bmi @idle
  lda DOC_MASTER
  sta f:$e0c03c
@saved:
  rep #$20
  tya
  clc
  adc f:WAVE_DEST
  sta f:WAVE_DEST
  tya
  clc
  adc f:WAVE_SOURCE
  sta f:WAVE_SOURCE
  bcc :+
  sep #$20
  lda f:WAVE_SOURCE+2
  inc
  sta f:WAVE_SOURCE+2
  rep #$20
:
  tya
  eor #$ffff
  sec
  adc f:WAVE_REMAIN
  sta f:WAVE_REMAIN
  bne @return16
  lda MUSIC_IRQ_COUNT
  cmp f:WAVE_DEADLINE
  bcc @return16
  beq @return16
  lda f:WAVE_LATE
  inc
  sta f:WAVE_LATE
@return16:
  sep #$20
  rtl
