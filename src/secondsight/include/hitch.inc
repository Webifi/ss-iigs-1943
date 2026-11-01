; The hitch scene states (hitch_scene.s; hitch_stage.s and background_full.s
; read them).

        .ifndef HITCH_INC
        .equ HITCH_INC, 1

; hitch_ready.
        .equ STATE_NONE, 0
        .equ STATE_METADATA, 1          ; coverage of every target row is ready
        .equ STATE_IMAGE, 2             ; the picture is in the hidden twins
        .equ STATE_CONSUMED, 3          ; the picture is on the page (both twins)
; hitch_d500_state (the host packets of scripts/hitch_stage.py set it).
        .equ D500_HELPER_PRESENT, 2     ; the $D500 helper is in the other buffer
        .equ D500_STAGED, 1             ; the staged image waits for its view
        .equ D500_VIEW, 0xD500          ; the foreground camera of the staged view

        .endif
