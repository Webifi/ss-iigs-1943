; Plan one background pass: append the foreground row commands and the
; scroll draw to the plan list at (scene_out). The planner runs straight
; through its sections (secondsight.ld .state_planner): this code
; continues .text.state_plan_a and falls into .text.state_plan_b.

; Each plan list entry is a command address: scene_next runs the list as a
; return stack, so each command ends with RET to the next one.

; Append HL to the plan list at DE; DE moves on.
        .macro append_hl
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        .endm

; Append the command LABEL to the plan list at DE.
        .macro handler label
        ld hl,\label
        append_hl
        .endm

        .section .vars.background_plan,"aw",@nobits
row_cache_remaining: .ds.b 2            ; foreground rows that still need a command

        .section .text.background_plan,"ax",@progbits

        ; The coverage begin command forgets the column staging of the
        ; last picture. background_plan_full can replace it (below).
        ld de,(scene_out)
        handler combined_coverage_begin
        ld (scene_out),de
        ; Add one command for each foreground row that the camera move
        ; shows (background_motion.s: row_cache_count from row_cache_first).
        ld hl,(row_cache_count)
        ld a,h
        or l
        jr z,bg_rows_ready              ; no new rows: all rows are on the page
        ld a,h
        or a
        jp z,bg_rows_ordinary           ; less than 256 rows: one command a row
        call background_plan_full       ; a full rebuild: try the empty-view shortcut
        jr c,bg_rows_ready              ; done: one blank command for all rows
        ld hl,(row_cache_count)
bg_rows_ordinary:
        ld (row_cache_remaining),hl
        ld hl,(row_cache_first)
        ld (scene_value),hl             ; state_fg_row reads the row in scene_value
bg_materialize:
        call state_fg_row
        ld hl,(scene_value)
        inc hl
        ld (scene_value),hl
        ld hl,(row_cache_remaining)
        dec hl
        ld (row_cache_remaining),hl
        ld a,h
        or l
        jr nz,bg_materialize
bg_rows_ready:
        ; Last: the scroll draw of the page (combined_scroll.s).
        ld de,(scene_out)
        handler scroll_draw
        ld (scene_out),de
