; Unchained VGA helpers for the 224 x 256 renderer. Addresses count
; four-pixel groups within a 256 KB segment.

        .ifndef VIDEO_INC
        .equ VIDEO_INC, 1

        .include "second_sight.inc"
        .include "vga.inc"
        .include "z180.inc"

        .equ GROUPS_PER_ROW, 56         ; 224 pixels: four pixels a group
        .equ PAGE_ROWS, 256
        .equ PAGE_GROUPS, GROUPS_PER_ROW * PAGE_ROWS
        .equ BOUNDED_ROWS, 129          ; a camera move of more rows redraws the whole view
        .equ WORLD_GROUPS, 64           ; groups of a world row (256 pixels)
        .equ COLUMN_ROWS, 32            ; rows of a world column

; The two display pages: page 0 starts at group PAGE_START, page 1
; PAGE_DISTANCE groups later (bit 7 of the high byte). The groups before
; each page hold the fixed text area.
        .equ PAGE_START, 0x400
        .equ PAGE_DISTANCE, 0x8000
; Each row of a page has a twin PAGE_ROWS rows later: the scan-out shows
; one of them while the card draws the other.
        .equ TWIN_DISTANCE, PAGE_GROUPS
; The upper twin of each page.
        .equ UPPER_TWIN_0, PAGE_START + TWIN_DISTANCE
        .equ UPPER_TWIN_1, UPPER_TWIN_0 + PAGE_DISTANCE

; DMA GROUPS groups from physical SOURCE to physical DEST. In write mode 1 one
; VRAM read and write moves four pixels. STREAM 1 keeps a running packet
; receive on channel 1. SYMBOLS 1: an operand is a link-time symbol. The
; assembler cannot mask a symbol; its relocation takes the right byte.
        .macro dma_groups source, dest, groups, fixed_source=0, stream=1, symbols=0
        set_io SAR0L, (\source) & 0xFF
        set_io_byte SAR0H, \source, 8, \symbols
        set_io_byte SAR0B, \source, 16, \symbols
        set_io DAR0L, (\dest) & 0xFF
        set_io_byte DAR0H, \dest, 8, \symbols
        set_io_byte DAR0B, \dest, 16, \symbols
        set_io BCR0L, (\groups) & 0xFF
        set_io_byte BCR0H, \groups, 8, \symbols
        .if \fixed_source
        set_io DMODE, DMODE_BURST | DMODE_SOURCE_FIXED
        .else
        set_io DMODE, DMODE_BURST
        .endif
        .if \stream
        set_io DCNTL, DCNTL_STREAM
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        .else
        set_io DCNTL, 0
        set_io DSTAT, DSTAT_DE0 | DSTAT_DME
        .endif
        .endm

; set_io_byte: set_io with the byte of VALUE at SHIFT (a link-time symbol
; is not masked: its relocation takes the byte).
        .macro set_io_byte port, value, shift, symbols
        .if \symbols
        set_io \port, (\value) >> \shift
        .else
        set_io \port, ((\value) >> \shift) & 0xFF
        .endif
        .endm

; vga_aperture: map the Oak VGA window for the CPU: the VGA mapping, video
; RAM half 1 (a read of VRAM_HALF1_SELECT), the read and write segments;
; common area 1 then shows VGA_WINDOW at WINDOW_C000.
        .macro vga_aperture read_segment=0, write_segment=0
        oak_set OAK_MEMORY_MAP, 0
        set_io LINEAR_WINDOW_OFF, 0
        set_io CBR, HALF1_SELECT_C000
        ld a,(WINDOW_C000)              ; selects video RAM half 1
        set_io CBR, VGA_WINDOW_C000
        oak_set OAK_READ_SEGMENT, \read_segment
        oak_set OAK_WRITE_SEGMENT, \write_segment
        .endm

; write_mode: the VGA write MODE (1: a read and a write move four latched
; pixels) to the planes MASK.
        .macro write_mode mode=1, mask=ALL_PLANES
        gc_set GC_MODE, GC_MODE_256 | \mode
        seq_set SEQ_MAP_MASK, \mask
        .endm

; Set the display start to group ADDRESS.
        .macro start_address address
        oak_set OAK_EXTENDED_CRTC, (\address) >> 16
        vga_set VGA_CRTC_INDEX, CRTC_START_HIGH, ((\address) >> 8) & 0xFF
        vga_set VGA_CRTC_INDEX, CRTC_START_LOW, (\address) & 0xFF
        .endm

; Wait for a new vertical retrace edge; leave a retrace in progress first.
        .macro wait_retrace
        ld bc,VGA_STATUS
1:      in a,(c)
        and STATUS_RETRACE
        jp nz,1b
2:      in a,(c)
        and STATUS_RETRACE
        jp z,2b
        .endm

        .endif
