"""Stage 1, sound: the DOC sound bank, made from the 1943 sound ROM.

1. The Python port of the sound program (scripts/sound_driver.py) plays each
   song and each sound effect and logs its YM2203 register writes.
2. The renderer (scripts/ym_stems.cpp on the ymfm library) plays the logs.
   Each instrument patch plays alone on an idle channel, and each sound
   effect plays in one clocked pass.
3. scripts/audio_snapshot_bank.py converts the renders to DOC tables and
   native tick records: build/sound/bank.

The stage runs again only when the ROM, a stage script or the renderer
source changes. build/sound/stage.json holds the key of the last run.
"""

import hashlib
import json
import subprocess

from roms import ROOT, load
from sound_files import SOUND, SCORE_LOG, EFFECT_LOG, SCORE, BANK

SOURCES = [
    "scripts/" + name
    for name in (
        "sound_assets.py",
        "sound_files.py",
        "sound_driver.py",
        "sound_logs.py",
        "music.py",
        "music_score.py",
        "instruments.py",
        "instrument_library.py",
        "instrument_isolated.py",
        "ssg_models.py",
        "ssg_controls.py",
        "ym_controls.py",
        "ssg_logic.py",
        "fm_snapshots.py",
        "sound_model.py",
        "audio_snapshot_bank.py",
        "audio_bank_codec.py",
        "audio_preview.py",
        "audio_config.py",
        "ym_stems.cpp",
    )
] + sorted(str(p.relative_to(ROOT)) for p in (ROOT / "third_party/ymfm/src").iterdir())


def key(rom):
    digest = hashlib.sha256(rom)
    for name in SOURCES:
        digest.update(name.encode() + b"\0" + (ROOT / name).read_bytes())
    digest.update(subprocess.check_output(["sox", "--version"]))
    return digest.hexdigest()


def build():
    """Make build/sound/bank, or keep it when its inputs did not change."""
    import sound_logs

    rom = load()[0]["audiocpu"][:0x8000]
    stamp = SOUND / "stage.json"
    want = key(rom)
    if stamp.exists() and json.loads(stamp.read_text())["key"] == want:
        return
    stamp.unlink(missing_ok=True)
    # The Makefile builds the renderer (build/sound/ym_stems) before the asset build.
    sound_logs.write(SCORE_LOG, sound_logs.run(rom, sound_logs.song_schedule(rom)))
    sound_logs.write(EFFECT_LOG, sound_logs.run(rom, sound_logs.effect_schedule()))

    import music_score, instrument_library, instrument_isolated, ssg_models, audio_snapshot_bank

    score = music_score.compile_scores(rom, SCORE)
    instrument_isolated.capture(instrument_library.select(score))
    ssg_models.capture_all()
    audio_snapshot_bank.build()
    stamp.write_text(json.dumps(dict(key=want, bank=str(BANK.relative_to(ROOT))), indent=2) + "\n")


if __name__ == "__main__":
    build()
