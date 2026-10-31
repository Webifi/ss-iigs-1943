; Opaque cores for moving-layer water repairs.
;
; For each foreground camera row the build finds the widest run of groups that
; stays opaque for the whole 256-row view. Water repair skips that run and
; copies only the strips left and right of it. The directory and records live
; in planes 0-2 of one VRAM allocation; this code lives in plane 3 of the same
; allocation and is copied into the ship staging buffer before it runs.

        .include "vga.inc"
        .include "z180.inc"

        .global repair_core_select, repair_core_copy, repair_core_end
        .global repair_core_registers, repair_core_load

        .equ VIEW_GROUPS, 56            ; visible width in four-pixel groups
        .equ MIN_CORE_GROUPS, 8         ; a narrower core saves no time
        .equ READ_PLANE_COUNT, 2        ; directory plane with the record count

        .section .vars.repair_core,"aw",@nobits
core_left:              .ds.b 1         ; core start, relative to the first visible group
core_right:             .ds.b 1         ; core end, relative to the first visible group
rect_left:              .ds.b 1         ; left group of the rectangle being repaired
left_strip_width:       .ds.b 1
right_strip_offset:     .ds.b 2
right_strip_width:      .ds.b 1

        .section .plane.repair_cores.3.0,"ax",@progbits

; Select the core for the current foreground camera. combined_pointer mapped
; the allocation into BBR and left read map 3; the caller pushed the old BBR.
; Directory planes: record offset low, record offset high, record count.
repair_core_select:
        ld bc,VGA_GC_DATA
        xor a
        out (c),a
        ld a,(scene_fg_camera+1)
        ld e,a
        ld d,0
        ld hl,repair_core_directory
        add hl,de
        ld e,(hl)
        ld a,1
        out (c),a
        ld d,(hl)
        ld a,READ_PLANE_COUNT
        out (c),a
        ld a,(hl)
        push af
        ld hl,repair_core_directory+256
        add hl,de
        ld a,(scene_fg_camera)
        ld d,a
        pop af
        ld e,a
        xor a
        out (c),a

; Each record holds the first camera row it covers; take the last one that
; does not start after the camera.
search:
        ld a,(hl)
        cp d
        jp nc,found_previous
advance:
        inc hl
        dec e
        jp nz,search
        dec hl
        jp found
found_previous:
        jp z,advance
        dec hl
found:
        ld a,1
        out (c),a
        ld d,(hl)
        ld a,READ_PLANE_COUNT
        out (c),a
        ld e,(hl)
        xor a
        out (c),a
        ld a,(bg_first_column)
        ld b,a
        ld a,d
        sub b
        jp c,done
        ld (core_left),a
        ld a,e
        sub b
        jp c,done
        cp VIEW_GROUPS+1
        jp nc,done
        ld (core_right),a
        ld b,a
        ld a,(core_left)
        ld d,a
        ld a,b
        sub d
        cp MIN_CORE_GROUPS
        jp c,done
        ld hl,repair_core_copy
        ld (combined_repair_call+1),hl
done:
        pop af
        out0 (BBR),a
        ret

; Repair one rectangle around the core. In: HL source, DE destination,
; B width, C height. Out: the left and right strips through water_rectangle.
repair_core_copy:
        ; The rectangle's left group is the destination low byte minus the row
        ; start; the difference is 0-55, so low-byte arithmetic is enough.
        push hl
        ld a,(scroll_row)
        ld l,a
        ld h,row_offset_low >> 8
        ld a,(hl)
        ld l,a
        ld a,(scene_screen_base)
        add a,l
        ld l,a
        ld a,e
        sub l
        ld (rect_left),a
        pop hl

        ; D and E hold the destination, so keep them on the stack.
        push de
        ld d,a
        add a,b
        ld e,a
        ld a,(core_left)
        cp d
        jp nc,left_ready
        ld a,d
left_ready:
        ld b,a
        ld a,(core_right)
        cp e
        jp c,right_ready
        ld a,e
right_ready:
        sub b
        jp c,copy_fallback
        cp MIN_CORE_GROUPS
        jp c,copy_fallback
        ld a,b
        sub d
        ld (left_strip_width),a
        ld a,(core_right)
        cp e
        jp c,right_again
        ld a,e
right_again:
        sub d
        ld (right_strip_offset),a
        ld a,e
        sub d
        ld b,a
        ld a,(right_strip_offset)
        ld d,a
        ld a,b
        sub d
        ld (right_strip_width),a
        pop de

        push bc
        push hl
        push de
        ld a,(left_strip_width)
        or a
        jp z,skip_left
        ld b,a
        call water_rectangle
skip_left:
        pop de
        pop hl
        pop bc
        ld a,(right_strip_width)
        or a
        ret z
        push bc
        ld a,(right_strip_offset)
        ld c,a
        ld b,0
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        pop bc
        ld a,(right_strip_width)
        ld b,a
        out0 (DAR0H),d
        jp water_rectangle

copy_fallback:
        ld a,e
        sub d
        ld b,a
        pop de
        jp water_rectangle
repair_core_end:

        .section .text.repair_core_registers,"ax",@progbits

; Select the repair of the moving layer: the opaque core is used only for
; phase 0.
repair_core_registers:
        ld hl,water_rectangle
        ld (combined_repair_call+1),hl
        ld a,(bg_moving_objects)
        or a
        jp z,combined_repair_registers
        ld a,(bg_pan_phase)
        or a
        call z,repair_core_load
        jp combined_repair_registers

; Copy the selector from plane 3 of its video RAM allocation to the ship
; staging buffer, and run it. Saves the BBR of the caller.
repair_core_load:
; An empty foreground edge row rules out an opaque core over the view.
        ld a,(scene_fg_camera)
        ld l,a
        ld h,row_classes >> 8
        ld a,(hl)
        or a
        ret z
        in0 a,(BBR)
        push af
        ld hl,repair_core_pointer
        call combined_pointer
        ld de,repair_core_select
        ld bc,repair_core_end - repair_core_select
        ldir
        jp repair_core_select
repair_core_pointer:
        .word repair_cores__group16
        .byte repair_cores__vseg + (3 << 2) ; segment, read plane 3
