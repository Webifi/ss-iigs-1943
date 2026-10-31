"""Stage report text, authored order and pauses from the US presentation."""

import struct
from roms import load
from cabinet_text import Lettering


def prepare():
    r = load()[0]["maincpu"]
    layouts = {}
    timelines = {}

    def rate(t):
        t.text(0x29CF)
        for at, i in zip((0xD1CC, 0xD1EC, 0xD20C), (3, 4, 5)):
            t.field(at, i, wait=6)
        t.add([(0x22C, 0x2D, 0)], sound=False, instant=True)
        t.line_cue = True
        t.wait(6)

    for stage, (name, action) in enumerate(
        zip(struct.unpack_from("<16H", r, 0x2C2A), struct.unpack_from("<16H", r, 0x2C5D))
    ):
        t = Lettering().text(0x2966).wait(6).text(name, instant=True).text(action).wait(18)
        rate(t)
        kind = 46 + stage
        layouts[kind] = t.layout
        timelines[kind] = t.finish(66)
    for kind, retry in ((31, False), (44, True)):
        t = Lettering().text(0x298F).wait(30)
        rate(t)
        t.wait(30)
        if retry:
            t.text(0x29E8)
        layouts[kind] = t.layout
        timelines[kind] = t.finish(60)
    layouts[30] = layouts[46]
    timelines[30] = timelines[46]
    statistics = []
    for bonus, pointer in enumerate(struct.unpack_from("<12H", r, 0x2CB3)):
        variants = []
        for flags in range(4):
            nil = bool(flags & 1)
            surplus = bool(flags & 2)
            t = Lettering().text(0x2A7F)
            t.field(0xD1F9, 1, wait=0).field(0xD219, 2).text(0x2A89).wait(6)
            t.text(0x2A95).text(pointer).wait(6).text(0x2AA7)
            for at, i in zip((0xD2F0, 0xD310, 0xD330), (6, 7, 8)):
                t.field(at, i)
            t.wait(6).text(0x2AC0)
            if nil:
                t.text(0x2AD3)
            else:
                t.field(0xD2EC, 9, wait=0).field(0xD30C, 10).field(0xD32C, 11).wait(6)
            # One layout per bonus. Zero surplus ends before its two lines.
            prefix_timing = t.finish(120)
            t.text(0x2AE2).field(0xD26A, 12).text(0x2AF1).wait(30)
            t.layout = [(i, c, 10 if i == 0x10A else a) for i, c, a in t.layout]
            layouts[(62 if nil else 32) + bonus] = t.layout
            variants.append(t.finish(120) if surplus else prefix_timing)
        statistics.append(variants)
    return layouts, timelines, statistics
