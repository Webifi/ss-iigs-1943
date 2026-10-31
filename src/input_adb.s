; ADB framing and timestamp publication ported from Wolf3D keys.s.
.a16
.i16
CaptureInput: sep #$20
captureByte:
J13AdbSite:   lda f:KMSTATUS
captureStatusMask: and #$20
              beq captureMouse
              lda f:DATAREG
              ldx a:.loword(keyReply)
              beq captureHeader
              cmp #255
              beq capturedKey
              sta a:.loword(irqValue)
              lda #0
              sta a:.loword(irqValue+1)
              rep #$20
              stz a:.loword(irqType)
              stz a:.loword(irqAux)
              jsr a:.loword(queueInput)
              sep #$20
capturedKey:  dec a:.loword(keyReply)
              bne captureByte
              stz a:.loword(keyTalk)
              bra captureByte
captureHeader:
              sta a:.loword(keyHeaderByte)
              bit #8
              beq noKeyRequest
              ldx #1
              stx a:.loword(keyPending)
;;; A status byte ends this pass; the Talk below answers its request. KEGS keeps
;;; the request byte valid until that Talk, so reading on would never stop (#1).
noKeyRequest: lda a:.loword(keyHeaderByte)
              bpl captureMouse
              and #7
              beq emptyKeyReply
              inc a
              sta a:.loword(keyReply)
              bra captureByte
emptyKeyReply:
              stz a:.loword(keyTalk)
              bra captureByte
captureMouse: lda f:KMSTATUS
              bpl captureTalk
              bit #2
              beq mouseXY
              lda f:MOUSEDATA           ; discard an orphan Y, not a pair
              bra captureTalk
mouseXY:      lda f:MOUSEDATA
              sta a:.loword(irqValue)
              lda f:MOUSEDATA
              sta a:.loword(irqAux)
              rep #$20
              lda #1
              sta a:.loword(irqType)
              jsr a:.loword(queueInput)
              sep #$20
              inc a:.loword(mouseTalkCount)
              ldx a:.loword(mouseTalkCount)
              cpx #4
              bcc captureTalk
              ldx #1                    ; keys may request service mid-motion
              stx a:.loword(keyPending)
captureTalk:  ldx a:.loword(keyPending)
              beq inputCaptured
              ldx a:.loword(keyTalk)
              bne inputCaptured
              lda f:KMSTATUS
              lsr a
              bcs inputCaptured
              lda #$c2
              sta f:DATAREG
              ldx #1
              stx a:.loword(keyTalk)
              stz a:.loword(keyPending)
              stz a:.loword(mouseTalkCount)
withoutRawKeys:
              stz a:.loword(keyPending)
inputCaptured:
              rep #$20
              rtl

queueInput:   jsl I_GetTime
              ldx a:.loword(inputHead)
              sta a:.loword(inputRing),x
              lda a:.loword(irqType)
              sta a:.loword(inputRing+2),x
              lda a:.loword(irqValue)
              sta a:.loword(inputRing+4),x
              lda a:.loword(irqAux)
              sta a:.loword(inputRing+6),x
              txa
              clc
              adc #8
              and #1023
              cmp a:.loword(inputTail)
              beq inputOverflow
              sta a:.loword(inputHead)   ; publish only the complete event
              rts
inputOverflow:
              inc a:.loword(inputDropped)
              rts

