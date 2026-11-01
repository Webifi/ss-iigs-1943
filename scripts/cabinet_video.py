"""Build-prepared cabinet text over the native scrolling picture.

Glyphs, masked color groups and shared layouts use free descriptor SRAM.
The live demo overlay also uses prepared code and pixels in VRAM.
"""

import struct
from collections import OrderedDict

from iigs_payload import HostData

# This scratch is unused by the row, sprite and HUD renderers. It is read only
# while the final cabinet command runs, after their work is complete.


def prepare(scene, pool, layouts):
    glyphs = OrderedDict()
    patterns = OrderedDict()
    patterns[(0, bytes(4))] = 0
    packed = []
    definitions = {}
    for digit in (*range(10), 0x24):
        glyphs[digit, 0] = digit
    all_keys = list(glyphs) + [(n, 0) for n in range(36)]
    all_keys += [(n, 0) for n in (0x28, 0x29, 0x2B, 0x2C, 0x37, 0x3A, 0x62, 0x64, 0x66)]
    all_keys += [(n, color) for color in (1, 2) for n in range(10)]
    # The arcade flashes the selected initials glyph between color 0 and 15.
    # Keep both variants as prepared glyphs; no pixel conversion runs in play.
    all_keys += [
        (n, 15)
        for n in sorted(
            set(range(36)) | {0x24, 0x28, 0x29, 0x2B, 0x2C, 0x37, 0x3A, 0x62, 0x64, 0x66}
        )
    ]
    glyphs.clear()
    layouts_for_font = {**layouts, 255: [(0, c, a) for c, a in all_keys]}
    for layout in layouts_for_font.values():
        for index, code, attr in layout:
            if code < 0:
                continue
            key = (code, attr)
            if key in glyphs:
                continue
            tile = scene.a.gfx[0][code]
            data = bytearray()
            for y in range(8):
                for x in range(0, 8, 4):
                    # Upright ROT270: screen x is raw y, screen y is 255-raw x.
                    pens = [tile[(x + k) * 8 + 7 - y] for k in range(4)]
                    mask = sum(bool(p) << i for i, p in enumerate(pens))
                    values = bytes(scene.a.colors[0][attr * 4 + p] if p else 0 for p in pens)
                    token = patterns.setdefault((mask, values), len(patterns)) if mask else 0
                    data.append(token)
            data = bytes(data)
            if data not in definitions:
                definitions[data] = len(packed)
                packed.append(data)
            glyphs[key] = definitions[data]
    assert len(patterns) <= 256 and len(packed) <= 512, (len(patterns), len(packed))
    scene.cabinet_video = dict(glyphs=glyphs, patterns=patterns, font=packed, layouts=layouts)
    print(
        f"Cabinet patterns: {len(patterns)} groups in SRAM, zero VRAM bytes; glyphs {len(glyphs)}",
        flush=True,
    )


def prepare_fast_demo(scene, pool):
    # Prepared per-band Z180 programs live in a VGA read plane beside their
    # preconverted pixels. Each LDI reloads the latches immediately before
    # its write; instruction fetches from VRAM therefore cannot corrupt it.
    from arcade_flow import cells

    programs = []
    for name, pointers in [("logo", (0x2658, 0x26E1)), ("prompt", (0x3038,))]:
        groups = {}
        for i, code, attr in cells(pointers):
            x = (i >> 5) * 8 - 16
            y = 248 - (i & 31) * 8
            tile = scene.a.gfx[0][code]
            for row in range(8):
                for col in (0, 4):
                    pens = [tile[(col + k) * 8 + 7 - row] for k in range(4)]
                    mask = sum(bool(p) << k for k, p in enumerate(pens))
                    if mask:
                        pixels = bytes(scene.a.colors[0][attr * 4 + p] if p else 0 for p in pens)
                        groups[y + row, x // 4 + col // 4] = (mask, pixels)
        for band in range(4):
            entries = sorted(
                ((y - band * 64) * 56 + x, mask, pixels)
                for (y, x), (mask, pixels) in groups.items()
                if y // 64 == band
            )
            if not entries:
                continue
            # Split the logo bands into four programs. The shorter piece of
            # band 1 shares its code plane with the independent prompt.
            cut = len(entries) // 2 if band == 0 else len(entries) * 3 // 10
            parts = (entries[:cut], entries[cut:]) if name == "logo" else (entries,)
            for part in parts:
                lines = []
                cursor = 0
                last = None
                for offset, mask, pixels in part:
                    gap = offset - cursor
                    if gap <= 3:
                        lines += ["        inc de                          ; a transparent group"] * gap
                    else:
                        lines += ["        ex de,hl", f"        ld bc,{gap}", "        add hl,bc", "        ex de,hl"]
                    if mask != last:
                        lines += [f"        ld a,{mask}", "        exx", "        out (c),a", "        exx"]
                        last = mask
                    lines.append("        ldi")
                    cursor = offset + 1
                lines.append("        jp cab_demo_next")
                source = b"".join(pixels for _, _, pixels in part)
                programs.append((name, band, source, lines))
    assert [(p[0], p[1]) for p in programs] == [
        ("logo", 0),
        ("logo", 0),
        ("logo", 1),
        ("logo", 1),
        ("prompt", 2),
    ]
    # One video RAM block inside one 8 KB window: the pixels of every program
    # in all four planes, then each program in its code plane.
    from asset_source import Plane, Source
    from secondsight_link import asset

    sources = b"".join(p[2] for p in programs)
    source_groups = len(sources) // 4
    planes = (0, 1, 2, 3, 2)
    block = Source("fast title demo (scripts/cabinet_video.py)")
    for plane in range(4):
        block.section(f".plane.cab_demo.{plane}.0").data(sources[plane::4])
    for n, (plane, (name, band, source, lines)) in enumerate(zip(planes, programs)):
        block.section(f".plane.cab_demo.{plane}.{n + 1}", "ax").label(f"cab_demo_program_{n}")
        block.code(lines)
    asset("cab_demo", block)
    # The block holds the pixels; the fitter (scripts/secondsight_fit.py)
    # makes it as large as its fullest plane, the pixels and the programs.
    demo = pool.vram.block(source_groups, 8192, "cab_demo")
    records = []
    offset = 0
    for n, (plane, (name, band, source, _)) in enumerate(zip(planes, programs)):
        program = Plane(f"cab_demo_program_{n}", plane)
        records.append((name, (demo("vbbr"), demo("vseg"), plane), ((demo + offset)("vptr"), program("pptr"), band * 64 * 56)))
        offset += len(source) // 4
        print("Fast demo band", name, band, len(source) // 4, flush=True)
    demo_tables_source(records)


# Bytes reserved for each table of program records, with its end mark.
DEMO_TABLES = {"logo": (41, (0, 0)), "prompt": (32, (0, 1))}


def demo_tables_source(records):
    """build/secondsight/gen/cab_demo_tables.s: the program records (BBR, segment,
    plane, pixels, program, band offset) of the fast title demo, from
    prepare_fast_demo. Without records, the space for them."""
    from asset_source import Source
    from secondsight_link import generate

    source = Source("the fast demo program records (scripts/cabinet_video.py)")
    source.section(".data.cab_demo_tables")
    for name, (capacity, end) in DEMO_TABLES.items():
        source.label(f"cab_demo_{name}_table")
        start = source.size
        for record, values, words in records:
            if record == name:
                source.byte(*values).word(*words)
        source.byte(*end)
        assert source.size - start <= capacity, (name, source.size - start)
        source.fill(capacity - (source.size - start))
    generate("cab_demo_tables", source.text())


def group_source(colors):
    """Write each colour of one four-pixel group through its map mask.

    VGA's map mask has four implemented bits. BC=$03C5 and DE=54 throughout
    a glyph, so B, C and E already hold the masks 3, 5 and 6.
    """
    lines = []
    for color, bits in colors.items():
        if bits in (3, 5, 6):
            lines.append("        out (c)," + "bce"[(3, 5, 6).index(bits)])
        else:
            lines += [f"        ld a,{bits}", "        out (c),a"]
        lines.append(f"        ld (hl),{color}")
    return lines + ["        inc hl", "        ret"]


def install(scene, host):
    from secondsight_link import define

    info = scene.cabinet_video
    from hitch_water import install as install_hitch_water

    install_hitch_water(scene, host)

    from asset_source import Source, derived
    from secondsight_link import alias, asset

    # Four-pixel group programs. card.ld puts each one into the first of the
    # cabinet code tail, the sprite cache tail and the pattern page with
    # space. No color/mask decoding happens while drawing.
    groups = Source("cabinet glyph group programs (scripts/cabinet_video.py)")
    for index, (mask, values) in enumerate(info["patterns"]):
        colors = OrderedDict()
        for lane, value in enumerate(values):
            if mask & (1 << lane):
                colors[value] = colors.get(value, 0) | (1 << lane)
        groups.section(f".cab_group.{index}", "ax").label(f"cab_group_{index}")
        groups.code(group_source(colors))
    asset("cab_groups", groups)
    # The largest packet is 26 header + 620 object + 40 HUD + 1026 asset bytes
    # = 1712 bytes (state_packet.s / world_stream.py), reserved at $8000;
    # canonical sprite masks start at $9000. The renderer's common code ends
    # at $7000. The tails between hold hot group code.
    # The program of each glyph row: its two groups. Rows run in the pattern
    # page through the bank area.
    row_pairs = list(dict.fromkeys(g[i : i + 2] for g in info["font"] for i in range(0, 16, 2)))
    row_index = {pair: n for n, pair in enumerate(row_pairs)}
    rows = Source("cabinet glyph row programs (scripts/cabinet_video.py)").section(".cab_rows", "ax")
    for n, (first, second) in enumerate(row_pairs):
        rows.label(f"cab_row_{n}")
        rows.code([f"        call cab_group_{first}"] if first else ["        inc hl                          ; empty group"])
        if second:
            rows.code([f"        jp cab_group_{second}"])
        else:
            rows.code(["        inc hl                          ; empty group", "        ret"])
    asset("cab_rows", rows)
    # Each glyph: the row programs of its eight rows. Share whole row
    # sequences and identical suffixes across characters.
    fonts = [tuple(row_index[tokens[i : i + 2]] for i in range(0, 16, 2)) for tokens in info["font"]]
    unique = list(dict.fromkeys(fonts))
    edges = []
    for i, left in enumerate(unique):
        for j, right in enumerate(unique):
            if i == j:
                continue
            overlap = next((n for n in range(7, 0, -1) if left[-n:] == right[:n]), 0)
            if overlap:
                edges.append((-overlap, i, j))
    # Join the strongest matching suffix/prefix pairs first. Each glyph still
    # has its complete ready-to-copy eight words; there is no runtime codec.
    parent = list(range(len(unique)))
    after = {}
    before = {}

    def root(i):
        while parent[i] != i:
            i = parent[i]
        return i

    for negative, i, j in sorted(edges):
        if i in after or j in before or root(i) == root(j):
            continue
        after[i] = (j, -negative)
        before[j] = i
        parent[root(j)] = root(i)
    font_rows = []
    offsets = {}
    for i, data in enumerate(unique):
        if i in before:
            continue
        offsets[data] = len(font_rows)
        font_rows += data
        while i in after:
            i, overlap = after[i]
            data = unique[i]
            offsets[data] = len(font_rows) - overlap
            font_rows += data[overlap:]
    assert all(tuple(font_rows[off : off + 8]) == data for data, off in offsets.items())
    # One record of the shared entries. A glyph is addressed by its physical
    # address / 2; the card copies its 16 bytes through the 8 KB bank area,
    # so the record may cross a 4 KB page.
    fonts_source = Source("cabinet glyph entries (scripts/cabinet_video.py)")
    fonts_source.section(".fonts.cab_fonts").code(["        .balign 2"]).label("cab_fonts")
    fonts_source.word(*(f"cab_row_{n}" for n in font_rows))
    asset("cab_fonts", fonts_source)
    entries = [derived("half", f"cab_fonts + {2 * offsets[data]}") for data in fonts]
    directory = Source("cabinet glyph directory (scripts/cabinet_video.py)")
    directory.section(".desc.cab_font_directory").code(["        .balign 2"]).label("cab_font_directory")
    directory.word(*entries)
    alias("cab_font_bbr", derived("bbr", "cab_font_directory"))
    alias("cab_font_address", derived("ptr", "cab_font_directory"))
    post_codes = sorted(
        set(range(36)) | {0x24, 0x28, 0x29, 0x2B, 0x2C, 0x37, 0x3A, 0x62, 0x64, 0x66}
    )
    post_entries = [entries[info["glyphs"][code, 0]] for code in post_codes]
    for color in (1, 2):
        post_entries += [entries[info["glyphs"][code, color]] for code in range(10)]
    post_flash = len(post_entries)
    post_entries += [entries[info["glyphs"][code, 15]] for code in post_codes]
    directory.section(".desc.cab_post_font").code(["        .balign 2"]).label("cab_post_font")
    directory.word(*post_entries)
    alias("cab_post_font_bbr", derived("bbr", "cab_post_font"))
    alias("cab_post_font_address", derived("ptr", "cab_post_font"))
    # The prepared layout list (replaced only when the presentation changes,
    # before that packet begins drawing) and one compact live ranking field
    # table, filled when the ranking page is loaded.
    layout_size = (
        3
        * max(
            sum(0 <= (i >> 5) * 8 - 16 < 224 for i, _, _ in layout)
            for layout in info["layouts"].values()
        )
        + 3
    )
    directory.section(".desc.cab_layout").code(["        .balign 2"]).label("cab_layout").fill(layout_size)
    directory.section(".desc.cab_rank_fields").code(["        .balign 2"]).label("cab_rank_fields").fill(79)
    asset("cab_directory", directory)
    alias("cab_layout_bbr", derived("bbr", "cab_layout"))
    alias("cab_layout_address", derived("ptr", "cab_layout"))
    alias("cab_rank_bbr", derived("bbr", "cab_rank_fields"))
    alias("cab_rank_address", derived("ptr", "cab_rank_fields"))
    # Layouts live in host RAM. One prepared SRAM list is replaced only when
    # the presentation changes, before that packet begins drawing.
    layouts = {}
    counts = {}
    for kind, layout in info["layouts"].items():
        if kind == 2:
            continue
        records = []
        for index, code, attr in layout:
            y = 248 - (index & 31) * 8
            x = (index >> 5) * 8 - 16
            if 0 <= x < 224:
                glyph = -code - 1 if code < 0 else info["glyphs"][code, attr]
                # Repaint only glyphs that a moving ending actor can cover.
                # All glyphs still enter the cached tableau as they type.
                front = (17 <= kind < 30 or 74 <= kind <= 84) and (
                    40 <= y < 56
                    or 112 <= y < 128
                    or (80 <= x < 144 and y >= 80)
                    or (74 <= kind <= 84 and code < 0)
                )
                assert glyph < 256, (kind, code, attr, glyph)
                records.append(
                    struct.pack(
                        "<HB",
                        y * 56 + x // 4 + (0x4000 if code < 0 else 0) + (0x8000 if front else 0),
                        glyph,
                    )
                )
        if kind == 1:
            logo = {
                struct.pack(
                    "<HB",
                    (248 - (i & 31) * 8) * 56 + ((i >> 5) * 8 - 16) // 4,
                    info["glyphs"][code, attr],
                )
                for i, code, attr in info["layouts"][2]
                if 0 <= (i >> 5) * 8 - 16 < 224
            }
            records.sort(key=lambda r: (r not in logo, r))
            info["demo_logo_count"] = sum(r in logo for r in records)
        layouts[kind] = b"".join(records) + b"\xff\xff\x00"
        counts[kind] = len(records)
    from asset_source import Source
    from secondsight_link import asset
    from world_stream import card_job

    directory = [(0, 0)] * 96
    stored = {}
    prefix = layouts[29][:-3]
    info["post_jobs"] = {}
    for kind, data in layouts.items():
        if 74 <= kind <= 84:
            assert data.startswith(prefix), (kind, len(prefix))
            key = (data, "post")
            job = card_job("cab_layout", data[len(prefix) :], len(prefix)) + b"\0"
        else:
            key = (data, kind in (4, 86), kind == 86, kind in (3, 16))
            job = card_job("cab_layout", data)
            if kind in (4, 86):
                # Both pages cache mode 4. A prompt transition changes the
                # layout without changing that mode or the credit value.
                job += card_job("cabinet_page_signature", b"\xff\xff")
                job += card_job("cab_prompt_visible", bytes((kind == 86,)))
            if kind in (3, 16):
                # A literal job lets the host fill the current 79 glyphs in
                # the packet before the card uploads the prepared layout.
                raw_at = len(job) + 11
                job += card_job("cab_rank_fields", bytes(79), literal=True)
                info["rank_packet_fields"] = raw_at
            job += b"\0"
        if len(job) & 1:
            job += b"\0"
        # Static ranking has no live object or art list; it has the full
        # 1792-byte packet area, while other pages keep their former cap.
        assert len(job) <= (1400 if kind in (3, 16) else 1000), (
            "cabinet layout packet",
            kind,
            len(job),
        )
        if key not in stored:
            stored[key] = host.blob_at(job)
        if 74 <= kind <= 84:
            info["post_jobs"][kind] = (len(job), stored[key])
            continue
        directory[kind] = (len(job), stored[key])
    layouts = HostData()
    for length, address in directory:
        layouts.word(length).dword(address)
    info["layout_directory"] = host.blob_at(layouts, "CABINET_LAYOUTS")
    # The glyphs of the digits 0-9 and the space (src/secondsight/cabinet.s cab_digits).
    digits = bytes(info["glyphs"][n, 0] for n in (*range(10), 0x24))
    source = Source("cabinet digit glyphs (scripts/cabinet_video.py)").section(".data.cab_digits", "aw")
    asset("cab_digits", source.label("cab_digits").data(digits))
    define("cab_demo_logo_glyphs", info["demo_logo_count"])

    from cabinet_live import install as install_live

    install_live(scene)
    post_index = {code: i for i, code in enumerate(post_codes)}
    glyphs = [post_index.get(n, post_index[0x24]) for n in range(103)]
    from roms import load

    alphabet = load()[0]["maincpu"][0x22AF:0x22DD]
    host.out.joinpath("cabinet_post_data.inc").write_text(
        f"CAB_RANK_PACKET_FIELDS = {info['rank_packet_fields']}\n"
        + f"CAB_POST_FONT_HIGH = {len(post_codes)}\n"
        + f"CAB_POST_FONT_PLAYER = {len(post_codes) + 10}\n"
        + f"CAB_POST_FONT_FLASH = {post_flash}\n"
        + "cabinet_post_glyphs:\n  .byte "
        + ",".join(map(str, glyphs))
        + "\n"
        + "cabinet_post_alphabet:\n  .byte "
        + ",".join(map(str, alphabet))
        + "\n"
        + "cabinet_post_counts:\n  .byte "
        + ",".join(str(counts[n]) for n in range(74, 85))
        + "\n"
    )


def config_include(scene):
    """build/secondsight/gen/cabinet_config.inc: the cabinet values of this build."""
    from secondsight_link import generate_include

    surface = scene.cabinet_surface
    palette = bytes(sorted(set(scene.cabinet_pages[5]))).ljust(4, b"\0")
    assert len(palette) == 4
    assert len(scene.cabinet_plane_directory) == 8

    def write():
        values = {
            "CABINET_SURFACE": surface,
            "CABINET_COMMANDS": surface + 14336,
            "CABINET_FLAG_FRONT_LIMIT": scene.cabinet_flag_front_limit,
            **{f"CABINET_PALETTE_{i}": v for i, v in enumerate(palette)},
            **{f"CABINET_POSE_{i}": a & 0xFFFF for i, a in enumerate(scene.cabinet_plane_directory)},
        }
        lines = ["; Generated by scripts/cabinet_video.py: the cabinet values of this build."]
        lines += [f"        .equ {name}, 0x{value:X}" for name, value in values.items()]
        lines.append("        .macro ending_palette")
        lines += [
            f"        ending_colour 0x{index:02X}, " + ", ".join(f"0x{v:02X}" for v in rgb)
            for index, rgb in scene.cabinet_ending_palette.items()
        ]
        lines.append("        .endm")
        return "\n".join(lines) + "\n"

    generate_include("cabinet_config", write())


def sources(scene):
    mark_damage(scene)
    # The space of the fast demo program records, until prepare_fast_demo.
    demo_tables_source([])


def mark_damage(scene):
    """Move the existing dispatcher to descriptor SRAM; keep its bounds."""
    tables = {}
    for name, kinds in (("demo", (1, 2)), ("idle", (3, 4, 6, 7, 16)), ("result", range(30, 74))):
        rows = {}
        for kind in kinds:
            for index, code, attr in scene.cabinet_video["layouts"].get(kind, []):
                y = 248 - (index & 31) * 8
                x = (index >> 5) * 2 - 4
                if 0 <= x < 56:
                    for yy in range(y, y + 8):
                        lo, hi = rows.get(yy, (56, 0))
                        rows[yy] = (min(lo, x), max(hi, x + 2))
        data = bytearray()
        y = 0
        while y < 256:
            if y not in rows:
                y += 1
                continue
            lo, hi = rows[y]
            end = y + 1
            while end < 256 and rows.get(end) == (lo, hi):
                end += 1
            data += bytes((end - y, y, hi, lo))
            y = end
        tables[name] = data + b"\0"
    from secondsight_link import generate

    lines = [
        "; Generated by scripts/cabinet_video.py: the text rows of each cabinet layout,",
        "; as damage runs (rows, first row, right, left), 0 at the end.",
        '        .section .rodata.cab_damage,"a",@progbits',
    ]
    for name, data in tables.items():
        lines += [f"        .global cab_damage_{name}", f"cab_damage_{name}:"]
        lines += ["        .byte " + ", ".join(str(v) for v in data[i : i + 16]) for i in range(0, len(data), 16)]
    generate("cab_damage", "\n".join(lines) + "\n")


