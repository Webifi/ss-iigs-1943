; Background motion: move the canonical rows whose twin changed owner, and
; the camera of the retained middle layer.

        .include "video.inc"
        .include "water.inc"

        .global background_migrate_clean

        .section .text.background_migration,"ax",@progbits

; background_migrate_clean: after a scroll, copy the strip of canonical rows
; whose clean twin changed with one DMA block move inside video RAM.
; AF, BC, DE, HL changed.
background_migrate_clean:
        ld a,(scroll_full)
        or a
        ret nz                          ; a new view redraws everything
        ld a,(scroll_delta)
        or a
        ret z
        ld a,(scroll_wrap)
        or a
        jp nz,move_required             ; a wrap exchanges the twins
        ld a,(bg_direct)
        or a
        ret nz                          ; outgoing rows will be seeded
move_required:
        ; Either direction exchanges only the strip whose twin ownership
        ; changed. A reverse wrap copies lower to upper, not upper to lower.
        ld a,(bg_reverse)
        ld b,a
        ld a,(scroll_wrap)
        xor b
        ld (bg_move_down),a
        jp z,move_up
        ld a,(scroll_old_origin)
        ld b,a
        ld a,(scene_ring_start)
        sub b
        ld (bg_move_count),a
        ld l,b
        jp move_address
move_up:
        ld a,(scene_ring_start)
        ld b,a
        ld a,(scroll_old_origin)
        sub b
        ld (bg_move_count),a
        ld l,b
move_address:
        ld h,0
        call state_times56
        ld de,PAGE_START
        add hl,de
        ld a,(scene_page)
        or h
        ld h,a
        ld (scroll_src),hl
        ld de,TWIN_DISTANCE
        add hl,de
        ld (scroll_dest),hl
        ld a,(bg_move_down)
        or a
        jp z,move_ready
        ld de,(scroll_src)
        ld (scroll_src),hl
        ld (scroll_dest),de
move_ready:
        ld a,(bg_move_count)
        ld l,a
        ld h,0
        call state_times56
        out0 (BCR0L),l
        out0 (BCR0H),h
        ld bc,OAK_INDEX
        ld a,OAK_READ_SEGMENT
        out (c),a
        inc c
        ld a,0
        out (c),a
        ld bc,VGA_SEQ_INDEX
        ld a,SEQ_MAP_MASK
        out (c),a
        inc c
        ld a,ALL_PLANES
        out (c),a
        ld a,VGA_WINDOW >> 16
        out0 (SAR0B),a
        ld a,VGA_WINDOW >> 16
        out0 (DAR0B),a
        ld hl,(scroll_src)
        ld de,(scroll_dest)
        ld a,l
        out0 (SAR0L),a
        ld a,h
        out0 (SAR0H),a
        ld a,e
        out0 (DAR0L),a
        ld a,d
        out0 (DAR0H),a
        ld a,DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        out0 (DSTAT),a
        ld a,0
        out0 (BCR0H),a                  ; the other DMA commands set only BCR0L
        ret

; ---------------------------------------------------------------------------
; Camera of the retained middle layer (light water or foreground) and its
; motion between the frames drawn on each page.

        .global background_camera_input, background_camera_delta, background_reindex
        .global background_bounded_delta, background_cache_delta, background_anchor_camera
        .global bg_layer_camera, bg_page_cameras, bg_layer_shift, bg_moving_objects
        .global row_cache_count, row_cache_reverse, row_cache_cull, row_cache_first

; The stage-one wrap: the foreground camera jumps from WRAP_HIGH:00-1F to
; 00:00-1F; both windows of the map are empty.
        .equ WRAP_HIGH, 0x9F
        .equ WRAP_ROWS, 0x20

; The layer cameras (secondsight.ld .playfield: zero at load). An 8-bit
; page index reads bg_page_cameras: it stays in one 256-byte page.
        .section .vars.background_motion,"aw",@nobits
        .balign 4
bg_page_cameras:        .ds.w 2         ; per page: layer camera when last drawn
bg_layer_camera:        .ds.w 1         ; camera of the retained middle layer
bg_layer_shift:         .ds.w 1         ; layer motion beyond the measured one
bg_moving_objects:      .ds.b 1         ; light-water ships move as objects

; The shared row cache (background_cache_delta): the new foreground rows of
; this picture (secondsight.ld .row_variables).
        .section .vars.row_cache,"aw",@nobits
row_cache_count:        .ds.w 1         ; rows to prepare; PAGE_ROWS: all
row_cache_reverse:      .ds.b 1         ; 1: the camera moved down the map
row_cache_cull:         .ds.w 1         ; the rows from the top that are not ready (high byte: none is)
row_cache_first:        .ds.w 1         ; the world row of the first new row

        .section .text.background_camera,"ax",@progbits

; background_camera_input: read the sea camera from the packet and choose
; the layer camera: the sea camera in the light water band, else the
; foreground camera. AF, DE, HL changed.
background_camera_input:
        ld hl,(scene_raw)
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (scroll_sea_camera),de
        ld a,d
        and SEA_BANK
        cp LIGHT_WATER_BAND
        jr nz,middle_camera
        ex de,hl
        jr camera_chosen
middle_camera:
        ld hl,(scene_fg_camera)
camera_chosen:
        ld (bg_layer_camera),hl
        ret

; background_camera_delta: In: HL middle-layer displacement already
; measured by the caller. Out: HL layer displacement since this page was
; last drawn; bg_layer_shift, bg_moving_objects. AF, BC, DE changed.
background_camera_delta:
        ld (bg_layer_shift),hl
        ld a,(scroll_page_index)
        add a,a
        add a,bg_page_cameras & 0xFF
        ld l,a
        ld h,bg_page_cameras >> 8
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld de,(bg_layer_camera)
        ld (hl),d
        dec hl
        ld (hl),e
        ex de,hl
        or a
        sbc hl,bc
        push hl
        ld de,(bg_layer_shift)
        or a
        sbc hl,de
        ld (bg_layer_shift),hl
        ld a,(bg_pan)
        or a
        jr nz,objects_ready
        ; The shift is zero in ordinary stage-water scenes, which retain the
        ; middle layer itself. Light-water ships become objects only when
        ; their displacement differs from the retained sea.
        ld a,(scroll_sea_camera+1)
        and SEA_BANK
        cp LIGHT_WATER_BAND
        ld a,0
        jr nz,objects_ready
        ld a,h
        or l
objects_ready:
        ld (bg_moving_objects),a
        pop hl
        ret

; background_reindex: seed the canonical rows that the foreground motion
; uncovered (all rows after a large move). AF, BC, DE, HL changed.
background_reindex:
        ld a,(bg_direct)
        or a
        ret nz                          ; the cache is aligned
        ld hl,(scene_fg_camera)
        ld de,(bg_old_fg_camera)
        or a
        sbc hl,de
        ld a,h
        or l
        ret z
        bit 7,h
        jr nz,seed_backwards
        ld a,h
        or a
        jr nz,seed_full
        ld a,l
        cp BOUNDED_ROWS
        jr nc,seed_full
        ld (scroll_left_count),hl
        jr seed_top
seed_backwards:
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,seed_full
        ld a,l
        cp BOUNDED_ROWS
        jr nc,seed_full
        ld (scroll_left_count),hl
        ld hl,(bg_old_fg_camera)
        dec hl
        jr seed_start
seed_full:
        ld hl,PAGE_ROWS
        ld (scroll_left_count),hl
seed_top:
        ld hl,(scene_fg_camera)
        ld de,PAGE_ROWS - 1
        add hl,de
seed_start:
        ld (scroll_world_row),hl
seed_row:
        ld a,(scroll_world_row)
        ld b,a
        ld a,(scene_fg_camera)
        dec a
        sub b
        ld (scroll_row),a
        ld a,(scroll_page_index)
        ld c,a
        call background_clean_address
        ld (scroll_dest),hl
        call ship_reuse_other_page
        jr c,seed_next
        call combined_water
        ld a,1
        ld (scroll_canonical_source),a
        call combined_cloud
        xor a
        ld (scroll_canonical_source),a
        call ship_row_seed
seed_next:
        ld hl,(scroll_left_count)
        dec hl
        ld (scroll_left_count),hl
        ld a,h
        or l
        ret z
        ld hl,(scroll_world_row)
        dec hl
        ld (scroll_world_row),hl
        jr seed_row

        .section .text.background_delta,"ax",@progbits

; background_bounded_delta: bound either camera direction; keep the count
; apart from ring motion.
; In: HL signed displacement. Out: A 0 for a retained view, 1 for a full
; reseed. Patches the new-row limit and skip test of combined_repair_new.
background_bounded_delta:
        ld a,l
        ld (bg_signed_delta),a
        xor a
        ld (bg_reverse),a
        ld (bg_new_start),a
        bit 7,h
        jr z,delta_absolute
        dec a
        ld (bg_reverse),a
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
delta_absolute:
        ld a,l
        ld (scroll_delta),a
        ld b,a
        ld d,OP_JP_C                    ; skip new top rows
        ld a,(bg_reverse)
        or a
        ld a,b
        jr z,delta_repair_limit
        neg                             ; first new bottom row
        ld (bg_new_start),a
        ld d,OP_JP_NC                   ; skip new bottom rows
delta_repair_limit:
        ld (combined_repair_new_limit+1),a
        ld a,d
        ld (combined_repair_new_skip),a
        ld a,h
        or a
        jr nz,delta_full
        ld a,l
        cp BOUNDED_ROWS
        jr nc,delta_full
        xor a
        ret
delta_full:
        ld a,1
        ret

; background_cache_delta: the shared row cache follows the last submitted
; foreground position,
; apart from either display page and from sea motion. row_cache_cull is the
; conservative culling count; reverse entries set its high byte, so low
; sprites cannot inspect a row before it is installed.
; In: DE previous foreground camera, HL rows moved.
background_cache_delta:
        ; The stage-one wrap jumps between two empty map windows whose 256
        ; coverage rows are identical at every ring index (checked by the build).
        ld a,d
        cp WRAP_HIGH
        jr nz,cache_measure
        ld a,e
        cp WRAP_ROWS
        jr nc,cache_measure
        ld a,(scene_fg_camera+1)
        or a
        jr nz,cache_measure
        ld a,(scene_fg_camera)
        cp WRAP_ROWS
        jr nc,cache_measure
        ld hl,0
cache_measure:
        xor a
        ld (row_cache_reverse),a
        bit 7,h
        jr z,cache_absolute
        inc a
        ld (row_cache_reverse),a
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
cache_absolute:
        ld a,h
        or a
        jr nz,cache_jump
        ld a,l
        cp BOUNDED_ROWS
        jr c,cache_count
cache_jump:
        ld hl,PAGE_ROWS
        xor a
        ld (row_cache_reverse),a
cache_count:
        ld (row_cache_count),hl
        ld (row_cache_cull),hl
        ex de,hl
        ld hl,(scene_fg_camera)
        ld a,(row_cache_reverse)
        or a
        jr nz,cache_bottom
        inc h
        or a
        sbc hl,de
        jr cache_first
cache_bottom:
        ld a,0xFF                       ; keep low sprites until the rows are ready
        ld (row_cache_cull+1),a
cache_first:
        ld (row_cache_first),hl
        ld a,(row_cache_count)
        ret

        .section .text.background_anchor_camera,"ax",@progbits

; Keep the page's anchor while the view only moves within it; choose direct
; or canonical repairs for the rows.
background_anchor_camera:
        ld a,(scroll_page_index)
        add a,bg_anchors & 0xFF
        ld l,a
        ld h,bg_anchors >> 8
        ld a,(scene_ring_start)
        ld b,a
        ld a,(scene_fg_camera)
        dec a
        add a,b
        ld b,a
        ld a,(scroll_full)
        or a
        jr z,anchor_existing
        ld (hl),b
        jr anchor_direct
anchor_existing:
        ld a,b
        cp (hl)
        jr nz,anchor_indirect
        ld hl,(bg_layer_shift)
        ld a,h
        or l
        jr nz,anchor_indirect
anchor_direct:
        ld a,1
        ld hl,combined_static_repair
        jr anchor_selected
anchor_indirect:
        xor a
        ld hl,combined_stage_cached_repair
anchor_selected:
        ld (bg_direct),a
        ld (combined_static_repair_path+1),hl
        jp background_reuse_overlap
