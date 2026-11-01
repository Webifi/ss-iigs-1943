; Firmware mirror switch: give the screen and the card to the Second Sight
; firmware for the Apple II text menu, and get the game back unchanged.
;
; Enter: send SRAM, video RAM, the palette and the selected registers to
; the IIgs, copy the firmware ROM back, then start the firmware. Restore:
; receive it all again and continue the game loop. The IIgs sends the
; bootstrap first, which saves the MMU and receives the enter or restore
; helper into common SRAM.

        .include "video.inc"
        .include "mode_table.inc"

        .global mirror_enter, mirror_boot, mirror_restore, mirror_final, mirror_final_end
        .global mirror_apply_mode

; The helper slot (secondsight.ld .mirror_helper and .mirror_buffer, one
; 4 KB page): the enter or restore helper runs at WINDOW_E000 through
; HELPER_CBR; the IIgs saves the SLOT_BYTES of SRAM of the page first.
        .equ SLOT, mirror_helper__load__phys ; physical SRAM of the helper
        .equ SLOT_BYTES, 0x1000
        .equ HELPER, WINDOW_E000
        .equ HELPER_CBR, mirror_helper__load__cbr
        .equ BUFFER, mirror_buffer__load__phys ; physical SRAM of the palette and registers
        .equ SCRATCH, mirror_buffer__load__ptre ; the same, seen through HELPER_CBR
; BUFFER: the DAC colours, then the selected registers.
        .equ DAC_BYTES, 256 * 3
        .equ SAVED_START_HIGH, DAC_BYTES
        .equ SAVED_START_LOW, DAC_BYTES + 1
        .equ SAVED_EXTENDED_CRTC, DAC_BYTES + 2
        .equ SAVED_READ_SEGMENT, DAC_BYTES + 3
        .equ SAVED_WRITE_SEGMENT, DAC_BYTES + 4
        .equ SAVED_MAP_MASK, DAC_BYTES + 5
        .equ SAVED_GC_MODE, DAC_BYTES + 6
        .equ SAVED_PANNING, DAC_BYTES + 7
        .equ BUFFER_BYTES, DAC_BYTES + 8
; The transfers: 64 KB of SRAM in TRANSFER_CHUNK parts, the two halves of
; video RAM through the linear window.
        .equ TRANSFER_CHUNK, 0x4000
; The firmware MMU stub: in the main text page, which the ROM copy
; (rom_copy) does not write.
        .equ ROM_STUB, FIRMWARE_TEXT_PAGE
        .equ HANDSHAKE_GAP, 0x0800      ; the wait loop count after each transfer
        .equ DCNTL_SEND, 0x08           ; channel 1: memory to the I/O port
        .equ DSTAT_START1, DSTAT_DE1 | DSTAT_KEEP0 | DSTAT_DME
        .equ MIRROR_TOKEN, 0x71         ; to the IIgs: the firmware ROM is back
        .equ MIRROR_STACK_BYTES, 0xE8   ; the stack of the restore helper

; For the IIgs (src/menu_mirror_host.s): the bytes that the bootstrap saves
; (its MIRROR_RETURN_SIZE bytes from mirror_saved), and the token.
        .global mirror_saved, mirror_token
        .equ mirror_token, MIRROR_TOKEN

; In the packet buffer after the bootstrap (scratch for the IIgs).
        .section .vars.mirror,"aw",@nobits
mirror_saved:
saved_sp: .ds.b 2                       ; the SP of the interrupted receive
        .ds.b 2                         ; unused
saved_bbr: .ds.b 1
saved_cbr: .ds.b 1
saved_cbar: .ds.b 1
        .ds.b 1                         ; unused
        .ds.b MIRROR_STACK_BYTES
mirror_stack:                           ; the stack of the restore helper (it grows down)

; Send (RECEIVE 0) or receive (RECEIVE 1) N bytes at physical ADDR through
; DMA channel 1 and the card port, then wait for the handshake gap. A send
; is one byte longer. SYMBOLS 1: ADDR is a link-time symbol.
        .macro transfer addr, receive, n, symbols=0
        set_io MAR1L, (\addr) & 0xFF
        set_io_byte MAR1H, \addr, 8, \symbols
        set_io_byte MAR1B, \addr, 16, \symbols
        set_io IAR1L, CARD_HOST
        set_io IAR1H, 0                 ; the I/O address of the card port
        set_io BCR1L, (\n + 1 - \receive) & 0xFF
        set_io BCR1H, ((\n + 1 - \receive) >> 8) & 0xFF
        .if \receive
        set_io DCNTL, DCNTL_STREAM
        .else
        set_io DCNTL, DCNTL_SEND
        .endif
        set_io DSTAT, DSTAT_START1
        set_io CARD_HOST, 1             ; tell the IIgs: the transfer runs
1:      in0 a,(DSTAT)
        bit DSTAT_DE1_BIT,a
        jp nz,1b
        set_io CARD_HOST, 0
        ld bc,HANDSHAKE_GAP
2:      dec bc
        ld a,b
        or c
        jp nz,2b
        .endm

; The game is unchained and often leaves write mode 1 on. The linear window
; also uses those VGA registers: force the packed chain-4 byte path of the
; firmware before the exact video RAM bytes move.
        .macro linear
        seq_set SEQ_RESET, 1            ; synchronous reset
        oak_set OAK_MODE_SELECT, 4      ; the Oak packed pixel modes
        seq_set SEQ_MEMORY_MODE, 0x0E   ; chain 4
        seq_set SEQ_MAP_MASK, ALL_PLANES
        .irp index,GC_SET_RESET,GC_ENABLE_SET_RESET,GC_DATA_ROTATE
        gc_set \index, 0
        .endr
        gc_set GC_MODE, GC_MODE_256
        gc_set GC_BIT_MASK, 0xFF        ; all bits from the CPU
        seq_set SEQ_RESET, 3            ; run
        set_io LINEAR_WINDOW_ON, 0
        oak_set OAK_MEMORY_MAP, 0x19    ; linear 1 MB
        set_io BBR, HALF0_SELECT_C000
        ld a,(WINDOW_C000)              ; select video RAM half 0
        set_io BBR, game_bbr
        .endm

; Read the 256 DAC colours into SCRATCH, or write them back.
        .macro palette reading
        .if \reading
        ld bc,VGA_DAC_READ_INDEX
        .else
        ld bc,VGA_DAC_WRITE_INDEX
        .endif
        xor a
        out (c),a
        ld bc,VGA_DAC_DATA
        ld hl,SCRATCH
        ld de,DAC_BYTES
1:
        .if \reading
        in a,(c)
        ld (hl),a
        .else
        ld a,(hl)
        out (c),a
        .endif
        inc hl
        dec de
        ld a,d
        or e
        jp nz,1b
        .endm

; Save or restore the registers the game changes: the display start every
; picture, the panning for the HUD.
        .macro selected_registers reading
        indexed_register \reading, SCRATCH+SAVED_START_HIGH, VGA_CRTC_INDEX, CRTC_START_HIGH
        indexed_register \reading, SCRATCH+SAVED_START_LOW, VGA_CRTC_INDEX, CRTC_START_LOW
        indexed_register \reading, SCRATCH+SAVED_EXTENDED_CRTC, OAK_INDEX, OAK_EXTENDED_CRTC
        indexed_register \reading, SCRATCH+SAVED_READ_SEGMENT, OAK_INDEX, OAK_READ_SEGMENT
        indexed_register \reading, SCRATCH+SAVED_WRITE_SEGMENT, OAK_INDEX, OAK_WRITE_SEGMENT
        indexed_register \reading, SCRATCH+SAVED_MAP_MASK, VGA_SEQ_INDEX, SEQ_MAP_MASK
        indexed_register \reading, SCRATCH+SAVED_GC_MODE, VGA_GC_INDEX, GC_MODE
        ld bc,VGA_STATUS                ; reset the attribute flip-flop
        in a,(c)
        ld bc,VGA_ATTR
        ld a,ATTR_PAS | ATTR_PANNING
        out (c),a
        .if \reading
        inc c
        in a,(c)
        ld (SCRATCH+SAVED_PANNING),a
        .else
        ld a,(SCRATCH+SAVED_PANNING)
        out (c),a
        .endif
        .endm

; indexed_register: read the register INDEX behind the index port PORT into
; SLOT (READING 1), or write it from SLOT.
        .macro indexed_register reading, slot, port, index
        ld bc,\port
        ld a,\index
        out (c),a
        inc c
        .if \reading
        in a,(c)
        ld (\slot),a
        .else
        ld a,(\slot)
        out (c),a
        .endif
        .endm

; rom_copy: copy BYTES of the firmware image from the EPROM back into SRAM
; (through SRAM_MIRROR) at START.
        .macro rom_copy start, bytes
        dma_groups EPROM+\start, SRAM_MIRROR+\start, \bytes, 0, 0
1:      in0 a,(DSTAT)
        and DSTAT_DE0
        jp nz,1b
        .endm

        .section .text.mirror_enter,"ax",@progbits

; mirror_enter: the enter helper (secondsight.ld .mirror_enter, at
; HELPER): send SRAM, video RAM, the palette and the selected registers,
; put the firmware back into SRAM, then start the firmware.
mirror_enter:
        di
; Save the display start before the firmware changes it.
        selected_registers 1
        .irp part,0,1,2,3
        transfer SRAM+\part*TRANSFER_CHUNK, 0, TRANSFER_CHUNK
        .endr
        linear
        .irp half,0,1
        transfer VIDEO_WINDOW+\half*TRANSFER_CHUNK, 0, TRANSFER_CHUNK
        .endr
        palette 1
        transfer BUFFER, 0, BUFFER_BYTES, symbols=1
        rom_copy FIRMWARE_VECTORS, FIRMWARE_VECTORS_BYTES
        rom_copy FIRMWARE_HANDLERS, FIRMWARE_HANDLERS_BYTES
        rom_copy FIRMWARE_RENDERERS, FIRMWARE_RENDERERS_BYTES
; A stub in low SRAM restores the ROM MMU and enters the firmware.
        ld hl,rom_stub
        ld de,ROM_STUB
        ld bc,rom_stub_end - rom_stub
        ldir
        set_io CARD_HOST, MIRROR_TOKEN
        ld bc,HANDSHAKE_GAP
1:      dec bc
        ld a,b
        or c
        jp nz,1b
        jp ROM_STUB
; Copied to ROM_STUB: it runs after this helper's CBR is gone.
rom_stub:
        xor a
        out0 (BBR),a
        out0 (CBR),a
        jp 0
rom_stub_end:
mirror_enter_end:


        .section .text.mirror_boot,"ax",@progbits

; mirror_boot: the bootstrap (secondsight.ld .mirror_bootstrap; the menu
; packet carries it, input_menu_receive copies it to its place). Save the
; MMU, send the 4 KB under the helper slot, receive the helper and run it.
        .global mirror_boot_size
        .equ mirror_boot_size, mirror_boot_end - mirror_boot
mirror_boot:
        di
        ld (saved_sp),sp
        in0 a,(BBR)
        ld (saved_bbr),a
        in0 a,(CBR)
        ld (saved_cbr),a
        in0 a,(CBAR)
        ld (saved_cbar),a
        transfer SLOT, 0, SLOT_BYTES, symbols=1
        transfer SLOT, 1, (mirror_enter_end - mirror_enter + 1) & 0xFFFE, symbols=1 ; the enter helper, even
        set_io CBR, HELPER_CBR
        jp HELPER
mirror_boot_end:

        .section .text.mirror_restore,"ax",@progbits

; mirror_restore: the restore helper (secondsight.ld .mirror_restore, at
; HELPER): receive SRAM, video RAM, the palette and the registers again,
; then run mirror_final from the packet buffer.
mirror_restore:
        di
; RunCode must let the IIgs see the zero handshake of the firmware before
; the first receive window.
        ld bc,HANDSHAKE_GAP
1:      dec bc
        ld a,b
        or c
        jp nz,1b
        .irp part,0,1,2,3
        transfer SRAM+\part*TRANSFER_CHUNK, 1, TRANSFER_CHUNK
        .endr
; The stack of the firmware overlaps live common art after the SRAM restore.
        ld sp,mirror_stack
        call mirror_apply_mode
        linear
        .irp half,0,1
        transfer VIDEO_WINDOW+\half*TRANSFER_CHUNK, 1, TRANSFER_CHUNK
        .endr
        call mirror_apply_mode          ; again after the packed writes
        transfer BUFFER, 1, BUFFER_BYTES, symbols=1
        palette 0
        selected_registers 0
; The normal game CPU window; the pages are not shown through it.
        set_io LINEAR_WINDOW_OFF, 0
        oak_set OAK_MEMORY_MAP, 0
        set_io BBR, HALF1_SELECT_C000
        ld a,(WINDOW_C000)              ; select the game video RAM half
        set_io BBR, game_bbr
        ld hl,mirror_final_data
        ld de,mirror_final
        ld bc,mirror_final_end - mirror_final
        ldir
        jp mirror_final
; The restore helper carries the final code (.text.mirror_final) here.
mirror_final_data:

        .section .text.mirror_apply_mode,"ax",@progbits

; mirror_apply_mode: apply the mode table that the entry selected for the
; monitor (mode_table.inc). AF, BC, DE, HL changed.
mirror_apply_mode:
        mode_apply mode, playfield_mode_data
mode_done:
        ret

        .section .text.mirror_final,"ax",@progbits

; mirror_final: runs in the packet buffer (secondsight.ld: run 0x4000): receive
; the 4 KB under the helper slot, restore the MMU and the card stack, then
; continue the game loop in resident code before this packet buffer is
; armed again.
mirror_final:
        transfer SLOT, 1, SLOT_BYTES, symbols=1
        ld a,(saved_cbar)
        out0 (CBAR),a
        ld a,(saved_bbr)
        out0 (BBR),a
        ld a,(saved_cbr)
        out0 (CBR),a
        ld sp,(saved_sp)
        inc sp                          ; drop the return of the interrupted receive
        inc sp
        ld hl,update
        push hl
; The menu packet only controls. In a special, stream_arm_next can be
; patched to paint through the other buffer, which has no helper for this
; packet: run the original first load and continue after it.
        ld a,(stream_receive + 1)
        jp stream_arm_other
mirror_final_end:
