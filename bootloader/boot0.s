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
TEXT    = $0400                 ; the text page
SLOT_ROM = $C0                  ; + the slot: the page of the slot ROM
DRIVER_OFFSET = $FF             ; $CnFF: the offset of the block driver
READ_BLOCK = 1                  ; the block driver command
DIR_BLOCK = 2                   ; the volume directory starts at this block
DIR_NEXT = 2                    ; a directory block: the next block (2 bytes),
DIR_ENTRY = 4                   ;   the first entry,
DIR_ENTRIES = 13                ;   the entries,
ENTRY_SIZE = 39                 ;   of this size
NAME_BITS = $0F                 ; an entry: byte 0: the storage type and the name length
SEEDLING = $10                  ; storage types (byte 0, high nibble)
SAPLING = $20
TREE = $30
KEY_POINTER = 17                ; an entry: the key block (2 bytes)

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
        ora     #SLOT_ROM
        sta     driver+1
        sta     PTR+1
        lda     #DRIVER_OFFSET
        sta     PTR
        ldy     #0
        lda     (PTR),y
        sta     driver
        lda     #DIR_BLOCK
        ldx     #0
dirblk: ldy     #>DIR
        jsr     read
        lda     #<(DIR + DIR_ENTRY)
        sta     PTR
        lda     #>(DIR + DIR_ENTRY)
        sta     PTR+1
        ldx     #DIR_ENTRIES
entry:  ldy     #0
        lda     (PTR),y
        and     #NAME_BITS
        cmp     name
        bne     skip
        tay
same:   lda     (PTR),y
        cmp     name,y
        bne     skip
        dey
        bne     same
        lda     (PTR),y
        cmp     #TREE
        bcs     skip
        cmp     #SEEDLING
        bcs     found           ; a seedling or a sapling
skip:   lda     PTR
        clc
        adc     #ENTRY_SIZE
        sta     PTR
        bcc     :+
        inc     PTR+1
:       dex
        bne     entry
        lda     DIR+DIR_NEXT    ; the next directory block
        ldx     DIR+DIR_NEXT+1
        bne     dirblk
        tay
        bne     dirblk
        beq     fail

found:  cmp     #SAPLING
        ldy     #KEY_POINTER+1
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
        lda     #READ_BLOCK
        sta     CMD
        jsr     call
        bcs     fail
        rts
call:   jmp     (driver)

fail:   ldy     #message_end-message-1
:       lda     message,y
        ora     #$80            ; normal text
        sta     TEXT,y
        dey
        bpl     :-
hang:   jmp     hang

message: .byte  "BOOT ERROR"
message_end:
index:  .byte   0
page:   .byte   0
driver: .word   0
        .assert <driver <> $FF, lderror, "6502 JMP (abs) cannot read a vector at $xxFF"
        .assert * <= $0A00, lderror, "boot0 is larger than one block"
