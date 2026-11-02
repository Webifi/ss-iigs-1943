# 1943 for the Apple IIgs with Second Sight

> **Prerelease.** This build is not finished.

A port of Capcom's arcade game *1943: The Battle of Midway* (US release) to the
Apple IIgs with a Sequential Systems Second Sight card. The game runs as native
65816 and Z180 code.

This repository contains no ROM data. Everything the game needs is made from
your own ROM files when you build.

## What you need to play

- An Apple IIgs with RAM in banks $02-$0F: a ROM 03 with its 1 MB, or a ROM 01
  with a 1 MB memory card
- A Second Sight card in slot 3, with a VGA monitor or an AppleColor RGB
  monitor on the card
- A hard disk device for the disk image (see the list under Build)
- Optional: an ADB mouse, a game-port joystick, a J13 keyboard (ROM 00 and
  ROM 01), or a SNES MAX adapter with one or two SNES pads

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

The disk images are in `build/game-disk/`. HASH in their names is the first 6
hex digits of the SHA-256 of the game data (SS1943.SYSTEM and SS1943.DATA), so a
build with different game data gets a different name:

- `1943-HASH.hdv`: a ProDOS volume, for a CFFA3000, a FloppyEmu or another
  SmartPort hard disk, a MicroDrive/Turbo, a BOOTI or an emulator
- `1943-HASH-scsi.hda`: the same volume with an Apple partition map, for an Apple
  SCSI card with a BlueSCSI, ZuluSCSI or SCSI2SD
- `debug.sym`: the debug symbols of this build, every IIgs and Second Sight
  address, for emulator debug runs (format in `scripts/debug_symbols.py`)

## Play

Start the IIgs from the 1943 volume. The game loads and starts its attract
mode, as the arcade machine does. Put in a coin, then push a start key.

### Default controls

| Action | Player 1 | Player 2 |
|---|---|---|
| Move | W A S D, I J K L, arrow keys, keypad 8 4 5 6 | Mouse, joystick |
| Fire | Control | Mouse button, joystick button 1 |
| Special | Option | Shift, keypad Enter, joystick button 2 |
| Start | 1 | 2 |
| Coin | 5 (coin A) | 6 (coin B) |

Esc opens the options menu. You cannot change the Esc key.

The keyboard keys work on the ADB keyboard and on a J13 keyboard. The mouse
is a virtual stick: move the mouse away from its centre to push the plane,
and move it back to stop.

SNES pads on a SNES MAX adapter: pad one is player 1, pad two is player 2.
The direction pad moves, B fires, Y is the special, Start is the start of
that player, and Select puts in a coin (pad one coin A, pad two coin B). Set
the slot of the adapter in the DEVICES menu first.

### Options menu

Push Esc during the game to stop it and open the menu. Use the up and down
arrows to choose, and Return to select. Esc goes back one page, and Esc on
the first page goes back to the game. A joystick, the mouse or a pad also
works: its directions are the arrows, and its buttons are Return.

- **CONTROLS**: the bindings of PLAYER 1, PLAYER 2 and START AND COINS. Choose
  an action, then CHANGE (the next key or device input replaces the binding),
  ADD (the next input is one more binding), REMOVE, NEXT BINDING, or BOTH
  KEYBOARDS (the binding is for the ADB keyboard, the J13 keyboard, or both).
  There is space for 64 bindings.
- **DEVICES**: Return or the right arrow changes a value.
  - J13 PLAY: ON makes the game read the J13 keyboard during play. The menu
    always reads it.
  - SNES MAX SLOT: the slot of the adapter (1, 2, 4, 5 or 6). The default is
    none.
  - RECHECK JOYSTICK: look for the joystick again.
  - MOUSE DEAD ZONE: how far the mouse moves before it pushes the plane (3 to
    24, default 9).
  - MOUSE PLAYER and JOYSTICK PLAYER: move that device and its bindings to
    the other player (default player 2).
  - RESTORE DEFAULT BINDINGS: all bindings go back to the table above.
- **SOUND**: MUSIC VOLUME and EFFECTS VOLUME (0 to 100, default 100), DEMO
  SOUNDS (sound in the attract mode, default ON).
- **DISPLAY**: the timing of the monitor that the card uses (VGA or
  AppleColor RGB). The game speed follows the picture rate of the preset.
  - VGA presets: ARCADE 59.64 HZ (default), 800X600 SYNC 59.65 HZ, 800X600
    VESA 60.32 HZ, CUSTOM TIMING. VGA SYNC sets the sync polarity.
  - RGB presets: BALANCED 58.74 HZ (default), NEAR ARCADE 59.59 HZ, 50 HZ
    FALLBACK 49.92 HZ, CUSTOM TIMING, IIGS LINE RATE 56.36 HZ.
  - HORIZONTAL and VERTICAL edit the timing. RESTORE DEFAULT puts back the
    factory timing of the preset.
- **DIP SWITCHES**: the switches of the arcade machine. Return or the right
  arrow gives the next value, and the left arrow gives the value before.
  - DIFFICULTY (1-16): 1 is the easiest (default 8).
  - 2 PLAYER GAME: 2 players cost 2 credits (default) or 1 credit.
  - COIN A and COIN B: 1 coin 1 credit (default), up to 1 coin 5 credits or 4
    coins 1 credit.
  - CONTINUE: ON (default) or OFF.
  - DEMO SOUNDS: the same setting as in SOUND.
  - SCREEN STOP: ON stops the play (default OFF).
- **SAVE**: write all the settings to the file SS1943.CONFIG on the 1943
  volume. The game reads them at the next start. Without SAVE, the changes
  stay only until you switch off or restart the IIgs.
- **RESUME**: go back to the game.

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
