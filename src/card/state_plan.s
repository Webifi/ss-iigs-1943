; State planner: read the game state packet and write the drawing commands
; of the back page: the background plan, the sprites, the HUD and the
; cabinet pictures. The commands go to scene_out; scene_next runs them.

        .include "video.inc"

        .global state_camera, state_plan, state_object_loop, state_hud, state_fg_row
        .global state_times56, state_word, state_restore_handlers, state_hud_restore_bank
        .global state_hud_restore_pointer, state_hud_fixed_pointer, hud_batch
        .global state_hud_fixed_bank, state_hud_fixed_size, hud_fixed_done
        .global scene_raw, scene_out, scene_repair, scene_restore_start, scene_screen_base
        .global scene_ring_start, scene_page, scene_items, scene_item, scene_xrec, scene_yrec
        .global scene_sprite_base, scene_attr, scene_desc, scene_count, scene_value
        .global scene_fg_camera, scene_previous, hud_p1_score

        .equ COMMANDS, 0x4800           ; the drawing commands of a picture
        .equ PAUSE_MODE, 0x7F           ; cabinet_mode values
        .equ FIRST_CABINET, 3
        .equ AFTER_CABINET, 30
        .equ WARNING, 5
        .equ X_RECORDS, 0xC000          ; 8 bytes for each sprite x, through BBR 7
        .equ Y_RECORDS, 0xC800          ; 8 bytes for each sprite y, through BBR 7
        .equ RECORDS_BBR, 7
        .equ HIDDEN_QUEUE_SIZE, 16
        .equ MISSING_ART, 0xEE          ; to the IIgs: a sprite has no art

; Packet: sea camera, foreground camera, ..., object count (+6), score and
; energy (+8), weapon state (+24), objects (+26, 4 bytes each).
        .equ PACKET_OBJECT_COUNT, 6
        .equ PACKET_SCORE, 8
        .equ PACKET_OBJECTS, 26

; The x record: left (2), width bits, visible columns, ..., foreground
; columns (+5). The y record: top (2), visible rows (2), top x 56 (+4),
; visible (+6), clipped rows (+7).

        .section .vars.scene,"aw",@nobits
scene_raw: .ds.b 2                      ; the state packet
scene_out: .ds.b 2                      ; the next drawing command
scene_repair: .ds.b 2
scene_restore_start: .ds.b 2
scene_screen_base: .ds.b 2              ; screen address of the ring start in the back page
scene_ring_start: .ds.b 2
scene_page: .ds.b 2
scene_items: .ds.b 2                    ; objects left
scene_item: .ds.b 2                     ; the next object in the packet
scene_xrec: .ds.b 8
scene_yrec: .ds.b 8
scene_sprite_base: .ds.b 2
scene_attr: .ds.b 2                     ; code low, attribute high
scene_desc: .ds.b 4                     ; draw header: BBR, pointer
scene_count: .ds.b 2
scene_hud_pointer: .ds.b 2
scene_value: .ds.b 2                    ; x and y value of the object
        .ds.b 8
scene_fg_camera: .ds.b 2
scene_fg_pointer: .ds.b 2
scene_previous: .ds.b 4                 ; the foreground camera of each page
hud_p1_score: .ds.b 16                  ; score digits, then energy cells

        .section .text.state_plan_a,"ax",@progbits

; Read the cameras of the new state.
state_camera:
        ld hl,(stream_active_packet)
        ld (scene_raw),hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (scene_fg_camera),de         ; the sea camera for now
        ld a,e
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
        ld a,(scene_page)
        or a
        ld hl,scene_previous
        jr z,state_page_camera
        inc hl
        inc hl
state_page_camera:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        dec hl
        dec hl
        ld bc,(scene_fg_camera)
        ld (hl),c
        inc hl
        ld (hl),b
        ld h,b
        ld l,c
        or a
        sbc hl,de
        ld a,l
        ld (play_back_row_count),a      ; rows to copy back on this page
        ld (state_back_rows),a
        ld hl,(play_world)
        dec h                           ; world - 256
        ex de,hl
        ld hl,(scene_fg_camera)
        or a
        sbc hl,de
        ld a,l
        ld (play_new_row_count),a
        ld (state_new_rows),a
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
        ld (state_foreground_delta),a
        call ship_alignment_view
; Cabinet pictures skip the live planner, but the ending header needs the
; score and energy of player 1: copy them before the split.
        ld hl,(scene_raw)
        push de
        ld de,PACKET_SCORE
        add hl,de
        pop de
        ld de,hud_p1_score
        ld bc,16
        ldir
        ld hl,hud_p1_score
        ld b,7                          ; leading digits
1:      ld a,(hl)
        or a
        jr nz,state_score_ready
        ld (hl),10                      ; blank
        inc hl
        djnz 1b
state_score_ready:
        ld a,(cabinet_mode)
        and 0x7F
        cp PAUSE_MODE
        jp z,cabinet_camera
        cp FIRST_CABINET
        jr c,state_game_camera
        cp AFTER_CABINET
        jp c,cabinet_camera
state_game_camera:
        jp scroll_camera

; Plan the back page.
state_plan:
        ld a,(cabinet_mode)
        and 0x7F
        cp PAUSE_MODE
        jr z,cabinet_static_plan
        cp FIRST_CABINET
        jr c,cabinet_plan_done
        cp AFTER_CABINET
        jr nc,cabinet_plan_done
cabinet_static_plan:
        ld de,COMMANDS
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
        and 0x7F
        cp WARNING
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
        ld hl,COMMANDS
        ld (stream_active_packet),hl
        ld a,2
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
        ld hl,(scene_raw)
        ld a,h
        and 0xC0                        ; the packet buffer
        add a,4                         ; its command area
        ld d,a
        ld e,0
        ld (scene_out),de
        add a,0x2C                      ; its repair area
        ld h,a
        ld l,0
        ld (scene_restore_start),hl
        ld de,COMMANDS
        ld (scene_out),de
        ld bc,0                         ; no repair command list
        ld hl,0x7002                    ; unused repair scratch
        ld (scene_repair),hl

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
        and 0x0E
        cp 0x0A                         ; palettes 10 and 11: drawn first
        jp z,state_object_loop
state_object_any:
; The pens of sprite 0 are all transparent in every palette.
        ld a,d
        and 0xE0                        ; code high bits
        or e
        jp z,state_object_loop
; The x and y records are build tables: the exact columns, rows and repair
; bounds of each position, never pixel math.
        set_io BBR, RECORDS_BBR
        ld a,(scene_value)
        ld l,a
        ld h,0
        .rept 3
        add hl,hl
        .endr
        push de
        ld de,X_RECORDS
        add hl,de
        pop de
        ld de,scene_xrec
        ld bc,8
        .rept 8
        ldi
        .endr
        ld a,(scene_xrec + 4)
        or a
        jp z,state_hidden
        ld a,(scene_attr + 1)
        and 0x10                        ; bit 8 of the y position
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
        ld de,Y_RECORDS
        add hl,de
        pop de
        ld de,scene_yrec
        ld bc,8
        .rept 8
        ldi
        .endr
        ld a,(scene_yrec + 6)
        or a
        jp z,state_hidden
        call game_low_hidden            ; a low sprite fully under the foreground
        jp c,state_object_loop
        ld hl,(scene_screen_base)
        ld de,(scene_yrec + 4)
        add hl,de
        ld de,(scene_xrec)
        add hl,de
        ld (scene_sprite_base),hl
        call sprite_cache_object
        jp z,state_object_loop          ; a transparent sprite
        jr state_palette_found
state_palette_found:
        ld de,scene_bounds
        ld bc,4
        .rept 4
        ldi
        .endr
        ld a,(scene_yrec + 7)
        or a
        jr z,state_art_bounds_ready     ; all rows of the tile are visible
        push hl
        call state_art_visible
        pop hl
        jp z,state_object_loop          ; all occupied rows are off the screen
state_art_bounds_ready:
        ld a,(scene_desc)
        cp 0xFF                         ; blank art
        jp z,state_object_loop
        ld de,(scene_out)
        ld a,(scene_xrec + 3)
        ld b,a
        ld a,(scene_yrec + 7)
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
        ld a,(scene_xrec + 2)
        ld l,a
        ld h,0
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld hl,(scene_yrec + 2)
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
state_object_ready:
        ld (scene_out),de
        call scroll_mark_object
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
        ld de,(scene_out)
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
        ld a,(scene_xrec + 2)
        ld l,a
        ld h,0
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld hl,(scene_yrec + 2)
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld hl,(scene_fg_camera)
        push de
        ld de,255
        add hl,de
        pop de
        ld bc,(scene_yrec)
        or a
        sbc hl,bc
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld hl,(scene_xrec)
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld (scene_out),de
state_no_priority:
        jp state_object_loop

state_hud:
        call state_hud_damage           ; repair the HUD on the next use of the page
        ld a,(cabinet_mode)
        cp FIRST_CABINET
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
        ld hl,COMMANDS
        ld (stream_active_packet),hl
        ret
state_missing:
        set_io CARD_HOST, MISSING_ART
        jr state_missing

; Queue a hidden object for the prefetch.
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

; Out: NZ when an occupied row of the art is on the screen.
state_art_visible:
        ld hl,(scene_yrec)
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

; Command for one prepared foreground row.
state_fg_row:
        ld de,(scene_out)
        ld hl,native_fg_row
        call state_word
        ld hl,(scene_value)
        ld h,0
        .rept 6
        add hl,hl
        .endr
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld hl,(scene_value)
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld (scene_out),de
        ret

; HL = HL x 56.
state_times56:
        .rept 3
        add hl,hl
        .endr
        ld d,h
        ld e,l
        .rept 3
        add hl,hl
        .endr
        or a
        sbc hl,de
        ret

; Append HL to the commands at DE.
state_word:
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ret

state_restore_handlers:
        .word restore_1, restore_2, restore_3, restore_4, restore_5
; The HUD restore geometry and the fixed HUD stream (flight_loop and
; native_sprites place them).
state_hud_restore_bank:
        .word state_hud_restore_bbr
state_hud_restore_pointer:
        .word state_hud_restore_address
state_hud_fixed_pointer:
        .word state_hud_fixed_address

; HUD command. The fixed geometry stays resident; the renderer reads each
; template directly, with no command list for each picture. Stack in: the
; display base.
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
        ld de,PACKET_OBJECT_COUNT
        add hl,de
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld (order_items + 1),bc
        ld a,c                          ; the pools hold fewer than 256 sprites
        ld (order_scan_left + 1),a
        ld de,PACKET_OBJECTS - PACKET_OBJECT_COUNT - 1
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

; Out: carry clear when no foreground lies under the low sprite: each of
; its rows has no foreground (row class 0), or the sprite lies inside the
; row's open water (water_left_bounds, view groups at pan 0). Rows that
; are not ready until after planning (game_low_hidden) count as covered.
state_low_covered:
        ld hl,(row_cache_cull)
        ld a,h
        or a
        jr nz,low_covered
        ld c,l
        ld hl,(scene_yrec)
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
        ld a,(scene_xrec + 1)
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
        ld a,(scene_yrec + 6)           ; visible rows
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
        ld de,4
order_scan:
        ld a,(hl)
        add hl,de
        and 0x0E
        cp 0x0A                         ; palettes 10 and 11
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
        ld de,-5
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
        .global hitch_scene_stream, hitch_scene_coverage_call, hitch_scene_coverage_map
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
        .global special_draw_bridge, special_draw_arm
special_draw_bridge:
        ld a,(scene_effect_flags)
        and 0x20                        ; the special overlay
        jp z,special_draw_arm
        ld de,special_draw_arm
        push de                         ; the painter returns here
        ld a,(stream_receive + 1)
        xor 0xC0                        ; the inactive buffer
        ld h,a
        ld l,0
        jp (hl)
special_draw_arm:
        ld a,(stream_receive + 1)
        jp stream_arm_next + 3          ; the arm code after this load

        .section .text.hitch_common_reserved,"ax",@progbits

; Space for the scene bridges (hitch_scene.s .text.hitch_scene_common).
        .global hitch_common_reserved
hitch_common_reserved:
        .fill 44, 1, 0

        .section .text.native_fg_row,"ax",@progbits

; Foreground row command: install the prepared row of the world row.
; Stack in: cache offset (unused), world row.
        .global native_fg_row
native_fg_row:
        pop hl
        pop hl
        ld (rows_world_row),hl
        jp game_coverage_row
