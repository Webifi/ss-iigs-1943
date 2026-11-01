; Combined scroll: retain one cloud and water layer; visit only new, damaged
; and refresh rows.

        .include "video.inc"
        .include "rows.inc"
        .include "ready.inc"
        .include "water.inc"

        .global combined_ship_mask_0, combined_ship_mask_1, combined_ship_mask_2, combined_ship_mask_3
        .global combined_ship_bias_0, combined_ship_bias_1, combined_ship_bias_2, combined_ship_bias_3
        .global combined_pan_mask_0, combined_pan_mask_1, combined_pan_mask_2, combined_pan_mask_3
        .global combined_pan_bias_0, combined_pan_bias_1, combined_pan_bias_2, combined_pan_bias_3
        .global wrap_repair_guard
        .global scroll_camera
        .global scroll_begin
        .global scroll_mark

        .global scroll_origins, scroll_cameras, scroll_pans, scroll_valid, scroll_delta
        .global scroll_full, scroll_sea_camera, scroll_page_index, scroll_current_map
        .global scroll_old_rows, scroll_damage_pages, scroll_spare_map, scroll_old_map
        .global scroll_old_count, scroll_old_origin, scroll_wrap, scroll_world_row, scroll_dest
        .global scroll_left, scroll_right, scroll_row, scroll_left_count, scroll_seed, scroll_ptr
        .global scroll_n, scroll_src, scroll_segment, scroll_mask, scroll_x, scroll_length
        .global world_row_slot, scroll_strip_source, scroll_strip_segment, scroll_column_key
        .global scroll_light_water, scroll_static_family, scroll_static_recipe, scroll_static_dest
        .global scroll_static_count, sea_feature_masked, ship_damage_span, scroll_pan_slide
        .global scroll_canonical_source, ship_clean_base, water_group_height, water_period_capacity

        .equ STRIPS, 16                 ; strip families of a column (4 groups each)
        .equ VISIBLE_STRIPS, 14         ; the strips of the 56 visible groups

; The column cache (secondsight.ld .column_cache, through the upper half
; of the bank area): the recipes of the column, the row programs of each
; strip family.
        .global column_families, column_recipes
        .section .vars.column_families,"aw",@nobits
column_families: .ds.b 64 * STRIPS
        .section .vars.column_recipes,"aw",@nobits
column_recipes: .ds.b 96

; The scroll state (secondsight.ld .playfield: zero at load).
        .section .vars.combined_scroll,"aw",@nobits
; The rows of the old damage, sorted (scroll_begin): one 256-byte page,
; stepped with INC L.
        .balign 256
scroll_old_rows: .ds.b 256
; The scroll state of the pages (SCROLL_PAGE_STATE bytes that playfield_setup
; clears). An 8-bit page index reads the tables: each stays in one
; 256-byte page (the block is 4-aligned).
        .balign 4
scroll_origins: .ds.b 4                 ; per page: the physical row of the ring start
scroll_cameras: .ds.b 4                 ; per page: the foreground camera of its last picture
scroll_pans: .ds.b 2                    ; per page: the pan of its last picture
scroll_valid: .ds.b 2                   ; per page: not 0 when its rows can be reused
scroll_delta: .ds.b 1                   ; the camera move in rows (unsigned)
scroll_full: .ds.b 1                    ; 1: the page is drawn again in full
scroll_sea_camera: .ds.b 2              ; the sea camera of the packet
scroll_page_index: .ds.b 1              ; the back page: 0 or 1
scroll_current_map: .ds.b 2             ; the damage map of the back page (high byte)
scroll_page_state_end:
        .global SCROLL_PAGE_STATE
        .equ SCROLL_PAGE_STATE, scroll_page_state_end - scroll_origins
; The damage maps of the pages and their exchange. The page index reads
; scroll_damage_pages: it stays in one 256-byte page.
        .balign 2
scroll_damage_pages: .ds.b 2            ; per page: the high byte of its damage map
scroll_spare_map: .ds.b 1               ; the high byte of the spare map
scroll_old_map: .ds.b 1                 ; the high byte of the old damage map
scroll_old_count: .ds.b 2               ; the rows in scroll_old_rows
scroll_old_origin: .ds.b 1              ; the ring start of the last picture of this page
scroll_wrap: .ds.b 1                    ; not 0: the ring wraps in this move
; The row state of the draw.
scroll_world_row: .ds.b 2               ; the world row of the current row
scroll_dest: .ds.b 2                    ; the screen address of the current row
scroll_left: .ds.b 1                    ; the left group of the span
scroll_right: .ds.b 1                   ; the right group of the span (exclusive)
scroll_row: .ds.b 1                     ; the view row of the current row
scroll_left_count: .ds.b 2              ; rows left to draw
scroll_seed: .ds.b 1                    ; 1: seed the twins too
scroll_ptr: .ds.b 2                     ; a command or source pointer of the draw
scroll_n: .ds.b 1                       ; a count of the draw
scroll_src: .ds.b 2                     ; a source address of the draw
scroll_segment: .ds.b 1                 ; the Oak segment, or a plane mask
scroll_mask: .ds.b 1                    ; the map mask of combined_dma
scroll_x: .ds.b 1                       ; the left group, or a lane
scroll_length: .ds.b 1                  ; the groups of combined_dma
world_row_slot: .ds.b 1                 ; the world slot of the current column
scroll_strip_source: .ds.b 2            ; the pixel row of the strip
scroll_strip_segment: .ds.b 1           ; its Oak segment
; The static repairs and the slide.
scroll_light_water: .ds.b 1             ; 1: the light water family
scroll_static_family: .ds.b 2           ; the family of a static repair
scroll_static_recipe: .ds.b 2           ; its recipe
scroll_static_dest: .ds.b 2             ; its destination
scroll_static_count: .ds.b 1            ; its rows
sea_feature_masked: .ds.b 1             ; not 0: the sea feature is masked by the cloud
ship_damage_span: .ds.b 2               ; the damage span of the ship row (left, right)
scroll_pan_slide: .ds.b 1               ; PAN_SLIDE_START, PAN_SLIDE_PLACED, or 0
scroll_canonical_source: .ds.b 1        ; 1: the water comes from the canonical row
ship_clean_base: .ds.b 2                ; the clean row of the ship copies
water_group_height: .ds.b 1             ; the rows of a water group
water_period_capacity: .ds.b 1          ; the water rows that one copy can take
        .section .data.scroll_column_key,"aw",@progbits
scroll_column_key: .word 0xFFFF         ; the cached cloud column; 0xFFFF: none

        .equ PAN_SLIDE_START, 1         ; scroll_pan_slide: a ship slide starts
        .equ PAN_SLIDE_PLACED, 2        ; the final object placement
        .equ HUD_ROWS, 16
        .equ HUD_LOWER_ROW, 240

; The damage maps: for each of the PAGE_ROWS rows the left and the right
; group of its damage (empty: left GROUPS_PER_ROW, right 0). The maps of
; page 0 and page 1 and the spare map change places (scroll_begin); the
; code names a map by its high byte, so each map starts a 256-byte page.
        .global damage_map_0, damage_map_1, damage_map_2
        .section .vars.damage_map_0,"aw",@nobits
        .balign 256
damage_map_0: .ds.b 2 * PAGE_ROWS
        .section .vars.damage_map_1,"aw",@nobits
        .balign 256
damage_map_1: .ds.b 2 * PAGE_ROWS
        .section .vars.damage_map_2,"aw",@nobits
        .balign 256
damage_map_2: .ds.b 2 * PAGE_ROWS

        .section .text.wrap_repair_guard,"ax",@progbits

; Skip the old-page repair only when the following refresh paints all rows.
wrap_repair_guard:
        ld a,(scroll_wrap)
        or a
        jp z,wrap_repair_default
        ld a,(bg_moving_objects)
        or a
        ret nz
wrap_repair_default:
hitch_repair_dispatch_operand:
        jp hitch_repair_dispatch_common

        .section .text.scroll_camera,"ax",@progbits

; Per picture: take the cameras, measure the motion since this page was
; drawn, and set the ring origin and the screen base.
scroll_camera:
        ld a,(scene_page)
        rlca
        ld (scroll_page_index),a
        call background_camera_input
        ld a,(scroll_page_index)
        add a,a
        add a,scroll_cameras & 0xFF
        ld l,a
        ld h,scroll_cameras >> 8
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld (bg_old_fg_camera),bc
        ld de,(scene_fg_camera)
        ld (hl),d
        dec hl
        ld (hl),e
        ex de,hl
        or a
        sbc hl,bc
        call background_camera_delta
        call background_bounded_delta
        ld (scroll_full),a
        ld a,(scroll_page_index)
        add a,scroll_valid & 0xFF
        ld l,a
        ld h,scroll_valid >> 8
        ld a,(hl)
        ld (hl),1
        or a
        jp nz,combined_page_valid
        inc a
        ld (scroll_full),a              ; the first picture on a page redraws it
combined_page_valid:
        xor a
        ld (scroll_pan_slide),a
        ld a,(scroll_page_index)
        add a,scroll_pans & 0xFF
        ld l,a
        ld h,scroll_pans >> 8
        ld b,(hl)
        ld a,(bg_moving_objects)
        ld (hl),a
        or a
        ld a,b
        jp nz,combined_pan_was_zero
        or a
        jp z,combined_pan_ok
        ld a,PAN_SLIDE_PLACED
        ld (scroll_pan_slide),a
        jp combined_pan_ok
combined_pan_was_zero:
        or a
        jp nz,combined_pan_ok
combined_pan_reseed:
        ld a,PAN_SLIDE_START
        ld (scroll_pan_slide),a
combined_pan_ok:
        ld a,(scroll_page_index)
        add a,scroll_origins & 0xFF
        ld l,a
        ld h,scroll_origins >> 8
        ld b,(hl)
        ld a,b
        ld (scroll_old_origin),a
        ld a,(bg_signed_delta)
        ld c,a
        ld a,b
        sub c
        ld (hl),a
        ld (play_new_start_row),a
        ld l,a
        ld h,0
        ld (scene_ring_start),hl
        sbc a,a                         ; forward wrap
        ld b,a
        ld a,(bg_reverse)
        xor b                           ; reverse wrap
        ld (scroll_wrap),a
        call state_times56
        ld de,PAGE_START
        add hl,de
        ld a,(scene_page)
        or h
        ld h,a
        ld (scene_screen_base),hl
        call water_camera
        jp background_anchor_camera

        .section .text.scroll_damage,"ax",@progbits

; The two pages and the old-damage scratch exchange ownership. The spare
; was cleared after its last repairs, so no bounds are copied.
scroll_begin:
        ld a,(scroll_page_index)
        add a,scroll_damage_pages & 0xFF
        ld l,a
        ld h,scroll_damage_pages >> 8
        ld b,(hl)                       ; old map high byte
        ld a,(scroll_spare_map)
        ld (hl),a
        ld h,a                          ; new map high byte
        ld l,0
        ld (scroll_current_map),hl
        ld a,b
        ld (scroll_spare_map),a
        ld (scroll_old_map),a
        ld (combined_repair_old_base+2),a
        ld (combined_group_old_base+2),a
        ld h,a
        ld l,1                          ; first right bound
        ld de,scroll_old_rows
        ld b,0
snapshot_row:
        ld a,(hl)
        or a
        jp z,snapshot_next
        ld a,b
        ld (de),a
        inc de
snapshot_next:
        inc hl
        inc hl
        inc b
        jp nz,snapshot_row
        ex de,hl
        ld de,scroll_old_rows
        or a
        sbc hl,de
        ld (scroll_old_count),hl
        ret

; Clear after every old-bound consumer has finished, including rows skipped
; by a full redraw or a camera move. A stack fill clears the 512 bytes
; without row addresses or per-row stores.
combined_clear_damage:
        ld hl,(scroll_old_count)
        ld a,h
        or l
        ret z
        ld (combined_clear_stack+1),sp
        ld a,(scroll_old_map)
        add a,2                         ; end of the map
        ld h,a
        ld l,0
        ld sp,hl
        ld de,GROUPS_PER_ROW            ; empty bounds: left 56, right 0
        ld b,16
combined_clear_damage_row:
        .rept 16
        push de
        .endr
        djnz combined_clear_damage_row
combined_clear_stack:
        ld sp,0                         ; patched: the command stack
        ret

; Mark B rows from physical row A between groups D and E for repair.
scroll_mark:
        ld l,a
        ld h,0
        add hl,hl
        ld a,(scroll_current_map+1)
        add a,h
        ld h,a
combined_mark_row:
        jp sprite_mark_fast

; ---------------------------------------------------------------------------
; The scroll pass of one picture.

        .global scroll_draw, combined_new_row, combined_repairs, combined_refresh
        .global combined_ship_source


        .section .text.scroll_draw,"ax",@progbits

; Plan list entry. Stack: three background arguments.
scroll_draw:
        ld a,(bg_pan)
        call game_set_pan
        set_io BCR0H, 0
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        oak_set OAK_WRITE_SEGMENT, 0
        gc_set GC_MODE, GC_MODE_256 | 1
        call combined_clean_old_twin
        call background_reindex
        call hitch_scene_consume
        ld a,1                          ; seed the twins
        ld (scroll_seed),a
        ld hl,GROUPS_PER_ROW << 8       ; full row: left 0, right 56
        ld (scroll_left),hl
        ld a,(scroll_delta)
        ld l,a
        ld h,0
        ld a,(scroll_full)
        or a
        jp nz,combined_new_full
        ld (scroll_left_count),hl
        ld a,l
        or a
        jp z,combined_repairs
        ld a,(bg_new_start)
        ld (scroll_row),a
; combined_new_row: compose each new row (scroll_left_count from
; scroll_row), then the repairs and the refresh.
combined_new_row:
        call combined_position
        call combined_compose
        ld a,(scroll_row)
        inc a
        ld (scroll_row),a
        ld hl,(scroll_left_count)
        dec hl
        ld (scroll_left_count),hl
        ld a,h
        or l
        jr nz,combined_new_row
; combined_repairs: repair the old damage of the page (unless a full
; redraw); combined_refresh: then the refresh rows of the slide or the wrap.
combined_repairs:
        xor a
        ld (scroll_seed),a
        ld a,(scroll_full)
        or a
        jp nz,combined_refresh
        call wrap_repair_guard
combined_refresh:
        ld a,(scroll_full)
        or a
        jp nz,combined_panning
        ld hl,GROUPS_PER_ROW << 8
        ld (scroll_left),hl
        ld a,(scroll_pan_slide)
        cp PAN_SLIDE_START
        jp z,combined_refresh_all
        ld a,(scroll_wrap)
        or a
        jp z,combined_panning
combined_refresh_all:
        call hitch_water_refresh
        jp c,combined_panning
        xor a
        ld (scroll_row),a
combined_refresh_row:
        ; scroll_row is a physical row here; translate it to this visible copy.
        ld a,(scroll_row)
        push af
        ld b,a
        ld a,(scene_ring_start)
        ld c,a
        ld a,b
        sub c
        ld (scroll_row),a
        call combined_position
        ld a,(scroll_pan_slide)
        or a
        jp nz,combined_refresh_needed
        ld a,(bg_moving_objects)
        or a
        jp nz,combined_refresh_needed
        ld a,(bg_direct)
        or a
        jp z,combined_refresh_needed    ; not anchored
        ld a,(scroll_world_row)
        ld l,a
        ld h,row_classes >> 8
        bit ROW_SHIP_CACHE,(hl)
        jp z,combined_refresh_kept
combined_refresh_needed:
        call combined_water
combined_refresh_kept:
        pop af
        ld l,a
        ld h,0
combined_refresh_stride:
        ld de,1                         ; patched: refresh stride
        add hl,de
        ld a,l
        ld (scroll_row),a
        ld a,h
        or a
        jr z,combined_refresh_row
combined_panning:
        call combined_sea
        ld hl,GROUPS_PER_ROW << 8
        ld (scroll_left),hl
        ld a,(bg_moving_objects)
        or a
        jp z,scroll_finish
        oak_set OAK_READ_SEGMENT, 0
        gc_set GC_READ_MAP, 0
        gc_set GC_MODE, GC_MODE_256 | 1
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        xor a
        ld (scroll_row),a
        call combined_position
combined_ship_row:
        ld a,1
        ld (ship_row_count),a
        ld a,(scroll_world_row)
        ld l,a
        ld h,row_classes >> 8
        ld a,(hl)
        or a
        jp z,combined_ship_next
        call ship_dispatch
combined_ship_next:
        ld a,(ship_row_count)
        ld b,a
        ld a,(scroll_row)
        add a,b
        ld (scroll_row),a
        jp z,scroll_finish
        ld e,b
        ld d,0
        ld hl,(scroll_world_row)
        or a
        sbc hl,de
        ld (scroll_world_row),hl
        ld l,b
        ld h,0
        call state_times56
        ld de,(scroll_dest)
        add hl,de
        ld (scroll_dest),hl
        jr combined_ship_row
scroll_finish:
        ld a,(scroll_pan_slide)
        cp PAN_SLIDE_PLACED
        jp nz,combined_finish_damage
        xor a                           ; the background is retained again
        ld (bg_moving_objects),a
combined_finish_damage:
        call combined_clear_damage
        gc_set GC_READ_MAP, 0
        seq_set SEQ_MAP_MASK, ALL_PLANES
        gc_set GC_MODE, GC_MODE_256 | 1
        exx
        ld bc,VGA_SEQ_DATA
        exx
        ret

; Compose a new row; while seeding, also copy it to its clean twin.
combined_compose:
        call combined_compose_source
        ld a,(scroll_seed)
        or a
        ret z
        ld a,(bg_direct)
        or a
        ret z
        ld hl,(scroll_dest)
        ld (scroll_src),hl
        ld a,(scroll_page_index)
        ld c,a
        call background_clean_address
        ld (scroll_dest),hl
        call ship_reuse_other_page
        ret c                           ; the clean row is already prepared
        ; A panning row also needs clean water beneath its canonical ship
        ; art, or a later static repair would bring back old HUD and sprite
        ; pixels from the ring's previous use.
        xor a
        ld (scroll_segment),a
        ld (scroll_x),a
        ld a,GROUPS_PER_ROW
        ld (scroll_length),a
        ld a,ALL_PLANES
        ld (scroll_mask),a
        call combined_dma
        ld a,(bg_moving_objects)
        or a
        jp nz,combined_seed_ship
        jp ship_row_seed
combined_seed_ship:
        ld a,1
        ld (scroll_canonical_source),a
        call combined_cloud
        xor a
        ld (scroll_canonical_source),a
        jp ship_row_seed

; Carry clear only when the whole damage span lies inside the build-prepared
; all-water interval of the row; no mask decoding at run time.
combined_water_gap:
        ld a,(scroll_world_row)
        ld l,a
        ld h,water_left_bounds >> 8
        ld a,(scroll_left)
        cp (hl)
        ret c
        inc h                           ; water_right_bounds
        ld a,(scroll_right)
        ld b,a
        ld a,(hl)
        sub b
        ret

; Repair the damage span from the clean twin. Repair addresses are in
; display segment 0 and cannot cross its 64 KB group boundary, so they stay
; in registers through the DMA setup.
combined_restore:
        oak_set OAK_READ_SEGMENT, 0
        seq_set SEQ_MAP_MASK, ALL_PLANES
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        ld hl,(scroll_dest)
        ld a,(scroll_left)
        ld e,a
        ld d,0
        add hl,de
        ld a,l
        out0 (DAR0L),a
        ld a,h
        out0 (DAR0H),a
        ld a,(scroll_page_index)
        ld c,a
        call background_clean_address
        ld a,(scroll_left)
        ld e,a
        ld d,0
        add hl,de
        ld a,h
combined_restore_source:
        out0 (SAR0H),a
        ld a,l
        out0 (SAR0L),a
        ld a,(scroll_left)
        ld b,a
        ld a,(scroll_right)
        sub b
        out0 (BCR0L),a
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        ret

; When the origin wraps, the previous visible twin becomes the clean twin.
; Remove its old objects before it serves as a repair source.
combined_clean_old_twin:
        jp background_migrate_clean

; Draw the ship pixels of the row from its prepared spans.
combined_ship_source:
        call combined_ready_row
        ld a,(hl)
        cp READY_CACHED
        jp z,ship_row_cached
        cp READY_SPILL
        jp nz,combined_ship_resident
        ld a,(scroll_world_row)
        ld l,a
        call combined_mask_root
        call combined_pointer
        ld de,RECORD_WATER
        add hl,de
        call combined_skip_water
        cp SHIP_ALIGNED
        jp z,ship_row_draw
        bit 7,a                         ; uncached edge
        jp nz,combined_cloud
        or a
        ret z
        inc hl
        ld c,a
        ld b,0
        ld de,ship_span_buffer
        ldir
        ld hl,ship_span_buffer
        jp combined_ship_commands
combined_ship_resident:
        call combined_skip_water
        cp SHIP_ALIGNED
        jp z,ship_row_draw
        bit 7,a
        jp nz,combined_cloud
        or a
        ret z
        inc hl
combined_ship_commands:
        push hl
        ld hl,GROUPS_PER_ROW            ; empty ship damage: left 56, right 0
        ld (ship_damage_span),hl
        ld a,(scroll_page_index)
        ld c,a
        call background_clean_address
        ld (ship_clean_base),hl
        oak_set OAK_READ_SEGMENT, 0
        gc_set GC_MODE, GC_MODE_256
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        pop hl                          ; prepared ship plane spans
        .irp plane, 0, 1, 2, 3
        ld a,(hl)
        inc hl
        or a
        jp z,plane_next_\plane
        exx
        ld b,a                          ; span count
        gc_set GC_READ_MAP, \plane
        ld bc,VGA_SEQ_DATA
combined_ship_mask_\plane:
        ld a,1 << \plane                ; patched: prepared lane
        out (c),a
combined_ship_bias_\plane:
        ld a,4                          ; patched: prepared crop
        ld (combined_ship_crop+1),a
        exx
        dec hl
        ld b,(hl)
        inc hl
plane_run_\plane:
        ld a,(hl)
        inc hl
        ld e,(hl)
        inc hl
        exx
        ld c,a
        exx
        ld a,e
        exx
        ld b,a
        call combined_ship_plane_copy
        exx
        dec b
        jp nz,plane_run_\plane
plane_next_\plane:
        .endr
        gc_set GC_READ_MAP, 0
        gc_set GC_MODE, GC_MODE_256 | 1
        jp combined_ship_damage

; ---------------------------------------------------------------------------

        .global combined_compose_source, background_water_view


        .section .text.compose_source,"ax",@progbits

; A retained cloud row avoids both water and cloud drawing.
combined_compose_source:
        ld a,(bg_moving_objects)
        ld b,a
        ld a,(scroll_light_water)
        or b
        jp nz,combined_compose_fresh
        ld a,(bg_reuse)
        or a
        jp z,combined_compose_fresh
        call ship_reuse_other_page
        ret c                           ; the whole clean row was copied
combined_compose_fresh:
        call combined_water
        ld a,(bg_moving_objects)
        or a
        ret nz
        jp combined_cloud

        .section .text.water_refresh,"ax",@progbits

; Copy water over the whole view, one pattern period at a time.
background_water_view:
        call combined_repair_registers
        xor a
        ld (scroll_row),a
water_refresh_chunk:
        call combined_position
        call water_pattern_source
        ld a,(scroll_light_water)
        or a
        ld a,STAGE_PERIOD
        jp z,refresh_period
        ld a,LIGHT_PERIOD
refresh_period:
        sub c                           ; source rows left in the period
        ld d,a
        ld a,(scroll_row)
        neg                             ; view rows left
        jp z,refresh_height
        cp d
        jp nc,refresh_height
        ld d,a
refresh_height:
        ld c,d
        ld b,GROUPS_PER_ROW
        ld de,(scroll_dest)
        out0 (DAR0H),d
        call water_rectangle
        ld a,(scroll_row)
        add a,c
        ld (scroll_row),a
        jp nc,water_refresh_chunk
        ret

        .section .text.feature_open,"ax",@progbits

; Draw an open-water span: the masked path, the plain water copy, or a
; sea feature tile.
water_open_dispatch:
        ld a,(sea_feature_masked)
        or a
        jp z,water_masked_source
        ld a,(sea_active)
        or a
        jp nz,water_feature_open_direct
        jp water_open_direct
; In a proven all-water span the feature tile is copied in every plane,
; including its own water pixels, which are fixed colours over the animated
; water. Its source is biased, so add the left edge as the water path does.
water_feature_open_direct:
        pop af                          ; unused count
        pop bc                          ; unused commands
        ld bc,VGA_SEQ_DATA
        ld a,ALL_PLANES
        out (c),a
        ld a,(scroll_left)
        ld c,a
        ld b,0
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        ld a,(scroll_right)
        sub c
        out0 (BCR0L),a
        out0 (SAR0L),l
        out0 (SAR0H),h
        out0 (DAR0L),e
        out0 (DAR0H),d
        ld a,DSTAT_DE0 | DSTAT_DME      ; note: also writes DE1 = 0
        out0 (DSTAT),a
        ret

; ---------------------------------------------------------------------------
; Row helpers: ready-row commands, cloud strips, ship spans, clipping, DMA.

        .global combined_ready_row, combined_skip_water, combined_pan_restore_static, combined_cloud
        .global combined_ship_damage
        .global combined_dma


        .section .text.scroll_helpers,"ax",@progbits

; combined_ready_row: map the ready row of scroll_world_row (ready_rows,
; through BBR). Out: HL its address. AF, B changed.
combined_ready_row:
        ld a,(scroll_world_row)
        ld b,a
        rlca
        rlca
        and 3                           ; cache bank
        add a,ready_rows__bbr
        out0 (BBR),a                    ; ready row commands
        ld a,b
        and 0x3F                        ; the row in its 4 KB page (64 ready rows)
        ld l,a
        ld h,0
        .rept 6
        add hl,hl
        .endr
        ld a,h
        or WINDOW_C000 >> 8             ; aperture
        ld h,a
        ret
; combined_skip_water: skip the water spans at HL (a count, then SPAN_BYTES
; each). Out: HL and A the ship byte. DE changed.
combined_skip_water:
        ld a,(hl)
        inc hl
        ld e,a
        add a,a
        add a,e
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        ret
; combined_pan_restore_static: after the final placement of a slide, the
; ships move as objects (bg_moving_objects), unless the page is redrawn.
combined_pan_restore_static:
        ld a,(scroll_pan_slide)
        cp PAN_SLIDE_PLACED             ; final placement
        ret nz
        ld a,(scroll_full)
        or a                            ; full redraw
        ret nz
        inc a                           ; final placement to object mode
        ld (bg_moving_objects),a
        ret
; combined_cloud: draw the cloud (foreground) row at scroll_world_row from
; its column strips, unless the row has no foreground.
combined_cloud:
        ld a,(scroll_world_row)
        ld l,a
        ld h,row_classes >> 8           ; coverage class
        ld a,(hl)
        or a
        ret z
        ld hl,GROUPS_PER_ROW            ; empty ship damage: left 56, right 0
        ld (ship_damage_span),hl
        ld hl,(scroll_world_row)
        ld a,l
        and ~(COLUMN_ROWS - 1) & 0xFF   ; column boundary
        ld l,a
        ld de,(scroll_column_key)
        or a
        sbc hl,de
        jp z,combined_column_ready
        ld hl,(scroll_world_row)
        ld a,l
        and ~(COLUMN_ROWS - 1) & 0xFF   ; column boundary
        ld l,a
        ld (scroll_column_key),hl
        ld a,(scroll_world_row)
        ld l,a
        call combined_cloud_root
        call combined_pointer
        ld de,world_upload_buffer       ; column staging
        ld bc,96                        ; recipes
        ldir
        set_io BBR, column_families__bbrd
        ld hl,world_upload_buffer       ; recipes
        ld de,column_recipes__ptrd      ; retained column recipes
        ld bc,96                        ; bytes
        ldir
        xor a
        ld (world_row_slot),a
combined_cache_family:
        ld a,(world_row_slot)
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,world_upload_buffer+3     ; family record
        add hl,de
        call combined_pointer
        call combined_expand_family
        ld a,(world_row_slot)
        ld l,a
        ld h,0
        .rept 6
        add hl,hl
        .endr
        ld de,column_families__ptrd     ; column families
        add hl,de
        ex de,hl
        set_io BBR, column_families__bbrd
        ld hl,family_staging            ; family staging
        ld bc,64                        ; pointers
        ldir
        call shared_rows_cache
        ld a,(world_row_slot)
        inc a
        ld (world_row_slot),a
        cp STRIPS                       ; strips
        jp nz,combined_cache_family
combined_column_ready:
        set_io BBR, column_families__bbrd
        ld a,(scroll_canonical_source)
        or a
        jp nz,combined_static_row
        ld a,(bg_moving_objects)
        or a
        jp z,combined_static_row
        xor a
        ld (world_row_slot),a
combined_cloud_strip:
        ld a,(world_row_slot)
        add a,a
        add a,a
        ld b,a
        ld a,(bg_first_column)
        ld c,a
        ld a,b
        sub c                           ; first
        and WORLD_GROUPS - 1            ; wrap
        ld a,(bg_pan_phase)
        or a
        jp nz,combined_strip_visible
        ld a,b
        sub c                           ; first
        and WORLD_GROUPS - 1            ; wrap
        ld b,a
        ld a,(scroll_right)
        cp b                            ; start
        jp c,combined_strip_next
        jp z,combined_strip_next
        ld a,b
        add a,4                         ; strip width
        ld b,a
        ld a,(scroll_left)
        cp b                            ; end
        jp nc,combined_strip_next
combined_strip_visible:
        ld a,(world_row_slot)
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,column_recipes__ptrd      ; column
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (scroll_strip_source),de
        ld a,(hl)
        ld (scroll_strip_segment),a
        set_io BBR, column_families__bbrd
        ld a,(world_row_slot)
        ld l,a
        ld h,0
        .rept 6
        add hl,hl
        .endr
        ld de,column_families__ptrd     ; cached family row
        add hl,de
        ld a,(scroll_world_row)
        and COLUMN_ROWS - 1             ; row
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,(hl)
        inc hl
        ld (scroll_n),a
        or a
        jp z,combined_strip_next
        ld c,a
        add a,a
        add a,c
        ld c,a
        ld b,0
        ld de,family_staging            ; ready strip runs
        ldir
        ld a,(world_row_slot)
        ld l,a
        ld h,0
        .rept 6
        add hl,hl
        .endr
        ld a,(scroll_world_row)
        and COLUMN_ROWS - 1             ; row
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld de,cached_row_addresses__ptrd ; cached pixel addresses
        add hl,de
        set_io BBR, cached_row_addresses__bbrd
        ld e,(hl)
        inc hl
        ld d,(hl)
        set_io BBR, column_families__bbrd
        ld (scroll_strip_source),de
        ld a,row_pixels__vseg
        ld (scroll_strip_segment),a
        gc_set GC_READ_MAP, 0
        ld hl,family_staging            ; strip runs
        ld (scroll_ptr),hl
combined_cloud_command:
        ld hl,(scroll_ptr)
        ld a,(hl)
        ld (scroll_mask),a
        inc hl
        ld e,(hl)
        inc hl
        ld a,(hl)
        ld (scroll_length),a
        inc hl
        ld (scroll_ptr),hl
        ld d,0
        ld hl,(scroll_strip_source)
        add hl,de
        ld (scroll_src),hl
        ld a,(scroll_strip_segment)
        ld (scroll_segment),a
        ld a,(world_row_slot)
        add a,a
        add a,a
        add a,e                         ; local group
        ld (scroll_x),a
combined_pan_command:
        ld a,(scroll_segment)
        ld d,a
        ld bc,OAK_INDEX                 ; read segment
        ld a,OAK_READ_SEGMENT           ; index
        out (c),a
        inc c
        out (c),d
        ld a,(bg_pan_phase)
        or a
        jp nz,combined_cloud_fine
        ld a,(scroll_mask)
        ld bc,VGA_SEQ_DATA              ; map mask
        out (c),a
        ld a,(bg_first_column)
        ld b,a
        call combined_pan_copy
        jp combined_cloud_next
combined_cloud_fine:
        gc_set GC_MODE, GC_MODE_256
        .irp plane, 0, 1, 2, 3
        ld a,(scroll_mask)
        and 1 << \plane                 ; source plane
        jp z,combined_fine_next_\plane
        gc_set GC_READ_MAP, \plane
        ld bc,VGA_SEQ_DATA
combined_pan_mask_\plane:
        ld a,1 << \plane                ; patched: prepared plane
        out (c),a
combined_pan_bias_\plane:
        ld b,4                          ; patched: prepared pan crop
        call combined_pan_copy
        .ifne \plane - 3
combined_fine_next_\plane:
        .endif
        .endr
combined_fine_next_3:
        gc_set GC_READ_MAP, 0
        gc_set GC_MODE, GC_MODE_256 | 1
combined_cloud_next:
        ld a,(scroll_n)
        dec a
        ld (scroll_n),a
        jp nz,combined_cloud_command
combined_strip_next:
        ld a,(world_row_slot)
        inc a
        ld (world_row_slot),a
        cp STRIPS                       ; strips
        jp c,combined_cloud_strip
        jp combined_ship_damage
combined_static_row:
        ld a,(scroll_world_row)
        and COLUMN_ROWS - 1             ; row
        add a,a
        ld l,a
        ld h,0
        ld de,column_families__ptrd + 0x40 ; first strip family
        add hl,de
        ld (scroll_static_family),hl
        ld hl,column_recipes__ptrd + 6  ; first strip recipe
        ld (scroll_static_recipe),hl
        ld hl,(scroll_dest)
        ld (scroll_static_dest),hl
        ld a,VISIBLE_STRIPS
        ld (scroll_static_count),a
combined_static_strip:
        ld hl,(scroll_static_family)
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,(hl)
        inc hl
        or a
        jp z,combined_static_next
        ld (scroll_n),a
        push hl
        set_io BBR, cached_row_addresses__bbrd ; the row address cache at $D000
        ld hl,(scroll_static_family)
        dec h
        ld e,(hl)
        inc hl
        ld d,(hl)
        set_io BBR, column_families__bbrd
        push de
        ld d,row_pixels__vseg
        ld bc,OAK_INDEX                 ; source segment
        ld a,OAK_READ_SEGMENT           ; index
        out (c),a
        inc c
        out (c),d
        pop de
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        ex de,hl
        ld de,(scroll_static_dest)
        ld bc,VGA_SEQ_DATA              ; map mask
        exx
        pop hl
        ld a,(scroll_n)
        ld b,a
combined_static_run:
        ld a,(hl)
        inc hl
        exx
        out (c),a
        exx
        ld c,(hl)
        inc hl
        ld a,c
        exx
        or l                            ; source offset
        out0 (SAR0L),a                  ; source low
        ld a,h
        out0 (SAR0H),a                  ; source high
        exx
        ld a,c
        exx
        add a,e                         ; destination offset
        out0 (DAR0L),a                  ; destination low
        ld a,d
        adc a,0                         ; carry
        out0 (DAR0H),a                  ; destination high
        exx
        ld a,(hl)
        inc hl
        out0 (BCR0L),a                  ; groups
        ld a,DSTAT_DE0 | DSTAT_DME      ; burst
        out0 (DSTAT),a                  ; copy prepared strip
        dec b
        jp nz,combined_static_run
        exx
        jp combined_static_next
combined_static_next:
        ld hl,(scroll_static_family)
        ld de,64                        ; next family
        add hl,de
        ld (scroll_static_family),hl
        ld hl,(scroll_static_recipe)
        ld de,6                         ; next recipe
        add hl,de
        ld (scroll_static_recipe),hl
        ld hl,(scroll_static_dest)
        ld de,4                         ; next strip position
        add hl,de
        ld (scroll_static_dest),hl
        ld a,(scroll_static_count)
        dec a
        ld (scroll_static_count),a
        jp nz,combined_static_strip
        ret
combined_ship_plane_copy:
        ld hl,(ship_clean_base)
        ld e,c
        ld d,0
        add hl,de
        ld a,c
        add a,4                         ; crop origin
combined_ship_crop:
        sub 4                           ; prepared crop
        and WORLD_GROUPS - 1            ; wrapped position
        ld c,a
        cp GROUPS_PER_ROW               ; viewport
        jp c,combined_ship_clip_right
        ld a,WORLD_GROUPS               ; world width
        sub c                           ; start
        ld e,a
        add hl,de
        ld a,b
        sub e                           ; clipped prefix
        ret c
        ret z
        ld b,a
        ld c,0
combined_ship_clip_right:
        ld a,GROUPS_PER_ROW             ; viewport
        sub c                           ; start
        cp b                            ; span length
        jp nc,combined_ship_copy_ready
        ld b,a
combined_ship_copy_ready:
        ld a,(ship_damage_span)
        cp c                            ; left
        jp c,combined_ship_left_kept
        ld a,c
        ld (ship_damage_span),a
combined_ship_left_kept:
        ld a,b
        add a,c                         ; left
        ld e,a
        ld a,(ship_damage_span+1)
        cp e                            ; right
        jp nc,combined_ship_right_kept
        ld a,e
        ld (ship_damage_span+1),a
combined_ship_right_kept:
        ld a,l                          ; ship source field
        out0 (SAR0L),a                  ; ship source
        ld a,h                          ; ship source field
        out0 (SAR0H),a                  ; ship source
        ld de,(scroll_dest)
        ld a,e
        add a,c                         ; start
        out0 (DAR0L),a                  ; ship destination low
        ld a,d
        adc a,0                         ; carry
        out0 (DAR0H),a                  ; ship destination high
        ld a,b
        out0 (BCR0L),a                  ; merged ship span
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        ret
combined_pan_copy:
        ld hl,(scroll_src)
        ld a,(scroll_x)
        sub b                           ; crop
        and WORLD_GROUPS - 1            ; wrap
        ld b,a
        ld a,(scroll_length)
        ld c,a
        ld a,b
        cp GROUPS_PER_ROW               ; visible groups
        jp c,combined_pan_right
        ld a,WORLD_GROUPS               ; world groups
        sub b                           ; wrapped start
        ld e,a
        ld d,0
        add hl,de
        ld a,c
        sub e                           ; clipped groups
        ret c
        ret z
        ld c,a
        ld b,0
combined_pan_right:
        ld a,GROUPS_PER_ROW             ; viewport end
        sub b                           ; start
        cp c                            ; length
        jp nc,combined_pan_ready
        ld c,a
combined_pan_ready:
        ld a,(ship_damage_span)
        cp b                            ; first group
        jp c,combined_pan_left_kept
        ld a,b
        ld (ship_damage_span),a
combined_pan_left_kept:
        ld a,b
        add a,c                         ; length
        ld d,a
        ld a,(ship_damage_span+1)
        cp d                            ; end
        jp nc,combined_pan_right_kept
        ld a,d
        ld (ship_damage_span+1),a
combined_pan_right_kept:
        ld a,l                          ; source field
        out0 (SAR0L),a                  ; ship source
        ld a,h                          ; source field
        out0 (SAR0H),a                  ; ship source
        ld de,(scroll_dest)
        ld a,e
        add a,b                         ; start
        out0 (DAR0L),a                  ; ship destination low
        ld a,d
        adc a,0                         ; carry
        out0 (DAR0H),a                  ; ship destination high
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        ld a,c
        out0 (BCR0L),a                  ; ship group count
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        ret
; combined_ship_damage: mark the ship span (ship_damage_span) of the rows
; for repair, unless the final placement keeps them.
combined_ship_damage:
        ld a,(scroll_pan_slide)
        cp PAN_SLIDE_PLACED             ; retained final placement
        ret z
        ld a,(ship_damage_span+1)
        or a
        ret z
        ld e,a
        ld a,(ship_damage_span)
        ld d,a
        ld a,(scroll_row)
        ld b,a
        ld a,(scene_ring_start)
        add a,b
        ld c,a
        ld a,(ship_row_count)
        ld b,a
        ld a,c
        jp scroll_mark
; combined_dma: one DMA move of scroll_length groups from scroll_src (Oak
; segment scroll_segment, planes scroll_mask) to scroll_dest + scroll_x.
; AF, BC, DE, HL changed.
combined_dma:
        ld a,(scroll_segment)
        ld d,a
        ld bc,OAK_INDEX                 ; Oak read segment
        ld a,OAK_READ_SEGMENT           ; index
        out (c),a
        inc c
        out (c),d
        ld a,(scroll_mask)
        ld bc,VGA_SEQ_DATA              ; map mask
        out (c),a
        ld hl,(scroll_src)
        ld a,l                          ; source
        out0 (SAR0L),a                  ; source address
        ld a,h                          ; source
        out0 (SAR0H),a                  ; source address
        ld hl,(scroll_dest)
        ld a,(scroll_x)
        ld e,a
        ld d,0
        add hl,de
        ld a,l                          ; destination
        out0 (DAR0L),a                  ; destination address
        ld a,h                          ; destination
        out0 (DAR0H),a                  ; destination address
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        ld a,(scroll_length)
        out0 (BCR0L),a                  ; prepared group count
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        ret

; ---------------------------------------------------------------------------
; Water under the foreground: whole rows by one DMA, prepared spans of the
; ready-row commands otherwise.

        .global combined_water
        .global water_source_mod_whole
        .global water_source_mod_clipped


        .section .text.water_fast,"ax",@progbits

; combined_water: draw the water of the row at scroll_world_row: none under
; an opaque foreground; else the masked water runs or an open copy.
combined_water:
        ld a,(bg_moving_objects)
        or a
        jp nz,combined_water_open
        ld a,(scroll_world_row)
        ld l,a
        ld h,row_classes >> 8
        ld a,(hl)
        and ROW_OPAQUE_VIEW
        ret nz
        ld a,(hl)
        or a
        jp z,combined_water_open
        call combined_water_gap
        jp nc,combined_water_open
        xor a                           ; mixed silhouette
        ld (sea_feature_masked),a
        call combined_ready_row
        ld a,(hl)
        cp READY_CACHED
        jp c,combined_water_commands
        ld a,(scroll_world_row)
        ld l,a
        call combined_mask_root
        call combined_pointer
        ld de,RECORD_WATER
        add hl,de
        ld a,(hl)
        ld c,a
        add a,a
        add a,c
        inc a
        ld c,a
        ld b,0
        ld de,ship_span_buffer          ; wide row staging
        ldir
        ld hl,ship_span_buffer
        jp combined_water_commands
combined_water_open:
        ld a,1                          ; open row
        ld (sea_feature_masked),a
        ld hl,combined_open_commands
combined_water_commands:
        ld a,(hl)
        or a
        ret z
        inc hl
        push hl
        push af
        ; Sources and destinations never cross a 64 KB DMA bank; reset the
        ; banks once here, the cloud path may have crossed one.
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        ld a,(sea_active)
        or a
        jp nz,water_feature_source
        ld a,(water_pattern_segment)
        ld d,a
        ld bc,OAK_INDEX
        ld a,OAK_READ_SEGMENT
        out (c),a
        inc c
        out (c),d
        ld a,(scroll_light_water)
        or a
        jp nz,water_light_row
        ld hl,(scroll_world_row)
        call water_mod30
        ld e,a
        ld a,STAGE_PERIOD - 1
        sub e
        call water_row_address
        jp water_source_ready
water_light_row:
        ld a,(scroll_world_row)
        ld b,a
        ld a,(scroll_relative)
        add a,b
        cpl
water_row_mask:
        and LIGHT_PERIOD - 1
        call water_row_address
        jp water_source_ready
water_feature_source:
        ld a,(sea_segment)
        ld d,a
        ld bc,OAK_INDEX
        ld a,OAK_READ_SEGMENT
        out (c),a
        inc c
        out (c),d
        ld hl,(sea_source)
water_source_ready:
        ld de,(scroll_dest)
        jp water_open_dispatch

; Masked water: one DMA per prepared span, with the planes of the span.
; Stack in: span count, span list.
water_masked_source:
        ld bc,VGA_SEQ_DATA
        exx
        pop af
        ld b,a
        pop hl
        ld a,(scroll_left)
        or a
        jp nz,water_run_clipped
        ld a,(scroll_right)
        cp GROUPS_PER_ROW
        jp nz,water_run_clipped

; Span: planes, start group, length (bit 7: same DMA addresses as the last).
        .macro water_runs variant
water_run_\variant:
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld e,(hl)
        inc hl
        .ifc \variant,clipped
        res 7,e
        ld a,(scroll_left)
        sub c
        jp c,water_right_clip
        jp z,water_right_clip
        add a,c
        ld c,a
        dec hl
        dec hl
        ld a,(hl)
        inc hl
        inc hl
        add a,e
        sub c
        jp c,water_next_clipped
        jp z,water_next_clipped
        ld e,a
water_right_clip:
        ld a,(scroll_right)
        sub c
        jp c,water_next_clipped
        jp z,water_next_clipped
        cp e
        jp nc,water_draw_clipped
        ld e,a
        .endif
water_draw_\variant:
        ld a,d
        exx
        out (c),a
        exx
        .ifc \variant,whole
        bit 7,e                         ; retained DMA addresses
        jp nz,water_length_whole
        .endif
        ld a,c
water_source_mod_\variant:
        and WORLD_GROUPS - 1            ; patched: repeat width
        exx
water_source_sum_\variant:
        add a,l                         ; patched: source row low
        out0 (SAR0L),a
        ld a,h
        adc a,0
        out0 (SAR0H),a
        exx
        ld a,c
        exx
        add a,e
        out0 (DAR0L),a
        ld a,d
        adc a,0
        out0 (DAR0H),a
        exx
water_length_\variant:
        ld a,e
        .ifc \variant,whole
        and WORLD_GROUPS - 1            ; span length
        .endif
        out0 (BCR0L),a
        ld a,DSTAT_DE0 | DSTAT_DME
water_transfer_\variant:
        out0 (DSTAT),a
water_next_\variant:
        dec b
        jp nz,water_run_\variant
        exx
        ret
        .endm

        water_runs whole
        water_runs clipped

; Both prepared patterns have the 56-group display pitch.
water_open_direct:
        pop af                          ; unused count
        pop bc                          ; unused commands
        ld bc,VGA_SEQ_DATA
        ld a,ALL_PLANES
        out (c),a
        ld a,(scroll_left)
        ld b,a
        add a,l
        ld l,a
        ld a,h
        adc a,0
        ld h,a
        ld a,b
        add a,e
        ld e,a
        ld a,d
        adc a,0
        ld d,a
        ld a,(scroll_right)
        sub b
        out0 (BCR0L),a
        out0 (SAR0L),l
        out0 (SAR0H),h
        out0 (DAR0L),e
        out0 (DAR0H),d
        ld a,DSTAT_DE0 | DSTAT_DME
water_transfer_open:
        out0 (DSTAT),a
water_open_copied:
        ret

; One span over the whole row: count 1, all planes, from group 0, 56 groups.
combined_open_commands:
        .byte 1, ALL_PLANES, 0, GROUPS_PER_ROW

; ---------------------------------------------------------------------------
; Row position and the repairs of old damage.

        .global combined_position, combined_stage_repairs, combined_repair_new_limit
        .global combined_repair_new_skip
        .global combined_static_repair_path, combined_static_repair
        .global combined_stage_cached_repair
        .global combined_repair_registers
        .global combined_repair_call

        .equ TWIN_HIGH, TWIN_DISTANCE >> 8
        .equ MAX_RECT_ROWS, 0xFF

        .section .text.combined_position,"ax",@progbits

; Out: scroll_world_row and scroll_dest of visible row scroll_row. The screen
; base already holds the ring origin and the page, so the sum selects the
; right twin.
combined_position:
        ld a,(scroll_row)
        ld e,a
        ld d,0
        ld hl,(scene_fg_camera)
        ld bc,PAGE_ROWS - 1
        add hl,bc
        or a
        sbc hl,de
        ld (scroll_world_row),hl
        ld a,(scroll_row)
        ld l,a
        ld h,row_offset_low >> 8
        ld e,(hl)
        inc h
        ld d,(hl)
        ld hl,(scene_screen_base)
        add hl,de
        ld (scroll_dest),hl
        ret

        .section .text.combined_repairs,"ax",@progbits

; Stage-water repairs keep the row-list cursor and the bounds in registers:
; B rows left, C ring origin, D new-row limit, HL the old row list.
combined_stage_repairs:
        ld hl,(scene_fg_camera)
        ld de,PAGE_ROWS - 1
        add hl,de
        call water_mod30
        ld (combined_repair_residue+1),a
        call repair_core_registers
        ld hl,(scroll_old_count)
        ld a,h
        or l
        ret z
        ld b,l
        ld a,(scene_ring_start)
        ld c,a
combined_repair_new_limit:
        ld d,0                          ; patched: new row boundary
        ld hl,scroll_old_rows
combined_stage_repair_row:
        ld a,(hl)
        inc l
        sub c
        cp d
combined_repair_new_skip:
        jp c,combined_stage_repair_next ; patched: jp c or jp nc
        ld (scroll_row),a
        add a,c
        exx
        ld l,a
        ld h,0
        add hl,hl
combined_repair_old_base:
        ld de,damage_map_2              ; patched: high byte, the old damage map
        add hl,de
        ld c,(hl)                       ; left
        inc l
        ld b,(hl)                       ; right
        ld a,(bg_moving_objects)
        or a
        jp nz,combined_stage_water_repair
; combined_static_repair_path: the repair of a row (patched by
; background_anchor_camera): combined_static_repair copies it from the
; other twin, combined_stage_cached_repair composes it again.
combined_static_repair_path:
        jp combined_static_repair       ; patched: static or cached repair
combined_static_repair:
        call combined_repair_address
        push hl
        ld a,h
        and ~(PAGE_DISTANCE >> 8) & 0xFF ; without the page bit
        cp UPPER_TWIN_0 >> 8            ; the upper twin
        ld a,h
        jp c,combined_stage_lower_twin
        sub TWIN_HIGH
        jp combined_stage_twin_ready
combined_stage_lower_twin:
        add a,TWIN_HIGH
combined_stage_twin_ready:
        ld h,a                          ; clean source
        pop de
        ld a,MAX_RECT_ROWS
        ld (water_period_capacity),a
        jp combined_water_repair_group
combined_stage_water_repair:
        call combined_repair_address
        push hl
        ld a,(scroll_light_water)
        or a
        jp nz,combined_light_repair_source
        ld a,(scroll_row)
        ld l,a
        ld h,water_low_residues >> 8
combined_repair_residue:
        ld a,0                          ; patched: residue of the top row
        sub (hl)
        jp nc,combined_repair_residue_ready
        add a,STAGE_PERIOD
combined_repair_residue_ready:
        inc a                           ; source rows before the wrap
        ld (water_period_capacity),a
        ld e,a
        ld a,STAGE_PERIOD
        sub e
        call water_row_address
        jp combined_water_repair_source_ready
combined_light_repair_source:
        ld a,(scroll_sea_camera)
        ld e,a
        ld a,(scroll_row)
        sub e
        and LIGHT_PERIOD - 1
        ld l,a
        neg
        add a,LIGHT_PERIOD              ; source rows before the wrap
        ld (water_period_capacity),a
        ld a,l
        call water_row_address
combined_water_repair_source_ready:
        ld a,l
        add a,c
        ld l,a
        ld a,h
        adc a,0
        ld h,a
        pop de
        jp combined_water_repair_group
combined_stage_repair_next:
        dec b
        jp nz,combined_stage_repair_row
        ret
combined_stage_cached_repair:
        ld a,c
        ld (scroll_left),a
        ld a,b
        ld (scroll_right),a
        exx
        push bc
        push de
        push hl
        call combined_position
        ld a,(bg_moving_objects)
        or a
        jp nz,combined_stage_cache_water
        call combined_water_gap
        jp nc,combined_stage_cache_water
        call combined_restore
combined_stage_cache_water:
        call combined_water
        call repair_core_registers
        pop hl
        pop de
        pop bc
        jp combined_stage_repair_next
; Out: HL and the DMA destination: the screen address of group C on scroll_row.
combined_repair_address:
        ld a,(scroll_row)
        ld l,a
        ld h,row_offset_low >> 8
        ld e,(hl)
        inc h
        ld d,(hl)
        ld hl,(scene_screen_base)
        add hl,de
        ld e,c
        ld d,0
        add hl,de
        out0 (DAR0L),l
        out0 (DAR0H),h
        ret
; combined_repair_registers: set the read segment of the repairs (the
; retained page, or the water pattern while ships move), the planes and
; the DMA banks. AF, BC, D changed.
combined_repair_registers:
        ld a,(bg_moving_objects)
        or a
        ld d,0                          ; retained source
        jp z,combined_repair_segment
        ld a,(water_pattern_segment)
        ld d,a
combined_repair_segment:
        ld bc,OAK_INDEX
        ld a,OAK_READ_SEGMENT
        out (c),a
        inc c
        out (c),d
        seq_set SEQ_MAP_MASK, ALL_PLANES
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        ret

        .section .text.repair_groups,"ax",@progbits

; Repair the run of following old rows that has the same bounds with one
; rectangle. In: HL source, DE target, C left, B right.
combined_water_repair_group:
        push hl
        push de
        ld a,(water_period_capacity)
        ld e,a
        ld a,(scroll_row)
        neg                             ; rows left in the view
        jp z,combined_group_visible_cap
        cp e
        jp nc,combined_group_visible_cap
        ld e,a
combined_group_visible_cap:
        ld a,(scene_ring_start)
        ld d,a
        ld a,(scroll_row)
        add a,d
        ld l,a                          ; physical row
        neg                             ; rows left in the physical list
        jp z,combined_group_physical_cap
        cp e
        jp nc,combined_group_physical_cap
        ld e,a
combined_group_physical_cap:
        ld a,e
        push af
        ld h,0
        add hl,hl
combined_group_old_base:
        ld de,damage_map_2+2            ; patched: high byte, the old damage map
        add hl,de
        pop af
        ld e,a
        ld d,1
        dec e
        jp z,combined_group_ready
combined_group_scan:
        ld a,(hl)
        cp c
        jp nz,combined_group_ready
        inc hl
        ld a,(hl)
        cp b
        jp nz,combined_group_ready
        inc hl
        inc d
        dec e
        jp nz,combined_group_scan
combined_group_ready:
        ld a,d
        ld (water_group_height),a
        pop de
        pop hl
        ld a,b
        sub c
        ld b,a                          ; width
        ld a,(water_group_height)
        ld c,a                          ; height
        out0 (DAR0H),d
combined_repair_call:
        call water_rectangle            ; patched: the repair core may take over
        ld a,(water_group_height)
        dec a                           ; extra rows
        exx
        ld e,a
        ld a,b
        sub e
        ld b,a
        ld a,l
        add a,e
        ld l,a
        jp combined_stage_repair_next
