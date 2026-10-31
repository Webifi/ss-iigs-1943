"""Circular foreground source cache, with all four horizontal alignments.

The cache is source art, never the displayed page. It preserves independent
foreground scrolling. New rows are prepared from ROM data during the build;
the game uploads only rows exposed by the next camera step.
"""


class ForegroundCache:
    def __init__(self, a, pool, initial_scroll, phases=range(4), allocate=True):
        self.a = a
        self.previous = initial_scroll
        self.rows = {}
        self.base = [None] * 4
        self.phases = tuple(sorted(set(phases)))
        assert self.phases and all(0 <= p < 4 for p in self.phases)
        if not allocate:
            self.base = [0] * 4
            return

    def row(self, world, phase):
        key = (world & 65535, phase)
        if key not in self.rows:
            pixels = bytearray()
            for x in range(256):
                wy = (x + phase) & 255
                offset = 2 * (((world >> 5) & 2047) * 8 + (wy >> 5))
                code, attr = self.a.maps[offset : offset + 2]
                code = (code | ((attr & 1) << 8)) % len(self.a.gfx[1])
                tx = world & 31
                ty = wy & 31
                pen = self.a.gfx[1][code][ty * 32 + tx]
                pixels.append(self.a.colors[1][((attr >> 2) & 15) * 16 + pen])
            self.rows[key] = bytes(pixels)
        return self.rows[key]
