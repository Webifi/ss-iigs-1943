"""State packets and card-owned object/HUD planning.

Wire words are little endian: sea camera, foreground camera, update, object
count, eight score digits, eight energy glyph values, then arcade four-byte
object records. Placement, clipping and repair records never cross the bus.
"""

import struct
from native_foreground import LiveScene

# Common SRAM, below the renderer. No firmware drawing runs in this phase.
OUT = 0x0C02
REPAIR = 0x0C04
RESTORE_START = 0x0C06
BASE = 0x0C08
START = 0x0C0A
PAGE = 0x0C0C
ITEMS = 0x0C0E
ITEM = 0x0C10
SPRITE_BASE = 0x0C22
COUNT = 0x0C2A
HUDPTR = 0x0C2C
SCORE = 0x0C40
FG = 0x0C38
FGPTR = 0x0C3A


class StateScene(LiveScene):
    state_only = True
    deferred_receive = True

    def __init__(self, *args, background_cache=False, **kwargs):
        super().__init__(*args, **kwargs)
        self.background_cache = background_cache
        self.packed_coverage = background_cache
        self.direct_masks = background_cache
        self.retained_rows = False
        self.damage_cells = False
        self.pattern_hud = background_cache

    def planner(self):
        """The generated sources and the checks of the renderer and the
        planner."""
        self.code_pages = 8
        self.indexed_codes = False
        self.code_table_bytes = 8192
        self.sprite_cache.sources()
        from ship_alignment import bases_source

        bases_source(self)
        from game_sea import check_occupancy

        check_occupancy(self)
        from background_full import limits_source

        limits_source(self)
        # The planner skips sprite 0: its pens are transparent in every palette.
        assert not any(self.a.gfx[3][0])
        assert self.background_cache and self.pattern_hud and not self.foreground_primary
        from hud_fast import bounds_source

        bounds_source(self)
        from game_water import sources as water_sources

        water_sources(self)


def tables(scene, offload):
    """All code, palette and clipping decisions independent of play are data."""
    codes = bytearray(scene.code_pages * 512)
    codes = bytes(8192)
    palette_chunks = []
    scene.compound_chunks = []
    # HUD data owns only its measured prefix of this 4 KB bank. Use the
    # remaining bytes for palette lists before spending descriptor storage.
    variables = {(v[0], v[2]) for _, _, _, v in scene.state_hud if v}

    def glyphs(kind, color):
        if kind in ("score2", "game_line", "loop"):
            from game_hud import glyphs as game_glyphs

            return game_glyphs(kind, color)
        if kind.startswith("p2_"):
            kind = kind[3:]
        if kind.startswith("weapon"):
            from weapon_hud import glyphs as weapon_glyphs

            return weapon_glyphs(kind)
        return [(i, color) for i in ([*range(10), 0x24])]

    timer_bytes = 512
    hud_bytes = (
        10 * len(scene.state_hud)
        + 2
        + sum(len(glyphs(kind, color)) * 4 for kind, color in variables)
        + timer_bytes
    )
    palette_at = 0x15000 + ((hud_bytes + 15) & ~15)
    keys = sorted({(k[1], k[2]) for k in offload if k[0] == 3})
    clip = bytearray()
    for x in range(256):
        left = x - 16
        group = left // 4
        width = max(0, (min(224, left + 16) + 3) // 4 - max(0, group)) if -16 < left < 224 else 0
        bits = sum((0 <= group + i < 56) << i for i in range(5))
        clip.extend(
            struct.pack(
                "<hBBBBH",
                group,
                bits,
                int(not 0 <= left <= 208),
                width,
                sum(1 << k for k in {i // 8 for i in range(max(0, group), min(56, group + 5))}),
                max(0, -group),
            )
        )
    for extended in range(2):
        for y in range(256):
            top = 240 - y + extended * 256
            height = max(0, min(256, top + 16) - max(0, top))
            bits = sum((0 <= top + i < 256) << i for i in range(16))
            offset = (top * 56) & 65535
            clip.extend(struct.pack("<hHHBB", top, bits, offset, height, int(not 0 <= top <= 240)))
    from asset_source import Source, derived
    from card_link import alias, asset

    # The HUD templates, then a lookup list for each variable glyph kind,
    # then the weapon timer. region hud-templates of src/card/memory.toml holds them in one 4 KB page.
    hud = Source("HUD templates (scripts/state_scene.py)").section(".rodata.hud_templates")
    hud.label("hud_templates")
    derived("bbr", "hud_templates"), derived("ptr", "hud_templates")  # src/card/hud.s
    variables = sorted({(v[0], v[2]) for _, _, _, v in scene.state_hud if v})
    lookup = {key: f"hud_lookup_{i}" for i, key in enumerate(variables)}
    for handler, (bank, ptr), offset, variable in scene.state_hud:
        assert variable is not None and handler == "native_glyph"
        # Low handler words are grouped-HUD sentinels; all other
        # handlers remain the ordinary native glyph entry.
        if variable[0] == "game_line" and variable[1] in (0, 14):
            handler = 1 if variable[1] == 0 else 2
        elif variable[0] in ("weapon_name0", "p2_weapon_name0"):
            handler = 3 if variable[0] == "weapon_name0" else 4
        elif variable[0] == "game_line" and variable[1] in (8, 22):
            handler = 5 if variable[1] == 8 else 6
        elif variable[0] in ("score", "score2") and variable[1] == 0:
            handler = 7 if variable[0] == "score" else 8
        kind, index, color = variable
        ptr = derived("ptr", lookup[kind, color])
        selector = (
            0x0C60 + (2 + index if kind == "weapon_time" else 0)
            if kind.startswith("weapon")
            else SCORE + (0) + index
        )
        if kind == "game_line":
            selector = 0x2CC0 + index
        elif kind == "loop":
            selector = 0x2CBC + index
        elif kind == "score2":
            selector = 0x2C80 + index
        elif kind.startswith("p2_weapon"):
            selector = 0x2CA0 + (2 + index if kind == "p2_weapon_time" else 0)
        hud.word(handler, bank, ptr, offset, selector)
    hud.word(0)
    from hud_fast import uniform_descriptor

    for kind, color in variables:
        hud.label(lookup[kind, color])
        for code, palette in glyphs(kind, color):
            key = (0, code, palette, 0, 0)
            art = scene.pool.items[key]
            if scene.background_cache and not any(any(row) for row in art.masks):
                hud.word(0, 0)
            else:
                hud.word(*(uniform_descriptor(art, scene) or offload[key]))
    if hasattr(scene, "hud_uniform_descriptors"):
        asset("hud_uniform", scene.hud_uniform_descriptors.source)
    if timer_bytes:
        from weapon_hud import timer_bytes as timer_data

        hud.label("weapon_timer_data").data(timer_data())
        alias("weapon_timer_table", derived("ptr", "weapon_timer_data"))
    assert hud.size == hud_bytes <= 4096
    asset("hud_templates", hud)
    # The sprite cache phase records and directory own $11000-$12EFF; the
    # rest of the old code table stays zero.
    result = [
        (0x12F00, bytes(256)),
        (0x13000, bytes(clip)),
        *palette_chunks,
        *scene.compound_chunks,
    ]
    from hud_energy_cache import prepare as prepare_energy_cache

    prepare_energy_cache(scene)
    from sparse_sprite import install as install_sparse_sprites

    install_sparse_sprites(scene)

    scene.state_lookup_bytes = len(codes) + sum(len(data) for _, data in palette_chunks)
    # These are startup uploads. Adjacent palette lists need one host command,
    # not a repeated upload loop for every resident sprite code.
    uploads = []
    for address, data in sorted(result, key=lambda record: record[0]):
        if (
            uploads
            and uploads[-1][0] + len(uploads[-1][1]) == address
            and len(uploads[-1][1]) + len(data) <= 16384
        ):
            start, previous = uploads[-1]
            uploads[-1] = (start, previous + data)
        else:
            uploads.append((address, data))
    return uploads
