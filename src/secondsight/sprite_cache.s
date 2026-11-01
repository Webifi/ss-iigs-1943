; Sprite art cache: 128 slots of sprite art, found by a hash of the ROM
; code and palette. Each slot holds the prepared pixels of up to four
; alignments in video RAM. A miss reads the packed ROM source from the
; cold source directory in video RAM, never from the IIgs.

        .include "video.inc"
        .include "sprite_records.inc"

        .global cache_source_lookup
        .global sprite_cache_begin, cache_relink, cache_clone, sprite_cache_prefetch
        .global prefetch_time, cache_slot_table, cache_descriptor
        .global quiet_art_load
        .global cache_boot_clear
        .global cache_allocate_pixel, cache_retire_art
        .global sprite_cache_object
        .global cache_ready, cache_resolve
        .global source_mask_entries
        .global sprite_mark_fast
        .global sprite_mask_select, sprite_mask_shift_0
        .global sprite_damage_bounds
        .global archive_find
        .global archive_read_tag, archive_write_index
        .global sparse_selector

        .global art_keys
        .global art_hidden_count

        .equ SLOTS, 128
        .equ STALE_AGE, 4               ; pictures without use before a slot is replaced
        .equ CACHE_FAULT, 0xE4          ; reported to the IIgs: every slot is in use
        .equ ABSENT, 0xFF               ; cache_source_lookup: no source pixels
        .equ PREFETCH_PINS, 120         ; most pinned phases that allow a prefetch
        .equ PREFETCH_TIME, 22500       ; PRT0 counts: about 25 ms of the picture

; SRAM tables of the cache, each seen in the BBR window at WINDOW_C000.
; Each group shares one 4 KB page (secondsight.ld .phase_records,
; sprite-headers and sprite-links checks the offsets); the code needs the
; window addresses as constants.
        .equ RECORDS_BBR, phase_records__bbr
        .equ PHASE_RECORDS, WINDOW_C000 ; 8 bytes for each phase (gen/phase_records.s)
        .equ HEADERS_BBR, art_headers__bbr
        .equ HEADERS, WINDOW_C000       ; art_headers: 16-byte draw headers
        .equ PAIR_MASKS, WINDOW_C000 + 0x800 ; 4 pages: pixel pair to mask bits at each offset
        .equ SPAN_HEADERS, WINDOW_C000 + 0xC00 ; original header of each encoded span header
        .equ SPAN_MASKS, WINDOW_C000 + 0xD00 ; low page, then high page of the interval masks
        .equ LINKS_BBR, art_bindings__bbr
        .equ BINDINGS, WINDOW_C000      ; art_bindings: slot + 1 of each ROM code, 0 for none
        .equ PHASE_LINKS, WINDOW_C000 + 0x800 ; 4 phase record pointers for each slot

; Phase record: VRAM address (2), segment and phase << 2, stamp (bit 7: the
; clock reference), owner slot, draw header (0xFF: none), art key (2).
        .equ RECORD_SIZE, 8
        .equ RECORD_STAMP, 3
        .equ RECORD_OWNER, 4
        .equ RECORD_HEADER, 5
        .equ HEADER_SIZE, 16
        .equ HEADER_OWNER, 14           ; phase record that uses the header
        .equ HEADER_RING, 128
        .equ STAMP_BITS, 0x7F
        .equ REFERENCE, 0x80

        .global art_hash, art_headers, pair_masks, art_bindings, phase_links, art_hidden_queue

; Hash heads: the slot + 1 of the first entry for each hash, 0 for none
; (secondsight.ld .playfield). One 256-byte page: the hash is its low
; byte.
        .section .data.art_hash,"aw",@progbits
        .balign 256
art_hash: .fill 256, 1, 0

; The slots: an empty key (0xFF) and the oldest age at the start
; (secondsight.ld .sprite_tables). The keys fill one 256-byte page and
; art_ages starts the next: the slot is the low byte of an age.
        .section .data.art_keys,"aw",@progbits
        .balign 256
art_keys: .fill 2 * SLOTS, 1, 0xFF      ; ROM code and palette of each slot
art_ages: .fill SLOTS, 1, 0xFF          ; pictures since the last use, 0 = in use
art_next: .byte 0                       ; next slot to examine
art_slot: .byte 0                       ; the slot of the current art
art_key: .word 0                        ; the key of the current art: code, palette
art_source: .word 0                     ; cold source fields: address,
art_flags: .byte 0                      ; plane and segment,
art_size: .byte 0                       ; byte count
art_color: .byte 0                      ; the palette of the current art
art_span_pointer: .word 0               ; the next span of the packed source
art_hash_key: .byte 0                   ; the hash of the current key
art_match: .byte 0                      ; the slot + 1 that matched, or 0
art_source_phase: .byte 0               ; the phase of the source pixels
art_prefetch_next: .byte 0              ; the next hidden sprite to prefetch

        .section .vars.art_bounds,"aw",@nobits
art_bounds: .ds.b 4 * SLOTS             ; left, right, top, height

; Slot fields of the current descriptor: segment, BBR, address, first
; row, rows, first row x 56, source pointer.
        .section .vars.art_wire,"aw",@nobits
art_wire: .ds.b 16

        .section .vars.art_temp,"aw",@nobits
art_temp: .ds.b 0x98                    ; packed source of a miss: at most 148 bytes

        .section .vars.art_state,"aw",@nobits
art_phase: .ds.b 1                      ; the alignment of the object (0-3)
art_clone_source: .ds.b 2               ; cache_clone: the source phase pixels
art_clone_dest: .ds.b 2                 ; and their destination
art_clone_plane: .ds.b 1
art_clone_lane: .ds.b 1
art_hidden_count: .ds.b 1               ; art_hidden_queue: the hidden sprites queued
art_hidden_next: .ds.b 1                ; the next hidden sprite to prefetch
art_binding: .ds.b 2                    ; the binding of the current code
art_clone_first: .ds.b 1                ; the first row of a clone
art_pixel: .ds.b 2                      ; the phase record of the current art
        .section .data.art_pixel_next,"aw",@progbits
art_pixel_next: .word PHASE_RECORDS     ; the next free phase record
        .section .vars.art_pixels,"aw",@nobits
art_match_pixel: .ds.b 2                ; the phase record that matched
art_new_pixels: .ds.b 1                 ; 1: the phase pixels are new, not restored
art_write_mask: .ds.b 1                 ; the planes that the art writes
art_pixel_origin: .ds.b 4               ; the origin of the phase pixels
art_rows: .ds.b 1                       ; the rows of the art
        .section .data.art_pins,"aw",@progbits
art_pin_count: .byte 0                  ; the phases pinned by this picture
art_header_next: .byte 0                ; the next draw header of the ring
art_stamp: .byte 1                      ; the clock stamp of this picture

; The hash chains and the slot phases (secondsight.ld .sprite_chain):
; the slot is the low byte of an entry. art_chain starts a 256-byte page;
; the slot phases start at a multiple of SLOTS, so OR with the slot keeps
; them in one page.
        .section .data.art_chain,"aw",@progbits
        .balign 256
art_chain: .fill SLOTS, 1, 0            ; slot + 1 of the next entry with the same hash
        .section .vars.art_slot_phases,"aw",@nobits
        .balign SLOTS
art_slot_phases: .ds.b SLOTS            ; the phases of each slot

; The occupied-pixel masks of each slot: 16 rows of 2 bytes (the clipper
; of object_kernel.s reads them as the canonical silhouette).
        .global canonical_masks
        .section .vars.canonical_masks,"aw",@nobits
canonical_masks: .ds.b 32 * SLOTS

; The hidden sprites of the picture: code word, phase, unused (state_hidden).
        .section .vars.art_hidden_queue,"aw",@nobits
art_hidden_queue: .ds.b 4 * 16

; The draw headers (secondsight.ld .sprite_headers): 16 bytes each; an
; empty one has the owner and the next fields 0xFF.
        .section .data.art_headers,"aw",@progbits
art_headers:
        .rept HEADER_RING
        .fill 8, 1, 0
        .byte 0xFF
        .fill 5, 1, 0
        .byte 0xFF, 0xFF
        .endr
; pair_masks: for each of the four group offsets a page: the pixel pair
; (two 4-bit pens) to its mask bits at that offset.
        .section .data.pair_masks,"aw",@progbits
pair_masks:
        .set pair, 0
        .rept 4
        .set value, 0
        .rept 256
        .byte ((((value & 15) != 0) & 1) | ((((value >> 4) != 0) & 1) << 1)) << (2 * pair)
        .set value, value + 1
        .endr
        .set pair, pair + 1
        .endr
; The bindings and the phase links (secondsight.ld .sprite_links).
        .section .data.art_bindings,"aw",@progbits
art_bindings: .fill 2048, 1, 0          ; slot + 1 of each ROM code, 0 for none
        .section .data.phase_links,"aw",@progbits
phase_links: .fill 4 * 2 * SLOTS, 1, 0xFF ; 4 phase record pointers for each slot; 0xFF none

        .section .text.cache_search,"ax",@progbits

; Find the art of the current object (scene_attr, scene_value), or load it
; into the oldest slot that is not in use.
sprite_cache_search_art:
        ld a,(scene_value)
        and 3
        ld (art_phase),a
        ld de,(scene_attr)
        ld a,d
        and ~ATTR_Y8 & 0xFF             ; art key: the code and the palette
        ld d,a
        ld (art_key),de
        and ATTR_PALETTE
        ld (art_color),a
; Hash by art: all phases share a bucket. Each slot has one chain byte, so
; a search visits only that bucket, not all 128 entries.
        ld a,d
        xor e
        ld (art_hash_key),a
        ld l,a
        ld h,art_hash >> 8
        ld a,(hl)
search_test:
        or a
        jp z,not_found
        dec a
        ld c,a
        add a,a
        ld l,a
        ld h,art_keys >> 8
        ld a,(hl)
        inc hl
        cp e
        jp nz,search_next
        ld a,(hl)
        cp d
        jp nz,search_next
        jp hit
search_next:
        ld l,c
        ld h,art_chain >> 8
        ld a,(hl)
        jp search_test

; Never replace a slot that the queued draws of this update use.
not_found:
        ld a,(art_next)
        ld l,a
        ld h,art_ages >> 8
        ld b,SLOTS
        ld c,0                          ; oldest age
victim:
        ld a,(hl)
        cp c
        jp c,victim_next
        jp z,victim_next
        ld c,a
        ld e,l
        cp STALE_AGE
        jp nc,miss
victim_next:
        inc l
        ld a,l
        and SLOTS - 1
        ld l,a
        djnz victim
        ld a,c
        or a
        ld l,e
        jp nz,miss
; Age 0 means that this picture uses the slot, so no slot is free.
        ld a,CACHE_FAULT
        out0 (CARD_HOST),a
cache_exhausted:
        jp cache_exhausted
hit:
        ld a,l
        srl a
        ld (art_slot),a
        jp cache_resolve
miss:
        ld a,l
        ld (art_slot),a
        call cache_forget
        call cache_retire_art
        push hl
        call cache_relink
        pop hl
        ld a,(art_slot)
        inc a
        and SLOTS - 1
        ld (art_next),a
        ld h,0
        add hl,hl
        ld bc,art_keys
        add hl,bc
        ld de,(art_key)
        ld (hl),e
        inc hl
        ld (hl),d
        call cache_allocate_pixel
cache_full:
        call cache_source_lookup
        cp ABSENT
        jp z,blank

; Read the packed source from its plane into art_temp.
        gc_set GC_MODE, GC_MODE_256     ; write mode 0
        ld a,(art_flags)
        and 3
        ld d,a                          ; segment
        ld bc,OAK_INDEX
        ld a,OAK_READ_SEGMENT
        out (c),a
        inc c
        out (c),d
        ld a,(art_flags)
        rrca
        rrca
        and 3
        ld d,a                          ; plane
        ld bc,VGA_GC_INDEX
        ld a,GC_READ_MAP
        out (c),a
        inc c
        out (c),d
        ld hl,(art_source)
        ld a,h
        .rept 4
        rrca
        .endr
        and 0x0F
        add a,VGA_WINDOW_C000           ; video RAM BBR
        out0 (BBR),a
        ld a,h
        and 0x0F
        or WINDOW_C000 >> 8             ; BBR window
        ld h,a
        ld a,(art_size)
        ld c,a
        ld b,0
        ld de,art_temp
        call sprite_source_fetch

; Copy the bounds and the masks once, when the slot changes.
        ld a,(art_slot)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,art_bounds
        add hl,de
        ex de,hl
        ld hl,art_temp                  ; source bounds
        ld bc,4
        ldir
        ld a,(art_slot)
        ld l,a
        ld h,0
        .rept 5
        add hl,hl
        .endr
        ld de,canonical_masks
        add hl,de
        ld a,(art_temp + 2)
        add a,a                         ; first mask row
        ld e,a
        ld d,0
        add hl,de
        ex de,hl
        ld hl,art_temp + 4              ; source spans
        ld a,(art_temp + 3)
        ld b,a                          ; occupied rows
        ld (art_span_pointer),hl
        call cache_masks_from_spans
; The source is upright. The palette pair latches expand art_temp
; directly into the slot.
        call cache_descriptor
        ld a,(art_new_pixels)
        or a
        call nz,quiet_art_load
        gc_set GC_READ_MAP, 0
        jp cache_publish
blank:
        ld a,(art_slot)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,art_bounds + 3
        add hl,de
        ld (hl),0                       ; height 0: nothing to draw
        jp cache_publish

        .section .text.cache_begin,"ax",@progbits

; Start a picture: age every slot, saturated at 255.
sprite_cache_begin:
        xor a
        ld (art_hidden_count),a
        ld hl,art_ages
        ld b,SLOTS
age_next:
        inc (hl)
        jp nz,age_ready
        dec (hl)
age_ready:
        inc hl
        djnz age_next
        jp cache_age_pixels

        .section .text.cache_relink,"ax",@progbits

; Move art_slot from the chain of its old key to the head of art_hash_key.
cache_relink:
        ld a,(art_slot)
        add a,a
        ld l,a
        ld h,art_keys >> 8
        ld e,(hl)
        inc hl
        ld a,(hl)
        bit 4,a                         ; no key yet
        jp nz,insert_link
        xor e
        ld l,a
        ld h,art_hash >> 8
        ld a,(art_slot)
        inc a
        ld b,a
unlink:
        ld a,(hl)
        cp b
        jp z,unlink_found
        dec a
        ld l,a
        ld h,art_chain >> 8
        jp unlink
unlink_found:
        push hl
        ld a,(art_slot)
        ld l,a
        ld h,art_chain >> 8
        ld a,(hl)
        pop hl
        ld (hl),a
insert_link:
        ld a,(art_hash_key)
        ld l,a
        ld h,art_hash >> 8
        ld b,(hl)
        ld a,(art_slot)
        inc a
        ld (hl),a
        dec a
        ld l,a
        ld h,art_chain >> 8
        ld (hl),b
        ret

        .section .text.cache_clone,"ax",@progbits

; A new alignment reuses the resident pixels, masks and bounds of another
; alignment. Four copies, one for each plane, rotate the lanes. Only the
; occupied rows are copied.
cache_clone:
        call cache_descriptor
        gc_set GC_MODE, GC_MODE_256     ; write mode 0
; Source: the matched alignment, through BBR and the Oak read segment.
        ld hl,(art_match_pixel)
        call cache_pixel_source
        ld d,(hl)                       ; segment
        inc hl
        ld a,(hl)
        inc hl
        add a,2                         ; BBR of the slot
        push af
        ld e,(hl)
        inc hl
        ld a,(hl)
        sub BANK_TO_COMMON >> 8         ; from the CBR window to the BBR window
        ld l,e
        ld h,a
        push hl
; Each phase has a row pitch of four groups; the edge lanes overlap.
        ld a,(art_wire + 4)
        ld c,a
        ld b,4
        mlt bc                          ; offset of the first occupied row
        pop hl
        add hl,bc
        ld (art_clone_source),hl
        pop af
        out0 (BBR),a
        ld bc,OAK_INDEX
        ld a,OAK_READ_SEGMENT
        out (c),a
        inc c
        out (c),d
; Destination: the new alignment, through CBR and the Oak write segment.
        ld hl,(art_pixel)
        call cache_pixel_source
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push af
        ld e,(hl)
        inc hl
        ld a,(hl)
        ld l,e
        ld h,a
        push hl
        ld a,(art_wire + 4)
        ld c,a
        ld b,4
        mlt bc
        pop hl
        add hl,bc
        ld (art_clone_dest),hl
        pop af
        out0 (CBR),a
        ld bc,OAK_INDEX
        ld a,OAK_WRITE_SEGMENT
        out (c),a
        inc c
        out (c),d
; cache_descriptor maps SRAM, so map the source window again.
        ld hl,(art_match_pixel)
        call cache_pixel_source
        inc hl
        ld a,(hl)
        add a,2
        out0 (BBR),a
        xor a
        ld (art_clone_plane),a
clone_plane:
        ld a,(art_source_phase)
        ld b,a
        ld a,(art_phase)
        ld c,a
        ld a,(art_clone_plane)
        add a,b
        sub c
        and 3
        ld (art_clone_lane),a           ; source plane of this destination plane
        ld d,a
        ld bc,VGA_GC_INDEX
        ld a,GC_READ_MAP
        out (c),a
        inc c
        out (c),d
        ld a,(art_clone_plane)
        ld b,a
        inc b
        xor a
        scf
clone_mask:
        rla
        djnz clone_mask
        ld d,a                          ; 1 << plane
        ld bc,VGA_SEQ_INDEX
        ld a,SEQ_MAP_MASK
        out (c),a
        inc c
        out (c),d
; A lane before the phase start is one group later.
        ld hl,(art_clone_source)
        ld a,(art_clone_lane)
        ld b,a
        ld a,(art_source_phase)
        cp b
        jp c,source_ready
        jp z,source_ready
        inc hl
source_ready:
        ld de,(art_clone_dest)
        ld a,(art_clone_plane)
        ld b,a
        ld a,(art_phase)
        cp b
        jp c,destination_ready
        jp z,destination_ready
        inc de
destination_ready:
        ld a,(art_wire + 5)
        add a,a
        add a,a
        ld c,a                          ; rows x 4 groups
        ld b,0
; A CPU copy also works while DMA channel 1 waits for the next packet.
        ldir
        ld a,(art_clone_plane)
        inc a
        ld (art_clone_plane),a
        cp VGA_PLANES
        jp nz,clone_plane
        set_io CBR, game_cbr
        gc_set GC_READ_MAP, 0
        seq_set SEQ_MAP_MASK, ALL_PLANES
        gc_set GC_MODE, GC_MODE_256 | 1 ; write mode 1
        oak_set OAK_WRITE_SEGMENT, 0
        jp cache_publish

        .section .text.cache_prefetch,"ax",@progbits

; Use spare time to prepare another alignment of live, resident art: at
; most one hidden object and one alignment, only below 25 ms. cache_get
; pins the source entry while its pixels are copied. The copies use the
; CPU, so the next packet receive can still run.
sprite_cache_prefetch:
        call prefetch_time
        ret nz
        call prefetch_room
        ret nz                          ; every slot is in use
        ld a,(art_hidden_count)
        or a
        jp z,align_live
        ld b,a
        ld a,(art_hidden_next)
        cp b
        jp c,hidden_index
        xor a
hidden_index:
        ld l,a
        inc a
        ld (art_hidden_next),a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,art_hidden_queue
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (scene_attr),de
        inc hl
        ld a,(hl)
        ld (scene_value),a
        call sprite_cache_get
        call prefetch_room
        ret nz
align_live:
        ld a,(art_prefetch_next)
        ld l,a
        ld h,art_ages >> 8
        ld b,SLOTS
find_live:
        inc l
        res 7,l
        ld a,(hl)
        or a
        jp z,live
        djnz find_live
        ret
live:
        ld a,l
        ld (art_prefetch_next),a
        or art_slot_phases & 0xFF       ; art_slot_phases
        ld l,a
        ld h,art_slot_phases >> 8
        ld a,(hl)
        inc a
        and 3
        ld (hl),a
        ld (scene_value),a
        ld a,(art_prefetch_next)
        add a,a
        ld l,a
        ld h,art_keys >> 8
        ld a,(hl)
        ld (scene_attr),a
        inc hl
        ld a,(hl)
        ld (scene_attr + 1),a
        jp sprite_cache_get

; prefetch_time allows at most 119 pinned phases, and one prefetch adds
; at most two. Every cache has at least 128 slots.
; Out: Z when a slot is free.
prefetch_room:
        ld hl,art_ages
        ld b,SLOTS
room_next:
        ld a,(hl)
        or a
        jp nz,room_free
        inc hl
        djnz room_next
        ld a,1
        or a
        ret
room_free:
        xor a
        ret

        .section .text.prefetch_time,"ax",@progbits

; Out: Z when there is time for a prefetch. Leave headers for the queued
; visible objects and a safe margin before the end of the picture.
prefetch_time:
        ld a,(art_pin_count)
        cp PREFETCH_PINS
        jp nc,busy
        in0 a,(TCR)
        and TCR_TIF0                    ; the picture time ran out
        ret nz
        in0 a,(TMDR0L)
        ld e,a
        in0 a,(TMDR0H)
        ld d,a
        ld hl,0xFFFF - PREFETCH_TIME
        or a
        sbc hl,de
        sbc a,a                         ; 0xFF when there is time
        inc a
        ret
busy:
        ld a,1
        or a
        ret

        .section .text.cache_slot_table,"ax",@progbits

; Out: HL the phase links of art_slot.
cache_slot_table:
        set_io BBR, LINKS_BBR
        ld a,(art_slot)
        ld l,a
        ld h,PHASE_LINKS >> 11
        .rept 3
        add hl,hl
        .endr
        ret

        .section .text.cache_descriptor,"ax",@progbits

; Make the draw header of a new alignment. Trim it to the occupied rows
; once for each replacement.
cache_descriptor:
        call cache_bind_descriptor
cache_build_descriptor:
        ld hl,(art_pixel)
        call cache_pixel_source
        ld de,art_wire
        ld bc,4
        ldir
        call cache_header_pointer
        push de                         ; header
        set_io BBR, 6
        ld a,(art_slot)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,art_bounds + 2
        add hl,de
        ld a,(hl)
        ld (art_wire + 4),a             ; first row
        inc hl
        ld a,(hl)
        ld (art_wire + 5),a             ; rows
        ld a,(art_wire + 4)
        ld l,a
        ld h,0
        call state_times56
        ld (art_wire + 6),hl
        ld a,(art_wire + 4)
        ld l,a
        ld h,0
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        ld de,(art_wire + 2)
        res 5,d                         ; CBR window to BBR window
        add hl,de
        ld (art_wire + 8),hl            ; source pointer
        pop de
; The compiled entry word selects the phase kernel once, when the slot
; changes, not for each drawn object.
        push hl
        ld a,(art_phase)
        add a,a
        ld c,a
        ld b,0
cache_phase_table_selector:
        call sparse_selector
        add hl,bc
        ld a,(hl)
        ld (de),a
        inc de
        inc hl
        ld a,(hl)
        ld (de),a
        inc de
        pop hl
        ld a,(art_wire + 1)
        add a,2
        ld (de),a                       ; BBR
        inc de
        ld a,(art_wire)
        ld (de),a                       ; segment
        inc de
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld hl,(art_wire + 6)
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        inc de                          ; fixed sentinel
        ld a,(art_phase)
        or a
        ld a,4                          ; groups: 4, or 5 for a shifted phase
        jp z,header_width
        inc a
header_width:
        ld (de),a
        inc de
        ld a,(art_wire + 4)
        ld (de),a
        inc de
        ld a,(art_wire + 5)
        ld (de),a
        inc de
        push de
        ld a,(art_slot)
        ld l,a
        ld h,0
        .rept 6
        add hl,hl
        .endr
        ld a,(art_wire + 4)
        add a,a
        add a,a
        ld e,a
        ld a,(art_phase)
        or e
        ld e,a
        ld d,0
        add hl,de
        set 6,h                         ; encoded mask pointer
        set 7,h
        pop de
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        ret

        .section .text.cache_source_lookup,"ax",@progbits

; Read the four fields of the cold source directory entry of art_key
; (one in each plane) into art_source, art_flags and art_size.
; Out: A art_size, ABSENT for no source.
cache_source_lookup:
        ld hl,(art_key)
        ld a,h
        .rept 3
        rlca
        .endr
        and 7                           ; code high bits
        ld h,a
        ld de,sprite_index__group16
        add hl,de
        ld a,h
        .rept 4
        rrca
        .endr
        and 0x0F
        add a,VGA_WINDOW_C000           ; video RAM BBR
        out0 (BBR),a
        ld a,h
        and 0x0F
        or WINDOW_C000 >> 8             ; BBR window
        ld h,a
        oak_set OAK_READ_SEGMENT, sprite_index__vseg
        ld bc,VGA_GC_INDEX
        ld a,GC_READ_MAP
        out (c),a
        inc c
; art_source, art_flags and art_size follow each other.
        .irp plane,0,1,2,3
        ld a,\plane
        out (c),a
        ld a,(hl)
        ld (art_source + \plane),a
        .endr
        cp ABSENT
        call nz,cache_propeller_rows
        ld a,(art_size)
        ret
cache_publish:
        jp cache_ready

        .section .text.quiet_art_load,"ax",@progbits

; Expand the packed source into the slot: each latch read from the palette
; pair table writes two final pixels. Main HL is the packed source and DE
; the output. The alternate HL addresses the pair table, and the alternate
; BC stays on the VGA map mask data register. These are ordinary CPU
; accesses: no DMA, so the packet receive goes on.
        .set saved_cbr, art_flags
        .set rows_left, art_source

quiet_art_load:
        in0 a,(CBR)
        ld (saved_cbr),a
        ld a,(art_wire)
        ld d,a
        ld a,(art_wire + 1)
        out0 (CBR),a
        ld hl,(art_wire + 8)
        set 5,h                         ; BBR window to CBR window
        ld (art_clone_dest),hl
        ld bc,OAK_INDEX
        ld a,OAK_WRITE_SEGMENT
        out (c),a
        inc c
        out (c),d
        oak_set OAK_READ_SEGMENT, sprite_pairs__vseg
cache_decoder_window:                   ; cache_propeller_rows sets the window
        set_io BBR, sprite_pairs__vbbr4k
        gc_set GC_MODE, GC_MODE_256 | 1 ; write mode 1
        ld bc,VGA_SEQ_INDEX
        ld a,SEQ_MAP_MASK
        out (c),a
        inc c
        ld a,(art_color)
        add a,WINDOW_C000 >> 8          ; pair table page of the palette
        ld h,a
        exx
        ld a,(art_wire + 5)
        ld (rows_left),a
        ld hl,(art_span_pointer)        ; the first occupied row
quiet_row:
        ld a,(hl)
        inc hl
        cp 0xFF                         ; empty row
        jp z,cache_pair_next_row
; The span header holds the length - 1. Copy (length - 1) / 2 pairs, then
; a tail of one or two pixels. No write goes into the next slot.
        ld c,a
        .rept 5
        rrca
        .endr
        and 7                           ; pairs before the tail
        ld b,a
        ld a,c
        and 0x0F                        ; first pixel
        ld e,a
        ld a,(art_phase)
        add a,e
        ld e,a
        and 3
        push af                         ; lane of the first pair
        ld a,e
        srl a
        srl a
        ld e,a
        ld d,0
        push hl
        ld hl,(art_clone_dest)
        add hl,de
        ex de,hl
        pop hl
        pop af
        exx
        push hl
        add a,a
        ld l,a
        ld h,0
        ld de,latch_entries
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        push de
        exx
        ret                             ; to the entry of the lane
latch_entries:
        .word cache_latch_test_0, cache_latch_test_1, cache_latch_test_2, cache_latch_test_3

; One pair for each latch read. An odd lane swaps the two pixels. The last
; pair is one pixel if bit 4 of the header is 0, else two.
        .macro latch_pair lane, next
cache_latch_test_\lane:
        ld a,b
        or a
        .if \lane == 0
        jr z,cache_latch_tail_0
        .else
        jp z,cache_latch_tail_\lane
        .endif
cache_latch_pair_\lane:
        ld a,(hl)
        inc hl
        .if \lane & 1
        .rept 4
        rrca
        .endr
        .endif
        exx
        ld l,a
        ld a,(hl)                       ; load all four latches
        ld a,(3 << \lane) & 0x0F
        out (c),a
        exx
        ld (de),a
        .if \lane == 3
        inc de                          ; the second pixel is in the next group
        exx
        ld a,1
        out (c),a
        exx
        ld (de),a
        .elseif \lane == 2
        inc de
        .endif
        dec b
        jr nz,cache_latch_pair_\next
        .if \next == 0
        jr cache_latch_tail_0
        .else
        jp cache_latch_tail_\next
        .endif
        .endm

        .macro latch_tail lane
cache_latch_tail_\lane:
        ld a,(hl)
        inc hl
        .if \lane & 1
        .rept 4
        rrca
        .endr
        .endif
        exx
        ld l,a
        ld a,(hl)
        exx
        bit 4,c
        jr z,cache_latch_single_\lane
        exx
        ld a,(3 << \lane) & 0x0F
        out (c),a
        exx
        ld (de),a
        .if \lane == 3
        inc de
        exx
        ld a,1
        out (c),a
        exx
        ld (de),a
        .endif
        jr cache_pair_next_row
cache_latch_single_\lane:
        exx
        ld a,1 << \lane
        out (c),a
        exx
        ld (de),a
        jr cache_pair_next_row
        .endm

        latch_pair 0, 2
        latch_pair 1, 3
        latch_pair 2, 0
        latch_pair 3, 1
        latch_tail 0
        latch_tail 1
        latch_tail 2
        latch_tail 3

cache_pair_next_row:
        push hl
        ld hl,(art_clone_dest)
        ld de,4                         ; row pitch in groups
        add hl,de
        ld (art_clone_dest),hl
        pop hl
        ld a,(rows_left)
        dec a
        ld (rows_left),a
        jp nz,quiet_row
        seq_set SEQ_MAP_MASK, ALL_PLANES
        oak_set OAK_WRITE_SEGMENT, 0
        ld a,(saved_cbr)
        out0 (CBR),a
        ret

        .section .text.cache_boot_clear,"ax",@progbits

; At boot, clear every phase slot in all planes with a fixed-source DMA of
; the zero byte art_next. The list of ranges follows this code
; (cache_boot_clear_ranges, generated): segment, address, groups for each
; range, then 0xFF.
cache_boot_clear:
        write_mode 0
        set_io SAR0L, art_next & 0xFF
        set_io SAR0H, art_next >> 8
        set_io SAR0B, art_next >> 16
        set_io DAR0B, VGA_WINDOW >> 16
        set_io DMODE, DMODE_BURST | DMODE_SOURCE_FIXED
        set_io DCNTL, 0
        ld hl,cache_boot_clear_ranges
next_range:
        ld a,(hl)
        inc hl
        cp 0xFF
        jp z,cache_boot_clear_done
        ld e,a
        ld bc,OAK_INDEX
        ld a,OAK_WRITE_SEGMENT
        out (c),a
        inc c
        ld a,e
        out (c),a
        .irp port,DAR0L,DAR0H,BCR0L,BCR0H
        ld a,(hl)
        inc hl
        out0 (\port),a
        .endr
        set_io DSTAT, DSTAT_DE0 | DSTAT_DME
        jp next_range

        .section .text.cache_allocate_pixel,"ax",@progbits

; Choose the phase record of a new alignment: restore it from the archive,
; or replace a record by the clock. The low seven bits of a record stamp pin
; the current picture. The reference bit gives one more pass before the
; record is replaced.
cache_allocate_pixel:
        call archive_find
        jp c,pixel_bind
        set_io BBR, RECORDS_BBR
        ld hl,(art_pixel_next)
        ld bc,phase_clock_passes
pixel_victim:
        push hl
        push de
        ld de,(art_match_pixel)
        or a
        sbc hl,de
        pop de
        pop hl
        jp z,pixel_next_record          ; the clone source stays
        .rept RECORD_STAMP
        inc hl
        .endr
        ld a,(hl)
        and STAMP_BITS
        ld d,a
        ld a,(art_stamp)
        cp d
        jp z,still_pinned
        bit 7,(hl)                      ; REFERENCE
        res 7,(hl)
        .rept RECORD_STAMP
        dec hl
        .endr
        jp z,pixel_chosen
        jp pixel_next_record
still_pinned:
        .rept RECORD_STAMP
        dec hl
        .endr
pixel_next_record:
        ld a,l
        add a,RECORD_SIZE
        ld l,a
        jp nc,no_carry
        inc h
no_carry:
        ld a,h
        cp phase_record_end >> 8
        jp nz,in_range
        ld a,l
        cp phase_record_end & 0xFF
        jp nz,in_range
        ld hl,PHASE_RECORDS
in_range:
        dec bc
        ld a,b
        or c
        jp nz,pixel_victim
        jp cache_exhausted
pixel_chosen:
        ld (art_pixel),hl
        ld (art_pixel_next),hl
; Remove only the old binding of this phase. The other phases and the mask
; of the old art stay.
        inc hl
        inc hl
        ld a,(hl)
        rrca
        and 6                           ; phase x 2: offset in the phase links
        ld c,a
        inc hl
        ld (hl),0                       ; stamp
        inc hl
        ld a,(hl)
        cp 0xFF                         ; no owner
        jp z,pixel_bind
        ld l,a
        ld h,8
        mlt hl
        ld de,PHASE_LINKS
        add hl,de
        ld e,c
        ld d,0
        add hl,de
        set_io BBR, LINKS_BBR
        ld (hl),0xFF
        inc hl
        ld (hl),0xFF
pixel_bind:
        set_io BBR, RECORDS_BBR
        ld hl,(art_pixel)
        inc hl
        inc hl
        ld a,(hl)
        and 3                           ; segment
        ld b,a
        ld a,(art_phase)
        add a,a
        add a,a
        or b
        ld (hl),a
        inc hl
        ld (hl),0                       ; stamp
        inc hl
        ld a,(art_slot)
        ld (hl),a                       ; owner
        inc hl
        inc hl
        ld de,(art_key)
        ld (hl),e
        inc hl
        ld (hl),d
        call cache_slot_table
        ld d,0
        ld a,(art_phase)
        add a,a
        ld e,a
        add hl,de
        ld de,(art_pixel)
        ld (hl),e
        inc hl
        ld (hl),d
        ld a,(art_new_pixels)
        or a
        ret z
        jp archive_store

; A stamp pins the current picture with no list and no unpin pass. When
; the stamp wraps, clear the old stamps before the picture is queued, so
; an old record cannot look pinned.
cache_age_pixels:
        xor a
        ld (art_pin_count),a
        ld a,(art_stamp)
        inc a
        and STAMP_BITS
        jp nz,stamp_ready
        call cache_epoch_clear
        ld a,1
stamp_ready:
        ld (art_stamp),a
        ret

        .section .text.cache_retire_art,"ax",@progbits

; Free the four phase links of art_slot and the owner of their records.
cache_retire_art:
        push hl
        push bc
        push de
        call cache_slot_table
        ld d,0
        ld b,4
retire_phase:
        set_io BBR, LINKS_BBR
        ld e,(hl)
        ld (hl),0xFF
        inc hl
        ld d,(hl)
        ld (hl),0xFF
        inc hl
        ld a,d
        cp 0xFF                         ; no record
        jp z,retire_next
        push hl
        ex de,hl
        .rept RECORD_OWNER - 1
        inc hl
        .endr
        set_io BBR, RECORDS_BBR
        inc hl
        ld (hl),0xFF                    ; no owner
        pop hl
retire_next:
        djnz retire_phase
        ld hl,0xFFFF                    ; no clone source
        ld (art_match_pixel),hl
        pop de
        pop bc
        pop hl
        ret

; In: HL phase record. Out: HL art_pixel_origin: segment, CBR, CBR window
; address of the pixels.
cache_pixel_source:
        set_io BBR, RECORDS_BBR
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        and 3
        ld (art_pixel_origin),a
        ld a,d
        .rept 4
        rrca
        .endr
        and 0x0F
        add a,VGA_WINDOW_E000           ; video RAM CBR
        ld (art_pixel_origin + 1),a
        ld a,e
        ld (art_pixel_origin + 2),a
        ld a,d
        and 0x0F
        or WINDOW_E000 >> 8             ; CBR window
        ld (art_pixel_origin + 3),a
        ld hl,art_pixel_origin
        ret

; Clear every stamp and keep the reference bits.
cache_epoch_clear:
        set_io BBR, RECORDS_BBR
        ld hl,PHASE_RECORDS + RECORD_STAMP
        ld bc,phase_record_count
        ld de,RECORD_SIZE
epoch_next:
        ld a,(hl)
        and REFERENCE
        ld (hl),a
        add hl,de
        dec bc
        ld a,b
        or c
        jp nz,epoch_next
        ret

        .section .text.cache_bindings,"ax",@progbits

; Each ROM code has a binding to its art slot. A hit checks the palette and
; selects the phase. Only a full miss reads the cold source directory.
sprite_cache_object:
sprite_cache_get:
        ld a,(scene_value)
        and 3
        ld (art_phase),a
        ld hl,(scene_attr)
        ld a,h
        .rept 3
        rlca
        .endr
        and 7                           ; code high bits
        or BINDINGS >> 8
        ld h,a
        ld (art_binding),hl
        set_io BBR, LINKS_BBR
        ld a,(hl)
        or a
        jr z,object_miss
        dec a
        ld (art_slot),a
        add a,a
        ld l,a
        ld h,art_keys >> 8
        inc l
        ld a,(scene_attr + 1)
        xor (hl)
        and ATTR_PALETTE                ; palette
        jr nz,object_miss
        jp cache_resolve_bound
object_miss:
        call sprite_cache_search_art
        push af
        push hl
        set_io BBR, LINKS_BBR
        ld hl,(art_binding)
        ld a,(art_slot)
        inc a
        ld (hl),a
        pop hl
        pop af
        ret

; Clear the binding of the old key of art_slot, if it still points here.
cache_forget:
        push hl
        push de
        push bc
        ld a,(art_slot)
        add a,a
        ld l,a
        ld h,art_keys >> 8
        ld e,(hl)
        inc hl
        ld a,(hl)
        bit 4,a                         ; no key yet
        jr nz,forgotten
        .rept 3
        rlca
        .endr
        and 7
        or BINDINGS >> 8
        ld h,a
        ld l,e
        set_io BBR, LINKS_BBR
        ld a,(art_slot)
        inc a
        cp (hl)
        jr nz,forgotten
        ld (hl),0
forgotten:
        pop bc
        pop de
        pop hl
        ret

        .section .text.cache_ready,"ax",@progbits

; Pin the phase for this picture and give the object its draw header.
; In: HL phase record (from cache_ready_pointer). Out: A height, HL bounds,
; NZ when the art is visible.
cache_ready:
        ld hl,(art_pixel)
cache_ready_pointer:
        set_io BBR, RECORDS_BBR
        .rept RECORD_STAMP
        inc l
        .endr
        ld a,(hl)
        and STAMP_BITS
        ld b,a
        ld a,(art_stamp)
        cp b
        jp z,already_pinned
        or REFERENCE
        ld (hl),a
        ld a,(art_pin_count)
        inc a
        ld (art_pin_count),a
already_pinned:
        inc l
        inc l
        ld a,(hl)
        cp 0xFF                         ; no draw header
        jp z,make_header
ready_header:
        ld l,a
        ld h,HEADERS >> 12
        .rept 4
        add hl,hl
        .endr
        ld (scene_desc + 2),hl
        ld hl,HEADERS_BBR
        ld (scene_desc),hl
        ld a,(art_slot)
        ld l,a
        ld h,art_ages >> 8
        ld (hl),0
        ld hl,0                         ; high priority ID
        ld a,(scene_attr + 1)
        and ATTR_LOW_PALETTE
        cp LOW_PALETTES                 ; palettes 10 and 11
        jp nz,ready_bounds
        ld hl,(scene_desc + 2)
        srl h
        rr l
        ld de,art_headers__half + 1 - (WINDOW_C000 >> 1) ; the descriptor word of the header
        add hl,de
ready_bounds:
        ld (scene_priority),hl
        ld a,(art_slot)
        ld l,a
        ld h,4
        mlt hl
        ld de,art_bounds + 3
        add hl,de
        ld a,(hl)
        .rept 3
        dec hl
        .endr
        or a
        ret
make_header:
        call cache_bind_descriptor
        call cache_build_descriptor
        set_io BBR, RECORDS_BBR
        ld hl,(art_pixel)
        ld a,l
        add a,RECORD_HEADER
        ld l,a
        ld a,(hl)
        jp ready_header

        .section .text.cache_resolve,"ax",@progbits

; Find the phase record of art_phase for art_slot.
cache_resolve:
        set_io BBR, LINKS_BBR
; The bindings have selected BBR 11 already. Multiply the base with the
; slot: no call, bank write or base addition.
cache_resolve_bound:
        ld a,(art_slot)
        ld l,a
        ld h,PHASE_LINKS >> 11
        .rept 3
        add hl,hl
        .endr
        ld a,(art_phase)
        add a,a
        or l
        ld l,a
        ld e,(hl)
        inc l
        ld d,(hl)
        ex de,hl
        ld (art_pixel),hl
        ld a,h
        cp 0xFF                         ; no record for the phase
        jp nz,cache_ready_pointer
; Search the four links of the key. A hit copies no pixels and no mask.
        call cache_slot_table
        ld d,0
        ld b,4
        ld c,0                          ; phase
other_phase:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        cp 0xFF
        jr nz,have_phase
        inc c
        djnz other_phase
        ld de,0xFFFF                    ; no source phase
have_phase:
        ld (art_match_pixel),de
        ld a,c
        ld (art_source_phase),a
        ld a,d
        cp 0xFF
        jr z,phase_needed
        ld a,(art_slot)
        ld l,a
        ld h,4
        mlt hl
        ld de,art_bounds + 3
        add hl,de
        ld a,(hl)
        or a
        jr nz,phase_needed
; Empty art: every phase uses the record of the other phase.
        ld hl,(art_match_pixel)
        ld (art_pixel),hl
        ld a,(art_source_phase)
        ld (art_phase),a
        jp cache_ready
phase_needed:
        ld hl,(scene_attr)
        res 4,h                         ; not part of the key
        ld (art_key),hl
        ld a,h
        and 0x0F
        ld (art_color),a
        call cache_allocate_pixel
        ld a,(art_new_pixels)
        or a
        jr z,restored_phase
        ld hl,(art_match_pixel)
        ld a,h
        cp 0xFF
        jp nz,cache_clone
; No phase has pixels: get the key and the palette of a direct binding hit
; again, then load the art.
        ld a,(art_slot)
        add a,a
        ld l,a
        ld h,art_keys >> 8
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (art_key),de
        ld a,d
        and 0x0F
        ld (art_color),a
        jp cache_full
restored_phase:
        call cache_descriptor
        jp cache_ready

        .section .text.cache_masks,"ax",@progbits

; Make the shared mask from the packed pixels, on a full miss only. Four
; lookup pages put the two opaque bits of a pair at their final offset.
; Eight entries in a line replace a 16-bit shift loop for each pair.
; In: HL packed spans, DE mask output, B rows.
cache_masks_from_spans:
        ld a,b
        ld (art_rows),a
        set_io BBR, HEADERS_BBR
mask_row:
        ld a,(hl)
        inc hl
        cp 0xFF                         ; empty row
        jp z,mask_blank
        push de
        ld c,a
        ld b,SPAN_MASKS >> 8
        ld a,(bc)
        ld e,a
        inc b
        ld a,(bc)
        ld d,a
        or e
        jp nz,mask_interval
; A span with holes: restore its header for the pixel decoder.
        ld b,SPAN_HEADERS >> 8
        ld a,(bc)
        dec hl
        ld (hl),a
        inc hl
        push af                         ; first pixel
        .rept 5
        rrca
        .endr
        and 7                           ; pairs
        ld e,a
        ld d,0
        inc de
        add hl,de
        push hl                         ; next source row
        push hl                         ; pair cursor
        add a,a
        ld l,a
        ld h,0
        ld de,source_mask_entries
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        push de
        ld de,0                         ; empty mask
        ret                             ; to the entry for the pair count
source_mask_pair_done:
        ex de,hl
        pop de                          ; next row
        pop af                          ; first pixel
        push de
        and 0x0F
        jp z,mask_aligned
        ld b,a
mask_shift:
        add hl,hl
        djnz mask_shift
mask_aligned:
        ld b,h
        ld c,l
        pop hl                          ; next source row
        pop de                          ; mask output
        jp mask_store
mask_interval:
        ld a,c
        .rept 5
        rrca
        .endr
        and 7
        inc a                           ; bytes of the span
        ld c,a
        ld b,0
        add hl,bc
        ld b,d
        ld c,e
        pop de
        jp mask_store
mask_blank:
        ld bc,0
mask_store:
        ld a,c
        ld (de),a
        inc de
        ld a,b
        ld (de),a
        inc de
        ld a,(art_rows)
        dec a
        ld (art_rows),a
        jp nz,mask_row
        ret

        .section .text.source_mask_entries,"ax",@progbits

; Mask of up to eight pairs, read from the last pair backward.
source_mask_entries:
        .irp pair,0,1,2,3,4,5,6,7
        .word source_mask_pair_\pair
        .endr
        .irp pair,7,6,5,4,3,2,1,0
source_mask_pair_\pair:
        ld b,(PAIR_MASKS >> 8) + \pair % 4
        dec hl
        ld c,(hl)
        ld a,(bc)
        or e
        ld e,a
        .if \pair == 4
        ld d,e                          ; the high byte is complete
        ld e,0
        .endif
        .endr
        jp source_mask_pair_done

        .section .text.cache_headers,"ax",@progbits

; A ring of 128 draw headers is enough for one queued picture.
; Out: A 1 for a new header, 0 when the record has one.
cache_bind_descriptor:
        set_io BBR, RECORDS_BBR
        ld hl,(art_pixel)
        ld de,RECORD_HEADER
        add hl,de
        ld a,(hl)
        cp 0xFF
        jr z,allocate_header
        xor a
        ret
allocate_header:
        ld a,(art_header_next)
        ld c,a
        ld b,HEADER_RING
header_candidate:
        ld l,c
        ld h,HEADER_SIZE
        mlt hl
        ld de,HEADERS + HEADER_OWNER
        add hl,de
        set_io BBR, HEADERS_BBR
        ld e,(hl)
        inc hl
        ld d,(hl)
        dec hl
        push hl                         ; owner field
        ld a,d
        cp 0xFF                         ; no owner
        jp z,header_chosen
; A header of a record of this picture stays.
        ex de,hl
        .rept RECORD_STAMP
        inc hl
        .endr
        set_io BBR, RECORDS_BBR
        ld a,(art_stamp)
        xor (hl)
        and STAMP_BITS
        jp z,header_next
        inc hl
        inc hl
        ld (hl),0xFF                    ; the old owner has no header
header_chosen:
        set_io BBR, HEADERS_BBR
        pop hl
        ld de,(art_pixel)
        ld (hl),e
        inc hl
        ld (hl),d
        ld de,-(HEADER_OWNER + 1) & 0xFFFF
        add hl,de
        ex de,hl                        ; DE header
        ld hl,(art_pixel)
        push de
        ld de,RECORD_HEADER
        add hl,de
        pop de
        set_io BBR, RECORDS_BBR
        ld (hl),c
        ld a,c
        inc a
        and HEADER_RING - 1
        ld (art_header_next),a
        ld a,1
        or a
        ret
header_next:
        pop hl
        inc c
        res 7,c                         ; HEADER_RING
        djnz header_candidate
        jp cache_exhausted

        .section .text.sprite_mark,"ax",@progbits

; Mark the row bounds D (left) and E (right) of B rows at HL in the damage
; map: two bytes for each row. Use the straight loop when no map page wraps.
sprite_mark_fast:
        ld a,b
        or a
        jp z,mark_slow
        cp 0x80
        jp nc,mark_slow
        add a,a
        add a,l
        jp c,mark_slow
        jp z,mark_slow
mark_fast_row:
        ld a,(hl)
        cp d
        jr c,1f
        ld (hl),d
1:      inc l
        ld a,(hl)
        cp e
        jr nc,2f
        ld (hl),e
2:      inc l
        djnz mark_fast_row
        ret
mark_slow:
        ld a,(hl)
        cp d
        jp c,mark_right
        ld (hl),d
mark_right:
        inc l
        ld a,(hl)
        cp e
        jp nc,mark_next
        ld (hl),e
mark_next:
        inc l
        jp nz,mark_same
        ld a,h
        xor 1                           ; the other half of the map
        ld h,a
mark_same:
        djnz mark_slow
        ret

        .section .text.sprite_fast,"ax",@progbits

; Select the mask shift for the pan (0-7 pixels) once for each sprite, not
; for every coverage pair of every row.
sprite_mask_select:
        add a,a
        ld l,a
        ld h,0
        ld de,mask_shifts
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld (game_mask_dispatch+1),hl
        ret
mask_shifts:
        .irp shift,0,1,2,3,4,5,6,7
        .word sprite_mask_shift_\shift
        .endr
; In: C mask byte, (HL) the byte before it. Out: A the mask shifted right.
        .irp shift,0,1,2,3,4,5,6,7
sprite_mask_shift_\shift:
        .if \shift == 0
        ld a,c
        .elseif \shift <= 3
        ld b,(hl)
        .rept \shift
        srl b
        rr c
        .endr
        ld a,c
        .else
        ld a,c
        .rept 8 - \shift
        rlca
        .endr
        and (1 << (8 - \shift)) - 1
        ld b,a
        ld a,(hl)
        .rept 8 - \shift
        rlca
        .endr
        and 0xFF ^ ((1 << (8 - \shift)) - 1)
        or b
        .endif
        ret
        .endr

; Copy C bytes of packed source from HL (video RAM through BBR) to DE.
; DMA is used only while DMA channel 1 is off, before the next ready token.
; The prefetch runs after that token and copies by CPU.
sprite_source_fetch:
        in0 a,(DSTAT)
        and DSTAT_DE1                   ; a packet receive runs
        jp nz,source_cpu
        ld a,l
        out0 (SAR0L),a
; Physical source: the BBR window at WINDOW_C000 in the VGA window.
        in0 a,(BBR)
        add a,WINDOW_C000 >> 12
        .rept 4
        rlca
        .endr
        and 0xF0
        ld d,a
        ld a,h
        and 0x0F
        or d
        out0 (SAR0H),a
        set_io SAR0B, VGA_WINDOW >> 16
        set_io DAR0L, art_temp & 0xFF
        set_io DAR0H, art_temp >> 8
        set_io DAR0B, art_temp >> 16
        out0 (BCR0L),c
        set_io BCR0H, 0
        set_io DMODE, DMODE_BURST
        set_io DSTAT, DSTAT_DE0 | DSTAT_KEEP1 | DSTAT_DME
        set_io DAR0B, VGA_WINDOW >> 16  ; the sprite copies write video RAM
        ret
source_cpu:
        ldir
        ret

; Mark the screen groups and rows of the current sprite as damage. The
; occupied bounds (scene_bounds: left, right, first row, end row) are in
; pixels and rows of the unshifted art.
sprite_damage_bounds:
        ld a,(scene_value)
        and 3                           ; phase
        ld b,a
        ld a,(scene_bounds)
        add a,b
        srl a
        srl a
        ld e,a
        ld d,0
        ld hl,(scene_xrec)
        add hl,de
        bit 7,h
        jp z,damage_left
        ld l,0
damage_left:
        ld c,l
        ld a,(scene_bounds + 1)
        add a,b
        add a,3                         ; round up to a group
        srl a
        srl a
        ld e,a
        ld hl,(scene_xrec)
        add hl,de
        bit 7,h
        ret nz
        ld a,l
        cp GROUPS_PER_ROW
        jp c,damage_right
        ld a,GROUPS_PER_ROW
damage_right:
        cp c
        ret c
        ret z
        ld d,c
        ld e,a
        push de                         ; left and right
        ld hl,(scene_yrec)
        ld a,(scene_bounds + 2)
        ld e,a
        ld d,0
        add hl,de
        ld c,l
        bit 7,h
        jp z,damage_top
        ld c,0                          ; first visible row
damage_top:
        ld a,(scene_bounds + 3)
        ld e,a
        add hl,de
        ld a,h
        or a
        jp z,damage_bottom
        ld l,0                          ; the bottom row modulo 256
damage_bottom:
        ld a,l
        sub c
        ld b,a
        ld a,(scene_ring_start)
        add a,c
        pop de
        jp scroll_mark

; Archive: the expanded pixels of a phase stay after its art slot is
; replaced. A 16 KB directory in video RAM holds a phase record pointer for
; each ROM code and phase. A pointer is used only when its phase record
; still has the same key and phase, so no sweep clears old pointers.

        .section .text.archive_banked,"ax",@progbits

; Out: carry set and art_pixel when the archive holds the pixels;
; art_new_pixels 0 then, else 1.
archive_find_banked:
        ld a,1
        ld (art_new_pixels),a
        call archive_index_address
        call archive_read_index
        ld a,d
        and 0xF0
        cp PHASE_RECORDS >> 8           ; a phase record pointer
        jp nz,archive_absent
        ld (art_pixel),de
        call archive_read_tag
        ld e,a
        ld a,(art_phase)
        add a,a
        add a,a
        cp e
        jp nz,archive_absent
        ld hl,(art_key)
        or a
        sbc hl,bc
        jp nz,archive_absent
        xor a
        ld (art_new_pixels),a
        scf
        ret
archive_absent:
        or a
        ret
archive_store_banked:
        call archive_index_address
        jp archive_write_index

; Out: HL the directory entry of art_key and art_phase, A its first plane.
; Phases 0 and 1 share an entry (planes 0 and 1), and so do 2 and 3
; (planes 2 and 3).
archive_index_address:
        ld hl,(art_key)
        ld a,h
        .rept 3
        rlca
        .endr
        and 7                           ; code high bits
        ld h,a
        add hl,hl
        ld a,(art_phase)
        srl a
        ld e,a
        ld d,0
        add hl,de
        set 6,h                         ; BBR window
        set 7,h
        ld a,(art_phase)
        and 1
        add a,a
        ret

        .section .text.archive_find,"ax",@progbits

; archive_find: find the archived phase of the current art (the banked
; archive_find_banked, with the links page mapped), then map the phase
; records again. archive_store: store it (archive_store_banked).
archive_find:
        set_io BBR, LINKS_BBR
        call archive_find_banked
        set_io BBR, RECORDS_BBR
        ret
archive_store:
        set_io BBR, LINKS_BBR
        jp archive_store_banked

; In: HL directory entry, A first plane. Out: DE the pointer.
archive_read_index:
        ld d,a
        oak_set OAK_READ_SEGMENT, sprite_archive__vseg
        set_io BBR, sprite_archive__vbbr4k
        ld bc,VGA_GC_INDEX
        ld a,GC_READ_MAP
        out (c),a
        inc c
        out (c),d
        ld e,(hl)
        inc d
        out (c),d
        ld d,(hl)
        set_io BBR, LINKS_BBR
        ret

; Out: DE the draw header of art_pixel in the HEADERS window.
cache_header_pointer:
        set_io BBR, RECORDS_BBR
        ld hl,(art_pixel)
        ld de,RECORD_HEADER
        add hl,de
        ld l,(hl)
        ld h,HEADER_SIZE
        mlt hl
        set 6,h                         ; HEADERS
        set 7,h
        ex de,hl
        ret

        .section .text.archive_read_tag,"ax",@progbits

; In: DE phase record. Out: A its phase << 2, BC its key.
archive_read_tag:
        ex de,hl
        set_io BBR, RECORDS_BBR
        inc hl
        inc hl
        ld a,(hl)
        and 0x0C                        ; the phase << 2
        ld e,a
        .rept 4
        inc hl
        .endr
        ld c,(hl)
        inc hl
        ld b,(hl)
        set_io BBR, LINKS_BBR
        ld a,e
        ret

        .section .text.archive_write_index,"ax",@progbits

; Write art_pixel to the directory entry HL. In: Z for the first plane pair.
archive_write_index:
        or a
        ld a,1                          ; plane 0
        jr z,1f
        ld a,4                          ; plane 2
1:      ld (art_write_mask),a
        gc_set GC_MODE, GC_MODE_256     ; write mode 0
        oak_set OAK_WRITE_SEGMENT, sprite_archive__vseg
        set_io BBR, sprite_archive__vbbr4k
        ld bc,VGA_SEQ_INDEX
        ld a,SEQ_MAP_MASK
        out (c),a
        inc c
        ld a,(art_write_mask)
        out (c),a
        ld de,(art_pixel)
        ld (hl),e
        ld a,(art_write_mask)
        add a,a                         ; the next plane
        out (c),a
        ld (hl),d
        ld a,ALL_PLANES
        out (c),a
        gc_set GC_MODE, GC_MODE_256 | 1 ; write mode 1
        oak_set OAK_WRITE_SEGMENT, 0
        set_io BBR, LINKS_BBR
        ret

        .section .common.sparse_selector,"ax",@progbits

; Out: HL the phase kernel table for the art of art_slot: the sparse
; programs of the arcade shot sprite, else the canonical kernels. A header
; can also be made on a direct binding hit, where art_key is old, so read
; the key of the slot. The code is position independent.
        .equ SHOT_CODE, 0x0BF

sparse_selector:
        ld a,(art_slot)
        add a,a
        ld l,a
        ld h,art_keys >> 8
        ld a,(hl)
        cp SHOT_CODE & 0xFF
        jr nz,1f
        inc l
        ld a,(hl)
        and ATTR_CODE_HIGH              ; code high bits
        jr nz,1f
        ld hl,sparse_phase_table
        ret
1:      ld hl,object_canonical_kernels
        ret

        .section .text.cache_propeller,"ax",@progbits

; The palette rows of a miss (scripts/propellers.py). Propeller art (the
; bit of its pair set in the code's byte of sprite_prop_masks) reads its
; pair's row in the propeller window; other art reads the pair table.
cache_propeller_rows:
        ld hl,(art_key)
        ld a,h
        .rept 3
        rlca
        .endr
        and 7
        ld h,a                          ; HL = ROM code
        ld a,l
        and 3
        ld d,a                          ; plane of its mask byte
        srl h
        rr l
        srl h
        rr l                            ; group of its mask byte
        ld bc,sprite_prop_masks__group16
        add hl,bc
        ld a,h
        .rept 4
        rrca
        .endr
        and 0x0F
        add a,VGA_WINDOW_C000           ; video RAM BBR
        out0 (BBR),a
        ld a,h
        and 0x0F
        or WINDOW_C000 >> 8             ; BBR window
        ld h,a
        oak_set OAK_READ_SEGMENT, sprite_prop_masks__vseg
        ld bc,VGA_GC_INDEX
        ld a,GC_READ_MAP
        out (c),a
        inc c
        out (c),d
        ld b,(hl)                       ; bit P: pair P flips
        ld a,(art_color)
        srl a
        ld c,a                          ; pair
        inc a
propeller_bit:
        rr b                            ; carry: the bit of the pair
        dec a
        jr nz,propeller_bit
        jr nc,propeller_none
        ld a,c
        cp 5
        ccf
        sbc a,0                         ; row: pairs 0-3, then 5 and 6
        ld (art_color),a
        ld a,sprite_pairs__vbbr4k + 1   ; the rows follow the pair table
        jr propeller_window
propeller_none:
        ld a,sprite_pairs__vbbr4k
propeller_window:
        ld (cache_decoder_window + 1),a
        ret
