"""Build the game's complete foreground map and shared, clipped-row source.

The map describes ROM space, not playback frames. Four fine-panning phases
share compact run lists. Coarse panning and clipping are placement operations.
"""

import numpy as np



def row_runs(mask):
    out = bytearray()
    x = 0
    while x < 64:
        value = int(mask[x])
        end = x + 1
        while end < 64 and mask[end] == value:
            end += 1
        if value:
            out.extend((x, end, value))
        x = end
    return bytes([len(out) // 3]) + out


class World:
    def __init__(self, a):
        tiles = np.frombuffer(b"".join(a.gfx[1]), dtype=np.uint8).reshape(-1, 32, 32)
        colors = np.frombuffer(bytes(a.colors[1]), dtype=np.uint8).reshape(16, 16)
        self.columns = []
        self.column_index = []
        self.runs = []
        self.tiles = []
        column_ids = {}
        run_ids = {}
        tile_ids = {}
        self.column_tiles = []
        for column in range(2048):
            key = bytes(a.maps[column * 16 : column * 16 + 16])
            if key in column_ids:
                self.column_index.append(column_ids[key])
                continue
            number = len(self.columns)
            column_ids[key] = number
            self.column_index.append(number)
            rows = []
            ids = []
            for i in range(8):
                code, attr = key[i * 2 : i * 2 + 2]
                code |= (attr & 1) << 8
                pixels = tiles[code]
                if attr & 128:
                    pixels = pixels[::-1, :]
                if attr & 64:
                    pixels = pixels[:, ::-1]
                pixels = colors[(attr >> 2) & 15][pixels.T]
                data = pixels.tobytes()
                if data not in tile_ids:
                    tile_ids[data] = len(self.tiles)
                    self.tiles.append(data)
                ids.append(tile_ids[data])
                rows.append(pixels)
            self.column_tiles.append(ids)
            pixels = np.concatenate(rows, axis=1)
            phases = []
            for phase in range(4):
                mask = np.roll(pixels, -phase, axis=1).reshape(32, 64, 4) != 15
                values = (mask * np.array([1, 2, 4, 8], dtype=np.uint8)).sum(axis=2)
                phase_ids = []
                for row in values:
                    data = row_runs(row)
                    if data not in run_ids:
                        run_ids[data] = len(self.runs)
                        self.runs.append(data)
                    phase_ids.append(run_ids[data])
                phases.append(phase_ids)
            self.columns.append(phases)

        # Final card commands include transparent spans too. Each segment is
        # already an end group and a map mask; its start is the preceding end.
        self.prepared_runs = []
        self.packed_runs = []
        for row in self.runs:
            parts = []
            last = 0
            decoded = [0] * 64
            for i in range(1, len(row), 3):
                start, end, mask = row[i : i + 3]
                if start > last:
                    parts.extend((start, 0))
                parts.extend((end, mask))
                last = end
                decoded[start:end] = [mask] * (end - start)
            if last < 64:
                parts.extend((64, 0))
            restored = []
            last = 0
            for end, mask in zip(parts[::2], parts[1::2]):
                restored.extend([mask] * (end - last))
                last = end
            assert restored == decoded
            occupied = [i for i, m in enumerate(decoded) if m]
            bounds = [occupied[0], occupied[-1] + 1] if occupied else [64, 0]
            self.prepared_runs.append(bytes([len(parts) // 2, *bounds]) + bytes(parts))
            packed = bytearray([len(parts) // 2])
            for end, mask in zip(parts[::2], parts[1::2]):
                packed.append((end & 63) | (0x80 if mask == 15 else 0x40 if mask == 0 else 0))
                if mask not in (0, 15):
                    packed.append(mask)
            self.packed_runs.append(bytes(packed))

    def run(self, world, phase):
        return self.columns[self.column_index[(world >> 5) & 2047]][phase][world & 31]

    def region(self, ranges):
        """Make one spatial art working set, including every pan phase."""
        ids = sorted(
            {
                self.run(w, p)
                for first, last in ranges
                for w in range(first, last + 1)
                for p in range(4)
            }
        )
        data = bytearray()
        offsets = {}
        for i in ids:
            row = self.packed_runs[i]
            # Four 5.5 KB planes hold a section's compressed command source.
            if len(data) % 5632 + len(row) > 5632:
                data.extend(bytes(5632 - len(data) % 5632))
            offsets[i] = (len(data) // 5632) * 8192 + len(data) % 5632
            data.extend(row)
        tiles = sorted(
            {
                i
                for first, last in ranges
                for c in range(first >> 5, (last >> 5) + 1)
                for i in self.column_tiles[self.column_index[c & 2047]]
            }
        )
        return data, offsets, tiles
