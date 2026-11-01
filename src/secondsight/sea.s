; Sea occupancy: one byte per world row tells which eight-group intervals of
; the background are fully covered by foreground, so the sea under them can
; be skipped. The map and this code share one SRAM page (secondsight.ld
; .sea_occupancy), which is visible at logical $CC00 through BBR in the bank
; window and BANK_TO_COMMON higher through common area 1.

        .include "second_sight.inc"
        .include "z180.inc"

        .global sea_occupancy_dispatch, sea_occupancy_build_banked, sea_occupancy_test
        .global sea_occupancy_d500, sea_occupancy_d500_install, sea_occupancy_access
        .global sea_occupancy_map

        .equ INTERVALS, 8               ; eight-group intervals of a row: one bit each
        .equ INTERVAL_BYTES, 4          ; bg_coverage_row bytes of an interval
        .equ BORDER_GROUPS, 4           ; scroll_left counts from the left border
        .equ COVERED, 0xFF              ; an AND of the coverage bytes: all pixels covered
        .equ D500_INTERVAL, 4           ; the only interval that the $D500 view can cover

; The map: bit N of the byte of a world row is 1 while interval N shows sea.
; It starts with all bits 1 (no row is known to be covered). The code reads
; it with H the page and L the world row: it stays in one 256-byte page.
        .section .data.sea_occupancy_map,"aw",@progbits
        .balign 256
sea_occupancy_map:
        .fill 256, 1, 0xFF

; bit_masks: 1 << N for each interval N (sea_occupancy_test). It stays in
; one 256-byte page (aligned to its size): the code adds the low byte.
        .global bit_masks
        .section .data.bit_masks,"aw",@progbits
        .balign 8
bit_masks:
        .byte 1, 2, 4, 8, 16, 32, 64, 128

        .section .text.sea_occupancy,"ax",@progbits

; sea_occupancy_dispatch: build or test an entry of the map (through
; sea_occupancy_access, in the bank).
; In: C 0 to build the entry of rows_world_row from bg_coverage_row, else
; test the interval at scroll_left of scroll_world_row. Test out: A nonzero
; when the interval shows sea. AF, B, HL changed by the test.
; sea_occupancy_build_banked: the build; its first three bytes change while
; sea_occupancy_d500 runs (a jump there, then PUSH BC, PUSH DE, PUSH HL).
sea_occupancy_dispatch:
        ld a,c
        or a
        jp nz,sea_occupancy_test
sea_occupancy_build_banked:
        push bc
        push de
        push hl
        ld hl,bg_coverage_row
        ld e,0
        ld b,INTERVALS
build_interval:
        ld a,(hl)
        inc hl
        .rept INTERVAL_BYTES - 1
        and (hl)
        inc hl
        .endr
        cp COVERED                      ; carry: some pixel shows sea
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

; sea_occupancy_test: A = the map bits of scroll_world_row AND the bit of
; the interval at scroll_left (bit_masks: 1 << N).
sea_occupancy_test:
        ld a,(scroll_left)
        add a,BORDER_GROUPS
        srl a
        srl a
        srl a                           ; the interval
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

; sea_occupancy_d500: the build entry only for a complete aligned rebuild of
; the $D500 view. There only interval D500_INTERVAL can be fully covered (the
; build proves this). On the last world row it puts the normal entry back.
sea_occupancy_d500:
        push bc
        push de
        push hl
        ld hl,bg_coverage_row + D500_INTERVAL * INTERVAL_BYTES
        ld a,(hl)
        inc hl
        and (hl)
        inc hl
        and (hl)
        inc hl
        and (hl)
        cp COVERED
        ld e,0xFF                       ; all intervals show sea
        jr nz,store
        ld e,~(1 << D500_INTERVAL) & 0xFF ; interval 4 is covered
store:
        ld a,(rows_world_row)
        ld l,a
        ld h,sea_occupancy_map >> 8
        ld (hl),e
        cp 0xFF                         ; the last world row of the rebuild
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

; sea_occupancy_d500_install: point the normal build entry at
; sea_occupancy_d500. It runs through common area 1 (the caller sets CBR),
; so it writes the code at its BANK_TO_COMMON address. DE, HL changed.
sea_occupancy_d500_install:
        ld hl,sea_occupancy_build_banked+BANK_TO_COMMON
        ld (hl),OP_JP
        inc hl
        ld de,sea_occupancy_d500
        ld (hl),e
        inc hl
        ld (hl),d
        ret

        .section .text.sea_occupancy_bridge,"ax",@progbits

; sea_occupancy_access: run sea_occupancy_dispatch in its bank (BBR), then
; put the BBR back. In: C as sea_occupancy_dispatch. Out: A and the Z flag
; from the test. B changed.
sea_occupancy_access:
        in0 a,(BBR)
        push af
        ld a,sea_occupancy__load__bbr
        out0 (BBR),a
        call sea_occupancy_dispatch
        ld b,a
        pop af
        out0 (BBR),a
        ld a,b
        or a
        ret
