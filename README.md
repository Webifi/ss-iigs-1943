# 1943 for the Apple IIgs with Second Sight

> **Prerelease.** This build is not finished.

A port of Capcom's arcade game *1943: The Battle of Midway* (US release) to the
Apple IIgs with a Sequential Systems Second Sight card. The game runs as native
65816 and Z180 code.

This repository contains no ROM data. Everything the game needs is made from
your own ROM files when you build.

## What you need to play

- A ROM 03 Apple IIgs, or a ROM 01 with a 1 MB memory card
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

The disk images are in `build/game-disk/`. The code in each name (HASH, for
example `1943-ee19c6.hdv`) changes when the game changes, so you can tell
builds apart:

- `1943-HASH.hdv`: a ProDOS volume, for a CFFA3000, a FloppyEmu or another
  SmartPort hard disk, a MicroDrive/Turbo, a BOOTI or an emulator
- `1943-HASH-scsi.hda`: the same volume with an Apple partition map, for an Apple
  SCSI card with a BlueSCSI, ZuluSCSI or SCSI2SD
- `debug.sym`: the debug symbols of this build, every IIgs and Second Sight
  address, for emulator debug runs (format in `scripts/debug_symbols.py`)

## Play

Boot the IIgs from the 1943 disk. When it has loaded, the game shows its
attract mode, like the arcade machine. Press 5 to add a coin, then 1 to start.

### Default controls

| Action | Player 1 | Player 2 |
|---|---|---|
| Move | W A S D, I J K L, arrow keys, keypad 8 4 5 6 | Mouse, joystick |
| Fire | Control | Mouse button, joystick button 1 |
| Special | Option | Shift, keypad Enter, joystick button 2 |
| Start | 1 | 2 |
| Coin | 5 (coin A) | 6 (coin B) |

Press Esc for the options menu. Esc cannot be changed.

The keys work on the ADB keyboard and on a J13 keyboard. The mouse works like
a joystick: move it to fly that way, and move it back to stop.

SNES pads (on a SNES MAX adapter): pad one is player 1, pad two is player 2.
The D-pad moves, B fires, Y is the special, Start starts and Select adds a
coin. Set the adapter's slot in the DEVICES menu first.

### Options menu

Press Esc during play to pause and open the menu. The up and down arrows
choose, Return selects, and Esc goes back. Esc on the first page returns to
the game. A joystick, the mouse or a pad works too: move to choose, press a
button to select.

- **CONTROLS**: change the keys for PLAYER 1, PLAYER 2 and START AND COINS.
  Pick an action, then CHANGE its key, ADD another key, or REMOVE one. After
  CHANGE or ADD, press the new key or button. NEXT BINDING steps through the
  keys of an action that has more than one. BOTH KEYBOARDS picks whether a key
  works on the ADB keyboard, the J13 keyboard, or both.
- **DEVICES**: Return or the right arrow changes a setting.
  - J13 PLAY: turn on to play with a J13 keyboard. The menu always works with
    it.
  - SNES MAX SLOT: the adapter's slot (1, 2, 4, 5 or 6). Default: none.
  - RECHECK JOYSTICK: look for the joystick again, for example after you plug
    one in.
  - MOUSE DEAD ZONE: how far the mouse must move before the plane moves (3 to
    24, default 9).
  - MOUSE PLAYER, JOYSTICK PLAYER: which player uses the mouse or the joystick
    (default player 2).
  - RESTORE DEFAULT BINDINGS: puts all keys back as in the table above.
- **SOUND**: music and effects volume (0 to 100, default 100). DEMO SOUNDS
  turns the sound of the attract mode on or off (default on).
- **DISPLAY**: the refresh rate for your monitor. The game runs at the rate
  you pick.
  - VGA: ARCADE 59.64 HZ (default, the arcade speed), 800X600 SYNC 59.65 HZ,
    800X600 VESA 60.32 HZ, or CUSTOM TIMING. VGA SYNC sets the sync polarity.
  - AppleColor RGB: BALANCED 58.74 HZ (default), NEAR ARCADE 59.59 HZ, 50 HZ
    FALLBACK 49.92 HZ, CUSTOM TIMING, or IIGS LINE RATE 56.36 HZ.
  - HORIZONTAL and VERTICAL edit the timing by hand. RESTORE DEFAULT undoes
    those edits.
- **DIP SWITCHES**: the arcade machine's settings. Return or the left and
  right arrows change a setting.
  - DIFFICULTY: 1 (easiest) to 16 (hardest), default 8.
  - 2 PLAYER GAME: a 2 player game costs 2 credits (default) or 1.
  - COIN A, COIN B: credits for each coin, from 1 coin 1 credit (default) to 1
    coin 5 credits or 4 coins 1 credit.
  - CONTINUE: lets you continue after the game ends (default on).
  - DEMO SOUNDS: the same as in SOUND.
  - SCREEN STOP: freezes the game (default off).
- **SAVE**: saves all settings to the disk. Without SAVE, your changes are lost
  when you restart or switch off the IIgs.
- **RESUME**: back to the game.

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
