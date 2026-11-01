; Shapes of the shared ship alignments. ship_alignment_view patches each
; operand that holds the pitch when the view changes shape.

        .ifndef SHIP_INC
        .equ SHIP_INC, 1

        .equ SHIP_PITCH, 32             ; groups per alignment row: ships
        .equ SHIP_ROW_MASK, 255
        .equ AIRCRAFT_PITCH, 64         ; groups per alignment row: plane bosses
        .equ AIRCRAFT_ROW_MASK, 127
        .equ AUXILIARY, 0x80            ; source flag: read the alignment, not the clean twin
        .equ SHIFT_GROUPS, 3            ; the shifted alignments start 3 groups left of the layout
        .equ MIN_CPU_HEIGHT, 4          ; ship_cpu_copy takes rectangles of this height or more
        .equ MAX_CPU_WIDTH, 3           ; and less than this width

        .endif
