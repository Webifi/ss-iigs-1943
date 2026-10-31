"""Use one native movement controller on either live player record."""

import re
from arcade import ROOT


def fields(text):
    lines = []
    for line in text.splitlines():
        code, sep, comment = line.partition(";")
        if not code.lstrip().startswith("."):
            code = re.sub(r"(?<= )\$[0-9a-fA-F]{2}(?=\s*$|,)", lambda m: "a:" + m[0], code)

        def field(m):
            off = int(m[1][1:], 16) if m[1] and m[1].startswith("$") else int(m[1] or 0)
            return f"z:${off:02x}"

        code = re.sub(r"\bPLAYER(?:\+(\$[0-9a-fA-F]+|[0-9]+))?\b", field, code)
        lines.append(code + (sep + comment if sep else ""))
    return "\n".join(lines)


def wrapper(name, far):
    return f"""{name}:
  phd
  rep #$20
  lda PLAYER_CURSOR
  clc
  adc #PLAYER
  tcd
  sep #$20
  jsr {".loword(" if far else ""}live_{name}{")" if far else ""}
  pld
  {"rtl" if far else "rts"}
"""


def prepare(out):
    flight = (ROOT / "src/flight.s").read_text()
    head, body = flight.split("flight_step:", 1)
    body = fields("flight_step:" + body).replace("flight_step:", "live_flight_step:", 1)
    (out / "live_flight.inc").write_text(head + "\n" + wrapper("flight_step", False) + body + "\n")
    core = (ROOT / "src/player_core.s").read_text()
    head, body = core.split("player_live_before:", 1)
    body = fields("player_live_before:" + body)
    for name in ("player_live_before", "player_live_after", "player_live_palette"):
        body = body.replace(name + ":", "live_" + name + ":", 1)
    body = body.replace("  rtl", "  rts")
    body = body.replace(
        "@ordinary:\n  sta PLAYER_PALETTE",
        """@ordinary:
  pha
  lda z:$05
  asl
  sta PLAYER_PALETTE
  pla
  ora PLAYER_PALETTE
  sta PLAYER_PALETTE""",
    )
    body = body.replace(
        "  sta ENERGY_HUD,x",
        """  pha
  lda z:$05
  beq :+
  rep #$20
  txa
  clc
  adc #28
  tax
  sep #$20
:
  pla
  sta ENERGY_HUD,x""",
    )
    (out / "live_player_core.inc").write_text(
        head
        + "\n"
        + "".join(
            wrapper(n, True)
            for n in ("player_live_before", "player_live_after", "player_live_palette")
        )
        + body
        + "\n"
    )
    launch = (ROOT / "src/launch_flow.s").read_text()
    head, body = launch.split("native_player_presentation:", 1)
    body = (
        fields("native_player_presentation:" + body)
        .replace("native_player_presentation:", "live_native_player_presentation:", 1)
        .replace("  rtl", "  rts")
    )
    # The launch control applies visibility to both active aircraft.
    head = head.replace(
        "  stz STAGE_BANNER_TASK\n@done:",
        """  lda PLAYER+$81
  and #$ef
  sta PLAYER+$81
  sta PLAYER+$a1
  stz STAGE_BANNER_TASK
@done:""",
    )
    (out / "live_launch.inc").write_text(
        head + wrapper("native_player_presentation", True) + body + "\n"
    )
