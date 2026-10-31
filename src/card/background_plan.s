; Plan one background pass: append the draw handlers and their parameters to
; the plan list at (scene_out).

        .global bg_rows_ordinary, bg_materialize, bg_rows_ready

        .equ VIEW_ROWS, 255             ; last visible row, relative to the camera

; Append HL to the plan list at DE.
        .macro append_hl
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        .endm

        .macro handler label
        ld hl,\label
        append_hl
        .endm

        .section .text.background_plan,"ax",@progbits

        ; Continues the planner. In: HL and BC the old repair list position and length.
        ld (plan_old_repairs),hl
        ld (plan_old_repairs+2),bc
        ; Materialize only newly exposed foreground rows, at the actual layer rate.
        ld de,(scene_out)
        handler game_materialize_begin
        ld (scene_out),de
        ld hl,(row_cache_count)
        ld a,h
        or l
        jr z,bg_rows_ready              ; foreground rows resident
        ld a,h
        or a
        jp z,bg_rows_ordinary
        call background_plan_full       ; classify a full row cache
        jr c,bg_rows_ready              ; bulk empty metadata queued
        ld hl,(row_cache_count)
bg_rows_ordinary:
        ld (row_cache_remaining),hl
        ld hl,(row_cache_first)
        ld (scene_value),hl
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
        ld de,(scene_out)
        handler game_materialize_end
        ld (scene_out),de
        ld de,(scene_out)
        handler native_fg_draw
        ld hl,(scene_screen_base)
        append_hl
        ld hl,(scene_fg_camera)
        push de
        ld de,VIEW_ROWS
        add hl,de
        pop de
        append_hl
        ld a,(bg_pan)
        ld l,a
        ld h,0
        append_hl
        ld (scene_out),de
