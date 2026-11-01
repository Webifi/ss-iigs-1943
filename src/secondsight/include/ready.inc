; The row records (scripts/combined_world.py) and the ready rows (ready_rows,
; READY_ROW_BYTES for each world row; game_coverage_row builds them from the
; row record).

        .ifndef READY_INC
        .equ READY_INC, 1

; A row record: the row kind (rows.inc), the coverage, the water gap (left,
; right), at RECORD_WATER the water span count and SPAN_BYTES for each span,
; then the ship byte and the ship data.
        .equ COVERAGE_BYTES, 32         ; the coverage nibbles of one row
        .equ RECORD_WATER, 1 + COVERAGE_BYTES + 2
        .equ SPAN_BYTES, 3
        .equ SHIP_ALIGNED, 0xFF         ; ship byte: a ship cache layout follows
        .equ SHIP_BYTES, 0x7F           ; ship byte: the bytes of the ship data
        .equ LAYOUT_BYTES, 3            ; a ship cache layout: left, width, directory
; A ready row: the water spans and the ship data of the row record, or one
; of these first bytes.
        .equ READY_ROW_BYTES, 64
        .equ READY_CACHED, 0xFE         ; a ship cache record follows
        .equ READY_SPILL, 0xFF          ; the row did not fit: use the row record
        .equ SPAN_CAPACITY, 0x16        ; water spans that a ready row can hold
        .equ ROW_CAPACITY, 0x41         ; bytes of a ready row, plus one
        .equ CACHE_CAPACITY, 0x3D       ; bytes of a ship cache record that fit
        .equ CACHE_PREFIX, 4            ; READY_CACHED and the layout before them
        .equ COLUMN_HEADER, 7           ; READY_CACHED, the layout, the column pointer

        .endif
