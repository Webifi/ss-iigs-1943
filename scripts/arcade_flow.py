"""Native cabinet-flow data from the original US reset and text routines.

The $0416 rectangle writer is evaluated in the build. These are ROM character
layouts, not captured screens or game states. The native cabinet owns time,
credits and transitions; the existing renderer displays its current layout.
"""

import struct
from iigs_payload import HostData, content_key
from roms import load
from world_stream import replace


def text_rectangle(rom, codes, attrs, pointer):
    dest, width, height, color = struct.unpack_from("<HBBB", rom, pointer)
    p = pointer + 5
    spaces = 0
    for row in range(height):
        for col in range(width):
            if spaces:
                code = 0x24
                spaces -= 1
            else:
                code = rom[p]
                p += 1
                if code == 255 and not color & 224:
                    spaces = rom[p]
                    p += 1
                    code = 0x24
                    if spaces:
                        spaces -= 1
            at = dest - 0xD000 - row + 32 * col
            assert 0 <= at < 1024, (hex(pointer), at)
            codes[at] = code
            attrs[at] = color


def page(a, kind):
    r = load()[0]["maincpu"]
    codes = bytearray([0x24]) * 1024
    attrs = bytearray(1024)
    # Reset $08C8-$08DD writes both players and high score before the warning.
    pointers = [0x0933, 0x095B, 0x0942, 0x094F]
    if kind == 5:
        pointers += [0x0D14]

    for p in pointers:
        text_rectangle(r, codes, attrs, p)
    black = next(i for i in range(256) if a.palette[i * 3 : i * 3 + 3] == bytes(3))
    pixels = bytearray([black]) * (256 * 256)
    for i, code in enumerate(codes):
        attr = attrs[i]
        code |= (attr & 224) << 3
        x = (i & 31) * 8
        y = (i >> 5) * 8 - 16
        if not 0 <= y < 224:
            continue
        tile = a.gfx[0][code]
        for dy in range(8):
            for dx in range(8):
                pen = tile[dy * 8 + dx]
                if pen:
                    pixels[(255 - x - dx) * 256 + y + dy] = a.colors[0][(attr & 31) * 4 + pen]
    return bytes(pixels)


def cells(pointers, rank=False, credit=False):
    r = load()[0]["maincpu"]
    codes = bytearray([0x24]) * 1024
    attrs = bytearray(1024)
    for p in pointers:
        text_rectangle(r, codes, attrs, p)
    # Ranking scores and initials are live cabinet state. Reserve every cell,
    # including leading blanks, and supply its current glyph with the page.
    rank_fields = []
    if rank:
        for n in range(5):
            for i in range(8):
                at = 0x190 - n * 2 + 32 * i
                codes[at] = 0x24
                rank_fields.append((at, -(17 + n * 11 + i), 0))
            for i in range(3):
                at = 0x190 - n * 2 + 32 * (10 + i)
                codes[at] = 0x24
                rank_fields.append((at, -(17 + n * 11 + 8 + i), 0))
        # The arcade retains the last scores above the ranking and updates
        # the high score there, including after the ending and initials.
        for field, first in ((55, 0x19E), (63, 0x05E), (71, 0x2BE)):
            for i in range(8):
                at = first + 32 * i
                codes[at] = 0x24
                rank_fields.append((at, -(17 + field + i), 0))
    result = [
        (i, c | ((attrs[i] & 224) << 3), attrs[i] & 31)
        for i, c in enumerate(codes)
        if c not in (0x24, 0xFE)
    ]
    result.extend(rank_fields)
    if credit:
        result.append((0x380, -1, 0))
    return result


def prepare(scene, pool):
    from cabinet_video import prepare as video_prepare

    header = [0x0933, 0x095B, 0x0942, 0x094F]
    logo = [0x2658, 0x26E1]
    ranks = [0x304F, 0x3062, 0x306A, 0x3072, 0x307A, 0x3082]
    layouts = {
        1: cells(logo + [0x3038]),
        2: cells(logo),
        3: cells(header + logo + ranks + [0x2710, 0x2766], True, True),
        4: cells(header + [0x0C3E, 0x2710, 0x2766], credit=True),
        6: cells(header + logo + [0x26FA, 0x273B, 0x2710, 0x2766], credit=True),
        7: cells(header + logo + [0x26FA, 0x274D, 0x2710, 0x2766], credit=True),
    }
    layouts[16] = layouts[3]
    # During the P-38 fly-in the original keeps the title and flashes the
    # insert-coin prompt. Both variants share the same card display mode.
    layouts[86] = layouts[4]  # the existing prepared prompt is drawn separately
    from cabinet_ending import prepare as ending_prepare

    base, ending, scene.cabinet_timelines, scene.cabinet_flag_front_limit = ending_prepare(
        scene.a, scene.cabinet_surface
    )
    # Ending-only sea colours share the cycling-water slots. Restore them
    # while the static tableau owns the display; gameplay restores its water
    # palette on the first subsequent flip. No additional palette allocation.
    scene.cabinet_ending_palette = {
        i: scene.a.palette[i * 3 : i * 3 + 3]
        for i in sorted(set(base[:57344]) & set(scene.a.water_slots))
    }
    layouts.update(ending)
    from cabinet_post import prepare as post_prepare

    layouts.update(post_prepare(ending[29]))
    from cabinet_result import prepare as result_prepare

    result_layouts, result_timelines, scene.cabinet_statistics = result_prepare()
    layouts.update(result_layouts)
    scene.cabinet_timelines.update(result_timelines)
    video_prepare(scene, pool, layouts)
    from cabinet_plane import prepare as plane_prepare

    scene.cabinet_pages = {4: plane_prepare(scene), 5: page(scene.a, 5), 17: base}
    # The renderer supplies one temporary 64 KB surface for static screens.
    # It owns the borrowed surface's world-slot invalidation and reload.
    assert (scene.cabinet_surface & 65535) + 16384 <= 65536
    replace(pool, scene.cabinet_surface * 4, scene.cabinet_pages[5])


def install(out, host, scene):
    from startup_pack import pack

    def jobs(address, pixels, kind):
        # Cabinet transitions expand directly into one selected VRAM plane.
        # Four-KB blocks share long blank runs without another resident copy.
        for plane in range(4):
            raw = pixels[plane::4]
            for off in range(0, len(raw), 4096):
                ptr = address + off
                remaining = raw[off : off + 4096]
                start = 0
                while start < len(remaining):
                    # $3400-$34FF is shared staging scratch; $3500 is live
                    # code, so two-bit input must never exceed 256 bytes.
                    part = remaining[start : start + 1024]
                    if kind == 5 and len(part) % 4 == 0 and len(set(part)) <= 4:
                        palette = bytes(sorted(set(pixels))).ljust(4, b"\0")
                        assert len(set(pixels)) <= 4
                        index = {v: i for i, v in enumerate(palette)}
                        pens = bytes(
                            sum(index[part[i + k]] << (k * 2) for k in range(4))
                            for i in range(0, len(part), 4)
                        )
                        assert len(pens) <= 256
                        packed = pack(pens)
                        if len(packed) < len(pack(part)):
                            p = ptr + start
                            yield (
                                struct.pack(
                                    "<BBBBHHH",
                                    9,
                                    0x92 + ((p & 65535) >> 12),
                                    1 << plane,
                                    p >> 16,
                                    0xE000 + (p & 4095),
                                    len(pens),
                                    len(packed),
                                )
                                + packed
                            )
                            start += len(part)
                            continue
                    n = len(remaining) - start
                    encoded = pack(remaining[start : start + n])
                    while len(encoded) > 980:
                        n = (n + 1) // 2
                        encoded = pack(remaining[start : start + n])
                    p = ptr + start
                    yield (
                        struct.pack(
                            "<BBBBHHH",
                            5,
                            0x92 + ((p & 65535) >> 12),
                            plane,
                            p >> 16,
                            0xE000 + (p & 4095),
                            n,
                            len(encoded),
                        )
                        + encoded
                    )
                    start += n

    shared = {}
    directory = [0] * 32

    def blob(data):
        key = content_key(data)
        if key not in shared:
            try:
                shared[key] = host.slow_blob_at(data)
            except ValueError:
                shared[key] = host.blob_at(data)
        return shared[key]

    for kind, pixels in scene.cabinet_pages.items():
        batches = []
        batch = bytearray()

        # vram_jobs crosses a CPU aperture only between these 4K groups.
        def changes():
            # The codec already splits each plane at its 4 KB CPU aperture.
            # Keep the full plane's repeated water rows in the build dictionary.
            yield from jobs(scene.cabinet_surface, pixels, kind)

        for job in changes():
            if len(batch) + len(job) > 1000:
                batches.append(bytes(batch) + b"\0")
                batch.clear()
            batch.extend(job)
        if batch:
            batches.append(bytes(batch) + b"\0")
        entries = HostData()
        for data in batches:
            data = data.ljust((len(data) + 1) & ~1, b"\0")
            entries.word(len(data)).dword(blob(data))
        entries.data(bytes(6))
        directory[kind] = blob(entries)
    from cabinet_video import install as video_install

    video_install(scene, host)
    from game_enemies import read
    from cabinet_ending import PANELS

    text_directory = [0] * (max(scene.cabinet_timelines) + 1)
    for kind, data in scene.cabinet_timelines.items():
        text_directory[kind] = blob(data)
    statistics = HostData().dword(
        *(blob(data) for variants in scene.cabinet_statistics for data in variants)
    )
    lines = [
        f"CABINET_PAGES = {blob(HostData().dword(*directory)).label}",
        f"CABINET_TEXT = {blob(HostData().dword(*text_directory)).label}",
        f"CABINET_STAT_TEXT = {blob(statistics).label}",
        f"CAB_ENDING_PAGES = {len(PANELS)}",
        "cabinet_ending_pages:",
        "  .byte " + ",".join(str(n + 17) for n in range(len(PANELS))),
        "cabinet_ending_sounds:",
        "  .byte " + ",".join(str(p[3]) for p in PANELS),
    ]
    lines += ['.include "cabinet_post_data.inc"', "cabinet_post_jobs:"]
    for kind in range(74, 85):
        length, address = scene.cabinet_video["post_jobs"][kind]
        lines += [f"  .word {length}", f"  .dword {address.label}"]
    from cabinet_actors import data as actor_data, typing_ticks

    lines += actor_data(blob)
    lines += [
        f"CAB_FLAG_START_TICKS = {typing_ticks(scene.cabinet_timelines[18], 120)}",
        f"CAB_DOG_START_TICKS = {typing_ticks(scene.cabinet_timelines[28], 60)}",
    ]
    takeoff = read(1, 0x942D, 1024)
    n = 0
    while takeoff[n] != 255:
        n += 4
    for name, bank, address, size in (
        ("cabinet_demo_player", 0, 0x0EC2, 40),
        ("cabinet_demo_player_two", 0, 0x0EEA, 40),
        ("cabinet_player_start", 0, 0x0FDF, 40),
        ("cabinet_player_two_start", 0, 0x1007, 40),
        ("cabinet_initial_scores", 0, 0x09AA, 80),
        ("launch_deck_template", 0, 0x4887, 32),
        ("launch_small_template", 0, 0x48A7, 32),
        ("launch_large_template", 0, 0x48C7, 32),
        ("launch_small_positions", 0, 0x484D, 20),
        ("launch_large_positions", 0, 0x4862, 36),
        ("launch_dock_poses", 1, 0x9319, 8),
        ("launch_takeoff", 1, 0x942D, n + 1),
    ):
        lines += [name + ":", "  .byte " + ",".join(str(v) for v in read(bank, address, size))]
    positions = read(0, 0x472C, 15)
    lines += [
        "launch_deck_positions:",
        "  .byte "
        + ",".join(str(v) for i in reversed(range(5)) for v in positions[i * 3 : i * 3 + 3]),
    ]
    demo = read(1, 0xA8C0, 0xC000 - 0xA8C0)
    n = 0
    while demo[n + 1] and demo[n + 2]:
        n += 3
    pairs = list(dict.fromkeys(bytes(demo[i + 1 : i + 3]) for i in range(0, n, 3)))
    assert len(pairs) < 255
    pair_index = {v: i for i, v in enumerate(pairs)}
    compact = b"".join(
        bytes((demo[i], pair_index[bytes(demo[i + 1 : i + 3])])) for i in range(0, n, 3)
    ) + bytes((0, 255))
    decoded = b"".join(
        bytes((compact[i],)) + pairs[compact[i + 1]] for i in range(0, len(compact) - 2, 2)
    )
    assert decoded == bytes(demo[:n]) and compact[-1] == 255
    lines += [
        f"cabinet_demo_controls = {blob(compact).label}",
        f"cabinet_demo_dictionary = {blob(b''.join(pairs)).label}",
    ]
    print(
        f"Native demo: {sum(demo[i] or 256 for i in range(0, n, 3))} logic ticks, {n // 3} ROM-authored control segments",
        flush=True,
    )
    lines += ["cabinet_plane_frames:", "  .byte " + ",".join(str(v) for v in read(0, 0x4D9B, 25))]
    lines += [
        "cabinet_stage_digits:",
        "  .byte "
        + ",".join(str(v) for n in range(1, 17) for v in (n // 10 if n >= 10 else 10, n % 10)),
        "cabinet_percent_bcd:",
        "  .byte " + ",".join(str(((n // 10) % 10) * 16 + n % 10) for n in range(256)),
    ]
    (out / "cabinet_data.inc").write_text("\n".join(lines) + "\n")
    return sum(map(len, shared))


def sources(scene):
    """The generated sources of the cabinet code."""
    from cabinet_video import config_include, sources as video_sources

    config_include(scene)
    video_sources(scene)
