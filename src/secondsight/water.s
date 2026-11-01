; Water palette: the stage water colours that move with the sea, the light
; water colours, the flash of the special weapons and the lit clouds.
;
; Stage water is a fixed 30-row pattern of the 120 water slots. Each picture
; rotates the slot colours by water_stage_phase = (FG + 16 - SEA) mod 30, so
; the texture moves with the sea layer and is never copied again. Light
; water has 3 slots with fixed colours.

        .include "video.inc"
        .include "water.inc"
        .include "stream.inc"
        .include "water_palette.inc"

        .global water_effect_banked, water_flash_banked, water_cloud_update
        .global water_camera, water_commit, palette_commit, special_palette_dispatch, water_mod30
        .global water_active, water_pattern_base, water_pattern_segment
        .global water_page_family, water_stage_phase, water_low_residues, water_high_residues

        .equ REQUEST_CLOUD, 3           ; update the clouds only
        .equ REQUEST_DARK, SPF_DARK     ; Tsunami: dark sea instead of cyan
        .equ WATER_SLOTS, 120           ; water-only palette indices
        .equ CLOUD_ENTRIES, 12          ; cloud_palette_normal entries (scripts/game_water.py)

; Flash colours. Bit 1 of the slot position darkens the cyan green to
; 188 ^ 16 = 172, so the sea texture stays visible; the dark flash keeps
; its green because its blue (67) has bit 4 clear.
        .equ CYAN_GREEN, 188
        .equ CYAN_BLUE, 241
        .equ DARK_GREEN, 0
        .equ DARK_BLUE, 67

        .equ PERIOD, STAGE_PERIOD       ; rows of the stage water pattern
        .equ PATTERNS, 4                ; stage water patterns of 30 slots
        .equ FLASH_FLAGS, SPF_DARK | SPF_CYAN ; scene_effect_flags: a flash picture
        .equ VIEW_RESIDUE, 16           ; upright view: FG + 16
        .equ PATTERN_WIDTH, 63          ; source columns of both patterns, minus 1
        .equ FAMILY_BG2_OFF, 2          ; water_page_family bit 1: the sea layer is off
        .equ CYAN_FADE, 0x10            ; the green bit that slot bit 1 clears

; The water state (secondsight.ld .playfield: zero at load). An 8-bit
; page index reads water_page_family: it stays in one 256-byte page.
        .section .vars.water,"aw",@nobits
        .balign 2
water_page_family: .ds.b 2              ; family shown on each page
water_active: .ds.b 1                   ; 1 after the first water_camera
water_pattern_base: .ds.b 1             ; high byte of the pattern address
water_pattern_segment: .ds.b 1          ; the Oak segment of the pattern
water_stage_phase: .ds.b 1              ; the rotation of the stage water colours
cloud_flash_shown: .ds.b 1              ; SPF_CLOUDS of the cloud colours in the DAC

; The mod 30 tables of water_mod30: N mod 30 and (N x 256) mod 30. Each
; stays in one 256-byte page: the code indexes it with L.
        .section .rodata.water_low_residues,"a",@progbits
        .balign 256
water_low_residues:
        .set n, 0
        .rept 256
        .byte n % PERIOD
        .set n, n + 1
        .endr
        .section .rodata.water_high_residues,"a",@progbits
        .balign 256
water_high_residues:
        .set n, 0
        .rept 256
        .byte (n * 256) % PERIOD
        .set n, n + 1
        .endr

        .section .text.water_camera,"ax",@progbits

; water_camera: set the stage water phase, the water family of the page
; and the pattern of this picture. A family change sets scroll_full.
; Out: A 0. AF, BC, DE, HL changed.
water_camera:
        ld a,1
        ld (water_active),a
; Both positions are native game state. A late picture uses the complete
; displacement, with the stops and reversals of the middle layer.
        ld hl,(scroll_sea_camera)
        ld de,(scene_fg_camera)
        or a
        sbc hl,de
        ld (scroll_relative),hl
        ld hl,(scroll_sea_camera)
        call water_mod30
        push af
        ld hl,(scene_fg_camera)
        call water_mod30
        add a,VIEW_RESIDUE
        ld b,a
        pop af
        ld e,a
        ld a,b
        sub e
        jr nc,phase_positive
        add a,PERIOD
phase_positive:
        cp PERIOD
        jr c,phase_ready
        sub PERIOD
phase_ready:
        ld (water_stage_phase),a
; A family change reseeds each page before the page shows the new palette.
        ld a,(scroll_sea_camera + 1)
        and SEA_BANK
        cp LIGHT_WATER_BAND
        ld a,0                          ; normal water
        jr nz,family_selected
        inc a                           ; light water
family_selected:
        ld (scroll_light_water),a
        ld b,a
        ld a,(scene_effect_flags)
        and SPF_BG2_OFF
        add a,a                         ; FAMILY_BG2_OFF
        or b
        ld b,a                          ; family: light water, bit 1 BG2 off
        ld a,(scroll_page_index)
        add a,water_page_family & 0xFF
        ld l,a
        ld h,water_page_family >> 8
        ld a,(hl)
        ld (hl),b
        cp b
        jr z,family_kept
        ld a,1
        ld (scroll_full),a
family_kept:
        ld a,(scroll_light_water)
        or a
        jr nz,light_source
        ld a,normal_water_pattern >> 8
        ld (water_pattern_base),a
        ld a,normal_water_pattern >> 16
        ld (water_pattern_segment),a
        ld a,PATTERN_WIDTH
        jr width_ready
light_source:
        ld a,light_water_pattern >> 8
        ld (water_pattern_base),a
        ld a,light_water_pattern >> 16
        ld (water_pattern_segment),a
        ld a,PATTERN_WIDTH
width_ready:
        ld (water_source_mod_whole+1),a
        ld (water_source_mod_clipped+1),a
        xor a                           ; a late picture never forces a refresh
        ret

; palette_commit: swap the propeller greys every picture (the back page
; alternates), then write the water colours (scripts/propellers.py).
; water_commit: write the water colours of this picture to the DAC.
; water_commit_active: the same with A = water_active. AF, BC, DE, HL changed.
palette_commit:
        ld a,(play_back_high)
        rla                             ; carry: the page bit
        ld bc,VGA_DAC_WRITE_INDEX
        ld a,PROPELLER_SLOT
        out (c),a
        inc c
        ld hl,propeller_greys
        jr nc,propeller_ready
        ld hl,propeller_greys + 2
propeller_ready:
        ld d,2                          ; the two propeller slots
propeller_entry:
        ld a,(hl)
        inc hl
        .rept 3
        out (c),a
        .endr
        dec d
        jr nz,propeller_entry
; Write the water colours of this picture to the DAC.
water_commit:
        ld a,(water_active)
water_commit_active:
        or a
        ret z
        ld a,(scene_effect_flags)
        and SPF_BG2_OFF
        jp z,palette_visible
; Black out only the private water slots (sea layer off, the dive into the
; light water section). The game layers share no colours with them. The
; ending picture does (slots 42-46), and arcade_flow restores them while
; water_active is 0.
        set_io BBR, water_palette_indices__bbr
        ld hl,water_palette_indices__ptr
        ld bc,VGA_DAC_WRITE_INDEX
        ld e,WATER_SLOTS
black_loop:
        ld a,(hl)
        inc hl
        out (c),a
        inc c
        xor a
        .rept 3
        out (c),a
        .endr
        dec c
        dec e
        jp nz,black_loop
        ret
palette_visible:
        ld a,(scroll_light_water)
        or a
        jp z,stage_commit
; The three light water slots are in a line, and the DAC address goes up
; after each RGB triple, so select the first slot only once.
        ld bc,VGA_DAC_WRITE_INDEX
        ld a,LIGHT_WATER_SLOT
        out (c),a
        inc c
        .irp component,0,1,2,3,4,5,6,7,8 ; the R, G, B of the three slots
        ld a,LIGHT_WATER_RGB_\component
        out (c),a
        .endr
        ret

; Palette (water_palette_indices): the 120 slot indices, then the 30
; colours of each pattern two times, so 30 entries from any phase need no
; wrap. It starts a 256-byte page: E counts the slot indices.
stage_commit:
        set_io BBR, water_palette_indices__bbr
        ld a,(water_stage_phase)
        ld e,a
        add a,a
        add a,e                         ; 3 bytes a colour
        ld e,a
        ld d,0
        ld hl,water_palette_indices__ptr + WATER_SLOTS
        add hl,de
        ld de,water_palette_indices__ptr
        .irp pattern,0,1,2,3
        ld bc,VGA_DAC_WRITE_INDEX
        .if WATER_PATTERN_\pattern\()_CONTIGUOUS
; The slots of this pattern are in a line: select the first slot once.
        ld a,(de)
        out (c),a
        inc c
        ld e,PERIOD
stage_palette_\pattern:
        .rept 3
        ld a,(hl)
        inc hl
        out (c),a
        .endr
        dec e
        jr nz,stage_palette_\pattern
        ld de,water_palette_indices__ptr + (\pattern + 1) * PERIOD
        .else
stage_palette_\pattern:
        ld a,(de)
        inc de
        out (c),a
        inc c
        .rept 3
        ld a,(hl)
        inc hl
        out (c),a
        .endr
        dec c
        ld a,e
        cp (\pattern + 1) * PERIOD
        jr nz,stage_palette_\pattern
        .endif
        .if \pattern < PATTERNS - 1
        ld bc,3 * PERIOD                ; skip the second copy
        add hl,bc
        .endif
        .endr
        ret

; special_palette_dispatch: while a special runs, its hook replaces the
; first instruction of water_commit with a jump here. A flash picture runs water_flash_banked,
; then the cloud update. Any other picture runs the normal commit, then the
; cloud update, so the clouds and the bolt slots go back to normal on the
; first picture without the flash.
special_palette_dispatch:
        ld a,(water_active)
        or a
        jp z,special_palette_cloud
        ld a,(scene_effect_flags)
        and SPF_BG2_OFF
        jp nz,special_palette_normal
        ld a,(scene_effect_flags)
        and FLASH_FLAGS
        jp nz,water_banked_bridge
special_palette_normal:
        ld a,(water_active)
        call water_commit_active
special_palette_cloud:
        ld a,REQUEST_CLOUD
water_banked_bridge:
        ld b,a
        in0 a,(CBR)
        push af
        set_io CBR, sea_occupancy__load__cbr ; the water_flash code page at WINDOW_E000
        ld a,b
        call water_effect_banked
        pop af
        out0 (CBR),a
        ret

; water_mod30: In: HL unsigned world coordinate. Out: A = HL mod 30, from
; the residue tables of the low and the high byte. BBR kept; DE, HL changed.
water_mod30:
        in0 a,(BBR)
        push af
        set_io BBR, water_high_residues__bbr
        ld e,l
        ld l,h
        ld h,water_high_residues__ptr >> 8
        ld d,(hl)
        ld h,water_low_residues >> 8
        ld l,e
        ld a,(hl)
        add a,d
        cp PERIOD
        jr c,mod30_ready
        sub PERIOD
mod30_ready:
        ld e,a
        pop af
        out0 (BBR),a
        ld a,e
        ret

; The propeller greys of the two pages, in DAC slot order (light, dark,
; then swapped; scripts/propellers.py GREYS).
propeller_greys:
        .byte PROPELLER_GREY_0, PROPELLER_GREY_1
        .byte PROPELLER_GREY_1, PROPELLER_GREY_0

        .section .text.water_flash,"ax",@progbits

; water_effect_banked: runs through common area 1 (secondsight.ld
; .sea_occupancy.e000, at the window address). In: A request (REQUEST_CLOUD,
; REQUEST_DARK or another flash request). AF, BC, DE, HL changed.
; water_flash_banked: the flash: the 120 water slots go cyan or dark.
water_effect_banked:
        cp REQUEST_CLOUD
        jp z,water_cloud_update
water_flash_banked:
        ld hl,(CYAN_BLUE << 8) | CYAN_GREEN
        cp REQUEST_DARK
        jr nz,flash_begin
        ld hl,(DARK_BLUE << 8) | DARK_GREEN
flash_begin:
        ld a,water_palette_indices__bbr
        out0 (BBR),a
        ld de,water_palette_indices__ptr
        ld bc,VGA_DAC_WRITE_INDEX
flash_loop:
        ld a,(de)
        inc de
        out (c),a
        inc c
        xor a                           ; red
        out (c),a
        ld a,e                          ; slot bit 1 to bit 4
        rlca
        rlca
        rlca
        and h
        and CYAN_FADE
        xor l                           ; green
        out (c),a
        ld a,h                          ; blue
        out (c),a
        dec c
        ld a,e
        cp WATER_SLOTS
        jr nz,flash_loop
        jp water_cloud_update

; water_cloud_update: load the normal or the lit cloud colours when the
; wanted state (SPF_CLOUDS) changed. Out: BBR on the water palette.
water_cloud_update:
        ld a,(scene_effect_flags)
        and SPF_CLOUDS
        ld b,a
        ld a,(cloud_flash_shown)
        cp b
        ret z
        ld a,b
        ld (cloud_flash_shown),a
        ld a,cloud_palette_normal__bbr
        out0 (BBR),a
        ld hl,cloud_palette_normal__ptr
        ld a,(cloud_flash_shown)
        or a
        jr z,cloud_ready
        ld hl,cloud_palette_lit__ptr
cloud_ready:
        ld bc,VGA_DAC_WRITE_INDEX
        ld e,CLOUD_ENTRIES
cloud_loop:
        ld a,(hl)
        inc hl
        out (c),a
        inc c
        .rept 3
        ld a,(hl)
        inc hl
        out (c),a
        .endr
        dec c
        dec e
        jr nz,cloud_loop
        ld a,water_palette_indices__bbr ; leave BBR as the commit paths do
        out0 (BBR),a
        ret
