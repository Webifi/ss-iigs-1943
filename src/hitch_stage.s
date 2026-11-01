; The deck staging: in quiet time a packet also carries one job of the
; carrier deck image ($D500, D500_STAGE_LIST) to the card, after the world
; batch, when the packet has room. On the deck the helper job goes instead.
; A16, X16, DBR = 0.
D500_DONE = $8000            ; the image is staged; stage nothing
D500_REPORT = $4000          ; with D500_DONE: it was staged during a report
D500_ENTRY_SIZE = 6          ; D500_STAGE_LIST: the length, the source (4 bytes)
PAGE_STAGING_END = 8         ; the staging runs on the cabinet pages below this

; d500_stage_world, d500_stage_layout, d500_stage_empty: the job before a
; world batch, a cabinet layout or nothing (D500_FOLLOW = the bytes after).
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

; d500_stage_append: append the next job at WORLD_OUTPUT when the packet
; keeps PACKET_AREA. JSL; D500_SOURCE kept.
d500_stage_append:
.a16
  lda D500_SOURCE
  pha
  lda D500_SOURCE+2
  pha
d500_gate_site:
  ; special_install_tick patches this LDA to JSR d500_gate_stub.
  lda CAMERA_BG1_SCROLL
  cmp #DECK_SCROLL
  bne :+
  jmp .loword(@helper)
:
  lda D500_INDEX
  bpl @eligible16               ; D500_DONE clear
  ; An image that was used is not staged again in the launch. After its use
  ; in a report, wait for that report to end, then for the next report.
  bit #D500_REPORT
  beq @await_report
  a8
  lda CAB_RESULT_ACTIVE
  beq :+
  jmp .loword(@return8)
:
  a16
  lda #D500_DONE
  sta D500_INDEX
  jmp .loword(@return16)
@await_report:
  a8
  lda CAB_RESULT_ACTIVE
  bne :+
  jmp .loword(@return8)
:
  a16
  stz D500_INDEX
@eligible16:
  a8
@eligible:
  ; Quiet time: a report, the ranking, warning, title and credit pages, or
  ; the first deck rows.
  lda CAB_RESULT_ACTIVE
  bne @stage
  lda GAME_FLOW
  cmp #CAB_PAGE_FIRST
  bcc :+
  cmp #PAGE_STAGING_END
  bcc @stage
  jmp .loword(@return8)
:
  lda CAMERA_BG1_SCROLL+1
  cmp #DECK_ROWS_FIRST
  beq @stage
  cmp #DECK_ROWS_FIRST+1
  beq @stage
  jmp .loword(@return8)
@stage:
  stz SPECIAL_WAVE_READY
  stz SPECIAL_LOADED            ; the deck jobs use the wave fragments
  a16
  ldx D500_INDEX
  lda f:D500_STAGE_LIST,x
  bne :+
  jmp .loword(@return16)
:
  sta D500_COPY_LENGTH
  lda f:D500_STAGE_LIST+2,x
  sta D500_SOURCE
  lda f:D500_STAGE_LIST+4,x
  sta D500_SOURCE+2
  bra @check
@helper:
  ; On the deck: the helper of this picture's buffer, after all image jobs.
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
  sta D500_SOURCE
  lda #.hiword(D500_HELPER0_ADDRESS)
  sta D500_SOURCE+2
  bra @check
@helper1:
  lda #D500_HELPER1_LENGTH
  sta D500_COPY_LENGTH
  lda #.loword(D500_HELPER1_ADDRESS)
  sta D500_SOURCE
  lda #.hiword(D500_HELPER1_ADDRESS)
  sta D500_SOURCE+2
@check:
  lda WORLD_OUTPUT
  sec
  sbc #.loword(PACKET_BUFFER)
  clc
  adc D500_COPY_LENGTH
  adc D500_FOLLOW
  adc #2                        ; the end word
  cmp #PACKET_AREA+1
  bcs @return16                 ; no room: the packet stays as it is
  ldx WORLD_OUTPUT
  ldy #0
@copy:
  lda [D500_SOURCE],y
  xba
  sta a:0,x
  inx
  inx
  iny
  iny
  cpy D500_COPY_LENGTH
  bcc @copy
  stx WORLD_OUTPUT
  lda CAMERA_BG1_SCROLL
  cmp #DECK_SCROLL
  beq @sent_helper
  lda D500_INDEX
  clc
  adc #D500_ENTRY_SIZE
  sta D500_INDEX
  bra @return16
@sent_helper:
  a8
  lda CAB_RESULT_ACTIVE
  beq :+
  a16
  lda #D500_DONE|D500_REPORT
  bra :++
:
  a16
  lda #D500_DONE
:
  sta D500_INDEX
@return8:
  a16
@return16:
  pla
  sta D500_SOURCE+2
  pla
  sta D500_SOURCE
  rtl

d500_stage_return = @return16
; d500_gate_stub: during a special the special stage can take the packet
; (special_stage_gate, carry 1): then the staging ends; else the LDA that the
; patch replaced. JSR from d500_gate_site.
d500_gate_stub:
  jsl special_stage_gate
  bcc @ordinary_gate
  pla                           ; the JSR return goes
  jmp .loword(d500_stage_return)
@ordinary_gate:
  lda CAMERA_BG1_SCROLL         ; the replaced instruction
  rts
