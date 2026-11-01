; Scene kernel: run the command stream of a picture. Each command is a
; return address with its parameters, popped from SP: a rectangle for a
; latch program, a cache upload, or another planner command. Each command
; ends with RET to the next one; scene_end ends the stream.

        .include "video.inc"
        .include "rect.inc"

        .global scene_next, scene_end, rect_header
        .global rect_mask_stream

        .section .vars.scene_kernel,"aw",@nobits
scene_saved_sp: .ds.b 2                 ; SP of the caller of scene_next

        .section .vars.rect_masks,"aw",@nobits
rect_mask_sp: .ds.b 2                   ; the mask stream address, for LD SP
rect_mask_stream: .ds.b 2               ; immutable masks of the next rectangle, or 0

        .section .text.scene_kernel,"ax",@progbits

; scene_next: run the command stream at stream_active_packet (the planner
; puts the commands there). The DMA source and destination banks stay in
; the VGA window; the alternate BC stays on the map mask data port.
; scene_end: the last command; it returns to the caller of scene_next.
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

; rect_header: read a rectangle command after its RECT_KERNEL word (see
; rect.inc): map the source (BBR) and the destination (CBR), set the map
; mask and the read segment, then jump to the row program that the entry
; of the rect_program chose. The row registers: HL source, DE destination,
; D' the rows; SP the row masks (in the command, or rect_mask_stream).
rect_header:
        pop bc                          ; RECT_SOURCE_BBR, RECT_CBR
        ld a,c
        out0 (BBR),a                    ; source
        ld a,b
        out0 (CBR),a                    ; destination
        pop bc                          ; RECT_PLANES, RECT_SEGMENT
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

; rect_program: the latch program rect_WIDTH_OPAQUE for a rectangle WIDTH
; groups wide: OPAQUE 1 writes all planes, 0 pops the coverage nibbles of
; each row (the map mask of each group). The entry patches rect_jump and
; source_gap_store for its row program, then reads the command.
; rect_WIDTH_OPAQUE_row: one row; LDI moves the four latched pixels of a
; group (write mode 1). rect_WIDTH_OPAQUE_source_gap: its gap operand.
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

