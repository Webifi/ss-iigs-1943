; State planner: read the game state packet and write the drawing commands
; of the back page: the background plan, the sprites, the HUD and the
; cabinet pictures. The commands go to scene_out; scene_next runs them.

        .include "video.inc"
        .include "cabinet_layouts.inc"
        .include "stream.inc"
        .include "sprite_records.inc"
        .include "hud.inc"

        .global state_camera, state_plan, state_object_loop, state_hud, state_fg_row
        .global state_times56, state_word
        .global hud_batch
        .global hud_fixed_done
        .global scene_raw, scene_out, scene_screen_base
        .global scene_ring_start, scene_page, scene_items, scene_item, scene_xrec, scene_yrec
        .global scene_attr, scene_desc, scene_value
        .global scene_fg_camera, hud_p1_score
        .global scene_priority, scene_previous_foreground, scene_bounds, state_object_command
        .global hud_stream_scratch, scene_commands

        .equ HIDDEN_QUEUE_SIZE, 16      ; art_hidden_queue: 4 bytes for each hidden sprite
        .equ MISSING_ART, 0xEE          ; to the IIgs: a sprite has no art
        .equ SCORE_ENERGY_BYTES, PKT_TIME - PKT_SCORE ; P1 score digits, then energy cells
        .equ BLANK_ART, 0xFF            ; scene_desc: the art has no pixel
; The object record of the packet: the code word (code low, attribute
; high), then the x and the y position.
        .equ PAGES_TO_SEED, 2           ; cabinet_seed_pages: both game pages

; The planner state (secondsight.ld .planner_variables).
        .section .vars.scene,"aw",@nobits
scene_raw: .ds.b 2                      ; the state packet
scene_out: .ds.b 2                      ; the next drawing command
scene_screen_base: .ds.b 2              ; screen address of the ring start in the back page
scene_ring_start: .ds.b 2               ; the physical row of the ring start (0-255)
scene_page: .ds.b 2                     ; the back page: 0 or PAGE_DISTANCE >> 8
scene_items: .ds.b 2                    ; objects left
scene_item: .ds.b 2                     ; the next object in the packet
scene_xrec: .ds.b POSITION_RECORD       ; the x record of the object (sprite_records.inc)
scene_yrec: .ds.b POSITION_RECORD       ; the y record of the object
scene_sprite_base: .ds.b 2              ; screen address of the sprite's group 0, row 0
scene_attr: .ds.b 2                     ; code low, attribute high
scene_desc: .ds.b 4                     ; draw header: BBR, pointer
scene_count: .ds.b 2                    ; not 0: the sprite is clipped
scene_value: .ds.b 2                    ; x and y value of the object
scene_fg_camera: .ds.b 2                ; the foreground camera of the packet
hud_p1_score: .ds.b SCORE_ENERGY_BYTES  ; score digits, then energy cells
scene_priority: .ds.b 4                 ; the priority descriptor of a low sprite, or 0
scene_previous_foreground: .ds.b 2      ; the foreground camera of the last packet; 0xFFFF: none
scene_bounds: .ds.b 4                   ; the art bounds: left, right, first row, end row
state_object_command: .ds.b 2           ; the command of the current object
; The fixed HUD command stream while it runs (secondsight.ld .scratch).
        .section .vars.hud_stream_scratch,"aw",@nobits
hud_stream_scratch: .ds.b 0x100
; The drawing commands of a picture (secondsight.ld .commands).
        .section .vars.commands,"aw",@nobits
scene_commands: .ds.b 0x1000

        .section .text.state_plan_a,"ax",@progbits

; state_camera: read the cameras of the new state: the ring start, the
; screen base, the row cache and the ship alignment; copy the P1 score and
; energy; then the cabinet or the game camera (scroll_camera).
state_camera:
        ld hl,(stream_active_packet)
        ld (scene_raw),hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,e                          ; the sea camera
        neg                             ; ring start
        ld (play_new_start_row),a
        ld l,a
        ld h,0
        ld (scene_ring_start),hl
        call state_times56
        ld (scene_screen_base),hl
        ld a,(play_back_high)
        ld (scene_page),a
        or h
        ld h,a
        ld (scene_screen_base),hl
        ld hl,(scene_raw)
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (scene_fg_camera),de
        ld hl,(scene_previous_foreground)
        ex de,hl
        ld (scene_previous_foreground),hl
        or a
        sbc hl,de
        call background_cache_delta     ; bound the new foreground rows
        call ship_alignment_view
; Cabinet pictures skip the live planner, but the ending header needs the
; score and energy of player 1: copy them before the split.
        ld hl,(scene_raw)
        push de
        ld de,STREAM_SCORE
        add hl,de
        pop de
        ld de,hud_p1_score
        ld bc,SCORE_ENERGY_BYTES
        ldir
        ld hl,hud_p1_score
        ld b,LEADING_DIGITS
1:      ld a,(hl)
        or a
        jr nz,state_score_ready
        ld (hl),GLYPH_BLANK
        inc hl
        djnz 1b
state_score_ready:
        ld a,(cabinet_mode)
        and LAYOUT_PAGE_MASK
        cp CAB_PAGE_FIRST
        jr c,state_game_camera
        cp PAGE_ENDING_END
        jp c,cabinet_camera
state_game_camera:
        jp scroll_camera

; state_plan: plan the back page: a cabinet picture (cabinet_draw, its
; overlay and the hitch scene stream), or the game: the background plan,
; the receive of the next packet, the HUD values, the objects (the low
; sprites first) and the HUD.
state_plan:
        ld a,(cabinet_mode)
        and LAYOUT_PAGE_MASK
        cp CAB_PAGE_FIRST
        jr c,cabinet_plan_done
        cp PAGE_ENDING_END
        jr nc,cabinet_plan_done
cabinet_static_plan:
        ld de,scene_commands
        ld hl,cabinet_draw
        call state_word
        ld hl,(scene_screen_base)
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
; The cabinet dispatch returns the mode, or enters the planner of its
; ending actors with the same stack.
        call cabinet_actor_dispatch
        and LAYOUT_PAGE_MASK
        cp PAGE_POWER_ON
        jr z,cabinet_static_ready       ; no extra text
        ld hl,cabinet_overlay
        call state_word
        ld hl,(scene_screen_base)
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
cabinet_static_ready:
        ld hl,hitch_scene_stream
        call state_word
        ld hl,scene_end
        call state_word
        ld hl,scene_commands
        ld (stream_active_packet),hl
        ld a,PAGES_TO_SEED
        ld (cabinet_seed_pages),a       ; seed both game pages
        ld hl,0xFFFF
        ld (scene_previous_foreground),hl ; the foreground rows are not valid
        ld hl,0
        ld (scroll_valid),hl            ; no page repairs
; No sprite work follows to arm the next receive on a cabinet picture.
        ret
cabinet_plan_done:
        xor a
        ld (cabinet_keep_picture),a
        ld (cabinet_rank_presentation),a
        dec a
        ld (cabinet_page_signature),a   ; the cabinet pages are not valid
        ld (cabinet_page_signature + 1),a
        call sprite_cache_begin
        call scroll_begin               ; the damage of the previous page
        ld de,scene_commands
        ld (scene_out),de

        .section .text.state_plan_b,"ax",@progbits

; After the background plan only CPU latch drawing follows. DMA channel 0
; is done, so channel 1 can take the next state packet with no burst that
; blocks the IIgs event channel. The other packet buffer is separate.
        ld de,(scene_out)
        ld hl,stream_arm_next
        call state_word
        ld (scene_out),de

        .section .text.state_plan_c,"ax",@progbits

        call game_hud_values
        call state_object_order
state_object_loop:
        ld hl,(scene_items)
        ld a,l
        or h
        jp z,state_object_pass_end
        dec hl
        ld (scene_items),hl
        ld hl,(scene_item)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (scene_attr),de
        ld a,(hl)
        ld (scene_value),a
        inc hl
        ld a,(hl)
        ld (scene_value + 1),a
        inc hl
        ld (scene_item),hl
state_object_pass:
        jr state_object_any             ; patched: 0 skips the low sprites
        ld a,d
        and ATTR_LOW_PALETTE
        cp LOW_PALETTES                 ; palettes 10 and 11: drawn first
        jp z,state_object_loop
state_object_any:
; The pens of sprite 0 are all transparent in every palette.
        ld a,d
        and ATTR_CODE_HIGH              ; code high bits
        or e
        jp z,state_object_loop
; The x and y records are build tables: the exact columns, rows and repair
; bounds of each position, never pixel math.
        set_io BBR, x_records__bbr      ; both record tables
        ld a,(scene_value)
        ld l,a
        ld h,0
        .rept 3
        add hl,hl                       ; x POSITION_RECORD
        .endr
        push de
        ld de,x_records__ptr
        add hl,de
        pop de
        ld de,scene_xrec
        .rept 8
        ldi
        .endr
        ld a,(scene_xrec + XREC_WIDTH)
        or a
        jp z,state_hidden
        ld a,(scene_attr + 1)
        and ATTR_Y8                     ; bit 8 of the y position
        .rept 4
        rrca
        .endr
        ld h,a
        ld a,(scene_value + 1)
        ld l,a
        .rept 3
        add hl,hl
        .endr
        push de
        ld de,y_records__ptr
        add hl,de
        pop de
        ld de,scene_yrec
        .rept 8
        ldi
        .endr
        ld a,(scene_yrec + YREC_HEIGHT)
        or a
        jp z,state_hidden
        call game_low_hidden            ; a low sprite fully under the foreground
        jp c,state_object_loop
        ld hl,(scene_screen_base)
        ld de,(scene_yrec + YREC_OFFSET)
        add hl,de
        ld de,(scene_xrec + XREC_GROUP)
        add hl,de
        ld (scene_sprite_base),hl
        call sprite_cache_object
        jp z,state_object_loop          ; a transparent sprite
state_palette_found:
        ld de,scene_bounds
        .rept 4
        ldi
        .endr
        ld a,(scene_yrec + YREC_CLIPPED)
        or a
        jr z,state_art_bounds_ready     ; all rows of the tile are visible
        push hl
        call state_art_visible
        pop hl
        jp z,state_object_loop          ; all occupied rows are off the screen
state_art_bounds_ready:
        ld a,(scene_desc)
        cp BLANK_ART
        jp z,state_object_loop
        ld de,(scene_out)
        ld a,(scene_xrec + XREC_CLIPPED)
        ld b,a
        ld a,(scene_yrec + YREC_CLIPPED)
        or b
        ld (scene_count),a
        ld hl,native_object
        jr z,state_handler
        ld hl,native_object_clipped
state_handler:
        ld (state_object_command),de
        .irp word,hl,scene_desc,scene_desc+2,scene_sprite_base
        .ifnc \word,hl
        ld hl,(\word)
        .endif
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        .endr
        ld a,(scene_count)
        or a
        jr z,state_object_ready
        ld a,(scene_xrec + XREC_VISIBLE)
        ld l,a
        ld h,0
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld hl,(scene_yrec + YREC_ROWS)
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
state_object_ready:
        ld (scene_out),de
        call sprite_damage_bounds       ; mark the sprite rows for repair
        ld hl,(scene_priority)
        ld a,h
        or l
        jp z,state_no_priority          ; an ordinary sprite
; The exact path clips against the foreground; skip it when no foreground
; lies under the sprite.
        call state_low_covered
        jp nc,state_no_priority
        ld hl,scene_priority
        ld de,scene_priority
        call state_unpack_descriptor
        ld de,(state_object_command)
        ld hl,native_object_priority
        call state_word
        .irp word,scene_priority,scene_priority+2,scene_sprite_base
        ld hl,(\word)
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        .endr
        ld a,(scene_xrec + XREC_VISIBLE)
        ld l,a
        ld h,0
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld hl,(scene_yrec + YREC_ROWS)
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld hl,(scene_fg_camera)
        push de
        ld de,PAGE_ROWS - 1
        add hl,de
        pop de
        ld bc,(scene_yrec + YREC_TOP)
        or a
        sbc hl,bc
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld hl,(scene_xrec + XREC_GROUP)
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld (scene_out),de
state_no_priority:
        jp state_object_loop

; state_hud: the end of the object loop: the HUD (hud_batch), the attract
; overlay, scene_end; the commands start at scene_commands.
state_hud:
        call state_hud_damage           ; repair the HUD on the next use of the page
        ld a,(cabinet_mode)
        cp CAB_PAGE_FIRST
        jr nc,cabinet_no_game_hud       ; the cabinet owns the header
        ld de,(scene_out)
        ld hl,hud_batch
        call state_word
        ld hl,(scene_screen_base)
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld (scene_out),de
cabinet_no_game_hud:
        ld a,(cabinet_mode)
        or a
        jr z,cabinet_overlay_absent     ; no attract overlay
        ld de,(scene_out)
        ld hl,cabinet_overlay
        call state_word
        ld hl,(scene_screen_base)
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld (scene_out),de
cabinet_overlay_absent:
        ld de,(scene_out)
        ld hl,scene_end
        call state_word
        ld hl,scene_commands
        ld (stream_active_packet),hl
        ret
; state_missing: stop and tell the IIgs that a sprite has no art.
state_missing:
        set_io CARD_HOST, MISSING_ART
        jr state_missing

; state_hidden: queue a hidden object for the prefetch (art_hidden_queue:
; the code word and the phase of each).
state_hidden:
        ld a,(art_hidden_count)
        cp HIDDEN_QUEUE_SIZE
        jp nc,state_object_loop
        ld l,a
        inc a
        ld (art_hidden_count),a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,art_hidden_queue
        add hl,de
        ld de,(scene_attr)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(scene_value)
        and 3                           ; phase
        ld (hl),a
        jp state_object_loop

; state_art_visible: Out: NZ when an occupied row of the art is on the
; screen. DE, HL changed.
state_art_visible:
        ld hl,(scene_yrec + YREC_TOP)
        ld a,(scene_bounds + 2)
        ld e,a
        ld d,0
        add hl,de
        bit 7,h
        jr nz,state_art_top_clipped
        ld a,h
        or a
        jr nz,state_art_invisible       ; below the screen
        jr state_art_visible_yes
state_art_top_clipped:
        ld a,(scene_bounds + 3)
        ld e,a
        add hl,de
        bit 7,h
        jr nz,state_art_invisible       ; above the screen
        ld a,h
        or l
        ret z
state_art_visible_yes:
        ld a,1
        or a
        ret
state_art_invisible:
        xor a
        ret

; state_fg_row: append the command for the prepared foreground row
; scene_value (native_fg_row).
state_fg_row:
        ld de,(scene_out)
        ld hl,native_fg_row
        call state_word
        ld hl,(scene_value)
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld (scene_out),de
        ret

; state_times56: HL = L x 56 (GROUPS_PER_ROW), from row_offset_low; H is 0
; on entry. DE changed; A kept.
state_times56:
        ld h,row_offset_low >> 8
        ld e,(hl)
        inc h
        ld d,(hl)
        ex de,hl
        ret
        .if GROUPS_PER_ROW != 56
        .error "state_times56 multiplies by 56 through row_offset_low"
        .endif

; state_word: append HL to the commands at DE. A changed.
state_word:
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ret

; The fixed HUD stream (native_sprites places it).
state_hud_fixed_pointer:
        .word state_hud_fixed_address

; hud_batch: the HUD command. The fixed geometry stays resident; the
; renderer reads each template directly, with no command list for each
; picture: the fixed HUD stream runs as a stack from hud_stream_scratch,
; then the HUD templates (hud.s). Stack in: the display base.
hud_batch:
        pop hl
        ld (hud_page_base),hl
        ld (hud_caller_sp),sp
state_hud_fixed_bank:
        set_io BBR, state_hud_fixed_bbr
        ld hl,(state_hud_fixed_pointer)
        ld de,hud_stream_scratch
state_hud_fixed_size:
        ld bc,state_hud_fixed_bytes
        ldir
        ld sp,hud_stream_scratch
        ret                             ; to the first fixed HUD pattern
hud_fixed_done:
        ld sp,(hud_caller_sp)

        .section .text.state_object_order,"ax",@progbits

; The arcade draws the sprites of palettes 10 and 11 below the foreground
; and below every other sprite. A scan of the packet gives the object loop
; each low sprite alone; then the loop takes the packet again and skips
; the low sprites.
        .equ ORDER_SKIP, state_object_any - state_object_pass - 2
state_object_order:
        ld hl,(scene_raw)
        ld de,STREAM_OBJECT_COUNT
        add hl,de
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld (order_items + 1),bc
        ld a,c                          ; the pools hold fewer than 256 sprites
        ld (order_scan_left + 1),a
        ld de,STREAM_OBJECTS - STREAM_OBJECT_COUNT - 1
        add hl,de
        ld (order_item + 1),hl
        inc hl                          ; the attribute of the first sprite
        ld (order_scan_at + 1),hl
        ld a,ORDER_SKIP
        ld (state_object_pass + 1),a    ; the low sprites pass no test
        ld (order_found + 1),a
        xor a
        ld (order_phase + 1),a
        ld h,a
        ld l,a
        ld (scene_items),hl             ; the loop starts with the scan
        ret

; state_low_covered: Out: carry clear when no foreground lies under the low
; sprite: each of its rows has no foreground (row class 0), or the sprite
; lies inside the row's open water (water_left_bounds, view groups at pan
; 0). Rows that are not ready until after planning (game_low_hidden) count
; as covered. AF, BC, DE, HL changed.
state_low_covered:
        ld hl,(row_cache_cull)
        ld a,h
        or a
        jr nz,low_covered
        ld c,l
        ld hl,(scene_yrec + YREC_TOP)
        ld a,h
        or a
        jr nz,low_covered
        ld a,l
        cp c
        jr c,low_covered
        ld a,(scene_fg_camera)
        dec a                           ; plus 255
        sub l
        ld c,a                          ; the world row of the top
        ld a,(scene_xrec + XREC_GROUP + 1)
        or a
        jr nz,low_covered               ; partly left of the view
        ld a,(scene_value)
        and 3                           ; phase
        ld b,a
        ld hl,scene_xrec
        ld a,(bg_pan)
        srl a
        srl a
        add a,(hl)
        ld e,a
        ld a,(scene_bounds)
        add a,b
        srl a
        srl a
        add a,e
        ld e,a                          ; the left group
        ld a,(bg_pan)
        add a,3
        srl a
        srl a
        add a,(hl)
        ld d,a
        ld a,(scene_bounds + 1)
        add a,b
        add a,3                         ; round up to a group
        srl a
        srl a
        add a,d
        ld d,a                          ; the group after the right
        ld a,(scene_yrec + YREC_HEIGHT) ; visible rows
        ld b,a
        ld l,c
low_row:
        ld h,row_classes >> 8
        ld a,(hl)
        or a
        jr z,low_row_clear
        ld h,water_left_bounds >> 8
        ld a,e
        cp (hl)
        jr c,low_covered                ; left of the open water
        inc h                           ; water_right_bounds
        ld a,(hl)
        cp d
        jr c,low_covered                ; right of the open water
low_row_clear:
        dec l
        djnz low_row
        or a
        ret
low_covered:
        scf
        ret

; The end of the object loop: the next low sprite, then the others.
state_object_pass_end:
order_phase:
        ld a,0                          ; patched: 1 after the low sprites
        or a
        jp nz,state_hud
order_scan_at:
        ld hl,0                         ; patched: the next attribute
order_scan_left:
        ld b,0                          ; patched: the sprites not scanned
        ld a,b
        or a
        jr z,order_others
        ld de,PACKET_RECORD
order_scan:
        ld a,(hl)
        add hl,de
        and ATTR_LOW_PALETTE
        cp LOW_PALETTES                 ; palettes 10 and 11
        jr z,order_low
        djnz order_scan
        jr order_others
order_low:
        dec b
        ld (order_scan_at + 1),hl
        ld a,b
        ld (order_scan_left + 1),a
        xor a
        ld (order_found + 1),a
        ld de,-(PACKET_RECORD + 1)      ; from the next attribute to the record
        add hl,de
        ld (scene_item),hl              ; the low sprite
        ld hl,1
        ld (scene_items),hl
        jp state_object_loop
order_others:
        ld a,1
        ld (order_phase + 1),a
order_found:
        ld a,ORDER_SKIP                 ; patched: 0 when there are low sprites
        ld (state_object_pass + 1),a
order_items:
        ld hl,0                         ; patched: the object count
        ld (scene_items),hl
order_item:
        ld hl,0                         ; patched: the first object
        ld (scene_item),hl
        jp state_object_loop

        .section .text.planner_hitch_bridges,"ax",@progbits

; Rare bridges at the planner tail. hitch_scene.install_common patches the
; call targets after the common mask allocations.
        .global hitch_scene_coverage_call
hitch_scene_stream:
        call hitch_scene_prepare_common
        jp stream_arm_next
hitch_scene_coverage_call:
        call game_coverage_row
hitch_scene_coverage_map:
        ld a,bank_code__load__cbr
        out0 (CBR),a
        ret

        .section .text.special_draw_bridge,"ax",@progbits

; In a special picture, run the special painter in the inactive packet
; buffer before the next receive is armed.
        .global special_draw_bridge
special_draw_bridge:
        ld a,(scene_effect_flags)
        and SPF_OVERLAY                 ; the special overlay
        jp z,special_draw_arm
        ld de,special_draw_arm
        push de                         ; the painter returns here
        ld a,(stream_receive + 1)
        xor stream_other                ; the inactive buffer
        ld h,a
        ld l,0
        jp (hl)
special_draw_arm:
        ld a,(stream_receive + 1)
        jp stream_arm_other             ; the arm code after the load of stream_arm_next

        .section .text.native_fg_row,"ax",@progbits

; Foreground row command: install the prepared row of the world row.
; Stack in: world row.
        .global native_fg_row
native_fg_row:
        pop hl
        ld (rows_world_row),hl
        jp game_coverage_row
