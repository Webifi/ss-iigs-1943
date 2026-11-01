# 1943 for the Apple IIgs with Second Sight

> **Prerelease.** This build is not finished.

A port of Capcom's arcade game *1943: The Battle of Midway* (US release) to the
Apple IIgs with a Sequential Systems Second Sight card. The game runs as native
65816 and Z180 code.

This repository contains no ROM data. Everything the game needs is made from
your own ROM files when you build.

## Build

You need:

- Python 3.12 or newer, as `python3`
- cc65 (`ca65` and `ld65`; macOS: `brew install cc65`)
- GNU binutils for the `z80-elf` target (`z80-elf-as`, `z80-elf-ld`, `z80-elf-objcopy`
  and `z80-elf-nm`)
- make, a C++17 compiler and SoX (macOS: `xcode-select --install`, `brew install sox`)
- a network connection for the first build, which installs the Python packages
  into `.venv/`

1. Put your 1943 ROM set into `roms/` (see `roms/README.md`).
2. Run `./build.sh`.

The disk images are in `build/game-disk/`:

- `1943.hdv`: a ProDOS volume, for a CFFA3000, a FloppyEmu or another
  SmartPort hard disk, a MicroDrive/Turbo, a BOOTI or an emulator
- `1943-scsi.hda`: the same volume with an Apple partition map, for an Apple
  SCSI card with a BlueSCSI, ZuluSCSI or SCSI2SD
- `debug.sym`: the debug symbols of this build, every IIgs and Second Sight
  address, for emulator debug runs (format in `scripts/debug_symbols.py`)

## Folders

| Folder | Contents |
|---|---|
| `src/` | 65816 source for the IIgs side |
| `src/secondsight/` | Z180 source for the Second Sight card |
| `bootloader/` | The boot block and file reader that replace ProDOS (see its README) |
| `scripts/` | The build: ROM reading, art, sound, card data, disk image |
| `third_party/` | ymfm (YM2203 sound chip model), used by the build |
| `assets/` | Data made for this port, with the scripts that make it |
| `roms/` | Your ROM files (not in the repository) |
| `build/` | Build output (not in the repository) |

## Assets

`assets/` holds data made for this port, not taken from the ROM. Each asset
folder has the script that makes it and a README.

- `assets/water/`: the stage water texture.

## License

MIT (`LICENSE`). `third_party/ymfm/` keeps its own BSD 3-Clause license.
