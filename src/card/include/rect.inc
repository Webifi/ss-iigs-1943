; Rectangle command: the latch programs rect_N_0 and rect_N_1 pop it from
; SP. N is the width in groups; _1 is opaque, _0 uses the row masks.

        .ifndef RECT_INC
        .equ RECT_INC, 1

        .equ RECT_KERNEL, 0             ; latch program
        .equ RECT_SOURCE_BBR, 2
        .equ RECT_CBR, 3                ; destination CBR
        .equ RECT_PLANES, 4             ; constant map mask; 0: the row masks follow
        .equ RECT_SEGMENT, 5            ; Oak read segment
        .equ RECT_SOURCE, 6
        .equ RECT_DESTINATION, 8
        .equ RECT_SOURCE_GAP, 10        ; signed
        .equ RECT_HEIGHT, 11
        .equ RECT_MASKS, 12             ; coverage nibbles of each row

        .endif
