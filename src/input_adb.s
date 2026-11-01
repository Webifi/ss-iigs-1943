; The ADB input capture (from the Wolf3D port, keys.s): the key bytes and
; the mouse moves become timestamped events in inputRing (queueInput).
.a16
.i16
KEY_TALK = GLU_TALK+ADB_KEYBOARD  ; ask the keyboard for its keys
MOUSE_TALKS = 4              ; after this many mouse moves the keys get a turn
INPUT_EVENT_SIZE = 8         ; inputRing: time, type, value, aux
INPUT_RING_SIZE = 1024       ; a power of two
INPUT_TIME = 0               ; an event: GAME_CLOCK when it came
INPUT_TYPE = 2               ; INPUT_KEY, INPUT_MOUSE or INPUT_J13
INPUT_VALUE = 4              ; the key byte (bit 7: a release), or the mouse X byte
INPUT_AUX = 6                ; the mouse Y byte (bit 7: the button is up)
INPUT_KEY = 0                ; INPUT_TYPE: an ADB keyboard key byte
INPUT_MOUSE = 1              ; INPUT_TYPE: a mouse move
INPUT_J13 = 2                ; INPUT_TYPE: a J13 keyboard key byte
HELD_ADB = 1                 ; keyHeld: the ADB keyboard holds the key
HELD_J13 = 2                 ; keyHeld: the J13 keyboard holds the key
ADB_REPLY_FOLLOWS = $80      ; an ADB status byte: reply bytes follow
ADB_KEY_REQUEST = $08        ; an ADB status byte: the keyboard has keys
ADB_STATUS_ESC = $20         ; an ADB status byte: an ESC notice
ADB_STATUS_ERROR = $40       ; an ADB status byte: a controller error
ADB_REPLY_BITS = $07         ; an ADB status byte: the reply bytes - 1
KEY_RELEASE = $80            ; a key byte: a release

; CaptureInput: read the ADB bytes and the mouse moves of the GLU, then ask
; the keyboard for its keys when it has some. JSL; returns A16.
CaptureInput:
  a8
captureByte:
              lda f:KMSTATUS
captureStatusMask: and #KM_DATA_FULL
              beq captureMouse
              lda f:DATAREG
              ldx a:.loword(keyReply)
              beq captureHeader
              cmp #$ff                  ; no key
              beq capturedKey
              sta a:.loword(irqValue)
              lda #0
              sta a:.loword(irqValue+1)
              a16
              stz a:.loword(irqType)    ; INPUT_KEY
              stz a:.loword(irqAux)
              jsr a:.loword(queueInput)
              a8
capturedKey:  dec a:.loword(keyReply)
              bne captureByte
              stz a:.loword(keyTalk)
              bra captureByte
captureHeader:
              sta a:.loword(keyHeaderByte)
              bit #ADB_KEY_REQUEST
              beq noKeyRequest
              ldx #1
              stx a:.loword(keyPending)
;;; A status byte ends this pass; the Talk below answers its request. KEGS keeps
;;; the request byte valid until that Talk, so reading on would never stop (#1).
noKeyRequest: lda a:.loword(keyHeaderByte)
              bpl captureMouse          ; bit 7: a reply follows
              and #ADB_REPLY_BITS
              beq emptyKeyReply
              inc a
              sta a:.loword(keyReply)
              bra captureByte
emptyKeyReply:
              stz a:.loword(keyTalk)
              bra captureByte
captureMouse: lda f:KMSTATUS
              bpl captureTalk           ; KM_MOUSE_FULL
              bit #KM_MOUSE_Y
              beq mouseXY
              lda f:MOUSEDATA           ; discard an orphan Y, not a pair
              bra captureTalk
mouseXY:      lda f:MOUSEDATA
              sta a:.loword(irqValue)
              lda f:MOUSEDATA
              sta a:.loword(irqAux)
              a16
              lda #INPUT_MOUSE
              sta a:.loword(irqType)
              jsr a:.loword(queueInput)
              a8
              inc a:.loword(mouseTalkCount)
              ldx a:.loword(mouseTalkCount)
              cpx #MOUSE_TALKS
              bcc captureTalk
              ldx #1                    ; keys may request service mid-motion
              stx a:.loword(keyPending)
captureTalk:  ldx a:.loword(keyPending)
              beq inputCaptured
              ldx a:.loword(keyTalk)
              bne inputCaptured
              lda f:KMSTATUS
              lsr a                     ; KM_COMMAND_FULL
              bcs inputCaptured
              lda #KEY_TALK
              sta f:DATAREG
              ldx #1
              stx a:.loword(keyTalk)
              stz a:.loword(keyPending)
              stz a:.loword(mouseTalkCount)
withoutRawKeys:
              stz a:.loword(keyPending)
inputCaptured:
              a16
              rtl

; queueInput: put the event irqType, irqValue, irqAux with the time in
; inputRing; a full ring drops it. JSR; A16.
queueInput:   lda f:GAME_CLOCK
              ldx a:.loword(inputHead)
              sta a:.loword(inputRing+INPUT_TIME),x
              lda a:.loword(irqType)
              sta a:.loword(inputRing+INPUT_TYPE),x
              lda a:.loword(irqValue)
              sta a:.loword(inputRing+INPUT_VALUE),x
              lda a:.loword(irqAux)
              sta a:.loword(inputRing+INPUT_AUX),x
              txa
              clc
              adc #INPUT_EVENT_SIZE
              and #INPUT_RING_SIZE-1
              cmp a:.loword(inputTail)
              beq inputOverflow
              sta a:.loword(inputHead)   ; publish only the complete event
              rts
inputOverflow:
              rts

.assert KM_MOUSE_FULL = $80 .and KM_COMMAND_FULL = 1, error ; the BPL and the LSR
