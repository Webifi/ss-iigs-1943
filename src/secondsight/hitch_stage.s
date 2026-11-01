; Staged $D500 picture: the host sends this helper and its compressed blocks
; in packets. The helper runs from whichever receive buffer got it, so it is
; assembled for both buffers. Each block expands through the world upload
; path into the other buffer, then its rows are copied to the display.

        .include "video.inc"
        .include "world_job.inc"
        .include "stream.inc"
        .include "hitch.inc"

        .global hitch_stage_draw_buffer1, hitch_stage_draw_buffer0

        .equ FIRST_PLANE_MASK, 1        ; SEQ_MAP_MASK of plane 0

        .section .vars.hitch_stage,"aw",@nobits
block_fragments:        .ds.b 1         ; compressed spans of each plane of the block
block_plane:            .ds.b 1         ; the plane that the spans are read from
block_count:            .ds.b 1         ; spans left in this plane

; The helper shares the hitch scratch words with the scene helper.
        .equ block_pointer, hitch_twin
        .equ block_cursor, hitch_copy_source
        .equ block_end, hitch_copy_dest

; hitch_stage_draw: the helper for one receive buffer (secondsight.ld
; .hitch_stage_draw_0 and _1). OUTPUT: the other buffer, which takes
; the expanded rows. TABLE: the block table of this copy. INPUT: the end of
; this copy (its region limit): a block is gathered there as a world upload
; job (world_job.inc), the job header first.
; The block table: for each block the JOB_NEXT header bytes, the span count
; of each plane, then for each plane its spans (BBR, Oak segment, source,
; byte count); a 0 byte ends the table. Out: hitch_ready STATE_CONSUMED.
        .macro hitch_stage_draw output, table, input
        .equ input\@, \input
        in0 a,(CBR)
        push af
        in0 a,(BBR)
        push af
        set_io BBR, background_full__load__bbr ; background_water_view is banked
        call background_water_view
        ld hl,\table
        ld (block_pointer),hl
        xor a
        ld (scroll_row),a
begin\@:
        ld hl,(block_pointer)
        ld de,input\@
        ld bc,JOB_NEXT                  ; the header bytes that a packet carries
        ldir
        ld a,(hl)
        inc hl
        ld (block_fragments),a
        ld (block_cursor),hl
        ld de,input\@ + JOB_NEXT
        xor a
        ld (block_plane),a
plane\@:
        ld bc,VGA_GC_INDEX
        ld a,GC_READ_MAP
        out (c),a
        inc c
        ld a,(block_plane)
        out (c),a
        ld hl,(block_cursor)
        ld a,(block_fragments)
        ld (block_count),a
chunk\@:
        ld a,(hl)                       ; BBR of the compressed span
        inc hl
        out0 (BBR),a
        ld a,(hl)                       ; Oak read segment
        inc hl
        push de
        push hl
        ld d,a
        ld bc,OAK_INDEX
        ld a,OAK_READ_SEGMENT
        out (c),a
        inc c
        out (c),d
        pop hl
        pop de
        ld c,(hl)                       ; source
        inc hl
        ld b,(hl)
        inc hl
        push bc
        ld c,(hl)                       ; count
        inc hl
        ld b,(hl)
        inc hl
        ex (sp),hl
        ldir
        pop hl
        ld a,(block_count)
        dec a
        ld (block_count),a
        jp nz,chunk\@
        ld a,(block_plane)
        inc a
        ld (block_plane),a
        cp VGA_PLANES
        jp nz,plane\@
        ld (block_pointer),hl
        xor a                           ; end marker
        ld (de),a
        ld hl,input\@
        call world_upload_batch
        ; The world upload left the expanded block at OUTPUT and may change mappings.
        ld hl,(input\@ + JOB_BYTES)     ; the expanded length
        ld de,\output
        add hl,de
        ld (block_end),hl
        ld hl,\output
        ld (scroll_src),hl
        oak_set OAK_WRITE_SEGMENT, 0
        gc_set GC_MODE, GC_MODE_256
; Each expanded row: left group, length in groups, then the pixels of the
; four planes interleaved (one byte a pixel).
row\@:
        ld hl,(scroll_src)
        ld de,(block_end)
        or a
        sbc hl,de
        jp z,done\@
        ld hl,(scroll_src)
        ld a,(hl)                       ; left
        ld (scroll_x),a
        inc hl
        ld a,(hl)                       ; length
        ld (scroll_length),a
        inc hl
        ld (scroll_src),hl
        or a
        jp z,next_row\@
        ld a,(scroll_row)
        ld l,a
        ld h,0
        call state_times56
        ld de,(scene_screen_base)
        add hl,de
        ld a,(scroll_x)
        ld e,a
        ld d,0
        add hl,de
        ld (scroll_dest),hl
        ld a,h
        rrca
        rrca
        rrca
        rrca
        and 0x0F
        add a,VGA_WINDOW_E000
        out0 (CBR),a
        ld hl,(scroll_dest)
        ld a,h
        and 0x0F
        or WINDOW_E000 >> 8
        ld h,a
        ld (scroll_dest),hl
        ld a,FIRST_PLANE_MASK
        ld (scroll_segment),a           ; the plane mask
        xor a                           ; lane
        ld (scroll_x),a
copy_plane\@:
        ld bc,VGA_SEQ_DATA
        ld a,(scroll_segment)
        out (c),a
        ld hl,(scroll_src)
        ld a,(scroll_x)
        ld e,a
        ld d,0
        add hl,de
        ld de,(scroll_dest)
        ld a,(scroll_length)
        ld b,a
copy_pixel\@:
        ld a,(hl)
        ld (de),a
        inc de
        .rept 4
        inc hl
        .endr
        djnz copy_pixel\@
        ld a,(scroll_segment)
        add a,a
        ld (scroll_segment),a
        ld a,(scroll_x)
        inc a
        ld (scroll_x),a
        cp VGA_PLANES
        jp nz,copy_plane\@
        ld a,(scroll_length)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,(scroll_src)
        add hl,de
        ld (scroll_src),hl
next_row\@:
        ld a,(scroll_row)
        inc a
        ld (scroll_row),a
        jp row\@
done\@:
        ld hl,(block_pointer)
        ld a,(hl)
        or a
        jp nz,begin\@
        ; Restore BBR and CBR, then copy the visible view to its clean twin.
        pop af
        out0 (BBR),a
        pop af
        out0 (CBR),a
        oak_set OAK_READ_SEGMENT, 0
        oak_set OAK_WRITE_SEGMENT, 0
        seq_set SEQ_MAP_MASK, ALL_PLANES
        gc_set GC_MODE, GC_MODE_256 | 1
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        ld hl,(scene_screen_base)
        ld de,TWIN_DISTANCE
        add hl,de
        ex de,hl
        ld hl,(scene_screen_base)
        ld a,l
        out0 (SAR0L),a
        ld a,h
        out0 (SAR0H),a
        ld a,e
        out0 (DAR0L),a
        ld a,d
        out0 (DAR0H),a
        set_io BCR0L, PAGE_GROUPS & 0xFF
        set_io BCR0H, PAGE_GROUPS >> 8
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        set_io BCR0H, 0
        call combined_coverage_begin
        ld hl,0xFFFF                    ; invalidate the cloud column
        ld (scroll_column_key),hl
        xor a                           ; the staged asset is used up
        ld (hitch_d500_state),a
        ld a,STATE_CONSUMED
        ld (hitch_ready),a
        ret
        .endm

        .section .text.hitch_stage_draw_buffer1,"ax",@progbits
hitch_stage_draw_buffer1:
        hitch_stage_draw packet_buffer_0__run, hitch_stage_blocks_buffer1, hitch_stage_draw_1__limit

        .section .text.hitch_stage_draw_buffer0,"ax",@progbits
hitch_stage_draw_buffer0:
        hitch_stage_draw packet_buffer_1__run, hitch_stage_blocks_buffer0, hitch_stage_draw_0__limit
