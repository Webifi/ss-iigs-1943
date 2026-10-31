"""Card-owned weapon labels and time. Two wire bytes; all choices are data."""

from weapon_timer import data


def glyphs(kind):
    names, offsets, _ = data()
    if kind.startswith("weapon_name"):
        slot = int(kind[11:])
        messages = ("CONTINUE", "GAMEOVER")
        return [(names[offsets[i] + 1 + slot], names[offsets[i]]) for i in range(17)] + [
            (ord(s[slot]) - ord("A") + 10, 0) for s in messages
        ]
    return [(i, 7) for i in range(10)] + [(0x24, 7)]


def timer_bytes():
    _, _, digits = data()
    return bytes(10 if v == 0x24 else v for v in digits)
