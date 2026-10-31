; Water palette: the stage water colours that move with the sea, the light
; water colours, the flash of the special weapons and the lit clouds.
;
; Stage water is a fixed 30-row pattern of the 120 water slots. Each picture
; rotates the slot colours by water_stage_phase = (FG + 16 - SEA) mod 30, so
; the texture moves with the sea layer and is never copied again. Light
; water has 3 slots with fixed colours.

        .include "vga.inc"
        .include "z180.inc"
        .include "water_palette.inc"

        .global water_effect_banked, water_flash_banked, water_cloud_update
        .global water_camera, water_commit, palette_commit, special_palette_dispatch, water_mod30
        .global water_active, water_force, water_pattern_base, water_pattern_segment
        .global water_page_family, water_stage_phase

        .equ REQUEST_CLOUD, 3           ; update the clouds only
        .equ REQUEST_DARK, 0x40         ; Tsunami: dark sea instead of cyan
        .equ WATER_SLOTS, 120           ; water-only palette indices
        .equ CLOUD_FLASH, 0x80          ; scene_effect_flags: clouds lit

; Flash colours. Bit 1 of the slot position darkens the cyan green to
; 188 ^ 16 = 172, so the sea texture stays visible; the dark flash keeps
; its green because its blue (67) has bit 4 clear.
        .equ CYAN_GREEN, 188
        .equ CYAN_BLUE, 241
        .equ DARK_GREEN, 0
        .equ DARK_BLUE, 67

        .equ PERIOD, 30                 ; rows of the stage water pattern
        .equ PATTERNS, 4
        .equ LIGHT_WATER_BAND, 0x10     ; sea camera bank of the light water
        .equ BG2_OFF, 0x01              ; scene_effect_flags
        .equ FLASH_FLAGS, 0x42          ; scene_effect_flags: a flash picture
        .equ VIEW_RESIDUE, 16           ; upright view: FG + 16
        .equ PATTERN_WIDTH, 63          ; source columns of both patterns, minus 1

        .section .vars.water,"aw",@nobits
water_active: .ds.b 1                   ; 1 after the first water_camera
        .ds.b 1
water_force: .ds.b 1
water_pattern_base: .ds.b 1             ; high byte of the pattern address
        .ds.b 1
water_pattern_segment: .ds.b 1
        .ds.b 1
water_pattern_width: .ds.b 1
        .ds.b 2
water_page_family: .ds.b 2              ; family shown on each page
water_stage_phase: .ds.b 1

        .section .text.water_camera,"ax",@progbits

; Set the stage water phase and the pattern of this picture.
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
        and 0xF0
        cp LIGHT_WATER_BAND
        ld a,0                          ; normal water
        jr nz,family_selected
        inc a                           ; light water
family_selected:
        ld (scroll_light_water),a
        ld b,a
        ld a,(scene_effect_flags)
        and BG2_OFF
        add a,a
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
        ld (water_pattern_width),a
        ld (water_source_mod_whole+1),a
        ld (water_source_mod_clipped+1),a
        xor a                           ; a late picture never forces a refresh
        ld (water_force),a
        ret

; Swap the propeller greys every picture (the back page alternates), then
; write the water colours (scripts/propellers.py).
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
        ld d,2
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
        and BG2_OFF
        jp z,palette_visible
; Black out only the private water slots (sea layer off, the dive into the
; light water section). The game layers share no colours with them. The
; ending picture does (slots 42-46), and arcade_flow restores them while
; water_active is 0.
        set_io BBR, water_palette_bank
        ld hl,water_palette_indices
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
        .irp component,0,1,2,3,4,5,6,7,8
        ld a,LIGHT_WATER_RGB_\component
        out (c),a
        .endr
        ret

; Palette: the 120 slot indices, then the 30 colours of each pattern two
; times, so 30 entries from any phase need no wrap.
stage_commit:
        set_io BBR, water_palette_bank
        ld a,(water_stage_phase)
        ld e,a
        add a,a
        add a,e
        ld e,a
        ld d,0
        ld hl,water_palette_indices + WATER_SLOTS
        add hl,de
        ld de,water_palette_indices
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
        ld de,water_palette_indices + (\pattern + 1) * PERIOD
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

; While a special runs, its hook replaces the first instruction of
; water_commit with a jump here. A flash picture runs water_flash_banked,
; then the cloud update. Any other picture runs the normal commit, then the
; cloud update, so the clouds and the bolt slots go back to normal on the
; first picture without the flash.
special_palette_dispatch:
        ld a,(water_active)
        or a
        jp z,special_palette_cloud
        ld a,(scene_effect_flags)
        and BG2_OFF
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
        set_io CBR, water_effect_cbr
        ld a,b
        call water_effect_banked
        pop af
        out0 (CBR),a
        ret

; In: HL unsigned world coordinate. Out: A = HL mod 30, from the residue
; tables of the low and the high byte.
water_mod30:
        in0 a,(BBR)
        push af
        set_io BBR, water_residue_bank
        ld e,l
        ld l,h
        ld h,water_high_residues >> 8
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

; In: A request (REQUEST_CLOUD, REQUEST_DARK or another flash request).
water_effect_banked:
        cp REQUEST_CLOUD
        jp z,water_cloud_update
water_flash_banked:
        ld hl,(CYAN_BLUE << 8) | CYAN_GREEN
        cp REQUEST_DARK
        jr nz,flash_begin
        ld hl,(DARK_BLUE << 8) | DARK_GREEN
flash_begin:
        ld a,water_palette_bank
        out0 (BBR),a
        ld de,water_palette_indices
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
        and 0x10
        xor l                           ; green
        out (c),a
        ld a,h                          ; blue
        out (c),a
        dec c
        ld a,e
        cp WATER_SLOTS
        jr nz,flash_loop
        jp water_cloud_update

; Load the normal or the lit cloud colours when the wanted state changed.
water_cloud_update:
        ld a,(scene_effect_flags)
        and CLOUD_FLASH
        ld b,a
        ld a,(cloud_flash_shown)
        cp b
        ret z
        ld a,b
        ld (cloud_flash_shown),a
        ld a,cloud_palette_bank
        out0 (BBR),a
        ld hl,cloud_palette_normal
        ld a,(cloud_flash_shown)
        or a
        jr z,cloud_ready
        ld hl,cloud_palette_lit
cloud_ready:
        ld bc,VGA_DAC_WRITE_INDEX
        ld e,cloud_entries
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
        ld a,water_palette_bank         ; leave BBR as the commit paths do
        out0 (BBR),a
        ret
