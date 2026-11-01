; The world upload jobs (world_rows.s): the host sends them in packets
; (scripts/world_stream.py builds them).

        .ifndef WORLD_JOB_INC
        .equ WORLD_JOB_INC, 1

; Upload job header, at world_upload_job. The packet has the first 10
; bytes; the receiver uses the rest.
        .equ JOB_KIND, 0
        .equ JOB_CBR, 1                 ; SRAM kinds: the CBR of the destination
        .equ JOB_TABLE_PLANES, 1        ; scattered rows: planes of the slot row table; 0: none
        .equ JOB_PLANES, 2              ; map mask, or the read plane
        .equ JOB_SEGMENT, 3             ; Oak segment
        .equ JOB_TABLE_ADDRESS, 4
        .equ JOB_DESTINATION, 4
        .equ JOB_BYTES, 6               ; scattered rows: two for each row
        .equ JOB_PACKED_BYTES, 8        ; bytes of the packed data in the packet
        .equ JOB_NEXT, 10               ; the next job in the packet
        .equ JOB_END, 12                ; the end of the unpacked data
        .equ JOB_ROW_BYTES, 14          ; prepared rows: the bytes of the row records
        .equ JOB_RUNS, 16
        .equ JOB_RUN_COUNT, 17

; Job kinds. 0 ends the list.
        .equ KIND_SRAM, 2               ; copy into SRAM
        .equ KIND_PALETTE, 3            ; 4-bit pixels through the 16-colour palette to video RAM
        .equ KIND_SRAM_DIRECT, 4        ; unpack directly into SRAM
        .equ KIND_CABINET_PLANE, 5      ; unpack directly into one video RAM plane
        .equ KIND_ROWS, 6               ; expand prepared row runs
        .equ KIND_SCATTER, 7            ; scattered pixel rows (with a palette)

        .endif
