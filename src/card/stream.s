; Packet stream from the IIgs: DMA channel 1 receives each update packet from
; the card port into one of two 16 KB buffers while the card draws.

        .include "second_sight.inc"
        .include "z180.inc"

        .global stream_arm, stream_take, stream_header_ready, stream_header
        .global stream_wait, stream_arm_next

        .equ BUFFER_BYTES_HIGH, 0x40    ; 16 KB
        .equ MAX_PAYLOAD, 0x3FFE
        .equ READY_TOKEN, 0x40          ; $40 for the buffer at $4000, $41 for $8000
        .equ OTHER_BUFFER, 0xC0         ; $40 xor $C0 = $80

        .section .text.stream,"ax",@progbits

; Start receiving into the buffer at A*256 and tell the IIgs it is ready.
; Logical memory below $C000 is common area 0, so both buffers stay mapped.
stream_arm:
        ld h,a
        ld l,0
        ld (stream_receive),hl
        ld (hl),0                       ; clear the unpublished length
        inc hl
        ld (hl),0
        ld a,h
        out0 (MAR1H),a
        ld a,0
        out0 (MAR1L),a
        ld a,0
        out0 (MAR1B),a
        ld a,0
        out0 (BCR1L),a
        ld a,BUFFER_BYTES_HIGH
        out0 (BCR1H),a
        ld a,DSTAT_DE1 | DSTAT_KEEP0 | DSTAT_DME
        out0 (DSTAT),a
        ld a,h
        rlca
        rlca
        add a,READY_TOKEN - 1
        out0 (CARD_HOST),a
        ret

; Wait for a complete packet. Out: stream_active_packet points at its payload.
stream_take:
        ld hl,(stream_receive)
stream_header_ready:
        in0 a,(BCR1H)                   ; wait for the first length byte
        cp BUFFER_BYTES_HIGH
        jp nc,stream_header_ready
        in0 a,(BCR1L)                   ; and the second
        cp 0xFF
        jp z,stream_header_ready
stream_header:
        ld e,(hl)
        inc hl
        ld d,(hl)
        dec hl
        ld a,d
        or e
        jp z,stream_header
        inc hl
        inc hl
        ld (stream_active_packet),hl
        ld hl,MAX_PAYLOAD
        or a
        sbc hl,de
        ld (stream_remaining_limit),hl
stream_wait:
        ; Read the high byte twice so a low-byte rollover cannot report an
        ; incomplete packet as complete. The counter only decreases.
        in0 a,(BCR1H)
        ld b,a
        in0 a,(BCR1L)
        ld e,a
        in0 a,(BCR1H)
        cp b
        jp nz,stream_wait
        ld d,a
        ld hl,(stream_remaining_limit)
        or a
        sbc hl,de
        jp c,stream_wait
        ld a,DSTAT_KEEP0 | DSTAT_DME    ; stop channel 1; drawing owns channel 0
        out0 (DSTAT),a
        ret

stream_arm_next:
        ld a,(stream_receive+1)
        xor OTHER_BUFFER
        jp stream_arm
