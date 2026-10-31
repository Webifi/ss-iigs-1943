"""Ending actors use the game's resident ROM-art cache, without another atlas."""

from roms import load


def typing_ticks(data, hold):
    import struct

    count = data[0]
    ticks = 0
    for target, wait, flags in struct.iter_unpack("<BHB", data[1:]):
        ticks += wait
        if target == 255:
            return ticks - hold
        if not flags & 2:
            ticks += 3 * (target - count)
        count = target
    raise AssertionError("unterminated lettering")


def data(allocate):
    r = load()[0]["maincpu"]
    flags = []
    for off in range(0x7919, 0x7935, 7):
        _, code, attr = r[off : off + 3]
        flags += [
            v
            for row in range(4)
            for col in range(4)
            for v in ((code + row * 8 + col) & 255, attr, 96 + col * 16, row * 16)
        ]
    # Native motion schedule: walk, look back, walk, turn, wag, walk away.
    # Every pair is the pose and horizontal position at a 30 Hz update.
    walk = [(2, 0xD7, 384), (2, 0xD6, 384), (2, 0xD7, 384), (2, 0xDE, 384)]
    pause = [
        (30, 0xEB, 0),
        (20, 0xE8, 0),
        (20, 0xEB, 0),
        (20, 0xE8, 0),
        (20, 0xEB, 0),
        (20, 0xE8, 0),
        (30, 0xEB, 0),
    ]
    sequence = (
        walk * 10
        + pause
        + walk * 5
        + [(60, 0xDF, 0), (30, 0xD7, 0)]
        + [(5, 0xE9, 0), (5, 0xEA, 0)] * 3
        + walk * 64
    )
    dog = []
    x = 0
    tick = 0
    for ticks, code, dx in sequence:
        for _ in range(ticks):
            x += dx
            tick += 1
            if tick % 2 == 0:
                dog += [code, min(x >> 8, 255)]
            if x >= 256 * 256:
                break
        if x >= 256 * 256:
            break
    dog += [0, 255]
    fly = bytes(r[p + 1] for p in range(0x7767, 0x7783, 7))
    # These are read with long indexed loads already. Keep the prepared
    # poses in the host data arena, leaving $01:F400-$01:FFFF to world data.
    address = allocate(bytes(flags) + fly + bytes(dog))
    return [
        f"cabinet_flag_poses = {address.label}",
        f"cabinet_fly_poses = {address.label} + {len(flags)}",
        f"CABINET_DOG_BYTES = {len(dog)}",
        f"cabinet_dog_poses = {address.label} + {len(flags) + len(fly)}",
    ]


