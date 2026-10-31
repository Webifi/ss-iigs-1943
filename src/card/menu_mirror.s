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

        .equ SLOT, 0x1C000              ; physical SRAM of the helper
        .equ BUFFER, 0x1C800            ; physical SRAM of the palette and registers
        .equ SCRATCH, 0xE800            ; the same, seen through CBR 0x0E
        .equ HELPER, 0xE000             ; the helper, through CBR 0x0E
        .equ HELPER_CBR, 0x0E
        .equ BOOT, 0x4000               ; the bootstrap and the final code
        .equ SAVED_SP, 0x4100
        .equ SAVED_BBR, 0x4104
        .equ SAVED_CBR, 0x4105
        .equ SAVED_CBAR, 0x4106
        .equ STACK, 0x41F0              ; a stack in the packet buffer
        .equ ROM_STUB, 0x0400
        .equ HANDSHAKE_GAP, 0x0800
        .equ DCNTL_SEND, 0x08           ; channel 1: memory to the I/O port
        .equ DSTAT_START1, DSTAT_DE1 | DSTAT_KEEP0 | DSTAT_DME
        .equ MIRROR_TOKEN, 0x71         ; to the IIgs: the firmware ROM is back

; Send (RECEIVE 0) or receive (RECEIVE 1) N bytes at physical ADDR through
; DMA channel 1 and the card port, then wait for the handshake gap. A send
; is one byte longer.
        .macro transfer addr, receive, n
        set_io MAR1L, (\addr) & 0xFF
        set_io MAR1H, ((\addr) >> 8) & 0xFF
        set_io MAR1B, ((\addr) >> 16) & 0xFF
        set_io IAR1L, CARD_HOST
        set_io IAR1H, 0
        set_io BCR1L, (\n + 1 - \receive) & 0xFF
        set_io BCR1H, ((\n + 1 - \receive) >> 8) & 0xFF
        .if \receive
        set_io DCNTL, DCNTL_STREAM
        .else
        set_io DCNTL, DCNTL_SEND
        .endif
        set_io DSTAT, DSTAT_START1
        set_io CARD_HOST, 1
1:      in0 a,(DSTAT)
        bit 7,a                         ; DE1
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
        seq_set 0, 1                    ; synchronous reset
        oak_set 0x21, 4
        seq_set SEQ_MEMORY_MODE, 0x0E
        seq_set SEQ_MAP_MASK, 0x0F
        .irp index,GC_SET_RESET,GC_ENABLE_SET_RESET,GC_DATA_ROTATE
        gc_set \index, 0
        .endr
        gc_set GC_MODE, 0x40
        gc_set GC_BIT_MASK, 0xFF
        seq_set 0, 3
        set_io LINEAR_WINDOW_ON, 0
        oak_set OAK_MEMORY_MAP, 0x19
        set_io BBR, 0x34
        ld a,(0xC000)                   ; select video RAM half 0
        set_io BBR, 0x10
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
        ld de,768
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
        indexed_register \reading, SCRATCH+768, VGA_CRTC_INDEX, CRTC_START_HIGH
        indexed_register \reading, SCRATCH+769, VGA_CRTC_INDEX, CRTC_START_LOW
        indexed_register \reading, SCRATCH+770, OAK_INDEX, OAK_EXTENDED_CRTC
        indexed_register \reading, SCRATCH+771, OAK_INDEX, OAK_READ_SEGMENT
        indexed_register \reading, SCRATCH+772, OAK_INDEX, OAK_WRITE_SEGMENT
        indexed_register \reading, SCRATCH+773, VGA_SEQ_INDEX, SEQ_MAP_MASK
        indexed_register \reading, SCRATCH+774, VGA_GC_INDEX, GC_MODE
        ld bc,VGA_STATUS                ; reset the attribute flip-flop
        in a,(c)
        ld bc,VGA_ATTR
        ld a,0x33                       ; panning
        out (c),a
        .if \reading
        inc c
        in a,(c)
        ld (SCRATCH+775),a
        .else
        ld a,(SCRATCH+775)
        out (c),a
        .endif
        .endm

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

; Copy GROUPS bytes of the firmware ROM image from SRAM back to its mirror.
        .macro rom_copy start, groups
        dma_groups 0x60000+\start, 0x20000+\start, \groups, 0, 0
1:      in0 a,(DSTAT)
        and DSTAT_DE0
        jp nz,1b
        .endm

        .section .text.mirror_enter,"ax",@progbits

mirror_enter:
        di
; Save the display start before the firmware changes it.
        selected_registers 1
        .irp bank,0,1,2,3
        transfer \bank*0x4000, 0, 0x4000
        .endr
        linear
        .irp half,0,1
        transfer 0x80000+\half*0x4000, 0, 0x4000
        .endr
        palette 1
        transfer BUFFER, 0, 776
        rom_copy 0x0000, 0x0400
        rom_copy 0x0C00, 0x1400
        rom_copy 0x6000, 0xA000
; A stub in low SRAM restores the ROM MMU and enters the firmware:
; xor a / out0 (BBR),a / out0 (CBR),a / jp 0.
        .set stub, ROM_STUB
        .irp byte,0xAF,0xED,0x39,0x39,0xED,0x39,0x38,0xC3,0x00,0x00
        ld a,\byte
        ld (stub),a
        .set stub, stub + 1
        .endr
        set_io CARD_HOST, MIRROR_TOKEN
        ld bc,HANDSHAKE_GAP
1:      dec bc
        ld a,b
        or c
        jp nz,1b
        jp ROM_STUB
mirror_enter_end:


        .section .text.mirror_boot,"ax",@progbits

; Save the MMU, send the 4 KB under the helper slot, receive the helper and
; run it.
mirror_boot:
        di
        ld (SAVED_SP),sp
        in0 a,(BBR)
        ld (SAVED_BBR),a
        in0 a,(CBR)
        ld (SAVED_CBR),a
        in0 a,(CBAR)
        ld (SAVED_CBAR),a
        transfer SLOT, 0, 4096
        transfer SLOT, 1, (mirror_enter_end - mirror_enter + 1) & 0xFFFE ; the enter helper, even
        set_io CBR, HELPER_CBR
        jp HELPER

        .section .text.mirror_restore,"ax",@progbits

mirror_restore:
        di
; RunCode must let the IIgs see the zero handshake of the firmware before
; the first receive window.
        ld bc,HANDSHAKE_GAP
1:      dec bc
        ld a,b
        or c
        jp nz,1b
        .irp bank,0,1,2,3
        transfer \bank*0x4000, 1, 0x4000
        .endr
; The stack of the firmware overlaps live common art after the SRAM restore.
        ld sp,STACK
        call mirror_apply_mode
        linear
        .irp half,0,1
        transfer 0x80000+\half*0x4000, 1, 0x4000
        .endr
        call mirror_apply_mode          ; again after the packed writes
        transfer BUFFER, 1, 776
        palette 0
        selected_registers 0
; The normal game CPU window; the pages are not shown through it.
        set_io LINEAR_WINDOW_OFF, 0
        oak_set OAK_MEMORY_MAP, 0
        set_io BBR, 0x44
        ld a,(0xC000)                   ; select the game video RAM half
        set_io BBR, 0x10
        ld hl,mirror_final_data
        ld de,BOOT
        ld bc,mirror_final_end - mirror_final
        ldir
        jp BOOT
; The restore helper carries the final code (.text.mirror_final) here.
mirror_final_data:

        .section .text.mirror_apply_mode,"ax",@progbits

; Apply the mode table that the entry selected for the monitor.
mirror_apply_mode:
        mode_apply mode, playfield_mode_data
mode_done:
        ret

        .section .text.mirror_final,"ax",@progbits

; Runs at BOOT: receive the 4 KB under the helper slot, restore the MMU and
; the card stack, then continue the game loop in resident code before the
; packet buffer at BOOT is armed again.
mirror_final:
        transfer SLOT, 1, 4096
        ld a,(SAVED_CBAR)
        out0 (CBAR),a
        ld a,(SAVED_BBR)
        out0 (BBR),a
        ld a,(SAVED_CBR)
        out0 (CBR),a
        ld sp,(SAVED_SP)
        inc sp                          ; drop the return of the interrupted receive
        inc sp
        ld hl,update
        push hl
; The menu packet only controls. In a special, stream_arm_next can be
; patched to paint through the other buffer, which has no helper for this
; packet: run the original first load and continue after it.
        ld a,(stream_receive + 1)
        jp stream_arm_next + 3
mirror_final_end:
