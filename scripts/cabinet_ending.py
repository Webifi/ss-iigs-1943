"""One ending tableau and native text panels from original-US data blocks."""

import struct
from roms import load
from playfield import sea_pixel

# (new text, retained prior text, pause after typing, cue at panel start).
# The first two credit roles share a screen; the final thanks retain CAPCOM.
PANELS = [
    ([], [], 60, 0),
    ([0x524D], [], 120, 0x32),
    ([0x52F4], [0x524D], 720, 255),
    ([], [], 324, 0x2F),
    ([0x536B, 0x5443, 0x5381, 0x5456], [], 180, 255),
    ([0x5394, 0x5463], [], 180, 255),
    ([0x53AF, 0x54A2], [], 180, 255),
    ([0x53C7, 0x54B2], [], 180, 255),
    ([0x53DB, 0x54D5], [], 180, 255),
    ([0x53DB, 0x54F8], [], 180, 255),
    ([0x53F4, 0x554C], [], 240, 255),
    ([0x5406], [], 60, 255),
    ([0x5423], [0x5406], 300, 255),
]


def prepare(a, surface=0):
    from cabinet_text import Lettering

    r = load()[0]["maincpu"]
    base = bytearray(sea_pixel(a, 0x2200 + 255 - y, x + 16) for y in range(256) for x in range(256))
    front = bytearray(224 * 256)
    # The ending's tableau is 74 sprite placements, not a captured screen.
    for off in reversed(range(74)):
        x, y, code, attr = r[0x5125 + off * 4 : 0x5129 + off * 4]
        code |= (attr & 224) << 3
        left = x - 16
        top = 240 - y
        tile = a.gfx[3][code]
        for dy in range(16):
            for dx in range(16):
                pen = tile[dx * 16 + 15 - dy]
                if pen:
                    base[(top + dy) * 256 + left + dx] = a.colors[3][(attr & 15) * 16 + pen]
                    front[(top + dy) * 224 + left + dx] = 1
    # Tight rows allow a single DMA of the tableau. The unused 8 KB of the
    # existing surface holds ready masked copies where its static sprites
    # stand in front of the rising flag. The two small actors never cross it.
    base = bytearray(b"".join(base[y * 256 : y * 256 + 224] for y in range(256))).ljust(
        65536, b"\0"
    )
    commands = bytearray()
    first_front_row = 256
    for y in range(256):
        masks = [sum(front[y * 224 + g * 4 + i] << i for i in range(4)) for g in range(20, 36)]
        g = 0
        while g < 16:
            if not masks[g]:
                g += 1
                continue
            end = g + 1
            while end < 16 and masks[end] == masks[g]:
                end += 1
            offset = y * 56 + 20 + g
            first_front_row = min(first_front_row, y)
            commands += struct.pack("<HHBB", (surface + offset) & 65535, offset, end - g, masks[g])
            g = end
    commands += bytes(6)
    assert len(commands) <= 2048, len(commands)
    base[57344 : 57344 + 4 * len(commands) : 4] = commands
    layouts = {}
    timelines = {}
    for n, (pointers, retained, wait, cue) in enumerate(PANELS):
        old = Lettering()
        for p in retained:
            old.text(p)
        text = Lettering(old.layout)
        for p in pointers:
            if p in (0x5381, 0x554C):
                text.wait(6)
            text.text(p)
        layouts[17 + n] = text.layout
        timelines[17 + n] = text.finish(wait)
    return bytes(base), layouts, timelines, 304 - first_front_row
