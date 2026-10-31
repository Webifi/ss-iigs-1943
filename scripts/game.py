"""Build the single playable game. No captured states or control playback."""

from flight_loop import build
from boot_disk import build as boot
import sound_assets
from arcade import ROOT
import json, subprocess, sys


def main():
    widths = subprocess.check_output(
        [sys.executable, str(ROOT / "scripts/width_lint.py"), str(ROOT / "src")], text=True
    ).strip()
    if widths != "none found":
        raise RuntimeError("65816 immediate width mismatch:\n" + widths)
    sound_assets.build()
    out = build()
    result = boot(out, ROOT / "build/game-disk")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
