"""Incremental unchained renderer.

Pixel assets contain only decoded ROM art; the Z180 executes
restores, masked rectangles, opaque rectangles, sea updates and page flips.
"""

from dataclasses import dataclass



@dataclass
class Art:
    address: int
    width: int
    size: int
    pixels: bytes
    masks: list
    high: list


class ArtPool:
    """The art and the other video RAM data of the build. Each part is a
    section that scripts/secondsight_fit.py places in the free video RAM."""

    def __init__(self, a):
        from asset_source import VideoRam

        self.a = a
        self.items = {}
        self.vram = VideoRam()
        self.cpu_window = 0x4000
        # Free video RAM (linear addresses) for the placed sections.
        self.free = [
            [0x5C000, 0x80000],
            [0x80000, 0x100000],
            [0x1C000, 0x20000],
            [0x3C000, 0x40000],
        ]

    def allocate(self, data):
        """A video RAM section of DATA inside one window of cpu_window groups."""
        return self.vram.add(data, self.cpu_window)

    def runtime(self, data, window=None, load=True, name=None):
        """A run-time area of the video RAM map: the host or the card writes it
        while the game runs, and the build data holds its address. It gets the
        first free place now that stays inside one window of WINDOW groups
        (or, when larger, one 64K-group segment). DATA (bytes, or a size) is
        its content at boot; without LOAD nothing loads it. NAME is its label
        for the Second Sight code. Returns the group address."""
        size = data if isinstance(data, int) else len(data)
        window = 4 * (window or self.cpu_window)
        boundary = window if size <= window else 0x10000
        for slot in self.free:
            lo, hi = slot
            before = lo
            if (lo & (boundary - 1)) + size > boundary:
                lo = (lo + boundary - 1) & ~(boundary - 1)
            if lo + size <= hi:
                if lo > before:
                    self.free.append([before, lo])
                slot[0] = lo + size
                content = bytearray(data if not isinstance(data, int) else size)
                self.vram.pin(name or f"vram_area_{lo:05X}", lo, content if load else size)
                return lo // 4
        raise ValueError(("no free video RAM for a run-time area", size, self.free))

    def replace(self, address, data):
        """Write DATA at linear ADDRESS into the boot content of run-time areas."""
        covered = 0
        for start, content in self.vram.pins.values():
            if isinstance(content, int):
                continue
            lo = max(start, address)
            hi = min(start + len(content), address + len(data))
            if lo < hi:
                content[lo - start : hi - start] = data[lo - address : hi - address]
                covered += hi - lo
        assert covered == len(data), ("missing run-time area", hex(address), len(data), covered)

    def replace_plane(self, group, plane, data):
        """Write DATA into one plane from group address GROUP of a run-time area."""
        address = group * 4 + plane
        for start, content in self.vram.pins.values():
            if not isinstance(content, int) and start <= address and address + 4 * len(data) <= start + len(content) + 3:
                at = address - start
                content[at : at + 4 * len(data) : 4] = data
                return
        raise AssertionError(("missing run-time area", hex(address), len(data)))

    def install(self):
        """Give the free video RAM to the allocator and the sections to the
        final link."""
        import secondsight_link
        from secondsight_link import asset_later

        secondsight_link.free_vram = lambda: [(lo, hi) for lo, hi in self.free if lo < hi]
        asset_later("vram", self.vram.source)

    def get(self, cmd):
        layer, gfx, code, color, flip, x, y = cmd
        key = (gfx, code % len(self.a.gfx[gfx]), color, flip)
        # Every used tile/sprite is prepared at all four horizontal alignments.
        if (*key, 0) not in self.items:
            size = (8, 32, 32, 16)[gfx]
            tile = self.a.gfx[gfx][key[1]]
            phases = (0,)
            if len(phases) == 1:
                assert y % 4 == 0, "Fixed HUD glyph must be group-aligned"
            for phase in phases:
                width = (phase + size + 3) // 4
                pixels = bytearray()
                masks = []
                high = []
                for yy in range(size):
                    row = []
                    hirow = []
                    for gx in range(width):
                        opaque = hi = 0
                        for lane in range(4):
                            xx = gx * 4 + lane - phase
                            v = 0
                            if 0 <= xx < size:
                                ox, oy = size - 1 - yy, xx
                                pen = tile[oy * size + ox]
                                index = color * (4) + pen
                                v = self.a.colors[gfx][index]
                                on = pen != 0
                                opaque |= int(on) << lane
                                hi |= (
                                    int(on and gfx == 3 and not (self.a.prom[0x900 + index] & 8))
                                    << lane
                                )
                            pixels.append(v)
                        row.append(opaque)
                        hirow.append(hi)
                    masks.append(row)
                    high.append(hirow)
                # Only immutable art shares storage. Dynamic foreground caches
                # still call allocate directly and always get independent RAM.
                occupied = [i for i, row in enumerate(masks) if any(row)]
                first, last = (occupied[0], occupied[-1] + 1) if occupied else (0, 0)
                data = bytes(pixels[first * width * 4 : last * width * 4])
                from asset_source import Vram

                # A descriptor reads the occupied rows through one 8 KB window.
                addr = self.vram.add(data, 0x2000) if data else Vram("vram_null")
                # The anchor is virtual. Draw commands only address occupied
                # rows, which start at the actual allocated source address.
                addr -= first * width
                self.items[(*key, phase)] = Art(addr, width, size, bytes(pixels), masks, high)
        return self.items[(*key, y & 3)]


class Scene:
    def __init__(self, a, pool, window):
        self.a = a
        self.pool = pool
        self.window = window
        pool.cpu_window = window

