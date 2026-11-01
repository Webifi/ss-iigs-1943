; weapon_timer: the time limit of the selected weapon (US arcade $1762-$1818).
; Every WEAPON_DIVIDER updates PL_WEAPON_TIME goes down by one; the weapon
; ends on the step after 0 (the arcade's borrow). WEAPON_ENDLESS never ends.
; The card draws the weapon name and the time from the packet.
; In: Y = the player record offset (0 or PLAYER_SIZE). A8, X16. A: changed.
.a8
.i16
weapon_timer:
  phd
  a16
  tya
  clc
  adc #PLAYER
  tcd
  a8
  lda PL_WEAPON
  beq @done                     ; the standard guns have no time
  inc PL_WEAPON_DIVIDER
  lda PL_WEAPON_DIVIDER
  cmp #WEAPON_DIVIDER
  bcc @done
  stz PL_WEAPON_DIVIDER
  lda PL_WEAPON_TIME
  cmp #WEAPON_ENDLESS
  beq @done
  sec
  sbc #1
  sta PL_WEAPON_TIME
  bcs @done                     ; no borrow: time is left
  stz PL_WEAPON                 ; the standard guns again
  stz PL_WEAPON_DIVIDER
@done:
  pld
  rtl
