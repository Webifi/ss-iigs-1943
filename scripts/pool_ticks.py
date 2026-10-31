"""Compile the existing native tick routines to operate on their pool record.

D addresses the selected 32-byte record. Original scratch stays in bank-zero
absolute RAM.
"""

import re
from arcade import ROOT


SOURCES = (
    "enemy_motion",
    "bullet_motion",
    "enemy_script",
    "enemy_ai",
    "medium_ai",
    "ship_ai",
    "formation_ai",
    "formation_extra",
    "ground_ai",
    "ground_bullet",
    "enemy_collision",
    "enemy_bullets",
    "bullet_contact",
    "bullet_intercept",
)
ENTRY = (
    "enemy_motion",
    "bullet_motion",
    "enemy_script",
    "enemy_ai",
    "enemy_shot_collision",
    "enemy_bullet_spawn",
    "ground_bullet_spawn",
    "ground_bullet_ai",
    "bullet_contact",
    "bullet_intercept",
)


def script_reader(text):
    """Use DBR for one prepared movement record, with no per-field calls.

    D still selects the enemy. IRQ entry saves both D and DBR. Every exit
    restores DBR before accessing bank-zero callers or resolving a jump.
    """
    bank_read = "  lda f:enemy_script_pages+2,x\n  adc #0\n"
    assert text.count(bank_read) == 1
    text = text.replace(
        bank_read,
        ".ifdef ENEMY_SCRIPT_FAST_BANK\n  lda #ENEMY_SCRIPT_FAST_BANK\n.else\n"
        + bank_read
        + ".endif\n",
    )
    begin = text.index("  sta a:$da\n")
    return (
        text[:begin]
        + """  ldx a:$d8
  phb
  pha
  plb
  lda a:$0000,x
  beq @callback
  cmp #$ff
  beq @jump
  cmp #$fe
  beq @retire
  sta z:$04
  rep #$20
  lda f:$0000d2
  sta z:$1e
  lda z:$00
  and #$1000
  sta f:$0000dc
  lda a:$0001,x
  ora f:$0000dc
  sta z:$00
  lda a:$0003,x
  xba
  sta z:$18
  lda a:$0005,x
  xba
  sta z:$1a
  plb
  sep #$20
  rts
@jump:
  rep #$20
  lda a:$0001,x
  plb
  sta z:$1e
  sta a:$d2
  jmp @record
@callback:
.a8
  rep #$20
  lda a:$0001,x
  plb
  sta ENEMY_CALLBACK
  sep #$20
  lda #2
  sta ENEMY_SCRIPT_KIND
  rts
@retire:
.a8
  plb
.ifdef ENEMY_SPECIAL_CONTACT
  lda z:$02
  sta ENEMY_RETIRE_X
.endif
  stz z:$00
  stz z:$08
  stz z:$02
  lda #1
  sta ENEMY_SCRIPT_KIND
  rts
"""
    )


def prepare(out):
    texts = {name: (ROOT / "src" / f"{name}.s").read_text() for name in SOURCES}
    labels = {
        label for text in texts.values() for label in re.findall(r"^([a-z][a-z_0-9]*):", text, re.M)
    }
    result = [
        "; Generated direct-record native ticks. Pool loop owns D.",
        "POOL_RECORD = $11de",
        "MEDIUM_TARGET = dp_ai_target_far",
        "SHIP_TARGET = dp_ai_target_far",
        "FORMATION_TARGET = dp_ai_target_far",
        "GROUND_TARGET = dp_ai_target_far",
        ".a8",
        ".i16",
    ]
    # Profile markers must read the update counter, not record+D+$68.
    profile = (ROOT / "src/profile.inc").read_text()
    profile = profile.replace("ROUTINE_PROFILE_MACROS", "POOL_PROFILE_MACROS")
    profile = (
        profile.replace("routine_mark", "pool_mark")
        .replace("routine_call", "pool_call")
        .replace("routine_long", "pool_long")
    )
    result.append(profile.replace("lda $68", "lda a:$68"))
    for text in texts.values():
        first = next(x for x in text.splitlines() if re.match(r"^[a-z].*:$", x))
        result.append(text[: text.index(first)])
    # Unused single-record callers still link. Live pool callers use wrappers.
    for name in ENTRY:
        if name.startswith("ground_"):
            result.append(".ifdef EXTENDED_STAGE_ENEMIES")
        if name not in ("ground_bullet_spawn", "enemy_bullet_spawn"):
            result.append(".if !FLIGHT_WAVES")
        result.append(f"{name} = {name}_direct")
        if name not in ("ground_bullet_spawn", "enemy_bullet_spawn"):
            result.append(".endif")
        if name.startswith("ground_"):
            result.append(".endif")
    result.append("energy_hud_update = dp_energy_hud_update")
    for entry in ENTRY:
        if entry.startswith("ground_"):
            result.append(".ifdef EXTENDED_STAGE_ENEMIES")
        if entry not in ("ground_bullet_spawn", "enemy_bullet_spawn"):
            result.append(".if !FLIGHT_WAVES")
        result += [
            f"{entry}_direct:",
            "  phd",
            "  rep #$20",
            "  lda POOL_RECORD",
            "  tcd",
            "  sep #$20",
            f"  {'jsl' if entry == 'ground_bullet_ai' else 'jsr'} dp_{entry}",
            "  pld",
            "  rts",
        ]
        if entry not in ("ground_bullet_spawn", "enemy_bullet_spawn"):
            result.append(".endif")
        if entry.startswith("ground_"):
            result.append(".endif")
    for name, text in texts.items():
        # The declarations belong to the original source, included separately.
        text = text[text.index(next(x for x in text.splitlines() if re.match(r"^[a-z].*:$", x))) :]
        for label in sorted(labels, key=len, reverse=True):
            text = re.sub(r"\b" + label + r"\b", "dp_" + label, text)
        lines = []
        for line in text.splitlines():
            code, sep, comment = line.partition(";")
            # Only numeric, non-immediate direct-page scratch operands change.
            if not code.lstrip().startswith("."):
                code = re.sub(r"(?<= )\$(?:[0-9a-fA-F]{2})(?=\s*$|,)", lambda m: "a:" + m[0], code)

            def field(m):
                offset = int(m[1][1:], 16) if m[1] and m[1].startswith("$") else int(m[1] or "0")
                assert 0 <= offset < 32
                return f"z:${offset:02x}"

            code = re.sub(r"\bENEMY(?:\+(\$[0-9a-fA-F]+|[0-9]+))?\b", field, code)
            lines.append(code + (sep + comment if sep else ""))
        text = ".a8\n.i16\n" + "\n".join(lines)
        if name == "enemy_motion":
            # Add the fraction and integer bytes directly in the existing
            # big-endian record. Preserve the result on retirement.
            before = """  rep #$20
  lda z:$18
  xba
  sta a:$d0
  lda z:$05
  and #255
  sta a:$d2
  lda z:$02
  and #255
  xba
  ora a:$d2
  clc
  adc a:$d0
  cmp #$f800
  bcc @x_inside
  sep #$20
  jmp dp_enemy_retire
@x_inside:
  sep #$20
  sta z:$05
  xba
  sta z:$02"""
            after = """  clc
  lda z:$05
  adc z:$19
  sta a:$d2
  lda z:$02
  adc z:$18
  cmp #$f8
  bcc @x_inside
  jmp dp_enemy_retire
@x_inside:
  sta z:$02
  lda a:$d2
  sta z:$05"""
            assert text.count(before) == 1
            text = text.replace(before, after)
            before = """  rep #$20
  lda z:$1a
  xba
  sta a:$d0
  lda z:$06
  and #255
  sta a:$d2
  lda z:$03
  and #255
  xba
  ora a:$d2
  clc
  adc a:$d0
  sep #$20
  sta z:$06
  xba
  sta z:$03"""
            after = """  clc
  lda z:$06
  adc z:$1b
  sta z:$06
  lda z:$03
  adc z:$1a
  sta z:$03"""
            assert text.count(before) == 1
            text = text.replace(before, after)
        if name == "enemy_script":
            text = script_reader(text)
        assert not re.search(r"\[\$|\(\$", text), name
        if name in ("medium_ai", "ship_ai", "formation_ai", "formation_extra", "ground_ai"):
            text = (
                (
                    ".ifdef EXTENDED_STAGE_ENEMIES\n"
                    if name.startswith("ground_")
                    else ".ifdef SHIP_ENEMIES\n"
                    if name == "ship_ai"
                    else ".ifdef ALL_STAGE_ENEMIES\n"
                )
                + '.segment "GAMEPLAY"\n'
                + text
                + '\n.segment "NATIVE"\n.endif'
            )
        if name == "ground_bullet":
            text = ".ifdef EXTENDED_STAGE_ENEMIES\n" + text + "\n.endif"
        result.append(text)
    # Fast path for a camera-attached wave record with no camera movement.
    # The ordinary path retains all retirement and signed-coordinate checks.
    result.append("""dp_stationary_wave_motion:
  lda z:$09
  and #4
  beq @ordinary
  lda ENEMY_CAM_X
  ora ENEMY_CAM_Y
  bne @ordinary
  stz ENEMY_RETIRED
  stz z:$18
  stz z:$19
  lda z:$05
  sta a:$d2
  lda z:$02
  cmp #$f8
  bcs @retire
  stz z:$1a
  stz z:$1b
  lda z:$01
  and #$10
  beq @inside
  lda z:$03
  beq @inside
  cmp #$f0
  bcc @retire
@inside:
  dec z:$04
  rts
@ordinary:
  jmp dp_enemy_motion
@retire:
  jmp dp_enemy_retire
""")
    (out / "pool_ticks.inc").write_text("\n".join(result) + "\n")
    for name, pool, slot in (
        ("wave_combat", "ENEMY_POOL", "WAVE_SLOT"),
        ("bullet_loop", "BULLETS", "BULLET_SLOT"),
    ):
        text = (ROOT / "src" / f"{name}.s").read_text()
        # Discard the earlier movement-only shortcut, including its diagnostic
        # refresh. Every active tick now uses its record, including callbacks.
        lines = []
        depth = 0
        for line in text.splitlines():
            if line.strip() == ".ifdef POOL_MOTION":
                assert depth == 0
                depth = 1
                continue
            if depth:
                if line.lstrip().startswith((".if ", ".ifdef ", ".ifndef ")):
                    depth += 1
                if line.strip() == ".endif":
                    depth -= 1
                continue
            lines.append(line)
        text = "\n".join(lines)
        copyin = f"""  rep #$20
  .repeat 16,I
    lda {pool}+I*2,x
    sta ENEMY+I*2
  .endrepeat
  sep #$20"""
        assert text.count(copyin) == 1
        text = text.replace(
            copyin,
            f"""  rep #$20
  txa
  clc
  adc #{pool}
  sta POOL_RECORD
  tcd
  sep #$20""",
        )
        copyout = f"""  rep #$20
  ldx {slot}
  .repeat 16,I
    lda ENEMY+I*2
    sta {pool}+I*2,x
  .endrepeat"""
        assert text.count(copyout) == 1
        text = text.replace(copyout, "")
        text = text.replace(f"  stz {slot}\n", f"  stz {slot}\n  stz $ec\n")
        # The scratch record is for debugging. Refresh once
        # per pool pass, never once per object or routine.
        marker = "@done:\n  sep #$20"
        assert text.count(marker) == 1
        text = text.replace(
            marker,
            """@done:
  rep #$20
.a16
  ; D still identifies the last live record; zero means no record selected.
  ; On an empty pass leave X at the last slot, as the original loop did.
  tdc
  beq :+
  tax
  lda #0
  tcd
.ifndef CONTINUOUS_GAME
  ; A debug build reads this scratch copy. The continuous game reads the
  ; live records.
  .repeat 16,I
    lda a:I*2,x
    sta ENEMY+I*2
  .endrepeat
.endif
:
  sep #$20""",
        )
        # Do not rewrite the final compatibility copy or wave_records output.
        head, tail = text.split("@done:\n", 1)
        # Inactive slots never select D. Active paths restore D at @next;
        # the caller and the final diagnostic copy keep their D=0 contract.
        head = head.replace("  jmp @next\n@active:", "  jmp @next_zero\n@active:")
        head = head.replace("@next:\n", "@next:\n@next_zero:\n")
        rewritten = []
        for line in head.splitlines():
            code, sep, comment = line.partition(";")
            if not code.lstrip().startswith("."):
                code = re.sub(r"(?<= )\$(?:[0-9a-fA-F]{2})(?=\s*$|,)", lambda m: "a:" + m[0], code)
            code = re.sub(r"\bENEMY(?:\+(\$[0-9a-fA-F]+|[0-9]+))?\b", field, code)
            line = code + (sep + comment if sep else "")
            call = re.match(r"\s*(routine_call|jsr) (\w+)(.*)", line)
            if call and call[2] in ENTRY:
                op = "pool_call" if call[1] == "routine_call" else "jsr"
                if call[2] == "ground_bullet_ai":
                    op = "jsl"
                line = f"  {op} dp_{call[2]}{call[3]}"
            elif call and call[2] in (
                "flight_enemy_killed",
                "flight_enemy_retire",
                "flight_enemy_retired",
                "flight_body_contacts",
                "doc_play_hit",
                "score_add",
                "doc_play_player_hurt",
                "doc_play_player_death",
            ):
                # These bridges use bank-zero scratch, unlike generated ticks.
                # PEA/PLD leaves A and carry alone; PLD restores the enemy D.
                rewritten += ["  phd", "  pea $0000", "  pld", line, "  pld"]
                continue
            rewritten.append(line)
        text = "\n".join(rewritten) + "\n@done:\n" + tail
        script_call = "@script:\n  pool_call dp_enemy_script, 20"
        assert text.count(script_call) == 1
        text = text.replace(
            script_call,
            """@script:
  lda z:$04
  beq @script_decode
  stz ENEMY_SCRIPT_KIND
  ; Motion clears ENEMY_RETIRED, which aliases ENEMY_CALLBACK low byte.
  stz ENEMY_CALLBACK+1
  jmp @move
@script_decode:
  pool_call dp_enemy_script, 20""",
        )
        for entry in ENTRY:
            text = re.sub(r"(?<=call )" + entry + r"\b", entry + "_direct", text)
            text = re.sub(r"(?<=jsr )" + entry + r"\b", entry + "_direct", text)
        if name == "wave_combat":
            before = "  pool_call dp_enemy_motion, 22"
            assert text.count(before) == 1
            text = text.replace(before, "  pool_call dp_stationary_wave_motion, 22")
            # The body-contact bridge returns without an effect when this bit
            # is clear. The selected record is already in direct page here.
            before = "@body_contact:\n  phd\n  pea $0000\n  pld\n  jsr flight_body_contacts"
            after = "@body_contact:\n  lda z:$09\n  and #1\n  beq @save\n  phd\n  pea $0000\n  pld\n  jsr flight_body_contacts"
            assert text.count(before) == 1
            text = text.replace(before, after)
        if name == "bullet_loop":
            # Added fast-path instructions put the retirement target out of
            # short-branch range in the ordinary build.
            before = ".else\n  beq @retired\n.endif"
            after = ".else\n  bne :+\n  jmp @retired\n:\n.endif"
            assert text.count(before) == 1
            text = text.replace(before, after)
            # The high byte of the existing 16-bit active-count scratch is
            # cleared at entry and never otherwise read. IRQs use D=$1e00.
            before = "  stz a:$e8\n@slot:"
            after = """  stz a:$e8
  sep #$20
  lda PLAYER+$51
  ora PLAYER+$d1
  and #2
  sta a:$e9
  rep #$20
@slot:"""
            assert text.count(before) == 1
            text = text.replace(before, after)
            before = "  jsr dp_bullet_intercept\n  bcc @body_contact"
            after = """  ; Without the shot flag or either intercept weapon, the
  ; interceptor cannot hit; retain its cleared sound output.
  lda z:$09
  and #2
  ora a:$e9
  bne :+
  stz INTERCEPT_SOUND
  ; The original miss leaves Y at the upper player-slot boundary.
  ldy #9*32
  lda PLAYER+$88
  cmp #2
  bne @body_contact
  ldy #18*32
  bra @body_contact
:
  jsr dp_bullet_intercept
  bcc @body_contact"""
            assert text.count(before) == 1
            text = text.replace(before, after)
            before = "  sep #$20\n  lda $e8\n  cmp BULLET_MAX_ACTIVE"
            after = "  sep #$20\n  stz $e9\n  lda $e8\n  cmp BULLET_MAX_ACTIVE"
            assert text.count(before) == 1
            text = text.replace(before, after)
        (out / f"{name}_direct.inc").write_text(
            profile.replace("lda $68", "lda a:$68") + "\n" + text + "\n"
        )
