"""YM2203 register logs of the sound commands, from the sound program
(scripts/sound_driver.py): the input of the sound renderers.

The commands run in turn: each song after the stop command, then each effect
after the stop command. Times follow the arcade video timing: four sound
interrupts a frame, at lines 32, 96, 160 and 224 of 262 lines of 64 us.

The files have the record formats that the renderers read:
  ym.bin     '<dBIBBB' time, command, tick, chip, register, value. An SSG
             register other than 13 is written to the log only when its
             value changes.
  ticks.bin  '<BIBd' command, tick, tick counter, time at the interrupt end.
  notes.bin  '<BIBBHB' command, tick, channel, kind (1 note, 2 key off),
             frequency, patch.
"""

import struct

from music import song
from sound_driver import Driver

LINE = 384 / 6_000_000
FRAME_LINES = 262
IRQ_LINES = (32, 96, 160, 224)
WRITE = 2e-6  # time between two register writes of one interrupt
# Interrupts of the stop command before the first scheduled command. The
# tick counter then reads 116: the slides of the SSG effects run when its two
# low bits are zero, so this count sets their phase.
LEAD = 371
ACTIVE = range(0xC500 - 0xC000, 0xC6A0 - 0xC000, 0x20)  # the six SSG effect blocks


def interrupt_times():
    frame = 0
    while True:
        for line in IRQ_LINES:
            yield (frame * FRAME_LINES + line) * LINE
        frame += 1


def song_schedule(rom):
    """Each song for its longest part and 32 ticks, after 8 ticks of stop."""
    schedule = []
    for command in range(0x20, 0x33):
        end = max(part["end_tick"] for part in song(rom, command)["parts"])
        schedule += [(0, 8, False), (command, end + 32, False)]
    return schedule


def effect_schedule():
    """Each effect until 120 ticks after its last SSG block stops."""
    return [entry for command in [*range(1, 31), 0x3A] for entry in ((0, 16, False), (command, 4800, True))]


def run(rom, schedule):
    """The log records of SCHEDULE: (writes, ticks, notes)."""
    driver = Driver(rom)
    times = interrupt_times()
    writes, ticks, notes = [], [], []
    last = [{}, {}]

    def log(time, command, tick):
        for i, (chip, register, value) in enumerate(driver.writes):
            if register >= 0x20 or register == 13 or last[chip].get(register) != value:
                writes.append((time + i * WRITE, command, tick, chip, register, value))
                last[chip][register] = value

    log(0.0, 0, 0)
    time = next(times)
    for _ in range(LEAD):
        driver.interrupt(0)
        log(time, 0, 0)
        time = next(times)
    for command, stop, effect in schedule:
        tick = 0
        ended = None
        while tick <= stop:
            driver.interrupt(command)
            log(time, command, tick)
            notes += [(command, tick, channel, kind, frequency, patch) for kind, channel, frequency, patch in driver.notes]
            ticks.append((command, tick, driver.ram[0], time + len(driver.writes) * WRITE))
            if effect:
                active = any(driver.ram[at] for at in ACTIVE)
                if tick > 2 and not active:
                    ended = ended or tick
                if ended and tick >= ended + 120:
                    stop = tick - 1
            tick += 1
            time = next(times)
    return writes, ticks, notes


def write(folder, records):
    """Write the three log files of RECORDS into FOLDER."""
    writes, ticks, notes = records
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "ym.bin").write_bytes(b"".join(struct.pack("<dBIBBB", *r) for r in writes))
    (folder / "ticks.bin").write_bytes(b"".join(struct.pack("<BIBd", *r) for r in ticks))
    (folder / "notes.bin").write_bytes(b"".join(struct.pack("<BIBBHB", *r) for r in notes))
