"""The asset build: the art, the data and the generated sources of the Second
Sight and IIgs programs (the Makefile links them)."""


from arcade import Arcade, ROOT
from flight import prepare_tables
from iigs_payload import Host
from playfield import build_kernel

CHAR_BANK = 0x3C



def build():
    out = ROOT / "build/game"
    out.mkdir(parents=True, exist_ok=True)
    a = Arcade()
    from game_palette import merge

    merge(a)
    from game_art import GameArtPool, SpriteCache

    pool = GameArtPool(a)
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
    from world_stream import prepare as prepare_world, install as install_world
    from state_scene import StateScene

    scene = StateScene(a, pool, background_cache=True)
    from game_world import initial_state, hud_commands

    initial_camera, foreground_initial, camera, initial = initial_state()
    commands = hud_commands()
    prepare_world(scene, pool, foreground_initial)
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
    assert 0 <= initial_camera and initial_camera + 256 <= 4096
    for code in range(0x20, 0x2A):
        pool.get(("sprite", 3, code, 0, 0, 0, 0))
    from player_death import prepare as prepare_death

    death_frames = prepare_death(out)
    death_codes = {base + offset for base in death_frames[1:-1:2] for offset in (0, 1, 8, 9)}
    # Death can start in a busy wave. Its complete art stays resident;
    # it never depends on a transfer during the animation.
    for code in sorted(death_codes):
        pool.get(("sprite", 3, code, 0, 0, 0, 0))
    from projectiles import prepare as prepare_shots

    prepare_shots(out)
    for code in (0x3F, 0xA5, 0xA6, 0xA7):
        pool.get(("sprite", 3, code, 9, 0, 0, 0))
    from weapons import prepare as prepare_weapons

    weapon_meta = prepare_weapons(out)
    for code in weapon_meta["sprite_codes"]:
        pool.get(("sprite", 3, code, 9, 0, 0, 0))
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

    prepare_simple(out)
    from formation_enemies import prepare as prepare_formations

    formation_roots = prepare_formations(out)
    from extended_spawns import prepare as prepare_extended

    prepare_extended(out)
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
    from ship_enemies import prepare as prepare_ship

    ship_roots = prepare_ship(out, patterns=None)
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
    scene.build_out = out
    from repair_core import reserve as reserve_repair_core

    reserve_repair_core(scene, pool)
    mode = build_kernel(out, "vga-224x256-roomy", initial_camera, scene)
    from native_sprites import object_packets

    offload = object_packets(pool, scene)
    prepare_tables(out)
    from native_sprites import compile_hud

    compile_hud(
        out,
        chars,
        offload,
        CHAR_BANK,
        score_char_start,
        energy_chars,
        pool=pool,
        scene=scene,
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
    include = [f"FLIGHT_INITIAL_CAMERA = {initial_camera}"]
    host = Host(out)
    from stage_controls import install as install_stages

    install_stages(out, host, enemy_spawns=True)
    from camera import prepare as prepare_camera
    from score import prepare as prepare_score

    prepare_camera(out)
    prepare_score(out)
    wave_scripts(host, scene.sprite_cache.prop_codes, script_pieces)
    ai_install(host)
    from audio_song_native import prepare as prepare_audio

    prepare_audio(out, host)
    from bullet_contact import prepare as prepare_contact

    prepare_contact(out)(host)
    host.blob_at(a.palette, "card_palette")
    pool.install()
    from game_water import install as install_water

    install_water(host, a, scene)

    install_world(out, host, scene)
    from special_wave import install_draw

    install_draw(scene, host)
    from secondsight_link import load
    from state_scene import tables

    for address, data in tables(scene, offload):
        load(0x100000 + address, data)
    scene.sprite_cache.install_directory(host)
    include.extend(
        (
            f"FLIGHT_FG_INITIAL = {foreground_initial}",
            f"COMBAT_CAMERA_SIZE = {len(camera)}",
            f"FLIGHT_INITIAL_SIZE = {len(initial)}",
        )
    )
    (out / "flight_draw.inc").write_text("\n".join(include) + "\n")
    camera[:2] = initial_camera.to_bytes(2, "little")
    camera[15:17] = foreground_initial.to_bytes(2, "little")
    host.blob_at(camera, "combat_camera")
    host.blob_at(initial, "flight_initial")
    host.blob_at(bytes((1, 0, 0, 0, 0, 0, 0, 0)), "bullet_seed")
    from playfield import finish_entry

    finish_entry(out, host, scene)
    from input_audio import prepare as prepare_mix

    prepare_mix(host)
    from special_wave import install as install_special_wave

    install_special_wave(scene, host)
    from display_control import install as install_display_control

    install_display_control(host, mode)
    from menu_mirror import allocate as allocate_menu_mirror

    allocate_menu_mirror(host)
    from secondsight_link import write_inputs

    # The inputs of the Second Sight link and of the IIgs link.
    write_inputs()
    host.save()
    return out
