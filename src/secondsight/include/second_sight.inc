; Second Sight card ports and physical memory. The card decodes only the low
; eight address bits of its ports.

        .ifndef SECOND_SIGHT_INC
        .equ SECOND_SIGHT_INC, 1

        .equ CARD_HOST, 0xA0            ; data to and from the IIgs; an access acknowledges the event
        .equ CARD_CONFIG, 0xA1          ; write only: a read reloads the configuration from the bus
        .equ BAND_FLAGS_LOW, 0xA4       ; read only
        .equ BAND_FLAGS_HIGH, 0xA5      ; read only
        .equ EVENT_ADDRESS_LOW, 0xA6    ; read only
        .equ EVENT_ADDRESS_HIGH, 0xA7   ; read only
        .equ CLOCK_VGA, 0xA8
        .equ CLOCK_RGB, 0xA9
        .equ LINEAR_WINDOW_OFF, 0xAA
        .equ LINEAR_WINDOW_ON, 0xAB     ; any write: video RAM at VIDEO_WINDOW
        .equ APPLE_IRQ_ASSERT, 0xAC
        .equ APPLE_IRQ_RELEASE, 0xAD

; Physical memory (20-bit Z180 addresses)
        .equ SRAM, 0x00000              ; 128 KB
        .equ SRAM_MIRROR, 0x20000
        .equ VRAM_HALF0_SELECT, 0x40000 ; any access selects video RAM half 0
        .equ VRAM_HALF1_SELECT, 0x50000 ; any access selects video RAM half 1
        .equ EPROM, 0x60000             ; 128 KB EPROM: the firmware image
        .equ VIDEO_WINDOW, 0x80000      ; video RAM through the linear window (32 KB)
        .equ VGA_WINDOW, 0xA0000        ; Oak VGA window while OAK_MEMORY_MAP is 0

; The firmware in SRAM: the parts of the EPROM image that it runs from
; (SRAM address = image offset), and the main text page that it shows.
        .equ FIRMWARE_VECTORS, 0x0000   ; the vectors, start-up code and stack
        .equ FIRMWARE_VECTORS_BYTES, 0x0400
        .equ FIRMWARE_TEXT_PAGE, 0x0400 ; $0400-$0BFF: no image part
        .equ FIRMWARE_HANDLERS, 0x0C00  ; the command and interrupt handlers
        .equ FIRMWARE_HANDLERS_BYTES, 0x1400
        .equ FIRMWARE_RENDERERS, 0x6000 ; the renderers, fonts, tables, mode records
        .equ FIRMWARE_RENDERERS_BYTES, 0xA000

; The MMU base (BBR or CBR) that shows a physical area at logical
; WINDOW_C000: physical = logical + base * 0x1000.
        .equ WINDOW_C000, 0xC000
        .equ VGA_WINDOW_C000, (VGA_WINDOW - WINDOW_C000) >> 12         ; 0x94
        .equ HALF0_SELECT_C000, (VRAM_HALF0_SELECT - WINDOW_C000) >> 12 ; 0x34
        .equ HALF1_SELECT_C000, (VRAM_HALF1_SELECT - WINDOW_C000) >> 12 ; 0x44
; The same for common area 1 at WINDOW_E000 (the CBAR of the renderer).
        .equ WINDOW_E000, 0xE000
        .equ VGA_WINDOW_E000, (VGA_WINDOW - WINDOW_E000) >> 12         ; 0x92
; When BBR and CBR show the same SRAM page, a label at X in the bank window
; (WINDOW_C000) is also at X + BANK_TO_COMMON in common area 1.
        .equ BANK_TO_COMMON, WINDOW_E000 - WINDOW_C000

        .endif
