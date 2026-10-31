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
        .equ LINEAR_WINDOW_ON, 0xAB
        .equ APPLE_IRQ_ASSERT, 0xAC
        .equ APPLE_IRQ_RELEASE, 0xAD

; Physical memory (20-bit Z180 addresses)
        .equ SRAM, 0x00000              ; 128 KB
        .equ SRAM_MIRROR, 0x20000
        .equ VRAM_HALF0_SELECT, 0x40000 ; any access selects video RAM half 0
        .equ VRAM_HALF1_SELECT, 0x50000 ; any access selects video RAM half 1
        .equ VIDEO_WINDOW, 0x80000
        .equ VGA_WINDOW, 0xA0000        ; Oak VGA window while OAK_MEMORY_MAP is 0

        .endif
