; The J13 keyboard: the keyboard of the ROM 00 and ROM 01 IIgs, read through
; its microcontroller. A native port of src/iigs/j13.s of the Wolf3D IIgs port
; (SHA-256 1f6f09af9da69e2a3a7bc74eff66eee4c24ad832a06ed8f0a2fe715223f90aaf).
; KBD and KBDSTRB give only the last character and "a key is down", not the
; state of each key. So a new character becomes a key identity (asciiKeys)
; and an INPUT_J13 press event; KBDSTRB gives the release of a single key.
; With more keys held, and only on the known microcontroller ROM
; (j13Matrix), the code reads the switch rows of the held keys from the
; microcontroller RAM (GLU_READ_MEMORY) to find the key that went up, and P3
; (MCU_P3) for the live modifier keys. A row read owns the GLU: the DOC timer
; interrupt sends its bytes (sendAlarm) and the ADB interrupt takes its reply
; (J13Pump). The menus always read the J13 keyboard; the play reads it only
; when the player turns it on.
.a16
.i16
NONE = 255                   ; no key identity (j13Keys, keyAction)
ROMVER_J13_END = 2           ; ROMVER: the J13 keyboard on ROM 00 and 01 only
GLU_WAIT = 16384             ; sendBounded, readBounded: the most status reads
INIT_DRAIN_MAX = 256         ; J13Init: the most old DATAREG bytes to read
MCU_SIGNATURE1 = $18ac       ; the microcontroller ROM: SIGNATURE_PART bytes at
MCU_SIGNATURE2 = $1a10       ; each address must be equal to matrixROM
SIGNATURE_PART = 32
MCU_P3 = $e8                 ; the microcontroller RAM: port 3, the modifier switches
P3_LOW_BITS = KMOD_SHIFT|KMOD_CONTROL|KMOD_CAPS  ; P3: these bits are 0 when down
MCU_ROW_FIRST = $31          ; the microcontroller RAM: the switch rows
MCU_ROWS = 10
MATRIX_KEYS = 64             ; pumpRows, pumpMasks: the identities below this
J13_KEY_SLOTS = 3            ; j13Keys: the most held key identities
QUEUE_ROOM = 10              ; J13Sample: the free events it needs (five
                             ; modifiers, three releases, a release and press)
ROW_WAKES = 2                ; deferRows: the DOC wakes before the row batch
ROW_GAP = 7                  ; GAME_CLOCK ticks from one row batch to the next
ROW_TIMEOUT = 239            ; GAME_CLOCK ticks: a longer batch stops the row reads
RECOVER_WAIT = 7             ; GAME_CLOCK ticks before a lost character is read again
SEND_BUDGET = 16             ; sendAlarm calls for P3 and up to three rows
FINISH_TRIES = 16384         ; finishOwner: J13Pump steps before the row reads stop
TRANSITION_TRIES = 1024      ; readTransition: ADB captures before it stops
NOTICE_MAX = 16              ; the most ADB status bytes before a reply
MODIFIER_KEYS = 5            ; modifierMasks, modifierKeys
NO_FRAME = $ffff             ; rowFrame, rowArmFrame, maskGeneration: not yet
ASCII_ESC = $1b
; j13State: the steps of a row read.
JS_IDLE = 0
JS_ARMED = 1                 ; J13Pump takes the GLU when it is free
JS_ADDRESS = 2               ; GLU_READ_MEMORY went out: next the address
JS_HIGH = 3                  ; next the high byte of the address
JS_REPLY = 4                 ; the reply comes in the ADB interrupt

; J13Init: on a ROM 00/01 machine: empty the GLU, check that it answers,
; probe the ADB keyboard, set the key buffer and stop the firmware key repeat,
; then compare the microcontroller ROM with matrixROM: when equal, the row
; reads work (j13Matrix). JSL; the DBR, D and widths stay.
J13Init:
  php
  sei
  ax16
  phb
  phk
  plb
  a8
  lda f:ROMVER
  cmp #ROMVER_J13_END
  bcs initDone
  lda #1
  sta a:.loword(j13Available)
  ldy #INIT_DRAIN_MAX
@drain:
  lda f:KMSTATUS
  and #KM_DATA_FULL
  beq @modes
  lda f:DATAREG
  dey
  bne @drain
  bra initDone
@modes:
  lda #GLU_READ_MODES            ; the GLU answers
  jsr .loword(sendBounded)
  bcs initDone
  jsr .loword(readBounded)
  bcs initDone
  jsr .loword(probeADB)
  jsr .loword(bufferKeyboard)
  ldx #0
@signature:
  phx
  a16
  txa
  cpx #SIGNATURE_PART
  bcs @second
  clc
  adc #MCU_SIGNATURE1
  bra @address
@second:
  clc
  adc #MCU_SIGNATURE2-SIGNATURE_PART
@address:
  tax
  a8
  jsr .loword(readMCU)
  plx
  bcs initDone
  cmp f:matrixROM,x
  bne initDone
  inx
  cpx #2*SIGNATURE_PART
  bcc @signature
  lda #1
  sta a:.loword(j13Matrix)
initDone:
  ax16
  plb
  plp
  rtl

; J13Prime: empty the key buffer, take the KBDSTRB and KBD state of now as
; known, then J13_MENU. JSL.
J13Prime:
  php
  sei
  ax16
  phb
  phk
  plb
  lda a:.loword(j13Available)
  beq @done
  a8
  lda #GLU_FLUSH_KEYS
  jsr .loword(sendBounded)
  lda f:KBDSTRB
  sta a:.loword(sampleAKD)
  lda f:KBD
  and #<~KBD_STROBE
  sta a:.loword(j13LastAscii)
  a16
  lda #J13_MENU
  sta a:.loword(j13Mode)
@done:
  plb
  plp
  rtl

; J13Menu: setMode with J13_MENU. setMode: j13Mode = A, outside a timed
; frame; an owned read ends first. A change to J13_ESCAPE, or from it,
; forgets the held keys; from J13_MENU to J13_PLAY or back they stay, and
; J13_PLAY checks them (J13ValidateTracked). JSL; A16; all kept.
J13Menu:
  .a16
  lda #J13_MENU
setMode:
  php
  sei
  ax16
  pha
  phx
  phy
  phb
  phk
  plb
  lda a:.loword(j13Available)
  beq @done
  lda 6,s                       ; the new mode, below B, Y and X
  sta a:.loword(j13NextMode)
  jsr .loword(finishOwner)
  stz a:.loword(rowWakeBudget)
  stz a:.loword(j13SendTimer)
  lda a:.loword(j13NextMode)
  beq @clear
  lda a:.loword(j13Mode)
  bne @keep
@clear:
  jsr .loword(clearHeld)
@keep:
  lda a:.loword(j13NextMode)
  sta a:.loword(j13Mode)
  cmp #J13_PLAY
  bne @done
  jsr .loword(J13ValidateTracked)
@done:
  plb
  ply
  plx
  pla
  plp
  rtl

; J13SettingsLoad: j13Enabled, j13Manual and j13MenuSeen from SET_J13. A
; choice by hand counts as a menu use; an untouched default can still turn
; on at the first menu use (menuUsed). JSL; A16.
J13SettingsLoad:
  .a16
  lda f:settings+SET_J13
  and #J13_ON
  and f:j13Available
  sta f:j13Enabled
  lda f:settings+SET_J13
  and #J13_CHOSEN
  sta f:j13Manual
  sta f:j13MenuSeen
  rtl
; J13SettingsStore: SET_J13 from j13Enabled and j13Manual. JSL; A16.
J13SettingsStore:
  lda f:j13Enabled
  ora f:j13Manual
  a8
  sta f:settings+SET_J13
  a16
  rtl

; J13Poll: the J13 work of a sample in a menu or the attract (never in
; J13_PLAY, so no row read): J13_ESCAPE looks only for ESC (escapeSample);
; J13_MENU reads the keys. JSL.
J13Poll:
  php
  sei
  ax16
  phb
  phk
  plb
  lda a:.loword(j13Available)
  beq @done
  lda a:.loword(j13Mode)
  beq @escape
  jsr .loword(J13Sample)
  bra @done
@escape:
  jsr .loword(escapeSample)
@done:
  plb
  plp
  rtl

; J13Frame: the J13 work of a play sample: the keys, the row batch (now or
; after ROW_WAKES DOC wakes) and a service step. JSL; A16.
J13Frame:
  php
  sei
  phb
  phk
  plb
  lda f:GAME_CLOCK
  sta a:.loword(controllerTime)
  jsr .loword(J13Sample)
  jsr .loword(deferRows)
  jsr .loword(serviceController)
  plb
  plp
  rtl
; readControllerClock: A = controllerTime = GAME_CLOCK. JSR; A16.
readControllerClock:
  lda f:GAME_CLOCK
  sta a:.loword(controllerTime)
  rts
; escapeSample: in J13_ESCAPE a new ESC character becomes an ESC press and
; release (the menu opens); it is a menu use too. JSR; A16.
escapeSample:
  a8
  lda f:KBD
  bpl @done
  pha
  lda f:KBDSTRB
  pla
  cmp #ASCII_ESC|KBD_STROBE
  bne @done
  a16
  jsr .loword(queueRoom)
  bcc @done
  jsr .loword(menuUsed)
  stz a:.loword(sampleTimed)
  lda #KEY_ESC
  jsr .loword(queue)
  lda #KEY_ESC|KEY_RELEASE
  jsr .loword(queue)
@done:
  a16
  rts

; j13Irq: the DOC timer interrupt in J13_PLAY: the keys, and at the last of
; the ROW_WAKES wakes of deferRows the row batch. The interrupt entry saved
; all the registers and the DBR. JSR; A16.
j13Irq:
  jsr .loword(J13Sample)
  lda a:.loword(rowWakeBudget)
  beq @done
  dec a:.loword(rowWakeBudget)
  bne @done
  jsr .loword(scheduleRow)
  jsr .loword(J13Pump)
@done:
  rts

; J13Sample: one sample of the J13 keyboard (interrupts off, DBR = this
; bank). It needs QUEUE_ROOM free events, else it waits for the next sample.
; A new character: the modifier changes, then the press of its identity. No
; new character: the modifier changes from KEYMODREG, and when KBDSTRB shows
; no key down the release of the held identities. JSR; A16.
J13Sample:
  .a16
  lda f:inputHead
  cmp f:inputTail
  beq @room
  jsr .loword(queueRoom)
  bcs @room
  rts
@room:
  a8
  lda f:KBD
  ; A character whose strobe a KBDSTRB read cleared too soon: KBD keeps it.
  bmi sampleFresh
  cmp a:.loword(j13LastAscii)
  beq sampleSlowHeld
  .a8
  ora #KBD_STROBE
sampleFresh:
  sta a:.loword(sampleAscii)
  stz a:.loword(sampleRecover)
  .a8
  and #<~KBD_STROBE
  sta a:.loword(j13LastAscii)
  ; The modifiers of the character, before the KBDSTRB read clears it.
  lda f:KEYMODREG
  sta a:.loword(sampleMods)
sampleMetadata:
  lda f:KBDSTRB
  sta a:.loword(sampleAKD)
  jsr .loword(readModifiers)
  stz a:.loword(sampleTimed)
  jmp .loword(sampleModifiers)
sampleSlowHeld:
  ; The same character: is a key still down (KBDSTRB)?
  .a8
  sta a:.loword(sampleAscii)
  ldx a:.loword(sampleAKD)
  lda f:KBDSTRB
  sta a:.loword(sampleAKD)
  bpl sampleUpCheck
  txa
  bmi sampleDownKnown
  ; Down with no new character: the strobe can have raced a KBDSTRB read.
  lda #1
  sta a:.loword(sampleRecover)
  a16
  jsr .loword(readControllerClock)
  clc
  adc #RECOVER_WAIT
  sta a:.loword(recoverTime)
  a8
  bra sampleHeld
sampleDownKnown:
  ldx a:.loword(sampleRecover)
  bne sampleRecovery
sampleHeld:
  ; With a key held, the P3 reads give the live modifiers; no new character
  ; means no work here.
  a16
  lda a:.loword(j13Mode)
  cmp #J13_PLAY
  bne @live
  lda a:.loword(physicalValid)
  beq @live
  rts
@live:
  a8
sampleIdleModifiers:
  .a8
  lda f:KEYMODREG
  ; KBDSTRB can clear before KEYMODREG stops showing the old character;
  ; KMOD_LATCH marks a change of the modifiers alone.
  bit #KMOD_LATCH
  bne @latch
  a16
  jmp .loword(sampleRelease)
@latch:
  stz a:.loword(physicalValid)
  sta a:.loword(sampleMods)
  jsr .loword(readModifiers)
  cmp a:.loword(j13Mods)
  beq @same
  stz a:.loword(sampleTimed)
  jsr .loword(updateModifiers)
@same:
  jmp .loword(sampleRelease)
sampleUpCheck:
  ldx a:.loword(sampleRecover)
  beq sampleIdleModifiers
sampleRecovery:
  ; KBDSTRB can rise before the microcontroller writes the character; a
  ; KBDSTRB read then can clear the later strobe, also for the same
  ; character. After RECOVER_WAIT, read the character when KEYMODREG shows
  ; it (KMOD_LATCH 0), or when the key is up again (the tap is complete).
  a16
  jsr .loword(readControllerClock)
  sec
  sbc a:.loword(recoverTime)
  a8
  bmi sampleHeld
  lda f:KEYMODREG
  bit #KMOD_LATCH
  beq @recovered
  bit a:.loword(sampleAKD)
  bmi sampleHeld
@recovered:
  ; The modifiers first: the microcontroller can write the character
  ; during the KBDSTRB read before.
  and #<~KMOD_REPEAT
  sta a:.loword(sampleMods)
  lda f:KBD
  .a8
  ora #KBD_STROBE
  sta a:.loword(sampleAscii)
  .a8
  and #<~KBD_STROBE
  sta a:.loword(j13LastAscii)
  stz a:.loword(sampleRecover)
  jmp .loword(sampleMetadata)
; readModifiers: A = nextMods = the KMOD_KEYS bits of sampleMods, with the
; Apple keys from BUTN0 and BUTN1. JSR; A8 in, A16 out.
readModifiers:
  lda a:.loword(sampleMods)
  .a8
  and #KMOD_KEYS
  sta a:.loword(nextMods)
  lda f:BUTN0
  bpl @option
  lda a:.loword(nextMods)
  .a8
  ora #KMOD_COMMAND
  sta a:.loword(nextMods)
@option:
  lda f:BUTN1
  bpl @done
  lda a:.loword(nextMods)
  ora #KMOD_OPTION
  sta a:.loword(nextMods)
@done:
  a16
  lda a:.loword(nextMods)
  rts
; sampleModifiers: a new character. In J13_PLAY a firmware repeat
; (KMOD_REPEAT) keeps the modifiers of P3, or of before: KEYMODREG can be
; wrong then. Then the modifier changes, and the character.
sampleModifiers:
  lda a:.loword(j13Mode)
  .a16
  cmp #J13_PLAY
  bne @update
  lda a:.loword(sampleMods)
  bit #KMOD_REPEAT
  beq @update
  lda a:.loword(physicalValid)
  beq @before
  lda a:.loword(physicalMods)
  bra @keep
@before:
  lda a:.loword(j13Mods)
@keep:
  sta a:.loword(nextMods)
@update:
  jsr .loword(updateModifiers)
  bra sampleCharacter
; updateModifiers: an event for each modifier key whose bit is not the same
; in j13Mods and nextMods; then j13Mods = nextMods. JSR; A16.
updateModifiers:
  lda a:.loword(nextMods)
  cmp a:.loword(j13Mods)
  bne @changed
  rts
@changed:
  ldx #0
@modifier:
  lda a:.loword(nextMods)
  eor a:.loword(j13Mods)
  and f:modifierMasks,x
  and #255
  beq @next
  lda a:.loword(nextMods)
  and f:modifierMasks,x
  and #255
  beq @up
  lda f:modifierKeys,x
  and #255
  bra @queue
@up:
  lda f:modifierKeys,x
  and #255
  ora #KEY_RELEASE
@queue:
  jsr .loword(queue)
@next:
  inx
  cpx #MODIFIER_KEYS
  bcc @modifier
  lda a:.loword(nextMods)
  sta a:.loword(j13Mods)
  rts
; sampleCharacter: a new character that is not a firmware repeat: the press
; of its identity (asciiKeys). In J13_MENU the first key is a menu use
; (in the demo only ESC is), and the held keys are checked first. Then
; sampleRelease: no key down (KBDSTRB) releases the held identities.
sampleCharacter:
  lda a:.loword(sampleAscii)
  bit #KBD_STROBE
  beq sampleRelease
  lda a:.loword(sampleMods)
  bit #KMOD_REPEAT              ; a firmware repeat is not a new press
  bne sampleRelease
  lda a:.loword(sampleAscii)
  and #<~KBD_STROBE
  tax
  lda f:asciiKeys,x
  and #255
  cmp #NONE
  beq sampleRelease
  sta a:.loword(newKey)
  lda a:.loword(j13Mode)
  .a16
  cmp #J13_MENU
  bne sampleOrdinary
  lda a:.loword(j13MenuSeen)
  bne sampleMenuOrdinary
  lda f:CAB_DEMO
  beq sampleMenuUsed
  lda a:.loword(newKey)
  cmp #KEY_ESC
  bne sampleMenuOrdinary
sampleMenuUsed:
  jsr .loword(menuUsed)
sampleMenuOrdinary:
  lda #1
  sta a:.loword(validateIncoming)
  jsr .loword(J13ValidateTracked)
  stz a:.loword(validateIncoming)
sampleOrdinary:
  jsr .loword(ordinaryDown)
sampleRelease:
  lda a:.loword(sampleAKD)
  bit #KBD_STROBE               ; KBDSTRB: a key is down
  bne @done
  lda a:.loword(knownCount)
  beq @done
  stz a:.loword(sampleTimed)
  jsr .loword(releaseOrdinary)
@done:
  rts

; menuUsed: the first menu use turns J13 play on (j13MenuSeen). JSR; A16.
menuUsed:
  lda a:.loword(j13MenuSeen)
  bne @done
  .a16
  lda #1
  sta a:.loword(j13MenuSeen)
  sta a:.loword(j13Enabled)     ; J13_ON
@done:
  rts

; ordinaryDown: newKey is pressed. Held already: a release and a press. On
; the known ROM a key with a row takes a free slot of j13Keys (no slot free:
; no event); else it releases all the held keys and takes the first slot.
; JSR; A16.
ordinaryDown:
  inc a:.loword(j13Generation)
  ldx #0
@find:
  lda a:.loword(j13Keys),x
  cmp a:.loword(newKey)
  beq @repress
  inx
  inx
  cpx #2*J13_KEY_SLOTS
  bcc @find
  lda a:.loword(j13Matrix)
  beq @single
  ldx a:.loword(newKey)
  cpx #MATRIX_KEYS
  bcs @single
  lda f:pumpMasks,x
  and #255
  beq @single
  ldx #0
@slot:
  lda a:.loword(j13Keys),x
  cmp #NONE
  beq @install
  inx
  inx
  cpx #2*J13_KEY_SLOTS
  bcc @slot
  rts
@single:
  jsr .loword(releaseOrdinary)
  ldx #0
@install:
  lda a:.loword(newKey)
  sta a:.loword(j13Keys),x
  inc a:.loword(knownCount)
  jmp .loword(queue)
@repress:
  ora #KEY_RELEASE
  jsr .loword(queue)
  lda a:.loword(newKey)
  jmp .loword(queue)
; releaseOrdinary: release all the held identities. JSR; A16.
releaseOrdinary:
  inc a:.loword(j13Generation)
  ldx #0
@key:
  lda a:.loword(j13Keys),x
  cmp #NONE
  beq @next
  ora #KEY_RELEASE
  jsr .loword(queue)
  lda #NONE
  sta a:.loword(j13Keys),x
@next:
  inx
  inx
  cpx #2*J13_KEY_SLOTS
  bcc @key
  stz a:.loword(knownCount)
  rts

; queueRoom: carry 1 when inputRing has QUEUE_ROOM free events. JSR; A16.
queueRoom:
  lda f:inputTail
  sec
  sbc f:inputHead
  dec a
  and #INPUT_RING_SIZE-1
  cmp #QUEUE_ROOM*INPUT_EVENT_SIZE
  rts
; queue: put the J13 key byte A in inputRing (queueRoom gave the room). The
; events of one sample get one time (sampleTimed). JSR; A16; X and Y kept.
queue:
  phx
  phy
  pha
  lda a:.loword(sampleTimed)
  bne @timed
  lda f:GAME_CLOCK
  sta a:.loword(sampleTime)
  inc a:.loword(sampleTimed)
@timed:
  lda f:inputHead
  tax
  lda a:.loword(sampleTime)
  sta f:inputRing+INPUT_TIME,x
  .a16
  lda #INPUT_J13
  sta f:inputRing+INPUT_TYPE,x
  pla
  sta f:inputRing+INPUT_VALUE,x
  .a16
  lda #0
  sta f:inputRing+INPUT_AUX,x
  txa
  clc
  adc #INPUT_EVENT_SIZE
  and #INPUT_RING_SIZE-1
  sta f:inputHead
  ply
  plx
  rts

; deferRows: with two or more held keys the row batch comes once a frame,
; at the last of ROW_WAKES DOC wakes (away from the frame edge: j13Irq). With
; fewer keys (P3 only: KBDSTRB gives the release of one key), or when the
; wakes did not come, it comes now. JSR; A16.
deferRows:
  lda a:.loword(knownCount)
  .a16
  cmp #2
  bcc @now
  lda f:GAME_UPDATES
  cmp a:.loword(rowArmFrame)
  beq @done
  sta a:.loword(rowArmFrame)
  lda a:.loword(rowWakeBudget)
  bne @now
  .a16
  lda #ROW_WAKES
  sta a:.loword(rowWakeBudget)
@done:
  rts
@now:
  stz a:.loword(rowWakeBudget)
  jmp .loword(scheduleRow)

; scheduleRow: in J13_PLAY on the known ROM with a key held, once a frame
; and ROW_GAP ticks after the last batch: arm a batch (JS_ARMED) that reads
; P3, then the rows. scheduleTwoKeys: arm the read of the next row of
; rowList. JSR; A16.
scheduleRow:
  lda f:GAME_UPDATES
  cmp a:.loword(rowFrame)
  beq @return
  lda a:.loword(j13Mode)
  .a16
  cmp #J13_PLAY
  bne @return
  lda a:.loword(j13State)
  bne @return
  lda a:.loword(j13Matrix)
  beq @return
  lda a:.loword(knownCount)
  beq @return
  lda f:GAME_UPDATES
  sta a:.loword(rowFrame)
  lda a:.loword(controllerTime)
  sec
  sbc a:.loword(lastRowTime)
  cmp #ROW_GAP
  bcs @due
@return:
  rts
@due:
  lda a:.loword(controllerTime)
  sta a:.loword(lastRowTime)
  jsr .loword(cacheRows)
  lda a:.loword(rowListSize)
  lsr a
  sta a:.loword(rowsLeft)
  lda #MCU_P3
  sta a:.loword(rowAddress)
  bra scheduleReady
scheduleTwoKeys:
  jsr .loword(cacheRows)
  ldx a:.loword(rowNext)
  inx
  inx
  cpx a:.loword(rowListSize)
  bcc @index
  ldx #0
@index:
  stx a:.loword(rowNext)
  lda a:.loword(rowList),x
  a8
  sta a:.loword(rowAddress)
  xba
  sta a:.loword(rowExpected)
  a16
scheduleReady:
  lda a:.loword(lastRowTime)
  clc
  adc #ROW_TIMEOUT
  sta a:.loword(rowDeadline)
  .a16
  lda #JS_ARMED
  sta a:.loword(j13State)
  rts

; cacheRows: rowMasks and rowList for the held keys, when they changed. JSR;
; A16.
cacheRows:
  lda a:.loword(j13Generation)
  cmp a:.loword(maskGeneration)
  beq @done
  jsr .loword(J13CacheRows)
@done:
  rts

; J13Pump: one step of a row read (from the samples, sendAlarm and the ADB
; interrupt). JS_ARMED: take the GLU when the ADB capture has no work (no
; talk, no byte, no command): the ADB data interrupt off (the mouse one
; stays), CaptureInput off DATAREG, GLU_READ_MEMORY out. Owned: a byte in
; DATAREG goes to pumpData; else the next address byte goes out when the
; GLU is free. JSR; A16.
J13Pump:
  .a16
  lda a:.loword(j13State)
  bne @active
  rts
@active:
  a8
  lda f:KMSTATUS
  sta a:.loword(rowStatus)
  lda a:.loword(j13State)
  cmp #JS_ARMED
  bne pumpOwned
  lda f:keyTalk
  ora f:keyPending
  beq @free
  brl pumpDone
@free:
  lda a:.loword(rowStatus)
  and #KM_MOUSE_FULL|KM_DATA_FULL|KM_COMMAND_FULL
  beq @take
  brl pumpDone
@take:
  lda a:.loword(rowStatus)
  and #KM_MOUSE_IRQ|KM_DATA_IRQ
  sta a:.loword(rowEnables)
  lda a:.loword(rowStatus)
  and #KM_MOUSE_IRQ
  sta f:KMSTATUS
  lda #0                        ; CaptureInput does not read DATAREG
  sta f:captureStatusMask+1
  lda #1
  sta a:.loword(j13Owner)
  sta f:keyTalk                 ; and does not talk to the keyboard
  a16
  jsr .loword(startSendTimer)
  a8
pumpCommand:
  lda #GLU_READ_MEMORY
  sta f:DATAREG
  lda #JS_ADDRESS
  sta a:.loword(j13State)
  a16
  lda a:.loword(j13Generation)
  sta a:.loword(rowGeneration)
  rts
pumpOwned:
  .a8
  lda a:.loword(rowStatus)
  bit #KM_DATA_FULL
  bne pumpData
  lda a:.loword(j13State)
  .a8
  cmp #JS_REPLY
  bne @send
  brl pumpDone
@send:
  lda a:.loword(rowStatus)
  and #KM_COMMAND_FULL
  beq @free
  brl pumpDone
@free:
  lda a:.loword(j13State)
  cmp #JS_ADDRESS
  bne @high
  lda a:.loword(rowAddress)
  sta f:DATAREG
  lda #JS_HIGH
  sta a:.loword(j13State)
  brl pumpDone
@high:
  lda #0                        ; the high byte: RAM page 0
  sta f:DATAREG
  lda #JS_REPLY
  sta a:.loword(j13State)
  lda a:.loword(rowEnables)     ; the data interrupt again, for the reply
  sta f:KMSTATUS
  a16
  brl pumpDone
pumpData:
  .a8
  lda f:DATAREG
  sta a:.loword(rowValue)
  lda a:.loword(j13State)
  .a8
  cmp #JS_REPLY
  bne pumpStatusByte
  lda a:.loword(rowAddress)
  cmp #MCU_P3
  bne @matrix
  lda a:.loword(rowValue)       ; a status byte before the reply?
  cmp #ADB_KEY_REQUEST
  beq pumpStatusByte
  cmp #ADB_STATUS_ESC
  beq pumpStatusByte
  cmp #ADB_STATUS_ERROR
  beq pumpStatusByte
  a16
  brl pumpPhysicalReply
@matrix:
  .a8
  lda a:.loword(rowValue)
  eor #$ff                      ; the switches: 1 = down
  cmp a:.loword(rowExpected)
  bne @changed
  a16
  brl batchReadDone             ; no held key went up
@changed:
  .a8
  ora a:.loword(rowExpected)
  cmp a:.loword(rowExpected)
  beq pumpValidReply            ; no other switch is down: held keys went up
  ; A status byte can come before the one-byte row reply.
  lda a:.loword(rowValue)
  and #ADB_REPLY_FOLLOWS|ADB_REPLY_BITS
  beq pumpStatusByte
  a16
  jsr .loword(releaseOwner)
  brl pumpDone                  ; a row that is not clear: no releases
pumpStatusByte:
  .a8
  lda a:.loword(rowValue)
  and #ADB_REPLY_FOLLOWS|ADB_REPLY_BITS
  bne @done
  lda a:.loword(rowValue)
  and #ADB_KEY_REQUEST          ; a keyboard request waits for the end
  ora a:.loword(rowDeferred)
  sta a:.loword(rowDeferred)
@done:
  a16
  rts
pumpValidReply:
  a16
  jsr .loword(queueRoom)
  bcs @room
  brl pumpFinished
@room:
  lda a:.loword(rowGeneration)
  cmp a:.loword(j13Generation)
  beq @current
  brl pumpFinished              ; a key was pressed after the read started
@current:
  stz a:.loword(sampleTimed)
  ldy #0
rowRelease:
  lda a:.loword(j13Keys),y
  cmp #MATRIX_KEYS
  bcs rowReleaseNext
  tax
  lda f:pumpRows,x
  and #255
  cmp a:.loword(rowAddress)
  bne rowReleaseNext
  lda f:pumpMasks,x
  and a:.loword(rowValue)
  and #255
  beq rowReleaseNext            ; the switch is down
  txa
  ora #KEY_RELEASE
  jsr .loword(queue)
  lda #NONE
  sta a:.loword(j13Keys),y
  dec a:.loword(knownCount)
  inc a:.loword(j13Generation)
rowReleaseNext:
  iny
  iny
  cpy #2*J13_KEY_SLOTS
  bcc rowRelease
batchReadDone:
  dec a:.loword(rowsLeft)
  beq pumpFinished
  jmp .loword(continueHeldRows)
pumpFinished:
  jsr .loword(releaseOwner)
pumpDone:
  a16
  rts

; pumpPhysicalReply: the P3 reply: the live modifiers (KEYMODREG keeps the
; state of its character while other keys stay down), unless a new
; character or a release came after the read started. Then, with two or
; more held keys, the next row read; else the GLU goes back.
pumpPhysicalReply:
  lda a:.loword(knownCount)
  beq physicalReturn
  lda a:.loword(rowGeneration)
  cmp a:.loword(j13Generation)
  bne physicalReturn
  lda a:.loword(rowValue)
  eor #P3_LOW_BITS
  and #KMOD_KEYS
  sta a:.loword(physicalMods)
  sta a:.loword(nextMods)
  .a16
  lda #1
  sta a:.loword(physicalValid)
  lda a:.loword(nextMods)
  cmp a:.loword(j13Mods)
  beq physicalNoRoom
  jsr .loword(queueRoom)
  bcc physicalNoRoom
  stz a:.loword(sampleTimed)
  jsr .loword(updateModifiers)
physicalNoRoom:
continueHeldRows:
  lda a:.loword(knownCount)
  .a16
  cmp #2
  bcc physicalReturn
  jsr .loword(scheduleTwoKeys)
  a8
  lda a:.loword(rowEnables)
  and #KM_MOUSE_IRQ
  sta f:KMSTATUS
  jmp .loword(pumpCommand)
physicalReturn:
  jmp .loword(releaseOwner)

; serviceController: one service step of a play sample: J13Pump; a read that
; waits for its reply after rowDeadline stops the row reads (j13Matrix 0)
; and gives the GLU back. JSR; A16.
serviceController:
  jsr .loword(J13Pump)
  lda a:.loword(j13State)
  .a16
  cmp #JS_REPLY
  bcc serviceDone
  lda a:.loword(controllerTime)
  sec
  sbc a:.loword(rowDeadline)
  bmi serviceDone
serviceTimeout:
  stz a:.loword(j13Matrix)
  jmp .loword(releaseOwner)
serviceDone:
  rts

; releaseOwner: the GLU goes back to the ADB capture: CaptureInput reads
; DATAREG again, a keyboard request seen during the read waits
; (keyPending), the interrupts are as before, JS_IDLE. JSR; returns A16.
releaseOwner:
  a8
  lda #KM_DATA_FULL
  sta f:captureStatusMask+1
  lda #0
  sta f:keyTalk
  sta a:.loword(j13Owner)
  lda a:.loword(rowDeferred)
  beq @none
  lda #1
  sta f:keyPending
@none:
  stz a:.loword(rowDeferred)
  lda a:.loword(rowEnables)
  sta f:KMSTATUS
  a16
  stz a:.loword(j13State)
  stz a:.loword(j13SendTimer)
  rts
; finishOwner: before a mode change an owned read finishes: a half-sent
; GLU_READ_MEMORY would leave its reply to the ADB capture. After
; FINISH_TRIES steps the row reads stop. Then JS_IDLE. JSR; A16.
finishOwner:
  lda a:.loword(j13Owner)
  beq @idle
  ldy #FINISH_TRIES
@wait:
  phy
  jsr .loword(J13Pump)
  ply
  lda a:.loword(j13Owner)
  beq @idle
  dey
  bne @wait
  stz a:.loword(j13Matrix)
  jmp .loword(releaseOwner)
@idle:
  stz a:.loword(j13State)
  rts

; sendAlarm: the DOC timer interrupt while a read owns the GLU
; (j13SendTimer): the next address byte goes out when the GLU is free, or a
; reply byte goes to J13Pump. After SEND_BUDGET calls the read times out. It
; does not sample the keys. JSR; A16.
sendAlarm:
  .a16
  lda a:.loword(j13State)
  .a8
  .a16
  cmp #JS_ADDRESS
  bcc @done
  dec a:.loword(sendBudget)
  beq @timeout
  .a16
  cmp #JS_REPLY
  bcs @done
  a8
  lda f:KMSTATUS
  bit #KM_DATA_FULL
  bne @data
  lsr a                         ; KM_COMMAND_FULL: busy
  bcs @wide
  lda a:.loword(j13State)
  cmp #JS_ADDRESS
  bne @high
  lda a:.loword(rowAddress)
  sta f:DATAREG
  inc a:.loword(j13State)       ; JS_HIGH
  bra @wide
@high:
  lda #0
  sta f:DATAREG
  inc a:.loword(j13State)       ; JS_REPLY
  lda a:.loword(rowEnables)
  sta f:KMSTATUS
@wide:
  a16
@done:
  rts
@timeout:
  jmp .loword(serviceTimeout)
@data:
  a16
  jmp .loword(J13Pump)

; startSendTimer: sendAlarm runs from now, SEND_BUDGET times at most. JSR;
; A16.
startSendTimer:
  lda #SEND_BUDGET
  sta a:.loword(sendBudget)
  .a16
  lda #1
  sta a:.loword(j13SendTimer)
  rts

; clearHeld: forget the held identities and modifiers, keep only the ADB
; bits of keyHeld, and take the KBDSTRB and KBD state of now as known. JSR;
; A16.
clearHeld:
  lda #NONE
  sta a:.loword(j13Keys)
  sta a:.loword(j13Keys+2)
  sta a:.loword(j13Keys+4)
  stz a:.loword(j13Mods)
  stz a:.loword(knownCount)
  stz a:.loword(physicalValid)
  stz a:.loword(sampleRecover)
  inc a:.loword(j13Generation)
  ldx #KEY_CODES-1
  a8
@source:
  lda f:keyHeld,x
  and #HELD_ADB
  sta f:keyHeld,x
  dex
  bpl @source
  lda f:KBDSTRB
  sta a:.loword(sampleAKD)
  lda f:KBD
  .a8
  and #<~KBD_STROBE
  sta a:.loword(j13LastAscii)
  a16
  rts
.assert J13_KEY_SLOTS = 3, error

; The J13 state.
j13Enabled: .word 0             ; J13_ON: the play reads the J13 keyboard
j13AdbPresent: .word 1          ; 1: an ADB keyboard answers (raw keys)
j13Available: .word 0           ; 1: a ROM 00/01 machine
j13Matrix: .word 0              ; 1: the known microcontroller ROM: the row reads work
j13Mode: .word 0                ; J13_ESCAPE, J13_MENU or J13_PLAY
j13NextMode: .word 0            ; setMode: the new mode
j13MenuSeen: .word 0            ; 1: a menu use was seen (or a choice by hand)
j13Manual: .word 0              ; J13_CHOSEN: the menu choice was made by hand
j13Owner: .word 0               ; 1: a row read owns the GLU
j13State: .word 0               ; JS_*
j13SendTimer: .word 0           ; 1: doc_tick runs sendAlarm
sendBudget: .word 0             ; sendAlarm calls left before the read times out
j13Keys: .word NONE,NONE,NONE   ; the held key identities
j13Mods: .word 0                ; the modifier bits (KMOD_KEYS) of the last events
knownCount: .word 0             ; the held identities in j13Keys
controllerTime: .word 0         ; GAME_CLOCK at the service
physicalMods: .word 0           ; the modifier bits of the last P3 read
physicalValid: .word 0          ; 1: physicalMods is newer than KEYMODREG
rowDeadline: .word 0            ; GAME_CLOCK: the read times out after this
nextMods: .word 0               ; updateModifiers: the new modifier bits
newKey: .word 0                 ; the identity of the new character
j13Generation: .word 0          ; changes with each change of j13Keys
rowGeneration: .word 0          ; j13Generation when the read started
rowNext: .word 0                ; scheduleTwoKeys: the rowList offset of the row
rowFrame: .word NO_FRAME        ; scheduleRow: GAME_UPDATES of the last call
rowArmFrame: .word NO_FRAME     ; deferRows: GAME_UPDATES of the last arm
rowWakeBudget: .word 0          ; j13Irq: the DOC wakes left before the batch
maskGeneration: .word NO_FRAME  ; j13Generation of rowMasks and rowList
rowMasks: .byte 0,0,0,0,0,0,0,0,0,0  ; each MCU row: the switch bits of the held keys
rowList: .word 0,0,0            ; the rows to read: the address, then the bits
rowListSize: .word 0            ; the bytes of rowList
cacheMask: .byte 0              ; J13CacheRows: the switch bit
rowsLeft: .word 0               ; the rows of the batch still to read
rowAddress: .word 0             ; the MCU address of the read: MCU_P3 or a row
rowExpected: .word 0            ; the switch bits of the held keys in the row
rowValue: .word 0               ; the reply byte
rowEnables: .word 0             ; the KMSTATUS interrupt bits before the read
rowStatus: .word 0              ; the KMSTATUS byte of this J13Pump step
rowDeferred: .word 0            ; ADB_KEY_REQUEST: the keyboard asked in the read
lastRowTime: .word 0            ; controllerTime of the last batch
sampleAscii: .word 0            ; the KBD byte; KBD_STROBE: a new character
sampleMods: .word 0             ; the KEYMODREG byte of the character
sampleAKD: .word 0              ; the last KBDSTRB byte; KBD_STROBE: a key is down
sampleRecover: .word 0          ; 1: a key went down with no new character
recoverTime: .word 0            ; GAME_CLOCK: the recovery reads after this
j13LastAscii: .word 0           ; the last character (7 bits)
sampleTime: .word 0             ; the time of the events of this sample
sampleTimed: .word 0            ; 1: sampleTime is set for this sample

; sendBounded: write A8 to DATAREG when the GLU command register is free;
; carry 1 after GLU_WAIT busy reads. No delay after the write: a $C05F (Zip
; delay) write is a Second Sight event that would corrupt DMA1. JSR; Y
; changed.
sendBounded:
  .a8
  pha
  ldy #GLU_WAIT
@busy:
  lda f:KMSTATUS
  and #KM_COMMAND_FULL
  beq @free
  dey
  bne @busy
  pla
  sec
  rts
@free:
  pla
  sta f:DATAREG
  clc
  rts
; readBounded: A8 = the next DATAREG byte; carry 1 after GLU_WAIT empty
; reads. JSR; Y changed.
readBounded:
  .a8
  ldy #GLU_WAIT
@empty:
  lda f:KMSTATUS
  and #KM_DATA_FULL
  bne @full
  dey
  bne @empty
  sec
  rts
@full:
  lda f:DATAREG
  clc
  rts

; The modifier keys: their KEYMODREG bits and their key codes.
modifierMasks: .byte KMOD_SHIFT,KMOD_CONTROL,KMOD_CAPS,KMOD_COMMAND,KMOD_OPTION
modifierKeys: .byte KEY_SHIFT,KEY_CONTROL,KEY_CAPS_LOCK,KEY_COMMAND,KEY_OPTION

; asciiKeys: the key identity (an ADB key code) of each 7-bit character. The
; arrow characters win (Ctrl-H is LEFT); a shifted sign is its unshifted US
; key. Keys with the same character look the same. The releases come from
; KBDSTRB or a row read.
asciiKeys:
  .byte $31,$00,$0b,$08,$02,$0e,$03,$05,$3b,$30,$3d,$3e,$25,$24,$2d,$1f  ; $00-$0F
  .byte $23,$0c,$0f,$01,$11,$3c,$09,$0d,$07,$10,$06,$35,$2a,$1e,$16,$1b  ; $10-$1F
  .byte $31,$12,$27,$14,$15,$17,$1a,$27,$19,$1d,$1c,$18,$2b,$1b,$2f,$2c  ; $20-$2F
  .byte $1d,$12,$13,$14,$15,$17,$16,$1a,$1c,$19,$29,$29,$2b,$18,$2f,$2c  ; $30-$3F
  .byte $13,$00,$0b,$08,$02,$0e,$03,$05,$04,$22,$26,$28,$25,$2e,$2d,$1f  ; $40-$4F
  .byte $23,$0c,$0f,$01,$11,$20,$09,$0d,$07,$10,$06,$21,$2a,$1e,$16,$1b  ; $50-$5F
  .byte $32,$00,$0b,$08,$02,$0e,$03,$05,$04,$22,$26,$28,$25,$2e,$2d,$1f  ; $60-$6F
  .byte $23,$0c,$0f,$01,$11,$20,$09,$0d,$07,$10,$06,$21,$2a,$1e,$32,$33  ; $70-$7F

; readMCU: A8 = the microcontroller byte at X (GLU_READ_MEMORY); carry 1
; when the GLU does not answer. JSR.
readMCU:
  .a8
  lda #GLU_READ_MEMORY
  jsr .loword(sendBounded)
  bcs @done
  txa
  jsr .loword(sendBounded)
  bcs @done
  a16
  txa
  xba
  a8
  jsr .loword(sendBounded)
  bcs @done
  jsr .loword(readBounded)
@done:
  rts

; matrixROM: the microcontroller ROM bytes of the known ROM: SIGNATURE_PART
; at MCU_SIGNATURE1 (the scanner), then SIGNATURE_PART at MCU_SIGNATURE2
; (the row update).
matrixROM:
  .byte $3c,$ff,$e4,$a2,$09,$22,$59,$3c,$0a,$48,$c6,$48,$30,$5b,$a5,$48,$aa,$8b,$85,$e4,$b5,$31,$45,$e2,$3c,$ff,$e4,$f0,$ed,$a0,$08,$88
  .byte $22,$b4,$f7,$4c,$05,$15,$31,$95,$31,$60,$8f,$0a,$e7,$0f,$06,$49,$ff,$35,$31,$95,$31,$22,$c5,$33,$1c,$f3,$1a,$a6,$4c,$e0,$37,$f0

; pumpRows, pumpMasks: for each key identity below MATRIX_KEYS, its row in
; the microcontroller RAM and its switch bit there (0 = down). Row $FF and
; bit 0: no row. The keys of one row share one read (rowList).
pumpRows:
  .byte $31,$33,$32,$35,$34,$36,$31,$32,$33,$34,$ff,$35,$32,$33,$34,$35
  .byte $36,$37,$32,$33,$34,$35,$36,$37,$38,$3a,$38,$3a,$39,$39,$3a,$3a
  .byte $38,$39,$39,$38,$37,$3a,$37,$3a,$38,$39,$37,$38,$3a,$36,$37,$39
  .byte $31,$39,$37,$37,$ff,$31,$ff,$ff,$ff,$ff,$ff,$39,$3a,$38,$38,$ff
pumpMasks:
  .byte $04,$04,$04,$04,$04,$04,$08,$08,$08,$08,$00,$08,$02,$02,$02,$02
  .byte $02,$02,$01,$01,$01,$01,$01,$01,$10,$01,$01,$10,$01,$10,$20,$02
  .byte $02,$20,$02,$20,$40,$04,$04,$40,$04,$04,$10,$08,$08,$08,$08,$08
  .byte $02,$40,$20,$80,$00,$01,$00,$00,$00,$00,$00,$80,$80,$80,$40,$00

; bufferKeyboard: set the GLU_KEY_BUFFER mode bit, then stop the firmware
; key repeat. JSR; A8.
bufferKeyboard:
  .a8
  lda #GLU_READ_MODES
  jsr .loword(sendBounded)
  bcs @done
  jsr .loword(readBounded)
  bcs @done
  and #GLU_KEY_BUFFER
  bne @done
  lda #GLU_SET_MODES
  jsr .loword(sendBounded)
  bcs @done
  lda #GLU_KEY_BUFFER
  jsr .loword(sendBounded)
@done:
  jmp .loword(stopFirmwareRepeat)

keyboardConfig: .res ::CONFIG_BYTES,0  ; the configuration bytes of the microcontroller
; stopFirmwareRepeat: read the configuration bytes; when the repeat delay is
; not CONFIG_NO_REPEAT, write them back with it. JSR; A8.
stopFirmwareRepeat:
  .a8
  lda #GLU_READ_CONFIG
  jsr .loword(sendBounded)
  bcs @done
  ldx #0
@read:
  jsr .loword(readBounded)
  bcs @done
  sta f:keyboardConfig,x
  inx
  cpx #CONFIG_BYTES
  bcc @read
  lda f:keyboardConfig+2
  and #CONFIG_DELAY
  cmp #CONFIG_NO_REPEAT
  beq @done
  jsr .loword(sendKeyboardConfig)
  bcs @done
  lda f:keyboardConfig+2
  and #<~CONFIG_DELAY
  ora #CONFIG_NO_REPEAT
  jsr .loword(sendBounded)
@done:
  rts

; sendKeyboardConfig: GLU_SET_CONFIG and the first two configuration bytes
; as they are; stopFirmwareRepeat sends the third. Carry 1: the GLU does not
; answer. JSR; A8.
sendKeyboardConfig:
  .a8
  lda #GLU_SET_CONFIG
  jsr .loword(sendBounded)
  bcs @done
  lda f:keyboardConfig
  jsr .loword(sendBounded)
  bcs @done
  lda f:keyboardConfig+1
  jsr .loword(sendBounded)
@done:
  rts

; probeADB: Talk register 3 of the ADB keyboard. No keyboard (no reply, or
; a one-byte reply): j13AdbPresent 0, and CaptureInput never talks to the
; keyboard (captureTalk becomes JMP withoutRawKeys), so a bus with only a
; mouse gets no empty talks. JSR; A8.
probeADB:
  .a8
  lda #GLU_TALK+3*ADB_REGISTER+ADB_KEYBOARD
  jsr .loword(sendBounded)
  bcs noADBKeyboard
  ldx #NOTICE_MAX
@header:
  jsr .loword(readBounded)
  bcs noADBKeyboard
  .a8
  bit #ADB_REPLY_FOLLOWS
  bne @reply
  dex
  bne @header
  bra noADBKeyboard
@reply:
  and #ADB_REPLY_BITS
  beq noADBKeyboard
  a16
  and #255
  inc a                         ; the reply bytes
  tax
  a8
@bytes:
  jsr .loword(readBounded)
  bcs noADBKeyboard
  dex
  bne @bytes
  rts
noADBKeyboard:
  lda #0
  sta a:.loword(j13AdbPresent)
  lda #OPCODE_JMP
  sta f:captureTalk
  a16
  lda #.loword(withoutRawKeys)
  sta f:captureTalk+1
  a8
  rts

; J13ValidateTracked: at a mode change, and before a new character in
; J13_MENU: read the row of each held identity (readTransition); a key that
; is up is released. In J13_PLAY a key still down is pressed again when a
; J13 binding gives it game bits (not a menu action: the ESC that closed the
; menu); then P3 gives the modifiers. Not in a play frame. JSR; A16;
; interrupts off; DBR = this bank.
J13ValidateTracked:
  .a16
  lda a:.loword(j13Matrix)
  beq @return
  lda a:.loword(knownCount)
  bne validateStart
  lda a:.loword(j13Mode)
  cmp #J13_PLAY
  bne @return
  brl validateModifiers
@return:
  rts
validateStart:
  stz a:.loword(sampleTimed)
  ldy #0
validateSlot:
  tyx
  lda a:.loword(j13Keys),x
  cmp #MATRIX_KEYS
  bcc @mapped
  brl validateNext
@mapped:
  ; rowExpected: the switch bits of all the held keys in this row.
  tax
  lda f:pumpRows,x
  and #255
  sta a:.loword(rowAddress)
  stz a:.loword(rowExpected)
  ldx #0
validateMask:
  lda a:.loword(j13Keys),x
  cmp #MATRIX_KEYS
  bcs @next
  phx
  tax
  lda f:pumpRows,x
  and #255
  cmp a:.loword(rowAddress)
  bne @done
  lda f:pumpMasks,x
  and #255
  ora a:.loword(rowExpected)
  sta a:.loword(rowExpected)
@done:
  plx
@next:
  inx
  inx
  cpx #2*J13_KEY_SLOTS
  bcc validateMask
  ; The new character is a key that is down already, though ordinaryDown has
  ; not put it in j13Keys yet. Its bit counts in a shared row; else UP and a
  ; new DOWN make the row of UP look like a status byte, and UP is lost.
  lda a:.loword(validateIncoming)
  beq validateExpected
  lda a:.loword(newKey)
  cmp #MATRIX_KEYS
  bcs validateExpected
  tax
  lda f:pumpRows,x
  and #255
  cmp a:.loword(rowAddress)
  bne validateExpected
  lda f:pumpMasks,x
  and #255
  ora a:.loword(rowExpected)
  sta a:.loword(rowExpected)
validateExpected:
  phy
  lda a:.loword(rowAddress)
  tax
  a8
  jsr .loword(readTransition)
  a16
  ply
  bcs validateForget
  and #255
  sta a:.loword(rowValue)
  eor #255
  ora a:.loword(rowExpected)
  cmp a:.loword(rowExpected)
  bne validateForget            ; an unknown switch is down: the row is not clear
  tyx
  lda a:.loword(j13Keys),x
  tax
  lda f:pumpMasks,x
  and a:.loword(rowValue)
  and #255
  bne validateForget            ; the key is up
  lda a:.loword(j13Mode)
  cmp #J13_PLAY
  bne validateNext
  txa
  ldx #BIND_COUNT*2-2
validateBound:
  cmp a:.loword(boundKeys),x
  bne validateBoundNext
  pha
  lda a:.loword(boundBits),x
  beq validateNotGame
  lda a:.loword(boundSources),x
  and #SOURCE_J13
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
  jsr .loword(queue)
  bra validateNext
validateForget:
  tyx
  lda a:.loword(j13Keys),x
  ora #KEY_RELEASE
  jsr .loword(queue)
  lda #NONE
  tyx
  sta a:.loword(j13Keys),x
  dec a:.loword(knownCount)
validateNext:
  iny
  iny
  cpy #2*J13_KEY_SLOTS
  bcs validateModifiers
  brl validateSlot
validateModifiers:
  lda a:.loword(j13Mode)
  cmp #J13_PLAY
  bne @done
  ldx #MCU_P3
  a8
  jsr .loword(readTransition)
  a16
  bcs @done
  eor #P3_LOW_BITS
  and #KMOD_KEYS
  sta a:.loword(physicalMods)
  sta a:.loword(nextMods)
  lda #1
  sta a:.loword(physicalValid)
  stz a:.loword(j13Mods)
  jsr .loword(updateModifiers)
@done:
  rts
validateIncoming: .word 0       ; 1: J13ValidateTracked counts newKey as held

; readTransition: A8 = the microcontroller byte at X, outside a play frame.
; First the ADB capture runs while it has work (TRANSITION_TRIES times at
; most). The status bytes before the reply are skipped; a keyboard request
; among them waits (keyPending). Carry 1: no reply. JSR; A8; DBR = this
; bank.
readTransition:
  .a8
  phx
  a16
  ldy #TRANSITION_TRIES
@wait:
  lda a:.loword(keyTalk)
  ora a:.loword(keyPending)
  bne @capture
  a8
  lda f:KMSTATUS
  bit #KM_MOUSE_FULL|KM_DATA_FULL|KM_COMMAND_FULL
  a16
  bne @capture
  plx
  a8
  jsr .loword(readMCU)
  bcs @return
  ldx #NOTICE_MAX
@byte:
  cmp #ADB_KEY_REQUEST
  beq @request
  cmp #ADB_STATUS_ESC
  beq @notice
  cmp #ADB_STATUS_ERROR
  beq @notice
  clc
@return:
  rts
@request:
  lda #1
  sta a:.loword(keyPending)
@notice:
  dex
  beq @timeout
  jsr .loword(readBounded)
  bcc @byte
  rts
@capture:
  phy
  jsl CaptureInput
  ply
  dey
  bne @wait
  plx
  a8
@timeout:
  sec
  rts

; J13CacheRows: rowMasks = the switch bits of the held keys in each row;
; rowList = the rows that have bits (the address, then the bits);
; maskGeneration = A. JSR; A16.
J13CacheRows:
  .a16
  sta a:.loword(maskGeneration)
  ldx #MCU_ROWS-2
  .a16
  lda #0
@clear:
  sta a:.loword(rowMasks),x
  dex
  dex
  bpl @clear
  ldy #0
@key:
  lda a:.loword(j13Keys),y
  cmp #MATRIX_KEYS
  bcs @next
  tax
  a8
  lda f:pumpMasks,x
  beq @none
  sta a:.loword(cacheMask)
  lda f:pumpRows,x
  sec
  sbc #MCU_ROW_FIRST
  tax
  lda a:.loword(rowMasks),x
  ora a:.loword(cacheMask)
  sta a:.loword(rowMasks),x
@none:
  a16
@next:
  iny
  iny
  cpy #2*J13_KEY_SLOTS
  bcc @key
  ldx #0
  ldy #0
  a8
@list:
  lda a:.loword(rowMasks),x
  beq @empty
  sta a:.loword(rowList+1),y
  txa
  clc
  adc #MCU_ROW_FIRST
  sta a:.loword(rowList),y
  iny
  iny
@empty:
  inx
  cpx #MCU_ROWS
  bcc @list
  a16
  sty a:.loword(rowListSize)
  rts
