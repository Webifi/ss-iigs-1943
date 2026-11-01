; The 65816 processor status bits. REP clears the given bits, SEP sets them.
P_CARRY         = $01
P_ZERO          = $02
P_IRQ_OFF       = $04           ; set: the CPU ignores IRQ
P_DECIMAL       = $08
P_X8            = $10           ; set: X and Y are 8 bits
P_M8            = $20           ; set: A and memory operations are 8 bits
P_OVERFLOW      = $40
P_NEGATIVE      = $80

; The opcodes that the code writes into its own instructions.
OPCODE_JSR      = $20           ; JSR absolute
OPCODE_JMP      = $4C           ; JMP absolute
OPCODE_RTS      = $60
OPCODE_ADC_IMM  = $69           ; ADC #immediate
OPCODE_BRA      = $80           ; BRA relative
OPCODE_LDA_DP   = $A5           ; LDA direct page
OPCODE_LDA_ABS  = $AD           ; LDA absolute

; Register widths. The sources assemble with .smart, so ca65 follows each
; macro and gives the immediate operands after it the new size.
.macro a8                       ; A and memory: 8 bits
  sep #::P_M8
.endmacro
.macro a16                      ; A and memory: 16 bits
  rep #::P_M8
.endmacro
.macro x16                      ; X and Y: 16 bits
  rep #::P_X8
.endmacro
.macro ax8                      ; A, X and Y: 8 bits
  sep #::P_M8|::P_X8
.endmacro
.macro ax16                     ; A, X and Y: 16 bits
  rep #::P_M8|::P_X8
.endmacro
