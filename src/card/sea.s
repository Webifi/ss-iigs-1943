; Sea occupancy: one byte per world row tells which eight-group intervals of
; the background are fully covered by foreground, so the sea under them can
; be skipped. The map and this code share one SRAM page, which is visible at
; logical $CC00 through BBR 11 and $2000 higher through common area 1.

        .include "z180.inc"

        .global sea_occupancy_dispatch, sea_occupancy_build_banked, sea_occupancy_test
        .global sea_occupancy_d500, sea_occupancy_d500_install, sea_occupancy_access

        .equ COMMON_ALIAS, 0x2000       ; this page seen through common area 1
        .equ OCCUPANCY_BANK, 11
        .equ BORDER_GROUPS, 4
        .equ OP_PUSH_BC, 0xC5
        .equ OP_PUSH_DE, 0xD5
        .equ OP_PUSH_HL, 0xE5
        .equ OP_JP, 0xC3

        .section .text.sea_occupancy,"ax",@progbits

; In: C 0 to build the entry of the current world row, else test the interval
; at scroll_left. A set bit means the interval still shows sea. Test out: A
; nonzero when the interval shows sea.
sea_occupancy_dispatch:
        ld a,c
        or a
        jp nz,sea_occupancy_test
sea_occupancy_build_banked:
        push bc
        push de
        push hl
        ld hl,bg_coverage_buffer+64
        ld e,0
        ld b,8
build_interval:
        ld a,(hl)
        inc hl
        .rept 3
        and (hl)
        inc hl
        .endr
        cp 0xFF
        rr e
        djnz build_interval
        ld a,(rows_world_row)
        ld l,a
        ld h,sea_occupancy_map >> 8
        ld (hl),e
        pop hl
        pop de
        pop bc
        ret

sea_occupancy_test:
        ld a,(scroll_left)
        add a,BORDER_GROUPS
        srl a
        srl a
        srl a
        add a,bit_masks & 0xFF
        ld l,a
        ld h,bit_masks >> 8
        ld b,(hl)
        ld a,(scroll_world_row)
        ld l,a
        ld h,sea_occupancy_map >> 8
        ld a,(hl)
        and b
        ret

; Entry used only for a complete aligned rebuild of the $D500 view. There
; only interval 4 can be fully covered (the build proves this). On the last
; world row it puts the normal entry back.
sea_occupancy_d500:
        push bc
        push de
        push hl
        ld hl,bg_coverage_buffer+80
        ld a,(hl)
        inc hl
        and (hl)
        inc hl
        and (hl)
        inc hl
        and (hl)
        cp 0xFF
        ld e,0xFF
        jr nz,store
        ld e,0xEF
store:
        ld a,(rows_world_row)
        ld l,a
        ld h,sea_occupancy_map >> 8
        ld (hl),e
        cp 0xFF
        jp nz,d500_done
        ld hl,sea_occupancy_build_banked
        ld (hl),OP_PUSH_BC
        inc hl
        ld (hl),OP_PUSH_DE
        inc hl
        ld (hl),OP_PUSH_HL
d500_done:
        pop hl
        pop de
        pop bc
        ret

; Called through common area 1: point the normal entry at the $D500 entry.
sea_occupancy_d500_install:
        ld hl,sea_occupancy_build_banked+COMMON_ALIAS
        ld (hl),OP_JP
        inc hl
        ld de,sea_occupancy_d500
        ld (hl),e
        inc hl
        ld (hl),d
        ret

        .section .text.sea_occupancy_bridge,"ax",@progbits

; Run the occupancy code in its bank. Out: A and the Z flag from the test.
sea_occupancy_access:
        in0 a,(BBR)
        push af
        ld a,OCCUPANCY_BANK
        out0 (BBR),a
        call sea_occupancy_dispatch
        ld b,a
        pop af
        out0 (BBR),a
        ld a,b
        or a
        ret
