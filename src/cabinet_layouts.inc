; The cabinet pages and the card layouts: the IIgs sends the layout of
; each packet in its trailer mode byte (src/cabinet.s cabinet_wire_mode);
; the Second Sight keeps it in cabinet_mode and draws by it (src/secondsight/
; cabinet.s, cabinet_live.s, state_plan.s). A cabinet page has the layout
; of its number. Both assemblers read this file: decimal NAME = value only.

; The cabinet pages (GAME_FLOW and CAB_PAGE on the IIgs).
CAB_PAGE_FIRST      = 3         ; GAME_FLOW: from this value on, a cabinet page shows
PAGE_RANKING_FIRST  = 3         ; CAB_PAGE: the ranking after PAGE_POWER_ON; GAME_FLOW: also the demo load under PAGE_RANKING
PAGE_TITLE          = 4         ; the attract title (the plane)
PAGE_POWER_ON       = 5         ; the page at power-on (the warning text)
PAGE_COIN_ONE       = 6         ; the title with one credit: one player
PAGE_COIN_TWO       = 7         ; the title with credits for two players
PAGE_RANKING        = 16        ; the ranking (with the plane)
PAGE_ENDING_FIRST   = 17        ; the ending pages, PAGE_ENDING_FIRST..PAGE_ENDING_END-1
PAGE_ENDING_END     = 30        ; the page after the last ending page

; The other layouts.
LAYOUT_DEMO         = 1         ; the demo: the logo and INSERT COIN
LAYOUT_DEMO_BLINK   = 2         ; the demo: the logo, INSERT COIN off
LAYOUT_FAILED       = 31        ; the stage result: failed
LAYOUT_STATISTICS   = 32        ; + CRD_BAND: the statistics
LAYOUT_FAILED_RETRY = 44        ; the stage result: failed, with the retry line
LAYOUT_SUCCESS      = 46        ; + CRD_STAGE: the stage result: success
LAYOUT_STATISTICS_NIL = 62      ; + CRD_BAND: the statistics with no refill
LAYOUT_POST_OVER    = 74        ; + CAB_POST_MASK: GAME OVER of the players (74: none)
LAYOUT_POST_ENTRY   = 77        ; + CAB_POST_ACTIVE: the initials
LAYOUT_POST_RANK    = 81        ; + CAB_POST_QUALIFIED: the new ranks (81: none)
LAYOUT_LIVE         = 85        ; the live initials over the play
LAYOUT_TITLE_PROMPT = 86        ; PAGE_TITLE with the prompt drawn apart
LAYOUT_TARGET       = 87        ; + CAMERA_STAGE: the stage start banner (TARGET, the ship, FIGHT BRAVELY!)
LAYOUT_CONTACT      = 103       ; the banner before the dive to the ships (VISUAL CONTACT ...)
LAYOUT_LOADING      = 128       ; + a page: its upload runs, the old picture stays
LAYOUT_LOADING_BIT  = 7
LAYOUT_PAGE_MASK    = 127       ; a layout without LAYOUT_LOADING
