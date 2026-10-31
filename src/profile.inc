; Optional elapsed-time markers. Preserve A, index widths, flags and DBR.
; All bytes disappear from ordinary builds.
.ifndef ROUTINE_PROFILE_MACROS
ROUTINE_PROFILE_MACROS = 1
.macro routine_mark address
.ifdef ROUTINE_PROFILE
 .ifdef PRODUCTION_WORLD_REUSE
  .assert address < $050480, error, "routine marker overlaps production status-gap data"
 .endif
  .if .asize = 16
  php
  sep #$20
  pha
  lda $68
  sta f:address
  pla
  plp
  .a16
  .else
  php
  sep #$20
  pha
  lda $68
  sta f:address
  pla
  plp
  .a8
  .endif
.endif
.endmacro
.macro routine_call target, number
  routine_mark $050440+number*2
  jsr target
  routine_mark $050441+number*2
.endmacro
.macro routine_long target, number
  routine_mark $050440+number*2
  jsl target
  routine_mark $050441+number*2
.endmacro
.endif
