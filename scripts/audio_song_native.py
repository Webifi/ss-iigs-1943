"""The sound data of the game: the SSG effect bank and every FM song asset.

The game carries the compact score, its loops and jingle priorities, every
FM capture and its native record (scripts/fm_native.py).
"""

from audio_config import DOC_TIMER, SSG_VOICES
from audio_envelopes import timing_table
from audio_bank_install import install
import fm_native


def prepare(out, host):
    install(out, host)
    fm, _ = fm_native.assets(host)
    values = timing_table()
    assert len({v >> 8 for v in values}) == 1
    host.blob_at(bytes(v & 255 for v in values), "music_irq_frequencies")
    lines = [
        f"MUSIC_TIMER_VOICE = {DOC_TIMER}",
        f"DOC_SSG_FIRST = {SSG_VOICES[0][1]}",
        *fm,
        f"MUSIC_TIMER_HIGH_CONSTANT = {values[0] >> 8}",
    ]
    (out / "audio_data.inc").write_text("\n".join(lines) + "\n")
