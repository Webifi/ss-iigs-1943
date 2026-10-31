"""The sound program of the 1943 sound board, ported to Python for the build.

The sound CPU runs the program of the sound ROM ($0000-$0C5B) only from its
interrupt, four times a frame: it counts a tick, reads the command latch,
plays the FM parts of the music, plays the SSG effects and writes the SSG
registers of both YM2203 chips. This module ports that program routine by
routine (the address of each routine is in its docstring). It keeps the
program's RAM ($C000-$C7FF) and gives the YM2203 register writes of each
interrupt. It reads only the ROM data; it runs no arcade instructions.
"""

RAM = 0xC000
COMMANDS = 0x009F  # 64 words: the start routine of each command
PATCHES = 0x0C5C  # 32 bytes for each FM patch
LENGTHS = 0x044C  # note length units, by the top three bits of a note
DOTTED = 0x0454
PITCHES = 0x04F5  # pitch tables
SILENT = 0x0C50  # SSG register values when no effect plays
MUSIC = (0xC400, 0xC300, 0xC200, 0xC100)  # FM blocks, highest priority first
EFFECTS = ((0xC580, 0xC560, 0xC540, 0xC520, 0xC500), (0xC680, 0xC660, 0xC640, 0xC620, 0xC600))
SHADOW = (0xC750, 0xC760)  # SSG register images of chip 0 and chip 1
CACHE = 0xC010  # the patch of each FM channel


def _signed(value):
    return value - 256 if value & 0x80 else value


class Driver:
    def __init__(self, rom):
        self.rom = bytes(rom[:0x8000])
        self.ram = bytearray(0x800)
        self.writes = []  # (chip, register, value) of the current interrupt
        self.notes = []  # (kind, channel, frequency, patch): 1 note, 2 key off
        self.reset()

    def read(self, address):
        if address < 0x8000:
            return self.rom[address]
        return self.ram[address - RAM]

    def field(self, ix, offset):
        return self.ram[ix + offset - RAM]

    def set(self, ix, offset, value):
        self.ram[ix + offset - RAM] = value & 0xFF

    def pair(self, ix, high, low):
        return self.field(ix, high) << 8 | self.field(ix, low)

    def set_pair(self, ix, high, low, value):
        self.set(ix, high, value >> 8)
        self.set(ix, low, value)

    def write(self, chip, register, value):
        """$007F: address write, then data write."""
        self.writes.append((chip, register, value & 0xFF))

    @staticmethod
    def chip(ix_channel):
        """Chip and channel of FM part channel 0-5."""
        return (0, ix_channel) if ix_channel < 3 else (1, ix_channel - 3)

    def reset(self):
        """$004B: clear the RAM and select the prescaler of both chips. Only
        the register address selects it; the data byte has no effect."""
        self.ram[:] = bytes(0x800)
        for chip in (0, 1):
            self.write(chip, 0x2D, 0)
            self.write(chip, 0x2E, 0)

    def interrupt(self, latch):
        """$0038: one sound interrupt. Returns its register writes."""
        self.writes = []
        self.notes = []
        self.ram[0] = (self.ram[0] + 1) & 0xFF
        self.command(latch)
        self.music()
        self.effects()
        self.ssg_output()
        return self.writes

    # Commands.

    def command(self, latch):
        """$008D: start a command when the latch changes."""
        if latch == self.ram[1]:
            return
        self.ram[1] = latch
        if latch == 0xFF:
            return
        at = COMMANDS + 2 * (latch & 0x3F)
        self.start(self.read(at) | self.read(at + 1) << 8)

    def start(self, entry):
        rom = self.rom
        if entry == 0x011F:
            self.stop_effects()
            self.stop_music()
        elif entry == 0x0125:
            self.stop_effects()
        elif entry == 0x0140:
            self.stop_music()
        elif rom[entry : entry + 2] == b"\xdd\x21" and rom[entry + 4] == 0x21 and rom[entry + 7 : entry + 10] == b"\xc3\x05\x0a":
            ix = rom[entry + 2] | rom[entry + 3] << 8
            self.start_effect(ix, rom[entry + 5] | rom[entry + 6] << 8)
        elif rom[entry] == 0xCD and rom[entry + 3] == 0x21 and rom[entry + 6 : entry + 9] == b"\xc3\xd6\x01":
            clear = rom[entry + 1] | rom[entry + 2] << 8
            block = {0x01A7: 0xC100, 0x01B0: 0xC200, 0x01B9: 0xC300, 0x01C2: 0xC400}[clear]
            for channel in range(6):
                self.set(block + 0x20 * channel, 0, 0)
            self.start_song(block, rom[entry + 4] | rom[entry + 5] << 8)
        else:
            raise ValueError(f"sound command routine ${entry:04X} is not ported")

    def stop_effects(self):
        """$0125"""
        for chain in EFFECTS:
            for ix in chain:
                self.set(ix, 0, 0)

    def stop_music(self):
        """$0140"""
        for block in reversed(MUSIC):
            for channel in range(6):
                self.set(block + 0x20 * channel, 0, 0)
        self.silence()

    def silence(self):
        """$0166: every FM operator to the lowest level, every key off, and
        no patch loaded ($0194)."""
        for chip in (0, 1):
            for register in range(0x40, 0x4E):
                self.write(chip, register, 0x7F)
            for channel in range(3):
                self.write(chip, 0x28, channel)
        for channel in range(6):
            self.ram[CACHE - RAM + channel] = 0xFF

    def start_song(self, ix, header):
        """$01D6: the six parts of a song from its header."""
        tempo = self.read(header)
        at = header + 1
        for channel in range(6):
            self.set(ix, 0, self.field(ix, 0) - 1)
            self.set(ix, 9, channel)
            self.set(ix, 13, self.read(at))
            self.set(ix, 12, self.read(at + 1))
            self.set(ix, 17, self.read(at + 2))
            self.set(ix, 8, self.read(at + 3))
            self.set(ix, 23, tempo)
            for offset in (3, 4, 30, 31):
                self.set(ix, offset, 0)
            at += 4
            ix += 0x20
        self.silence()
        self.ram[0x26] = 1

    def start_effect(self, ix, data):
        """$0A05"""
        self.set_pair(ix, 21, 22, data)
        self.set_pair(ix, 23, 24, data)
        self.set(ix, 0, self.field(ix, 0) - 1)
        self.set_pair(ix, 19, 20, 0)
        self.set(ix, 25, 0)
        self.set(ix, 8, 0xFF)

    # FM music.

    def music(self):
        """$021A: the parts of the highest active block."""
        block = next((b for b in MUSIC if self.field(b, 0)), None)
        if block is None:
            return
        self.ram[0x20], self.ram[0x21] = block & 0xFF, block >> 8
        if block != self.ram[0x23] | self.ram[0x24] << 8:
            self.silence()
            self.ram[0x23], self.ram[0x24] = block & 0xFF, block >> 8
            return
        if self.ram[0x26]:
            self.ram[0x26] = 0
            return
        for channel in range(6):
            ix = block + 0x20 * channel
            iy = CACHE + channel
            if self.read(iy) != self.field(ix, 17):
                self.load_patch(ix, iy)
            if self.field(ix, 0):
                self.part(ix, iy)

    def load_patch(self, ix, iy):
        """$02A1: the 26 bytes of the part's patch."""
        chip, channel = self.chip(self.field(ix, 9))
        at = (PATCHES + 32 * self.field(ix, 17)) & 0xFFFF
        register = 0x30 + channel
        for i in range(24):
            self.write(chip, register, self.read(at + i))
            register += 4
        self.write(chip, register + 0x20, self.read(at + 24))
        self.set(ix, 6, channel + self.read(at + 25))
        self.ram[iy - RAM] = self.field(ix, 17)

    def part(self, ix, iy):
        """$02EE: a part steps twice on odd ticks after a fast mark."""
        if self.field(ix, 31) & 1 and self.ram[0] & 1:
            self.step(ix, iy)
        self.step(ix, iy)

    def step(self, ix, iy):
        """$02FF"""
        wait = self.pair(ix, 3, 4)
        if wait in (0, 1):
            self.next_event(ix, iy)
            return
        self.set_pair(ix, 3, 4, wait - 1)
        if self.field(ix, 30):
            return
        release = self.pair(ix, 10, 11)
        if not release:
            return
        self.set_pair(ix, 10, 11, release - 1)
        if release != 1:
            return
        chip, _ = self.chip(self.field(ix, 9))
        self.notes.append(self.note(ix, 2))
        self.write(chip, 0x28, self.field(ix, 6) & 3)

    def fetch(self, ix):
        """$04E3: the next score byte of the part."""
        at = self.pair(ix, 12, 13)
        value = self.read(at)
        self.set(ix, 22, value)
        self.set_pair(ix, 12, 13, at + 1)
        return value

    def next_event(self, ix, iy):
        """$0347: score bytes up to the next note or rest."""
        self.set(ix, 31, 0)
        while True:
            token = self.fetch(ix)
            pitch = token & 0x1F
            if pitch == 0:
                self.set_pair(ix, 1, 2, 0)
                self.length(ix, LENGTHS)
                return
            if pitch == 0x1F:
                kind = token >> 5
                if kind == 6:
                    self.dotted(ix)
                    return
                if kind == 7:
                    self.set(ix, 0, 0)
                    return
                self.control(ix, kind)
                continue
            if token < 0x20:
                self.set(ix, 17, token)
                self.set(ix, 8, self.fetch(ix))
                self.load_patch(ix, iy)
                continue
            if token < 0x40:
                if token == 0x30:
                    self.set(ix, 31, 1)
                else:
                    self.set(ix, 30, (token + 1) & 0x1F)
                continue
            if self.field(ix, 30):
                self.set(ix, 30, self.field(ix, 30) - 1)
            self.note_on(ix)
            self.length(ix, LENGTHS)
            return

    def dotted(self, ix):
        """$039B: a dotted note or rest."""
        if self.fetch(ix) & 0x1F:
            self.note_on(ix)
            self.set(ix, 0, self.field(ix, 0) | 0x40)
            self.length(ix, DOTTED)
        else:
            self.set_pair(ix, 1, 2, 0)
            self.length(ix, DOTTED)
            self.set_pair(ix, 1, 2, 0)

    def control(self, ix, kind):
        """$0470: the control codes 0-5."""
        if kind == 0:
            at = PITCHES + (2 * self.fetch(ix) & 0xFF)
            self.set_pair(ix, 19, 20, at)
        elif kind == 1:
            self.set(ix, 23, self.fetch(ix))
        elif kind == 2:
            self.set(ix, 21, self.fetch(ix))
        elif kind == 3:
            low = self.fetch(ix)
            self.set_pair(ix, 12, 13, self.fetch(ix) << 8 | low)
        elif kind == 4:
            self.set_pair(ix, 14, 15, self.pair(ix, 12, 13))
            self.set(ix, 16, 0)
        else:
            limit = self.fetch(ix)
            self.set(ix, 16, self.field(ix, 16) + 1)
            if limit >= self.field(ix, 16):
                self.set_pair(ix, 12, 13, self.pair(ix, 14, 15))

    def note_on(self, ix):
        """$03BC: the frequency of the note, then key on."""
        at = self.pair(ix, 19, 20) + 2 * (self.field(ix, 22) & 0x1F)
        self.set(ix, 1, self.read(at))
        self.set(ix, 2, self.read(at + 1))
        chip, channel = self.chip(self.field(ix, 9))
        self.write(chip, 0xA4 + channel, self.field(ix, 1))
        self.write(chip, 0xA0 + channel, self.field(ix, 2))
        self.notes.append(self.note(ix, 1))
        self.write(chip, 0x28, self.field(ix, 6))

    def note(self, ix, kind):
        return (kind, self.field(ix, 9), self.pair(ix, 1, 2), self.field(ix, 17))

    def length(self, ix, table):
        """$0401: the wait of the note and the tick of its key off."""
        units = self.read(table + (self.field(ix, 22) >> 5))
        wait = self.field(ix, 23) * units
        self.set_pair(ix, 3, 4, wait)
        gate = self.field(ix, 8) & 0x0F or 1
        self.set_pair(ix, 10, 11, (wait * (gate + 1) >> 4) & 0xFFFF)

    # SSG effects.

    def effects(self):
        """$05B7: the highest active effect of each chip."""
        for chain in EFFECTS:
            ix = next((b for b in chain if self.field(b, 0)), None)
            if ix is None:
                continue
            wait = self.pair(ix, 19, 20)
            if wait == 0:
                self.effect_codes(ix)
            else:
                self.set_pair(ix, 19, 20, wait - 1)
                self.slide(ix)

    def effect_byte(self, ix):
        """$08B6: the next byte of the effect; the byte after it stays in
        field 27."""
        at = self.pair(ix, 21, 22)
        self.set(ix, 26, self.read(at))
        self.set(ix, 27, self.read(at + 1))
        self.set_pair(ix, 21, 22, at + 1)
        return self.field(ix, 26)

    def effect_codes(self, ix):
        """$06E4: effect codes up to the next wait."""
        code = self.effect_byte(ix)
        while True:
            kind = code >> 2 & 7
            if kind == 0:
                self.set(ix, 19, self.field(ix, 26))
                self.effect_byte(ix)
                self.set(ix, 20, self.field(ix, 26))
                code = None
                while self.field(ix, 27) & 0xE0:
                    value = self.effect_byte(ix)
                    if value >> 5 == 0:
                        code = value
                        break
                    self.parameter(ix, value >> 5)
                if code is not None:
                    continue
                self.set_pair(ix, 19, 20, self.pair(ix, 19, 20) - 1)
                return
            if kind == 1:
                self.set_pair(ix, 23, 24, self.pair(ix, 21, 22))
                self.set(ix, 25, 0)
            elif kind == 2:
                count = self.effect_byte(ix)
                self.set(ix, 25, self.field(ix, 25) + 1)
                if count != self.field(ix, 25):
                    self.set_pair(ix, 21, 22, self.pair(ix, 23, 24))
            elif kind == 3:
                self.set_pair(ix, 21, 22, self.pair(ix, 29, 30))
            elif kind == 4:
                self.set_pair(ix, 29, 30, self.pair(ix, 21, 22))
                self.set(ix, 31, 0xFF)
            else:
                self.set(ix, 0, 0)
                return
            code = self.effect_byte(ix)

    def parameter(self, ix, kind):
        """$0776: the parameter codes 1-7."""
        if kind <= 3:
            low, high, bit, slide = ((1, 2, 0, 12), (3, 4, 1, 13), (5, 6, 2, 14))[kind - 1]
            period = (self.field(ix, 26) & 0x0F) << 8 | self.effect_byte(ix)
            if period == 0:
                self.set(ix, low, 0)
                self.set(ix, high, 0)
                self.set(ix, 8, self.field(ix, 8) | 1 << bit)
            elif period != 0x0FFF:
                self.set(ix, 8, self.field(ix, 8) & ~(1 << bit))
                period = period << 4 & 0xFFFF
                self.set(ix, high, period >> 8)
                self.set(ix, low, period)
            self.set(ix, slide, self.effect_byte(ix))
        elif kind <= 6:
            level, slide = ((9, 15), (10, 16), (11, 17))[kind - 4]
            value = self.field(ix, 26) & 0x1F
            if value != 0x1F:
                self.set(ix, level, value << 4)
            self.set(ix, slide, self.effect_byte(ix))
        else:
            value = self.field(ix, 26) & 0x1F
            if value != 0x1F:
                self.set(ix, 7, value << 3)
            mixer = self.effect_byte(ix) & 0x38
            self.set(ix, 8, (self.field(ix, 8) & 0xC7) + mixer)
            self.set(ix, 18, self.effect_byte(ix))

    def slide(self, ix):
        """$0644: the periods slide every tick, the levels and the noise
        every fourth tick."""
        for delta, low, high in ((12, 1, 2), (13, 3, 4), (14, 5, 6)):
            step = self.field(ix, delta)
            if step:
                value = (self.field(ix, low) | self.field(ix, high) << 8) + _signed(step)
                self.set(ix, low, value)
                self.set(ix, high, value >> 8)
        if self.ram[0] & 3:
            return
        for delta, target in ((15, 9), (16, 10), (17, 11), (18, 7)):
            step = self.field(ix, delta)
            if step:
                self.set(ix, target, self.field(ix, target) + step)

    def ssg_output(self):
        """$0A25: SSG registers 0-10 of each chip, from its highest active
        effect. An active effect stops the lower ones that it does not keep."""
        for chip, chain in enumerate(EFFECTS):
            values = self.rom[SILENT + 1 : SILENT + 12]
            for k, ix in enumerate(chain):
                if self.field(ix, 0):
                    for lower in chain[k + 1 :]:
                        if self.field(lower, 31) != 0xFF:
                            self.set(lower, 0, 0)
                    values = self.shadow(ix, SHADOW[chip])
                    break
            for register, value in enumerate(values):
                self.write(chip, register, value)

    def shadow(self, ix, iy):
        """$0AD5: the register image of an effect."""
        values = []
        for low, high in ((1, 2), (3, 4), (5, 6)):
            period = (self.field(ix, low) | self.field(ix, high) << 8) >> 4
            values += [period & 0xFF, period >> 8]
        values.append(self.field(ix, 7) >> 3)
        values.append(self.field(ix, 8))
        values += [self.field(ix, offset) >> 4 for offset in (9, 10, 11)]
        self.ram[iy + 1 - RAM : iy + 12 - RAM] = bytes(values)
        return values
