"""Three shared alignments for the visible ship rows, indexed by world row.

Canonical pixels remain in the clean display rows. Each additional alignment
holds 256 x 32 groups for ships, or 128 x 64 for the short, wide plane bosses.
Both display pages use the same prepared pixels and the same allocation.
"""

PITCH = 32
BYTES = 256 * PITCH * 4


def prepare(scene, pool):
    scene.ship_alignment_bases = [pool.runtime(BYTES, 8192) for _ in range(3)]
    assert all((p & 65535) + BYTES // 4 <= 65536 for p in scene.ship_alignment_bases)


def boss_columns(world):
    """The three native boss-camera sections contain short aircraft bodies."""
    columns = set()
    # These are the camera values selected by the three boss_camera controls.
    # Inspect the actual ROM map; do not substitute a recorded game window.
    for camera in (0xF100, 0xE100, 0xF900):
        rows = []
        for row in range(camera, camera + 512):
            column = world.column_index[row >> 5]
            if world.runs[world.columns[column][0][row & 31]][0]:
                rows.append(row)
                columns.add(column)
        assert rows and max(rows) - min(rows) < 128, ("wide boss cache height", hex(camera), rows)
        assert len({r & 127 for r in rows}) == len(rows), "wide boss rows alias"
    return columns


def bases_source(scene):
    """build/secondsight/gen/ship_alignment_bases.s: the video RAM bases of the
    three alignments."""
    from secondsight_link import generate

    lines = [
        '        .section .rodata.ship_alignment_bases,"a"',
        "        .global ship_alignment_bases",
        "ship_alignment_bases:",
    ]
    for address in scene.ship_alignment_bases:
        lines.append(f"        .word 0x{address & 0xFFFF:04X}")
        lines.append(f"        .byte 0x{address >> 16:02X}")
    generate("ship_alignment_bases", "\n".join(lines) + "\n")


