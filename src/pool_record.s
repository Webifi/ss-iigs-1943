; The pool routines (enemy_motion.s to bullet_intercept.s) read the fields of
; one object record (src/records.inc) through D. The pool loops
; (wave_combat.s, bullet_loop.s) point D at the selected record and keep its
; address in POOL_RECORD. Code outside the loops calls a *_direct entry,
; which selects the record in POOL_RECORD first.
.a8
.i16

; enemy_bullet_spawn_direct: enemy_bullet_spawn for the record POOL_RECORD.
; JSR; D kept.
enemy_bullet_spawn_direct:
  phd
  a16
  lda POOL_RECORD
  tcd
  a8
  jsr enemy_bullet_spawn
  pld
  rts
; ground_bullet_spawn_direct: ground_bullet_spawn for the record POOL_RECORD.
; JSR; D kept.
ground_bullet_spawn_direct:
  phd
  a16
  lda POOL_RECORD
  tcd
  a8
  jsr ground_bullet_spawn
  pld
  rts
