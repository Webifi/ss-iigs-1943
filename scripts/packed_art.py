"""Lossless compact host art. Expansion happens on load, never while drawing.

Four-bit row spans keep sprite expansion simple. Foreground tiles use shared
four-bit 8x8 blocks. Every index and flip is included in the reported sizes.
These files are source assets, not final card pixels.
"""

import hashlib, json, struct, time
from arcade import Arcade, ROOT


def flip(data, size, flags):
    return bytes(
        data[(size - 1 - y if flags & 2 else y) * size + (size - 1 - x if flags & 1 else x)]
        for y in range(size)
        for x in range(size)
    )


def nibbles(data):
    return bytes(
        data[i] | ((data[i + 1] if i + 1 < len(data) else 0) << 4) for i in range(0, len(data), 2)
    )


def unpack(data, n):
    return bytes((data[i // 2] >> (4 * (i & 1))) & 15 for i in range(n))


def spans(data):
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


def expand_spans(data):
    out = bytearray(256)
    pos = 0
    for y in range(16):
        header = data[pos]
        pos += 1
        if header == 255:
            continue
        x = header & 15
        n = (header >> 4) + 1
        assert x + n <= 16
        out[y * 16 + x : y * 16 + x + n] = unpack(data[pos : pos + (n + 1) // 2], n)
        pos += (n + 1) // 2
    return bytes(out), pos


def build(out=None):
    from machine_gate import check

    check("build")
    start = time.perf_counter()
    a = Arcade()
    out = out or ROOT / "build/packed-art"
    out.mkdir(parents=True, exist_ok=True)
    unique = {}
    sprite_data = bytearray()
    sprite_index = bytearray()
    nonblank = 0
    for tile in a.gfx[3]:
        # Upright rows match the card's final art orientation.
        pixels = bytes(tile[x * 16 + 15 - y] for y in range(16) for x in range(16))
        if not any(pixels):
            sprite_index.extend(b"\xff\xff\xff\0")
            continue
        nonblank += 1
        variants = [flip(pixels, 16, f) for f in range(4)]
        canonical = min(variants)
        flags = variants.index(canonical)
        if canonical not in unique:
            unique[canonical] = len(sprite_data)
            sprite_data.extend(spans(canonical))
        offset = unique[canonical]
        sprite_index.extend(offset.to_bytes(3, "little") + bytes([flags]))
        decoded, used = expand_spans(sprite_data[offset:])
        assert flip(decoded, 16, flags) == pixels
    block_ids = {}
    blocks = bytearray()
    tiles = bytearray()
    for tile in a.gfx[1]:
        pixels = bytes(tile[x * 32 + 31 - y] for y in range(32) for x in range(32))
        restored = bytearray(1024)
        for y in range(0, 32, 8):
            for x in range(0, 32, 8):
                block = bytes(pixels[(y + j) * 32 + x + i] for j in range(8) for i in range(8))
                variants = [flip(block, 8, f) for f in range(4)]
                canonical = min(variants)
                flags = variants.index(canonical)
                if canonical not in block_ids:
                    block_ids[canonical] = len(blocks) // 32
                    blocks.extend(nibbles(canonical))
                number = block_ids[canonical]
                assert number < 16384
                tiles.extend(struct.pack("<H", number | (flags << 14)))
                decoded = flip(unpack(blocks[number * 32 : number * 32 + 32], 64), 8, flags)
                for j in range(8):
                    restored[(y + j) * 32 + x : (y + j) * 32 + x + 8] = decoded[j * 8 : j * 8 + 8]
        assert restored == pixels
    files = {
        "sprites.idx": sprite_index,
        "sprites.rows": sprite_data,
        "foreground.idx": tiles,
        "foreground.blocks": blocks,
    }
    for name, data in files.items():
        (out / name).write_bytes(data)
    result = dict(
        sprite_codes=len(a.gfx[3]),
        nonblank_sprites=nonblank,
        unique_sprite_images=len(unique),
        sprite_index_bytes=len(sprite_index),
        sprite_pixel_bytes=len(sprite_data),
        foreground_tiles=len(a.gfx[1]),
        unique_blocks=len(block_ids),
        foreground_index_bytes=len(tiles),
        foreground_block_bytes=len(blocks),
        total_bytes=sum(map(len, files.values())),
        exact_sprite_pixels=2048 * 256,
        exact_foreground_pixels=512 * 1024,
        representation="Four-bit sprite row spans and shared four-bit 8x8 foreground blocks, flip bits and every index included",
        source="Original-US 1943ua graphics, verified by scripts/roms.py",
        files={
            name: dict(bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
            for name, data in files.items()
        },
        build_seconds=time.perf_counter() - start,
    )
    (out / "manifest.json").write_text(json.dumps(result, indent=2) + "\n")
    return result
