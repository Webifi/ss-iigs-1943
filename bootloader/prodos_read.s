; File reader for a program that boot0.s started: open a file of the volume
; directory and read it as a byte stream through the block driver of the
; boot slot. Seedling, sapling and tree files; no sparse files, no writes.
;
; .include it in 6502 or 8-bit 65816 code. Call it in emulation mode with
; D = 0. The program defines:
;   PR_ZP     4 zero-page bytes
;   PR_DBUF   a 512-byte buffer (a data or directory block)
;   PR_IBUF   a 512-byte buffer (an index block)
; The block driver uses $42-$47 and may change other zero page; the reader
; keeps nothing in zero page across a driver call.
;
; pr_init   in: A = the boot unit (X at the start of the program). Sets
;           pr_unit and pr_driver, the block driver of the slot.
; pr_open   in: A/Y = the name, a length byte and the name (upper case).
;           Carry set: not in the volume directory or a disk error. Sets
;           pr_storage, pr_key and pr_eof; the mark is 0.
; pr_read   in: pr_dest = the address, pr_count = the bytes. Reads from the
;           mark and moves it. Out: pr_count = the bytes read, fewer at the
;           end of the file. Carry set: a disk error.
; pr_call   the block driver: $42 command, $43 unit, $44 buffer, $46 block.

PR_CMD  = $42
PR_UNIT = $43
PR_BUF  = $44
PR_BLK  = $46
PR_SRC  = PR_ZP
PR_DST  = PR_ZP + 2

pr_init:
        sta     pr_unit
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        and     #7
        ora     #$C0
        sta     pr_driver+1
        sta     PR_SRC+1
        lda     #$FF
        sta     PR_SRC
        ldy     #0
        lda     (PR_SRC),y
        sta     pr_driver
        rts

pr_open:
        sta     pr_name
        sty     pr_name+1
        lda     #$FF
        sta     pr_held+1       ; no data block in PR_DBUF
        sta     pr_ihold        ; no index block in PR_IBUF
        lda     #0
        sta     pr_mark
        sta     pr_mark+1
        sta     pr_mark+2
        lda     #2              ; the volume directory starts at block 2
        ldx     #0
@block: ldy     #<PR_DBUF
        sty     PR_BUF
        ldy     #>PR_DBUF
        sty     PR_BUF+1
        jsr     pr_disk
        bcs     @done
        lda     pr_name
        sta     PR_SRC
        lda     pr_name+1
        sta     PR_SRC+1
        lda     #<(PR_DBUF + 4)
        sta     PR_DST
        lda     #>(PR_DBUF + 4)
        sta     PR_DST+1
        ldx     #13             ; entries in a block
@entry: ldy     #0
        lda     (PR_DST),y
        and     #$0F
        cmp     (PR_SRC),y
        bne     @skip
        tay
@same:  lda     (PR_DST),y
        cmp     (PR_SRC),y
        bne     @skip
        dey
        bne     @same
        lda     (PR_DST),y
        cmp     #$40
        bcs     @skip
        cmp     #$10
        bcs     @found          ; a seedling, sapling or tree ($1n-$3n)
@skip:  lda     PR_DST
        clc
        adc     #39
        sta     PR_DST
        bcc     :+
        inc     PR_DST+1
:       dex
        bne     @entry
        lda     PR_DBUF+2       ; the next directory block
        ldx     PR_DBUF+3
        bne     @block
        tay
        bne     @block
        sec
@done:  rts
@found: lsr     a
        lsr     a
        lsr     a
        lsr     a
        sta     pr_storage
        ldy     #17
        lda     (PR_DST),y
        sta     pr_key
        iny
        lda     (PR_DST),y
        sta     pr_key+1
        ldy     #21
        lda     (PR_DST),y
        sta     pr_eof
        iny
        lda     (PR_DST),y
        sta     pr_eof+1
        iny
        lda     (PR_DST),y
        sta     pr_eof+2
        clc
        rts

pr_read:
        sec                     ; limit the count to the end of the file
        lda     pr_eof
        sbc     pr_mark
        sta     pr_left
        lda     pr_eof+1
        sbc     pr_mark+1
        sta     pr_left+1
        lda     pr_eof+2
        sbc     pr_mark+2
        bne     @counted
        lda     pr_count+1
        cmp     pr_left+1
        bcc     @counted
        bne     @clip
        lda     pr_count
        cmp     pr_left
        bcc     @counted
@clip:  lda     pr_left
        sta     pr_count
        lda     pr_left+1
        sta     pr_count+1
@counted:
        lda     pr_count
        sta     pr_left
        lda     pr_count+1
        sta     pr_left+1
@loop:  lda     pr_left
        ora     pr_left+1
        bne     :+
        clc
        rts
:       lda     pr_mark+2       ; the block of the mark in the file
        lsr     a
        sta     pr_n+1
        lda     pr_mark+1
        ror     a
        sta     pr_n
        lda     pr_mark+1
        and     #1
        ora     pr_mark
        bne     @part
        lda     pr_left+1
        cmp     #2
        bcc     @part
        jsr     pr_block        ; a whole block: read it to the address
        bcc     :+
        rts
:
        ldy     pr_dest
        sty     PR_BUF
        ldy     pr_dest+1
        sty     PR_BUF+1
        jsr     pr_disk
        bcc     :+
        rts
:
        lda     #0
        sta     pr_k
        lda     #2
        sta     pr_k+1
        jmp     @moved
@part:  lda     pr_n
        cmp     pr_held
        bne     @load
        lda     pr_n+1
        cmp     pr_held+1
        beq     @have
@load:  jsr     pr_block
        bcc     :+
        rts
:
        ldy     #<PR_DBUF
        sty     PR_BUF
        ldy     #>PR_DBUF
        sty     PR_BUF+1
        jsr     pr_disk
        bcc     :+
        rts
:
        lda     pr_n
        sta     pr_held
        lda     pr_n+1
        sta     pr_held+1
@have:  lda     pr_mark+1       ; the offset in the block
        and     #1
        tax
        sec                     ; k = the rest of the block, at most the count
        lda     #0
        sbc     pr_mark
        sta     pr_k
        lda     #2
        stx     pr_k+1
        sbc     pr_k+1
        sta     pr_k+1
        lda     pr_left+1
        cmp     pr_k+1
        bcc     @short
        bne     @copy
        lda     pr_left
        cmp     pr_k
        bcs     @copy
@short: lda     pr_left
        sta     pr_k
        lda     pr_left+1
        sta     pr_k+1
@copy:  clc
        lda     #<PR_DBUF
        adc     pr_mark
        sta     PR_SRC
        txa
        adc     #>PR_DBUF
        sta     PR_SRC+1
        lda     pr_dest
        sta     PR_DST
        lda     pr_dest+1
        sta     PR_DST+1
        ldy     #0
        ldx     pr_k+1
        beq     @tail
@page:  lda     (PR_SRC),y
        sta     (PR_DST),y
        iny
        bne     @page
        inc     PR_SRC+1
        inc     PR_DST+1
        dex
        bne     @page
@tail:  ldx     pr_k
        beq     @moved
@byte:  lda     (PR_SRC),y
        sta     (PR_DST),y
        iny
        dex
        bne     @byte
@moved: clc                     ; the address, the mark and the count move by k
        lda     pr_dest
        adc     pr_k
        sta     pr_dest
        lda     pr_dest+1
        adc     pr_k+1
        sta     pr_dest+1
        clc
        lda     pr_mark
        adc     pr_k
        sta     pr_mark
        lda     pr_mark+1
        adc     pr_k+1
        sta     pr_mark+1
        bcc     :+
        inc     pr_mark+2
:       sec
        lda     pr_left
        sbc     pr_k
        sta     pr_left
        lda     pr_left+1
        sbc     pr_k+1
        sta     pr_left+1
        jmp     @loop

; X:A = the disk block of block pr_n of the open file. Carry set: a disk
; error while an index block loads.
pr_block:
        lda     pr_storage
        cmp     #2
        bcs     @index
        lda     pr_key          ; a seedling: block 0 only
        ldx     pr_key+1
        clc
        rts
@index: lda     pr_n+1
        cmp     pr_ihold
        beq     @have
        lda     pr_key
        ldx     pr_key+1
        jsr     pr_index
        bcs     @ret
        lda     pr_storage
        cmp     #3
        bne     @held
        ldy     pr_n+1          ; a tree: the key block is the master index
        lda     PR_IBUF,y
        ldx     PR_IBUF+256,y
        jsr     pr_index
        bcs     @ret
@held:  lda     pr_n+1
        sta     pr_ihold
@have:  ldy     pr_n
        lda     PR_IBUF,y
        ldx     PR_IBUF+256,y
        clc
@ret:   rts

; Read block X:A to PR_IBUF.
pr_index:
        ldy     #<PR_IBUF
        sty     PR_BUF
        ldy     #>PR_IBUF
        sty     PR_BUF+1

; Read block X:A to PR_BUF.
pr_disk:
        sta     PR_BLK
        stx     PR_BLK+1
        lda     #1
        sta     PR_CMD
        lda     pr_unit
        sta     PR_UNIT
pr_call:
        jmp     (pr_driver)

pr_driver:  .word 0
pr_unit:    .byte 0
pr_storage: .byte 0
pr_key:     .word 0
pr_eof:     .res 3
pr_mark:    .res 3
pr_dest:    .word 0
pr_count:   .word 0
pr_name:    .word 0
pr_held:    .word 0
pr_ihold:   .byte 0
pr_left:    .word 0
pr_n:       .word 0
pr_k:       .word 0
        .assert <pr_driver <> $FF, lderror, "6502 JMP (abs) cannot read a vector at $xxFF"
