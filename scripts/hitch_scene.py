"""Diagnostic: prepare intro metadata first, then draw into hidden title twins."""



def place_banked(scene):
    """The prepaint helper, in the banked code page (.bank_code of secondsight.ld)."""
    from secondsight_link import alias

    for name, value in zip(("hitch_jobs_bank", "hitch_jobs_pointer", "hitch_jobs_segment"), scene.hitch_jobs):
        alias(name, value)
    alias("normal_water_high", scene.normal_water_pattern("gb1"))
    alias("normal_water_segment", scene.normal_water_pattern("vseg"))


def preservation_jobs(scene):
    # The intro is permanently resident: each stage's row colors are
    # disjoint from different intro rows, and combined_world's intro arena
    # is excluded from every mutable section arena.
    from world_stream import INTRO, resident_ranges

    assert any(lo <= 0xD101 and hi >= 0xD200 for lo, hi in resident_ranges(INTRO))
    intro = scene.row_sets[INTRO]
    intro_colors = {scene.row_colors[i]: i for i in intro}
    assert len(intro_colors) == len(intro)
    for rows in scene.row_sets.values():
        assert all(
            scene.row_colors[i] not in intro_colors or intro_colors[scene.row_colors[i]] == i
            for i in rows
        )
    jobs = []
    for y in range(225, 256):
        row = scene.game_world.runs[scene.game_world.run(0xD200 - y, 0)]
        for i in range(row[0]):
            start, end, mask = row[1 + i * 3 : 4 + i * 3]
            start = max(start, 4)
            end = min(end, 60)
            if start < end:
                jobs.append((y, start - 4, end - start, mask))
    assert sum(n * mask.bit_count() for _, _, n, mask in jobs) == 908, jobs
    return bytes(v for job in jobs for v in job) + b"\xff"


def place_preservation_jobs(scene, jobs):
    """The jobs follow the selector code in plane 3 of the repair core block."""
    from asset_source import Source, derived
    from secondsight_link import asset

    source = Source("title preservation jobs (scripts/hitch_scene.py)")
    source.section(".plane.repair_cores.3.1").label("hitch_jobs").data(jobs)
    asset("hitch_jobs", source)
    scene.hitch_jobs = tuple(derived(kind, "hitch_jobs") for kind in ("pbbr", "pptr", "pseg"))


