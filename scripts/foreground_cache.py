"""Foreground rows from the ROM tile map, with all four horizontal alignments."""


class ForegroundCache:
    def __init__(self, a):
        self.a = a
        self.rows = {}

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
