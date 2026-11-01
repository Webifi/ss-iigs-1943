; World uploads: the jobs that the host sends in packets (world_job.inc),
; and the shared world pixel rows: equal rows of the map's tiles share one
; pixel row in video RAM. A per-slot table maps each tile row to its shared
; row.

        .include "video.inc"
        .include "world_job.inc"

        .global shared_rows_cache, world_scatter_rows, world_scatter_row, world_scatter_pair
        .global world_upload_done, world_scatter_table
        .global world_upload_batch, world_upload_next
        .global KIND_SRAM_DIRECT        ; the IIgs builds these jobs (src/host_jobs.inc)
        .global world_upload_job, world_palette, world_upload_buffer, cached_row_addresses

        .equ RECORD_BYTES, 6            ; per slot in the row table record list
        .equ ROW_POINTERS, 64           ; 32 rows x 2 bytes
        .equ SLOTS, 16                  ; world slots of the row address cache
        .equ PALETTE_BYTES, 16          ; world_palette: one colour for each pen
        .equ RUN_START, 63              ; a prepared run: the start group bits

; Job payload, at world_upload_buffer
        .equ BUFFER_ROW_STAGING, 0x60
        .equ BUFFER_ROW_ADDRESSES, 0x80 ; scripts/world_rows.py writes these
        .equ BUFFER_DISTINCT_ROWS, 0xC0
        .equ BUFFER_BYTES, 0x100

; The job of the batch: the JOB_NEXT bytes of its header, then the
; receiver's fields.
        .section .vars.world_upload_job,"aw",@nobits
world_upload_job: .ds.b JOB_RUN_COUNT + 1
; The pen-to-colour table of KIND_PALETTE and KIND_SCATTER: a PALETTE_BYTES
; record in one 256-byte page, so the pen ORs into the low byte.
        .section .vars.world_palette,"aw",@nobits
        .balign PALETTE_BYTES
world_palette: .ds.b PALETTE_BYTES
; The unpacked job data (secondsight.ld .scratch): one 256-byte page,
; stepped with INC L.
        .section .vars.world_upload_buffer,"aw",@nobits
        .balign 256
world_upload_buffer: .ds.b BUFFER_BYTES
; The 32 pixel row addresses of each world slot (secondsight.ld
; .row_address_cache), read through the upper half of the bank area.
        .section .vars.row_address_cache,"aw",@nobits
cached_row_addresses: .ds.b ROW_POINTERS * SLOTS

        .section .text.world_rows_cache,"ax",@progbits

; shared_rows_cache: copy the 32 pixel-row addresses of slot world_row_slot
; from video RAM into cached_row_addresses. AF, BC, DE, HL changed.
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
        add hl,hl                       ; x ROW_POINTERS
        .endr
        ld de,cached_row_addresses__ptrd
        add hl,de
        ex de,hl
        ld a,cached_row_addresses__bbrd
        out0 (BBR),a
        ld hl,world_upload_buffer+BUFFER_ROW_STAGING
        ld bc,ROW_POINTERS
        ldir
        ret

        .section .text.world_scatter,"ax",@progbits

; world_scatter_rows: write the job's packed pixel rows (two pens a byte,
; through world_palette) to their shared rows in video RAM.
; world_scatter_row: one row. Then the next job.
world_scatter_rows:
        ld a,(world_upload_job+JOB_TABLE_PLANES)
        or a
        call nz,world_scatter_table
        ld bc,VGA_GC_INDEX
        ld a,GC_MODE
        out (c),a
        inc c
        ld a,GC_MODE_256                ; write mode 0: CPU bytes
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
        add a,VGA_WINDOW_E000
        out0 (CBR),a
        ld a,h
        and 0x0F
        or WINDOW_E000 >> 8
        ld h,a
        ld l,c
        ex de,hl
        pop hl
        ld b,world_palette >> 8
        call world_scatter_pair
        call world_scatter_pair
        ex de,hl
        pop bc
        pop hl
        djnz world_scatter_row
        jp world_upload_next

; world_scatter_pair: two packed pens at (HL) to two colour bytes at (DE).
; In: B the world_palette page. HL and DE move on; AF, C changed.
world_scatter_pair:
        ld a,(hl)
        and 0x0F
        or world_palette & 0xFF
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
        or world_palette & 0xFF
        ld c,a
        ld a,(bc)
        ld (de),a
        inc de
        inc hl
        ret

        .section .text.world_upload_done,"ax",@progbits

; world_upload_done: the end of a batch: the CBR, the latch copy mode, all
; planes and write segment 0 again, then the pan (game_set_pan).
world_upload_done:
        ld a,game_cbr
        out0 (CBR),a
        ld bc,VGA_GC_INDEX
        ld a,GC_MODE
        out (c),a
        inc c
        ld a,GC_MODE_256 | 1            ; write mode 1: latch copies
        out (c),a
        ld bc,VGA_SEQ_INDEX
        ld a,SEQ_MAP_MASK
        out (c),a
        inc c
        ld a,ALL_PLANES
        out (c),a
        ld bc,OAK_INDEX
        ld a,OAK_WRITE_SEGMENT
        out (c),a
        inc c
        ld a,0
        out (c),a
        ld a,(bg_pan)
        jp game_set_pan

        .section .text.world_scatter_table,"ax",@progbits

; world_scatter_table: upload the slot's row table (the row addresses of
; the job, in row_table). In: A planes of the slot. AF, BC, DE, HL changed.
world_scatter_table:
        ld d,a
        ld bc,VGA_GC_INDEX
        ld a,GC_MODE
        out (c),a
        inc c
        ld a,GC_MODE_256                ; write mode 0: CPU bytes
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
        add a,VGA_WINDOW_E000
        out0 (CBR),a
        ld a,h
        and 0x0F
        or WINDOW_E000 >> 8
        ld h,a
        ex de,hl
        ld hl,world_upload_buffer+BUFFER_ROW_ADDRESSES
        ld bc,ROW_POINTERS
        ldir
        ret

        .section .text.world_upload_batch,"ax",@progbits

; world_upload_batch: run the upload jobs of a received batch, before any
; drawing starts. Each job is packed: a byte N < 0x80 copies N + 1 literal
; bytes; 0x80 + N copies N + 3 bytes from the distance in the next word.
; world_upload_next: the next job. In: HL the first job; a 0 kind ends the
; batch (world_upload_done). AF, BC, DE, HL changed.
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
        ld de,world_palette
        ld bc,PALETTE_BYTES
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
        gc_set GC_MODE, GC_MODE_256
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
        gc_set GC_MODE, GC_MODE_256
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
        ld b,world_palette >> 8
upload_pair:
        ld a,(hl)
        and 0x0F
        or world_palette & 0xFF
        ld c,a
        ld a,(bc)
        ld (de),a
        inc de
        ld a,(hl)
        .rept 4
        rrca
        .endr
        and 0x0F
        or world_palette & 0xFF
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

; expand_rows: expand the run records of prepared rows, from the end to the
; start. A run is 2 bytes: mask and length high, length low and start; it
; expands to 3 bytes: start, end, mask.
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
        and RUN_START                   ; start
        add a,b
        ld (de),a                       ; end
        dec de
        ld a,c
        and RUN_START
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
