; Scene kernel: run the command stream of a packet. Each command is a
; return address with its parameters, popped from SP: a rectangle for a
; latch program, a DMA copy, or a cache upload.

        .include "video.inc"
        .include "rect.inc"

        .global scene_next, scene_end, rect_header, scene_dma, dma_body, cache_blit
        .global cache_upload, cache_latches, scene_transfers, scene_cameras
        .global rect_mask_stream

        .section .vars.scene_kernel,"aw",@nobits
scene_saved_sp: .ds.b 2

        .section .vars.rect_masks,"aw",@nobits
rect_mask_sp: .ds.b 2
rect_mask_stream: .ds.b 2               ; immutable masks of the next rectangle, or 0

        .section .text.scene_kernel,"ax",@progbits

; Run the commands of the active packet. The alternate BC stays on the map
; mask data port.
scene_next:
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        oak_set OAK_WRITE_SEGMENT, 0
        ld (scene_saved_sp),sp
        ld hl,(stream_active_packet)
        ld sp,hl
        exx
        ld bc,VGA_SEQ_DATA
        exx
        ret                             ; to the first command
scene_end:
        ld sp,(scene_saved_sp)
        ret

; Rectangle command after RECT_KERNEL; see rect.inc.
rect_header:
        pop bc
        ld a,c
        out0 (BBR),a                    ; source
        ld a,b
        out0 (CBR),a                    ; destination
        pop bc
        ld d,b                          ; read segment
        ld a,c
        exx
        out (c),a                       ; constant map mask
        exx
        ld bc,OAK_INDEX
        ld a,OAK_READ_SEGMENT
        out (c),a
        inc c
        ld a,d
        out (c),a
        pop hl                          ; source
        pop de                          ; destination
        pop bc                          ; C source row gap, B height
        ld a,b
        exx
        ld d,a                          ; rows
        exx
; The fifth masked group can overlap the next row: the gap is signed.
        ld a,c
        rlca
        sbc a,a
        ld b,a
source_gap_store:
        ld (0),bc                       ; patched: the gap operand of the program
        ld bc,(rect_mask_stream)
        ld a,b
        or c
        jp z,masks_ready                ; the masks follow in the command
        ld (rect_mask_sp),bc
        ld sp,(rect_mask_sp)
masks_ready:
rect_jump:
        jp 0                            ; patched: the row program

; Latch program for a rectangle WIDTH groups wide: OPAQUE 1 writes all
; planes, 0 pops the coverage nibbles of each row. The entry selects the
; row program, then parses the command.
        .macro rect_program width, opaque
        .global rect_\width\()_\opaque, rect_\width\()_\opaque\()_row
        .global rect_\width\()_\opaque\()_source_gap
rect_\width\()_\opaque:
        ld hl,rect_\width\()_\opaque\()_row
        ld (rect_jump+1),hl
        ld hl,rect_\width\()_\opaque\()_source_gap+1
        ld (source_gap_store+2),hl
        jp rect_header
rect_\width\()_\opaque\()_row:
        .set group, 0
        .rept \width
        .if !\opaque
        .set packed, (group / 4) * 4 + 2 < \width
        .if packed && (group % 4 == 0)
        pop bc                          ; four coverage nibbles
        ld a,c
; LDI decrements BC. Keep C above the row width, so B (the second pair)
; cannot borrow.
        ld c,0xFF
        .elseif packed && (group % 4 == 2)
        ld a,b                          ; the second pair
        .elseif group % 2 == 0
        pop af                          ; two coverage nibbles
        .else
        .rept 4
        rrca                            ; the next nibble
        .endr
        .endif
        exx
        out (c),a
        exx
        .endif
        ldi                             ; four pixels
        .set group, group + 1
        .endr
rect_\width\()_\opaque\()_source_gap:
        ld bc,0                         ; patched: the source row gap
        add hl,bc
        ex de,hl
        ld bc,GROUPS_PER_ROW - \width
        add hl,bc
        ex de,hl
        exx
        dec d
        exx
        jp nz,rect_\width\()_\opaque\()_row
        ret                             ; to the next command
        .endm

        .irp width,1,2,3,4,5
        rect_program \width, 1
        .endr
        .irp width,1,2,3,4,5,8
        rect_program \width, 0
        .endr

; DMA command: source, back page destination, groups. Read segment 1.
scene_dma:
        oak_set OAK_READ_SEGMENT, 1
        ld a,0x0F
        exx
        out (c),a
        exx
dma_body:
        pop hl
        pop de
        pop bc
        ld a,l
        out0 (SAR0L),a
        ld a,h
        out0 (SAR0H),a
        ld a,e
        out0 (DAR0L),a
        ld a,d
        out0 (DAR0H),a
        ld a,c
        out0 (BCR0L),a
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        ret

; Cache copy: C read segment, B map mask, then a DMA command.
cache_blit:
        pop bc
        ld d,c
        ld a,b
        exx
        out (c),a
        exx
        ld bc,OAK_INDEX
        ld a,OAK_READ_SEGMENT
        out (c),a
        inc c
        ld a,d
        out (c),a
        jp dma_body

; Cache upload from SRAM: C write segment, B map mask, source, destination,
; byte count.
cache_upload:
        gc_set GC_MODE, 0x40            ; write mode 0
        pop bc
        ld d,c
        ld a,b
        exx
        out (c),a
        exx
        ld bc,OAK_INDEX
        ld a,OAK_WRITE_SEGMENT
        out (c),a
        inc c
        ld a,d
        out (c),a
        pop hl
        pop de
        pop bc
        ld a,l
        out0 (SAR0L),a
        ld a,h
        out0 (SAR0H),a
        ld a,e
        out0 (DAR0L),a
        ld a,d
        out0 (DAR0H),a
        ld a,c
        out0 (BCR0L),a
        ld a,b
        out0 (BCR0H),a
        set_io SAR0B, 0                 ; SRAM
        set_io DAR0B, VGA_WINDOW >> 16
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        ret

; Back to latch copies after the uploads.
cache_latches:
        gc_set GC_MODE, 0x41            ; write mode 1
        oak_set OAK_WRITE_SEGMENT, 0
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        ret

; No transfer or camera records follow in this build.
scene_transfers:
scene_cameras:
