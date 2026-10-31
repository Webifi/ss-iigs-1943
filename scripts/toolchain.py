"""The assemblers and linkers, found on PATH."""

import shutil


def cc65(tool):
    path = shutil.which(tool)
    if path is None:
        raise SystemExit(f"{tool} not found on PATH. Install cc65 (macOS: brew install cc65).")
    return path


def z80(tool):
    """A GNU binutils tool for the z80-elf target, for example z80('as')."""
    name = f"z80-elf-{tool}"
    path = shutil.which(name)
    if path is None:
        raise SystemExit(f"{name} not found on PATH. Install GNU binutils for the z80-elf target.")
    return path
