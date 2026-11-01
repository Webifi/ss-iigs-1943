"""The build-time sound clock, the DOC voice layout and the output gain."""

import math

# Six even/odd FM crossfade pairs, six odd/even SSG AM pairs, and the
# silent final timer. Slot 12 separates the opposite hardware parities.
# No extra DAC voices are enabled just to raise the output level.
DOC_VOICES = 26
DOC_TIMER = 25
FM_PAIRS = tuple((2 * ch, 2 * ch + 1) for ch in range(6))
SSG_VOICES = tuple((12, 13 + 2 * ch, 14 + 2 * ch) for ch in range(6))
DOC_RATE = 14318180 / 16 / (DOC_VOICES + 2)
MASTER_NIBBLE = 5
# The master volume scales the output linearly.
MASTER_GAIN = MASTER_NIBBLE / 15
# Peak sample of the IIgs startup sound at master volume 5, in the 16-bit
# scale of the arcade sound render. The loudest arcade sound effect plays at
# this level: the one fixed level reference of all sounds.
CHIME_PEAK = 6599


def knee_volume(d):
    low, high = 0.0, (5 * d / 256) / 1000
    for _ in range(64):
        mid = (low + high) / 2
        if mid * 1000 + 1.75 * 0.025852 * math.log1p(mid / 2.5e-9) > 5 * d / 256:
            high = mid
        else:
            low = mid
    return round(256 * ((low + high) / 2) * 1000 / 5 * 16384) / 16384


KNEE = [knee_volume(d) for d in range(256)]


def volume_register(linear, law):
    """Preserve requested amplitude; only the hardware transfer law changes."""
    return min(range(256), key=lambda d: abs(KNEE[d] - linear))


# Measured on songs 20, 23 and 2F: the original sound program keys each note
# 17.4 ms (4 sequencer ticks plus write time) after the score tick. The
# player starts every part 4 ticks after its command, as the arcade does.
