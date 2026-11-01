"""The asset build: the sound bank, the art and the data from the ROM files,
and the generated sources of the Second Sight and IIgs programs. The
Makefile runs it when its inputs change, then links the programs."""

import sound_assets
from game_build import build


def main():
    sound_assets.build()
    build()


if __name__ == "__main__":
    main()
