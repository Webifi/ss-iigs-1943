; OTI-087X (Oak) VGA ports and register indexes. The Oak decodes the full
; 16-bit I/O address, so use out (c) with BC set to the port.

        .ifndef VGA_INC
        .equ VGA_INC, 1

        .equ VGA_ATTR, 0x3C0
        .equ VGA_MISC_WRITE, 0x3C2
        .equ VGA_SEQ_INDEX, 0x3C4
        .equ VGA_SEQ_DATA, 0x3C5
        .equ VGA_DAC_MASK, 0x3C6
        .equ VGA_DAC_READ_INDEX, 0x3C7
        .equ VGA_DAC_WRITE_INDEX, 0x3C8
        .equ VGA_DAC_DATA, 0x3C9
        .equ VGA_GC_INDEX, 0x3CE
        .equ VGA_GC_DATA, 0x3CF
        .equ VGA_CRTC_INDEX, 0x3D4
        .equ VGA_CRTC_DATA, 0x3D5
        .equ VGA_STATUS, 0x3DA
        .equ OAK_INDEX, 0x3DE
        .equ OAK_DATA, 0x3DF

; Sequencer
        .equ SEQ_MAP_MASK, 0x02
        .equ SEQ_MEMORY_MODE, 0x04

; Graphics controller
        .equ GC_SET_RESET, 0x00
        .equ GC_ENABLE_SET_RESET, 0x01
        .equ GC_COLOR_COMPARE, 0x02
        .equ GC_DATA_ROTATE, 0x03
        .equ GC_READ_MAP, 0x04
        .equ GC_MODE, 0x05
        .equ GC_MISC, 0x06
        .equ GC_COLOR_DONT_CARE, 0x07
        .equ GC_BIT_MASK, 0x08

; CRT controller
        .equ CRTC_START_HIGH, 0x0C
        .equ CRTC_START_LOW, 0x0D

; Oak extended registers (index through OAK_INDEX)
        .equ OAK_MEMORY_MAP, 0x05       ; 0x19: linear 1 MB at Oak 0x100000; 0x00: VGA windows
        .equ OAK_EXTENDED_CRTC, 0x17
        .equ OAK_READ_SEGMENT, 0x23
        .equ OAK_WRITE_SEGMENT, 0x24
        .equ OAK_COMMON_SEGMENT, 0x25
        .equ OAK_EXPAND_CONTROL, 0x30
        .equ OAK_FOREGROUND, 0x31
        .equ OAK_BACKGROUND, 0x32
        .equ OAK_PATTERN, 0x33
        .equ OAK_PIXEL_MASK, 0x34
        .equ OAK_LATCH_INDEX, 0x35
        .equ OAK_LATCH_DATA, 0x36

; Write VALUE to register INDEX behind the index port PORT (data port PORT+1).
        .macro vga_set port, index, value
        ld bc,\port
        ld a,\index
        out (c),a
        inc c
        ld a,\value
        out (c),a
        .endm

        .macro oak_set index, value
        vga_set OAK_INDEX, \index, \value
        .endm

        .macro gc_set index, value
        vga_set VGA_GC_INDEX, \index, \value
        .endm

        .macro seq_set index, value
        vga_set VGA_SEQ_INDEX, \index, \value
        .endm

        .endif
