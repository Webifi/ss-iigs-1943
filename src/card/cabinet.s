; Cabinet pictures: the attract text, the title demo, the warning, the
; ranking, the plane pages and the ending, drawn over the native scrolling
; picture from build-prepared glyphs, layouts and copy lists.

        .include "video.inc"
        .include "cabinet_config.inc"

        .global cabinet_overlay, cabinet_overlay_text, cabinet_overlay_next
        .global cabinet_glyph_ready, cabinet_overlay_finish, cab_damage_done
        .global cabinet_overlay_done, cab_live_map, cab_live_jump, cab_live_receive_map
        .global cab_live_receive_jump, cab_layout_map, cab_layout_pointer, cab_font_map
        .global cab_font_pointer, cab_pattern_map, cab_demo_count
        .global cab_demo_fast, cab_demo_next, cab_demo_prompt_sentinel, cab_demo_finish
        .global cabinet_glyph_static, cabinet_resolve_dynamic, cabinet_select_font
        .global cab_post_font_map, cab_post_font_pointer, cabinet_overlay_presentation
        .global cabinet_presentation_hud, cabinet_text_limit
        .global input_menu_receive, input_menu_clear, input_menu_layout
        .global cabinet_draw, cabinet_static_image, cabinet_ending_clear_bars
        .global cabinet_cached, cabinet_ranking, cabinet_rank_copy, cabinet_ending_cached
        .global cabinet_ending_foreground, cabinet_camera, cabinet_water_draw
        .global cabinet_plane_directory, cabinet_expand_2bit, cabinet_actor_dispatch
        .global cabinet_actor_plan, hitch_water_refresh, hitch_water_map, hitch_water_call
        .global hitch_scene_consume, hitch_scene_prepare_operand, hitch_scene_compose_call
        .global hitch_scene_compose_map
        .global cabinet_regular_field, cabinet_rank_load, cab_rank_map, cab_rank_pointer
        .global cabinet_presentation_live_entry, cab_demo_prompt_dispatch
        .global cabinet_rank_dispatch, cab_demo_finish_dispatch

; cabinet_mode: the presentation; bit 7 while its art uploads.
        .equ LOADING, 7
        .equ MODE_DEMO_PROMPT, 1
        .equ MODE_DEMO, 2
        .equ MODE_RANKING, 3
        .equ MODE_PLANE, 4
        .equ MODE_WARNING, 5
        .equ MODE_PLANE_RANKING, 16
        .equ MODE_ENDING, 17            ; 17-29: the ending
        .equ MODE_LATER_CREDITS, 20
        .equ MODE_RESULT, 30
        .equ MODE_POST_END, 74
        .equ MODE_INITIALS, 85
        .equ MODE_PAUSE, 127

        .equ HIDDEN_HALF, 0x3C00        ; the hidden twin of display page 0
        .equ GLYPH_BYTES, 16
        .equ ROW_GAP, GROUPS_PER_ROW - 2 ; after the two groups of a glyph row
        .equ VRAM_CBR, 0x92
        .equ ALTERNATE_FONT, cab_alternate_font
        .equ BLANK_RANK_GLYPH, 0x24

; Write one DAC colour; BC is VGA_DAC_WRITE_INDEX.
        .macro ending_colour index, red, green, blue
        ld a,\index
        out (c),a
        inc c
        .irp component,\red,\green,\blue
        ld a,\component
        out (c),a
        .endr
        dec c
        .endm

; Development timing slots (phase_times + offset).
        .equ TIMES_TEXT, phase_times + 0x4C
        .equ TIMES_TEXT_END, phase_times + 0x4E
        .equ TIMES_WATER, phase_times + 0x0C
        .equ TIMES_WATER_END, phase_times + 0x0E

; A layout record: screen offset (bit 14: dynamic field, bit 15: in front
; of the ending actors), glyph. 0xFFFF ends a list; 0xFF?? continues it at
; the bank and pointer that follow.

        .section .text.cabinet_overlay,"ax",@progbits

; Cabinet text command. Stack in: the screen base.
cabinet_overlay:
        pop hl
        ld (cab_dest),hl
        ld (cab_saved_sp),sp
        xor a
        ld (cab_foreground_filter),a
        ld a,(cabinet_keep_picture)
        or a
        jp nz,cabinet_overlay_done
; The packet mode tells the demo from live play; the loading bit belongs to
; the warning and the ending only.
        ld a,(cabinet_mode)
        or a
        jp z,cabinet_overlay_done
        bit LOADING,a
        jp nz,cabinet_overlay_done
        ld a,(cab_hidden_prepaint)
        or a
        jp nz,prepaint_text
        jp cabinet_overlay_presentation
cabinet_overlay_text:
        ld a,(cabinet_mode)
        phase_stamp TIMES_TEXT
        cp MODE_INITIALS
        jp z,cabinet_overlay_finish
        cp MODE_RANKING
        jp c,cab_demo_fast
        call cabinet_text_limit
        ld a,b
        cp MODE_DEMO                    ; the demo without the prompt
        jp nz,layout_select
        ld hl,(cab_demo_count)          ; the glyphs of the logo
        ld a,l
        ld (cab_overlay_count),a
        jp layout_select
prepaint_text:
        ld b,a
        cp 3                            ; an ending append
        jp nc,prepaint_budget
        ld a,96                         ; glyphs for one picture
        ld (cab_overlay_count),a
prepaint_budget:
        phase_stamp TIMES_TEXT
        ld a,b
        and 1                           ; the first pass
        jp z,layout_ready
        ld a,(cabinet_mode)
layout_select:
        cp MODE_PAUSE
        jp z,input_menu_layout
        ld hl,(cab_layout_map)
        ld a,l
        ld (cab_overlay_cursor + 2),a
        ld hl,(cab_layout_pointer)
        ld (cab_overlay_cursor),hl
layout_ready:
        write_mode 0
        oak_set OAK_WRITE_SEGMENT, 0
cabinet_overlay_next:
        ld a,(cab_overlay_count)
        inc a                           ; 0xFF: no limit
        jp z,count_ready
        dec a
        jp z,cabinet_overlay_finish
        dec a
        ld (cab_overlay_count),a
count_ready:
        ld a,(cab_overlay_cursor + 2)
        out0 (BBR),a
        ld hl,(cab_overlay_cursor)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        cp 0xFF
        jp z,overlay_tail
        ld a,(hl)
        inc hl
        ld (cab_overlay_cursor),hl
        bit 6,d                         ; a dynamic field
        jp z,cabinet_glyph_static
        res 6,d
        jp cabinet_resolve_dynamic
cabinet_glyph_ready:
        push af
        ld a,(cab_foreground_filter)
        or a
        jp z,glyph_visible
        bit 7,d                         ; in front of the actors
        jp nz,glyph_visible
        pop af
        jp cabinet_overlay_next
glyph_visible:
        res 7,d
        ld hl,(cab_dest)
        add hl,de
        ld (cab_row),hl
        call cabinet_select_font
        pop af
        ld e,a
        ld d,0
        ex de,hl
        add hl,hl
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
; A glyph address is in words. Below 0x6000 it is in common SRAM, else
; in a 4 KB descriptor bank.
        ld a,h
        cp 0x60
        jp c,common_glyph
        ld a,h
        .rept 3
        rrca
        .endr
        and 0x1F
        sub 0x0C                        ; BBR of the window
        out0 (BBR),a
        add hl,hl
        ld a,h
        and 0x0F
        or 0xC0                         ; BBR window
        ld h,a
        jp copy_glyph
common_glyph:
        add hl,hl
copy_glyph:
        ld de,cab_glyph
        ld bc,GLYPH_BYTES
        ldir
        ld hl,(cab_pattern_map)
        ld a,l
        out0 (BBR),a
        ld sp,cab_glyph
        ld hl,(cab_row)
        ld a,h
        .rept 4
        rrca
        .endr
        and 0x0F
        add a,VRAM_CBR
        out0 (CBR),a
        ld a,h
        and 0x0F
        or 0xE0                         ; CBR window
        ld h,a
; The 8 x 8 glyph fits the 8 KB destination window even when its first
; row is near a 4 KB boundary: 4095 + 7 * 56 + 1 < 8192. Run its eight
; prepared rows with no counter, no patched call and no mapping per row.
        ld de,ROW_GAP
        ld bc,VGA_SEQ_DATA
        .rept 7
        pop ix
        call glyph_row
        add hl,de
        .endr
        pop ix
        call glyph_row
        ld sp,(cab_saved_sp)
        jp cabinet_overlay_next
glyph_row:
        jp (ix)
overlay_tail:
        ld a,e
        inc a
        jp z,text_complete
        ld a,(hl)                       ; the bank of the continuation
        ld (cab_overlay_cursor + 2),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld (cab_overlay_cursor),hl
        jp cabinet_overlay_next
text_complete:
        inc a
        ld (cab_text_complete),a
cabinet_overlay_finish:
; The damage marking of the text runs in a descriptor helper.
cab_live_map:
        set_io CBR, bank_code__load__cbr
cab_live_jump:
        jp cab_live_helper
cab_live_receive_map:
        set_io CBR, bank_code__load__cbr
cab_live_receive_jump:
        jp cab_live_receive
cab_damage_done:
        phase_stamp TIMES_TEXT_END
        ld hl,(TIMES_TEXT)
        ld de,(TIMES_TEXT_END)
        or a
        sbc hl,de
        ld (cab_overlay_time),hl
        ld a,(cabinet_mode)
        ld (cab_overlay_mode),a
        ld a,(cab_overlay_pictures)
        inc a
        ld (cab_overlay_pictures),a
cabinet_overlay_done:
        ld sp,(cab_saved_sp)
        ret
; The BBR and pointer of each directory (cabinet_video.install).
cab_layout_map:
        .word cab_layout_bbr
cab_layout_pointer:
        .word cab_layout_address
cab_font_map:
        .word cab_font_bbr
cab_font_pointer:
        .word cab_font_address
cab_pattern_map:
        .word pattern_pages__load__bbr
cab_demo_count:
        .word cab_demo_logo_glyphs

        .section .text.cab_demo_fast,"ax",@progbits

; The title demo: prepared programs in a video RAM read plane, beside
; their converted pixels, write the logo and the prompt band by band. Each
; LDI loads the latches just before its write, so the instruction fetches
; from video RAM cannot change them.
cab_demo_fast:
        gc_set GC_MODE, 0x41            ; write mode 1
        gc_set GC_READ_MAP, 0
        oak_set OAK_WRITE_SEGMENT, 0
        ld bc,VGA_SEQ_DATA
        exx
        ld hl,cab_demo_logo_table
        ld (cab_overlay_cursor),hl
cab_demo_next:
        ld hl,(cab_overlay_cursor)
        ld a,(hl)
        or a
        jr z,cab_demo_list_end
        out0 (BBR),a                    ; the code and the pixels
        inc hl
        ld a,(hl)
        inc hl
        ld bc,OAK_INDEX
        ld d,a
        ld a,OAK_READ_SEGMENT
        out (c),a
        inc c
        out (c),d
        ld d,(hl)                       ; the read plane of the code
        inc hl
        ld bc,VGA_GC_INDEX
        ld a,GC_READ_MAP
        out (c),a
        inc c
        out (c),d
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (cab_row),de                 ; the pixels
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push de                         ; the program
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (cab_overlay_cursor),hl
        ld hl,(cab_dest)
        add hl,de
        ld a,h
        .rept 4
        rrca
        .endr
        and 0x0F
        add a,VRAM_CBR                  ; the destination band
        out0 (CBR),a
        ld a,h
        and 0x0F
        or 0xE0
        ld h,a
        ex de,hl
        ld hl,(cab_row)
        pop bc
        push bc
        ret                             ; run the prepared program
cab_demo_list_end:
        ld a,(cabinet_mode)
        cp MODE_DEMO_PROMPT
        jp nz,cab_demo_prompt_dispatch
; A separate sentinel ends the prompt table.
cab_demo_prompt_sentinel:
        ld hl,(cab_overlay_cursor)
        inc hl
        ld a,(hl)
        or a
        jr nz,cab_demo_finish
        ld hl,cab_demo_prompt_table
        ld (cab_overlay_cursor),hl
        jr cab_demo_next
cab_demo_finish:
        seq_set SEQ_MAP_MASK, 0x0F
        gc_set GC_READ_MAP, 0
        oak_set OAK_READ_SEGMENT, 0
        jp cab_demo_finish_dispatch

        .section .text.cabinet_presentation,"ax",@progbits

; Numeric fields are digit selectors. The initials after the ending already
; hold the glyph ID in the same field bytes.
cabinet_glyph_static:
        ld b,a
        xor a
        ld (cab_alternate_font),a
        ld a,b
        jp cabinet_glyph_ready
cabinet_resolve_dynamic:
        jp cabinet_rank_dispatch

; Out: HL the font directory, mapped in BBR.
cabinet_select_font:
        ld a,(cab_alternate_font)
        or a
        jr z,select_regular_font
        ld hl,(cab_post_font_map)
        ld a,l
        out0 (BBR),a
        ld hl,(cab_post_font_pointer)
        ret
select_regular_font:
        ld hl,(cab_font_map)
        ld a,l
        out0 (BBR),a
        ld hl,(cab_font_pointer)
        ret
cab_post_font_map:
        .word cab_post_font_bbr         ; cabinet_video.install
cab_post_font_pointer:
        .word cab_post_font_address

; The presentation dispatch has its own code; the common sprite planner
; keeps its 0x7000 limit.
cabinet_overlay_presentation:
        ld a,(cabinet_mode)
        cp MODE_RANKING
        jp z,cabinet_overlay_done
        cp MODE_PLANE_RANKING
        jp z,cabinet_overlay_done
        cp MODE_PLANE
        jp z,cab_demo_fast
        cp MODE_ENDING
        jr c,overlay_live
        cp MODE_RESULT
        jr nc,overlay_live
        call cabinet_ending_foreground
        ld a,1                          ; only the text in front of the actors
        ld (cab_foreground_filter),a
        jp cabinet_overlay_text
overlay_live:
        jp cabinet_presentation_live_entry

; The game HUD over a live presentation.
cabinet_presentation_hud:
        ld a,(cabinet_mode)
        cp MODE_ENDING
        ret c
        cp MODE_PAUSE
        ret z
        call game_hud_values
        ld hl,hud_return
        push hl
        ld hl,(cab_dest)
        push hl                         ; the display base
        jp hud_batch
hud_return:
        ld a,(cabinet_mode)
        cp MODE_RESULT
        ret nc
        jp cabinet_ending_clear_bars

; In: A the mode. Set cab_overlay_count: no limit, or the typed letters of
; an ending page.
cabinet_text_limit:
        ld b,a
        ld a,0xFF
        ld (cab_overlay_count),a
        ld a,b
        cp MODE_ENDING
        jr c,count_done
        cp MODE_POST_END
        jr nc,count_done
        ld a,(cabinet_values + 13)
        ld (cab_overlay_count),a
count_done:
        ret

        .section .text.cabinet_draw,"ax",@progbits

; The pause packet carries a bootstrap after its 40-byte trailer.
; In: HL the mode byte.
input_menu_receive:
        ld de,39
        add hl,de
        ld de,0x4000
        ld bc,175
        ldir
        jp 0x4000
; The packet no longer reaches the cabinet renderer; these entries keep
; its old dispatch paths, which cannot run.
input_menu_clear:
        ret
input_menu_layout:
        ret


; Cabinet picture command. Stack in: the page destination.
cabinet_draw:
        pop de
        ld (cab_page_destination),de
        call cabinet_cached
        ld a,(cabinet_keep_picture)
        or a
        ret nz
        ld a,(cabinet_mode)
        cp MODE_RANKING
        jp z,cabinet_ranking
        cp MODE_PLANE_RANKING
        jp z,cabinet_ranking
        ld a,(cabinet_mode)
        cp MODE_PAUSE
        jr z,input_menu_clear
        ld a,(cabinet_mode)
        and 0x7F
        cp MODE_WARNING
        jr z,cabinet_static_image
        cp MODE_ENDING
        jp c,cabinet_water_draw
        jp cabinet_ending_cached

; Copy the warning or ending image from the cabinet surface.
cabinet_static_image:
        ld a,(cabinet_mode)
        bit LOADING,a
        ret nz                          ; keep the old complete page
        cp MODE_ENDING
        jr c,image_palette_ready
        ld bc,VGA_DAC_WRITE_INDEX
        ending_palette
image_palette_ready:
        ld hl,CABINET_SURFACE & 0xFFFF
        ld (cab_source_row),hl
        xor a
        ld (cab_rows_left),a            ; 256 rows
        gc_set GC_MODE, 0x41            ; write mode 1
        seq_set SEQ_MAP_MASK, 0x0F
        oak_set OAK_READ_SEGMENT, CABINET_SURFACE >> 16
        oak_set OAK_WRITE_SEGMENT, 0
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        set_io BCR0H, 0
        ld a,(cabinet_mode)
        cp MODE_ENDING
        jr c,draw_row                   ; 64-group source rows
; Later credit pages keep the score header in the cache: restore only the
; tableau below it.
        cp MODE_LATER_CREDITS
        jr c,copy_ending_all
        set_io SAR0L, (CABINET_SURFACE + 16 * 56) & 0xFF
        set_io SAR0H, ((CABINET_SURFACE + 16 * 56) >> 8) & 0xFF
        ld hl,(cab_page_destination)
        ld de,16 * 56                   ; the header
        add hl,de
        set_io BCR0L, (240 * 56) & 0xFF
        set_io BCR0H, (240 * 56) >> 8
        jr copy_ending_to
copy_ending_all:
        set_io SAR0L, CABINET_SURFACE & 0xFF
        set_io SAR0H, (CABINET_SURFACE >> 8) & 0xFF
        ld hl,(cab_page_destination)
        set_io BCR0L, 0
        set_io BCR0H, 56                ; 256 rows of 56 groups
copy_ending_to:
        ld a,l
        out0 (DAR0L),a
        ld a,h
        out0 (DAR0H),a
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        set_io BCR0H, 0
        ret
draw_row:
        ld hl,(cab_source_row)
        ld a,l
        out0 (SAR0L),a
        ld a,h
        out0 (SAR0H),a
        ld bc,64                        ; source pitch
        add hl,bc
        ld (cab_source_row),hl
        ld hl,(cab_page_destination)
        ld a,l
        out0 (DAR0L),a
        ld a,h
        out0 (DAR0H),a
        ld bc,GROUPS_PER_ROW
        add hl,bc
        ld (cab_page_destination),hl
        set_io BCR0L, GROUPS_PER_ROW
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        ld a,(cab_rows_left)
        dec a
        ld (cab_rows_left),a
        jr nz,draw_row
        ret

; Copy HEIGHT rows from ROW of the tableau to the same rows of cab_dest.
        .macro clear_strip row, height
        set_io SAR0L, (CABINET_SURFACE + \row * 56) & 0xFF
        set_io SAR0H, ((CABINET_SURFACE + \row * 56) >> 8) & 0xFF
        ld hl,(cab_dest)
        ld de,\row * 56
        add hl,de
        ld a,l
        out0 (DAR0L),a
        ld a,h
        out0 (DAR0H),a
        set_io BCR0L, (\height * 56) & 0xFF
        set_io BCR0H, (\height * 56) >> 8
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        .endm

; The ending keeps the score header, but has no energy and weapon strip or
; boss bar: restore those two strips from the same tableau.
cabinet_ending_clear_bars:
        gc_set GC_MODE, 0x41            ; write mode 1
        seq_set SEQ_MAP_MASK, 0x0F
        oak_set OAK_READ_SEGMENT, CABINET_SURFACE >> 16
        oak_set OAK_WRITE_SEGMENT, 0
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        clear_strip 32, 8               ; the energy and weapon strip
        clear_strip 240, 16             ; the boss bar rows
        set_io BCR0H, 0
        ret

        .section .text.cabinet_plane,"ax",@progbits

; Keep the cabinet picture when the mode, the camera and the values are
; the same as on this page before. Out: cabinet_keep_picture.
cabinet_cached:
        xor a
        ld (cabinet_keep_picture),a
        ld a,(cabinet_mode)
        and 0x7F
        cp MODE_ENDING
        ret nc
        ld a,(scroll_page_index)
        add a,cab_page_state & 0xFF
        ld l,a
        ld h,cab_page_state >> 8
        ld c,0                          ; changed
        .irp value,cabinet_mode,scene_fg_camera+1,cabinet_values
        ld a,(\value)
        ld b,(hl)
        ld (hl),a
        xor b
        or c
        ld c,a
        inc l
        inc l
        .endr
        ld a,c
        or a
        ret nz
        inc a
        ld (cabinet_keep_picture),a
        ret

; The ranking: draw the water and the text into the hidden half of page 0
; over several pictures, then copy the complete picture in one DMA.
cabinet_ranking:
        ld a,(cabinet_rank_presentation)
        ld b,a
        ld a,(cabinet_mode)
        cp b
        jr z,rank_stage
        ld (cabinet_rank_presentation),a
        xor a
        ld (cab_rank_stage),a
rank_stage:
        ld a,(cab_rank_stage)
        cp 0xFF                         ; the picture is complete
        jr z,cabinet_rank_copy
        or a
        jr nz,rank_text
        ld hl,(scene_screen_base)
        push hl
        ld hl,HIDDEN_HALF
        ld (scene_screen_base),hl
        ld (cab_page_destination),hl
        call cabinet_water_draw
        pop hl
        ld (scene_screen_base),hl
        ld a,1                          ; the first text pass
        ld (cab_rank_stage),a
        jr rank_pending
rank_text:
        ld (cab_hidden_prepaint),a
        xor a
        ld (cab_text_complete),a
        ld hl,rank_text_done
        push hl
        ld hl,HIDDEN_HALF
        push hl
        jp cabinet_overlay
rank_text_done:
        ld a,(cab_text_complete)
        or a
        ld a,2                          ; the next text pass
        jr z,rank_more
        ld a,0xFF                       ; complete
rank_more:
        ld (cab_rank_stage),a
        xor a
        ld (cab_hidden_prepaint),a
rank_pending:
        ld a,0xFF
        ld (cabinet_page_signature),a
        ld (cabinet_page_signature + 1),a
        ld a,1                          ; keep the old complete picture
        ld (cabinet_keep_picture),a
        ret
cabinet_rank_copy:
        gc_set GC_MODE, 0x41            ; write mode 1
        seq_set SEQ_MAP_MASK, 0x0F
        oak_set OAK_READ_SEGMENT, 0
        oak_set OAK_WRITE_SEGMENT, 0
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        set_io SAR0L, HIDDEN_HALF & 0xFF
        set_io SAR0H, HIDDEN_HALF >> 8
        ld hl,(scene_screen_base)
        ld a,l
        out0 (DAR0L),a
        ld a,h
        out0 (DAR0H),a
        set_io BCR0L, 0
        set_io BCR0H, 56                ; 256 rows
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        set_io BCR0H, 0
        ret

; The ending: the actors move over a still tableau. Append the newly typed
; glyphs in the hidden half, then copy it in one DMA; the history is never
; drawn again for each picture. cab_prepared_letters is the prepared
; prefix length.
cabinet_ending_cached:
        ld a,(cabinet_mode)
        bit LOADING,a
        ret nz
        ld b,a
        ld a,(cabinet_rank_presentation)
        cp b
        jr z,end_append
        ld c,a                          ; the previous mode
        ld a,b
        ld (cabinet_rank_presentation),a
; These pages keep the whole prefix of the page before in the same SRAM
; list; its saved cursor stays valid after the new list arrives.
        .irp page,19,29
        cp \page
        jr nz,end_retained_\page
        ld a,c
        cp \page - 1
        jr z,end_append
        ld a,b
end_retained_\page:
        .endr
        xor a
        ld (cab_prepared_letters),a
        ld a,3                          ; the first append
        ld (cab_rank_stage),a
        ld hl,(scene_screen_base)
        push hl
        ld hl,HIDDEN_HALF
        ld (cab_page_destination),hl
        ld (cab_dest),hl
        call cabinet_static_image
        ld a,(cabinet_mode)
        cp MODE_LATER_CREDITS
        jr nc,end_header_ready          ; the header is kept
        call cabinet_presentation_hud
end_header_ready:
        pop hl
        ld (scene_screen_base),hl
end_append:
        ld a,(cab_prepared_letters)
        ld b,a
        ld a,(special_timer)            ; the typed letters
        sub b
        jp z,cabinet_rank_copy
        cp 17
        jr c,end_budget
        ld a,16                         ; letters for one picture
end_budget:
        ld (cab_overlay_count),a
        add a,b
        ld (cab_prepared_letters),a
        ld hl,(cab_append_cursor)
        ld (cab_overlay_cursor),hl
        ld a,(cab_append_cursor + 2)
        ld (cab_overlay_cursor + 2),a
        ld a,(cab_rank_stage)
        ld (cab_hidden_prepaint),a
        ld hl,end_text_done
        push hl
        ld hl,HIDDEN_HALF
        push hl
        jp cabinet_overlay
end_text_done:
        ld hl,(cab_overlay_cursor)
        ld (cab_append_cursor),hl
        ld a,(cab_overlay_cursor + 2)
        ld (cab_append_cursor + 2),a
        ld a,4                          ; continue the append
        ld (cab_rank_stage),a
        xor a
        ld (cab_hidden_prepaint),a
        jp cabinet_rank_copy

; Copy the tableau parts in front of the ending actors again, when the
; first actor is above the flag.
cabinet_ending_foreground:
        ld hl,(scene_raw)
        ld de,6                         ; actor count
        add hl,de
        ld a,(hl)
        or a
        ret z
        ld de,23                        ; Y of the first actor
        add hl,de
        ld a,(hl)
        cp CABINET_FLAG_FRONT_LIMIT
        ret nc
        gc_set GC_MODE, 0x41            ; write mode 1
        seq_set SEQ_MAP_MASK, 0x0F
        gc_set GC_READ_MAP, 0
        oak_set OAK_READ_SEGMENT, CABINET_SURFACE >> 16
        oak_set OAK_WRITE_SEGMENT, 0
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        set_io BCR0H, 0
        set_io CBR, VRAM_CBR + ((CABINET_COMMANDS & 0xFFFF) >> 12)
        ld hl,0xE000 + (CABINET_COMMANDS & 0x0FFF)
        ld bc,VGA_SEQ_DATA
; Copy: source (2), destination offset (2), groups, map mask; 0 groups end.
end_front_row:
        ld a,(hl)
        inc hl
        out0 (SAR0L),a
        ld a,(hl)
        inc hl
        out0 (SAR0H),a
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        or a
        ret z
        out0 (BCR0L),a
        ld a,(hl)
        inc hl
        out (c),a
        push hl
        ld hl,(cab_dest)
        add hl,de
        ld a,l
        out0 (DAR0L),a
        ld a,h
        out0 (DAR0H),a
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        pop hl
        jr end_front_row

; The camera of a cabinet picture: a fixed origin, the water phase from the
; packet.
cabinet_camera:
        ld a,(scene_page)
        rlca
        ld (scroll_page_index),a
        xor a
        ld (play_new_start_row),a
        ld (play_back_row_count),a
        ld hl,0
        ld (scene_ring_start),hl
        ld a,(scene_page)
        add a,4                         ; after the text area
        ld h,a
        ld (scene_screen_base),hl
        ld hl,(scene_raw)
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (scroll_sea_camera),de
        ex de,hl
        call water_mod30
        ld b,a
        ld a,16                         ; the water origin
        sub b
        jr nc,water_phase
        add a,30
water_phase:
        ld (water_stage_phase),a
        xor a
        ld (scroll_light_water),a
        ld a,(cabinet_mode)
        cp MODE_ENDING
        jr c,animate_water
        cp MODE_RESULT
        jr nc,animate_water
        xor a                           ; the ending keeps its fixed palette
        ld (water_active),a
        ret
animate_water:
        ld a,1
        ld (water_active),a
        ret

; Draw the stage water of a cabinet picture: 16 rows, then eight 30-row
; periods, in nine burst copies, not 256 row setups.
cabinet_water_draw:
        phase_stamp TIMES_WATER
        gc_set GC_MODE, 0x41            ; write mode 1
        seq_set SEQ_MAP_MASK, 0x0F
        oak_set OAK_READ_SEGMENT, normal_water__vseg
        oak_set OAK_WRITE_SEGMENT, 0
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0B, VGA_WINDOW >> 16
; The source is 30 rows. From row 14, a 256-row picture is 16 rows, then
; eight complete periods.
        set_io SAR0L, (normal_water__group + 14 * 56) & 0xFF
        set_io SAR0H, (normal_water__group + 14 * 56) >> 8
        ld hl,(cab_page_destination)
        ld a,l
        out0 (DAR0L),a
        ld a,h
        out0 (DAR0H),a
        ld de,16 * 56
        add hl,de
        set_io BCR0L, (16 * 56) & 0xFF
        set_io BCR0H, (16 * 56) >> 8
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        ld b,8
water_period:
        set_io SAR0L, normal_water__group & 0xFF
        set_io SAR0H, normal_water__group >> 8
        ld a,l
        out0 (DAR0L),a
        ld a,h
        out0 (DAR0H),a
        ld de,30 * 56
        add hl,de
        set_io BCR0L, (30 * 56) & 0xFF
        set_io BCR0H, (30 * 56) >> 8
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        djnz water_period
        phase_stamp TIMES_WATER_END
; The P-38 pose of the plane pages over the water.
        ld a,(cabinet_mode)
        bit LOADING,a
        ret nz
        ld a,(scene_fg_camera + 1)
        sub 0xE8                        ; the plane poses
        cp 8
        ret nc
        add a,a
        ld e,a
        ld d,0
        ld hl,cabinet_plane_directory
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,h
        .rept 4
        rrca
        .endr
        and 0x0F
        add a,VRAM_CBR                  ; the window of the pose copies
        out0 (CBR),a
        ld a,h
        and 0x0F
        or 0xE0
        ld h,a
        oak_set OAK_READ_SEGMENT, CABINET_SURFACE >> 16
        gc_set GC_READ_MAP, 0
; All addresses, the water under the transparent pixels and the widths are
; prepared. The DMA uses physical video RAM; the CPU window does not move.
plane_row:
        ld a,(hl)
        inc hl
        out0 (SAR0L),a
        ld a,(hl)
        inc hl
        out0 (SAR0H),a
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        or a
        ret z
        out0 (BCR0L),a
        push hl
        ld hl,(scene_screen_base)
        add hl,de
        ld a,l
        out0 (DAR0L),a
        ld a,h
        out0 (DAR0H),a
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        pop hl
        jr plane_row
cabinet_plane_directory:
        .irp pose,0,1,2,3,4,5,6,7
        .word CABINET_POSE_\pose
        .endr

        .section .text.cabinet_expand_2bit,"ax",@progbits

; Upload job: 2-bit cabinet pixels through a 4-colour palette.
cabinet_expand_2bit:
        .irp pen,0,1,2,3
        ld a,CABINET_PALETTE_\pen
        ld (world_palette + \pen),a
        .endr
        ld de,(world_upload_job + 4)    ; the destination
        ld hl,world_upload_buffer
        ld b,world_palette >> 8
expand_loop:
        .irp shift,0,2,4,6
        ld a,(hl)
        .rept \shift
        rrca
        .endr
        and 3
        or world_palette & 0xFF
        ld c,a
        ld a,(bc)
        ld (de),a
        inc de
        .endr
        inc hl
        push hl
        push de
        ld de,(world_upload_job + 12)   ; the end
        or a
        sbc hl,de
        pop de
        pop hl
        jr nz,expand_loop
        jp world_upload_next

        .section .text.cabinet_actors,"ax",@progbits

; Enter the clipped sprite planner after the base picture of the ending.
; The planner calls this in the place of its three-byte mode load.
cabinet_actor_dispatch:
        ld a,(cabinet_mode)
        bit LOADING,a
        ret nz
        cp MODE_RESULT
        ret nc
        cp MODE_ENDING
        ret c
        pop hl                          ; drop the return of the dispatch
        jr cabinet_actor_plan
cabinet_actor_plan:
        ld hl,stream_arm_next           ; receive after the background DMA
        call state_word
        ld (scene_out),de
        call sprite_cache_begin
        ld hl,0x7002                    ; unused repair scratch
        ld (scene_repair),hl
; The cabinet surface has no foreground. The ending art uses only the
; high sprite palettes (2 and 9), so the ordinary clipping is enough.
        ld hl,(scene_raw)
        ld de,6                         ; object count
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (scene_items),de
        ld de,19                        ; the objects
        add hl,de
        ld (scene_item),hl
        xor a
        ld (scene_spare),a
        ld a,2
        ld (cabinet_seed_pages),a       ; seed both game pages
        ld hl,0xFFFF
        ld (scene_previous_foreground),hl
        ld hl,0
        ld (scroll_valid),hl
        jp state_object_loop

        .section .text.cabinet_bridges,"ax",@progbits

; Call the banked water refresh; keep the bank and the flags of the caller.
hitch_water_refresh:
        in0 a,(CBR)
        push af
hitch_water_map:
        ld a,bank_code__load__cbr
        out0 (CBR),a
hitch_water_call:
        call hitch_water_banked
        push af
        pop bc                          ; the result
        pop af
        out0 (CBR),a
        push bc
        pop af
        ret
hitch_scene_consume:
hitch_scene_prepare_operand:
        call hitch_scene_prepare_common
        jp combined_pan_restore_static
hitch_scene_compose_call:
        call combined_compose_source
hitch_scene_compose_map:
        ld a,bank_code__load__cbr
        out0 (CBR),a
        ret

        .section .text.cabinet_regular_field,"ax",@progbits

; A dynamic field: a value byte, as a digit selector or, after the ending,
; as a glyph ID. In: B the field.
cabinet_regular_field:
        ld a,b
        add a,cabinet_values & 0xFF
        ld l,a
        ld h,cabinet_values >> 8
        ld a,(hl)
        ld b,a
        ld a,(cabinet_values + 15)
        ld (cab_alternate_font),a
        or a                            ; the initials after the ending
        ld a,b
        jp nz,cabinet_glyph_ready
        add a,cab_digits & 0xFF
        ld l,a
        ld a,(hl)
        jp cabinet_glyph_ready

        .section .text.cabinet_rank_dispatch,"ax",@progbits

cabinet_rank_dispatch:
        ld b,a
        ld a,(cabinet_mode)
        cp MODE_RANKING
        jp z,rank_field_test
        cp MODE_PLANE_RANKING
        jp z,rank_field_test
        jp cabinet_regular_field
rank_field_test:
        ld a,b
        cp 16                           ; the rank fields
        jp c,cabinet_regular_field
        push de                         ; the glyph destination
        sub 16
        ld e,a
        ld d,0
        jp cabinet_rank_load

        .section .text.cabinet_rank_load,"ax",@progbits

cabinet_rank_load:
        ld hl,(cab_rank_map)
        ld a,l
        out0 (BBR),a
        ld hl,(cab_rank_pointer)
        add hl,de
        ld a,(hl)
        pop de
        cp BLANK_RANK_GLYPH
        jp z,cabinet_overlay_next
        ld b,a
        ld a,1
        ld (cab_alternate_font),a
        ld a,b
        jp cabinet_glyph_ready
cab_rank_map:
        .word cab_rank_bbr              ; cabinet_video.install
cab_rank_pointer:
        .word cab_rank_address
cabinet_presentation_live_entry:
        call cabinet_presentation_hud
        jp cabinet_overlay_text
cab_demo_prompt_dispatch:
        cp MODE_PLANE
        jp nz,cab_demo_finish
        ld a,(cab_prompt_visible)
        or a
        jp z,cab_demo_finish
        jp cab_demo_prompt_sentinel

        .section .text.cab_demo_finish_dispatch,"ax",@progbits

; Finish the title bands before the remaining text of the plane page.
cab_demo_finish_dispatch:
        ld a,(cabinet_mode)
        cp MODE_PLANE
        jp z,cabinet_overlay_text
        jp cabinet_overlay_finish
