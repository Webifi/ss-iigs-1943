; Object kernel: draw immutable art rectangles, with the clipping at the
; screen edges and the priority clip against the foreground. Each
; rectangle is staged as a rectangle command at object_stage, then its
; latch program draws it.

        .include "video.inc"
        .include "rect.inc"

        .global native_object_priority, state_unpack_descriptor, object_expand_masks
        .global native_object_clipped, native_object, object_parameters, native_object_next
        .global object_descriptor_ready, object_draw_staged, native_object_done, object_clip
        .global object_compact_header, object_expand_canonical, object_trim_vertical
        .global object_compiled_select, object_compiled_done, object_canonical_kernels
        .global object_priority_masks
        .global object_descriptor, object_descriptor_bbr, object_caller_sp, object_base
        .global object_columns, object_rows, object_flags, object_width, object_x, object_y

        .equ CLIPPED, 0x01              ; object_flags: clip at the screen edges
        .equ PRIORITY, 0x02             ; object_flags: clip against the foreground
        .equ COMPACT, 0xFF              ; descriptor: compact full-width rectangle
        .equ CANONICAL, 0xC0            ; mask pointer at or above: a canonical silhouette

; Object stage fields after the rectangle command.
        .equ STAGE_PACKED_MASKS, 14     ; packed mask runs
        .equ STAGE_EXPANDED, 0xA0       ; expanded masks
        .equ STAGE_CANONICAL_SP, 0xF6
        .equ STAGE_CANONICAL_SOURCE, 0xF8
        .equ STAGE_ROWS_LEFT, 0xFD
        .equ STAGE_PHASE, 0xFE
        .equ STAGE_MASK_HIGH, 0xFF

        .section .vars.object_kernel,"aw",@nobits
object_descriptor: .ds.b 2
object_descriptor_bbr: .ds.b 1
object_caller_sp: .ds.b 2
object_base: .ds.b 2                    ; physical destination base
object_columns: .ds.b 1                 ; visible column bits
object_rows: .ds.b 2                    ; visible row bits
object_flags: .ds.b 1                   ; CLIPPED, PRIORITY
object_width: .ds.b 1                   ; rectangle width in groups
object_x: .ds.b 1                       ; rectangle column in the object
object_y: .ds.b 1                       ; rectangle row in the object
object_constant: .ds.b 1
object_rows_left: .ds.b 1
object_column_mask: .ds.b 3             ; map masks of groups 1-4
object_fifth_mask: .ds.b 1
object_row_bits: .ds.b 2
object_body_end: .ds.b 2
object_fill: .ds.b 2

        .section .vars.priority,"aw",@nobits
priority_world: .ds.b 2                 ; foreground world row at the sprite top
priority_left: .ds.b 2                  ; sprite left group
priority_base: .ds.b 2
priority_world_row: .ds.b 2
priority_mask: .ds.b 2
        .ds.b 4
priority_width: .ds.b 1
priority_stride: .ds.b 1
priority_group: .ds.b 2
priority_rows: .ds.b 2
priority_count: .ds.b 2
        .ds.b 4
priority_parity: .ds.b 1

        .section .text.object_kernel,"ax",@progbits

native_object_priority:
        ld a,PRIORITY
        jp object_parameters

; In: HL descriptor word pointer, DE output. Write the BBR, 0 and the
; CPU window address of the packed descriptor, or 0xFF, 0 and 0 for none.
state_unpack_descriptor:
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        ld h,b
        ld l,c
        ld a,h
        or l
        jp z,unpack_empty
        dec hl
        ld a,h
        .rept 3
        rrca
        .endr
        and 0x1F                        ; 2 KB bank
        sub 0x0C                        ; BBR of the window
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        ld a,h
        and 7
        ld h,a
        add hl,hl
        ld a,h
        or 0xC0                         ; BBR window
        ld h,a
unpack_store:
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        pop hl
        ret
unpack_empty:
        ld a,0xFF
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        jp unpack_store

; Expand the packed mask runs: a count with one word to repeat, or bit 7
; with a count of literal words, until 0.
object_expand_masks:
        ld hl,object_stage + STAGE_PACKED_MASKS
        ld de,object_stage + STAGE_EXPANDED
expand_next:
        ld a,(hl)
        inc hl
        or a
        jp z,expand_done
        bit 7,a
        jp nz,expand_literal
        ld b,a
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld (object_stage + STAGE_MASK_HIGH),a
expand_repeat:
        ld a,c
        ld (de),a
        inc de
        ld a,(object_stage + STAGE_MASK_HIGH)
        ld (de),a
        inc de
        djnz expand_repeat
        jp expand_next
expand_literal:
        and 0x7F
        add a,a
        ld c,a
        ld b,0
        ldir
        jp expand_next
expand_done:
        ld hl,object_stage + STAGE_EXPANDED
        ld (object_stage + RECT_MASKS),hl
        ret

; Stack in: descriptor BBR, descriptor pointer, destination base; for a
; clipped object also the visible column bits and row bits; for a priority
; object also the foreground world row and the left group.
native_object_clipped:
        ld a,CLIPPED
        jp object_parameters
native_object:
        xor a                           ; fully visible
object_parameters:
        ld (object_flags),a
        pop bc
        ld a,c
        ld (object_descriptor_bbr),a
        pop hl
        ld (object_descriptor),hl
        pop hl
        ld (object_base),hl
        ld a,(object_flags)
        and CLIPPED | PRIORITY
        jp z,parameters_done
        pop bc
        ld a,c
        ld (object_columns),a
        pop hl
        ld (object_rows),hl
        ld a,(object_flags)
        bit 1,a                         ; PRIORITY
        jp z,parameters_done
        pop hl
        ld (priority_world),hl
        pop hl
        ld (priority_left),hl
parameters_done:
        ld (object_caller_sp),sp
        jp object_compiled_select

; Stage the next rectangle of the descriptor.
native_object_next:
        ld sp,(object_caller_sp)
        ld a,(object_descriptor_bbr)
        out0 (BBR),a
        ld hl,(object_descriptor)
        ld a,(hl)                       ; body bytes
        or a
        jp z,native_object_done
        cp COMPACT
        jp z,object_compact_header
        ld c,a
        ld b,0
        .irp field,object_width,object_x,object_y
        inc hl
        ld a,(hl)
        ld (\field),a
        .endr
        inc hl
        ld de,object_stage
        ldir
        ld (object_descriptor),hl
object_descriptor_ready:
        ld hl,(object_stage + RECT_MASKS)
        ld a,h
        and l
        inc a
        call z,object_expand_masks      ; 0xFFFF: packed runs follow
        ld hl,(object_stage + RECT_MASKS)
        ld a,h
        cp CANONICAL
        call nc,object_expand_canonical
        ld a,(object_flags)
        and CLIPPED | PRIORITY
        jp z,vertical_ready
        ld hl,(object_rows)
        inc hl
        ld a,h
        or l
        call nz,object_trim_vertical    ; some rows are hidden
        ld a,(object_stage + RECT_HEIGHT)
        or a
        jp z,native_object_next         ; every row is hidden
vertical_ready:
        ld hl,(object_stage + RECT_MASKS)
        ld (rect_mask_stream),hl
        ld a,(object_flags)
        and CLIPPED | PRIORITY
        jp z,masks_ready                ; the immutable masks stay where they are
        ld a,(object_stage + RECT_PLANES)
        or a
        jp nz,masks_materialized        ; the clipper expands the constant
; Copy the masks of a clipped rectangle into the stage.
        ld a,(object_stage + RECT_HEIGHT)
        add a,a
        ld b,a
        ld a,(object_width)
        cp 5
        ld a,b
        jp nz,mask_length               ; two bytes for each row
        add a,a
mask_length:
        ld c,a
        ld b,0
        ld de,object_stage + RECT_MASKS
        ldir
masks_materialized:
        ld hl,0                         ; the masks are in the stage
        ld (rect_mask_stream),hl
masks_ready:
        ld (object_body_end),de
        ld hl,(object_stage + RECT_DESTINATION)
        ld de,(object_base)
        add hl,de
        ld (priority_base),hl
        ld a,h
        and 0xF0
        .rept 4
        rrca
        .endr
        add a,0x92                      ; video RAM CBR
        ld (object_stage + RECT_CBR),a
        ld a,h
        and 0x0F
        or 0xE0                         ; CBR window
        ld h,a
        ld (object_stage + RECT_DESTINATION),hl
        ld a,(object_flags)
        and CLIPPED | PRIORITY
        call nz,object_clip
        ld a,(object_flags)
        bit 1,a                         ; PRIORITY
        call nz,object_priority_masks
        ld a,(object_flags)
        bit 1,a
        jp nz,native_object_next        ; the priority clip has drawn it
object_draw_staged:
        ld hl,(object_body_end)
        ld de,native_object_next
        ld (hl),e
        inc hl
        ld (hl),d
        ld sp,object_stage
        ret                             ; to the latch program
native_object_done:
        ret

; Apply the visible columns and rows to the staged masks.
object_clip:
        ld a,(object_stage + RECT_PLANES)
        or a
        jp nz,clip_required             ; expand the constant masks
        ld a,(object_columns)
        cp 0x1F                         ; all columns
        jp nz,clip_required
        ld hl,(object_rows)
        inc hl
        ld a,h
        or l
        ret z                           ; the full mask is in place
clip_required:
        ld a,(object_stage + RECT_PLANES)
        ld (object_constant),a
        ld a,(object_stage + RECT_HEIGHT)
        ld (object_rows_left),a
        ld hl,(object_rows)
        ld a,(object_y)
        or a
        jp z,row_mask_ready
shift_rows:
        srl h
        rr l
        dec a
        jp nz,shift_rows
row_mask_ready:
        ld (object_row_bits),hl
        ld a,(object_columns)
        ld b,a
        ld a,(object_x)
        or a
        jp z,column_bits_ready
shift_columns:
        srl b
        dec a
        jp nz,shift_columns
column_bits_ready:
        ld a,b
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,column_masks
        add hl,de
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        inc hl
        ld a,(hl)
        ld (object_fifth_mask),a
        ld a,(object_width)
        dec a
        add a,a
        ld e,a
        ld d,0
        ld hl,clip_widths
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        jp (hl)

; One handler for each width: the column map masks in BC, the constant
; fill word, then the masked latch program.
        .irp width,1,2,3,4,5
clip_\width:
        .if \width <= 2
        ld a,c
        .if \width == 1
        and 0x0F
        .endif
        ld b,a
        ld c,0
        .elseif \width == 3
        ld a,b
        and 0x0F
        ld b,a
        .endif
        ld (object_column_mask),bc
        ld a,(object_constant)
        ld l,a
        .rept 4
        rlca
        .endr
        or l
        .if \width == 1
        ld h,l
        ld l,0
        .elseif \width == 2
        ld h,a
        ld l,0
        .elseif \width == 3
        ld h,l
        ld l,a
        .else
        ld h,a
        ld l,a
        .endif
        ld (object_fill),hl
        ld hl,rect_\width\()_0
        ld (object_stage + RECT_KERNEL),hl
        .if \width == 5
        jp clip_rows4
        .else
        jp clip_rows2
        .endif
        .endr

; Clip the mask rows: STRIDE bytes for each row (4 for width 5).
        .macro clip_rows stride
clip_rows\stride:
        ld de,(object_row_bits)
        ld bc,(object_column_mask)
        ld hl,object_stage + RECT_MASKS
clip_rows\stride\()_loop:
        srl d
        rr e
        jp nc,clip_rows\stride\()_zero  ; hidden row
        ld a,(object_constant)
        or a
        jp nz,clip_rows\stride\()_fill
        ld a,(hl)
        and c
        ld (hl),a
        inc hl
        ld a,(hl)
        and b
        ld (hl),a
        inc hl
        .if \stride == 4
        inc hl                          ; the padding stays 0
        ld a,(object_fifth_mask)
        and (hl)
        ld (hl),a
        inc hl
        .endif
        jp clip_rows\stride\()_next
clip_rows\stride\()_fill:
        ld a,(object_fill)
        and c
        ld (hl),a
        inc hl
        ld a,(object_fill + 1)
        and b
        ld (hl),a
        inc hl
        .if \stride == 4
        ld (hl),0
        inc hl
        ld a,(object_fifth_mask)
        push hl
        ld hl,object_constant
        and (hl)
        pop hl
        ld (hl),a
        inc hl
        .endif
        jp clip_rows\stride\()_next
clip_rows\stride\()_zero:
        xor a
        .rept \stride
        ld (hl),a
        inc hl
        .endr
clip_rows\stride\()_next:
        ld a,(object_rows_left)
        dec a
        ld (object_rows_left),a
        jp nz,clip_rows\stride\()_loop
        ld (object_body_end),hl
        ret
        .endm

        clip_rows 2
        clip_rows 4

clip_widths:
        .word clip_1, clip_2, clip_3, clip_4, clip_5

; Map masks of the five groups for each value of the visible column bits:
; groups 1 and 2, groups 3 and 4, 0, group 5.
column_masks:
        .set bits, 0
        .rept 32
        .byte ((bits & 1) * 0x0F) | (((bits >> 1) & 1) * 0xF0)
        .byte (((bits >> 2) & 1) * 0x0F) | (((bits >> 3) & 1) * 0xF0)
        .byte 0, ((bits >> 4) & 1) * 0x0F
        .set bits, bits + 1
        .endr

        .section .text.object_compact_header,"ax",@progbits

; A compact header is a full-width cache rectangle. The compiled header
; before it holds the source mapping, the source address and the first
; destination row, so the clipper uses it, not a second copy for each
; alignment.
object_compact_header:
        .irp field,object_width,object_y,object_stage+RECT_HEIGHT
        inc hl
        ld a,(hl)
        ld (\field),a
        .endr
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (object_stage + RECT_MASKS),de ; canonical silhouette pointer
        ld hl,(object_descriptor)
        ld de,-6 & 0xFFFF               ; compiled source fields
        add hl,de
        .irp field,RECT_SOURCE_BBR,RECT_SEGMENT,RECT_SOURCE,RECT_SOURCE+1,RECT_DESTINATION,RECT_DESTINATION+1
        ld a,(hl)
        ld (object_stage + \field),a
        inc hl
        .endr
        xor a
        ld (object_x),a
        ld (object_stage + RECT_CBR),a
        ld (object_stage + RECT_PLANES),a
        ld (object_stage + RECT_SOURCE_GAP),a
        ld hl,rect_4_0
        ld a,(object_width)
        cp 4
        jp z,compact_kernel
        ld hl,rect_5_0
        ld a,0xFF                       ; the fifth group overlaps the next row
        ld (object_stage + RECT_SOURCE_GAP),a
compact_kernel:
        ld (object_stage + RECT_KERNEL),hl
        ld hl,compact_end
        ld (object_descriptor),hl
        ld de,object_stage + STAGE_PACKED_MASKS ; header end
        jp object_descriptor_ready
compact_end:
        .byte 0                         ; descriptor end

        .section .text.canonical_masks,"ax",@progbits

; Expand one shared 16-bit silhouette to its alignment, for the general
; clipping path only. Whole sprites keep their prepared row code.
; In: HL canonical pointer: bits 0-1 phase, bits 2-13 offset.
object_expand_canonical:
        ld a,l
        and 3
        ld (object_stage + STAGE_PHASE),a
        ld a,l
        and 0xFC
        ld l,a
        ld a,h
        and 0x3F
        ld h,a
        srl h
        rr l
        ld de,canonical_masks
        add hl,de
        ld (object_stage + STAGE_CANONICAL_SOURCE),hl
        ld de,object_stage + STAGE_EXPANDED
        ld a,(object_stage + RECT_HEIGHT)
        ld (object_stage + STAGE_ROWS_LEFT),a
canonical_row:
        ld hl,(object_stage + STAGE_CANONICAL_SOURCE)
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld (object_stage + STAGE_CANONICAL_SOURCE),hl
        ld h,b
        ld l,c
        ld b,0                          ; bits shifted out
        ld a,(object_stage + STAGE_PHASE)
        or a
        jp z,canonical_store
canonical_shift:
        add hl,hl
        rl b
        dec a
        jp nz,canonical_shift
canonical_store:
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld a,(object_stage + STAGE_PHASE)
        or a
        jp z,canonical_next             ; no fifth group
        xor a
        ld (de),a
        inc de
        ld a,b
        ld (de),a
        inc de
canonical_next:
        ld hl,object_stage + STAGE_ROWS_LEFT
        dec (hl)
        jp nz,canonical_row
        ld hl,native_object_next        ; next rectangle
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld hl,object_stage + STAGE_EXPANDED
        ld (object_stage + RECT_MASKS),hl
        ret

        .section .text.object_trim_vertical,"ax",@progbits

; Remove the hidden rows at the top and the bottom of the staged rectangle
; before its masks are copied or drawn.
object_trim_vertical:
        push de
        ld de,(object_rows)
        ld a,(object_y)
        or a
        jr z,trim_ready
trim_shift:
        srl d
        rr e
        dec a
        jr nz,trim_shift
trim_ready:
        ld a,(object_stage + RECT_HEIGHT)
        ld c,a
        ld b,0                          ; hidden rows at the top
trim_leading:
        bit 0,e
        jr nz,trim_visible
        srl d
        rr e
        inc b
        dec c
        jr nz,trim_leading
        xor a
        ld (object_stage + RECT_HEIGHT),a
        pop de
        ret
trim_visible:
        ld a,b
        ld (trim_leading_rows),a
        xor a
trim_count:
        inc a
        dec c
        jr z,trim_counted
        srl d
        rr e
        bit 0,e
        jr nz,trim_count
trim_counted:
        ld (object_stage + RECT_HEIGHT),a
        ld a,b
        or a
        jr z,trim_done
        ld a,(object_y)
        add a,b
        ld (object_y),a
        ld a,(object_width)
        ld e,a
        ld a,(object_stage + RECT_SOURCE_GAP)
        add a,e
        ld e,a
        ld d,0
        ld hl,0
trim_source:
        add hl,de
        djnz trim_source
        ld de,(object_stage + RECT_SOURCE)
        add hl,de
        ld (object_stage + RECT_SOURCE),hl
        ld a,(trim_leading_rows)
        ld l,a
        ld h,0
        call state_times56
        ld de,(object_stage + RECT_DESTINATION)
        add hl,de
        ld (object_stage + RECT_DESTINATION),hl
        ld a,(trim_leading_rows)
        add a,a
        ld e,a
        ld a,(object_width)
        cp 5
        jr nz,trim_mask                 ; two bytes for each mask row
        sla e
trim_mask:
        ld d,0
        ld hl,(object_stage + RECT_MASKS)
        add hl,de
        ld (object_stage + RECT_MASKS),hl
trim_done:
        pop de
        ret

        .section .text.object_compiled,"ax",@progbits

; A wholly visible sprite runs a prepared phase kernel; others take the
; general rectangle path.
object_compiled_select:
        ld a,(object_descriptor_bbr)
        out0 (BBR),a
        ld hl,(object_descriptor)
        ld a,(object_flags)
        or a
        jr nz,compiled_fallback
        jr compiled_canonical
compiled_setup:
        ld sp,hl
        pop hl                          ; prepared phase kernel
        ld (compiled_jump+1),hl
        pop bc                          ; source BBR and segment
        ld (compiled_mapping),bc
        pop hl
        ld (compiled_source),hl
        pop de                          ; relative first destination
        ld hl,(object_base)
        add hl,de
        ld a,h
        .rept 4
        rrca
        .endr
        and 0x0F
        add a,0x92                      ; video RAM CBR
        out0 (CBR),a
        ld a,h
        and 0x0F
        or 0xE0                         ; CBR window
        ld d,a
        ld e,l
        ld bc,(compiled_mapping)
        ld a,c
        out0 (BBR),a
        ld h,b
        ld bc,OAK_INDEX
        ld a,OAK_READ_SEGMENT
        out (c),a
        inc c
        out (c),h
        ld hl,(compiled_source)
        ld sp,(object_caller_sp)
compiled_jump:
        jp 0                            ; patched: the phase kernel
        ret                             ; unused
object_compiled_done:
        ld sp,(object_caller_sp)
        ret
compiled_fallback:
        ld de,8                         ; compiled header
        add hl,de
        ld (object_descriptor),hl
        jp native_object_next

; A large art window must not make ordinary sprites expand masks while the
; game runs. Read the shared silhouette directly, one word for each row.
; Four prepared kernels shift it by a constant phase in registers. Cache
; descriptors are always compact: the phase kernel is in their compiled
; entry word; only the height and the mask SP are used here.
compiled_canonical:
        push hl
        ld de,11                        ; height field
        add hl,de
        ld a,(hl)
        exx
        ld d,a
        exx
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,l
        and 0xFC
        ld l,a
        ld a,h
        and 0x3F
        ld h,a
        srl h
        rr l
        ld de,canonical_masks
        add hl,de
        ld (object_stage + STAGE_CANONICAL_SP),hl
        pop hl
        jp compiled_setup

object_canonical_kernels:
        .word object_canonical_0, object_canonical_1, object_canonical_2, object_canonical_3

; A 0 map mask keeps the destination while the latch copy goes on. The
; sequencer ignores the high nibble. Alternate D counts the rows.
        .irp phase,0,1,2,3
object_canonical_\phase:
        ld sp,(object_stage + STAGE_CANONICAL_SP)
object_canonical_\phase\()_row:
        exx
        pop hl                          ; the 16-pixel silhouette
        .if \phase
        xor a
        .rept \phase
        add hl,hl
        rla
        .endr
        ld e,a                          ; fifth group
        .endif
        out (c),l
        exx
        ldi
        exx
        ld a,l
        .rept 4
        rrca
        .endr
        out (c),a
        exx
        ldi
        exx
        out (c),h
        exx
        ldi
        exx
        ld a,h
        .rept 4
        rrca
        .endr
        out (c),a
        exx
        ldi
        exx
        .if \phase
        out (c),e
        exx
        ldi
        exx
        .endif
        dec d
        exx
        jp z,object_compiled_done
        .if \phase
        dec hl                          ; the edge group starts the next row
        ex de,hl
        ld bc,GROUPS_PER_ROW - 5
        .else
        ex de,hl
        ld bc,GROUPS_PER_ROW - 4
        .endif
        add hl,bc
        ex de,hl
        jr object_canonical_\phase\()_row
        .endr

        .section .text.object_priority,"ax",@progbits

; Clip a live low-priority sprite against the canonical cloud silhouette:
; a covered pixel is never written. The sprite keeps its own pixels, so no
; cloud art is copied after the draw.
object_priority_masks:
        xor a
        ld (priority_mapped),a          ; map the coverage on the first row
        ld hl,(priority_world)
        ld a,(object_y)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld (priority_world_row),hl
        ld hl,(priority_left)
        ld a,(object_x)
        ld e,a
        ld d,0
        add hl,de
        ld (priority_group),hl
        ld (priority_unused),hl
        ld hl,(object_rows)
        ld a,(object_y)
        or a
        jr z,rows_ready
shift_visibility:
        srl h
        rr l
        dec a
        jr nz,shift_visibility
rows_ready:
        ld (priority_rows),hl
        ld a,(object_stage + RECT_HEIGHT)
        ld (priority_count),a
        ld a,(object_width)
        ld (priority_width),a
        cp 5
        ld a,2                          ; mask bytes for each row
        jr nz,stride_ready
        ld a,4
stride_ready:
        ld (priority_stride),a
        ld hl,object_stage + RECT_MASKS
        ld a,(priority_width)
        cp 3
        jr nc,mask_start
        inc hl                          ; a narrow rectangle has one mask byte
mask_start:
        ld (priority_mask),hl
; Select one aligned coverage row. Its bytes match each staged pair of
; group masks, so no shift loop runs for each group.
        ld a,(priority_group)
        ld b,a
        ld a,(bg_first_column)
        add a,b
        and 0x3F
        ld b,a
        and 1
        ld (priority_parity),a
        ld a,b
        srl a
        ld (priority_group),a
        ld a,(priority_parity)
        add a,a
        add a,a
        ld b,a
        ld a,(bg_pan_phase)
        add a,b
        call sprite_mask_select
priority_row:
        ld hl,(priority_rows)
        srl h
        rr l
        ld (priority_rows),hl
        jp nc,row_done                  ; a hidden row
        ld a,(priority_mapped)
        or a
        jr nz,coverage_cached
; Map the coverage row: 32 groups for each world row, 64 rows in a block,
; each block in its own plane.
        ld a,(priority_world_row)
        and 0x3F
        ld l,a
        ld h,0
        .rept 5
        add hl,hl
        .endr
        ld de,game_coverage__group16
        add hl,de
        ld a,h
        .rept 4
        rrca
        .endr
        and 0x0F
        add a,0x94                      ; video RAM BBR
        out0 (BBR),a
        ld a,h
        and 0x0F
        or 0xC0                         ; BBR window
        ld h,a
        oak_set OAK_READ_SEGMENT, game_coverage__vseg
        ld a,(priority_world_row)
        rlca
        rlca
        and 3
        ld d,a
        ld bc,VGA_GC_INDEX
        ld a,GC_READ_MAP
        out (c),a
        inc c
        out (c),d
        ld a,(priority_group)
        ld e,a
        ld d,0
        add hl,de
        ld (priority_coverage),hl
        ld a,1
        ld (priority_mapped),a
coverage_cached:
        ld hl,(priority_coverage)
        ld de,(priority_mask)
        call game_mask_pair
        cpl                             ; the pixels with no cover
        ld b,a
        ld a,(de)
        and b
        ld (de),a
        ld a,(priority_width)
        cp 3
        jr c,draw_ready                 ; one pair only
        inc de
        call game_mask_pair
        cpl
        ld b,a
        ld a,(de)
        and b
        ld (de),a
        ld a,(priority_width)
        cp 5
        jr c,draw_ready                 ; two pairs only
        inc de
        inc de                          ; the fifth mask after the padding
        call game_mask_pair
        cpl
        ld b,a
        ld a,(de)
        and b
        ld (de),a
draw_ready:
row_done:
        ld hl,(priority_coverage)
        ld de,32                        ; coverage groups for each row
        or a
        sbc hl,de
        ld (priority_coverage),hl
        ld a,(priority_world_row)
        sub 0
        and 0x3F
        jr nz,coverage_valid            ; the same coverage block
        ld (priority_mapped),a
coverage_valid:
        ld hl,(priority_mask)
        ld a,(priority_stride)
        ld e,a
        ld d,0
        add hl,de
        ld (priority_mask),hl
        ld hl,(priority_world_row)
        dec hl
        ld (priority_world_row),hl
        ld a,(priority_count)
        dec a
        ld (priority_count),a
        jp nz,priority_row
; Go on in the normal masked draw, after the old restore branch. The
; priority flags stay for every rectangle of the object.
        pop hl                          ; the return of the priority call
        jp object_draw_staged
