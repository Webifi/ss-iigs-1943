; The format of SS1943.DATA. The boot loader (src/boot.s) reads the file;
; scripts/boot_disk.py writes it with these values, which it reads from the
; debug file of the boot loader (build/game-disk/boot.dbg).
;
; The file: the header block, the segment data in table order, the card
; startup records, the D_WORLD parts, then the C_WORLD parts.

; The header block
DATA_HEADER_SIZE    = 512
DATA_MAGIC          = 0         ; "SS1943"
DATA_VERSION        = 6         ; DATA_FORMAT
DATA_SEGMENTS       = 8         ; the number of segment entries
DATA_STARTUP        = 9         ; nonzero: card startup records follow the segments
DATA_TABLE          = 10        ; the segment entries
DATA_FORMAT         = 2         ; DATA_VERSION of this format
SEGMENT_ENTRY       = 6         ; host address (3 bytes), size (3 bytes)
MAX_SEGMENTS        = 10        ; the segment entries that the table has room for
DATA_PROGRESS       = DATA_TABLE+MAX_SEGMENTS*SEGMENT_ENTRY ; for each progress cell, the bytes read when it fills (4 bytes)
PROGRESS_CELLS      = 36        ; the cells of the progress bar of the loading screen (src/boot.s)
.assert DATA_PROGRESS+PROGRESS_CELLS*4 <= DATA_HEADER_SIZE, error

; A card startup record: this header, then the stored bytes. A record with
; zero size ends the list.
RECORD_ADDRESS      = 0         ; card address (3 bytes)
RECORD_SIZE         = 3         ; bytes after unpack (3 bytes)
RECORD_CONTROL      = 6         ; RECORD_FINAL_* and RECORD_PACKED flags
RECORD_MASK         = 7         ; VGA map mask: the planes that receive the bytes
RECORD_STORED       = 8         ; stored bytes of a packed record (2 bytes)
RECORD_HEADER_SIZE  = 10
RECORD_FINAL_SRAM   = $80       ; the first record that replaces the firmware renderer
RECORD_FINAL_VRAM   = $40       ; the first record that replaces the firmware text image
RECORD_PACKED       = $20       ; scripts/startup_pack.py packed the stored bytes
