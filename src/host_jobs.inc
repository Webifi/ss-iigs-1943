; Second Sight SRAM jobs in the host data (src/secondsight/world_rows.s,
; KIND_SRAM_DIRECT): the 10-byte header (src/secondsight/include/world_job.inc
; JOB_*), then the packed bytes in the format of scripts/startup_pack.py, where
; a token n-1 stores n literal bytes (n <= 128). A job writes into one 4 KB
; page of the card SRAM. The values come from build/game/secondsight_symbols.inc
; (the linked Second Sight program); build/secondsight/regions holds the linked
; helpers (*.bin) and their packed forms (*.lz, scripts/startup_pack.py).

; card_physical ADDRESS: the physical SRAM address of a Second Sight label: a
; load address (a data label, from secondsight_load_sram on) or a logical
; address in common SRAM (below secondsight_bank_window, physical = logical).
.define card_physical(address) ((address) - ((address) >= secondsight_load_sram) * secondsight_load_sram)

; sram_job_header PHYSICAL, BYTES, PACKED: the job header. Below the bank
; window the card writes PHYSICAL directly; above it, through common area 1
; with the CBR of its 4 KB page.
.macro sram_job_header physical, bytes, packed
  .assert ((physical) .mod $1000) + (bytes) <= $1000, error, "a Second Sight SRAM job crosses a 4 KB page"
  .if (physical) < secondsight_bank_window
    .byte secondsight_KIND_SRAM_DIRECT, 0, 0, 0
    .word physical
  .else
    .byte secondsight_KIND_SRAM_DIRECT, <(((physical) - secondsight_common1_window) >> 12), 0, 0
    .word secondsight_common1_window + ((physical) .mod $1000)
  .endif
  .word bytes, packed
.endmacro

; sram_literal_job PHYSICAL, FILE, OFFSET, COUNT: COUNT (at most 128) bytes of
; FILE from OFFSET as one literal run.
.macro sram_literal_job physical, file, offset, count
  .assert (count) <= 128, error, "a literal run holds at most 128 bytes"
  sram_job_header physical, count, (count) + 1
  .byte (count) - 1
  .incbin file, offset, count
.endmacro

; sram_packed_job PHYSICAL, BYTES, FILE: the packed FILE that unpacks to BYTES
; bytes, padded to an even length (the receiver reads words).
.macro sram_packed_job physical, bytes, file
  .local data, data_end
  sram_job_header physical, bytes, (data_end - data) + ((data_end - data) .mod 2)
data:
  .incbin file
data_end:
  .res (data_end - data) .mod 2
.endmacro
