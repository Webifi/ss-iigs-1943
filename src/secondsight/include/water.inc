; The water patterns (water.s): the stage water repeats every STAGE_PERIOD
; rows, the light water every LIGHT_PERIOD rows.

        .ifndef WATER_INC
        .equ WATER_INC, 1

        .equ STAGE_PERIOD, 30           ; rows of the stage water pattern
        .equ LIGHT_PERIOD, 128          ; rows of the light-water pattern
; The sea camera: its high byte bits 7-4 select the sea bank.
        .equ SEA_BANK, 0xF0
        .equ LIGHT_WATER_BAND, 0x10     ; the bank of the light water

        .endif
