; The IIgs memory map of the game: every fixed area, its size and its use,
; for the code. src/iigs.cfg places the same areas for ld65; src/game.s
; checks that the two agree, and exports the values that scripts/boot_disk.py
; needs (build/game/host.lbl).

; Program code and its banks (src/iigs.cfg segments)
NATIVE_CODE         = $002000   ; bank-zero code: NATIVE segment
NATIVE_CODE_SIZE    = $3000
BOOT_CODE           = $006000   ; CODE segment: entry, startup, handoff stub
BOOT_CODE_SIZE      = $0200
SOUND_CODE          = $006200   ; SOUND segment
SOUND_CODE_SIZE     = $1E00
GAMEPLAY_CODE       = $010000   ; GAMEPLAY segment
GAMEPLAY_CODE_SIZE  = $8000
GAMEFLOW_CODE       = $01C000   ; GAMEFLOW segment
GAMEFLOW_CODE_SIZE  = $3400
PAYLOAD             = $020000   ; data and the far code segments, to $0FFFFF
PAYLOAD_END         = $100000
VIDEO_E0_DATA       = $E02000   ; slow-bank data: the card owns the display
VIDEO_E1_DATA       = $E12000
VIDEO_DATA_SIZE     = $A000

; World data that the main CPU reads (scripts/iigs_payload.py world_blob_at)
LOW_WORLD           = $019000   ; with B_WORLD: low-world.bin
LOW_WORLD_SIZE      = $2000
B_WORLD             = $01B000   ; world data around CAB_SCORES and WORLD_SLOTS
B_WORLD_SIZE        = $1000
CAB_SCORES          = $01B300   ; the score table of the cabinet (src/cabinet.s)
CAB_SCORES_SIZE     = $0050
CAB_SCORE_ENTRY     = 16        ; one rank: SCORE_DIGITS digits, 3 initials, 5 more bytes
WORLD_SLOTS         = $01B400   ; the world slot table (src/game_world.s)
LC_WORLD            = $01F400   ; bank-one language card tail
LC_WORLD_SIZE       = $0C00
BC_WORLD            = $00BC00   ; bank-zero world data (staged after LC_WORLD)
BC_WORLD_SIZE       = $0300
A_WORLD             = $00A000   ; where the boot loader runs until the handoff
A_WORLD_SIZE        = $0C00
C_WORLD             = $00C000   ; bank-zero language card, bank 2 view
C_WORLD_SIZE        = $1000
D_WORLD             = $00D000   ; bank-zero language card
D_WORLD_SIZE        = $2B00

; The game stack: the entry sets S here.
STACK_TOP           = $001FFF

; The game RAM in bank 0 (src/game_ram.s): the game state up to MUSIC_PAGE,
; and the object pools.
GAME_RAM            = $001000
GAME_RAM_SIZE       = $0E00
POOL_RAM            = $005000
POOL_RAM_SIZE       = $1000

; The direct page of the music interrupt and the sound code: their page-zero
; names (src/music_player.s, src/fm_voice.s) are offsets from it. The bank-0
; RAM equates of the $1E00 page share it.
MUSIC_PAGE          = $001E00

; The card packet that stream_packet (src/stream.s) sends starts here, in
; bank zero, where its PEI loop reads it as page zero.
PACKET_BUFFER       = $008000

; The paused menu (src/menu_mirror_host.s) keeps card SRAM $0000-$FFFF here,
; at the end of the payload. The first 1 KiB of the card receive packet in it
; is scratch, so the menu code (the MIRROR segment) runs from that part.
MIRROR_SNAPSHOT     = $0F0000
MIRROR_SNAPSHOT_SIZE = $10000
MIRROR_CODE         = $0F4000
MIRROR_CODE_SIZE    = $0400

; Menu scratch in bank $E0 (scripts/menu_mirror.py): only text page 1 is
; shadowed, and play, the menu and Save never touch it.
MIRROR_PALETTE      = $E00800   ; the card palette and its registers
MIRROR_PALETTE_SIZE = 776
MIRROR_TEXT         = $E00B08   ; the Apple text page
MIRROR_SLOT         = $E00F08   ; the card SRAM under the menu helper slot
MIRROR_SLOT_SIZE    = $1000
MIRROR_LC_STATE     = $E01F08   ; the language card state of the firmware
; MIRROR_RETURN (game RAM, src/menu_mirror_host.s) keeps the card bootstrap's saved SP and MMU bytes.
MIRROR_RETURN_SIZE  = 8
; The card video snapshot: the language card RAM of banks $E0 and $E1.
MIRROR_VIDEO_E0     = $E0D000
MIRROR_VIDEO_E1     = $E1D000

; Bank-zero page zero and the page-one stack: the firmware's in emulation
; mode. The boot loader runs with them; the save bridge
; (src/input_disk_bridge.s) keeps a copy of page zero and calls the block
; driver with them.
ZERO_PAGE           = $000000
ZERO_PAGE_SIZE      = $0100
EMULATION_STACK_TOP = $0001FF

; The paused menu (src/input_menu.s) draws its text here, MENU_ROWS rows of
; MENU_COLUMNS characters, then copies it to the text page. Save, from the
; menu, reads and writes the settings block in the same RAM (the save bridge,
; src/input_disk_bridge.s); the menu draws again after it. Play keeps nothing here.
MENU_TEXT           = $000800
MENU_ROWS           = 24
MENU_COLUMNS        = 28
SAVE_BLOCK_BUFFER   = $000800

; The boot loader (src/boot.s). boot0 loads SS1943.SYSTEM to SYSTEM_LOAD; its
; BOOT segment moves the LOADER segment, which follows it in the file, to
; BOOT_LOADER. The loader runs there in emulation mode until the handoff.
SYSTEM_LOAD         = $002000
SYSTEM_BOOT_SIZE    = $0100
BOOT_LOADER         = $00A000
BOOT_LOADER_SIZE    = $1000
LOADER_ZERO_PAGE    = $000020   ; the loader's page-zero variables, below DRV_COMMAND
LOADER_ZERO_PAGE_SIZE = $0020

; The boot loader reads SS1943.DATA in 4 KB blocks through this buffer.
DATA_BUFFER         = $000800
DATA_BUFFER_SIZE    = $1000

; The file reader (bootloader/prodos_read.s): a data block and an index block.
READER_BUFFERS      = $009000
READER_BUFFERS_SIZE = $0400

; The card startup decoder (src/boot_unpack.s) expands one packed record
; here. stage_d_world uses the same RAM after the card uploads.
STARTUP_UNPACK_OUTPUT = $018000

; Staging: the boot loader parks each world part where the loader and the
; firmware leave RAM free; the handoff stub (src/game.s) moves them in place.
A_WORLD_STAGE             = $009400   ; A_WORLD
LC_WORLD_STAGE            = $00B000   ; LC_WORLD; then the firmware's $01F400 image
C_WORLD_STAGE0            = $008000   ; C_WORLD + $0000, $0C00 bytes
C_WORLD_STAGE1            = $000C00   ; C_WORLD + $0C00, $0400 bytes
C_WORLD_PART0_SIZE        = $0C00
C_WORLD_PART1_SIZE        = $0400
D_WORLD_STAGE0            = $018000   ; D_WORLD + $0000, $1000 bytes
D_WORLD_STAGE1            = $005000   ; D_WORLD + $1000, $1000 bytes
D_WORLD_STAGE2            = $001800   ; D_WORLD + $2000, $0700 bytes
D_WORLD_STAGE3            = $008C00   ; D_WORLD + $2700, $0400 bytes
D_WORLD_PART0_SIZE        = $1000
D_WORLD_PART1_SIZE        = $1000
D_WORLD_PART2_SIZE        = $0700
D_WORLD_PART3_SIZE        = $0400
.assert C_WORLD_PART0_SIZE+C_WORLD_PART1_SIZE = C_WORLD_SIZE, error
.assert D_WORLD_PART0_SIZE+D_WORLD_PART1_SIZE+D_WORLD_PART2_SIZE+D_WORLD_PART3_SIZE = D_WORLD_SIZE, error

; After the handoff the firmware's own bank-zero $C000 contents wait here,
; so the save bridge (src/input_disk_bridge.s) can swap them back for disk calls.
FIRMWARE_C0_SAVE    = $009400   ; C_WORLD + $0000, C_WORLD_PART0_SIZE bytes
FIRMWARE_C1_SAVE    = $00AC00   ; C_WORLD + $0C00, C_WORLD_PART1_SIZE bytes
FIRMWARE_LC_SAVE    = LC_WORLD_STAGE  ; LC_WORLD, LC_WORLD_SIZE bytes

; Bank 1 after startup: the D_WORLD_STAGE0 RAM keeps the music, FM, SSG and
; wave upload state and the world decoder state (src/game_ram.s, BANK1RAM).
BANK1_RAM           = D_WORLD_STAGE0
BANK1_RAM_SIZE      = $1000

.assert GAMEFLOW_CODE+GAMEFLOW_CODE_SIZE <= LC_WORLD, error
.assert B_WORLD = LOW_WORLD+LOW_WORLD_SIZE, error
.assert BC_WORLD = LC_WORLD_STAGE+LC_WORLD_SIZE, error
.assert SOUND_CODE = BOOT_CODE+BOOT_CODE_SIZE, error
.assert MIRROR_SLOT+MIRROR_SLOT_SIZE <= MIRROR_LC_STATE, error
.assert MIRROR_LC_STATE < VIDEO_E0_DATA, error
.assert GAME_RAM+GAME_RAM_SIZE <= MUSIC_PAGE, error
.assert BANK1_RAM+BANK1_RAM_SIZE <= LOW_WORLD, error
.assert NATIVE_CODE+NATIVE_CODE_SIZE <= POOL_RAM, error
.assert POOL_RAM+POOL_RAM_SIZE <= BOOT_CODE, error
