"""Allocate the display editor entirely inside tracked INPUT bank padding."""

from modes import mode_data
from display_timing import DEFAULT_VGA, DEFAULT_RGB, CLOCKS, encode
from dataclasses import astuple
from fractions import Fraction
import json
from pathlib import Path
from display_timing import Timing, validate


def install(host, mode):
    profiles = [mode_data(n, "unchained") for n in ("vga-224x256-roomy", "rgb-224x256-276")]
    records = [p["register_records"] for p in profiles]
    assert all(len(r) == len(records[0]) for r in records)
    assert all(
        [(a[0], a[1]) for a in r[1:]] == [(a[0], a[1]) for a in records[0][1:]] for r in records
    )

    def indexed(port, index):
        hits = [
            i
            for i in range(len(records[0]) - 1)
            if records[0][i][1:] == (port, index) and records[0][i + 1][1] == port + 1
        ]
        assert len(hits) == (2 if port == 0x3D4 and index == 0x11 else 1), (port, index, hits)
        return 4 * (hits[-1] + 1) + 3

    misc = [i for i, r in enumerate(records[0]) if r[1] == 0x3C2 and r[0] == 0]
    assert len(misc) == 1
    lines = [
        f"DISPLAY_MODE = $0F0000 + card_{mode['register_table_label']}",
        "DISPLAY_FIRST = $0F0000 + card_first_raster_threshold",
        "DISPLAY_HALF = $0F0000 + card_half_raster_threshold",
        f"DISPLAY_N = {len(records[0])}",
        f"DISPLAY_MISC = {4 * misc[0] + 3}",
        f"DISPLAY_CLOCK = {indexed(0x3DE, 6)}",
    ]
    lines += [
        f"DISPLAY_CRTC_{i:02X} = {indexed(0x3D4, i)}"
        for i in (0, 2, 3, 4, 5, 6, 7, 9, 0x10, 0x11, 0x15, 0x16)
    ]
    lines += ["display_profiles:"]
    for p, t, r in zip(profiles, (DEFAULT_VGA, DEFAULT_RGB), records):
        expected = encode(t, p["rgb"])
        assert all(p["crtc"][k] == v for k, v in expected.items()), (p["rgb"], expected, p["crtc"])
        lines += ["  .byte " + ",".join(str(x[2]) for x in r)]
    presets = json.loads(Path(__file__).with_name("display_presets.json").read_text())

    def timing(q):
        return Timing(
            q["h_total"] // 8,
            q["h_blank_start"] // 8,
            q["h_blank_end"] // 8,
            q["h_sync_start"] // 8,
            q["h_sync_end"] // 8,
            q["v_total"],
            q["v_blank_start"],
            q["v_blank_end"] + 1,
            q["v_sync_start"],
            q["v_sync_end"],
            q["clock_select"],
            (not q["hsync_positive"]) + 2 * (not q["vsync_positive"]),
        )

    byid = {q["id"]: q for q in presets}
    for q, t in ((byid["vga-arcade"], DEFAULT_VGA), (byid["rgb-default"], DEFAULT_RGB)):
        assert timing(q) == t, (q["id"], timing(q), t)
    lines += ["display_defaults:"]
    for name in (
        "vga-arcade",
        "vga-800-near",
        "vga-800-standard",
        "vga-arcade",
        "rgb-default",
        "rgb-arcade",
        "rgb-50",
        "rgb-default",
        "rgb-nominal",
    ):
        q = byid[name]
        t = timing(q)
        validate(t, q["rgb"])
        lines += ["  .word " + ",".join(map(str, astuple(t)))]
    lines += ["display_clock_select:", "  .byte " + ",".join(str(x[0]) for x in CLOCKS)]
    # Q32 DOC ticks per horizontal-character/vertical-line pair. The menu
    # multiplies this by the validated totals; game updates only accumulate.
    lines += ["display_rate_coefficients:"]
    for rgb in (False, True):
        for _, hz in CLOCKS:
            value = round(Fraction(500000 * (2 if rgb else 1) * (1 << 32), 131 * hz))
            lines += [f"  .dword {value}"]

    lines += ["display_thresholds:"]
    for p in profiles:
        clocks = dict(CLOCKS)
        div = (2 if p["rgb"] else 1) * (1)
        ticks = round(900000 * p["total"] * p["htotal"] * div / clocks[p["clock"]])
        lines += [f"  .word {65535 if p['rgb'] else 65535 - ticks},{65535 - ticks // 2}"]
    (host.out / "display-control.inc").write_text("\n".join(lines) + "\n")
    host.display_code_size = 0xF00
    host.display_code_source = host.blob_at_padding_or_bank(bytes(host.display_code_size))
    host.routines += [
        '.segment "DISPLAY"',
        '.include "display_control.s"',
        '.segment "SPECIAL"',
        '.include "display_game_clock.s"',
        '.segment "NATIVE"',
    ]
