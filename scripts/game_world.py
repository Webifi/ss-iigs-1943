"""ROM-derived stage world data and the rolling card row directory."""


def initial_state():
    # Power-on cabinet state. Player and cameras are initialized by the
    # native $0F12 port only after a credit is spent at the title.
    return 0, 0xD100, bytearray(38), bytearray(128)


def hud_commands():
    # Upright arcade coordinates; all glyph shapes/palettes come from ROM.
    rows = []
    for i in range(8):
        rows.append(("char", 0, 0x24, 0, 0, 240, 8 * i))
    for i in range(8):
        rows.append(("char", 0, 0x88, 0, 0, 8, 8 * i))
    for i, ch in enumerate("1UP"):
        code = 1 if ch == "1" else ord(ch) - ord("A") + 10
        rows.append(("char", 0, code, 0, 0, 248, 8 * i))
    return rows


