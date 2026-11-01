; Opaque cores for moving-layer water repairs.
;
; For each foreground camera row the build finds the widest run of groups that
; stays opaque for the whole 256-row view. Water repair skips that run and
; copies only the strips left and right of it. The directory and records live
; in planes 0-2 of one VRAM allocation; this code lives in plane 3 of the same
; allocation and is copied into the ship staging buffer before it runs.

        .include "video.inc"

        .global repair_core_select, repair_core_copy, repair_core_end
        .global repair_core_registers, repair_core_load

        .equ MIN_CORE_GROUPS, 8         ; a narrower core saves no time
; The read planes (GC_READ_MAP) of the data. The directory: one entry for
; each camera high byte; plane 0 and 1 the record offset, plane 2 the
; record count. A record: plane 0 the first camera row (low byte), plane 1
; the core start, plane 2 the core end. Plane 3 holds this code. XOR A
; selects plane 0.
        .equ PLANE_OFFSET_HIGH, 1
        .equ PLANE_COUNT, 2
        .equ PLANE_CORE_LEFT, 1
        .equ PLANE_CORE_RIGHT, 2
        .equ PLANE_CODE, 3
        .equ DIRECTORY_SIZE, 256        ; the records follow the directory
        .equ POINTER_PLANE_SHIFT, 2     ; combined_pointer: the read plane in bits 3-2

        .section .vars.repair_core,"aw",@nobits
core_left:              .ds.b 1         ; core start, relative to the first visible group
core_right:             .ds.b 1         ; core end, relative to the first visible group
left_strip_width:       .ds.b 1         ; groups of the strip left of the core
right_strip_offset:     .ds.b 2         ; groups from the rectangle start to the right strip
right_strip_width:      .ds.b 1         ; groups of the strip right of the core

        .section .plane.repair_cores.3.0,"ax",@progbits

; repair_core_select: select the core for the current foreground camera.
; combined_pointer mapped the allocation into BBR and left read map 3 (the
; GC index stays on GC_READ_MAP); the caller pushed the old BBR. With a
; core of MIN_CORE_GROUPS or more, combined_repair_call goes to
; repair_core_copy. Out: the BBR of the caller. AF, BC, DE, HL changed.
repair_core_select:
        ld bc,VGA_GC_DATA
        xor a                           ; plane 0: the record offset low byte
        out (c),a
        ld a,(scene_fg_camera+1)
        ld e,a
        ld d,0
        ld hl,repair_core_directory
        add hl,de
        ld e,(hl)
        ld a,PLANE_OFFSET_HIGH
        out (c),a
        ld d,(hl)
        ld a,PLANE_COUNT
        out (c),a
        ld a,(hl)
        push af
        ld hl,repair_core_directory+DIRECTORY_SIZE
        add hl,de
        ld a,(scene_fg_camera)
        ld d,a                          ; D the camera row
        pop af
        ld e,a                          ; E the record count
        xor a                           ; plane 0: the first camera row
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
        ld a,PLANE_CORE_LEFT
        out (c),a
        ld d,(hl)
        ld a,PLANE_CORE_RIGHT
        out (c),a
        ld e,(hl)
        xor a                           ; plane 0: the first camera row
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
        cp GROUPS_PER_ROW+1
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

; repair_core_copy: repair one rectangle around the core (it replaces
; water_rectangle at combined_repair_call). In: HL source, DE destination,
; B width, C height. Out: the left and right strips through water_rectangle;
; a rectangle that holds less than MIN_CORE_GROUPS of the core is copied
; whole. AF, BC, DE, HL changed.
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

; repair_core_registers: select the repair of the moving layer, then set
; the repair registers (combined_repair_registers). The opaque core is used
; only for pan phase 0.
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

; repair_core_load: copy the selector from plane 3 of its video RAM
; allocation to the ship staging buffer, and run it. Saves the BBR of the
; caller. repair_core_pointer: the allocation as a combined_pointer record.
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
        .byte repair_cores__vseg + (PLANE_CODE << POINTER_PLANE_SHIFT) ; segment, read plane
