; SYSTEM file entry: bootloader/boot0.s loads this file to SYSTEM_LOAD and
; starts it with X = the boot unit. Relocate before loading the native game's
; low RAM.
.setcpu "65816"
.include "w65c816.inc"
.include "iigs.inc"
.include "second_sight.inc"
.include "host_memory.inc"
.include "data_file.inc"
.include "settings.inc"
.smart
.macpack longbranch
.a8
.i8
; src/boot.cfg places the loader: it must agree with host_memory.inc.
.import __SYSTEM_START__, __SYSTEM_SIZE__, __LOADER_START__, __LOADER_SIZE__
.import __LOADERZP_START__, __LOADERZP_SIZE__
.assert __SYSTEM_START__ = SYSTEM_LOAD && __SYSTEM_SIZE__ = SYSTEM_BOOT_SIZE, error, "boot.cfg SYSTEM"
.assert __LOADER_START__ = BOOT_LOADER && __LOADER_SIZE__ = BOOT_LOADER_SIZE, error, "boot.cfg LOADER"
.assert __LOADERZP_START__ = LOADER_ZERO_PAGE && __LOADERZP_SIZE__ = LOADER_ZERO_PAGE_SIZE, error, "boot.cfg LOADERZP"
.segment "BOOT"
boot:
.setcpu "6502"
  ; Apple IIgs Firmware Reference, IDROUTINE: call with carry set; only a
  ; IIgs clears it. Keep this entire rejection path 6502-safe.
  stx z:PR_UNIT              ; the boot unit, for pr_init
  cld
  sec
  jsr IDROUTINE
  bcc is_iigs
  lda #0
  sta .loword(KBD)                  ; main 40-column text, page 1
  sta .loword(RDMAINRAM)
  sta .loword(WRMAINRAM)
  sta .loword(SETSLOTCXROM)
  sta .loword(CLR80VID)
  sta .loword(CLRALTCHAR)
  bit .loword(TXTSET)
  bit .loword(MIXCLR)
  bit .loword(TXTPAGE1)
  ldx #0
  lda #TEXT_SPACE
@clear:
  sta .loword(TEXT_PAGE1),x
  sta .loword(TEXT_PAGE1)+$100,x
  sta .loword(TEXT_PAGE1)+$200,x
  sta .loword(TEXT_PAGE1)+$300,x
  inx
  bne @clear
  ldx #3                        ; the 4 characters, centred
@title:
  lda boot_title,x
  ora #TEXT_NORMAL
  sta .loword(TEXT_ROW_2)+18,x
  dex
  bpl @title
  ldx #0
@message:
  lda not_iigs_message,x
  beq @hold
  ora #TEXT_NORMAL
  sta .loword(TEXT_ROW_11)+6,x
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
  ax16
  ldx #.loword(SYSTEM_LOAD+SYSTEM_BOOT_SIZE)
  ldy #loader
  lda #loader_end-loader-1
  mvn #^SYSTEM_LOAD,#^loader
  jmp loader
.segment "LOADER"
.include "boot_settings.inc"
PROBE_TOP_BANK = $7f         ; the top bank of the memory probe
PROBE_OFFSET = $5a5a         ; the word probe: its address in each bank
PROBE_WORD = $a55a           ; and its value: two unequal bytes, so an empty bus fails
MEMORY_BITMAP_SIZE = 16      ; memory_bitmap: a bit for each bank $00-$7F
UNIT_DEVICE = $f0            ; a ProDOS unit number: bit 7 the drive, bits 4-6 the slot
UNIT_SLOT = $70
; A slot ROM page $Cn: a ProDOS block device has $20 at $Cn01, $00 at $Cn03
; and $03 at $Cn05; a SmartPort also $00 at $Cn07. $CnFF: the offset of the
; block entry; the SmartPort entry is SMARTPORT_ENTRY after it.
ID_BYTE1 = $20
ID_BYTE5 = $03
SMARTPORT_ENTRY = 3
BLOCK_ENTRY = $ff
ROMVER_01 = 1                ; ROMVER: ROM 01 and ROM 03 keep the bank count at
ROMVER_03 = 3                ; FW_BANKS_ROM03, ROM 00 at FW_BANKS_ROM00
FW_BANKS_MIN = 2             ; a firmware bank count from this
FW_BANKS_END = $81           ; up to under this is believed
NEWVIDEO_SHR = $80           ; NEWVIDEO: super hi-res on
CLOCKCTL_BORDER = $0f        ; CLOCKCTL: the border colour
; The progress bar cells: MouseText on the text page, and the codes of the
; same cells for the card firmware text (draw_progress, card_progress).
MT_RIGHT_LINE = $5a          ; a line at the right edge of a cell
MT_LEFT_LINE = $5f           ; a line at the left edge of a cell
MT_CELL_EMPTY = $5c          ; an outlined empty cell
MT_CELL_FULL = $4e           ; a filled cell
CARD_CELL_EMPTY = $dc
CARD_CELL_FULL = $ce
; The progress bar: PROGRESS_CELLS (data_file.inc) cells on a text row of the
; loading screen.
PROGRESS_ROW = 22
PROGRESS_COLUMN = 2
PROGRESS_TEXT = .ident(.sprintf("TEXT_ROW_%d", PROGRESS_ROW))+PROGRESS_COLUMN
; Loader page-zero variables. The block driver may change any of page zero
; (bootloader/prodos_read.s), so nothing here lives across a disk read.
.pushseg
.segment "LOADERZP": zeropage
probe_ptr: .res 3            ; check_memory: the probe address
pr_zp: .res 4                ; the file reader's pointers
unpack_end: .res 2           ; startup_unpack: the end address of the output
unpack_length: .res 2        ; startup_unpack: a match: the byte count - 1
unpack_distance: .res 2      ; startup_unpack: a match: the distance back
.popseg
.a16
.i16
loader:
  lda #0
  tcd
  ldx #.loword(EMULATION_STACK_TOP)
  txs
  ax8
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
  lda #<DATA_HEADER_SIZE
  sta read_request
  lda #>DATA_HEADER_SIZE
  sta read_request+1
  jsr read_block
  jcs failed
  lda DATA_BUFFER+DATA_MAGIC
  cmp #'S'
  jne failed
  lda DATA_BUFFER+DATA_MAGIC+1
  cmp #'S'
  jne failed
  lda DATA_BUFFER+DATA_VERSION
  cmp #DATA_FORMAT
  jne failed
  lda DATA_BUFFER+DATA_SEGMENTS
  jeq failed
  sta segments
  lda DATA_BUFFER+DATA_STARTUP
  sta card_startup
  lda pr_unit
  and #UNIT_DEVICE
  sta boot_unit
  lda pr_driver
  sta boot_driver
  lda pr_driver+1
  sta boot_driver+1
  ; Reject a driver outside the slot ROMs before replacing the text firmware.
  lda #0
  sta f:INPUT_SAVE_SP_UNIT
  jsr locate_smartport
  lda f:INPUT_SAVE_SP_UNIT
  bne :+
  lda boot_driver+1
  cmp #>SLOT1_ROM
  jcc unsupported_driver
  cmp #>SLOT_ROMS_END
  jcs unsupported_driver
:
  ; Disk use ends when all resident segments have been loaded.
  ldx #0
@headers:
  lda DATA_BUFFER+DATA_TABLE,x
  sta headers,x
  inx
  cpx #MAX_SEGMENTS*SEGMENT_ENTRY
  bne @headers
  ldx #0
@thresholds:
  lda DATA_BUFFER+DATA_PROGRESS,x
  sta progress_thresholds,x
  inx
  cpx #PROGRESS_CELLS*4
  bne @thresholds
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
  ax16
.a16
.i16
  lda #DATA_BUFFER_SIZE
  sta amount
  lda dest
  beq @remaining
  eor #$ffff
  inc
  cmp amount
  bcs @remaining
  sta amount
@remaining:
  a8
.a8
  lda remaining+2
  bne @amount
  a16
.a16
  lda remaining
  cmp amount
  bcs @amount
  sta amount
@amount:
  a16
  lda amount
  sta read_request
  ax8
.a8
.i8
  sec
  xce
  jsr read_block
  jcs failed_far
  clc
  xce
  ax16
.a16
.i16
  lda amount
  cmp read_actual
  jne failed_native
  dec
  ldx #.loword(DATA_BUFFER)
  ldy dest
  a8
.a8
  lda dest+2
  sta @copy+1
  php
  sei
  lda f:SHADOW
  pha
  ora #SHADOW_IOLC            ; bank-one $C000-$FFFF must be RAM during MVN
  sta f:SHADOW
  a16
.a16
  lda amount
  dec
@copy:
  mvn #^DATA_BUFFER,#0        ; the destination bank: dest+2
  a8
.a8
  pla
  sta f:SHADOW               ; the normal I/O/LC mapping again
  plp
  lda #0
  pha
  plb
  a16
.a16
  lda dest
  clc
  adc amount
  sta dest
  a8
.a8
  lda dest+2
  adc #0
  sta dest+2
  a16
.a16
  lda remaining
  sec
  sbc amount
  sta remaining
  a8
.a8
  lda remaining+2
  sbc #0
  sta remaining+2
  a16
.a16
  lda remaining
  ora remaining+1
  bne @more
  ax8
.a8
.i8
  sec
  xce
  lda current
  clc
  adc #SEGMENT_ENTRY
  sta current
  dec segments
  beq @ready
  jmp @segment
@more:
  jmp @chunk
@ready:
  lda card_startup
  beq :+
  ; The startup decoder writes STARTUP_UNPACK_OUTPUT. Do not shadow its
  ; writes into resident slow-bank data; leave text mirroring enabled.
  lda f:SHADOW
  ora #SHADOW_GRAPHICS
  sta f:SHADOW
  jsr load_card
:
  ; Prevent startup scratch writes in the pool page from shadowing onto the
  ; slow-bank world assets. Text mirroring stays enabled for the card.
  lda f:SHADOW
  ora #SHADOW_GRAPHICS
  sta f:SHADOW
  jsr stage_d_world
  jcs failed_far
  ; Last DATA read. The config read later uses only the first 512 bytes of
  ; DATA_BUFFER; these two staging areas survive until the handoff stub runs.
  .assert <C_WORLD_SIZE = 0 && C_WORLD_SIZE <= DATA_BUFFER_SIZE, error
  lda #>C_WORLD_SIZE
  jsr read_pages
  jcs failed_far
  clc
  xce
  ax16
  ldx #.loword(DATA_BUFFER)
  ldy #.loword(C_WORLD_STAGE0)
  lda #C_WORLD_PART0_SIZE-1
  mvn #^DATA_BUFFER,#^C_WORLD_STAGE0
  ldx #.loword(DATA_BUFFER+C_WORLD_PART0_SIZE)
  ldy #.loword(C_WORLD_STAGE1)
  lda #C_WORLD_PART1_SIZE-1
  mvn #^DATA_BUFFER,#^C_WORLD_STAGE1
  ax8
  lda #0
  pha
  plb
  sec
  xce
  ; The slow video banks now hold resident game data. The settings handoff
  ; writes bank-zero variables in the hi-res address range: stop their
  ; shadow copies before publishing them. Text mirroring remains enabled.
  lda f:SHADOW
  ora #SHADOW_GRAPHICS
  sta f:SHADOW
  jsr load_settings
  jsr locate_smartport
  jsr black_screen
  ; The disk reads are done. LC_WORLD_STAGE does not overlap the loader.
  ; Publish the bank-one language-card tail only after the last disk call.
  php
  sei
  lda f:SHADOW
  pha
  ora #SHADOW_IOLC
  sta f:SHADOW
  clc
  xce
  ax16
  ; Swap rather than discard the prior bank-one contents: LC_WORLD_STAGE
  ; keeps the firmware image (FIRMWARE_LC_SAVE) for the save bridge while
  ; the game owns LC_WORLD.
  ldx #LC_WORLD_SIZE-2
@swap_lc:
  lda f:LC_WORLD_STAGE,x
  pha
  lda f:LC_WORLD,x
  sta f:LC_WORLD_STAGE,x
  pla
  sta f:LC_WORLD,x
  dex
  dex
  bpl @swap_lc
  ax8
  lda #0
  pha
  plb
  sec
  xce
  pla
  sta f:SHADOW
  plp
  lda #0
  sta f:SETSLOTCXROM
  sta f:RDMAINRAM
  sta f:WRMAINRAM
  lda f:SLTROMSEL
  ora #SLTROMSEL_SLOT4
  sta f:SLTROMSEL
  ; ROM 1.4 can turn video back on after an Apple display-switch event.
  ; All Apple display setup is now complete; blank once more.
  lda #SS_SCREEN_OFF         ; leaves the prior status unchanged
  sta .loword(SS_COMMAND)
  jml GAME_HANDOFF
failed_native:
  ax8
.a8
.i8
  sec
  xce
failed_far:
  jmp failed
; Read read_request bytes of SS1943.DATA to DATA_BUFFER; read_actual = the
; bytes read.
read_block:
  lda #<DATA_BUFFER
  sta pr_dest
  lda #>DATA_BUFFER
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

; Read A pages of SS1943.DATA to DATA_BUFFER. Carry set: a disk error or a
; short read.
read_pages:
  stz read_request
  sta read_request+1
  jsr read_block
  bcs @done
  lda read_actual+1
  eor read_request+1
  ora read_actual
  cmp #1                     ; carry clear only when all pages came
@done:
  rts

; The D_WORLD parts use no permanent high-memory backing: they wait in
; startup-only audio, pool, game-state and packet scratch until the handoff.
D_WORLD_PART23_SIZE = D_WORLD_PART2_SIZE+D_WORLD_PART3_SIZE
.assert <D_WORLD_PART0_SIZE = 0 && D_WORLD_PART0_SIZE <= DATA_BUFFER_SIZE, error
.assert <D_WORLD_PART1_SIZE = 0 && D_WORLD_PART1_SIZE <= DATA_BUFFER_SIZE, error
.assert <D_WORLD_PART23_SIZE = 0 && D_WORLD_PART23_SIZE <= DATA_BUFFER_SIZE, error
stage_d_world:
  lda #>D_WORLD_PART0_SIZE
  jsr read_pages
  bcs @done
  php
  sei
  clc
  xce
  ax16
  ldx #.loword(DATA_BUFFER)
  ldy #.loword(D_WORLD_STAGE0)
  lda #D_WORLD_PART0_SIZE-1
  mvn #^DATA_BUFFER,#^D_WORLD_STAGE0
  ax8
  lda #0
  pha
  plb
  sec
  xce
  plp
  lda #>D_WORLD_PART1_SIZE
  jsr read_pages
  bcs @done
  php
  sei
  clc
  xce
  ax16
  ldx #.loword(DATA_BUFFER)
  ldy #.loword(D_WORLD_STAGE1)
  lda #D_WORLD_PART1_SIZE-1
  mvn #^DATA_BUFFER,#^D_WORLD_STAGE1
  ax8
  lda #0
  pha
  plb
  sec
  xce
  plp
  lda #>D_WORLD_PART23_SIZE
  jsr read_pages
  bcs @done
  php
  sei
  clc
  xce
  ax16
  ldx #.loword(DATA_BUFFER)
  ldy #.loword(D_WORLD_STAGE2)
  lda #D_WORLD_PART2_SIZE-1
  mvn #^DATA_BUFFER,#^D_WORLD_STAGE2
  ldx #.loword(DATA_BUFFER+D_WORLD_PART2_SIZE)
  ldy #.loword(D_WORLD_STAGE3)
  lda #D_WORLD_PART3_SIZE-1
  mvn #^DATA_BUFFER,#^D_WORLD_STAGE3
  ax8
  lda #0
  pha
  plb
  sec
  xce
  plp
  clc
@done:
  rts

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
  lda #<DATA_BUFFER
  sta pr_dest
  lda #>DATA_BUFFER
  sta pr_dest+1
  stz pr_count
  lda #>SETTINGS_SIZE
  sta pr_count+1
  jsr pr_read
  bcs @done
  clc
  xce
  ax16
  ldx #.loword(DATA_BUFFER)
  ldy #.loword(INPUT_SETTINGS)
  lda #SETTINGS_SIZE-1
  mvn #^DATA_BUFFER,#^INPUT_SETTINGS
  ax8
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
  cmp #>SLOT1_ROM
  jcc @done
  cmp #>SLOT_ROMS_END
  jcs @done
  sec
  sbc #>SLOT1_ROM-1             ; the slot
  asl
  asl
  asl
  asl
  sta smart_slot
  lda boot_unit
  and #UNIT_SLOT
  cmp smart_slot
  jne @done
  lda boot_driver
  clc
  adc #SMARTPORT_ENTRY
  jcs @done
  sta smart_entry
  lda boot_driver+1
  sta smart_entry+1
  lda #1                        ; the SmartPort unit: 1, or 2 for drive 2
  bit boot_unit
  bpl :+
  inc
:
  sta smart_unit
  lda smart_entry+1
  cmp #>SLOT1_ROM
  jcc @done
  cmp #>SLOT_ROMS_END
  jcs @done
  sta probe_ptr+1
  stz probe_ptr
  ldy #1
  lda (probe_ptr),y
  cmp #ID_BYTE1
  jne @done
  ldy #3
  lda (probe_ptr),y
  jne @done
  iny
  iny
  lda (probe_ptr),y
  cmp #ID_BYTE5
  jne @done
  iny
  iny
  lda (probe_ptr),y             ; $Cn07: a SmartPort
  jne @done
  ldy #BLOCK_ENTRY
  lda (probe_ptr),y
  clc
  adc #SMARTPORT_ENTRY
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
; no duplicate of these immutable VRAM/SRAM uploads in host RAM. Each record
; fits DATA_BUFFER (scripts/boot_disk.py boot_uploads).
.a8
.i8
load_card:
  lda #SS_SET_SHADOW
  sta .loword(SS_COMMAND)
  jsr card_on
  lda #SS_SHADOW_NONE
  sta .loword(SS_DATA_OUT)
  jsr card_off
  jsr freeze_mirror
@record:
  lda #RECORD_HEADER_SIZE
  sta read_request
  stz read_request+1
  jsr read_block
  jcs failed
  ldx #RECORD_HEADER_SIZE-1
@keep:
  lda DATA_BUFFER,x
  sta card_header,x
  dex
  bpl @keep
  lda card_header+RECORD_SIZE
  ora card_header+RECORD_SIZE+1
  bne :+
  ; Keep the text timing blanked until the native entry selects the cable's
  ; game mode. A firmware graphics mode here can finish after ScreenOff and
  ; expose the newly loaded art during host/DOC initialization (ROM 1.4 E29).
  lda #SS_SCREEN_OFF
  sta .loword(SS_COMMAND)
  rts
:
  lda card_header+RECORD_CONTROL
  and #RECORD_FINAL_SRAM
  beq :+
  lda #1
  sta mirror_final
  jsr freeze_mirror
:
  lda card_header+RECORD_CONTROL
  and #RECORD_FINAL_VRAM
  beq :+
  lda #1
  sta card_final_video
  jsr freeze_mirror
  lda #SS_SCREEN_OFF         ; text VRAM is about to become game data
  sta .loword(SS_COMMAND)    ; blank only this final, short handoff
:
  lda card_header+RECORD_MASK
  sta upload_map_mask
  ; Disk firmware may restore Apple video switches. Read the record first,
  ; then establish the card's byte-write path before its DMA phase.
  lda card_header+RECORD_SIZE
  sta amount
  sta read_request
  lda card_header+RECORD_SIZE+1
  sta amount+1
  sta read_request+1
  lda card_header+RECORD_CONTROL
  and #RECORD_PACKED
  beq @read_upload
  lda card_header+RECORD_STORED
  sta read_request
  lda card_header+RECORD_STORED+1
  sta read_request+1
  ora read_request
  jeq failed
  lda read_request+1
  cmp #>DATA_BUFFER_SIZE
  jcs failed
@read_upload:
  jsr read_block
  jcs failed
  lda card_header+RECORD_CONTROL
  and #RECORD_PACKED
  beq @upload_ready
  ; Reassert the shadow state after the firmware read before writing
  ; STARTUP_UNPACK_OUTPUT. Text shadowing remains enabled.
  lda f:SHADOW
  ora #SHADOW_GRAPHICS
  sta f:SHADOW
  php
  sei
  clc
  xce
  ax16
  lda read_actual
  cmp read_request
  jne failed_native
  lda amount
  sta read_actual            ; the unpacked size, for the check below
  sta unpack_end
  jsr startup_unpack
  ax8
  sec
  xce
  plp
@upload_ready:
  stz mirror_frozen
  jsr freeze_mirror
  lda card_final_video
  beq :+
  lda #SS_SCREEN_OFF
  sta .loword(SS_COMMAND)
:
  lda #SS_UPLOAD_DATA
  sta .loword(SS_COMMAND)
  jsr card_on
  lda #SS_UPLOAD_LINEAR
  sta .loword(SS_DATA_OUT)
  ldx #0
@address:
  lda card_header+RECORD_ADDRESS,x
  sta .loword(SS_DATA_OUT)
  inx
  cpx #3
  bne @address
  lda amount
  sta .loword(SS_DATA_OUT)
  lda amount+1
  sta .loword(SS_DATA_OUT)
  lda #0                     ; the high byte of the length, then the source
  sta .loword(SS_DATA_OUT)
  sta .loword(SS_DATA_OUT)
  sta .loword(SS_DATA_OUT)
  sta .loword(SS_DATA_OUT)
  jsr card_off
  jsr card_on
  clc
  xce
  ax16
.a16
.i16
  lda amount
  cmp read_actual
  jne failed_native
  and #$fffc                    ; the loops below send four bytes at a time
  sta send_limit
  ldx #0
  a8
.a8
  lda card_header+RECORD_CONTROL
  and #RECORD_PACKED
  bne @send_unpacked
  cpx send_limit
  beq @send_tail
@send:
.repeat 4
  lda f:DATA_BUFFER,x
  sta f:SS_DATA_OUT
  inx
.endrepeat
  cpx send_limit
  bcc @send
@send_tail:
  cpx amount
  beq @sent
@send_tail_loop:
  lda f:DATA_BUFFER,x
  sta f:SS_DATA_OUT
  inx
  cpx amount
  bcc @send_tail_loop
  bra @sent
@send_unpacked:
  cpx send_limit
  beq @unpacked_tail
@unpacked_loop:
.repeat 4
  lda f:STARTUP_UNPACK_OUTPUT,x
  sta f:SS_DATA_OUT
  inx
.endrepeat
  cpx send_limit
  bcc @unpacked_loop
@unpacked_tail:
  cpx amount
  beq @sent
@unpacked_tail_loop:
  lda f:STARTUP_UNPACK_OUTPUT,x
  sta f:SS_DATA_OUT
  inx
  cpx amount
  bcc @unpacked_tail_loop
@sent:
  ax8
.a8
.i8
  sec
  xce
  jsr card_off
  jsr mirror_progress
  jmp @record
card_on:
  lda .loword(SS_HANDSHAKE)
  cmp #SS_READY
  bne card_on
  rts
card_off:
  lda .loword(SS_HANDSHAKE)
  bne card_off
  rts
send_limit: .res 2           ; amount rounded down to the 4-byte send loop

.include "boot_unpack.s"
.a8
.i8

; GetStatus is the library's card-presence test: one dummy read and twelve
; result bytes. Never open the game file until the five-byte signature agrees.
detect_card:
  stz .loword(SS_COMMAND)    ; SS_GET_STATUS
  ldy #0
  ldx #0
@wait:
  lda .loword(SS_HANDSHAKE)
  cmp #1
  beq @reply
  dex
  bne @wait
  dey
  bne @wait
  sec
  rts
@reply:
  lda .loword(SS_DATA_IN)
  ldx #0
@read:
  lda .loword(SS_DATA_IN)
  sta card_status,x
  inx
  cpx #SS_STATUS_SIZE
  bne @read
  ldx #card_signature_end-card_signature-1
@signature:
  lda card_status+SS_SIGNATURE,x
  cmp card_signature,x
  bne @absent
  dex
  bpl @signature
  lda card_status+SS_STATUS_COUNT
  cmp #SS_STATUS_BYTES
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
  x16
.a8
.i16
  stz probe_ptr
  stz probe_ptr+1
  lda #PROBE_TOP_BANK
@write_byte:
  sta probe_ptr+2
  eor #$ff
  sta [probe_ptr]
  eor #$ff
  dec
  cmp #^PAYLOAD
  bcs @write_byte
  ldx #MEMORY_BITMAP_SIZE-1
@clear_bitmap:
  stz memory_bitmap,x
  dex
  bpl @clear_bitmap
  lda #3                      ; $00/$01 are motherboard RAM
  sta memory_bitmap
  lda #PROBE_TOP_BANK
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
  cmp #^PAYLOAD
  bcs @read_byte
  ldx #PROBE_OFFSET
  stx probe_ptr
  lda #PROBE_TOP_BANK
@write_word:
  sta probe_ptr+2
  jsr memory_probe_word
.a16
  sta [probe_ptr]
  a8
.a8
  lda probe_ptr+2
  dec
  cmp #^PAYLOAD
  bcs @write_word
  lda #PROBE_TOP_BANK
@read_word:
  sta probe_ptr+2
  jsr memory_probe_word
.a16
  cmp [probe_ptr]
  a8
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
  cmp #^PAYLOAD
  bcs @read_word
  lda #^PAYLOAD
@required:
  jsr memory_bank_found
  bcc @missing
  inc
  cmp #^PAYLOAD_END
  bcc @required
  ax8
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
  ax8
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
  a16
.a16
  and #$00ff
  eor #PROBE_WORD
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
  a16
.a16
  and #7
  tax
  a8
.a8
  lda memory_bits,x
  sta probe_bit
  lda 1,s
  a16
.a16
  and #$00ff
  lsr
  lsr
  lsr
  tax
  a8
.a8
  pla
  rts

; Firmware's own count, as in Doom fwBanks. This is diagnostic only: the
; top bank is not proof that every lower required bank exists.
; Return the exclusive fast-RAM bank limit, or zero if unknown.
firmware_banks:
  lda f:ROMVER
  beq @rom00
  cmp #ROMVER_01
  beq @rom01_03
  cmp #ROMVER_03
  bne @unknown
@rom01_03:
  lda f:FW_BANKS_ROM03
  bra @check
@rom00:
  lda f:FW_BANKS_ROM00
@check:
  cmp #FW_BANKS_MIN
  bcc @unknown
  cmp #FW_BANKS_END
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
  x16
.i16
  ldy #2                      ; add slow $E0/$E1 to the bitmap's fast RAM
  ldx #MEMORY_BITMAP_SIZE-1
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
  a16
.a16
  tya
  sta memory_banks
  ldx #found_value
  jsr memory_kilobytes
.a8
  jsr firmware_banks
  sta firmware_limit
  beq @no_firmware
  a16
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
  ax8
.a8
.i8
  sec
  xce
  ldx #0
@found:
  lda found_text,x
  beq @firmware_start
  ora #TEXT_NORMAL
  sta f:TEXT_ROW_13+4,x             ; row 13, column 4
  inx
  bne @found
@firmware_start:
  ldx #0
@firmware:
  lda firmware_text,x
  beq @missing_start
  ora #TEXT_NORMAL
  sta f:TEXT_ROW_14+4,x             ; row 14, column 4
  inx
  bne @firmware
@missing_start:
  ldx #0
@missing:
  lda missing_text,x
  beq @done
  ora #TEXT_NORMAL
  sta f:TEXT_ROW_15+4,x             ; row 15, column 4
  inx
  bne @missing
@done:
  rts

.a8
.i16
; memory_hex: A = the hex digit character of A (0-15). JSR.
memory_hex:
  cmp #10
  bcc :+
  adc #'A'-'0'-10-1             ; carry 1 from the CMP
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
  a8
.a8
  lda probe_digit
  cpy #0
  bne @store
  cmp #'0'
  beq @next
@store:
  sta a:0,x
  inx
@next:
  a16
.a16
  iny
  iny
  cpy #8
  bcc @place
  a8
.a8
  lda #'K'
  sta a:0,x
  stz a:1,x
  rts

memory_bits: .byte 1,2,4,8,16,32,64,128
memory_tens: .word 1000,100,10,1
memory_bitmap: .res MEMORY_BITMAP_SIZE  ; a bit for each bank found
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
  sta f:KBD               ; 80STORE off, main 40-column text page
  sta f:CLR80VID
  sta f:SETALTCHAR               ; alternate characters enable MouseText
  sta f:TXTSET
  sta f:MIXCLR
  sta f:TXTPAGE1
  lda f:NEWVIDEO
  and #<~NEWVIDEO_SHR
  sta f:NEWVIDEO
  lda #$60                   ; medium blue text, black background
  sta f:TBCOLOR
  lda f:CLOCKCTL
  and #<~CLOCKCTL_BORDER         ; a black border
  sta f:CLOCKCTL
  jsr clear_text
  ldx #3
@title:
  lda title,x
  ora #TEXT_NORMAL
  sta f:TEXT_ROW_2+18,x            ; row 2, centered
  dex
  bpl @title
  ldx #6                        ; the 7 characters of loading_text
@label:
  lda loading_text,x
  ora #TEXT_NORMAL
  sta f:TEXT_ROW_21+16,x            ; row 21, centered
  dex
  bpl @label
  jsr draw_progress
  rts

clear_text:
  ldx #0
  lda #TEXT_SPACE
@clear:
  sta f:TEXT_PAGE1,x
  sta f:TEXT_ROW_2,x
  sta f:TEXT_ROW_4,x
  sta f:TEXT_ROW_6,x
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
  ax16
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
  cmp #PROGRESS_CELLS
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
  ax8
.a8
.i8
  sec
  xce
  jsr draw_progress
  rts

draw_progress:
  lda #MT_RIGHT_LINE
  sta f:PROGRESS_TEXT-1      ; closes the bar's left end
  lda #MT_LEFT_LINE
  sta f:PROGRESS_TEXT+PROGRESS_CELLS   ; closes the bar's right end
  ldx #0
@cell:
  cpx progress_done
  lda #MT_CELL_EMPTY
  bcs :+
  lda #MT_CELL_FULL
:
  sta f:PROGRESS_TEXT,x
  inx
  cpx #PROGRESS_CELLS
  bne @cell
  rts

; Keep the firmware's completed text image and font visible during uploads.
; Re-entering FC/0 clears both text planes before rendering; it must not be
; used as a progress refresh. Update only the 36 bar characters in plane 0.
; ROM 1.4 text40 uses two plane addresses per cell (SS_TEXT40).
; Its alternate font maps MouseText $4E/$5C to VGA glyphs $CE/$DC.
mirror_progress:
  lda mirror_final
  bne @done
  lda progress_done
  cmp mirrored_progress
  beq @done
  sta mirrored_progress
  lda #1                     ; character plane only; attributes/font stay intact
  sta upload_map_mask
  stz mirror_frozen
  jsr freeze_mirror
  lda #SS_UPLOAD_DATA
  sta .loword(SS_COMMAND)
  jsr card_on
  ldx #0
@parameter:
  lda bar_upload,x
  sta .loword(SS_DATA_OUT)
  inx
  cpx #SS_UPLOAD_PARAMETERS
  bne @parameter
  jsr card_off
  jsr card_on
  ldx #0
@cell:
  cpx progress_done
  lda #CARD_CELL_EMPTY
  bcs :+
  lda #CARD_CELL_FULL
:
  sta .loword(SS_DATA_OUT)
  lda #$10                   ; unused odd address, as in the firmware clear
  sta .loword(SS_DATA_OUT)
  inx
  cpx #PROGRESS_CELLS
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
  lda #SS_NATIVE             ; also the flag value
  sta mirror_disabled
  jsr text_emulation
@register_setup:
  ; UploadData selects the linear aperture but retains VGA write addressing.
  ; One selected VGA plane receives the build-prepared byte stream. Text
  ; scanout remains live. Restore only upload addressing between disk reads;
  ; resetting the complete display mode for each block is unnecessary.
  ldx #0
@register:
  lda #SS_SET_VGA_REG
  sta .loword(SS_COMMAND)
  jsr card_on
  ldy #SS_VGA_REG_PARAMETERS
@byte:
  lda upload_registers,x
  sta .loword(SS_DATA_OUT)
  inx
  dey
  bne @byte
  jsr card_off
  cpx #upload_registers_end-upload_registers
  bne @register
@done:
  rts

; Select 40-column text: A = SS_EMULATION or SS_NATIVE.
text_emulation:
  pha
  lda #SS_SET_MODE
  sta .loword(SS_COMMAND)
  jsr card_on
  lda #SS_MODE_TEXT40
  sta .loword(SS_DATA_OUT)
  pla
  sta .loword(SS_DATA_OUT)
  jsr card_off
@mode:
  lda .loword(SS_HANDSHAKE)
  cmp #SS_DONE
  bne @mode
  rts

unsupported_driver:
  ; DATA's first read may already have frozen the mirrored loading screen.
  ; Re-enable text emulation so the error is visible on the card display.
  lda #SS_EMULATION
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
  ora #TEXT_NORMAL
  sta f:TEXT_ROW_2+18,x
  dex
  bpl @title
  ldx #0
error_text:
  lda a:0,x                  ; the operand is the message address
  beq @details
  ora #TEXT_NORMAL
  sta f:TEXT_ROW_11+8,x
  inx
  bne error_text
@details:
  lda memory_missing
  beq @hold
  jsr memory_details
@hold:
  bra @hold
failed:
  ldx #<load_error_message
  ldy #>load_error_message
  bra requirement_error
load_error_message: .asciiz "1943 LOAD ERROR"
no_card_message: .asciiz "SECOND SIGHT NOT DETECTED"
no_memory_message: .asciiz "1943 REQUIRES 1 MB OF MEMORY"
unsupported_driver_message: .asciiz "UNSUPPORTED BOOT DEVICE DRIVER"
title: .byte "1943"
loading_text: .byte "LOADING"
card_signature: .byte "GSVGA"
card_signature_end:
card_status: .res SS_STATUS_SIZE
card_final_video: .byte 0
mirror_frozen: .byte 0
mirror_disabled: .byte 0
mirror_final: .byte 0
mirrored_progress: .byte 0
bar_upload:                  ; UploadData of the progress bar cells
  .byte SS_UPLOAD_LINEAR
  .faraddr SS_TEXT40+(PROGRESS_ROW*40+PROGRESS_COLUMN)*2   ; plane 0
  .faraddr PROGRESS_CELLS*2  ; each character byte and its unused odd address
  .faraddr 0                 ; the IIgs source: the card ignores it
upload_registers:
  .word VGA_SEQ_INDEX        ; sequencer map mask: the planes of the record
  .byte SEQ_MAP_MASK
  .word VGA_SEQ_DATA
upload_map_mask:
  .byte $0f
  .word VGA_SEQ_INDEX        ; unchained, odd/even CPU writes disabled
  .byte SEQ_MEMORY_MODE
  .word VGA_SEQ_DATA
  .byte $06
  .word VGA_GC_INDEX         ; write mode 0, no odd/even read addressing
  .byte GC_MODE
  .word VGA_GC_DATA
  .byte $00
upload_registers_end:
loaded_bytes: .dword 0
progress_done: .word 0
; The bytes of SS1943.DATA read when each progress cell fills: a copy of the
; table of the data file header (DATA_PROGRESS, scripts/boot_disk.py).
progress_thresholds: .res PROGRESS_CELLS*4
path: .byte 11,"SS1943.DATA"
read_request: .res 2
read_actual: .res 2
segments: .res 1
current: .res 1
headers: .res MAX_SEGMENTS*SEGMENT_ENTRY
card_startup: .res 1
card_header: .res RECORD_HEADER_SIZE
dest: .res 3                 ; the segment loop: the next host address
remaining: .res 3            ; the segment loop: the bytes left to read
amount: .res 2               ; the bytes of this block
probe_bit: .res 1            ; check_memory: the bit of the bank in memory_bitmap
probe_number: .res 2         ; memory_kilobytes: the value left to print
probe_digit: .res 1          ; memory_kilobytes: the digit
; The file reader
PR_ZP = pr_zp
PR_DBUF = .loword(READER_BUFFERS)
PR_IBUF = .loword(READER_BUFFERS)+$200
.assert READER_BUFFERS+READER_BUFFERS_SIZE <= A_WORLD_STAGE, error
.a8
.i8
.include "prodos_read.s"
loader_end:
