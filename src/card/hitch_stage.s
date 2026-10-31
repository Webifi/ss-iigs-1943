; Staged $D500 picture: the host sends this helper and its compressed blocks
; in packets. The helper runs from whichever receive buffer got it, so it is
; assembled for both buffers. Each block expands through the world upload
; path into the other buffer, then its rows are copied to the display.

        .include "second_sight.inc"
        .include "vga.inc"
        .include "z180.inc"

        .global hitch_stage_draw_8000, hitch_stage_draw_4000

        .equ BLOCK_BANK, 15             ; BBR while the blocks are read
        .equ HEADER_BYTES, 10           ; world decompression header
        .equ RAW_LENGTH, 6              ; header offset of the expanded length
        .equ VRAM_CBR, 0x92
        .equ VRAM_APERTURE, 0xE0
        .equ TWIN_DISTANCE, 0x3800
        .equ VIEW_GROUPS, 56
        .equ PREPARED_VIEW, 3

        .section .vars.hitch_stage,"aw",@nobits
block_fragments:        .ds.b 1
block_plane:            .ds.b 1
block_count:            .ds.b 1

; The helper shares the hitch scratch words with the scene helper.
        .equ block_pointer, hitch_twin
        .equ block_cursor, hitch_copy_source
        .equ block_end, hitch_copy_dest

; BUFFER: receive buffer this copy runs in. OUTPUT: the other buffer, which
; takes the expanded rows. TABLE: the block table of this copy.
        .macro hitch_stage_draw buffer, output, table
        .equ input\@, \buffer + 0x300
        in0 a,(CBR)
        push af
        in0 a,(BBR)
        push af
        set_io BBR, BLOCK_BANK
        call background_water_view
        ld hl,\table
        ld (block_pointer),hl
        xor a
        ld (scroll_row),a
begin\@:
        ld hl,(block_pointer)
        ld de,input\@
        ld bc,HEADER_BYTES
        ldir
        ld a,(hl)
        inc hl
        ld (block_fragments),a
        ld (block_cursor),hl
        ld de,input\@ + HEADER_BYTES
        xor a
        ld (block_plane),a
plane\@:
        gc_set GC_READ_MAP, 0
        ld a,(block_plane)
        ld bc,VGA_GC_DATA
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
        cp 4
        jp nz,plane\@
        ld (block_pointer),hl
        xor a                           ; end marker
        ld (de),a
        ld hl,input\@
        call world_upload_batch
        ; The world upload left the expanded block at OUTPUT and may change mappings.
        ld hl,(input\@ + RAW_LENGTH)
        ld de,\output
        add hl,de
        ld (block_end),hl
        ld hl,\output
        ld (scroll_src),hl
        oak_set OAK_WRITE_SEGMENT, 0
        gc_set GC_MODE, 0x40
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
        add a,VRAM_CBR
        out0 (CBR),a
        ld hl,(scroll_dest)
        ld a,h
        and 0x0F
        or VRAM_APERTURE
        ld h,a
        ld (scroll_dest),hl
        ld a,1                          ; plane mask
        ld (scroll_segment),a
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
        cp 4
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
        seq_set SEQ_MAP_MASK, 0x0F
        gc_set GC_MODE, 0x41
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
        set_io BCR0L, 0
        set_io BCR0H, (VIEW_GROUPS * 256) >> 8
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        set_io BCR0H, 0
        call combined_coverage_begin
        ld hl,0xFFFF                    ; invalidate the cloud column
        ld (scroll_column_key),hl
        xor a                           ; the staged asset is used up
        ld (hitch_d500_state),a
        ld a,PREPARED_VIEW
        ld (hitch_ready),a
        ret
        .endm

        .section .text.hitch_stage_draw_8000,"ax",@progbits
hitch_stage_draw_8000:
        hitch_stage_draw 0x8000, 0x4000, hitch_stage_blocks_8000

        .section .text.hitch_stage_draw_4000,"ax",@progbits
hitch_stage_draw_4000:
        hitch_stage_draw 0x4000, 0x8000, hitch_stage_blocks_4000
