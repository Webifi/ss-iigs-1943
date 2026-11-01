"""Decode the arcade ROM graphics, tile maps and palettes for the build."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class Arcade:
    def __init__(self):
        from roms import load

        regions, _ = load("1943ua")
        region = lambda name: regions[name]
        self.prom = region("proms")
        self.maps = region("tilerom")
        self.palette = bytes(
            sum(
                weight * ((self.prom[c * 256 + i] >> bit) & 1)
                for bit, weight in enumerate((14, 31, 67, 143))
            )
            for i in range(256)
            for c in range(3)
        )
        self.gfx = []
        for name, size in [("gfx1", 8), ("gfx2", 32), ("gfx3", 32), ("gfx4", 16)]:
            data = region(name)
            half = len(data) * 4
            planes = [4, 0] if size == 8 else [half + 4, half, 4, 0]
            stride = {8: 128, 16: 512, 32: 2048}[size]
            count = len(data) * 8 // stride // (1 if size == 8 else 2)
            pixels = []
            for code in range(count):
                tile = bytearray()
                for y in range(size):
                    for x in range(size):
                        off = (
                            code * stride + y * 16 + (x // 8) * 16 * size + (x % 8 // 4) * 8 + x % 4
                        )
                        tile.append(
                            sum(
                                ((data[(off + p) // 8] >> (7 - (off + p) % 8)) & 1)
                                << (len(planes) - 1 - i)
                                for i, p in enumerate(planes)
                            )
                        )
                pixels.append(bytes(tile))
            self.gfx.append(pixels)
        self.colors = []
        self.colors.append(bytes((self.prom[0x300 + i] & 15) | 0x40 for i in range(128)))
        for base in (0x400, 0x600):
            self.colors.append(
                bytes(
                    ((self.prom[base + 0x100 + i] & 3) << 4) | (self.prom[base + i] & 15)
                    for i in range(256)
                )
            )
        self.colors.append(
            bytes(
                0x80 | ((self.prom[0x900 + i] & 7) << 4) | (self.prom[0x800 + i] & 15)
                for i in range(256)
            )
        )
