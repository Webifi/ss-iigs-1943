; Shared world pixel rows: equal rows of the map's tiles share one pixel row
; in video RAM. A per-slot table maps each tile row to its shared row.

        .include "vga.inc"
        .include "z180.inc"

        .global shared_rows_cache, world_scatter_rows, world_scatter_row, world_scatter_pair
        .global world_upload_done, world_scatter_table
        .global world_upload_batch, world_upload_next

        .equ RECORD_BYTES, 6            ; per slot in the row table record list
        .equ ROW_POINTERS, 64           ; 32 rows x 2 bytes
        .equ CACHE_BANK, 14             ; BBR of the cached pixel addresses
        .equ CACHE_WINDOW, 0xD000
        .equ VRAM_CBR, 0x92             ; CBR of video RAM group window 0
        .equ VRAM_APERTURE, 0xE0        ; high byte of the 4 KB group window
        .equ GAME_CBR, 0x84
        .equ PALETTE_PAGE, 0x7B         ; pen-to-colour table at $7B60
        .equ PALETTE_LOW, 0x60
        .equ GC_MODE_WRITE1, 0x40       ; write mode 0, packed-pixel read
        .equ GC_MODE_LATCH, 0x41        ; write mode 1: latch copies

; Upload job header, at world_upload_job. The packet has the first 10
; bytes; the receiver uses the rest.
        .equ JOB_KIND, 0
        .equ JOB_CBR, 1                 ; SRAM kinds: the CBR of the destination
        .equ JOB_TABLE_PLANES, 1        ; scattered rows: planes of the slot row table; 0: none
        .equ JOB_PLANES, 2              ; map mask, or the read plane
        .equ JOB_SEGMENT, 3             ; Oak segment
        .equ JOB_TABLE_ADDRESS, 4
        .equ JOB_DESTINATION, 4
        .equ JOB_BYTES, 6               ; scattered rows: two for each row
        .equ JOB_PACKED_BYTES, 8        ; bytes of the packed data in the packet
        .equ JOB_NEXT, 10               ; the next job in the packet
        .equ JOB_END, 12                ; the end of the unpacked data
        .equ JOB_ROW_BYTES, 14          ; prepared rows: the bytes of the row records
        .equ JOB_RUNS, 16
        .equ JOB_RUN_COUNT, 17

; Job kinds. 0 ends the list.
        .equ KIND_SRAM, 2               ; copy into SRAM
        .equ KIND_PALETTE, 3            ; 4-bit pixels through the 16-colour palette to video RAM
        .equ KIND_SRAM_DIRECT, 4        ; unpack directly into SRAM
        .equ KIND_CABINET_PLANE, 5      ; unpack directly into one video RAM plane
        .equ KIND_ROWS, 6               ; expand prepared row runs
        .equ KIND_SCATTER, 7            ; scattered pixel rows (with a palette)

; Job payload, at world_upload_buffer
        .equ BUFFER_ROW_STAGING, 0x60
        .equ BUFFER_ROW_ADDRESSES, 0x80
        .equ BUFFER_DISTINCT_ROWS, 0xC0

        .section .text.world_rows_cache,"ax",@progbits

; Copy the 32 pixel-row addresses of slot world_row_slot from video RAM
; into the cache at CACHE_WINDOW (bank CACHE_BANK).
shared_rows_cache:
        ld a,(world_row_slot)
        ld l,a
        ld h,RECORD_BYTES
        mlt hl
        ld de,world_upload_buffer
        add hl,de
        call combined_pointer
        ld de,world_upload_buffer+BUFFER_ROW_STAGING
        ld bc,ROW_POINTERS
        ldir
        ld a,(world_row_slot)
        ld l,a
        ld h,0
        .rept 6
        add hl,hl
        .endr
        ld de,CACHE_WINDOW
        add hl,de
        ex de,hl
        ld a,CACHE_BANK
        out0 (BBR),a
        ld hl,world_upload_buffer+BUFFER_ROW_STAGING
        ld bc,ROW_POINTERS
        ldir
        ret

        .section .text.world_scatter,"ax",@progbits

; Write the job's packed pixel rows to their shared rows in video RAM.
world_scatter_rows:
        ld a,(world_upload_job+JOB_TABLE_PLANES)
        or a
        call nz,world_scatter_table
        ld bc,VGA_GC_INDEX
        ld a,GC_MODE
        out (c),a
        inc c
        ld a,GC_MODE_WRITE1
        out (c),a
        ld bc,OAK_INDEX
        ld a,OAK_WRITE_SEGMENT
        out (c),a
        inc c
        ld a,(world_upload_job+JOB_SEGMENT)
        out (c),a
        ld bc,VGA_SEQ_INDEX
        ld a,SEQ_MAP_MASK
        out (c),a
        inc c
        ld a,(world_upload_job+JOB_PLANES)
        out (c),a
        ld hl,world_upload_buffer+BUFFER_DISTINCT_ROWS
        ld de,world_upload_buffer
        ld a,(world_upload_job+JOB_BYTES)
        srl a
        ld b,a
world_scatter_row:
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        push bc
        push de
        ld h,a
        rrca
        rrca
        rrca
        rrca
        and 0x0F
        add a,VRAM_CBR
        out0 (CBR),a
        ld a,h
        and 0x0F
        or VRAM_APERTURE
        ld h,a
        ld l,c
        ex de,hl
        pop hl
        ld b,PALETTE_PAGE
        call world_scatter_pair
        call world_scatter_pair
        ex de,hl
        pop bc
        pop hl
        djnz world_scatter_row
        jp world_upload_next

; Two packed pens at (HL) to two colour bytes at (DE).
world_scatter_pair:
        ld a,(hl)
        and 0x0F
        or PALETTE_LOW
        ld c,a
        ld a,(bc)
        ld (de),a
        inc de
        ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and 0x0F
        or PALETTE_LOW
        ld c,a
        ld a,(bc)
        ld (de),a
        inc de
        inc hl
        ret

        .section .text.world_upload_done,"ax",@progbits

world_upload_done:
        ld a,GAME_CBR
        out0 (CBR),a
        ld bc,VGA_GC_INDEX
        ld a,GC_MODE
        out (c),a
        inc c
        ld a,GC_MODE_LATCH
        out (c),a
        ld bc,VGA_SEQ_INDEX
        ld a,SEQ_MAP_MASK
        out (c),a
        inc c
        ld a,0x0F
        out (c),a
        ld bc,OAK_INDEX
        ld a,OAK_WRITE_SEGMENT
        out (c),a
        inc c
        ld a,0
        out (c),a
        ld hl,0xFFFF
        ld (row_roots),hl               ; invalidate the cached column
        ld a,(bg_pan)
        jp game_set_pan

        .section .text.world_scatter_table,"ax",@progbits

; Upload the slot's row table. In: A planes of the slot.
world_scatter_table:
        ld d,a
        ld bc,VGA_GC_INDEX
        ld a,GC_MODE
        out (c),a
        inc c
        ld a,GC_MODE_WRITE1
        out (c),a
        ld bc,OAK_INDEX
        ld a,OAK_WRITE_SEGMENT
        out (c),a
        inc c
        ld a,row_table__vseg
        out (c),a
        ld bc,VGA_SEQ_INDEX
        ld a,SEQ_MAP_MASK
        out (c),a
        inc c
        out (c),d
        ld hl,(world_upload_job+JOB_TABLE_ADDRESS)
        ld a,h
        rrca
        rrca
        rrca
        rrca
        and 0x0F
        add a,VRAM_CBR
        out0 (CBR),a
        ld a,h
        and 0x0F
        or VRAM_APERTURE
        ld h,a
        ex de,hl
        ld hl,world_upload_buffer+BUFFER_ROW_ADDRESSES
        ld bc,ROW_POINTERS
        ldir
        ret

        .section .text.world_upload_batch,"ax",@progbits

; Run the upload jobs of a received batch, before any drawing starts.
; Each job is packed: a byte N < 0x80 copies N + 1 literal bytes; 0x80 + N
; copies N + 3 bytes from the distance in the next word.
; In: HL the first job.
world_upload_batch:
        ld a,(hl)
        or a
        jp z,world_upload_done
        ld de,world_upload_job
        ld bc,JOB_NEXT
        ldir
        ld a,(world_upload_job + JOB_KIND)
        cp KIND_ROWS
        jp nz,upload_palette
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (world_upload_job + JOB_ROW_BYTES),de
        jp upload_source
upload_palette:
        ld a,(world_upload_job + JOB_KIND)
        cp KIND_PALETTE
        jp z,palette_copy
        cp KIND_SCATTER
        jp nz,upload_source
palette_copy:
        ld de,(PALETTE_PAGE << 8) | PALETTE_LOW
        ld bc,16
        ldir
upload_source:
        push hl
        ld de,(world_upload_job + JOB_PACKED_BYTES)
        add hl,de
        ld (world_upload_job + JOB_NEXT),hl
        pop hl
        ld a,(world_upload_job + JOB_KIND)
        cp KIND_CABINET_PLANE
        jp nz,unpack_staging
; A cabinet plane: unpack straight into the plane, segment JOB_SEGMENT.
        push hl
        call game_row_cache_clear
        pop hl
        gc_set GC_MODE, GC_MODE_WRITE1
        .irp index,OAK_READ_SEGMENT,OAK_WRITE_SEGMENT
        ld bc,OAK_INDEX
        ld a,\index
        out (c),a
        inc c
        ld a,(world_upload_job + JOB_SEGMENT)
        out (c),a
        .endr
        ld bc,VGA_GC_INDEX
        ld a,GC_READ_MAP
        out (c),a
        inc c
        ld a,(world_upload_job + JOB_PLANES)
        out (c),a
        ld e,a
        ld a,1
cabinet_mask:
        dec e
        jp m,cabinet_mask_ready
        add a,a
        jp cabinet_mask
cabinet_mask_ready:
        ld d,a                          ; 1 << plane
        ld bc,VGA_SEQ_INDEX
        ld a,SEQ_MAP_MASK
        out (c),a
        inc c
        out (c),d
        jp unpack_direct
unpack_staging:
        ld de,world_upload_buffer
        ld a,(world_upload_job + JOB_KIND)
        cp KIND_SCATTER
        jp nc,unpack_address
        cp KIND_SRAM_DIRECT
        jp c,unpack_address
unpack_direct:
        ld a,(world_upload_job + JOB_CBR)
        out0 (CBR),a
        ld de,(world_upload_job + JOB_DESTINATION)
unpack_address:
        push hl
        ld hl,(world_upload_job + JOB_BYTES)
        add hl,de
        ld (world_upload_job + JOB_END),hl
        pop hl
unpack_token:
        ld a,(hl)
        inc hl
        bit 7,a
        jp nz,unpack_match
        inc a
        ld c,a
        ld b,0
        ldir
        jp unpack_next
unpack_match:
        and 0x7F
        add a,3
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        ld h,d
        ld l,e
        or a
        sbc hl,bc
        ld c,a
        ld b,0
        ldir
        pop hl
unpack_next:
        push hl
        ld hl,(world_upload_job + JOB_END)
        or a
        sbc hl,de
        pop hl
        jp nz,unpack_token
        ld a,(world_upload_job + JOB_KIND)
        cp KIND_ROWS
        jp z,expand_rows
        ld a,(world_upload_job + JOB_KIND)
        cp KIND_SCATTER
        jp nc,world_scatter_rows
        ld a,(world_upload_job + JOB_KIND)
        cp KIND_SRAM_DIRECT
        jp nc,world_upload_next         ; unpacked in place
        ld a,(world_upload_job + JOB_CBR)
        out0 (CBR),a
        ld a,(world_upload_job + JOB_KIND)
        cp KIND_SRAM
        jp z,upload_copy
        gc_set GC_MODE, GC_MODE_WRITE1
        ld bc,OAK_INDEX
        ld a,OAK_WRITE_SEGMENT
        out (c),a
        inc c
        ld a,(world_upload_job + JOB_SEGMENT)
        out (c),a
        ld bc,VGA_SEQ_INDEX
        ld a,SEQ_MAP_MASK
        out (c),a
        inc c
        ld a,(world_upload_job + JOB_PLANES)
        out (c),a
        ld a,(world_upload_job + JOB_KIND)
        cp KIND_PALETTE
        jp nz,upload_copy
; Two pixels from each packed byte, through the palette.
        ld de,(world_upload_job + JOB_DESTINATION)
        ld hl,world_upload_buffer
        ld b,PALETTE_PAGE
upload_pair:
        ld a,(hl)
        and 0x0F
        or PALETTE_LOW
        ld c,a
        ld a,(bc)
        ld (de),a
        inc de
        ld a,(hl)
        .rept 4
        rrca
        .endr
        and 0x0F
        or PALETTE_LOW
        ld c,a
        ld a,(bc)
        ld (de),a
        inc de
        inc l
        ld a,l
        ld c,a
        ld a,(world_upload_job + JOB_BYTES)
        cp c
        jp nz,upload_pair
        jp world_upload_next
upload_copy:
        ld hl,world_upload_buffer
        ld de,(world_upload_job + JOB_DESTINATION)
        ld bc,(world_upload_job + JOB_BYTES)
        ldir
        jp world_upload_next

; Expand the run records of prepared rows, from the end to the start.
; A run is 2 bytes: mask and length high, length low and start.
expand_rows:
        ld hl,(world_upload_job + JOB_DESTINATION)
        ld de,(world_upload_job + JOB_ROW_BYTES)
        add hl,de
        dec hl
        ex de,hl
        ld hl,(world_upload_job + JOB_END)
        dec hl
expand_row:
        ld a,(hl)
        dec hl
        ld (world_upload_job + JOB_RUNS),a
        ld (world_upload_job + JOB_RUN_COUNT),a
        or a
        jp z,expand_count
expand_run:
        ld b,(hl)
        dec hl
        ld c,(hl)
        dec hl
        ld a,b
        .rept 4
        rrca
        .endr
        and 0x0F                        ; mask
        ld (de),a
        dec de
        ld a,b
        and 0x0F                        ; length high bits
        add a,a
        add a,a
        ld b,a
        ld a,c
        rlca
        rlca
        and 3                           ; length low bits
        add a,b
        inc a
        ld b,a                          ; length
        ld a,c
        and 63                          ; start
        add a,b
        ld (de),a                       ; end
        dec de
        ld a,c
        and 63
        ld (de),a                       ; start
        dec de
        ld a,(world_upload_job + JOB_RUNS)
        dec a
        ld (world_upload_job + JOB_RUNS),a
        jp nz,expand_run
expand_count:
        ld a,(world_upload_job + JOB_RUN_COUNT)
        ld (de),a
        dec de
        push de
        push hl
        ld de,(world_upload_job + JOB_DESTINATION)
        or a
        sbc hl,de
        pop hl
        pop de
        jp nc,expand_row
world_upload_next:
        ld hl,(world_upload_job + JOB_NEXT)
        jp world_upload_batch
