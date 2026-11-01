; Glyph kernel: fixed-position 8x8 HUD glyphs and HUD patterns, drawn
; without the general object staging. A glyph is a latch rectangle
; (scene_kernel.s rect_program) from a descriptor in banked SRAM.

        .include "video.inc"

        .global native_glyph, native_glyph4, native_glyph8, native_glyph_compiled
        .global glyph_compiled_start, glyph_parameters
        .global glyph_mapped_parameters, glyph_row_jump, native_glyph_done
        .global glyph_outer_sp

        .section .vars.glyph_kernel,"aw",@nobits
glyph_outer_sp:         .ds.w 1         ; SP of the command stream during a glyph
glyph_source:           .ds.w 1         ; source address of the glyph pixels
glyph_window:           .ds.w 1         ; source BBR, then Oak read segment
glyph_destination:      .ds.w 1         ; destination in the WINDOW_E000 window

        .section .text.glyph_kernel,"ax",@progbits

; native_glyph, native_glyph4, native_glyph8: plan list commands for
; glyphs 2, 4 and 8 groups wide: select the masked latch row program of
; that width, then glyph_parameters reads the command.
        .irp width, 2, 4, 8
        .ifeq \width - 2
native_glyph:
        .else
native_glyph\width:
        .endif
        ld hl,rect_\width\()_0_row
        ld (glyph_row_jump+1),hl
        xor a                           ; contiguous source rows
        ld (rect_\width\()_0_source_gap+1),a
        jp glyph_parameters
        .endr

; native_glyph_compiled: a plan list command for a compiled glyph program
; (scripts/pattern_hud.py): each fixed HUD group maps video RAM once.
; glyph_compiled_start is its row program: the RET takes the first word of
; the mask stream, the address of the compiled program, which ends with a
; jump to native_glyph_done.
native_glyph_compiled:
        ld hl,glyph_compiled_start
        ld (glyph_row_jump+1),hl
        jp glyph_parameters
glyph_compiled_start:
        ret

; glyph_parameters: map the descriptor, then draw it.
; Stack in: descriptor BBR, descriptor pointer, physical destination base.
; glyph_mapped_parameters: the same with the descriptor BBR set, HL the
; descriptor and DE the destination base (hud.s).
; The descriptor holds: source BBR and read segment, source address, occupied
; row offset, occupied height, then the immutable common mask stream.
; The row program runs with SP on the mask stream; native_glyph_done gives
; the command stream back. Out: RET to the next command.
glyph_parameters:
        pop bc
        ld a,c
        out0 (BBR),a
        pop hl
        pop de
glyph_mapped_parameters:
        ld (glyph_outer_sp),sp
        ld sp,hl
        pop bc
        ld (glyph_window),bc
        pop hl
        ld (glyph_source),hl
        pop hl                          ; the occupied row offset
        add hl,de                       ; HL the destination group
        ld a,h
        rrca
        rrca
        rrca
        rrca
        and 0x0F
        add a,VGA_WINDOW_E000           ; the 4K groups of video RAM at WINDOW_E000
        out0 (CBR),a
        ld a,h
        and 0x0F
        or WINDOW_E000 >> 8
        ld h,a
        ld (glyph_destination),hl
        pop bc                          ; C the occupied height
        ld a,c
        or a
        jp z,native_glyph_done          ; an empty glyph
        exx
        ld d,a                          ; row count
        exx
        pop hl                          ; the mask stream
        ld sp,hl
        ld bc,(glyph_window)
        ld a,c
        out0 (BBR),a
        ld d,b
        ld bc,OAK_INDEX
        ld a,OAK_READ_SEGMENT
        out (c),a
        inc c
        ld a,d
        out (c),a
        ld hl,(glyph_source)
        ld de,(glyph_destination)
glyph_row_jump:
        jp 0                            ; patched: selected masked row program
native_glyph_done:
        ld sp,(glyph_outer_sp)
        ret
