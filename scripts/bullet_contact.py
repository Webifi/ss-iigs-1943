"""Compare native enemy-bullet contact, energy, dodge and HUD writes."""


def prepare(out):
    # Every energy row is a window into one of eight shared 30-byte rows.
    # Lookup indices are prepared at build time, leaving the same 16 output
    # tile bytes for every energy from 0 through 112.
    tiles = b"".join(bytes([0x88] * 14 + [0x80 + r] + [0x80] * 15) for r in range(8))
    offsets = [(energy % 8) * 30 + 14 - energy // 8 for energy in range(113)]
    original = bytes(
        0x80 + min(8, max(0, energy - i * 8)) for energy in range(113) for i in range(16)
    )
    assert all(
        tiles[offsets[e] : offsets[e] + 16] == original[e * 16 : (e + 1) * 16] for e in range(113)
    )

    def install(host):
        host.blob_at(tiles, "ENERGY_TILES")
        host.blob_at(b"".join(value.to_bytes(2, "little") for value in offsets), "ENERGY_OFFSETS")

    return install
