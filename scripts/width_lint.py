"""Flag branch targets whose assembled width differs from the width at a branch source:
an immediate operand assembled for the other width, or a return (rts/rtl) reached
with a width that differs from the fall-through path. Resolves :+ and :- targets.
Tracks ca65 .smart state in source order: rep/sep #$20/$10/$30, .a8/.a16/.i8/.i16;
.else starts from the state at its .if."""

import re, sys, glob, collections

ACC_IMM = re.compile(r"^(lda|adc|sbc|and|ora|eor|cmp|bit)\s+#", re.I)
IDX_IMM = re.compile(r"^(ldx|ldy|cpx|cpy)\s+#", re.I)
BR = re.compile(
    r"^(b(ra|eq|ne|cc|cs|mi|pl|vc|vs)|brl|jmp)\s+(\.loword\()?([@\w:+\-]+)\)?\s*$", re.I
)


def lint(path):
    lines = open(path, errors="ignore").read().split("\n")
    m = x = None
    labels = {}
    anon = []
    sources = collections.defaultdict(list)
    out = []
    scope = ""
    stmts = []
    cond = []
    for i, l in enumerate(lines):
        s = l.split(";")[0].strip()
        if not s:
            continue
        lab = re.match(r"^(@?[A-Za-z_]\w*|):\s*(.*)$", s)
        if lab and not s.startswith("."):
            name = lab.group(1)
            if name == "":
                anon.append(i)
                stmts.append(("label", i, ("anon", len(anon) - 1), None))
            else:
                if not name.startswith("@"):
                    scope = name
                key = (scope + name) if name.startswith("@") else name
                stmts.append(("label", i, key, None))
                labels[key] = None
            s = lab.group(2).strip()
            if not s:
                continue
        d = s.lower().split()[0]
        if d.startswith(".if"):
            cond.append((m, x))
        elif d in (".else", ".elseif") and cond:
            m, x = cond[-1]
        elif d == ".endif" and cond:
            cond.pop()
        r = re.match(r"^(rep|sep)\s+#\$?([0-9a-f]+)", s, re.I)
        if r:
            v = int(r.group(2), 16)
            val = 16 if r.group(1).lower() == "rep" else 8
            if v & 0x20:
                m = val
            if v & 0x10:
                x = val
        if s.lower() in (".a8", ".a16"):
            m = 8 if s.lower() == ".a8" else 16
        if s.lower() in (".i8", ".i16"):
            x = 8 if s.lower() == ".i8" else 16
        if s.lower().startswith((".proc", ".endproc", ".macro", ".endmacro")):
            pass
        b = BR.match(s)
        if b:
            t = b.group(4)
            if re.fullmatch(r":\++", t):
                key = ("anon", len(anon) + len(t) - 2)
            elif re.fullmatch(r":-+", t):
                key = ("anon", len(anon) - len(t) + 1)
            else:
                key = (scope + t) if t.startswith("@") else t
            stmts.append(("branch", i, key, (m, x)))
        stmts.append(("state", i, None, (m, x)))
    # width at each label = state of the first statement after it
    width_at = {}
    for k, (kind, i, key, st) in enumerate(stmts):
        if kind == "label":
            nxt = next((s for s in stmts[k + 1 :] if s[0] == "state"), None)
            width_at[key] = (nxt[3] if nxt else (None, None), i)
    for kind, i, key, st in stmts:
        if kind == "branch" and key in width_at:
            (lm, lx), li = width_at[key]
            sm, sx = st
            # find first width-dependent instruction after the label
            for j in range(li + 1, min(li + 8, len(lines))):
                s = lines[j].split(";")[0].strip()
                if not s or s.startswith(".") and s.lower() not in (".a8", ".a16", ".i8", ".i16"):
                    continue
                if s.lower() in (".a8", ".a16", ".i8", ".i16"):
                    break
                if ACC_IMM.match(s) and sm and lm and sm != lm:
                    out.append(
                        f'{path}:{j + 1}: "{s}" assembled {lm}-bit A, reached from line {i + 1} with {sm}-bit A'
                    )
                if IDX_IMM.match(s) and sx and lx and sx != lx:
                    out.append(
                        f'{path}:{j + 1}: "{s}" assembled {lx}-bit X, reached from line {i + 1} with {sx}-bit X'
                    )
                if re.match(r"^(rtl|rts)\b", s, re.I):
                    if sm and lm and sm != lm:
                        out.append(
                            f'{path}:{j + 1}: "{s}" returns with {sm}-bit A when reached from line {i + 1}; the fall-through path has {lm}-bit A'
                        )
                    if sx and lx and sx != lx:
                        out.append(
                            f'{path}:{j + 1}: "{s}" returns with {sx}-bit X when reached from line {i + 1}; the fall-through path has {lx}-bit X'
                        )
                    break
                if re.match(r"^(rep|sep|php|plp|jmp|jsr|jsl|bra)", s, re.I):
                    break
    return out


res = [r for f in sorted(glob.glob(sys.argv[1] + "/*.s")) for r in lint(f)]
print("\n".join(sorted(set(res))) or "none found")
