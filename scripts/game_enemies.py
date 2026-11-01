"""Build native stage spawns and path tables from the original US ROM data."""

import struct
from roms import load
from stage_controls import event_tables


def read(bank, address, size):
    rom = load()[0]["maincpu"]
    p = address if address < 0x8000 else 0x10000 + bank * 0x4000 + address - 0x8000
    return rom[p : p + size]


def prepare(out):
    text = ['.segment "GAMEFLOW"']
    roots = []
    giant = []
    quad = []
    for name, bank, address, size in (
        ("launch_deck_paths", 0, 0x4915, 16),
        ("launch_deck_delays", 0, 0x4925, 8),
        ("game_pair_template", 6, 0xAAA5, 32),
        ("game_giant_template", 0, 0x9BCE, 32),
        ("game_pair_turns", 6, 0xAAFE, 96),
        ("game_giant_turns", 0, 0x9D0D, 126),
        ("game_quad_turns", 4, 0xAC80, 32),
        ("game_bonus_template", 0, 0x770C, 32),
        ("game_open_delays", 4, 0xA9A5, 4),
        ("game_open_paths", 4, 0xA9A9, 12),
        ("game_weave_paths", 4, 0xAA75, 14),
        ("game_sweep_sequence", 6, 0xA189, 110),
        ("game_sweep_paths", 6, 0xA1F7, 64),
        ("game_pair_sweep_sequence", 6, 0xAE1E, 110),
        ("game_pair_sweep_paths", 6, 0xAE8C, 64),
        ("game_cross_deltas", 6, 0xA42C, 89),
        ("game_cross_paths", 6, 0xA485, 64),
        ("game_edge_deltas", 6, 0xA78C, 111),
        ("game_edge_paths", 6, 0xA7FB, 64),
        ("game_turning_quad_paths", 6, 0xB183, 64),
        ("game_sway_quad_paths", 4, 0xB193, 64),
        ("game_raid_paths", 0, 0xA1D1, 64),
        ("game_raid_steps", 0, 0xA1A7, 42),
        ("game_raid_spawns", 0, 0x32DA, 8),
        ("game_carrier_giant_paths", 0, 0xA584, 64),
        ("game_carrier_child_template", 0, 0x99A9, 32),
        ("game_carrier_child_paths", 0, 0x9A06, 64),
        ("game_land_quad_paths", 0, 0xB6F9, 32),
        ("game_predict_quad_paths", 0, 0xB872, 32),
        ("game_double_quad_paths", 6, 0x8A5F, 32),
        ("game_double_muzzles", 6, 0x8A16, 64),
        ("game_triple_quad_paths", 6, 0x8684, 6),
        ("game_triple_muzzles", 6, 0x86BF, 18),
        ("game_heavy_bullet_template", 8, 0x3FF9, 32),
        ("game_heavy_bullet_paths", 8, 0x4019, 26),
        ("game_fan_left_paths", 6, 0x9E55, 34),
        ("game_fan_right_paths", 6, 0x9E77, 34),
    ):
        data = read(bank, address, size)
        text += [name + ":", "  .byte " + ",".join(str(v) for v in data)]
    # Native result data: no runtime ROM-format decoding.
    for name, address, size in (("game_difficulty", 0x96A, 64), ("game_refill", 0x4DB4, 48)):
        text += [name + ":", "  .byte " + ",".join(map(str, read(0, address, size)))]
    awards = [p - 0x2397 for p in struct.unpack("<12H", read(0, 0x4DF2, 24))]
    text += [
        "game_result_awards:",
        "  .byte " + ",".join(map(str, awards)),
        "game_continue_awards:",
        "  .byte 7,24,40,48,40",
    ]
    _, stages = event_tables()
    text += [
        "game_retry_events:",
        "  .word " + ",".join(str((row["first_end_offset"] // 6 + 1) * 4) for row in stages),
    ]
    # The arcade converts each nibble of its 8-bit damage ratio separately.
    nibble = read(1, 0x923B, 16)
    text += [
        '.segment "GAMEPLAY"',
        "game_damage_percent:",
        "  .byte " + ",".join(str(10 * nibble[q >> 4] + nibble[q & 15]) for q in range(256)),
        '.segment "GAMEFLOW"',
    ]
    roots.extend((0, p) for p in struct.unpack("<8H", read(0, 0x4915, 16)))
    roots.extend(((0, 0x49C9), (0, 0x4A41)))
    roots.extend((6, int.from_bytes(read(6, 0xAAFF + 3 * i, 2), "little")) for i in range(32))
    roots.extend(((6, 0xACF6), (0, 0x772C), (6, 0x99E6)))
    giant.extend((0, p) for p in struct.unpack("<63H", read(0, 0x9D0D, 126)))
    giant.extend((0, p) for p in (0x9C25, 0x9C44, 0x9C63, 0x9F4F, 0x9F52))
    quad.extend((4, p) for p in struct.unpack("<16H", read(4, 0xAC80, 32)))
    quad.append((4, 0xACA0))
    quad.extend((4, int.from_bytes(read(4, 0xA9AA + 3 * i, 2), "little")) for i in range(4))
    quad.extend((4, p) for p in struct.unpack("<7H", read(4, 0xAA75, 14)))
    quad.extend((4, p) for p in (0xAF6B, 0xAF7C, 0xAF9B, 0xAFBA))
    roots.extend((8, p) for p in (0x5ADD, 0x5B25, 0x5F33, 0x5F74, 0x6FBC, 0x736D, 0x7585, 0x75FD))
    for address in (0xA1F7, 0xAE8C, 0xA485, 0xA7FB):
        roots.extend((6, p) for p in struct.unpack("<32H", read(6, address, 64)))
    for address in (0x9E55, 0x9E77):
        roots.extend((6, p) for p in struct.unpack("<17H", read(6, address, 34)))
    roots.extend((6, p) for p in (0x9E99, 0x9EAA))
    for bank, address, count in (
        (4, 0xB193, 32),
        (6, 0xB183, 32),
        (0, 0xB6F9, 16),
        (0, 0xB872, 16),
        (6, 0x8A5F, 16),
        (6, 0x8684, 3),
    ):
        quad.extend(
            (bank, p) for p in struct.unpack("<%dH" % count, read(bank, address, count * 2))
        )
    giant.extend((0, p) for p in struct.unpack("<32H", read(0, 0xA584, 64)))
    giant.extend(((0, 0xA5C4), (0, 0xA6E5), (0, 0xA321), (0, 0xA431)))
    giant.extend((0, p) for p in struct.unpack("<32H", read(0, 0xA1D1, 64)))
    roots.extend((0, p) for p in struct.unpack("<32H", read(0, 0x9A06, 64)))
    roots.extend(((0, 0x9A46), (0, 0x9A50)))
    roots.extend((8, p + 7) for p in struct.unpack("<13H", read(8, 0x4019, 26)))
    roots.extend(((4, 0xA1D6), (4, 0xA1FD), (8, 0x6623)))
    from air_boss import prepare as prepare_air

    roots.extend(prepare_air(out))
    text.append('.segment "GAMEPLAY"')
    (out / "game_enemy_data.inc").write_text("\n".join(text) + "\n")
    return roots, quad, giant


def stage_roots(stage):
    """Only the stage's reachable spawn templates; AI continuations are added separately."""
    from simple_spawns import collect
    from extended_spawns import collect as extended
    from medium_enemies import SPAWNS

    tables, meta = event_tables()
    table = tables[stage]
    simple = collect()
    ext = extended()
    result = []
    quads = []
    for i in range(0, meta[stage]["final_end_offset"] + 1, 6):
        _, p, b, _ = struct.unpack_from("<HHBB", table, i)
        b = b // 4 if p >= 0x8000 else 0
        records = [(0, d) for _, d in simple.get((b, p), [])]
        records.extend((kind, d) for kind, flags, d in ext.get((b, p), []))
        if p in SPAWNS and SPAWNS[p][0] == b:
            records.append((0, read(b, SPAWNS[p][1], 32)))
        for kind, data in records:
            target = (b, int.from_bytes(data[30:32], "little") + 7)
            result.append(target)
            death = int.from_bytes(data[28:30], "little")
            if death and death != 65535:
                result.append((b, death + 7))
            if kind in (1, 2):
                quads.append(target)
    return result, quads
