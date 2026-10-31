"""Display timing data and validation; counts are real CRTC characters/lines.

The picture is always 224x256, stored unchained. Horizontal counts are in
8-dot characters; vertical counts are output scan lines. The blank interval
and sync pulse do not wrap in these absolute coordinates. The sync and blank
ends are exclusive, even though the Oak end registers hold only low bits.
"""

from dataclasses import dataclass

# Only clock-select values already accounted for by the card code. Entries 6
# and E are the same 40 MHz source; offer it once, not a fictitious PLL.
CLOCKS = ((0, 25_175_000), (1, 28_322_000), (5, 36_000_000), (6, 40_000_000), (12, 63_000_000))


@dataclass(frozen=True)
class Timing:
    htotal: int
    hblank_start: int
    hblank_end: int
    hsync_start: int
    hsync_end: int
    vtotal: int
    vblank_start: int
    vblank_end: int
    vsync_start: int
    vsync_end: int
    clock: int
    polarity: int


# Factory defaults.
DEFAULT_VGA = Timing(131, 78, 109, 85, 101, 640, 512, 640, 574, 578, 6, 3)
DEFAULT_RGB = Timing(152, 78, 130, 98, 110, 280, 256, 280, 259, 263, 6, 3)


class InvalidTiming(ValueError):
    pass


def validate(t, rgb):
    def need(ok, why):
        if not ok:
            raise InvalidTiming(why)

    visible = 256 if rgb else 512
    need(t.clock in dict(CLOCKS), "clock is not a populated Oak clock select")
    need(0 <= t.polarity <= 3, "polarity")
    need(not rgb or t.polarity == 3, "RGB uses composite negative TTL sync")
    need(61 <= t.htotal <= 260, "horizontal total")
    need(
        56 <= t.hblank_start < min(t.hblank_end, 256) and t.hblank_end <= t.htotal,
        "horizontal blank interval",
    )
    need(t.hblank_end - t.hblank_start <= 63, "Oak horizontal blank width")
    need(
        t.hblank_start <= t.hsync_start < min(t.hsync_end, 256) and t.hsync_end <= t.hblank_end,
        "horizontal sync interval",
    )
    need(t.hsync_end - t.hsync_start <= 31, "Oak horizontal sync width")
    need(visible + 2 <= t.vtotal <= 1025, "vertical total")
    need(
        visible <= t.vblank_start < min(t.vblank_end, 1024) and t.vblank_end <= t.vtotal,
        "vertical blank interval",
    )
    need(t.vblank_end - t.vblank_start <= 255, "Oak vertical blank width")
    need(
        t.vblank_start <= t.vsync_start < min(t.vsync_end, 1024) and t.vsync_end <= t.vblank_end,
        "vertical sync interval",
    )
    need(t.vsync_end - t.vsync_start <= 15, "Oak vertical sync width")
    return t


def encode(t, rgb):
    """Return CRTC values for the writable table, retaining full picture."""
    validate(t, rgb)
    vt = t.vtotal - 2
    vd = (256 if rgb else 512) - 1
    vb = t.vblank_start
    vs = t.vsync_start
    overflow = (
        ((vt >> 8) & 1)
        | (((vd >> 8) & 1) << 1)
        | (((vs >> 8) & 1) << 2)
        | (((vb >> 8) & 1) << 3)
        | 0x10
        | (((vt >> 9) & 1) << 5)
        | (((vd >> 9) & 1) << 6)
        | (((vs >> 9) & 1) << 7)
    )
    return {
        0: (t.htotal - 5) & 255,
        2: t.hblank_start,
        3: 0x80 | (t.hblank_end & 31),
        4: t.hsync_start,
        5: (t.hsync_end & 31) | ((t.hblank_end & 32) << 2),
        6: vt & 255,
        7: overflow,
        9: (0 if rgb else 0x80) | 0x40 | (((vb >> 9) & 1) << 5),
        0x10: vs & 255,
        0x11: 0x30 | (t.vsync_end & 15),
        0x15: vb & 255,
        0x16: (t.vblank_end - 1) & 255,
    }
