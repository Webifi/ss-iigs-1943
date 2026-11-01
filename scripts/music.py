"""Compile the original-US score to resident note events. No recorded-song assets.

This is a build-time port of bm05.4k $01D6-$04F4.
The six FM parts retain their independent loops, including unequal periods.
Sound-effect SSG programs have a separate decoder. ROMs remain read only.
"""

from dataclasses import dataclass, field


@dataclass
class Part:
    rom: bytes
    channel: int
    pc: int
    instrument: int
    gate: int
    tempo: int
    active: int = 255
    wait: int = 0
    release: int = 0
    pitch_base: int = 0
    repeat_pc: int = 0
    repeat_count: int = 0
    tie: int = 0
    fast: int = 0
    fnum: int = 0
    unknown15: int = 0
    token: int = 0
    events: list = field(default_factory=list)

    def get(self):
        assert 0 <= self.pc < 0x8000, hex(self.pc)
        self.token = self.rom[self.pc]
        self.pc += 1
        return self.token

    def state(self):
        return (
            self.pc,
            self.instrument,
            self.gate,
            self.tempo,
            self.active,
            self.wait,
            self.release,
            self.pitch_base,
            self.repeat_pc,
            self.repeat_count,
            self.tie,
            self.fast,
            self.fnum,
            self.unknown15,
        )

    def step(self, tick):
        self.wait = (self.wait - 1) & 65535
        if self.wait not in (0, 65535):
            if not self.tie and self.release:
                self.release = (self.release - 1) & 65535
                if self.release == 0:
                    self.events.append((tick, "off", self.channel))
            return
        self.fast = 0
        for _ in range(1024):
            token = self.get()
            note = token & 31
            kind = token >> 5
            dotted = False
            if note == 31:
                if kind == 0:
                    self.pitch_base = 0x4F5 + 2 * self.get()
                elif kind == 3:
                    lo = self.get()
                    self.pc = lo | (self.get() << 8)
                elif kind == 6:
                    token = self.get()
                    note = token & 31
                    kind = token >> 5
                    dotted = True
                else:
                    self.active = 0
                    return
                if not dotted:
                    continue
            elif note and kind == 0:
                self.instrument = token
                self.gate = self.get()
                self.events.append((tick, "patch", self.instrument))
                continue
            elif note and kind == 1:
                if token == 0x30:
                    self.fast = 1
                else:
                    self.tie = (token + 1) & 31
                continue
            if note:
                if not dotted and self.tie:
                    self.tie -= 1
                at = self.pitch_base + 2 * note
                self.fnum = int.from_bytes(self.rom[at : at + 2], "big")
                self.events.append((tick, "on", self.fnum, self.instrument, self.tie))
                if dotted:
                    self.active |= 64
            else:
                self.fnum = 0
            self.wait = ((0, 0, 3, 6, 12, 24, 48, 96) if dotted else (0, 0, 2, 4, 8, 16, 32, 64))[
                kind
            ] * self.tempo
            self.wait &= 65535
            self.release = (self.wait * (max(1, self.gate & 15) + 1) // 16) & 65535
            return
        raise ValueError("Unbounded control-only score loop")


def song(rom, command, max_ticks=200000, phase=0):
    entry = int.from_bytes(rom[0x9F + 2 * command : 0xA1 + 2 * command], "little")
    assert (
        rom[entry] == 0xCD
        and rom[entry + 3] == 0x21
        and rom[entry + 6 : entry + 9] == b"\xc3\xd6\x01"
    )
    priority = {0x1A7: 0, 0x1B0: 1, 0x1B9: 2, 0x1C2: 3}[
        int.from_bytes(rom[entry + 1 : entry + 3], "little")
    ]
    header = int.from_bytes(rom[entry + 4 : entry + 6], "little")
    tempo = rom[header]
    parts = []
    for ch in range(6):
        at = header + 1 + ch * 4
        p = Part(
            rom, ch, int.from_bytes(rom[at : at + 2], "little"), rom[at + 2], rom[at + 3], tempo
        )
        seen = {}
        loop = None
        for tick in range(max_ticks):
            state = p.state() + ((tick + phase) & 1,)
            if state in seen:
                loop = dict(start_tick=seen[state], end_tick=tick)
                break
            seen[state] = tick
            # $02EE: fast notes make a second $02FF call on odd sound IRQs.
            if p.fast and (tick + phase) & 1:
                p.step(tick)
            p.step(tick)
            if not p.active:
                break
        else:
            raise ValueError((command, ch, "no independent part loop"))
        parts.append(
            dict(
                channel=ch,
                initial_instrument=rom[at + 2],
                initial_gate=rom[at + 3],
                events=p.events,
                loop=loop,
                end_tick=tick,
                source_address=at,
            )
        )
    return dict(
        command=command,
        priority=priority,
        source_entry=entry,
        header=header,
        tempo=tempo,
        parts=parts,
    )
