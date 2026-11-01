; The row classes (row_classes, one byte for each ring row): the row kind
; of the prepared coverage (scripts/combined_world.py).

        .ifndef ROWS_INC
        .equ ROWS_INC, 1

        .equ ROW_EMPTY, 0               ; no foreground pixel
        .equ ROW_PARTIAL, 1             ; some foreground pixels
        .equ ROW_OPAQUE, 2              ; all 256 pixels opaque
        .equ ROW_OPAQUE_VIEW, 6         ; test mask: the foreground covers the view
        .equ ROW_SHIP_CACHE, 3          ; bit: the row has a ship layout (ship cache)
        .equ ROW_SHIP_COLUMN, 0x10      ; the column has ship column programs
        .equ ROW_SHIP_COLUMN_BIT, 4

        .endif
