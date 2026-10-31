"""Prepare native ordinary-weapon patterns from the original US data tables."""

import json
from roms import load

# Slot operation: find one, find a pair, or second half of the previous pair.
SINGLE, PAIR, NEXT = 0, 1, 2


def prepare(out):
    regions, receipt = load()
    rom = regions["maincpu"]
    base = 0x14000 - 0x8000
    addresses = list(range(0x97FA, 0x9940, 13))
    templates = b"".join(rom[base + a : base + a + 12] for a in addresses)
    offsets = {a: i * 12 for i, a in enumerate(addresses)}

    def item(a, dx=0, code=0, link=0xFF, slot=SINGLE):
        return (offsets[a], dx & 255, code, link, slot)

    plans = {
        "basic": [item(0x97FA)],
        "basic_pair": [
            item(0x97FA, -16, link=0x80, slot=PAIR),
            item(0x97FA, 16, link=0x81, slot=NEXT),
        ],
        "rapid": [
            item(0x9807, code=0x94, link=0, slot=PAIR),
            item(0x9814, code=0x94, link=1, slot=NEXT),
        ],
        "rapid_pair": [item(0x9807, -8, 0x90, 0, PAIR), item(0x9814, 8, 0x90, 1, NEXT)],
        "spread": [item(a) for a in range(0x982E, 0x9863, 13)],
        "spread_pair": [item(a) for a in range(0x9821, 0x9870, 13)],
        "wide": [item(a) for a in range(0x9889, 0x98BE, 13)],
        "wide_pair": [item(a) for a in range(0x987C, 0x98CB, 13)],
        "shell": [item(a) for a in (0x98FE, 0x990B, 0x9918)],
        "laser": [item(0x98D7)],
        "laser_pair": [item(0x98E4), item(0x98F1)],
        "fire": [item(a) for a in (0x9925, 0x9932, 0x993F)],
    }
    lines = [
        "weapon_templates:",
        "  .byte " + ",".join(f"${v:02x}" for v in templates),
        "weapon_patterns:",
    ]
    for name, items in plans.items():
        lines.append(f"WP_{name.upper()} = *-weapon_patterns")
        for template, dx, code, link, slot in items:
            lines.append(f"  .word {template}\n  .byte {dx},{code},{link},{slot}")
        lines.append("  .word $ffff")
    (out / "weapon_data.inc").write_text("\n".join(lines) + "\n")
    codes = sorted({templates[o] for items in plans.values() for o, *_ in items} | {0x90, 0x94})
    meta = dict(
        reference="1943ua fixed $1579-$16E9; bank 1 $9522-$97F9 and $97FA-$994A",
        selectors=[0, 1, 2, 3, 4, 8, 16],
        template_bytes=len(templates),
        plans=len(plans),
        sprite_codes=codes,
    )
    (out / "weapon-data.json").write_text(json.dumps(meta, indent=2) + "\n")
    return meta
