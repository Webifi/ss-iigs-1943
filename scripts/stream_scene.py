"""Concurrent IIgs -> DMA1 command streaming into two common-area buffers.

This is the native frame transport. There is no per-frame ROM call and no IIgs interrupt. DMA1 receives the next
packet while the Z180 draws the current one. No SRAM staging copy remains.
"""

from scene import Scene

RX_PTR = 0x3350
RECEIVE_TIME_PTR = 0x33B8
RECEIVE_START = 0x33BA


class StreamScene(Scene):
    streaming = True

    def __init__(self, *args, **kwargs):
        super().__init__(*args, window=0x2000, **kwargs)

