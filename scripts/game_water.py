"""Stage palette water (assets/water) and the exact light-water texture.

- Normal (stage) water: a 30-row x 256-column pattern of the 120 water-slot
  indices, fixed in the foreground ring. water_stage_commit rotates the slot
  colours by STAGE_PHASE = (FG + 16 - SEA) mod 30 every picture, so the texture
  appears to move with the sea layer without any re-copy.
- Light water: exact ROM pixels in 3 water slots, static colours; its rows
  are copied at sea positions, so sea motion re-copies them.
- Only pixels copied from these patterns use the water slots. Sea features
  (scripts/game_sea.py) and foreground art draw their blues as fixed
  colours: they neither animate nor flash.
- Flashes (special hook only): the 120 slots go cyan or dark; clouds and
  the bolt slots switch between the normal and the lit table.
"""

import json
from arcade import ROOT
from playfield import sea_pixel

ACTIVE = 0x2E30
PHASE = 0x2E31
FORCE = 0x2E32
BASE = 0x2E33
END = 0x2E34
PAGE_PHASE = 0x2E38
STAGE_PHASE = 0x2E3C
PAL = 0x10800
# Cloud flash table (normal, then lit; index R G B per entry) in the sea
# directory's spare SRAM (game_sea.SEA_SPARE), read at $CE00 through BBR 13.
CLOUD_TABLE = 0x19E00
SEA_WATER_COLOURS = (2, 26, 39, 48)
CLOUD_ENTRIES = 12
MOD30 = 0xA700
HIGH30 = 0x1B600
BG2_DISABLED = 0x7BCE


def stage(a):
    spec = json.loads((ROOT / "assets/water/stage-water-4x30.json").read_text())
    slots = a.water_slots
    patterns = spec["patterns"]
    offsets = spec["column_offset"]
    columns = spec["column_pattern"]
    # A retained world row owns permanent codes. Palette phase supplies the
    # sea's displacement relative to the actual middle-layer position.
    # data[w*256+x] is the slot of foreground ring row w (w = FG+255-y on
    # screen) and column x: pattern columns[x%60], phase (-1-w+offset)%30.
    # palette = the 120 slot indices, then each pattern's 30 colours twice
    # (water_stage_commit reads 30 entries from any phase without a wrap).
    data = bytes(
        slots[columns[x % 60] * 30 + (-1 - w + offsets[x % 60]) % 30]
        for w in range(30)
        for x in range(256)
    )
    rgb = [a.palette[i * 3 : i * 3 + 3] for i in spec["arcade_colour_index"]]
    palette = bytes(slots) + b"".join(rgb[value] for pattern in patterns for value in pattern * 2)
    assert len(data) == 7680 and len(palette) == 840
    assert set(data) == set(slots) and len(set(data)) == 120
    # Every phase, screen row and repeat column follows the water texture.
    fg = 0x9000
    sea = 0
    for t in range(60):
        if t:
            fg += (2, 2, 0, 4, 6, -1, -2)[t % 7]
            sea += (1, 2, 1, 2, 3, 1, 0)[t % 7]
        phase = (fg + 256 - sea) % 30
        for y in range(60):
            w = fg + 255 - y
            for x in range(60):
                slot = data[(w % 30) * 256 + x]
                k, j = divmod(slots.index(slot), 30)
                actual = patterns[k][(j + phase) % 30]
                expected = patterns[columns[x]][(y - sea + offsets[x]) % 30]
                assert actual == expected
    return data, palette


def prepare(a, world_base=0, period=64):
    if world_base == 0:
        return stage(a)
    # Exact visible ROM pixels, at the display pitch. Full-width grouped
    # repairs can copy successive rows with a single DMA.
    assert world_base == 0x1000 and period == 128
    data = bytes(sea_pixel(a, world_base + 127 - r, x + 16) for r in range(128) for x in range(224))
    # Light water has three colors. Give them water-only DAC slots so the
    # special flash never changes sprites, clouds or the HUD.
    colors = sorted(set(data))
    assert len(colors) == 3
    a.light_water_colors = colors
    slots = a.water_slots[: len(colors)]
    translate = bytes.maketrans(bytes(colors), bytes(slots))
    remapped = data.translate(translate)
    assert all(
        a.palette[src * 3 : src * 3 + 3]
        == a.palette[colors[slots.index(dst)] * 3 : colors[slots.index(dst)] * 3 + 3]
        for src, dst in zip(data, remapped)
    )
    return remapped, b"".join(a.palette[c * 3 : c * 3 + 3] for c in colors)


def install(host, a, scene=None):
    data, palettes = prepare(a)
    if scene is not None:
        host.upload(0x41E00, scene.ship_seed_data)
    host.upload(0x100000 + PAL, palettes)
    _, light_palette = prepare(a, 0x1000, 128)
    host.upload(0x100000 + PAL + 840, light_palette)
    # Cloud-only flash changes shared DAC entries briefly; restore the exact
    # pre-existing RGB values as soon as the lightning flash clears.
    # Table (CLOUD_TABLE): CLOUD_ENTRIES normal entries (6 clouds, the bolt
    # slot twice, the sea water colours), then the same number of lit entries;
    # 4 bytes each (index, R, G, B).
    cloud_indices = (22, 33, 34, 32, 30, 29)
    normal = b"".join(bytes([i]) + a.palette[i * 3 : i * 3 + 3] for i in cloud_indices)

    # Keep the cloud pixels and tonal differences: lightning brightens the
    # existing colours instead of replacing all of them with sea blue. The
    # lit table ("cyan" in the names) moves each colour 3/5 toward white.
    def lit(v):
        return v + (255 - v) * 3 // 5

    cyan = b"".join(
        bytes([i] + [lit(v) for v in a.palette[i * 3 : i * 3 + 3]]) for i in cloud_indices
    )
    # The bolt slot twice: the table keeps its 12 entries (its SRAM place).
    normal += b"".join(bytes((i, 0, 188, 241)) for i in a.bolt_slots * 2)
    cyan += b"".join(bytes((i, 241, 241, 241)) for i in a.bolt_slots * 2)
    # The sea's water colours (normal-sea blues 2/26/39) and foam (48) flash
    # with the clouds in Lightning. Island water that is still drawn in tile
    # pixels uses them; other art using the same colours flashes too.
    for i in SEA_WATER_COLOURS:
        normal += bytes([i]) + a.palette[i * 3 : i * 3 + 3]
    cyan += b"".join(
        bytes([i])
        + (
            bytes([0, 172, 241])
            if i == 2
            else bytes([0, 188, 241])
            if i in (26, 39)
            else bytes(lit(v) for v in a.palette[i * 3 : i * 3 + 3])
        )
        for i in SEA_WATER_COLOURS
    )
    assert len(normal) == len(cyan) == 4 * CLOUD_ENTRIES
    cloud_address = 0x100000 + CLOUD_TABLE
    assert all(
        cloud_address + 8 * CLOUD_ENTRIES <= p or cloud_address >= p + len(data)
        for p, data in host.card_startup
    )
    host.upload(cloud_address, normal + cyan)
    host.upload(0x100000 + MOD30, bytes(r % 30 for r in range(256)))
    host.upload(0x100000 + HIGH30, bytes((r * 256) % 30 for r in range(256)))
    host.upload(0x100000 + ACTIVE, bytes(0x70))
    # The first palette commit precedes the first world packet.
    host.upload(0x100000 + BG2_DISABLED, b"\0")
    host.upload(0x102E9C, b"\xff\xff")
    host.upload(0x102EC6, b"\xff\0\0\0")
    host.upload(0x102EF0, bytes(8))


def palette_include(a):
    """Assembler constants of the water slots, for src/card/water.s."""
    light = a.water_slots[:3]
    assert len(a.light_water_colors) == 3 and light == list(range(light[0], light[0] + 3))
    rgb = [v for i in a.light_water_colors for v in a.palette[i * 3 : i * 3 + 3]]
    lines = [
        "; Generated by scripts/game_water.py from the stage water assets.",
        f"        .equ LIGHT_WATER_SLOT, {light[0]}",
        *(f"        .equ LIGHT_WATER_RGB_{i}, {v}" for i, v in enumerate(rgb)),
    ]
    for pattern in range(4):
        slots = a.water_slots[pattern * 30 : (pattern + 1) * 30]
        contiguous = all(slots[i] == slots[0] + i for i in range(30))
        lines.append(f"        .equ WATER_PATTERN_{pattern}_CONTIGUOUS, {int(contiguous)}")
    from propellers import GREYS

    lines += [f"        .equ PROPELLER_SLOT, {a.prop_slots[0]}"]
    lines += [f"        .equ PROPELLER_GREY_{i}, {v}" for i, v in enumerate(GREYS)]
    return "\n".join(lines) + "\n"


def sources(scene):
    """build/card/gen/water_palette.inc and the water pattern symbols."""
    from card_link import alias, generate_include

    generate_include("water_palette", palette_include(scene.a))
    alias("normal_water_pattern", scene.normal_water_pattern("group"))
    alias("light_water_pattern", scene.light_water_patterns[0]("group"))


