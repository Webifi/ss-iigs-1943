"""Precompile captured-table playback into the final one-voice DOC lists."""

from audio_config import DOC_RATE

TICK = 6e6 / (384 * 262) * 4


def timing_table():
    # The original sound IRQ visits scanlines32,96,160,224. Error diffusion
    # chooses ready timer frequencies; no rate division occurs at run time.
    values = []
    error = 0.0
    for i in range(256):
        seconds = (70 if i % 4 == 3 else 64) * 384 / 6e6
        exact = (1 << 17) / (seconds * DOC_RATE)
        f = round(exact + error)
        error += exact - f
        values.append(f)
    return values
