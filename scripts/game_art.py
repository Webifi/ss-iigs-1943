"""All sprite source art in card memory, with a cache of final aligned pixels.

The source is ROM-derived four-bit row spans. Cache misses are local card
reads; the IIgs never sends sprite pixels during play. Live objects pin cache
entries until the current picture is drawn.
"""

import os
import struct
from scene import ArtPool, Art
from packed_art import spans

SLOTS = 128
CODE = 0x6000
KEYS = 0x7400
USED = 0x7500
NEXT = 0x7580
SLOT = 0x7581
KEY = 0x7582
SOURCE = 0x7584
FLAGS = 0x7586
SIZE = 0x7587
COLOR = 0x7588
BOUNDS = 0x7600
WIRE = 0x7900
ENTRY = 0x7B00
PHASE = 0x7B20
SLOT_PHASES = 0x7C80
CHAIN = 0x7C00
SPANPTR = 0x758A
HASH = 0x2F00
HASH_KEY = 0x758C
MATCH = 0x758D
SOURCE_PHASE = 0x758E
CLONE_SOURCE = 0x7B24
CLONE_DEST = 0x7B26
PREFETCH_NEXT = 0x758F
HIDDEN_COUNT = 0x7B2A
HIDDEN_NEXT = 0x7B2B
BINDING = 0x7B2C
CLONE_FIRST = 0x7B2F
PIXEL = 0x7B30
PIXEL_NEXT = 0x7B32
MATCH_PIXEL = 0x7B34
PIXEL_BEST = 0x7B36
PIXEL_SOURCE = 0x7B38
PHASE_RECORD = 0xC000
DIRECT_BANK = 11
PIN_LIST = 0xCC00
PIN_COUNT = 0x7B3D
HEADER_NEXT = 0x7B3E
STAMP = 0x7B3F


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
        self.mask_table = bytes(int(bool(v & 15)) | int(bool(v >> 4)) << 1 for v in range(256))
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
        self.source_wire_bytes = sum(map(len, shared))

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
        # The card code reads these (src/card/sprite_cache.s).
        index("group16"), index("vseg"), pairs("vseg"), pairs("vbbr4k")
        prop_masks("group16"), prop_masks("vseg")
        archive("vseg"), archive("vbbr4k")
        # Final phase capacity is allocated after every other feature's art.
        self.requested_slots = int(os.environ.get("SS1943_SPRITE_SLOTS", "512"))
        if not 128 <= self.requested_slots <= 512:
            raise ValueError("SS1943_SPRITE_SLOTS must be 128..512")
        # Code generation needs the cache interface before the HUD and
        # attract programs allocate. Physical slots are placed only after
        # those assets, so a small slot cannot fragment their larger blocks.
        self.phase_records = bytearray()
        pool.cpu_window = previous
        self.low_palettes = {
            c for c in range(16) if any(a.prom[0x900 + c * 16 + p] & 8 for p in range(1, 16))
        }
        assert self.low_palettes == {10, 11}
        assert all(
            (a.prom[0x900 + c * 16 + p] & 8) != 0 for c in self.low_palettes for p in range(1, 16)
        )
        self.slot_records = bytearray(b"\xff" * 1024)

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
        from card_link import asset

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
        self.phase_record_bytes = records.size
        asset("phase_records", records)
        self.set_capacity(len(self.slots))

    def boot_clear_source(self):
        """Boot-only DMA fill; no host payload, gameplay code or extra VRAM:
        build/card/gen/cache_boot_clear_ranges.s."""
        from card_link import generate, section_sizes

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
        source = generate("cache_boot_clear_ranges", "\n".join(lines) + "\n")
        self.clear_code_bytes = (
            section_sizes("sprite_cache")[".text.cache_boot_clear"]
            + section_sizes(source)[".rodata.cache_boot_clear_ranges"]
        )

    def set_capacity(self, slots):
        """Link values of the phase record count, for the cache code."""
        from card_link import define

        define("phase_clock_passes", slots * 2)
        define("phase_record_end", 0xC000 + slots * 8)
        define("phase_record_count", slots)

    def install(self, host):
        host.upload(0x100000 + KEYS, b"\xff" * 384 + bytes(128))
        host.upload(0x100000 + HASH, bytes(256))
        host.upload(0x100000 + CHAIN, bytes(SLOTS))
        # Build-prepared canonical coverage for uniform terrain rows, in
        # the existing reserved common-SRAM area beside the row cache.
        host.upload(0x10B900, bytes(32) + b"\xff" * 32)
        host.upload(0x117800, self.slot_records)
        host.upload(0x100000 + PIXEL_NEXT, struct.pack("<H", PHASE_RECORD))
        host.upload(0x100000 + PIN_COUNT, b"\0\0\1")

    def install_directory(self, host):
        host.upload(0x112000, (bytes(8) + b"\xff" + bytes(5) + b"\xff\xff") * 128)
        host.upload(0x117000, bytes(2048))
        host.upload(0x112800, bytes(m << (2 * pair) for pair in range(4) for m in self.mask_table))
        host.upload(0x112C00, self.span_headers + self.span_masks)

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


