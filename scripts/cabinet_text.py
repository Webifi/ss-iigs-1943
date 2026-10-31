"""Prepare lettering order and delays; the host only advances ready segments."""

import struct
from roms import load


class Lettering:
    def __init__(self, retained=()):
        self.layout = list(retained)
        self.initial = len(self.layout)
        self.segments = []
        self.delay = 0
        self.line_cue = False

    def wait(self, frames):
        self.delay += frames
        return self

    def add(self, cells, *, sound=True, instant=False):
        self.layout.extend(cells)
        assert len(self.layout) < 255
        flags = (1 if sound else 0) | (2 if instant else 0) | (128 if self.line_cue else 0)
        self.segments.append((len(self.layout), self.delay, flags))
        self.delay = 0
        self.line_cue = False
        return self

    def text(self, pointer, *, instant=False):
        r = load()[0]["maincpu"]
        dest, width, height, color = struct.unpack_from("<HBBB", r, pointer)
        p = pointer + 5
        spaces = 0
        for row in range(height):
            cells = []
            for col in range(width):
                if spaces:
                    code = 0x24
                    spaces -= 1
                else:
                    code = r[p]
                    p += 1
                    if code == 255 and not color & 224:
                        spaces = r[p]
                        p += 1
                        code = 0x24
                        if spaces:
                            spaces -= 1
                if code not in (0x24, 0xFE):
                    cells.append(
                        (dest - 0xD000 - row + 32 * col, code | ((color & 224) << 3), color & 31)
                    )
            self.add(cells, sound=not instant, instant=instant)
            if code == 0xFE and not instant:
                self.delay += 12
                self.line_cue = True
        return self

    def field(self, address, index, *, wait=3):
        self.add([(address - 0xD000, -index - 1, 0)], sound=False, instant=True)
        self.wait(wait)
        return self

    def finish(self, hold=0):
        parts = self.segments + [(255, self.delay + hold, 128 if self.line_cue else 0)]
        return bytes((self.initial,)) + b"".join(struct.pack("<BHB", *part) for part in parts)
