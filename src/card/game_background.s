; Background pass hooks used by the plan list.

        .include "z180.inc"

        .global game_materialize_begin, game_materialize_end, native_fg_draw

        .section .text.game_background_restore,"ax",@progbits

; Each page owns the damage it actually drew. World-command slots may be
; replaced without changing old repairs, including camera jumps.
game_materialize_begin:
        phase_stamp phase_times+0x04
        jp combined_coverage_begin
game_materialize_end:
        phase_stamp phase_times+0x06
        ret

        .section .text.game_background_draw,"ax",@progbits
native_fg_draw:
        jp scroll_draw
