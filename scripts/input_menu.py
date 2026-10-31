"""Native pause text reuses the display pages and cabinet font. No VRAM."""


def install(out, info):
    glyphs = info["glyphs"]
    glyph = [255] * 128
    for i in range(10):
        glyph[48 + i] = glyphs[i, 0]
    for i in range(26):
        glyph[65 + i] = glyphs[10 + i, 0]
    # Apple text page 1 interleaves its 24 rows; six columns center 28.
    lines = [
        "menu_apple_rows:",
        "  .word " + ",".join(str((y & 7) * 128 + (y >> 3) * 40 + 6) for y in range(24)),
    ]
    names = [
        "P1 RIGHT",
        "P1 LEFT",
        "P1 DOWN",
        "P1 UP",
        "P1 FIRE",
        "P1 SPECIAL",
        "P2 RIGHT",
        "P2 LEFT",
        "P2 DOWN",
        "P2 UP",
        "P2 FIRE",
        "P2 SPECIAL",
        "P1 START",
        "P2 START",
        "COIN A",
        "COIN B",
    ]
    lines += ["menu_actions:"] + ['  .byte "' + n.ljust(10) + '"' for n in names]
    # Names use the actual physical identities. Hex is shown for uncommon keys.
    names = {
        0: "A",
        1: "S",
        2: "D",
        0x0D: "W",
        0x12: "1",
        0x13: "2",
        0x17: "5",
        0x16: "6",
        0x24: "RETURN",
        0x30: "TAB",
        0x31: "SPACE",
        0x33: "DELETE",
        0x35: "ESC",
        0x36: "CONTROL",
        0x37: "OPEN APPLE",
        0x38: "SHIFT",
        0x39: "CAPS LOCK",
        0x3A: "OPTION",
        0x3B: "LEFT",
        0x3C: "RIGHT",
        0x3D: "DOWN",
        0x3E: "UP",
        0x4C: "PAD ENTER",
        0x53: "PAD 1",
        0x54: "PAD 2",
        0x55: "PAD 3",
        0x56: "PAD 4",
        0x57: "PAD 5",
        0x58: "PAD 6",
        0x59: "PAD 7",
        0x5B: "PAD 8",
        0x5C: "PAD 9",
        0x7B: "LEFT",
        0x7C: "RIGHT",
        0x7D: "DOWN",
        0x7E: "UP",
    }
    key_names = list(dict.fromkeys(names.values()))
    lines += [
        "menu_key_index:",
        "  .byte "
        + ",".join(str(key_names.index(names[n]) if n in names else 255) for n in range(128)),
    ]
    lines += ["menu_key_names:"] + ['  .byte "' + n.ljust(10) + '"' for n in key_names]
    device = [
        "RIGHT",
        "LEFT",
        "DOWN",
        "UP",
        "BUTTON 1",
        "BUTTON 2",
        "BUTTON 3",
        "BUTTON 4",
        "BUTTON A",
        "BUTTON X",
        "BUTTON L",
        "BUTTON R",
    ]
    # Pad indexes follow the serial bit order published by SNES MAX.
    pad = [
        "RIGHT",
        "LEFT",
        "DOWN",
        "UP",
        "START",
        "SELECT",
        "BUTTON Y",
        "BUTTON B",
        "BUTTON A",
        "BUTTON X",
        "BUTTON L",
        "BUTTON R",
    ]
    lines += ["menu_device_names:"] + ['  .byte "' + n.ljust(10) + '"' for n in device]
    lines += ["menu_pad_names:"] + ['  .byte "' + n.ljust(10) + '"' for n in pad]
    lines += ["menu_sources:"] + [
        '  .byte "' + n.ljust(14) + '"'
        for n in (
            "UNBOUND",
            "ADB KEYBOARD",
            "J13 KEYBOARD",
            "ADB AND J13",
            "MOUSE",
            "JOYSTICK",
            "PAD ONE",
            "PAD TWO",
        )
    ]
    # Default records also exist outside the writable settings, for Reset.
    lines += ["menu_default_bindings:", '.include "input_defaults.inc"']
    out.joinpath("input_menu_data.inc").write_text("\n".join(lines) + "\n")
