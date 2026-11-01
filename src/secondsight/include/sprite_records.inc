; The sprite position records: the clipping of a sprite at each x and y
; position, built by scripts/state_scene.py (tables). The planner copies
; the record of the sprite position into scene_xrec and scene_yrec.

        .ifndef SPRITE_RECORDS_INC
        .equ SPRITE_RECORDS_INC, 1

        .equ POSITION_RECORD, 8         ; bytes in each record

; The x record (256 records, x 0-255; the sprite is 16 pixels wide).
        .equ XREC_GROUP, 0              ; first group, signed (2 bytes)
        .equ XREC_VISIBLE, 2            ; bit N: group N of the sprite is on the screen
        .equ XREC_CLIPPED, 3            ; 1: part of the sprite is off the screen
        .equ XREC_WIDTH, 4              ; visible groups
        .equ XREC_BLOCKS, 5             ; bit N: the sprite touches groups 8N-8N+7
        .equ XREC_HIDDEN, 6             ; groups off the left edge (2 bytes)

; The y record (512 records: y 0-255, then the extended range).
        .equ YREC_TOP, 0                ; top row, signed (2 bytes)
        .equ YREC_ROWS, 2               ; bit N: row N of the sprite is on the screen (2 bytes)
        .equ YREC_OFFSET, 4             ; top row x GROUPS_PER_ROW (2 bytes)
        .equ YREC_HEIGHT, 6             ; visible rows
        .equ YREC_CLIPPED, 7            ; 1: part of the sprite is off the screen

; The attribute byte of a sprite (the high byte of its packet code word).
        .equ ATTR_PALETTE, 0x0F         ; the palette
        .equ ATTR_Y8, 0x10              ; bit 8 of the y position
        .equ ATTR_CODE_HIGH, 0xE0       ; the high bits of the sprite code
        .equ ATTR_LOW_PALETTE, 0x0E     ; palettes 10 and 11 give LOW_PALETTES
        .equ LOW_PALETTES, 0x0A         ; drawn below the foreground

        .endif
