; Unchained VGA helpers for the 224 x 256 renderer. Addresses count
; four-pixel groups within a 256 KB segment.

        .ifndef VIDEO_INC
        .equ VIDEO_INC, 1

        .include "second_sight.inc"
        .include "vga.inc"
        .include "z180.inc"

        .equ GROUPS_PER_ROW, 56
        .equ PAGE_GROUPS, GROUPS_PER_ROW * 256

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

        .macro set_io_byte port, value, shift, symbols
        .if \symbols
        set_io \port, (\value) >> \shift
        .else
        set_io \port, ((\value) >> \shift) & 0xFF
        .endif
        .endm

; Map the Oak VGA window for the CPU: VGA mapping, half 1, read and write segments.
        .macro vga_aperture read_segment=0, write_segment=0
        oak_set OAK_MEMORY_MAP, 0
        set_io LINEAR_WINDOW_OFF, 0
        set_io CBR, 0x44
        ld a,(0xC000)                   ; select VGA half at physical $50000
        set_io CBR, 0x94
        oak_set OAK_READ_SEGMENT, \read_segment
        oak_set OAK_WRITE_SEGMENT, \write_segment
        .endm

        .macro write_mode mode=1, mask=0x0F
        gc_set GC_MODE, 0x40 | \mode
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
        and 0x08
        jp nz,1b
2:      in a,(c)
        and 0x08
        jp z,2b
        .endm

        .endif
