"""The asset build: the sound bank, the art and the data from the ROM files,
and the generated sources of the Second Sight and IIgs programs. The
Makefile runs it when its inputs change, then links the programs."""

import multiprocessing

import sound_assets
from game_build import build


def main():
    # The game build reads the files of the sound stage only at its audio
    # step, so the sound stage runs in its own process at the same time.
    sound = multiprocessing.get_context("spawn").Process(target=sound_assets.build, name="sound stage")
    sound.start()

    def sound_ready():
        sound.join()
        if sound.exitcode:
            raise SystemExit(f"The sound stage failed (exit code {sound.exitcode}).")

    build(sound_ready)


if __name__ == "__main__":
    main()
