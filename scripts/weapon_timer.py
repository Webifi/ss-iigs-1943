"""US weapon HUD data. Decimal/label choices are built, never divided live."""

from roms import load


def data():
    rom = load()[0]["maincpu"]
    names = [bytes([0]) + bytes([0x24]) * 8]
    for address in (0x186A, 0x189E, 0x1850, 0x1884, 0x18B8):
        names.append(rom[address + 4 : address + 13])
    offsets = [
        9 * (1 if i == 1 else 2 if i & 2 else 3 if i & 4 else 4 if i & 8 else 5 if i else 0)
        for i in range(32)
    ]
    digits = bytes(
        v for n in range(256) for v in ((n // 10 or 0x24, n % 10) if n != 255 else (0x24, 0x24))
    )
    return b"".join(names), offsets, digits

