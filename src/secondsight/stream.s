; Packet stream from the IIgs: DMA channel 1 receives each update packet from
; the card port into one of two receive buffers (stream.inc) while the card
; draws from the other.

        .include "second_sight.inc"
        .include "z180.inc"
        .include "stream.inc"

        .global stream_arm, stream_take, stream_header_ready, stream_header
        .global stream_wait, stream_arm_next, stream_arm_other
        .global stream_receive, stream_active_packet

        .equ MAX_PAYLOAD, STREAM_BUFFER_SIZE - 2 ; the bytes after the length word
        .global READY_TOKEN             ; the host uses it as PACKET_TOKEN
        .equ READY_TOKEN, 0x40          ; $40 for packet buffer 0, $41 for packet buffer 1

        .section .vars.stream,"aw",@nobits
stream_receive: .ds.b 2                 ; the buffer that channel 1 fills
stream_remaining_limit: .ds.b 2         ; the channel 1 count at the end of the packet
stream_active_packet: .ds.b 2           ; the packet that the card draws, after its length word

        .section .text.stream,"ax",@progbits

; stream_arm: start receiving into the buffer A (the high byte of
; packet_buffer_0__run or packet_buffer_1__run) and tell the IIgs the token
; of that buffer.
; Logical memory below $C000 is common area 0, so both buffers stay mapped.
; AF, HL changed.
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
        ld a,STREAM_BUFFER_SIZE & 0xFF
        out0 (BCR1L),a
        ld a,STREAM_BUFFER_SIZE >> 8
        out0 (BCR1H),a
        ld a,DSTAT_DE1 | DSTAT_KEEP0 | DSTAT_DME
        out0 (DSTAT),a
        ld a,h
        rlca
        rlca                            ; buffer 0: 1, buffer 1: 2
        add a,READY_TOKEN - 1
        out0 (CARD_HOST),a
        ret

; stream_take: wait for a complete packet in the receive buffer.
; stream_header_ready, stream_header, stream_wait: the steps of the wait.
; Out: stream_active_packet points at its payload. AF, BC, DE, HL changed.
stream_take:
        ld hl,(stream_receive)
stream_header_ready:
        in0 a,(BCR1H)                   ; wait for the first length byte
        cp STREAM_BUFFER_SIZE >> 8
        jp nc,stream_header_ready
        in0 a,(BCR1L)                   ; and the second (the count leaves xxFF)
        cp 0xFF
        jp z,stream_header_ready
stream_header:
        ld e,(hl)
        inc hl
        ld d,(hl)
        dec hl
        ld a,d
        or e
        jp z,stream_header              ; the length is not in memory yet
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

; stream_arm_next: receive the next packet into the other buffer.
; stream_arm_other: the same for the buffer A xor stream_other.
; A special packet writes a jump over the load of stream_arm_next
; (special_wave.s); state_plan.s jumps to stream_arm_other after it.
stream_arm_next:
        ld a,(stream_receive+1)
stream_arm_other:
        xor stream_other
        jp stream_arm
