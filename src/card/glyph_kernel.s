; Fixed-position 8x8 HUD glyphs, drawn without general object staging.

        .include "vga.inc"
        .include "z180.inc"

        .global native_glyph, native_glyph4, native_glyph8, native_glyph_compiled
        .global glyph_compiled_next, glyph_compiled_start, glyph_parameters
        .global glyph_mapped_parameters, glyph_row_jump, native_glyph_done

        .equ GLYPH_GROUPS, 16           ; source groups of one glyph program
        .equ VRAM_CBR, 0x92             ; CBR of video RAM group window 0
        .equ VRAM_APERTURE, 0xE0

        .section .vars.glyph_kernel,"aw",@nobits
glyph_outer_sp:         .ds.w 1
glyph_source:           .ds.w 1
glyph_window:           .ds.w 1         ; source BBR, then Oak read segment
glyph_destination:      .ds.w 1

        .section .vars.compiled_hud,"aw",@nobits
glyph_source_base:      .ds.w 1
glyph_destination_base: .ds.w 1

        .section .text.glyph_kernel,"ax",@progbits

; Entries for glyphs 2, 4 and 8 groups wide: select the latch row program.
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

; Shared glyph-shaped latch programs: each fixed HUD group maps VRAM once.
native_glyph_compiled:
        ld hl,glyph_compiled_start
        ld (glyph_row_jump+1),hl
        jp glyph_parameters
glyph_compiled_next:
        ld hl,(glyph_source_base)
        ld bc,GLYPH_GROUPS
        add hl,bc
        ld de,(glyph_destination_base)
        inc de
        inc de
glyph_compiled_start:
        ld (glyph_source_base),hl
        ld (glyph_destination_base),de
        ret

; Stack in: descriptor BBR, descriptor pointer, physical destination base.
; The descriptor holds: source BBR and read segment, source address, occupied
; row offset, occupied height, then the immutable common mask stream.
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
        pop hl
        add hl,de
        ld a,h
        rrca
        rrca
        rrca
        rrca
        and 0x0F
        add a,VRAM_CBR
        out0 (CBR),a
        ld a,h
        and 0x0F
        or VRAM_APERTURE
        ld h,a
        ld (glyph_destination),hl
        pop bc
        ld a,c
        or a
        jp z,native_glyph_done
        exx
        ld d,a                          ; row count
        exx
        pop hl
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
