"""All sprite source art in card memory, with a cache of final aligned pixels.

The source is ROM-derived four-bit row spans. Cache misses are local card
reads; the IIgs never sends sprite pixels during play. Live objects pin cache
entries until the current picture is drawn.
"""

from scene import ArtPool, Art


def nibbles(data):
    return bytes(
        data[i] | ((data[i + 1] if i + 1 < len(data) else 0) << 4) for i in range(0, len(data), 2)
    )


def spans(data):
    """Four-bit row spans of a 16x16 sprite: per row a header byte, then the pixels."""
    out = bytearray()
    for y in range(16):
        row = data[y * 16 : y * 16 + 16]
        visible = [x for x, p in enumerate(row) if p]
        if not visible:
            out.append(255)
            continue
        first, last = visible[0], visible[-1] + 1
        out.append(first | ((last - first - 1) << 4))
        out.extend(nibbles(row[first:last]))
    return bytes(out)


SLOTS = 128


class GameArtPool(ArtPool):
    def get(self, cmd):
        if cmd[1] != 3:
            return super().get(cmd)
        # Sprites are represented by the ROM-code cache, not permanent slots.
        return Art(0, 4, 16, bytes(256), [[0] * 4 for _ in range(16)], [[0] * 4 for _ in range(16)])


class SpriteCache:
    def __init__(self, scene):
        self.scene = scene
        pool = scene.pool
        a = scene.a
        # The directory entry of each ROM code: (wire address, plane, size).
        self.index = [None] * 2048
        self.slots = []
        self.blocks = []
        # Spans of length 1 or 2 cannot have internal transparent pixels.
        # The unused header codes fit every longer span with holes, so the
        # source itself says whether its mask is an interval. No extra bytes.
        valid = [h for h in range(256) if (h & 15) + (h >> 4) + 1 <= 16]
        unused = iter(h for h in range(255) if h not in valid)
        holes = {h: next(unused) for h in valid if (h >> 4) + 1 >= 3}
        self.span_headers = bytearray(range(256))
        mask_words = [0] * 256
        for h in valid:
            mask_words[h] = ((1 << ((h >> 4) + 1)) - 1) << (h & 15)
        for h, encoded in holes.items():
            self.span_headers[encoded] = h
        self.span_masks = bytes(m & 255 for m in mask_words) + bytes(m >> 8 for m in mask_words)

        def wire_for(code, pixels, bounds):
            first, height = bounds[2:4]
            # Only occupied rows are read by the descriptor. The old wire
            # carried two redundant bytes for every top/bottom blank row.
            rows = spans(pixels[first * 16 : (first + height) * 16] + bytes((16 - height) * 16))
            if height < 16:
                rows = rows[: height - 16]
            rows = bytearray(rows)
            offset = 0
            for row in range(height):
                h = rows[offset]
                offset += 1
                if h == 255:
                    continue
                n = (h >> 4) + 1
                first = h & 15
                if 0 in pixels[(bounds[2] + row) * 16 + first : (bounds[2] + row) * 16 + first + n]:
                    rows[offset - 1] = holes[h]
                offset += (n + 1) // 2
            assert offset == len(rows)
            assert len(bounds + rows) <= 148
            return bounds + rows

        previous = pool.cpu_window
        pool.cpu_window = 4096
        data = bytearray(16384)
        used = [0] * 4
        pending = []

        def flush():
            nonlocal data, used, pending
            address = pool.allocate(bytes(data[: max(used) * 4]))
            for code, plane, offset, size in pending:
                self.index[code] = (address + offset, plane, size)
            data = bytearray(16384)
            used = [0] * 4
            pending = []

        shared = {}
        for code, tile in enumerate(a.gfx[3]):
            pixels = bytes(tile[x * 16 + 15 - y] for y in range(16) for x in range(16))
            positions = [(i & 15, i >> 4) for i, p in enumerate(pixels) if p]
            if not positions:
                continue
            bounds = bytes(
                (
                    min(x for x, y in positions),
                    max(x for x, y in positions) + 1,
                    min(y for x, y in positions),
                    max(y for x, y in positions) - min(y for x, y in positions) + 1,
                )
            )
            wire = wire_for(code, pixels, bounds)
            if wire in shared:
                continue
            shared[wire] = code
            plane = min(range(4), key=lambda n: used[n])
            if used[plane] + len(wire) > 4096:
                flush()
                plane = 0
            offset = used[plane]
            used[plane] += len(wire)
            data[plane + offset * 4 : plane + (offset + len(wire)) * 4 : 4] = wire
            pending.append((code, plane, offset, len(wire)))
        if pending:
            flush()
        # Alias exact images and bounds; phases share the derived mask.
        for code, tile in enumerate(a.gfx[3]):
            pixels = bytes(tile[x * 16 + 15 - y] for y in range(16) for x in range(16))
            pos = [(i & 15, i >> 4) for i, p in enumerate(pixels) if p]
            if not pos:
                continue
            bounds = bytes(
                (
                    min(x for x, y in pos),
                    max(x for x, y in pos) + 1,
                    min(y for x, y in pos),
                    max(y for x, y in pos) - min(y for x, y in pos) + 1,
                )
            )
            origin = shared[wire_for(code, pixels, bounds)]
            self.index[code] = self.index[origin]

        def directory(source):
            for entry in self.index:
                if entry is None:
                    source.byte(0xFF, 0xFF, 0xFF, 0xFF)
                    continue
                wire, plane, size = entry
                source.word(wire("group16")).byte(f"{wire('vseg')} + {plane << 2}", size)

        index = pool.vram.table(8192, directory, 4096, name="sprite_index")
        archive = pool.vram.add(b"\xff" * 16384, 4096, name="sprite_archive")
        # One four-plane latch entry contains two ROM palette pixels twice.
        # Swapping source nibbles gives the odd-lane ordering as well. The
        # build does every palette conversion; a miss just reads this table
        # and writes two pixels with the standard VGA map mask/write mode 1.
        pair_pixels = bytes(
            a.colors[3][color * 16 + pen]
            for color in range(16)
            for pair in range(256)
            for pen in (pair & 15, pair >> 4, pair & 15, pair >> 4)
        )
        # Propeller rows in the next 4 KB window of the same segment: the even
        # palette of each pair in propellers.PAIRS, pens 7/8 on the two
        # swapped DAC entries (game_palette.prop_slots).
        from propellers import PAIRS

        rows = bytearray()
        for pair in PAIRS:
            row = bytearray(a.colors[3][pair * 32 : pair * 32 + 16])
            row[7:9] = bytes(a.prop_slots)
            rows += bytes(row[pen] for p in range(256) for pen in (p & 15, p >> 4, p & 15, p >> 4))
        pairs = pool.vram.add(pair_pixels + rows, 4096, name="sprite_pairs", align=16384)
        # The propeller pair mask of each ROM code, a byte per code
        # (set_propellers); the bytes are written at link time.
        self.prop_masks = bytes(2048)
        prop_masks = pool.vram.table(
            2048, lambda source: source.data(self.prop_masks), 4096, name="sprite_prop_masks"
        )
        # The card code reads these (src/secondsight/sprite_cache.s).
        index("group16"), index("vseg"), pairs("vseg"), pairs("vbbr4k")
        prop_masks("group16"), prop_masks("vseg")
        archive("vseg"), archive("vbbr4k")
        # Final phase capacity is allocated after every other feature's art.
        self.requested_slots = 512
        # Code generation needs the cache interface before the HUD and
        # attract programs allocate. Physical slots are placed only after
        # those assets, so a small slot cannot fragment their larger blocks.
        pool.cpu_window = previous
        self.low_palettes = {
            c for c in range(16) if any(a.prom[0x900 + c * 16 + p] & 8 for p in range(1, 16))
        }
        assert self.low_palettes == {10, 11}
        assert all(
            (a.prom[0x900 + c * 16 + p] & 8) != 0 for c in self.low_palettes for p in range(1, 16)
        )

    def set_propellers(self, keys):
        """The propeller art among KEYS, (code, pair) of scripts/propellers.py:
        the pair mask table of the card."""
        from propellers import table, masks

        self.prop_codes = table(keys, self.scene.a.gfx[3])
        self.prop_masks = masks(self.prop_codes)

    def reserve(self):
        """The phase slots: 260 bytes each, in blocks of up to 63 slots inside
        one 4096-group window. Entry clears every plane with fixed-source DMA
        before any cache descriptor can become live, so no load writes them."""
        assert not self.slots, "Sprite pixels must be allocated once, last"
        from asset_source import Source
        from secondsight_link import asset

        pool = self.scene.pool
        self.clear_ranges = []
        for first in range(0, self.requested_slots, 63):
            count = min(63, self.requested_slots - first)
            block = pool.vram.reserve(count * 260, 4096, name=f"sprite_slots_{first // 63}")
            self.clear_ranges.append((block, count * 65))
            self.slots += [block + 65 * n for n in range(count)]
        # Draw headers are a separate 128-slot cache. Retained pixels do not
        # consume scarce SRAM while they are off screen.
        records = Source("sprite phase records (scripts/game_art.py)").section(".rodata.phase_records")
        records.label("phase_records")
        for slot in self.slots:
            records.word(slot("group16")).byte(slot("vseg"), 0, 255, 255).word(0)
        asset("phase_records", records)
        self.set_capacity(len(self.slots))

    def boot_clear_source(self):
        """Boot-only DMA fill; no host payload, gameplay code or extra VRAM:
        build/secondsight/gen/cache_boot_clear_ranges.s."""
        from secondsight_link import generate

        lines = [
            "; Generated by scripts/game_art.py: video RAM ranges of the phase slots.",
            '        .section .rodata.cache_boot_clear_ranges,"a",@progbits',
            "        .global cache_boot_clear_ranges, cache_boot_clear_done",
            "cache_boot_clear_ranges:",
        ]
        for block, count in self.clear_ranges:
            lines.append(f"        .byte {block('vseg')}")
            lines.append(f"        .word {block('group16')}, {count}")
        lines += ["        .byte 0xFF", "cache_boot_clear_done:"]
        generate("cache_boot_clear_ranges", "\n".join(lines) + "\n")

    def set_capacity(self, slots):
        """Link values of the phase record count, for the cache code."""
        from asset_source import derived
        from secondsight_link import alias, define

        define("phase_clock_passes", slots * 2)
        alias("phase_record_end", f"{derived('ptr', 'phase_records')} + {slots * 8}")
        define("phase_record_count", slots)

    def install_directory(self, host):
        """The span tables of the sprite cache (.sprite_headers of
        secondsight.ld; src/secondsight/sprite_cache.s holds the others)."""
        from asset_source import Source
        from secondsight_link import asset

        source = Source("sprite cache span tables (scripts/game_art.py)")
        source.section(".rodata.span_headers").label("span_headers").data(self.span_headers)
        source.section(".rodata.span_masks").label("span_masks").data(self.span_masks)
        asset("sprite_spans", source)

    def sources(self):
        """The generated sources of the sprite cache and the code that shares
        its regions."""
        # The phase capacity is known only after the last VRAM allocation
        # (SpriteCache.reserve); until then the requested capacity stands.
        self.set_capacity(self.requested_slots)
        from game_hud import messages_source

        messages_source()
        from arcade_flow import sources as cabinet_sources

        cabinet_sources(self.scene)


