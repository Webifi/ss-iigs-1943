; Boot block of a ProDOS volume (block 0): loads one file of the volume
; directory to $2000 and runs it. No ProDOS.
;
; The firmware of a block device (SmartPort, an Apple SCSI card, a CFFA,
; the IIgs 3.5-inch drive) loads block 0 to $0800 and jumps to $0801 in
; emulation mode with X = slot * 16. This block reads through the block
; driver of that slot ($Cn00 + the byte at $CnFF).
;
; The file is a seedling or a sapling in the volume directory, at most
; $9E00 bytes. The name goes in bytes 4-19 (prodos_volume.py). The file
; starts at $2000 in emulation mode with X = the ProDOS unit number of the
; boot drive. The block uses $0A00-$0DFF and $42-$49.
;
; 6502 code: on any Apple II the file starts and can show its own message.

        .setcpu "6502"

CMD     = $42                   ; the block driver: command,
UNIT    = $43                   ;   unit,
BUF     = $44                   ;   buffer,
BLK     = $46                   ;   block
PTR     = $48                   ; the directory entry
DIR     = $0A00                 ; a directory block
INDEX   = $0C00                 ; the index block of the file
LOAD    = $2000

        .segment "CODE"
        .byte   $01
        jmp     boot
name:   .res    16

boot:   stx     UNIT
        txa
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        ora     #$C0
        sta     driver+1
        sta     PTR+1
        lda     #$FF
        sta     PTR
        ldy     #0
        lda     (PTR),y
        sta     driver
        lda     #2              ; the volume directory starts at block 2
        ldx     #0
dirblk: ldy     #>DIR
        jsr     read
        lda     #<(DIR + 4)
        sta     PTR
        lda     #>(DIR + 4)
        sta     PTR+1
        ldx     #13             ; entries in a block
entry:  ldy     #0
        lda     (PTR),y
        and     #$0F
        cmp     name
        bne     skip
        tay
same:   lda     (PTR),y
        cmp     name,y
        bne     skip
        dey
        bne     same
        lda     (PTR),y
        cmp     #$30
        bcs     skip
        cmp     #$10
        bcs     found           ; a seedling ($1n) or a sapling ($2n)
skip:   lda     PTR
        clc
        adc     #39
        sta     PTR
        bcc     :+
        inc     PTR+1
:       dex
        bne     entry
        lda     DIR+2           ; the next directory block
        ldx     DIR+3
        bne     dirblk
        tay
        bne     dirblk
        beq     fail

found:  cmp     #$20
        ldy     #18
        lda     (PTR),y
        tax
        dey
        lda     (PTR),y         ; the key block
        ldy     #>LOAD
        bcc     last            ; a seedling: the key block holds the data
        ldy     #>INDEX
        jsr     read
        lda     #>LOAD
        sta     page
next:   ldy     index
        lda     INDEX+256,y
        tax
        lda     INDEX,y
        bne     :+
        cpx     #0
        beq     run             ; the index ends at the first zero pointer
:       inc     index
        ldy     page
        inc     page
        inc     page
        jsr     read
        jmp     next
last:   jsr     read
run:    ldx     UNIT
        jmp     LOAD

; Read block X:A to page Y.
read:   sta     BLK
        stx     BLK+1
        sty     BUF+1
        lda     #0
        sta     BUF
        lda     #1
        sta     CMD
        jsr     call
        bcs     fail
        rts
call:   jmp     (driver)

fail:   ldy     #9
:       lda     message,y
        ora     #$80
        sta     $0400,y
        dey
        bpl     :-
hang:   jmp     hang

message: .byte  "BOOT ERROR"
index:  .byte   0
page:   .byte   0
driver: .word   0
        .assert <driver <> $FF, lderror, "6502 JMP (abs) cannot read a vector at $xxFF"
        .assert * <= $0A00, lderror, "boot0 is larger than one block"
