"""Live native input -> flight -> commands -> DMA1 -> scrolling Oak component."""

import json
import struct
import time

from arcade import Arcade, ROOT
from flight import prepare_tables
from harness import Host
from machine_gate import check
from native_sprites import swap
from playfield import assets, build_kernel, GROUPS

UPDATES = 120
INITIAL_CAMERA = 1000


def build():
    check("build")
    started = time.perf_counter()
    folder = "native-contact-loop"
    out = ROOT / "build/game"
    out.mkdir(parents=True, exist_ok=True)
    a = Arcade()
    from game_palette import merge

    merge(a, out)
    atlas, table, tiles = assets(a, 0)
    # The native scrolling kernel returns immediately from legacy new_row.
    # Its startup atlas is unreachable; all sea art is game_water/game_sea.
    atlas = b""
    from game_art import GameArtPool, SpriteCache

    pool = GameArtPool(a, len(atlas))
    # Cabinet shares the gameplay water pattern; reclaim its old image.
    pool.free.append([0x40000, 0x41E00])
    pool.free = [
        ([lo + 4096, hi] if lo in (0x1C000, 0x3C000) else [lo, hi]) for lo, hi in pool.free
    ]
    # The handoff disables Apple video emulation. Page 0 starts at group
    # $0400 and page 1 at $8400, leaving both alignment prefixes free.
    pool.free.insert(0, [0, 0x1000])
    pool.free.insert(1, [0x20000, 0x21000])
    pool.free.append([0x44000, 0x5C000])
    pool.fixed_character_positions = True
    energy_chars = {}
    from native_foreground import prepare, compile_rows, FG_BANK, CHAR_BANK
    from state_scene import StateScene

    scene = StateScene(a, [], pool, False, background_cache=True)
    scene.extra_object_sram = True
    scene.compound_objects = False
    scene.weapon_hud = True
    scene.quiet_art = False
    scene.quiet_blocks = False
    scene.foreground_vram_rows = True
    from game_world import initial_state, hud_commands

    initial_camera, foreground_initial, camera, initial = initial_state()
    ram = bytes(0x3000)
    commands = hud_commands()
    scene.continuous = True
    scene.game_scroll = True
    config = prepare(scene, pool, foreground_initial, UPDATES)
    scene.sprite_cache = SpriteCache(scene)
    chars = [v for v in commands if v[0] == "char" and any(a.gfx[0][v[2] % len(a.gfx[0])])]
    chars = [v for v in chars if not (v[5] == 240 and v[6] in range(0, 64, 8))]
    score_char_start = len(chars)
    chars.extend(("char", 0, 0x24, 0, 0, 240, i * 8) for i in range(8))
    for digit in range(10):
        pool.get(("char", 0, digit, 0, 0, 0, 0))
    weapon_chars = {}
    from weapon_hud import glyphs

    # Original D060..D140 labels, D1A0/D1C0 countdown. Upright row 248.
    for slot in range(8):
        weapon_chars[len(chars)] = (f"weapon_name{slot}", 0, 0)
        chars.append(("char", 0, 0x24, 0, 0, 0, 8 + 8 * slot))
    for slot in range(2):
        weapon_chars[len(chars)] = ("weapon_time", slot, 7)
        chars.append(("char", 0, 0x24, 7, 0, 0, 88 + 8 * slot))
    for kind, _, color in weapon_chars.values():
        for code, palette in glyphs(kind):
            pool.get(("char", 0, code, palette, 0, 0, 0))
    scene.weapon_characters = weapon_chars
    for cmd in chars:
        pool.get(cmd)
    energy_chars = {
        i: cmd[6] // 8 for i, cmd in enumerate(chars) if cmd[5] == 8 and 0 <= cmd[6] < 64
    }
    assert len(energy_chars) == 8
    for color in (0, 2, 4):
        for code in range(0x80, 0x89):
            pool.get(("char", 0, code, color, 0, 0, 0))
    from game_hud import prepare as prepare_game_hud

    prepare_game_hud(scene, pool, chars, energy_chars)
    # Two 64x8 opaque bars, independent of both display pages.
    from hud_energy_cache import reserve as reserve_energy_cache

    scene.energy_cache = reserve_energy_cache(pool)
    scene.packed_masks = True
    assert 0 <= initial_camera and initial_camera + UPDATES + 256 <= 4096
    scene.sea_window_rows = 4096
    scene.camera_start = initial_camera
    scene.times_base = 0x2C00
    scene.cadence_offset = 0x200
    scene.camera_updates = []
    for code in range(0x20, 0x2A):
        pool.get(("sprite", 3, code, 0, 0, 0, 0))
    from player_death import prepare as prepare_death

    death_frames = prepare_death(out)
    death_codes = {base + offset for base in death_frames[1:-1:2] for offset in (0, 1, 8, 9)}
    # Death can start in a busy wave. Its complete art stays resident;
    # it never depends on a transfer during the animation.
    for code in sorted(death_codes):
        pool.get(("sprite", 3, code, 0, 0, 0, 0))
    from gun import prepare as prepare_gun
    from projectiles import prepare as prepare_shots

    prepare_gun(out)
    prepare_shots(out)
    for code in (0x3F, 0xA5, 0xA6, 0xA7):
        pool.get(("sprite", 3, code, 9, 0, 0, 0))
    from weapons import prepare as prepare_weapons

    weapon_meta = prepare_weapons(out)
    for code in weapon_meta["sprite_codes"]:
        pool.get(("sprite", 3, code, 9, 0, 0, 0))
    from weapon_timer import prepare as prepare_timer

    prepare_timer(out)
    from player_aux import prepare as prepare_aux

    prepare_aux(out)
    for code in (*range(0x2A, 0x2F), *range(0x30, 0x3F), *range(0xA8, 0xB0)):
        pool.get(("sprite", 3, code, 0, 0, 0, 0))
    for code in (*range(0x2A, 0x2F), *range(0x3A, 0x3F)):
        pool.get(("sprite", 3, code, 9, 0, 0, 0))
    for code in (*range(0x20, 0x2F), *range(0x30, 0x3F), *range(0xA8, 0xB0)):
        pool.get(("sprite", 3, code, 1, 0, 0, 0))
    for code in sorted(death_codes):
        pool.get(("sprite", 3, code, 1, 0, 0, 0))
    for code, color in [(0x200, 6), (0x200, 7), *((code, 9) for code in range(0xB0, 0xB8))]:
        pool.get(("sprite", 3, code, color, 0, 0, 0))
    from enemy_script import prepare_data
    from enemy_ai import prepare as prepare_ai
    from waves import prepare as prepare_waves
    from roms import load

    regions, _ = load()
    program = regions["maincpu"]
    pool.get(("sprite", 3, 0, 0, 0, 0, 0))  # Active spawn-delay records use code zero.
    destinations = (
        0x8A92,
        0x8B93,
        0x8A81,
        0x8B82,
        0x8B0A,
        0x8C12,
        0x8AA3,
        0x8BA4,
        0x8B67,
        0x8C6F,
        0x8B56,
        0x8C5E,
        0x8D3A,
        0x8E32,
        0x8CFC,
        0x8DF4,
        0x8AF9,
        0x8C01,
        0x8AE8,
        0x8BF0,
        0x8CBE,
        0x8DB6,
        0x8C80,
        0x8D78,
    )
    roots = [(0, p) for p in (*destinations, 0x8A77, 0x8B7F, 0x5A3B, 0x5A53, 0x5A8C)]
    roots.extend(
        (6, int.from_bytes(program[0x29B0B + i : 0x29B0D + i], "little")) for i in range(0, 96, 3)
    )
    roots.append((6, 0x9BF2))
    from medium_enemies import prepare as prepare_medium

    medium_roots = prepare_medium(out)
    from simple_spawns import prepare as prepare_simple

    simple_roots = prepare_simple(out)
    from formation_enemies import prepare as prepare_formations

    formation_roots = prepare_formations(out)
    from extended_spawns import prepare as prepare_extended

    extended_roots = prepare_extended(out)
    from ground_enemies import prepare as prepare_ground

    ground_roots = prepare_ground(out)
    roots.extend(medium_roots)
    from pickups import prepare as prepare_pickups

    roots.extend(prepare_pickups(out))
    from enemy_bullets import prepare as prepare_bullets

    pointers = prepare_bullets(out)
    roots.extend((0, p + 7) for p in pointers)
    roots.append((0, 0x3DAA))
    large_art = set()
    from large_enemies import prepare as prepare_large

    large_roots = prepare_large(out)
    from ship_enemies import prepare as prepare_ship, prepare_target

    ship_roots = prepare_ship(out, patterns=None)
    prepare_target(out)
    roots.extend(ship_roots)
    from ship_turrets import prepare as prepare_turrets

    turret_roots = prepare_turrets(out)
    _, turret_meta = prepare_data(out, [], turret_roots)
    roots.extend(turret_roots)
    large_art.update(
        (code + offset, color) for code, color in turret_meta["art_keys"] for offset in (0, 1, 8, 9)
    )
    propeller_keys = {
        (code + offset, pair) for code, pair in turret_meta["flips"] for offset in (0, 1, 8, 9)
    }
    core_roots = large_roots + [(8, 0x5EA9), (8, 0x5EE2)]
    _, core_meta = prepare_data(out, [], core_roots)
    large_art.update(
        (code + offset, color) for code, color in core_meta["art_keys"] for offset in (0, 1, 8, 9)
    )
    propeller_keys.update(
        (code + offset, pair) for code, pair in core_meta["flips"] for offset in (0, 1, 8, 9)
    )
    roots.extend(core_roots)
    from ship_finish import prepare as prepare_finish

    finish = prepare_finish(out)
    _, giant_meta = prepare_data(out, [], [(8, 0x663B), (8, 0x6674)])
    large_art.update(
        (code + row * 8 + col, color)
        for code, color in giant_meta["art_keys"]
        for row in range(4)
        for col in range(4)
    )
    propeller_keys.update(
        (code + row * 8 + col, pair)
        for code, pair in giant_meta["flips"]
        for row in range(4)
        for col in range(4)
    )
    roots.extend(finish["roots"])
    from game_enemies import prepare as prepare_game_enemies, stage_roots

    extra, quads, giants = prepare_game_enemies(out)
    reachable = []
    spawn_quads = []
    for stage in range(16):
        stage_paths, stage_quads = stage_roots(stage)
        reachable.extend(stage_paths)
        spawn_quads.extend(stage_quads)
    roots.extend(reachable + extra + quads + giants + [(0, 0x7683)])
    roots.extend(ground_roots + formation_roots)
    stage_large_roots = core_roots
    roots.extend(stage_large_roots)
    # Every stage's native paths, including all ship and aircraft cores.
    _, extra_large = prepare_data(out, [], quads + spawn_quads + stage_large_roots)
    large_art.update(
        (code + offset, color) for code, color in extra_large["art_keys"] for offset in (0, 1, 8, 9)
    )
    propeller_keys.update(
        (code + offset, pair) for code, pair in extra_large["flips"] for offset in (0, 1, 8, 9)
    )
    _, extra_giant = prepare_data(out, [], giants)
    large_art.update(
        (code + row * 8 + col, color)
        for code, color in extra_giant["art_keys"]
        for row in range(4)
        for col in range(4)
    )
    propeller_keys.update(
        (code + row * 8 + col, pair)
        for code, pair in extra_giant["flips"]
        for row in range(4)
        for col in range(4)
    )
    wave_scripts, wave_meta = prepare_data(out, [], roots)
    # The pieces of the object of each record, for the propeller palettes.
    quad, giant = (0, 1, 8, 9), tuple(row * 8 + col for row in range(4) for col in range(4))
    script_pieces = {}
    for script_meta, offsets in (
        (turret_meta, quad),
        (core_meta, quad),
        (extra_large, quad),
        (giant_meta, giant),
        (extra_giant, giant),
    ):
        script_pieces.update(dict.fromkeys(script_meta["records"], offsets))
    from propellers import rom_keys
    from game_palette import UNDRAWN_SPRITE_PENS

    drawn = large_art | set(wave_meta["art_keys"])
    for code, color in drawn:
        tile = scene.a.gfx[3][code % 2048]
        assert not any((color, pen) in UNDRAWN_SPRITE_PENS for pen in set(tile)), (
            "a drawn sprite uses a pen that game_palette frees",
            hex(code),
            color,
        )

    propeller_keys.update(wave_meta["flips"])
    propeller_keys.update(rom_keys(program, {code for code, color in wave_meta["art_keys"]}))
    scene.sprite_cache.set_propellers(propeller_keys)
    (out / "propellers.json").write_text(
        json.dumps(
            {f"{c:03x}": sorted(p) for c, p in sorted(scene.sprite_cache.prop_codes.items())},
            indent=1,
        )
        + "\n"
    )
    for code, color in wave_meta["art_keys"]:
        pool.get(("sprite", 3, code, color, 0, 0, 0))
    prepare_waves(out)
    ai_install = prepare_ai(out)
    stage_data = program[0x18008:0x186AA]
    (out / "stage_data.inc").write_text(
        "stage_events:\n"
        + "\n".join(
            "  .byte " + ",".join(f"${v:02x}" for v in stage_data[i : i + 18])
            for i in range(0, len(stage_data), 18)
        )
        + "\n"
    )
    for code, color in sorted(large_art):
        pool.get(("sprite", 3, code, color, 0, 0, 0))
    scene.compound_objects = bool(not scene.foreground_primary and False)
    scene.compound_keys = {tuple(k) for k in core_meta["art_keys"]}
    scene.build_out = out
    scene.rect_foreground = False
    scene.sprite_program_weights = {code: 16 for code, color in large_art}
    from repair_core import reserve as reserve_repair_core

    reserve_repair_core(scene, pool)
    mode = build_kernel(out, "vga-224x256-roomy", UPDATES, initial_camera, scene)
    from native_sprites import object_packets

    offload = object_packets(pool, scene)
    sprite_bank = 0x32
    meta = {"native_code_bytes": 0, "sprite_planner_cpu": "Z180"}
    prepare_tables(out)
    meta["trimmed_art_bytes"] = pool.trimmed_art_bytes
    meta["reclaimed_background_sram_bytes"] = getattr(scene, "reclaimed_background_sram_bytes", 0)
    from native_sprites import compile_hud

    meta["characters"] = compile_hud(
        out,
        chars,
        offload,
        CHAR_BANK,
        score_char_start,
        energy_chars,
        pool=pool,
        scene=scene,
        static_pairs=False,
    )
    from cabinet_video import prepare_fast_demo

    prepare_fast_demo(scene, pool)
    scene.sprite_cache.reserve()
    assert len(scene.sprite_cache.slots) == scene.sprite_cache.requested_slots
    from hitch_scene import preservation_jobs, place_preservation_jobs

    place_preservation_jobs(scene, preservation_jobs(scene))
    from special_wave import reserve_bolts

    reserve_bolts(scene, pool)
    from hitch_stage import prepare as prepare_hitch_stage

    prepare_hitch_stage(scene, pool)
    from special_wave import prepare as prepare_special_wave

    prepare_special_wave(scene, pool)
    include = [
        f"FLIGHT_UPDATES = {UPDATES}",
        f"FLIGHT_INITIAL_CAMERA = {initial_camera}",
        f"FLIGHT_LAYERS = {1}",
        f"FLIGHT_GUN = {1}",
        f"FLIGHT_DOC = {1}",
        f"FLIGHT_COMBAT = {1}",
        "Z_SCENE_DMA_BE = ((card_scene_dma & $FF) << 8) | (card_scene_dma >> 8)",
    ]
    include.extend(
        (f"FLIGHT_WAVES = {1}", f"FLIGHT_OBJECTS = ${0x5400:04x}", f"FLIGHT_BOUNDS = ${0x5800:04x}")
    )
    include.append(f"FLIGHT_BULLETS = {1}")
    include.append(f"FLIGHT_WEAPONS = {1}")
    include.append(f"FLIGHT_PLAYER_AUX = {1}")
    include.append(f"FLIGHT_CONTACT = {1}")
    include.append("ALL_STAGE_ENEMIES = 1\nFORMATION_ENEMIES = 1" + "")
    include.append("NATIVE_LARGE_OBJECTS = 1\nEXTENDED_STAGE_ENEMIES = 1" + "")
    include.append("BANK6_TURRETS = 1")
    include.append("SHIP_ENEMIES = 1\nGIANT_ENEMIES = 1\nLARGE_TARGET = large_target_far")
    include.append(f"FLIGHT_DEATH = {1}")
    include.append("FLIGHT_ART_STREAM = 0")  # Stage-scheduled streaming is separate.
    include.append("COMBINED_BOUNDS = 1")
    include.append(f"SPRITE_PLAN = ${sprite_bank << 16:06x}")
    include.extend(
        (
            "COMPACT_RESTORE = 1",
            "Z_RESTORE_BEGIN_BE = ((card_restore_begin & $FF) << 8) | (card_restore_begin >> 8)",
        )
    )
    restore_names = [f"restore_{n}" for n in range(1, 6)]
    include.extend(
        (
            "flight_restore_vectors:",
            "  .word "
            + ",".join(f"((card_{name} & $FF) << 8) | (card_{name} >> 8)" for name in restore_names),
        )
    )
    host = Host(out)
    host.compressed_uploads = True
    host.emit("STREAM_POLL_INPUT = 1")
    host.stream_startup = True
    host.card_startup = []
    host.boot_segments = True
    host.production_world_reuse = True
    host.emit("PRODUCTION_WORLD_REUSE = 1")
    host.production_sound_reuse = True
    host.production_lc_reuse = True
    host.emit("PRODUCTION_LC_WORLD = 1")
    host.emit(
        "CONTINUOUS_GAME = 1\n  rep #$20\n  lda #0\n  sta f:$050320\n  sta f:$050300\n  lda #$1943\n  sta f:$05032c\n  lda #$e6bc\n  sta f:$05032e\n  sep #$20"
    )
    host.emit("STATE_ONLY = 1")
    from stage_controls import install as install_stages

    meta["stage_tables"] = install_stages(out, host, enemy_spawns=True)
    from pool_ticks import prepare as prepare_pool_ticks

    prepare_pool_ticks(out)
    from enemy_script import prepare_data
    from camera import prepare as prepare_camera
    from score import prepare as prepare_score

    prepare_camera(out)
    prepare_score(out)
    include.append(f"SCORE_CHAR_OFFSET = {score_char_start * 8}")
    meta["score_char_start"] = score_char_start
    wave_scripts(host, scene.sprite_cache.prop_codes, script_pieces)
    ai_install(host)
    meta["enemy_scripts"] = {k: v for k, v in wave_meta.items() if k != "records"}
    template = bytes(32)
    (out / "combat_data.inc").write_text(
        "combat_enemy_template:\n  .byte " + ",".join(f"${v:02x}" for v in template) + "\n"
    )
    from game_audio import prepare as prepare_audio

    meta["audio_integrated"] = prepare_audio(out, host)
    from bullet_contact import prepare as prepare_contact

    prepare_contact(out)(host)
    hud = bytes(ram[base + i * 32] for base in (0x1041, 0x1441, 0x1201, 0x1601) for i in range(14))
    with (out / "energy_data.inc").open("w") as f:
        f.write("contact_initial_hud:\n  .byte " + ",".join(str(v) for v in hud) + "\n")
        f.write(
            "energy_character_offsets:\n  .word "
            + ",".join(
                str(next(i for i, slot in energy_chars.items() if slot == n) * 8) for n in range(8)
            )
            + "\n"
        )
    meta["energy_character_slots"] = energy_chars
    host.palette(a.palette)
    from card_link import Block

    import card_layout

    host.deferred_card_sram = {lo: Block(hi - lo) for lo, hi in card_layout.memory_map()["staged"]}
    pool.install()
    for off in range(0, len(table), 16384):
        host.upload(0x110000 + off, table[off : off + 16384])
    scene.sprite_cache.install(host)
    from game_water import install as install_water

    install_water(host, a, scene)

    # $2D00 is the previous page dirty-row list in the combined renderer.
    host.upload(0x102E20, bytes(1 << i for i in range(8)))
    lookups = (
        bytes((i * GROUPS) & 255 for i in range(256))
        + bytes((i * GROUPS) >> 8 for i in range(256))
        + bytes(((~i) & 31) * 8 for i in range(256))
    )

    lookups = bytearray(lookups)
    for mask in range(128):
        bits = [i for i in range(7) if mask & (1 << i)]
        lookups[0x220 + mask] = min(bits) | (max(bits) + 1) << 4 if bits else 0
    host.upload(0x103000, lookups)
    host.emit("  sep #$20\n  lda #0\n  pha\n  plb")
    from native_foreground import runs

    meta.update(compile_rows(out, host, scene, config))
    records = b"".join(
        struct.pack("<HHhh", code, color, y, 248 - x) for _, _, code, color, _, x, y in chars
    )
    source = host.blob_at(records, "character_records")
    host.emit(
        f"  rep #$30\n  ldx #.loword({source.label})\n  ldy #$1600\n  lda #{len(records) - 1}\n  mvn #^{source.label},#$00"
    )
    damage = [[0] * 56 for _ in range(256)]
    for cmd in chars:
        art = pool.get(cmd)
        left = cmd[6] // 4
        top = 248 - cmd[5]
        if (
            (cmd[5] == 240 and cmd[6] in range(0, 64, 8))
            or (cmd[5] == 8 and cmd[6] in range(0, 64, 8))
            or cmd in [chars[i] for i in weapon_chars]
            or cmd in [chars[i] for i in getattr(scene, "game_characters", {})]
        ):
            for y in range(8):
                for x in range(2):
                    damage[top + y][left + x] = 15
            continue
        for y, row in enumerate(art.masks):
            for x, mask in enumerate(row):
                if 0 <= top + y < 256 and 0 <= left + x < 56:
                    damage[top + y][left + x] |= mask
    restore = []
    for y, row in enumerate(damage):
        spans = []
        for x, n, _ in runs([15 if m else 0 for m in row]):
            if spans and x - spans[-1][1] <= 16:
                spans[-1][1] = x + n
            else:
                spans.append([x, x + n])
        restore.extend((y * 56 + x, end - x) for x, end in spans)
    host.blob_at(b"".join(struct.pack("<HH", x, swap(n)) for x, n in restore), "HUD_RESTORE")
    from restore_kernel import merge_hud_runs

    from asset_source import Source, derived
    from card_link import alias, asset

    runs = Source("HUD restore runs (scripts/flight_loop.py)").section(".desc.hud_restore_runs")
    runs.code(["        .balign 2"]).label("hud_restore_runs")
    for x, n in merge_hud_runs(restore):
        runs.word(x, n)
    runs.fill(4)
    assert runs.size <= 4096
    asset("hud_restore_runs", runs)
    alias("state_hud_restore_bbr", derived("bbr", "hud_restore_runs"))
    alias("state_hud_restore_address", derived("ptr", "hud_restore_runs"))
    host.emit("  sep #$20")
    include.extend(
        (
            "COMPACT_HUD_RESTORE = 1",
            "Z_HUD_RESTORE_BE = ((card_hud_restore & $FF) << 8) | (card_hud_restore >> 8)",
            "HUD_RESTORE_BANK_BE = ((card_hud_restore_runs__bbr & $FF) << 8) | (card_hud_restore_runs__bbr >> 8)",
            "HUD_RESTORE_POINTER_BE = ((card_hud_restore_runs__ptr & $FF) << 8) | (card_hud_restore_runs__ptr >> 8)",
        )
    )
    meta["resident_hud_restore_bytes"] = runs.size
    from special_wave import install_draw

    install_draw(scene, host)
    from state_scene import tables

    for address, data in tables(scene, offload):
        host.upload(0x100000 + address, data)
    scene.sprite_cache.install_directory(host)
    planner = card_layout.region("state-planner")
    meta.update(
        state_packet_bytes=f"{26} + 4 per active object" + "",
        card_planner_bytes=planner["limit"] - planner["run"],
        state_only_packets=True,
        receive_drawing_overlap=True,
        card_state_lookup_bytes=scene.state_lookup_bytes,
    )
    include.extend(
        (
            f"FLIGHT_FG_INITIAL = {foreground_initial}",
            f"FG_PLAN = ${FG_BANK << 16:06x}",
            f"CHAR_PLAN = ${CHAR_BANK << 16:06x}",
            f"CHAR_COUNT = {len(chars)}",
            f"HUD_RESTORE_COUNT = {len(restore)}",
        )
    )
    (out / "character-records.bin").write_bytes(records)
    meta.update(
        foreground_initial=foreground_initial,
        character_records=len(chars),
        character_state="Original-US HUD layout with native score and P1 energy glyphs",
    )
    host.blob_at(struct.pack("<512H", *(i * 56 for i in range(512))), "FLIGHT_ROW_TABLE")
    (out / "flight_draw.inc").write_text("\n".join(include) + "\n")
    camera[:2] = initial_camera.to_bytes(2, "little")
    camera[15:17] = foreground_initial.to_bytes(2, "little")
    host.blob_at(camera, "combat_camera")
    host.emit("""  sep #$20
  lda #0
  pha
  plb
  rep #$30
  ldx #36
combat_camera_copy:
  lda f:combat_camera,x
  sta a:$1140,x
  dex
  dex
  bpl combat_camera_copy""")
    host.blob_at(initial, "flight_initial")
    host.emit("""  sep #$20
  lda #0
  pha
  plb
  rep #$30
  ldx #126
flight_initial_copy:
  lda f:flight_initial,x
  sta a:$1000,x
  dex
  dex
  bpl flight_initial_copy
  sep #$20
  lda #0
  pha
  plb""")
    seed = bytes((1, 0, 0, 0, 0, 0, 0, 0))
    frame = 0
    host.blob_at(seed, "bullet_seed")
    host.emit("""  rep #$20
  ldx #6
bullet_seed_copy:
  lda f:bullet_seed,x
  sta a:$11c8,x
  dex
  dex
  bpl bullet_seed_copy
  sep #$20""")
    meta["random_seed_frame"] = frame
    meta["random_seed"] = seed.hex()
    from playfield import finish_entry

    finish_entry(out, host, scene)
    from game_audio import install as install_audio

    install_audio(host)
    host.emit("  jsr doc_init")
    host.run(0x400, wait=False)
    host.emit("  jsr flight_loop")
    host.emit("NATIVE_STAGE_FLOW = 1")
    host.routines = [
        '.include "input.s"',
        '.include "flight.s"',
        '.include "stream.s"',
        '.include "flight_loop.s"',
    ]
    host.routines.insert(0, '.include "game_world.inc"')
    host.split_native = True
    host.routines += [
        "GUN_OVERFLOW = $1d00",
        '.include "gun.s"',
        '.include "projectiles.s"',
        '.include "flight_weapons.s"',
        '.include "gun_data.inc"',
        '.include "shot_data.inc"',
    ]
    host.routines = [
        r for r in host.routines if r not in ('.include "gun.s"', '.include "gun_data.inc"')
    ]
    host.gameplay_bank = True
    host.emit("WEAPON_FAR = 1")
    host.routines += [
        "SHOTS = $1800",
        "GUN_SOUND = $17f0",
        '.include "weapon_data.inc"',
        '.segment "GAMEPLAY"',
        '.include "weapons.s"',
        '.segment "NATIVE"',
    ]
    host.emit(
        "PLAYER_AUX_FAR = 1\nWEAPON_TIMER_FAR = 1\nWEAPON_TIMER_STATE_ONLY = 1\nPLAYER_CONTACT_FAR = 1\nENEMY_SPECIAL_CONTACT = 1\nENEMY_RETIRE_X = $17d1"
    )
    host.routines += [
        '.include "player_aux_data.inc"',
        '.segment "GAMEPLAY"',
        '.include "player_aux.s"',
        '.include "weapon_timer.s"',
        '.include "player_contact.s"',
        '.include "player_core.s"',
        '.include "pickups.s"',
        '.include "pickup_data.inc"',
        '.segment "NATIVE"',
        '.include "player_live.s"',
    ]
    host.routines += [
        '.segment "GAMEPLAY"',
        '.include "medium_data.inc"',
        '.include "medium_spawn.s"',
        '.include "simple_spawn_data.inc"',
        '.include "simple_spawn.s"',
        '.include "formation_data.inc"',
        '.segment "NATIVE"',
    ]
    host.routines += [
        '.segment "GAMEPLAY"',
        '.include "extended_spawn_data.inc"',
        '.include "extended_spawn.s"',
        '.include "ground_data.inc"',
        '.include "large_data.inc"',
        '.include "large_spawn.s"',
        '.include "large_object.s"',
        '.include "large_ai.s"',
        '.include "large_contact.s"',
        '.include "large_loop.s"',
        '.segment "NATIVE"',
        '.include "large_bridge.s"',
    ]
    host.routines += [
        '.segment "GAMEPLAY"',
        '.include "ship_data.inc"',
        '.include "ship_spawn.s"',
        '.include "large_aircraft.s"',
        '.include "large_target.inc"',
        '.segment "NATIVE"',
    ]
    host.routines += [
        '.segment "GAMEPLAY"',
        '.include "turret_data.inc"',
        '.include "ship_turrets.s"',
        '.include "turret_spawn.s"',
        '.include "turret_bullet.s"',
        '.segment "NATIVE"',
    ]
    host.routines += [
        '.segment "GAMEPLAY"',
        '.include "ship_finish_data.inc"',
        '.include "ship_finish.s"',
        '.include "giant_object.s"',
        '.segment "NATIVE"',
    ]
    host.routines += [
        '.segment "GAMEPLAY"',
        '.include "stage_controls.inc"',
        '.include "stage_controls.s"',
        '.include "stage_flow.s"',
        '.segment "NATIVE"',
    ]
    from game_audio import routines as audio_routines

    host.routines += audio_routines()
    host.routines += [
        '.include "combat.s"',
        '.include "enemy_motion.s"',
        '.include "enemy_script.s"',
        '.include "enemy_collision.s"',
        '.include "enemy_script_data.inc"',
        '.include "combat_data.inc"',
        '.include "camera.s"',
        '.include "camera_data.inc"',
        '.include "score.s"',
        '.include "score_data.inc"',
    ]
    host.native_limit = 0x3000
    host.routines += [
        '.include "enemy_ai.s"',
        '.include "enemy_ai_data.inc"',
        '.include "waves.s"',
        '.include "wave_data.inc"',
        '.include "stage_data.inc"',
        '.include "stage.s"',
        '.include "wave_combat.s"',
    ]
    host.routines += [
        '.include "random.s"',
        '.include "enemy_bullets.s"',
        '.include "bullet_data.inc"',
        '.include "bullet_motion.s"',
        '.include "bullet_loop.s"',
    ]
    host.routines += [
        '.include "energy_data.inc"',
        '.include "bullet_contact.s"',
        '.include "contact_loop.s"',
    ]
    host.routines += [
        '.include "death_data.inc"',
        '.include "player_death.s"',
        '.include "death_loop.s"',
    ]
    from pool_ticks import SOURCES

    host.routines = [
        r for r in host.routines if r not in [f'.include "{name}.s"' for name in SOURCES]
    ]
    host.routines = [
        r.replace('"wave_combat.s"', '"wave_combat_direct.inc"').replace(
            '"bullet_loop.s"', '"bullet_loop_direct.inc"'
        )
        for r in host.routines
    ]
    host.routines += ['.include "pool_ticks.inc"']
    host.gameplay_bank = True
    host.routines += [
        '.segment "GAMEPLAY"',
        '.include "state_packet.s"',
        '.segment "NATIVE"',
        '.include "state_packet_bridge.s"',
    ]
    from live_players import prepare as prepare_live_players

    prepare_live_players(out)
    host.routines = [
        r.replace('"flight.s"', '"live_flight.inc"').replace(
            '"player_core.s"', '"live_player_core.inc"'
        )
        for r in host.routines
    ]
    host.routines += [
        '.segment "SPECIAL"',
        '.include "special_loop.s"',
        '.segment "NATIVE"',
        '.include "game_players.s"',
    ]
    host.routines += [
        '.segment "GAMEPLAY"',
        '.include "game_enemy_data.inc"',
        '.include "game_enemies.s"',
        '.segment "NATIVE"',
    ]
    host.flow_bank = True
    host.routines += [
        '.segment "CABDATA"',
        '.include "cabinet_data.inc"',
        '.segment "GAMEFLOW"',
        '.include "game_flow.s"',
        '.include "game_world.s"',
        '.include "cabinet.s"',
        '.include "live_launch.inc"',
        '.include "player_continue.s"',
        '.segment "NATIVE"',
    ]
    host.routines += ['.segment "INPUT"', '.include "hitch_stage.s"', '.segment "NATIVE"']
    from input_stack import reserve as reserve_input

    reserve_input(host)
    host.special_code_size = 0xA00
    # Code runs in one bank: the 65816 program counter wraps inside its bank.
    host.special_code_source = host.blob_at_bank(bytes(host.special_code_size), "special_code")
    # Cabinet tables use long-address reads or explicit banked pointers.
    host.cabinet_data_size = 0x800
    host.cabinet_data_source = host.blob_at_bank(bytes(host.cabinet_data_size), "cabinet_data")
    from packed_art import build as pack_art

    packed = ROOT / "build/packed-art"
    packed_meta = pack_art(packed)
    resident = {}
    names = ()
    meta["compact_host"] = dict(
        art=resident,
        art_bytes=sum(v["bytes"] for v in resident.values()),
        startup_raw_bytes=getattr(host, "startup_raw_bytes", 0),
        startup_packed_bytes=getattr(host, "startup_packed_bytes", 0),
        startup_scratch=[0x18000, 0x1C000],
        highest_host_address=0x20000 + len(host.blob),
    )
    meta["compact_host"]["video_bank_bytes"] = sum(map(len, getattr(host, "slow_blobs", [])))
    assert 0x20000 + len(host.blob) <= 0x100000, meta["compact_host"]
    from special_wave import install as install_special_wave

    install_special_wave(scene, host)
    from card_link import after_link
    from display_control import install as install_display_control

    # The host packets of the specials precede the display code in the
    # payload, after the final link.
    after_link(lambda: install_display_control(host, mode))
    # Reserve only after specials and display code have appended all
    # their live data: the two snapshots end the 1 MiB payload.
    from menu_mirror import allocate as allocate_menu_mirror

    allocate_menu_mirror(host)
    from card_link import final_link

    # The card records hold the linked bytes of each code object and asset.
    final_link()
    from card_link import asset_loads, export_host, run_after_link

    for address, data in asset_loads():
        host.record(address, data)
    # Host data that holds card addresses.
    run_after_link()
    host.check_card_loads(asset_loads())
    export_host(out / "card.inc")
    host.save()
    # Specials and menu allocations occur after the original art summary.
    # The published limit must describe the final file, not an earlier
    # intermediate payload length.
    end = 0x20000 + len(host.blob)
    assert (out / "payload.bin").stat().st_size == len(host.blob)
    meta["compact_host"]["highest_host_address"] = end
    assert end <= 0x100000, meta["compact_host"]
    assert (out / "host.bin").stat().st_size < 0x2000, "Native host code reaches packet buffer"
    events = [
        (10, "Left Arrow", 80, 1),
        (25, "Up Arrow", 82, 1),
        (40, "Space", 44, 1),
        (55, "Left Arrow", 80, 0),
        (70, "Up Arrow", 82, 0),
        (85, "Space", 44, 0),
        (100, "Right Arrow", 79, 1),
        (110, "Right Arrow", 79, 0),
    ]
    # Leave several updates for actual ADB delivery before the final image.
    events.extend(((100, "Down Arrow", 81, 1), (110, "Down Arrow", 81, 0), (108, "Space", 44, 1)))
    events.sort(key=lambda event: event[0])
    events = []
    (out / "input-events.tsv").write_text(
        "".join(f"{tick}\t{name}\t{down}\n" for tick, name, _, down in events)
    )
    (out / "input-events.json").write_text(
        json.dumps(
            [dict(tick=tick, scancode=scan, down=down) for tick, _, scan, down in events], indent=2
        )
        + "\n"
    )
    meta.update(
        base_set="1943ua",
        continuous=True,
        native_input=True,
        native_flight=True,
        native_basic_gun=True,
        native_doc_gun=True,
        native_combat=True,
        native_sprite_planning=True,
        native_wave_spawns=True,
        native_enemy_bullets=True,
        native_bullet_contact=True,
        native_player_death=True,
        controlled_death_start=False,
        native_ordinary_weapons=True,
        controlled_weapon=0,
        native_player_aux=True,
        weapon_character_slots=weapon_chars,
        controlled_player_fixture=None,
        fixed_input_trace=False,
        native_medium_enemies=True,
        native_large_core=True,
        native_ship_fixture=0,
        startup_display_scratch_bytes=getattr(scene, "startup_display_scratch_bytes", 0),
        resident_death_codes=sorted(death_codes),
        cpu_profile=False,
        routine_profile=False,
        direct_pool_ticks=True,
        controlled_input_replay=False,
        sea_window_rows=4096,
        sea_atlas_bytes=len(atlas),
        sea_map_bytes=len(table),
        native_foreground_planning=True,
        native_character_planning=True,
        mode=mode,
        updates=None,
        initial_camera=initial_camera,
        scope="Continuous native game with live keyboard input",
        build_seconds=time.perf_counter() - started,
    )
    meta["sprite_cache"] = dict(
        requested_phase_slots=scene.sprite_cache.requested_slots,
        phase_slots=len(scene.sprite_cache.slots),
        art_records=128,
        shared_mask_bytes=4096,
        phase_record_bytes=scene.sprite_cache.phase_record_bytes,
        pixel_bytes=len(scene.sprite_cache.slots) * 260,
        boot_clear_bytes=len(scene.sprite_cache.slots) * 260,
        boot_clear_code_bytes=scene.sprite_cache.clear_code_bytes,
        boot_clear_ranges=len(scene.sprite_cache.clear_ranges),
        source_payload_bytes=scene.sprite_cache.source_wire_bytes,
        source_index_bytes=8192,
        phase_pin_bytes=0,
        phase_stamp_bits=7,
        span_lookup_bytes=1792,
        art_link_bytes=1024,
        descriptor_bytes=2048,
        descriptor_slots=128,
        source_pitch=4,
        retained_pixel_index_bytes=16384,
    )
    from card_link import symbol

    def span(region):
        """The run address and the end of the last section of a region."""
        prefix = card_layout.symbol_name(region)
        return [symbol(f"{prefix}__run"), symbol(f"{prefix}__end")]

    meta["combined_background"] = dict(
        display_group_bases=[0x400, 0x8400],
        fixed_text_bytes=0,
        cloud_phase_cache_bytes=0,
        firmware_backup_bytes=0,
        shared_strip_program_bytes=len(scene.combined_row_programs),
        ship_aligned_rows=len(scene.ship_row_layouts),
        ship_rows_cached=scene.ship_rows_cached,
        ship_column_programs=len(scene.ship_column_programs),
        strip_family_vram_bytes=sum(map(len, scene.combined_shared_arena.blocks)),
        strip_family_encoded_bytes=scene.combined_shared_arena.used,
        strip_family_expanded_bytes=64 * len(scene.combined_shared_arena.shared),
        section_slot_bytes=7 * 16384,
        section_metadata_bytes={r: arena.used for r, (arena, _) in scene.combined_arenas.items()},
        ship_geometry_bytes=scene.ship_row_geometry_bytes,
        ship_geometry_vram_bytes=0,
        ship_geometry_shared_vram_bytes=sum(map(len, scene.ship_geometry_arena.blocks)),
        ship_geometry_shared_tail_bytes=scene.ship_geometry_overflow_bytes,
        ship_column_staging_sram=[0x5C00, 0x5DA0],
        ship_anchor_helpers_sram=span("background-anchors"),
        sprite_fast_sram=span("sprite-fast"),
        ship_seed_bytes=scene.ship_seed_bytes,
        ship_seed_vram=[0x41E00, 0x41E00 + len(scene.ship_seed_data)],
        ship_auxiliary_vram_bytes=3 * 32768,
        ship_alignment_group_bases=scene.ship_alignment_bases,
        ship_alignment_sram=span("ship-alignment"),
        normal_water_vram_bytes=6720,
        normal_water_reserved_bytes=6720,
        normal_water_palette_entries=120,
        normal_water_refresh_rows=0,
        normal_water_gameplay_bytes=6720,
        water_copy_sram=span("water-copy"),
        background_migration_sram=span("background-migration"),
        shared_metadata_group_address=scene.combined_shared_arena.addresses[-1],
        shared_metadata_protected_plane_bytes=scene.combined_shared_tail,
        column_sram=[0x19100, 0x19560],
        open_water_bounds_sram=[0xA400, 0xA600],
        cloud_roots_sram=[0xA600, 0xA618],
        sea_metadata_sram=[0x19600, 0x19600 + scene.sea_directory_bytes],
        light_water_palette_sram=[],
        water_modulo_high_sram=[0x1B600, 0x1B700],
        background_full_sram=[0x1B700, 0x1C000],
        world_side1_descriptors_sram=[
            [0x1B400, 0x1B5FE],
            [0x1BB00, 0x1BB00 + (len(scene.game_world.columns) - 170) * 3],
        ],
        ready_water_sram=[0x1C000, 0x20000],
        sea_bands=list(scene.sea_bands),
        sea_feature_tiles=scene.sea_object_count,
        sea_feature_vram_bytes=scene.sea_art_bytes,
        light_water_vram_bytes=28672,
    )
    (out / "manifest.json").write_text(json.dumps(meta, indent=2) + "\n")
    print(
        json.dumps(
            {k: v for k, v in meta.items() if k not in ("mode", "enemy_scripts", "doc_sample")}
        ),
        flush=True,
    )
    return out
