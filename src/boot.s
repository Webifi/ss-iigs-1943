; SYSTEM file entry: bootloader/boot0.s loads this file to $2000 and starts
; it with X = the boot unit. Relocate before loading the native game's low RAM.
.setcpu "65816"
.smart
.macpack longbranch
.a8
.i8
; Startup-only direct-page scratch.
probe_ptr = $2c
probe_bit = $2f
probe_number = $30
probe_digit = $32
.segment "BOOT"
boot:
.setcpu "6502"
  ; Apple IIgs Firmware Reference, IDROUTINE ($FE1F): call with carry
  ; set; only a IIgs clears it. Keep this entire rejection path 6502-safe.
  stx z:PR_UNIT              ; the boot unit, for pr_init
  cld
  sec
  jsr $fe1f
  bcc is_iigs
  lda #0
  sta $c000                  ; main 40-column text, page 1
  sta $c002
  sta $c004
  sta $c006
  sta $c00c
  sta $c00e
  bit $c051
  bit $c052
  bit $c054
  ldx #0
  lda #$a0
@clear:
  sta $0400,x
  sta $0500,x
  sta $0600,x
  sta $0700,x
  inx
  bne @clear
  ldx #3
@title:
  lda boot_title,x
  ora #$80
  sta $0512,x
  dex
  bpl @title
  ldx #0
@message:
  lda not_iigs_message,x
  beq @hold
  ora #$80
  sta $05ae,x
  inx
  bne @message
@hold:
  jmp @hold
boot_title: .byte "1943"
not_iigs_message: .asciiz "1943 REQUIRES AN APPLE IIGS"
.setcpu "65816"
is_iigs:
  clc
  xce
  rep #$30
  ldx #$2100
  ldy #$a000
  lda #loader_end-loader-1
  mvn #0,#0
  jmp $a000
.segment "LOADER"
.include "boot_settings.inc"
.export loaded_bytes,progress_done,mirror_frozen,card_status,memory_banks
.export boot,is_iigs,check_memory,no_memory,no_card
.export memory_bitmap,memory_missing,firmware_limit,boot_unit,boot_driver,locate_smartport
.a16
.i16
loader:
  lda #0
  tcd
  ldx #$01ff
  txs
  sep #$30
  sec
  xce
.a8
.i8
  lda z:PR_UNIT
  jsr pr_init
  jsr boot_screen
  jsr check_memory
  jcs no_memory
  jsr detect_card
  jcs no_card
  lda #<path
  ldy #>path
  jsr pr_open
  jcs failed
  lda #0
  sta read_request
  lda #2
  sta read_request+1
  jsr read_block
  jcs failed
  lda $0800
  cmp #'S'
  jne failed
  lda $0801
  cmp #'S'
  jne failed
  lda $0806
  cmp #1
  jne failed
  lda $0808
  jeq failed
  sta segments
  lda $0809
  sta card_startup
  lda pr_unit
  and #$f0
  sta boot_unit
  lda pr_driver
  sta boot_driver
  lda pr_driver+1
  sta boot_driver+1
.if BOOT_D_WORLD
  ; Reject a driver outside the slot ROMs before replacing the text firmware.
  lda #0
  sta f:INPUT_SAVE_SP_UNIT
  jsr locate_smartport
  lda f:INPUT_SAVE_SP_UNIT
  bne :+
  lda boot_driver+1
  cmp #$c1
  jcc unsupported_driver
  cmp #$c8
  jcs unsupported_driver
:
.endif
  ; Disk use ends when all resident segments have been loaded.
  ldx #0
@headers:
  lda $080a,x
  sta headers,x
  inx
  cpx #60
  bne @headers
  stz current
@segment:
  ldx current
  lda headers,x
  sta dest
  lda headers+1,x
  sta dest+1
  lda headers+2,x
  sta dest+2
  lda headers+3,x
  sta remaining
  lda headers+4,x
  sta remaining+1
  lda headers+5,x
  sta remaining+2
@chunk:
  clc
  xce
  rep #$30
.a16
.i16
  lda #4096
  sta amount
  lda dest
  beq @remaining
  eor #$ffff
  inc
  cmp amount
  bcs @remaining
  sta amount
@remaining:
  sep #$20
.a8
  lda remaining+2
  bne @amount
  rep #$20
.a16
  lda remaining
  cmp amount
  bcs @amount
  sta amount
@amount:
  rep #$20
  lda amount
  sta read_request
  sep #$30
.a8
.i8
  sec
  xce
  jsr read_block
  jcs failed_far
  clc
  xce
  rep #$30
.a16
.i16
  lda amount
  cmp read_actual
  jne failed_native
  dec
  ldx #$0800
  ldy dest
  sep #$20
.a8
  lda dest+2
  sta @copy+1
  php
  sei
  lda f:$e0c035
  pha
  ora #$40                    ; bank-one $C000-$FFFF must be RAM during MVN
  sta f:$e0c035
  rep #$20
.a16
  lda amount
  dec
@copy:
  mvn #0,#0
  sep #$20
.a8
  pla
  sta f:$e0c035               ; the normal I/O/LC mapping again
  plp
  lda #0
  pha
  plb
  rep #$20
.a16
  lda dest
  clc
  adc amount
  sta dest
  sep #$20
.a8
  lda dest+2
  adc #0
  sta dest+2
  rep #$20
.a16
  lda remaining
  sec
  sbc amount
  sta remaining
  sep #$20
.a8
  lda remaining+2
  sbc #0
  sta remaining+2
  rep #$20
.a16
  lda remaining
  ora remaining+1
  bne @more
  sep #$30
.a8
.i8
  sec
  xce
  lda current
  clc
  adc #6
  sta current
  dec segments
  beq @ready
  jmp @segment
@more:
  jmp @chunk
@ready:
  lda card_startup
  beq :+
  ; The startup decoder uses bank-one $8000 scratch. Do not shadow its
  ; writes into resident slow-bank data; leave text mirroring enabled.
  lda f:$e0c035
  ora #$1e
  sta f:$e0c035
  jsr load_card
:
.if BOOT_D_WORLD
  ; Prevent startup scratch writes in the pool page from shadowing onto the
  ; slow-bank world assets. Text mirroring stays enabled for the card.
  lda f:$e0c035
  ora #$1e
  sta f:$e0c035
  jsr stage_d_world
  jcs failed_far
.endif
.if BOOT_C_WORLD
  ; Last DATA read. The config read later touches only $0800-$09FF; these
  ; two staging areas survive until the handoff stub runs.
  stz read_request
  lda #$10
  sta read_request+1
  jsr read_block
  jcs failed_far
  lda read_actual
  jne failed_far
  lda read_actual+1
  cmp #$10
  jne failed_far
  clc
  xce
  rep #$30
  ldx #$0800
  ldy #$8000
  lda #$0bff
  mvn #$00,#$00
  ldx #$1400
  ldy #$0c00
  lda #$03ff
  mvn #$00,#$00
  sep #$30
  lda #0
  pha
  plb
  sec
  xce
.endif
  ; The slow video banks now hold resident game data. The settings handoff
  ; writes bank-zero variables in the hi-res address range: stop their
  ; shadow copies before publishing them. Text mirroring remains enabled.
  lda f:$e0c035
  ora #$1e
  sta f:$e0c035
  jsr load_settings
  jsr locate_smartport
  jsr black_screen
.if BOOT_LC_WORLD
  ; The disk reads are done. The temporary $B000 buffer does not overlap the
  ; loader. Publish the bank-one language-card tail only after the last disk
  ; call.
  php
  sei
  lda f:$e0c035
  pha
  ora #$40
  sta f:$e0c035
  clc
  xce
  rep #$30
  ; Swap rather than discard the prior bank-one contents: $B000 keeps the
  ; firmware image for the save bridge while the game owns $01:F400.
  ldx #$0bfe
@swap_lc:
  lda f:$00b000,x
  pha
  lda f:$01f400,x
  sta f:$00b000,x
  pla
  sta f:$01f400,x
  dex
  dex
  bpl @swap_lc
  sep #$30
  lda #0
  pha
  plb
  sec
  xce
  pla
  sta f:$e0c035
  plp
.endif
  lda #0
  sta f:$e0c006
  sta f:$e0c002
  sta f:$e0c004
  sta f:$050300
  sta f:$050301
  sta f:$050320
  sta f:$050321
  lda f:$e0c02d
  ora #$10
  sta f:$e0c02d
  lda #$43
  sta f:$0503fe
  ; ROM 1.4 can turn video back on after an Apple display-switch event.
  ; All Apple display setup is now complete; blank once more.
  lda #4                     ; ScreenOff leaves the prior status unchanged
  sta $c0b0
.if BOOT_LC_WORLD
  jml GAME_HANDOFF
.else
  jml $006000
.endif
failed_native:
  sep #$30
.a8
.i8
  sec
  xce
failed_far:
  jmp failed
; Read read_request bytes of SS1943.DATA to $0800; read_actual = the bytes
; read.
read_block:
  lda #<$0800
  sta pr_dest
  lda #>$0800
  sta pr_dest+1
  lda read_request
  sta pr_count
  lda read_request+1
  sta pr_count+1
  jsr pr_read
  bcs @done
  lda pr_count
  sta read_actual
  lda pr_count+1
  sta read_actual+1
  pha
  phx
  phy
  jsr load_progress
  ply
  plx
  pla
  clc
@done:
  rts


; The $D000-$FAFF trailer uses no permanent high-memory backing. Its
; pieces occupy startup-only audio, pool, game-state and packet scratch.
.if BOOT_D_WORLD
stage_d_world:
  stz read_request
  lda #$10
  sta read_request+1
  jsr read_block
  jcs @bad
  lda read_actual
  jne @bad
  lda read_actual+1
  cmp #$10
  jne @bad
  php
  sei
  clc
  xce
  rep #$30
  ldx #$0800
  ldy #$8000
  lda #$0fff
  mvn #$00,#$01
  sep #$30
  lda #0
  pha
  plb
  sec
  xce
  plp
  jsr read_block
  jcs @bad
  lda read_actual
  jne @bad
  lda read_actual+1
  cmp #$10
  jne @bad
  php
  sei
  clc
  xce
  rep #$30
  ldx #$0800
  ldy #$5000
  lda #$0fff
  mvn #$00,#$00
  sep #$30
  lda #0
  pha
  plb
  sec
  xce
  plp
  stz read_request
  lda #$0b
  sta read_request+1
  jsr read_block
  jcs @bad
  lda read_actual
  jne @bad
  lda read_actual+1
  cmp #$0b
  jne @bad
  php
  sei
  clc
  xce
  rep #$30
  ldx #$0800
  ldy #.loword(BOOT_D_STAGE)
  lda #$06ff
  mvn #$00,#.bankbyte(BOOT_D_STAGE)
  ldx #$0f00
  ldy #$8c00
  lda #$03ff
  mvn #$00,#$00
  sep #$30
  lda #0
  pha
  plb
  sec
  xce
  plp
  clc
  rts
@bad:
  sec
  rts
.endif

; Read the tiny configuration. Its native checksum validator keeps compiled
; defaults if the file is corrupt. Saves write its one block in place; with
; no such block the save driver stays 0 and saves are refused.
load_settings:
  lda boot_unit
  sta f:INPUT_SAVE_UNIT
  lda #<config_path
  ldy #>config_path
  jsr pr_open
  bcs @done
  lda pr_storage
  cmp #1                     ; a seedling: the key block holds the data
  bne @done
  lda pr_key
  sta f:INPUT_SAVE_BLOCK
  lda pr_key+1
  sta f:INPUT_SAVE_BLOCK+1
  lda boot_driver
  sta f:INPUT_SAVE_DRIVER
  lda boot_driver+1
  sta f:INPUT_SAVE_DRIVER+1
  lda #<$0800
  sta pr_dest
  lda #>$0800
  sta pr_dest+1
  stz pr_count
  lda #>512
  sta pr_count+1
  jsr pr_read
  bcs @done
  clc
  xce
  rep #$30
  ldx #$0800
  ldy #.loword(INPUT_SETTINGS)
  lda #511
  .byte $54,.bankbyte(INPUT_SETTINGS),0
  sep #$30
  lda #0
  pha
  plb
  sec
  xce
@done:
  rts
config_path: .byte 13,"SS1943.CONFIG"
boot_unit: .byte 0
boot_driver: .word 0

; The SmartPort entry of the boot slot (the block driver + 3), for the save
; bridge, when the slot firmware is a SmartPort.
locate_smartport:
  stz smart_unit
  lda boot_driver+1
  cmp #$c1
  jcc @done
  cmp #$c8
  jcs @done
  sec
  sbc #$c0
  asl
  asl
  asl
  asl
  sta smart_slot
  lda boot_unit
  and #$70
  cmp smart_slot
  jne @done
  lda boot_driver
  clc
  adc #3
  jcs @done
  sta smart_entry
  lda boot_driver+1
  sta smart_entry+1
  lda #1
  bit boot_unit
  bpl :+
  inc
:
  sta smart_unit
  lda smart_entry+1
  cmp #$c1
  jcc @done
  cmp #$c8
  jcs @done
  sta probe_ptr+1
  stz probe_ptr
  ldy #1
  lda (probe_ptr),y
  cmp #$20
  jne @done
  ldy #3
  lda (probe_ptr),y
  jne @done
  iny
  iny
  lda (probe_ptr),y
  cmp #3
  jne @done
  iny
  iny
  lda (probe_ptr),y
  jne @done
  ldy #$ff
  lda (probe_ptr),y
  clc
  adc #3
  jcs @done
  cmp smart_entry
  jne @done
  lda smart_unit
  sta f:INPUT_SAVE_SP_UNIT
  lda smart_entry
  sta f:INPUT_SAVE_SP_ENTRY
  lda smart_entry+1
  sta f:INPUT_SAVE_SP_ENTRY+1
@done:
  rts
smart_unit: .byte 0
smart_slot: .byte 0
smart_entry: .word 0

; Startup only: stream card assets from the open DATA file. The game keeps
; no duplicate of these immutable VRAM/SRAM uploads in host RAM.
.a8
.i8
load_card:
  lda #11
  sta $c0b0
  jsr card_on
  lda #4
  sta $c0b1
  jsr card_off
  jsr freeze_mirror
@header:
  lda #10
  sta read_request
  stz read_request+1
  jsr read_block
  jcs failed
  ldx #9
@keep:
  lda $0800,x
  sta card_header,x
  dex
  bpl @keep
  lda card_header+3
  ora card_header+4
  ora card_header+5
  bne :+
  ; Keep the text timing blanked until the native entry selects the cable's
  ; game mode. A firmware graphics mode here can finish after ScreenOff and
  ; expose the newly loaded art during host/DOC initialization (ROM 1.4 E29).
  lda #4                     ; ScreenOff has no response or parameter phase
  sta $c0b0
  rts
:
  lda card_header+6
  and #$80
  beq :+
  lda #1
  sta mirror_final
  jsr freeze_mirror
:
  lda card_header+6
  and #$40
  beq :+
  lda #1
  sta card_final_video
  jsr freeze_mirror
  lda #4                     ; text VRAM is about to become game data
  sta $c0b0                  ; blank only this final, short handoff
:
  lda card_header+7
  sta upload_registers+5
@chunk:
  ; Disk firmware may restore Apple video switches. Read the next block
  ; first, then establish the card's byte-write path before its DMA phase.
  clc
  xce
  rep #$30
.a16
.i16
  lda card_header+3
  cmp #4096
  bcc :+
  lda #4096
:
  sta amount
  sta read_request
  sep #$30
.a8
.i8
  sec
  xce
  lda card_header+6
  and #$20
  beq @read_upload
  ; The stored length travels in the record header, avoiding a separate
  ; read for each compressed block.
  lda card_header+8
  sta read_request
  lda card_header+9
  sta read_request+1
  ora read_request
  jeq failed
  lda read_request+1
  cmp #$10
  jcs failed
@read_upload:
  jsr read_block
  jcs failed
  lda card_header+6
  and #$20
  beq @upload_ready
  ; Reassert the shadow state after the firmware read before writing the
  ; bank-one staging page. Text shadowing remains enabled.
  lda f:$e0c035
  ora #$1e
  sta f:$e0c035
  ; The regular amount variable is direct page $28, which the decoder
  ; uses as distance scratch, so retain the output length in loader RAM.
  php
  sei
  clc
  xce
  rep #$30
  lda read_actual
  cmp read_request
  jne failed_native
  lda amount
  sta unpacked_length
  sta $26
  lda #$0800
  sta $20
  sep #$20
  stz $22
  jsr startup_unpack
  rep #$20
  lda unpacked_length
  sta amount
  sta read_actual
  sep #$30
  sec
  xce
  plp
@upload_ready:
  stz mirror_frozen
  jsr freeze_mirror
  lda card_final_video
  beq :+
  lda #4
  sta $c0b0
:
  lda #2
  sta $c0b0
  jsr card_on
  lda #1
  sta $c0b1
  ldx #0
@address:
  lda card_header,x
  sta $c0b1
  inx
  cpx #3
  bne @address
  lda amount
  sta $c0b1
  lda amount+1
  sta $c0b1
  lda #0
  sta $c0b1
  sta $c0b1
  sta $c0b1
  sta $c0b1
  jsr card_off
  jsr card_on
  clc
  xce
  rep #$30
.a16
.i16
  lda amount
  cmp read_actual
  jne failed_native
  and #$fffc
  sta $2e
  ldx #0
  sep #$20
.a8
  lda card_header+6
  and #$20
  bne @send_unpacked
  cpx $2e
  beq @send_tail
@send:
.repeat 4
  lda f:$000800,x
  sta f:$e0c0b1
  inx
.endrepeat
  cpx $2e
  bcc @send
@send_tail:
  cpx amount
  beq @sent
@send_tail_loop:
  lda f:$000800,x
  sta f:$e0c0b1
  inx
  cpx amount
  bcc @send_tail_loop
  bra @sent
@send_unpacked:
  cpx $2e
  beq @unpacked_tail
@unpacked_loop:
.repeat 4
  lda f:$018000,x
  sta f:$e0c0b1
  inx
.endrepeat
  cpx $2e
  bcc @unpacked_loop
@unpacked_tail:
  cpx amount
  beq @sent
@unpacked_tail_loop:
  lda f:$018000,x
  sta f:$e0c0b1
  inx
  cpx amount
  bcc @unpacked_tail_loop
@sent:
  rep #$20
.a16
  lda card_header
  clc
  adc amount
  sta card_header
  sep #$20
.a8
  lda card_header+2
  adc #0
  sta card_header+2
  rep #$20
.a16
  lda card_header+3
  sec
  sbc amount
  sta card_header+3
  sep #$30
.a8
.i8
  sec
  xce
  jsr card_off
  lda card_header+3
  ora card_header+4
  jne @chunk
  jsr mirror_progress
  jmp @header
card_on:
  lda $c0b8
  cmp #1
  bne card_on
  rts
card_off:
  lda $c0b8
  bne card_off
  rts

.include "boot_unpack.s"
.a8
.i8
unpacked_length: .word 0

; GetStatus is the library's card-presence test: one dummy read and twelve
; result bytes. Never open the game file until the five-byte signature agrees.
detect_card:
  stz $c0b0
  ldy #0
  ldx #0
@wait:
  lda $c0b8
  cmp #1
  beq @reply
  dex
  bne @wait
  dey
  bne @wait
  sec
  rts
@reply:
  lda $c0b2
  ldx #0
@read:
  lda $c0b2
  sta card_status,x
  inx
  cpx #12
  bne @read
  ldx #4
@signature:
  lda card_status,x
  cmp card_signature,x
  bne @absent
  dex
  bpl @signature
  lda card_status+5
  cmp #6
  bne @absent
  clc
  rts
@absent:
  sec
  rts

; Doom/Wolf's MiniMemoryTester-order probe, adapted only for ca65 and the
; required bank range ($02-$0F). Write all banks top-down, then read in the
; same order. The previous access to that offset is in another bank: no
; Zip/TransWarp cache hit on the probe's own write. Never probe $80-$FE.
; A bank found by either offset counts; one bad byte does not reject RAM.
check_memory:
  php
  sei
  clc
  xce
  rep #$10
.a8
.i16
  stz probe_ptr
  stz probe_ptr+1
  lda #$7f
@write_byte:
  sta probe_ptr+2
  eor #$ff
  sta [probe_ptr]
  eor #$ff
  dec
  cmp #2
  bcs @write_byte
  ldx #15
@clear_bitmap:
  stz memory_bitmap,x
  dex
  bpl @clear_bitmap
  lda #3                      ; $00/$01 are motherboard RAM
  sta memory_bitmap
  lda #$7f
@read_byte:
  sta probe_ptr+2
  eor #$ff
  cmp [probe_ptr]
  bne @next_byte
  lda probe_ptr+2
  jsr memory_bank_bit
  lda memory_bitmap,x
  ora probe_bit
  sta memory_bitmap,x
@next_byte:
  lda probe_ptr+2
  dec
  cmp #2
  bcs @read_byte
  ldx #$5a5a
  stx probe_ptr
  lda #$7f
@write_word:
  sta probe_ptr+2
  jsr memory_probe_word
.a16
  sta [probe_ptr]
  sep #$20
.a8
  lda probe_ptr+2
  dec
  cmp #2
  bcs @write_word
  lda #$7f
@read_word:
  sta probe_ptr+2
  jsr memory_probe_word
.a16
  cmp [probe_ptr]
  sep #$20
.a8
  bne @next_word
  lda probe_ptr+2
  jsr memory_bank_bit
  lda memory_bitmap,x
  ora probe_bit
  sta memory_bitmap,x
@next_word:
  lda probe_ptr+2
  dec
  cmp #2
  bcs @read_word
  lda #2
@required:
  jsr memory_bank_found
  bcc @missing
  inc
  cmp #$10
  bcc @required
  sep #$30
.a8
.i8
  sec
  xce
  plp
  clc
  rts
@missing:
.a8
.i16
  sta memory_missing
  sep #$30
.a8
.i8
  sec
  xce
  plp
  sec
  rts

.a8
.i16
memory_probe_word:
  rep #$20
.a16
  and #$00ff
  eor #$a55a                   ; unequal bytes reject an empty bus
  rts

.a8
.i16
memory_bank_found:
  jsr memory_bank_bit
  pha
  lda memory_bitmap,x
  and probe_bit
  cmp #1
  pla
  rts

.a8
.i16
memory_bank_bit:
  pha
  rep #$20
.a16
  and #7
  tax
  sep #$20
.a8
  lda memory_bits,x
  sta probe_bit
  lda 1,s
  rep #$20
.a16
  and #$00ff
  lsr
  lsr
  lsr
  tax
  sep #$20
.a8
  pla
  rts

; Firmware's own count, as in Doom fwBanks. This is diagnostic only: the
; top bank is not proof that every lower required bank exists.
; Return the exclusive fast-RAM bank limit, or zero if unknown.
firmware_banks:
  lda f:$fffb59
  beq @rom00
  cmp #1
  beq @rom01_03
  cmp #3
  bne @unknown
@rom01_03:
  lda f:$e11624
  bra @check
@rom00:
  lda f:$e1161a
@check:
  cmp #2
  bcc @unknown
  cmp #$81
  bcc @done
@unknown:
  lda #0
@done:
  rts

; Called only for a failed bank check, after the main error line.
.a8
.i8
memory_details:
  clc
  xce
  rep #$10
.i16
  ldy #2                      ; add slow $E0/$E1 to the bitmap's fast RAM
  ldx #15
@byte:
  lda memory_bitmap,x
@bit:
  asl
  bcc :+
  iny
:
  cmp #0
  bne @bit
  dex
  bpl @byte
  rep #$20
.a16
  tya
  sta memory_banks
  ldx #found_value
  jsr memory_kilobytes
.a8
  jsr firmware_banks
  sta firmware_limit
  beq @no_firmware
  rep #$20
.a16
  and #$00ff
  inc
  inc
  ldx #firmware_value
  jsr memory_kilobytes
.a8
@no_firmware:
  lda memory_missing
  lsr
  lsr
  lsr
  lsr
  jsr memory_hex
  sta missing_value
  lda memory_missing
  and #15
  jsr memory_hex
  sta missing_value+1
  sep #$30
.a8
.i8
  sec
  xce
  ldx #0
@found:
  lda found_text,x
  beq @firmware_start
  ora #$80
  sta f:$e006ac,x             ; row 13, column 4
  inx
  bne @found
@firmware_start:
  ldx #0
@firmware:
  lda firmware_text,x
  beq @missing_start
  ora #$80
  sta f:$e0072c,x             ; row 14, column 4
  inx
  bne @firmware
@missing_start:
  ldx #0
@missing:
  lda missing_text,x
  beq @done
  ora #$80
  sta f:$e007ac,x             ; row 15, column 4
  inx
  bne @missing
@done:
  rts

.a8
.i16
memory_hex:
  cmp #10
  bcc :+
  adc #6
:
  adc #'0'
  rts

; Doom putKB: A16 banks -> decimal KB at X, return A8. Omit only the
; thousands zero; every valid count here is at least 256 KB.
.a16
.i16
memory_kilobytes:
  asl
  asl
  asl
  asl
  asl
  asl
  sta probe_number
  ldy #0
@place:
  lda #'0'
  sta probe_digit
  lda probe_number
@subtract:
  cmp memory_tens,y
  bcc @digit
  sbc memory_tens,y
  inc probe_digit
  bra @subtract
@digit:
  sta probe_number
  sep #$20
.a8
  lda probe_digit
  cpy #0
  bne @store
  cmp #'0'
  beq @next
@store:
  sta a:$0000,x
  inx
@next:
  rep #$20
.a16
  iny
  iny
  cpy #8
  bcc @place
  sep #$20
.a8
  lda #'K'
  sta a:$0000,x
  stz a:$0001,x
  rts

memory_bits: .byte 1,2,4,8,16,32,64,128
memory_tens: .word 1000,100,10,1
memory_bitmap: .res 16
memory_missing: .byte 0
memory_banks: .word 0
firmware_limit: .byte 0
found_text: .byte "RAM FOUND: "
found_value: .res 6
firmware_text: .byte "FIRMWARE: "
firmware_value: .asciiz "UNKNOWN"
missing_text: .byte "FAST BANK $"
missing_value: .byte "00 IS NOT RAM",0
.a8
.i8

boot_screen:
  lda #0
  sta f:$e0c000               ; 80STORE off, main 40-column text page
  sta f:$e0c00c
  sta f:$e0c00f               ; alternate characters enable MouseText
  sta f:$e0c051
  sta f:$e0c052
  sta f:$e0c054
  lda f:$e0c029
  and #$7f
  sta f:$e0c029
  lda #$60                   ; medium blue text, black background
  sta f:$e0c022
  lda f:$e0c034
  and #$f0
  sta f:$e0c034
  jsr clear_text
  ldx #3
@title:
  lda title,x
  ora #$80
  sta f:$e00512,x            ; row 2, centered
  dex
  bpl @title
  ldx #6
@label:
  lda loading_text,x
  ora #$80
  sta f:$e006e0,x            ; row 21, centered
  dex
  bpl @label
  jsr draw_progress
  rts

clear_text:
  ldx #0
  lda #$a0
@clear:
  sta f:$e00400,x
  sta f:$e00500,x
  sta f:$e00600,x
  sta f:$e00700,x
  inx
  bne @clear
  rts

black_screen:
  ; Spaces on black keep the Apple display blank through play and menus.
  ; Changing C022 after takeover would inject an event into card DMA1.
  jsr clear_text
  rts

; Thresholds are prepared from the exact DATA file size. Disk reads and card
; uploads advance the same bar; there is no timer pretending to be progress.
load_progress:
  clc
  xce
  rep #$30
.a16
.i16
  lda loaded_bytes
  clc
  adc read_actual
  sta loaded_bytes
  lda loaded_bytes+2
  adc #0
  sta loaded_bytes+2
@threshold:
  lda progress_done
  cmp #36
  bcs @draw
  asl
  asl
  tax
  lda loaded_bytes+2
  cmp progress_thresholds+2,x
  bcc @draw
  bne @advance
  lda loaded_bytes
  cmp progress_thresholds,x
  bcc @draw
@advance:
  inc progress_done
  bra @threshold
@draw:
  sep #$30
.a8
.i8
  sec
  xce
  jsr draw_progress
  rts

draw_progress:
  lda #$5a                   ; MouseText line at the cell's right edge
  sta f:$e00751              ; closes the bar's left end
  lda #$5f                   ; line at the cell's left edge
  sta f:$e00776              ; closes the bar's right end
  ldx #0
@cell:
  cpx progress_done
  lda #$5c                   ; outlined empty cell
  bcs :+
  lda #$4e                   ; solid filled cell
:
  sta f:$e00752,x
  inx
  cpx #36
  bne @cell
  rts

; Keep the firmware's completed text image and font visible during uploads.
; Re-entering FC/0 clears both text planes before rendering; it must not be
; used as a progress refresh. Update only the 36 bar characters in plane 0.
; ROM 1.4 text40 uses two plane addresses per cell: row 22, column 2 = $06E4.
; Its alternate font maps MouseText $4E/$5C to VGA glyphs $CE/$DC.
mirror_progress:
  lda mirror_final
  bne @done
  lda progress_done
  cmp mirrored_progress
  beq @done
  sta mirrored_progress
  lda #1                     ; character plane only; attributes/font stay intact
  sta upload_registers+5
  stz mirror_frozen
  jsr freeze_mirror
  lda #2
  sta $c0b0
  jsr card_on
  ldx #0
@parameter:
  lda bar_upload,x
  sta $c0b1
  inx
  cpx #10
  bne @parameter
  jsr card_off
  jsr card_on
  ldx #0
@cell:
  cpx progress_done
  lda #$dc                   ; outlined empty cell
  bcs :+
  lda #$ce                   ; solid filled cell
:
  sta $c0b1
  lda #$10                   ; unused odd address, as in the firmware clear
  sta $c0b1
  inx
  cpx #36
  bne @cell
  jsr card_off
@done:
  rts

; Leave the completed text image visible while replacing the firmware's
; renderer SRAM. Its font/framebuffer are the final uploads, under ScreenOff.
freeze_mirror:
  lda mirror_frozen
  bne @done
  lda #1
  sta mirror_frozen
  lda mirror_disabled
  bne @register_setup
  lda #1
  sta mirror_disabled
  jsr text_emulation
@register_setup:
  ; UploadData selects the linear aperture but retains VGA write addressing.
  ; One selected VGA plane receives the build-prepared byte stream. Text
  ; scanout remains live. Restore only upload addressing between disk reads;
  ; resetting the complete display mode for each block is unnecessary.
  ldx #0
@register:
  lda #12
  sta $c0b0
  jsr card_on
  ldy #6
@byte:
  lda upload_registers,x
  sta $c0b1
  inx
  dey
  bne @byte
  jsr card_off
  cpx #18
  bne @register
@done:
  rts

text_emulation:
  pha
  lda #1
  sta $c0b0
  jsr card_on
  lda boot_mode             ; same 40-column timing on either monitor
  sta $c0b1
  pla
  sta $c0b1
  jsr card_off
@mode:
  lda $c0b8
  cmp #$a5
  bne @mode
  rts

unsupported_driver:
  ; DATA's first read may already have frozen the mirrored loading screen.
  ; Re-enable text emulation so the error is visible on the card display.
  lda #0
  jsr text_emulation
  ldx #<unsupported_driver_message
  ldy #>unsupported_driver_message
  jmp requirement_error
no_memory:
  ldx #<no_memory_message
  ldy #>no_memory_message
  bra requirement_error
no_card:
  ldx #<no_card_message
  ldy #>no_card_message
requirement_error:
  stx error_text+1
  sty error_text+2
  jsr clear_text
  ldx #3
@title:
  lda title,x
  ora #$80
  sta f:$e00512,x
  dex
  bpl @title
  ldx #0
error_text:
  lda $ffff,x
  beq @details
  ora #$80
  sta f:$e005b0,x
  inx
  bne error_text
@details:
  lda memory_missing
  beq @hold
  jsr memory_details
@hold:
  bra @hold
failed:
  lda #$8d
  jsr $fded
  ldx #0
@text:
  lda message,x
  beq @hold
  ora #$80
  jsr $fded
  inx
  bne @text
@hold:
  bra @hold
message: .asciiz "1943 LOAD ERROR"
no_card_message: .asciiz "SECOND SIGHT NOT DETECTED"
no_memory_message: .asciiz "1943 REQUIRES 1 MB OF MEMORY"
unsupported_driver_message: .asciiz "UNSUPPORTED BOOT DEVICE DRIVER"
title: .byte "1943"
loading_text: .byte "LOADING"
card_signature: .byte "GSVGA"
card_status: .res 12
boot_mode: .byte $fc
card_final_video: .byte 0
mirror_frozen: .byte 0
mirror_disabled: .byte 0
mirror_final: .byte 0
mirrored_progress: .byte 0
bar_upload:
  .byte 1                    ; UploadData, absolute linear destination
  .byte $e4,$06,0             ; text row 22, column 2, plane 0
  .byte 72,0,0               ; 36 character bytes and their unused odd addresses
  .byte 0,0,0                ; unused IIgs source pointer
upload_registers:
  .byte $c4,3,2,$c5,3,15    ; sequencer map mask: all planes
  .byte $c4,3,4,$c5,3,6     ; unchained, odd/even CPU writes disabled
  .byte $ce,3,5,$cf,3,0     ; write mode 0, no odd/even read addressing
loaded_bytes: .dword 0
progress_done: .word 0
.include "boot_progress.inc"
path: .byte 11,"SS1943.DATA"
read_request: .word 512
read_actual: .word 0
segments: .byte 0
current: .byte 0
headers: .res 60
card_startup: .byte 0
card_header: .res 10
; The file reader: two block buffers in the free $9000-$93FF.
PR_ZP = $48
PR_DBUF = $9000
PR_IBUF = $9200
.a8
.i8
.include "prodos_read.s"
; Direct-page operands are explicit addresses.
dest = $20
remaining = $24
amount = $28
loader_end:
