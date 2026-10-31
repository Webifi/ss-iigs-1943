; Only STATE_ONLY continuous builds use these old host repair-list words.
; Each update advances two game ticks. Arcade timing uses eight DOC ticks;
; other display timings use fractional deadlines at half the refresh rate.
; Picture ownership and DMA1 tokens advance only when a packet is sent.
GAME_PICTURE = $1510
GAME_DUE = $1512
GAME_SKIPPED = $1514
GAME_SENT_LOGIC = $1516
GAME_CLOCK_ORIGIN = $1518
GAME_CLOCK = $1e96
