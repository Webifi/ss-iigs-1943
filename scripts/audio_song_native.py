"""Real song through the native FM part engine and the SSG effect bank.

The game carries the compact score, its loops and jingle priorities, every
FM capture and its native record (scripts/fm_native.py). The song starts on
a game-style request at tick 1 + music_delay. No test note and no separate
listening page are produced.
"""

from audio_config import DOC_VOICES, DOC_TIMER
from audio_envelopes import timing_table
import fm_native


def prepare(
    out,
    host,
    command=0x20,
    seconds=8,
    compact_ssg=True,
    music_delay=0,
    effect_tick=None,
    effect_commands=(10, 13),
):
    if compact_ssg:
        from audio_bank_install import install

        install(out, host)
    fm, receipt = fm_native.assets(host)
    values = timing_table()
    assert len({v >> 8 for v in values}) == 1
    host.blob_at(b"\xff\xff", "WAVE_QUEUE")
    host.blob_at(bytes(v & 255 for v in values), "music_irq_frequencies")
    lines = [
        f"DOC_ENABLED_COUNT = {DOC_VOICES}",
        f"MUSIC_TIMER_VOICE = {DOC_TIMER}",
        "MUSIC_ENABLED = 1",
        "AUDIO_PROFILE = 1",
        *fm,
        f"MUSIC_FEATURE_TICK = {1 + music_delay}",
        f"MUSIC_FEATURE_COMMAND = {command}",
        f"MUSIC_TIMER_HIGH_CONSTANT = {values[0] >> 8}",
    ]
    if compact_ssg:
        lines += [
            "AUDIO_COMPACT_SSG = 1",
            f"SSG_FEATURE_TICK = {1 + round(2 * fm_native_tick())}",
            f"SSG_FEATURE_COMMAND_A = {effect_commands[0]}",
            f"SSG_FEATURE_COMMAND_B = {effect_commands[1]}",
        ]
    (out / "audio_data.inc").write_text("\n".join(lines) + "\n")
    return dict(
        command=command,
        seconds=seconds,
        effects=list(effect_commands),
        compact_ssg=compact_ssg,
        music_delay=music_delay,
        effect_tick=effect_tick,
        enabled_count=DOC_VOICES,
        fm=receipt,
        scope="Native FM part engine with every song and capture resident, and the complete native effect commands",
    )


def fm_native_tick():
    return 6e6 / (384 * 262) * 4
