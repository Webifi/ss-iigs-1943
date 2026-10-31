; Restore saved rectangles and the fixed HUD from the clean page.

        .include "vga.inc"
        .include "z180.inc"

        .global restore_begin, restore_1, restore_2, restore_3, restore_4, restore_5
        .global restore_parameters, restore_jump, hud_restore, hud_restore_run, hud_restore_done

        .equ SCREEN_PITCH, 56
        .equ VRAM_CBR, 0x92             ; CBR of video RAM group window 0
        .equ CLEAN_BBR, 0x94            ; BBR of the clean page window 0
        .equ SOURCE_WINDOW, 0xC0
        .equ DESTINATION_WINDOW, 0x20   ; added to SOURCE_WINDOW: $E000
        .equ CLEAN_PAGE_MASK, 0x7F

        .section .vars.restore_kernel,"aw",@nobits
hud_old_base:           .ds.w 1         ; old HUD base, including the display page
hud_outer_sp:           .ds.w 1

        .section .text.restore_kernel,"ax",@progbits

; Latch copies: read segment 1, all planes (alternate BC is the map mask port).
restore_begin:
        ld bc,OAK_INDEX
        ld a,OAK_READ_SEGMENT
        out (c),a
        inc c
        ld a,1
        out (c),a
        ld a,0x0F
        exx
        out (c),a
        exx
        ret

; Entries for rectangles 1-5 groups wide: select the latch row program.
        .irp width, 1, 2, 3, 4, 5
restore_\width:
        ld hl,rect_\width\()_1_row
        ld (restore_jump+1),hl
        ld a,SCREEN_PITCH - \width
        ld (rect_\width\()_1_source_gap+1),a
        jp restore_parameters
        .endr

; Stack in: physical destination group, clipped height.
restore_parameters:
        pop hl
        pop bc
        ld a,c
        exx
        ld d,a
        exx
        ld a,h
        rrca
        rrca
        rrca
        rrca
        and 0x0F
        add a,VRAM_CBR
        out0 (CBR),a
        ld a,h
        rrca
        rrca
        rrca
        rrca
        and 0x07
        add a,CLEAN_BBR
        out0 (BBR),a
        ld a,h
        and 0x0F
        or SOURCE_WINDOW
        ld h,a
        or DESTINATION_WINDOW
        ld d,a
        ld e,l
restore_jump:
        jp 0                            ; patched: selected row program

; The run shape is immutable; only the old back-page base travels in the
; update packet. DMA uses physical VRAM addresses, so mapping the geometry
; into BBR does not disturb the copy.
; Stack in: geometry BBR, geometry pointer, old HUD base.
hud_restore:
        pop bc
        ld a,c
        out0 (BBR),a
        pop hl
        pop de
        ld (hud_old_base),de
        ld (hud_outer_sp),sp
        ld sp,hl
        ld bc,OAK_INDEX
        ld a,OAK_READ_SEGMENT
        out (c),a
        inc c
        ld a,1
        out (c),a
        ld a,0x0F
        exx
        out (c),a
        exx
hud_restore_run:
        pop hl                          ; group offset
        pop bc                          ; run length; 0 ends the list
        ld a,c
        or b
        jp z,hud_restore_done
        ld a,b
        out0 (BCR0H),a
        ld a,c
        out0 (BCR0L),a
        ld de,(hud_old_base)
        add hl,de
        ld a,l
        out0 (DAR0L),a
        out0 (SAR0L),a
        ld a,h
        out0 (DAR0H),a
        and CLEAN_PAGE_MASK
        out0 (SAR0H),a
        ld a,DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        out0 (DSTAT),a
        jp hud_restore_run
hud_restore_done:
        ld a,0
        out0 (BCR0H),a
        ld sp,(hud_outer_sp)
        ret
