; Shapes of the shared ship alignments. ship_alignment_view patches each
; operand that holds the pitch when the view changes shape.

        .ifndef SHIP_INC
        .equ SHIP_INC, 1

        .equ SHIP_PITCH, 32             ; groups per alignment row: ships
        .equ SHIP_ROW_MASK, 255
        .equ AIRCRAFT_PITCH, 64         ; groups per alignment row: plane bosses
        .equ AIRCRAFT_ROW_MASK, 127

        .endif
