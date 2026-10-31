; Native adaptation of Wolf3D j13.s, SHA256 1f6f09af9da69e2a3a7bc74eff66eee4c24ad832a06ed8f0a2fe715223f90aaf.
; Source: the Wolfenstein 3D IIgs port, src/iigs/j13.s.
; Capture, recovery, row generations, ownership and transition validation are retained.
; 1943 schedules parameter delivery on its always-running DOC timer (4.19 ms).
; Paired latency/cost acceptance is required before this replaces the old input.
.a16
.i16
;;; ROM 00/01 compatibility keyboard. Menus always accept it; gameplay is
;;; opt-in. C000/C010 provide character/any-key-down, not an 80-key bitmap.
;;; Only a matching MCU firmware fingerprint permits partial-release reads.
;;; Captured transitions enter the timestamped input ring with source tag 2.
;;; DOC interrupts sample registers; DATA interrupts retire private replies.
;;; The existing short-lived DOC alarm sends a bounded batch of parameters.
;;; Controller service never installs a hook in the renderer.
AKD = KBDSTRB
MODIFIERS = KEYMODREG
ADBDATA = DATAREG
ADBSTATUS = KMSTATUS
NONE = 255

;;; Before StartKeys owns ADB. Save firmware buffering/repeat policy, then
;;; validate the private row layout. Failure leaves only ASCII/all-up input.
J13Init:      php
              sei
              rep #$30
              phb
              phk
              plb
              sep #$20
              lda f:ROMVER
              cmp #2
              bcs initDone
              lda #1
              sta a:.loword(j13Available)
              ldy #256
initDrain:    lda f:ADBSTATUS
              and #$20
              beq initModes
              lda f:ADBDATA
              dey
              bne initDrain
              bra initDone
initModes:    lda #$0a
              jsr a:.loword(sendBounded)
              bcs initDone
              jsr a:.loword(readBounded)
              bcs initDone
              sta a:.loword(savedModes)
              lda #1
              sta a:.loword(modesValid)
              jsr a:.loword(probeADB)
              jsr a:.loword(bufferKeyboard)
              ldx #0
initSignature:phx
              rep #$20
              txa
              cpx #32
              bcs initSecond
              clc
              adc #$18ac
              bra initAddress
initSecond:   clc
              adc #($1a10-32)
initAddress:  tax
              sep #$20
              jsl readMCU
              plx
              bcs initDone
              cmp f:matrixROM,x
              bne initDone
              inx
              cpx #64
              bcc initSignature
              lda #1
              sta a:.loword(j13Matrix)
initDone:
              rep #$30
              plb
              plp
              rtl

J13Prime:     php
              sei
              rep #$30
              phb
              phk
              plb
              lda a:.loword(j13Available)
              beq primeDone
              sep #$20
              lda #3
              jsr a:.loword(sendBounded)
              lda f:AKD
              sta a:.loword(sampleAKD)
              lda f:KBD
              .a8
              and #127
              sta a:.loword(j13LastAscii)
              rep #$20
              .a16
              lda #1
              sta a:.loword(j13Mode)
primeDone:    plb
              plp
              rtl

;;; Mode transitions happen outside timed frames. Finish an owned command
;;; before changing its IRQ mask. Retain observed keys between menu/game;
;;; the UI resets its consumer, and game entry validates the held switches.
J13Menu:
              .a16
              lda #1
              bra setMode
J13Benchmark:
              .a16
              lda #0
              bra setMode
J13Game:      lda f:j13Enabled
              beq gameOff
              .a16
              lda #2
              bra setMode
gameOff:
              .a16
              lda #0
setMode:      php
              sei
              rep #$30
              pha
              phx
              phy
              phb
              phk
              plb
              lda a:.loword(j13Available)
              bne modeAvailable
              brl modeDone
modeAvailable:
              lda 6,s                     ; requested A below B,Y,X
              sta a:.loword(j13NextMode)
              jsr a:.loword(finishOwner)
              jsr a:.loword(restoreHeldSample)
              stz a:.loword(rowWakeBudget)
              jsr a:.loword(removeOwnerIRQ)
              jsr a:.loword(stopSendTimer)
              jsr a:.loword(stopTimer)
              lda a:.loword(j13NextMode)
              beq modeClearHeld
              lda a:.loword(j13Mode)
              bne modeKeepHeld
modeClearHeld:
              jsr a:.loword(clearHeld)
modeKeepHeld:
              lda a:.loword(j13NextMode)
              sta a:.loword(j13Mode)
              .a16
              cmp #2
              bne modeDone
              jsl J13ValidateTracked
modeDone:     plb
              ply
              plx
              pla
              plp
              rtl

;;; Menu recognition is once per program run, so explicitly selecting Off
;;; with J13 is not undone by the following Escape. Saving remains explicit.
J13Toggle:    lda f:j13Enabled
              eor #1
              sta f:j13Enabled
              .a16
              lda #2
              sta f:j13Manual
              .a16
              lda #1
              sta f:j13MenuSeen
              rtl

;;; Bit 1 remembers an explicit choice, including saved Off. An untouched
;;; default remains eligible for automatic enable on the first menu use.
J13SettingsLoad:
              lda f:settings + 8
              .a16
              and #1
              and f:j13Available
              sta f:j13Enabled
              lda f:settings + 8
              and #2
              sta f:j13Manual
              sta f:j13MenuSeen
              rtl
J13SettingsStore:
              lda f:j13Enabled
              ora f:j13Manual
              sep #$20
              sta f:settings + 8
              rep #$20
              rtl

;;; Called by PollKey in menus and attract playback. Benchmark mode only
;;; checks Escape; it does not run gameplay capture or MCU row scans.
J13Poll:      php
              sei
              rep #$30
              phb
              phk
              plb
              lda a:.loword(j13Available)
              beq pollDone
              lda a:.loword(j13Mode)
              beq pollEscape
              .a16
              cmp #2
              bne pollSample
              jsr a:.loword(readControllerClock)
pollSample:
              jsr a:.loword(J13Sample)
              jsr a:.loword(scheduleRow)
              jsr a:.loword(J13Pump)
              bra pollDone
pollEscape:   jsr a:.loword(escapeSample)
pollDone:     plb
              plp
              rtl

J13Frame:     php
              sei
              phb
              sep #$20
              lda #^input_native
              pha
              plb
              rep #$20
              jsl I_GetTime
              phk
              plb
              sta a:.loword(controllerTime)
              jsr a:.loword(J13Sample)
              jsr a:.loword(ensureTimer)
              jsr a:.loword(deferRows)
              jsr a:.loword(serviceController)
              lda a:.loword(controllerTime)
              plb
              plp
              rtl
readControllerClock:
              phb
              sep #$20
              lda #^input_native
              pha
              plb
              rep #$20
              jsl I_GetTime
              plb
              sta a:.loword(controllerTime)
              rts
J13EscapeFrame:
              php
              sei
              phb
              phk
              plb
              jsr a:.loword(escapeSample)
              plb
              plp
              jml I_GetTime
escapeSample:
              sep #$20
              lda f:KBD
              bpl escapeDone
              pha
              lda f:AKD
              pla
              cmp #$9b
              bne escapeDone
              rep #$20
              jsr a:.loword(queueRoom)
              bcc escapeDone
              jsr a:.loword(menuUsed)
              stz a:.loword(sampleTimed)
              lda #$35
              jsr a:.loword(queue)
              lda #$b5
              jsr a:.loword(queue)
escapeDone:
              rep #$20
              rts

;;; The DOC IRQ entry already saved every register and DBR. Private replies
;;; belong to the DATA interrupt; sampling never issues a controller command.
j13Irq:
              rep #$30
              jsr a:.loword(J13Sample)
              lda a:.loword(rowWakeBudget)
              beq irqCaptureDone
              dec a:.loword(rowWakeBudget)
              bne irqCaptureDone
              jsr a:.loword(scheduleRow)
              jsr a:.loword(J13Pump)
irqCaptureDone:
              rts

;;; Caller masks IRQs, DBR=code bank, A/X/Y16. Reserve room before touching C010.
;;; At most five modifiers, three releases and a repress pair can be queued.
J13Sample:
              .a16
              lda f:inputHead
              cmp f:inputTail
              beq sampleRoom
              jsr a:.loword(queueRoom)
              bcs sampleRoom
              rts
sampleRoom:   inc a:.loword(j13Samples)
              sep #$20
              lda f:KBD
              ; Recover a character whose strobe raced the previous C010.
              bmi sampleFresh
              cmp a:.loword(j13LastAscii)
              beq sampleUnchanged
              .a8
              ora #128
sampleFresh:  sta a:.loword(sampleAscii)
              stz a:.loword(sampleRecover)
              .a8
              and #127
              sta a:.loword(j13LastAscii)
              ; Snapshot character modifiers before acknowledging C010.
              lda f:MODIFIERS
              sta a:.loword(sampleMods)
sampleMetadata:
              lda f:AKD
              sta a:.loword(sampleAKD)
              jsr a:.loword(readModifiers)
              stz a:.loword(sampleTimed)
              jmp a:.loword(sampleModifiers)
sampleUnchanged:
              bra sampleSlowHeld
;;; P3 enabled this path only after recovery finished. Fresh characters still
;;; take sampleFresh. All-up and mode changes restore the general sampler.
sampleSteadyHeld:
              lda f:AKD
              bpl sampleSteadyUp
              rep #$20
              rts
sampleSteadyUp:
              .a8
              sta a:.loword(sampleAKD)
              lda #(sampleSlowHeld-sampleUnchanged-2)
              sta a:.loword(sampleUnchanged+1)
              jmp a:.loword(sampleIdleModifiers)
sampleSlowHeld:
              .a8
              sta a:.loword(sampleAscii)
              ldx a:.loword(sampleAKD)
              lda f:AKD
              sta a:.loword(sampleAKD)
              bmi sampleDown
              bra sampleUpCheck
sampleDown:
              txa
              bmi sampleDownKnown
              lda #1
              sta a:.loword(sampleRecover)
              rep #$20
              jsr a:.loword(readControllerClock)
              clc
              adc #7
              sta a:.loword(recoverTime)
              sep #$20
              bra sampleHeld
sampleDownKnown:
              ldx a:.loword(sampleRecover)
              bne sampleRecovery
sampleHeld:
              ; With an ordinary key held, P3 replies already publish live
              ; modifiers. No new character means no translation work here.
              rep #$20
              lda a:.loword(j13Mode)
              .a16
              cmp #2
              bne sampleLive8
              lda a:.loword(physicalValid)
              beq sampleLive8
              rts
sampleLive8:
              sep #$20
sampleIdleModifiers:
              .a8
              lda f:MODIFIERS
              ; AKD can clear before C025 stops describing the old character.
              ; Bit 5 identifies an independent modifier-latch update.
              bit #$20
              bne sampleIdleReady
              rep #$20
              jmp a:.loword(sampleRelease)
sampleIdleReady:
              stz a:.loword(physicalValid)
              sta a:.loword(sampleMods)
              jsr a:.loword(readModifiers)
              cmp a:.loword(j13Mods)
              beq sampleNoModifierChange
              stz a:.loword(sampleTimed)
              jsr a:.loword(updateModifiers)
sampleNoModifierChange:
              jmp a:.loword(sampleRelease)
sampleUpCheck:
              ldx a:.loword(sampleRecover)
              beq sampleIdleModifiers
sampleRecovery:
              ; AKD can rise before the MCU writes ASCII. A C010 read in
              ; that interval can clear the later strobe even when the new
              ; character equals the last one. Wait for character modifiers,
              ; or retain the completed tap when AKD has already fallen.
              ; Menu polls can run before the MCU finishes publishing the
              ; character. Fresh strobes still bypass this recovery-only
              ; delay; two clock edges guarantee at least one full tic.
              rep #$20
              jsr a:.loword(readControllerClock)
              sec
              sbc a:.loword(recoverTime)
              sep #$20
              bmi sampleHeld
              lda f:MODIFIERS
              bit #$20
              beq sampleRecovered
              bit a:.loword(sampleAKD)
              bmi sampleHeld
sampleRecovered:
              ; Metadata must precede the recovered character read: the MCU
              ; may publish ASCII while the earlier C010 is being sampled.
              and #$f7
              sta a:.loword(sampleMods)
              lda f:KBD
              .a8
              ora #128
              sta a:.loword(sampleAscii)
              .a8
              and #127
              sta a:.loword(j13LastAscii)
              stz a:.loword(sampleRecover)
              jmp a:.loword(sampleMetadata)
readModifiers:
              lda a:.loword(sampleMods)
              .a8
              and #$c7
              sta a:.loword(nextMods)
              lda f:BUTN0
              bpl sampleApple1
              lda a:.loword(nextMods)
              .a8
              ora #128
              sta a:.loword(nextMods)
sampleApple1: lda f:BUTN1
              bpl sampleModifierBits
              lda a:.loword(nextMods)
              ora #64
              sta a:.loword(nextMods)
sampleModifierBits:
              rep #$20
              lda a:.loword(nextMods)
              rts
sampleModifiers:
              lda a:.loword(j13Mode)
              .a16
              cmp #2
              bne sampleUpdateMods
              ; A fresh character is newer than the cached P3 reply. Repeat
              ; modifier bits can be mistranslated, so retain live state there.
              lda a:.loword(sampleMods)
              bit #8
              beq sampleUpdateMods
              lda a:.loword(physicalValid)
              beq sampleRepeatMods
              lda a:.loword(physicalMods)
              bra sampleKeepMods
sampleRepeatMods:
              lda a:.loword(j13Mods)
sampleKeepMods:
              sta a:.loword(nextMods)
sampleUpdateMods:
              jsr a:.loword(updateModifiers)
              bra sampleCharacter
updateModifiers:
              lda a:.loword(nextMods)
              cmp a:.loword(j13Mods)
              bne modifiersChanged
              rts
modifiersChanged:
              ldx #0
sampleModifier:
              lda a:.loword(nextMods)
              eor a:.loword(j13Mods)
              and f:modifierMasks,x
              and #255
              beq sampleNextModifier
              lda a:.loword(nextMods)
              and f:modifierMasks,x
              and #255
              beq sampleModifierUp
              lda f:modifierKeys,x
              and #255
              bra sampleModifierQueue
sampleModifierUp:
              lda f:modifierKeys,x
              and #255
              ora #128
sampleModifierQueue:
              jsr a:.loword(queue)
sampleNextModifier:
              inx
              cpx #5
              bcc sampleModifier
              lda a:.loword(nextMods)
              sta a:.loword(j13Mods)
              rts
sampleCharacter:
              lda a:.loword(sampleAscii)
              bit #128
              beq sampleRelease
              lda a:.loword(sampleMods)
              bit #8                       ; firmware repeat is not a fresh down
              bne sampleRelease
              lda a:.loword(sampleAscii)
              and #127
              tax
              lda f:asciiKeys,x
              and #255
              cmp #NONE
              beq sampleRelease
              sta a:.loword(newKey)
              lda a:.loword(j13Mode)
              .a16
              cmp #1
              bne sampleOrdinary
              lda a:.loword(j13MenuSeen)
              bne sampleMenuOrdinary
              ; Ignored title/demo keys do not opt gameplay in.
              lda f:$001520
              bne sampleAttractKey
              lda f:menuMode
              and #255
              cmp #13
              bne sampleMenuUsed
sampleAttractKey:
              lda a:.loword(newKey)
              cmp #$35
              bne sampleMenuOrdinary
sampleMenuUsed:
              jsr a:.loword(menuUsed)
sampleMenuOrdinary:
              lda #1
              sta a:.loword(validateIncoming)
              jsl J13ValidateTracked
              stz a:.loword(validateIncoming)
sampleOrdinary:
              jsr a:.loword(ordinaryDown)
sampleRelease:lda a:.loword(sampleAKD)
              bit #128
              bne sampleDone
              lda a:.loword(knownCount)
              beq sampleDone
              stz a:.loword(sampleTimed)
              jsr a:.loword(releaseOrdinary)
sampleDone:   rts

menuUsed:     lda a:.loword(j13MenuSeen)
              bne menuUseDone
              .a16
              lda #1
              sta a:.loword(j13MenuSeen)
              sta a:.loword(j13Enabled)
menuUseDone:  rts

ordinaryDown: inc a:.loword(j13Generation)
              ldx #0
ordinaryFind: lda a:.loword(j13Keys),x
              cmp a:.loword(newKey)
              beq ordinaryRepress
              inx
              inx
              cpx #6
              bcc ordinaryFind
              lda a:.loword(j13Matrix)
              beq ordinarySingle
              ldx a:.loword(newKey)
              cpx #64
              bcs ordinarySingle
              lda f:pumpMasks,x
              and #255
              beq ordinarySingle
              ldx #0
ordinarySlot: lda a:.loword(j13Keys),x
              cmp #NONE
              beq ordinaryInstall
              inx
              inx
              cpx #6
              bcc ordinarySlot
              rts                            ; three ordinary identities maximum
ordinarySingle:
              jsr a:.loword(releaseOrdinary)
              ldx #0
ordinaryInstall:
              lda a:.loword(newKey)
              sta a:.loword(j13Keys),x
              inc a:.loword(knownCount)
              jmp a:.loword(queue)
ordinaryRepress:
              ora #128
              jsr a:.loword(queue)
              lda a:.loword(newKey)
              jmp a:.loword(queue)
releaseOrdinary:
              jsr a:.loword(restoreHeldSample)
              inc a:.loword(j13Generation)
              ldx #0
releaseKey:   lda a:.loword(j13Keys),x
              cmp #NONE
              beq releaseNext
              ora #128
              jsr a:.loword(queue)
              lda #NONE
              sta a:.loword(j13Keys),x
releaseNext:  inx
              inx
              cpx #6
              bcc releaseKey
              stz a:.loword(knownCount)
              rts

queueRoom:    lda f:inputTail
              sec
              sbc f:inputHead
              dec a
              and #1023
              cmp #(10*8)
              rts
;;; Preserve X/Y. Timestamp once for all transitions from one sample.
queue:        phx
              phy
              pha
              lda a:.loword(sampleTimed)
              bne queueTimed
              phb
              sep #$20
              lda #^input_native
              pha
              plb
              rep #$20
              jsl I_GetTime
              plb
              sta a:.loword(sampleTime)
              inc a:.loword(sampleTimed)
queueTimed:   lda f:inputHead
              tax
              lda a:.loword(sampleTime)
              sta f:inputRing,x
              .a16
              lda #2
              sta f:inputRing+2,x
              pla
              sta f:inputRing+4,x
              .a16
              lda #0
              sta f:inputRing+6,x
              txa
              clc
              adc #8
              and #1023
              sta f:inputHead
              inc a:.loword(j13Events)
              ply
              plx
              rts

;;; One batch per frame, at least two tics apart: P3 and every distinct held
;;; row. One ordinary key needs only P3 because AKD supplies its release.
;;; With overlapping keys, two existing music wakes move the batch away
;;; from the frame boundary. The stopped-music sampler supplies the same
;;; wakes; a sparse-wake frame falls back at the next foreground poll.
deferRows:    lda a:.loword(knownCount)
              .a16
              cmp #2
              bcc deferImmediate
              lda f:$000068
              cmp a:.loword(rowArmFrame)
              beq deferDone
              sta a:.loword(rowArmFrame)
              lda a:.loword(rowWakeBudget)
              bne deferImmediate
              .a16
              lda #2
              sta a:.loword(rowWakeBudget)
deferDone:    rts
deferImmediate:
              stz a:.loword(rowWakeBudget)
              jmp a:.loword(scheduleRow)

scheduleRow:  lda f:$000068
              cmp a:.loword(rowFrame)
              beq scheduleReturn
              lda a:.loword(j13Mode)
              .a16
              cmp #2
              bne scheduleReturn
              lda a:.loword(j13State)
              bne scheduleReturn
              lda a:.loword(j13Matrix)
              beq scheduleReturn
              lda a:.loword(knownCount)
              beq scheduleReturn
              lda f:$000068
              sta a:.loword(rowFrame)
              lda a:.loword(controllerTime)
              sec
              sbc a:.loword(lastRowTime)
              cmp #7
              bcs scheduleDue
scheduleReturn:rts
scheduleDue:  lda a:.loword(controllerTime)
              sta a:.loword(lastRowTime)
              jsr a:.loword(cacheRows)
              lda a:.loword(rowListSize)
              lsr a
              sta a:.loword(rowsLeft)
              lda #$e8
              sta a:.loword(rowAddress)
              bra scheduleReady
scheduleHeldRow:
              lda a:.loword(knownCount)
              .a16
              cmp #2
              bcs scheduleTwoKeys
              rts
scheduleTwoKeys:
              jsr a:.loword(cacheRows)
              ldx a:.loword(rowNext)
              inx
              inx
              cpx a:.loword(rowListSize)
              bcc scheduleIndex
              ldx #0
scheduleIndex:stx a:.loword(rowNext)
              lda a:.loword(rowList),x
              sep #$20
              sta a:.loword(rowAddress)
              xba
              sta a:.loword(rowExpected)
              rep #$20
scheduleReady:lda a:.loword(lastRowTime)
              clc
              adc #239
              sta a:.loword(rowDeadline)
              .a16
              lda #1
              sta a:.loword(j13State)
scheduleDone: rts

restoreHeldSample:
              lda #($80 | ((sampleSlowHeld-sampleUnchanged-2) << 8))
              sta a:.loword(sampleUnchanged)
              rts

cacheRows:    lda a:.loword(j13Generation)
              cmp a:.loword(maskGeneration)
              beq cacheRowsDone
              jsl J13CacheRows
cacheRowsDone:rts

;;; One status sample per call. Pending ADB Talk, DATA or mouse wins before
;;; acquisition. While owned, only DATA IRQ/parsing is masked; mouse runs.
J13Pump:
              .a16
              lda a:.loword(j13State)
              bne pumpActive
              rts
pumpActive:
              sep #$20
              lda f:ADBSTATUS
              sta a:.loword(rowStatus)
              lda a:.loword(j13State)
              cmp #1
              bne pumpOwned
              lda f:keyTalk
              ora f:keyPending
              beq j13Long3
              brl pumpDone
j13Long3:
              lda a:.loword(rowStatus)
              and #$a1
              beq j13Long4
              brl pumpDone
j13Long4:
              lda a:.loword(rowStatus)
              and #$50
              sta a:.loword(rowEnables)
              lda a:.loword(rowStatus)
              and #$40
              sta f:ADBSTATUS
              lda #0
              sta f:captureStatusMask+1
              lda #1
              sta a:.loword(j13Owner)
              sta f:keyTalk
              jsr a:.loword(installOwnerIRQ)
              rep #$20
              jsr a:.loword(startSendTimer)
              sep #$20
pumpCommand:  lda #9
              sta f:ADBDATA
              ; $C05F is a Second Sight event; never inject it into DMA1.
              lda #2
              sta a:.loword(j13State)
              rep #$20
              lda a:.loword(j13Generation)
              sta a:.loword(rowGeneration)
              rts
pumpOwned:
              .a8
              lda a:.loword(rowStatus)
              bit #$20
              bne pumpData
              lda a:.loword(j13State)
              .a8
              cmp #4
              bne pumpSend
              brl pumpDone
pumpSend:
              lda a:.loword(rowStatus)
              and #1
              beq j13Long5
              brl pumpDone
j13Long5:
              lda a:.loword(j13State)
              cmp #2
              bne pumpHigh
              lda a:.loword(rowAddress)
              sta f:ADBDATA
              ; $C05F is a Second Sight event; never inject it into DMA1.
              lda #3
              sta a:.loword(j13State)
              brl pumpDone
pumpHigh:     lda #0
              sta f:ADBDATA
              ; $C05F is a Second Sight event; never inject it into DMA1.
              lda #4
              sta a:.loword(j13State)
              lda a:.loword(rowEnables)
              sta f:ADBSTATUS
              rep #$20
              brl pumpDone
pumpData:
              .a8
     lda f:ADBDATA
              sta a:.loword(rowValue)
              lda a:.loword(j13State)
              .a8
              cmp #4
              bne pumpStatusByte
              lda a:.loword(rowAddress)
              cmp #$e8
              bne pumpMatrixReply
              lda a:.loword(rowValue)
              cmp #8                      ; keyboard SRQ
              beq pumpStatusByte
              cmp #$20                   ; Escape notification
              beq pumpStatusByte
              cmp #$40                   ; controller error
              beq pumpStatusByte
              rep #$20
              brl pumpPhysicalReply
pumpMatrixReply:
              .a8

              lda a:.loword(rowValue)
              eor #255
              cmp a:.loword(rowExpected)
              bne pumpChangedRow
              rep #$20
              brl batchReadDone
pumpChangedRow:
              .a8

              ora a:.loword(rowExpected)
              cmp a:.loword(rowExpected)
              beq pumpValidReply
              ; Status notifications may precede the single-byte row reply.
              lda a:.loword(rowValue)
              and #$87
              beq pumpStatusByte
              rep #$20
              jsr a:.loword(releaseOwner)
              brl pumpDone                  ; ambiguous row: no inferred releases
pumpStatusByte:
              .a8

              lda a:.loword(rowValue)
              and #$87
              bne pumpStatusDone
              lda a:.loword(rowValue)
              and #8
              ora a:.loword(rowDeferred)
              sta a:.loword(rowDeferred)
pumpStatusDone:
              rep #$20
              rts
pumpValidReply:
              rep #$20
              jsr a:.loword(queueRoom)
              bcs pumpHaveRoom
              brl pumpFinished
pumpHaveRoom: lda a:.loword(rowGeneration)
              cmp a:.loword(j13Generation)
              beq pumpCurrentGeneration
              brl pumpFinished              ; reply predates a newly pressed key
pumpCurrentGeneration:
              stz a:.loword(sampleTimed)
              ldy #0
rowRelease:   lda a:.loword(j13Keys),y
              cmp #64
              bcs rowReleaseNext
              tax
              lda f:pumpRows,x
              and #255
              cmp a:.loword(rowAddress)
              bne rowReleaseNext
              lda f:pumpMasks,x
              and a:.loword(rowValue)
              and #255
              beq rowReleaseNext
              txa
              ora #128
              jsr a:.loword(queue)
              lda #NONE
              sta a:.loword(j13Keys),y
              dec a:.loword(knownCount)
              inc a:.loword(j13Generation)
rowReleaseNext:
              iny
              iny
              cpy #6
              bcc rowRelease
batchReadDone:dec a:.loword(rowsLeft)
              beq pumpFinished
              jmp a:.loword(continueHeldRows)
pumpFinished:
              jsr a:.loword(releaseOwner)
pumpDone:
              rep #$20
              rts

;;; C025 stays at its character's modifier state while ordinary keys remain
;;; down. Firmware P3 ($E8) supplies live independent switches; bits 0..2 are
;;; active low and Apple bits 6/7 active high. P3 is read only on validated ROM.
pumpPhysicalReply:
              ; An intervening character/all-up transition owns newer state.
              lda a:.loword(knownCount)
              beq physicalReturn
              lda a:.loword(rowGeneration)
              cmp a:.loword(j13Generation)
              bne physicalReturn
              lda a:.loword(rowValue)
              eor #7
              and #$c7
              sta a:.loword(physicalMods)
              sta a:.loword(nextMods)
              .a16
              lda #1
              sta a:.loword(physicalValid)
              lda a:.loword(sampleRecover)
              bne physicalRecovery
              sep #$20
              stz a:.loword(sampleUnchanged+1)
              rep #$20
physicalRecovery:
              lda a:.loword(nextMods)
              cmp a:.loword(j13Mods)
              beq physicalNoRoom
              jsr a:.loword(queueRoom)
              bcc physicalNoRoom
              stz a:.loword(sampleTimed)
              jsr a:.loword(updateModifiers)
physicalNoRoom:
continueHeldRows:
              lda a:.loword(knownCount)
              .a16
              cmp #2
              bcc physicalDone
              jsr a:.loword(scheduleTwoKeys)
              sep #$20
              lda a:.loword(rowEnables)
              and #$40
              sta f:ADBSTATUS
              jmp a:.loword(pumpCommand)
physicalDone: jmp a:.loword(releaseOwner)
physicalReturn:jmp a:.loword(releaseOwner)

 ; One foreground service step. The parameter alarm and DATA IRQ complete
 ; owned commands asynchronously; a busy raw ADB transaction defers capture.
serviceController:
              jsr a:.loword(J13Pump)
              lda a:.loword(j13State)
              .a16
              cmp #4
              bcc serviceDone
              bra serviceDeadline
serviceTimeout:
              inc a:.loword(j13Timeouts)
              stz a:.loword(j13Matrix)
              jmp a:.loword(releaseOwner)
serviceDeadline:
              lda a:.loword(controllerTime)
              sec
              sbc a:.loword(rowDeadline)
              bpl serviceTimeout
serviceDone:  rts

releaseOwner:
              sep #$20
              lda #$20
              sta f:captureStatusMask+1
              lda #0
              sta f:keyTalk
              sta a:.loword(j13Owner)
              lda a:.loword(rowDeferred)
              beq releaseNoPending
              lda #1
              sta f:keyPending
releaseNoPending:
              stz a:.loword(rowDeferred)
              lda a:.loword(rowEnables)
              sta f:ADBSTATUS
              rep #$20
              stz a:.loword(j13State)
              jsr a:.loword(removeOwnerIRQ)
              jsr a:.loword(stopSendTimer)
              rts
;;; Transition cleanup may wait. Never abandon a partially sent $09 command
;;; and let the ADB parser consume its reply. A timeout disables future rows
;;; after allowing the validated firmware to finish its bounded receive wait.
finishOwner:  lda a:.loword(j13Owner)
              beq finishIdle
              ldy #16384
finishWait:   phy
              jsr a:.loword(J13Pump)
              ply
              lda a:.loword(j13Owner)
              beq finishIdle
              dey
              bne finishWait
              inc a:.loword(j13Timeouts)
              stz a:.loword(j13Matrix)
              jmp a:.loword(releaseOwner)
finishIdle:   stz a:.loword(j13State)
              rts

 ; Private command replies use the existing ADB interrupt. Its parser
 ; remains displaced only while this owner holds C026; mouse service follows
 ; normally and pending raw keyboard SRQs are replayed when ownership ends.
 ; Caller masks IRQs and has A8. Restore the original LDA long instruction.
installOwnerIRQ:
              rts
removeOwnerIRQ:
              rts

;;; 1943 uses its existing 238.55 Hz DOC clock for parameter delivery.
;;; Only an owned batch enables this bounded service. No oscillator or
;;; permanently active extra interrupt is added. Measure release latency
;;; against Wolf before accepting the 4.19 ms delivery interval.
;;; The IRQ entry has saved all registers. Do not sample keys on this alarm.
sendAlarm:
              .a16
              lda a:.loword(j13State)
              .a8
              .a16
              cmp #2
              bcc sendIRQDone
              dec a:.loword(sendBudget)
              beq sendIRQTimeout
              .a16
              cmp #4
              bcs sendIRQDone
              sep #$20
              lda f:ADBSTATUS
              bit #$20
              bne sendIRQData
              lsr a
              bcs sendIRQWide
              lda a:.loword(j13State)
              cmp #2
              bne sendIRQHigh
              lda a:.loword(rowAddress)
              sta f:ADBDATA
              ; $C05F is a Second Sight event; never inject it into DMA1.
              inc a:.loword(j13State)
              bra sendIRQWide
sendIRQHigh:  lda #0
              sta f:ADBDATA
              ; $C05F is a Second Sight event; never inject it into DMA1.
              inc a:.loword(j13State)
              lda a:.loword(rowEnables)
              sta f:ADBSTATUS
sendIRQWide:
              rep #$20
sendIRQDone:  rts
sendIRQTimeout:
              jmp a:.loword(serviceTimeout)
sendIRQData:
              rep #$20
              jmp a:.loword(J13Pump)

startSendTimer:
              lda #16                     ; bounded P3 plus up to three distinct rows
              sta a:.loword(sendBudget)
              .a16
              lda #1
              sta a:.loword(j13SendTimer)
              rts
stopSendTimer:
              stz a:.loword(j13SendTimer)
              rts
ensureTimer:
stopTimer:
              rts                          ; 1943's DOC clock always runs

;;; UI reset discards consumer events, not the identities of switches still
;;; held on J13. Refresh them before the consumer resets; game entry validates
;;; and republishes bindings. Raw/off mode still releases J13 ownership.
J13Reset:     php
              sei
              rep #$30
              phb
              phk
              plb
              jsr a:.loword(finishOwner)
              jsr a:.loword(removeOwnerIRQ)
              lda a:.loword(j13Mode)
              beq resetClearHeld
              jsr a:.loword(J13Sample)
              bra resetDone
resetClearHeld:
              jsr a:.loword(clearHeld)
resetDone:
              plb
              plp
              rtl
clearHeld:    jsr a:.loword(restoreHeldSample)
              lda #NONE
              sta a:.loword(j13Keys)
              sta a:.loword(j13Keys+2)
              sta a:.loword(j13Keys+4)
              stz a:.loword(j13Mods)
              stz a:.loword(knownCount)
              stz a:.loword(physicalValid)
              stz a:.loword(sampleRecover)
              inc a:.loword(j13Generation)
              ; Remove only J13's held bit from the merged consumer state.
              ldx #127
              sep #$20
clearSource:  lda f:keyHeld,x
              and #1
              sta f:keyHeld,x
              dex
              bpl clearSource
              lda f:AKD
              sta a:.loword(sampleAKD)
              lda f:KBD
              .a8
              and #127
              sta a:.loword(j13LastAscii)
              rep #$20
              rts

J13Stop:      jsl J13Benchmark
              php
              sei
              rep #$30
              phb
              phk
              plb
              ; Finish outstanding raw Talk before sending firmware commands.
              ldy #16384
stopTalk:     phy
              phb
              sep #$20
              lda #^input_native
              pha
              plb
              rep #$20
              jsl CaptureInput
              plb
              ply
              lda f:keyTalk
              beq stopRestore
              dey
              bne stopTalk
              bra stopDone
stopRestore:
              sep #$20
              jsr a:.loword(restoreFirmwareRepeat)
              lda a:.loword(modesValid)
              beq stopDone
              lda #5
              jsr a:.loword(sendBounded)
              bcs stopDone
              lda #$11
              jsr a:.loword(sendBounded)
              bcs stopDone
              lda #4
              jsr a:.loword(sendBounded)
              bcs stopDone
              lda a:.loword(savedModes)
              and #$11
              jsr a:.loword(sendBounded)
stopDone:
              rep #$20
              plb
              plp
              rtl

j13Enabled:   .word 0
j13AdbPresent:.word 1
j13Available: .word 0
j13Matrix:    .word 0
j13Mode:      .word 0
j13NextMode:  .word 0
j13MenuSeen:  .word 0
j13Manual:    .word 0                      ; saved bit 1: explicit On/Off
j13Owner:     .word 0
j13State:     .word 0
j13Timeouts:  .word 0
j13Samples:   .word 0
j13Events:    .word 0
j13Timer:     .word 0
j13SendTimer: .word 0
sendBudget:   .word 0
j13Keys:      .word NONE,NONE,NONE
j13Mods:      .word 0
knownCount:   .word 0
controllerTime:.word 0
physicalMods: .word 0
physicalValid:.word 0
rowDeadline:  .word 0
nextMods:     .word 0
newKey:       .word 0
j13Generation:.word 0
rowGeneration:.word 0
rowNext:      .word 0
rowFrame:     .word $ffff
rowArmFrame:  .word $ffff
rowWakeBudget:.word 0
maskGeneration:.word $ffff
rowMasks:     .byte 0,0,0,0,0,0,0,0,0,0
rowList:      .word 0,0,0
rowListSize:  .word 0
cacheMask:    .byte 0
rowsLeft:     .word 0
rowAddress:   .word 0
rowExpected:  .word 0
rowValue:     .word 0
rowEnables:   .word 0
rowStatus:    .word 0
rowDeferred:  .word 0
lastRowTime:  .word 0
sampleAscii:  .word 0
sampleMods:   .word 0
sampleAKD:    .word 0
sampleRecover:.word 0
recoverTime:  .word 0
j13LastAscii: .word 0
sampleTime:   .word 0
sampleTimed:  .word 0
savedModes:   .byte 0
modesValid:   .byte 0

sendBounded:
              .a8
  pha
              ldy     #16384
sendBounded_local_1:           lda     f:ADBSTATUS
              and     #1
              beq     sendBounded_local_2
              dey
              bne     sendBounded_local_1
              pla
              sec
              rts
sendBounded_local_2:           pla
              sta     f:ADBDATA
              ; Stock-speed IIgs has no Zip delay; $C05F would corrupt DMA1.
              clc
              rts
readBounded:
              .a8
  ldy     #16384
readBounded_local_1:           lda     f:ADBSTATUS
              and     #$20
              bne     readBounded_local_2
              dey
              bne     readBounded_local_1
              sec
              rts
readBounded_local_2:           lda     f:ADBDATA
              clc
              rts


modifierMasks: .byte $01, $02, $04, $80, $40
modifierKeys:  .byte $38, $36, $39, $37, $3a, 0

;;; Translate the low seven ASCII bits to synthetic ADB identities.
;;; Navigation aliases take precedence (Ctrl-H becomes Left); shifted
;;; punctuation maps to its unshifted US key. This mapping cannot distinguish
;;; keys that produce the same character. A NONE entry would be ignored by
;;; the caller; release information comes from AKD or a validated row.
asciiKeys:
              .byte   $31, $00, $0b, $08, $02, $0e, $03, $05, $3b, $30, $3d, $3e, $25, $24, $2d, $1f ; $00-$0F
              .byte   $23, $0c, $0f, $01, $11, $3c, $09, $0d, $07, $10, $06, $35, $2a, $1e, $16, $1b ; $10-$1F
              .byte   $31, $12, $27, $14, $15, $17, $1a, $27, $19, $1d, $1c, $18, $2b, $1b, $2f, $2c ; $20-$2F
              .byte   $1d, $12, $13, $14, $15, $17, $16, $1a, $1c, $19, $29, $29, $2b, $18, $2f, $2c ; $30-$3F
              .byte   $13, $00, $0b, $08, $02, $0e, $03, $05, $04, $22, $26, $28, $25, $2e, $2d, $1f ; $40-$4F
              .byte   $23, $0c, $0f, $01, $11, $20, $09, $0d, $07, $10, $06, $21, $2a, $1e, $16, $1b ; $50-$5F
              .byte   $32, $00, $0b, $08, $02, $0e, $03, $05, $04, $22, $26, $28, $25, $2e, $2d, $1f ; $60-$6F
              .byte   $23, $0c, $0f, $01, $11, $20, $09, $0d, $07, $10, $06, $21, $2a, $1e, $32, $33 ; $70-$7F


readMCU:
              .a8
      lda     #9
              jsr     a:.loword(sendBounded)
              bcs     readMCUDone
              txa
              jsr     a:.loword(sendBounded)
              bcs     readMCUDone
              rep     #$20
              txa
              xba
              sep     #$20
              jsr     a:.loword(sendBounded)
              bcs     readMCUDone
              jsr     a:.loword(readBounded)
readMCUDone:  rtl


;;; Scanner bytes followed by row-update bytes, in identifyLoop read order.
matrixROM:
              .byte $3c, $ff, $e4, $a2, $09, $22, $59, $3c, $0a, $48, $c6, $48, $30, $5b, $a5, $48, $aa, $8b, $85, $e4, $b5, $31, $45, $e2, $3c, $ff, $e4, $f0, $ed, $a0, $08, $88
              .byte $22, $b4, $f7, $4c, $05, $15, $31, $95, $31, $60, $8f, $0a, $e7, $0f, $06, $49, $ff, $35, $31, $95, $31, $22, $c5, $33, $1c, $f3, $1a, $a6, $4c, $e0, $37, $f0

;;; Indexed by the synthetic ADB identity from asciiKeys: MCU RAM row and
;;; active-low switch mask. Row $FF/mask 0 means no supported matrix entry.
;;; Same-row keys share one read; the cached row list merges their masks.
pumpRows:
              .byte $31, $33, $32, $35, $34, $36, $31, $32, $33, $34, $ff, $35, $32, $33, $34, $35
              .byte $36, $37, $32, $33, $34, $35, $36, $37, $38, $3a, $38, $3a, $39, $39, $3a, $3a
              .byte $38, $39, $39, $38, $37, $3a, $37, $3a, $38, $39, $37, $38, $3a, $36, $37, $39
              .byte $31, $39, $37, $37, $ff, $31, $ff, $ff, $ff, $ff, $ff, $39, $3a, $38, $38, $ff
pumpMasks:
              .byte $04, $04, $04, $04, $04, $04, $08, $08, $08, $08, $00, $08, $02, $02, $02, $02
              .byte $02, $02, $01, $01, $01, $01, $01, $01, $10, $01, $01, $10, $01, $10, $20, $02
              .byte $02, $20, $02, $20, $40, $04, $04, $40, $04, $04, $10, $08, $08, $08, $08, $08
              .byte $02, $40, $20, $80, $00, $01, $00, $00, $00, $00, $00, $80, $80, $80, $40, $00



bufferRestore: .byte 0
bufferKeyboard:
              .a8

              lda     #$0a
              jsr     a:.loword(sendBounded)
              bcs     bufferDone
              jsr     a:.loword(readBounded)
              bcs     bufferDone
              and     #$10
              bne     bufferDone
              lda     #$10
              sta     f:bufferRestore
              lda     #$04
              jsr     a:.loword(sendBounded)
              bcs     bufferDone
              lda     #$10
              jsr     a:.loword(sendBounded)
bufferDone:   jsr     a:.loword(stopFirmwareRepeat)
              ldx     #0                   ; First scanner-signature byte.
              rts


repeatRestore: .byte 0
keyboardConfig: .res 3,0
stopFirmwareRepeat:
              .a8

              lda     #$0b
              jsr     a:.loword(sendBounded)
              bcs     repeatSetupDone
              ldx     #0
readKeyboardConfig:
              jsr     a:.loword(readBounded)
              bcs     repeatSetupDone
              sta     f:keyboardConfig,x
              inx
              cpx     #3
              bcc     readKeyboardConfig
              lda     f:keyboardConfig+2
              and     #$70
              cmp     #$40
              beq     repeatSetupDone
              lda     #1
              sta     f:repeatRestore
              jsr     a:.loword(sendKeyboardConfig)
              bcs     repeatSetupDone
              lda     f:keyboardConfig+2
              and     #$8f
              ora     #$40
              jsr     a:.loword(sendBounded)
repeatSetupDone:
              rts

;;; Send the command and unchanged first two bytes. The caller supplies the
;;; final repeat byte. Carry reports a bounded controller timeout.
sendKeyboardConfig:
              .a8

              lda     #$06
              jsr     a:.loword(sendBounded)
              bcs     configDone
              lda     f:keyboardConfig
              jsr     a:.loword(sendBounded)
              bcs     configDone
              lda     f:keyboardConfig+1
              jsr     a:.loword(sendBounded)
configDone:   rts

restoreFirmwareRepeat:
              .a8

              lda     f:repeatRestore
              beq     repeatRestored
              jsr     a:.loword(sendKeyboardConfig)
              bcs     repeatRestored
              lda     f:keyboardConfig+2
              jsr     a:.loword(sendBounded)
              bcs     repeatRestored
              lda     #0
              sta     f:repeatRestore
repeatRestored:
              rts


;;; ADB address 2 presence is separate from J13 availability. A missing raw
;;; keyboard must not create repeated empty Talks on a mouse-only ADB bus.
probeADB:
              .a8
     lda #$f2
              jsr a:.loword(sendBounded)
              bcs noADBKeyboard
              ldx #16
probeHeader:  jsr a:.loword(readBounded)
              bcs noADBKeyboard
              .a8
              bit #128
              bne probeReply
              dex
              bne probeHeader
              bra noADBKeyboard
probeReply:   and #7
              beq noADBKeyboard
              rep #$20
              and #255
              inc a
              tax
              sep #$20
probeBytes:   jsr a:.loword(readBounded)
              bcs noADBKeyboard
              dex
              bne probeBytes
              rts
noADBKeyboard:
              lda #0
              sta a:.loword(j13AdbPresent)
              lda #$4c
              sta f:captureTalk
              rep #$20
              lda #.loword(withoutRawKeys)
              sta f:captureTalk+1
              sep #$20
              rts

queueLong:
              .a16
    jsr a:.loword(queue)
              rtl
readBoundedLong:
              .a8

              jsr a:.loword(readBounded)
              rtl
updateModifiersLong:
              .a16

              jsr a:.loword(updateModifiers)
              rtl

;;; A=raw transition, X=ring offset. Menu repeats use the merged ownership
;;; too: one keyboard's release cannot stop an arrow held on the other.
J13MenuKey:
              .a16
              phb
              phx
              phy
              phk
              plb
              sta a:.loword(menuRaw)
              lda f:inputRing+2,x
              lsr a
              inc a
              sta a:.loword(menuSource)
              lda a:.loword(menuRaw)
              and #127
              tax
              lda f:keyHeld,x
              and #255
              sta a:.loword(menuWas)
              lda a:.loword(menuRaw)
              bit #128
              bne menuKeyUp
              lda a:.loword(menuWas)
              ora a:.loword(menuSource)
              sep #$20
              sta f:keyHeld,x
              rep #$20
              lda a:.loword(menuWas)
              bne menuKeyIgnored
              bra menuKeyReturn
menuKeyUp:
              .a16
              lda a:.loword(menuSource)
              .a16
              eor #255
              and a:.loword(menuWas)
              sep #$20
              sta f:keyHeld,x
              rep #$20
              and #255
              bne menuKeyIgnored
menuKeyReturn:lda a:.loword(menuRaw)
              bra menuKeyDone
menuKeyIgnored:
              lda #$ffff
menuKeyDone:  ply
              plx
              plb
              rtl
menuRaw:      .word 0
menuWas:      .word 0
menuSource:   .word 0


;;; Menu/game transitions retain observed ordinary identities. The UI resets
;;; its event consumer separately, so gameplay entry verifies those keys and
;;; republishes only switches still down. Menus retire released identities
;;; before accepting another character, without manufacturing row presses.
;;; Caller has IRQs masked, A/X/Y16 and DBR=input bank. No gameplay-frame call.
J13ValidateTracked:
              lda f:j13Matrix
              beq validateReturn
              lda f:knownCount
              bne validateStart
              lda f:j13Mode
              .a16
              cmp #2
              bne validateReturn
              brl validateModifiers
validateReturn:
              rtl
validateStart:
              .a16
              lda #0
              sta f:sampleTimed
              ldy #0
validateSlot: tyx
              lda f:j13Keys,x
              cmp #64
              bcc validateMapped
              brl validateNext
validateMapped:
              tax
              lda f:pumpRows,x
              and #255
              sta f:rowAddress
              .a16
              lda #0
              sta f:rowExpected
              ldx #0
validateMask: lda f:j13Keys,x
              cmp #64
              bcs validateMaskNext
              phx
              tax
              lda f:pumpRows,x
              and #255
              cmp f:rowAddress
              bne validateMaskDone
              lda f:pumpMasks,x
              and #255
              ora f:rowExpected
              sta f:rowExpected
validateMaskDone:
              plx
validateMaskNext:
              inx
              inx
              cpx #6
              bcc validateMask
              ; The fresh ASCII character is already a known physical down,
              ; though ordinaryDown has not installed its identity yet. Include
              ; its bit when checking a shared row. Otherwise Up+new Down makes
              ; Up's row look like an unrelated status byte and forgets Up.
              lda f:validateIncoming
              beq validateExpected
              lda f:newKey
              cmp #64
              bcs validateExpected
              tax
              lda f:pumpRows,x
              and #255
              cmp f:rowAddress
              bne validateExpected
              lda f:pumpMasks,x
              and #255
              ora f:rowExpected
              sta f:rowExpected
validateExpected:
              phy
              lda f:rowAddress
              tax
              sep #$20
              jsl readTransition
              rep #$20
              ply
              bcs validateForget
              and #255
              sta f:rowValue
              .a16
              eor #255
              ora f:rowExpected
              cmp f:rowExpected
              bne validateForget
              tyx
              lda f:j13Keys,x
              tax
              lda f:pumpMasks,x
              and f:rowValue
              and #255
              bne validateForget
              lda f:j13Mode
              .a16
              cmp #2
              bne validateNext
              txa
              ; Rebuild gameplay bindings, without reissuing menu/debug
              ; actions such as the Escape that just closed the menu.
              pha
              lda #.loword(boundBits)    ; contiguous key and action tables
              sec
              sbc #.loword(boundKeys)
              dec a
              dec a
              tax
              pla
validateBound:
              cmp f:boundKeys,x
              bne validateBoundNext
              pha
              lda f:boundBits,x
              beq validateNotGame
              lda f:boundSources,x
              and #2
              beq validateNotGame
              pla
              bra validatePublish
validateNotGame:
              pla
validateBoundNext:
              dex
              dex
              bpl validateBound
              bra validateNext
validatePublish:
              jsl queueLong
              bra validateNext
validateForget:
              tyx
              lda f:j13Keys,x
              ora #128
              jsl queueLong
              lda #NONE
              tyx
              sta f:j13Keys,x
              lda f:knownCount
              dec a
              sta f:knownCount
validateNext: iny
              iny
              cpy #6
              bcs validateModifiers
              brl validateSlot
validateModifiers:
              lda f:j13Mode
              .a16
              cmp #2
              bne validateDone
              ldx #$e8
              sep #$20
              jsl readTransition
              rep #$20
              bcs validateDone
              eor #7
              and #$c7
              sta f:physicalMods
              sta f:nextMods
              .a16
              lda #1
              sta f:physicalValid
              .a16
              lda #0
              sta f:j13Mods
              jsl updateModifiersLong
validateDone: rtl
validateIncoming: .word 0


;;; A8, X16 = a validated MCU address. Finish raw keyboard or mouse
;;; service before issuing $09. Notifications may precede its one-byte reply;
;;; preserve keyboard SRQs for the normal ADB parser instead of consuming
;;; them as row bits. This bounded wait is only used outside gameplay frames.
readTransition:
              .a8

              phx
              rep #$20
              ldy #1024
transitionWait:
              lda f:keyTalk
              ora f:keyPending
              bne transitionCapture
              sep #$20
              lda f:ADBSTATUS
              bit #$a1
              rep #$20
              bne transitionCapture
              plx
              sep #$20
              jsl readMCU
              bcs transitionReturn
              ldx #16
transitionByte:
              cmp #8
              beq transitionSRQ
              cmp #$20
              beq transitionNotification
              cmp #$40
              beq transitionNotification
              clc
transitionReturn:
              rtl
transitionSRQ:
              lda #1
              sta f:keyPending
transitionNotification:
              dex
              beq transitionTimedOut
              jsl readBoundedLong
              bcc transitionByte
              rtl
transitionCapture:
              phy
              phb
              sep #$20
              lda #^input_native
              pha
              plb
              rep #$20
              jsl CaptureInput
              plb
              ply
              dey
              bne transitionWait
              plx
              sep #$20
transitionTimedOut:
              sec
              rtl

;;; Rebuild only when tracked identities change. DBR remains the input bank;
;;; these long-addressed helpers and immutable tables use existing UiExtra.
J13CacheRows:
              .a16
              sta a:.loword(maskGeneration)
              ldx #8
              .a16
              lda #0
cacheRowsClear:
              sta a:.loword(rowMasks),x
              dex
              dex
              bpl cacheRowsClear
              ldy #0
cacheRowKey:  lda a:.loword(j13Keys),y
              cmp #64
              bcs cacheRowNext
              tax
              sep #$20
              lda f:pumpMasks,x
              beq cacheRow8Done
              sta a:.loword(cacheMask)
              lda f:pumpRows,x
              sec
              sbc #$31
              tax
              lda a:.loword(rowMasks),x
              ora a:.loword(cacheMask)
              sta a:.loword(rowMasks),x
cacheRow8Done:
              rep #$20
cacheRowNext: iny
              iny
              cpy #6
              bcc cacheRowKey
              ldx #0
              ldy #0
              sep #$20
cacheList:    lda a:.loword(rowMasks),x
              beq cacheListNext
              sta a:.loword(rowList+1),y
              txa
              clc
              adc #$31
              sta a:.loword(rowList),y
              iny
              iny
cacheListNext:inx
              cpx #10
              bcc cacheList
              rep #$20
              sty a:.loword(rowListSize)
              rtl
