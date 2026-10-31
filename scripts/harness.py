"""The 65816 firmware-command builder of the game."""

from toolchain import cc65
import hashlib, json, subprocess, zipfile
from pathlib import Path
from machine_gate import check

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT


class Address:
    """A host address: the label that the host sources use, and the value
    that the host layout gives it. It has no number operations: host data
    refers to other host data by label."""

    def __init__(self, value, label):
        self.value = value
        self.label = label

    def __add__(self, offset):
        assert isinstance(offset, int) and not isinstance(offset, bool), offset
        label = f"{self.label}+{offset}" if offset >= 0 else f"{self.label}-{-offset}"
        return Address(self.value + offset, label)

    __radd__ = __add__

    def __sub__(self, offset):
        return self + -offset

    def __repr__(self):
        return f"Address({self.label})"


class HostData:
    """Host data that holds addresses of other host data. bytes() gives the
    payload bytes; lines() gives the ca65 source with labels."""

    SIZES = dict(byte=1, word=2, faraddr=3, dword=4)

    def __init__(self):
        self.parts = []  # (directive, values) or ("data", bytes)

    def _add(self, directive, values):
        self.parts.append((directive, values))
        return self

    def byte(self, *values):
        return self._add("byte", values)

    def word(self, *values):
        return self._add("word", values)

    def faraddr(self, *values):
        return self._add("faraddr", values)

    def dword(self, *values):
        return self._add("dword", values)

    def data(self, raw):
        return self._add("data", bytes(raw))

    def __len__(self):
        return sum(len(v) if d == "data" else self.SIZES[d] * len(v) for d, v in self.parts)

    def __bytes__(self):
        out = bytearray()
        for directive, values in self.parts:
            if directive == "data":
                out += values
            else:
                for value in values:
                    value = value.value if isinstance(value, Address) else value
                    out += value.to_bytes(self.SIZES[directive], "little")
        return bytes(out)

    def lines(self):
        out = []
        for directive, values in self.parts:
            if directive == "data":
                values = tuple(values)
                directive = "byte"
            items = [v.label if isinstance(v, Address) else f"${v:x}" for v in values]
            out += [f"  .{directive} " + ",".join(items[i : i + 16]) for i in range(0, len(items), 16)]
        return out


class Host:
    def __init__(self, out):
        self.out = out
        out.mkdir(parents=True, exist_ok=True)
        self.ops = ["run_fixture:"]
        self.blob = bytearray()
        self.labels = []  # (label, address) of the host data
        self.data_sources = {}  # label -> HostData: data that holds addresses
        self.contents = {}  # label -> the bytes of the host data

    def label(self, address, name=None, data=b""):
        """ADDRESS of host DATA as an Address with label NAME (or a new one)."""
        name = name or f"host_data_{len(self.labels)}"
        assert all(name != n for n, _ in self.labels), name
        self.labels.append((name, address))
        self.contents[name] = data
        return Address(address, name)

    def emit(self, s):
        self.ops.append(s)

    def cmd(self, n, params=(), done=False):
        self.emit(f"  lda #${n:02x}\n  sta $e0c0b0")
        if params:
            self.emit("  jsr on")
            for v in params:
                self.emit(f"  lda #${v:02x}\n  sta $e0c0b1")
            self.emit("  jsr off")

    def _late(self, address, data):
        """Keep the place of Late bytes (card_link) for save."""
        from card_link import Late

        if isinstance(data, Late):
            self.__dict__.setdefault("late_blobs", []).append((address, data))
            return bytes(len(data))
        return data

    def address(self, name):
        """The Address of the host data with label NAME."""
        return next(Address(a, n) for n, a in self.labels if n == name)

    def _data(self, place, data, name):
        """Place HostData DATA with PLACE(bytes, name); keep its source."""
        address = place(bytes(data), name)
        self.data_sources[address.label] = data
        return address

    def blob_at(self, data, name=None):
        if isinstance(data, HostData):
            return self._data(self.blob_at, data, name)
        addr = 0x020000 + len(self.blob)
        # The host completion/error flags and readback live in bank 5. Leave their
        # entire $50000-$51FFF range out of asset storage, including crossing chunks.
        if addr < 0x052000 and addr + len(data) > 0x050000:
            self.blob.extend(bytes(0x052000 - addr))
            addr = 0x052000
        self.blob.extend(self._late(addr, data))
        assert len(self.blob) <= 0x300000
        assert addr + len(data) <= 0x050000 or addr >= 0x052000
        return self.label(addr, name, data)

    def production_world_blob_at(self, data, name=None):
        if isinstance(data, HostData):
            return self._data(self.production_world_blob_at, data, name)
        # Continuous game's readback fixtures are not linked. Keep live status,
        # profiling, DOC markers and transfer-stack scratch reserved. This allocator
        # is only for immutable world packets read by the main CPU, never DMA or IRQ.
        if not hasattr(self, "production_low_world"):
            self.production_low_world = bytearray()
            self.production_low_allocations = []
        if len(self.production_low_world) + len(data) <= 0x2000:
            start = 0x019000 + len(self.production_low_world)
            self.production_low_world.extend(data)
            self.production_low_allocations.append(
                dict(address=start, bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
            )
            return self.label(start, name, data)
        for hole in self.production_b_holes:
            start, end = hole
            if len(data) <= end - start:
                self.production_b_world[start : start + len(data)] = data
                hole[0] += len(data)
                self.production_b_allocations.append(
                    dict(
                        address=0x01B000 + start,
                        bytes=len(data),
                        sha256=hashlib.sha256(data).hexdigest(),
                    )
                )
                return self.label(0x01B000 + start, name, data)
        if len(self.blob) >= 0x32000:
            if not hasattr(self, "production_world_holes"):
                self.production_world_holes = [[0x050000, 0x050300], [0x050600, 0x052000]]
                self.production_world_allocations = []
            for hole in self.production_world_holes:
                start, end = hole
                if len(data) <= end - start:
                    assert not any(self.blob[start - 0x20000 : start - 0x20000 + len(data)]), (
                        "world reuse overlaps existing payload"
                    )
                    self.blob[start - 0x20000 : start - 0x20000 + len(data)] = data
                    hole[0] += len(data)
                    self.production_world_allocations.append(
                        dict(
                            address=start, bytes=len(data), sha256=hashlib.sha256(data).hexdigest()
                        )
                    )
                    return self.label(start, name, data)
        if not hasattr(self, "production_lc_world"):
            self.production_lc_world = bytearray()
            self.production_lc_allocations = []
        if len(self.production_lc_world) + len(data) <= 0x0C00:
            start = 0x01F400 + len(self.production_lc_world)
            self.production_lc_world.extend(data)
            self.production_lc_allocations.append(
                dict(address=start, bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
            )
            return self.label(start, name, data)
        if not hasattr(self, "production_bc_world"):
            self.production_bc_world = bytearray()
            self.production_bc_allocations = []
        if len(self.production_bc_world) + len(data) <= 0x0300:
            start = 0x00BC00 + len(self.production_bc_world)
            self.production_bc_world.extend(data)
            self.production_bc_allocations.append(
                dict(address=start, bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
            )
            return self.label(start, name, data)
        if not hasattr(self, "production_a_world"):
            self.production_a_world = bytearray()
            self.production_a_allocations = []
        if len(self.production_a_world) + len(data) <= 0x0C00:
            start = 0x00A000 + len(self.production_a_world)
            self.production_a_world.extend(data)
            self.production_a_allocations.append(
                dict(address=start, bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
            )
            return self.label(start, name, data)
        if not hasattr(self, "production_c_world"):
            self.production_c_world = bytearray()
            self.production_c_allocations = []
        if len(self.production_c_world) + len(data) <= 0x1000:
            start = 0x00C000 + len(self.production_c_world)
            self.production_c_world.extend(data)
            self.production_c_allocations.append(
                dict(address=start, bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
            )
            return self.label(start, name, data)
        if not hasattr(self, "production_d_world"):
            self.production_d_world = bytearray()
            self.production_d_allocations = []
        if len(self.production_d_world) + len(data) <= 0x2B00:
            start = 0x00D000 + len(self.production_d_world)
            self.production_d_world.extend(data)
            self.production_d_allocations.append(
                dict(address=start, bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
            )
            return self.label(start, name, data)
        return self.blob_at(data, name)

    def blob_at_input_padding(self, data, alignment=1, name=None):
        # Explicit opt-in: callers must not assume blob_at's normal append order.
        assert alignment > 0 and alignment & (alignment - 1) == 0
        cursor, end = self.input_padding_hole
        start = (cursor + alignment - 1) & -alignment
        if start + len(data) > end:
            raise ValueError(("input alignment hole too small", hex(cursor), hex(end), len(data)))
        offset = start - 0x20000
        assert not any(self.blob[offset : offset + len(data)]), "input-alignment overlap"
        self.blob[offset : offset + len(data)] = data
        self.input_padding_hole[0] = start + len(data)
        return self.label(start, name, data)

    def blob_at_input(self, size, name=None):
        """SIZE bytes for the input code: 256-byte aligned, inside one bank.
        The alignment gap before it becomes the input padding hole."""
        address = 0x20000 + len(self.blob)
        aligned = (address + 255) & ~255
        if (aligned & 65535) + size > 65536:
            aligned = (aligned + 65535) & ~65535
        if aligned != address:
            assert aligned <= 0x050000 or address >= 0x052000, "input alignment crosses the status area"
            self.blob.extend(bytes(aligned - address))
        # Empty when the payload is already aligned; blob_at_padding_or_bank
        # then takes its bank fallback.
        self.input_padding_hole = [address, aligned]
        assert aligned + size <= 0x100000, hex(aligned + size)
        return self.blob_at(bytes(size), name)

    def reserve_top(self, address, size, name=None):
        """SIZE bytes at ADDRESS, the end of the payload; the payload before it
        is padded."""
        here = 0x20000 + len(self.blob)
        assert here <= address, (hex(here), "the payload reaches", hex(address))
        self.blob.extend(bytes(address - here))
        return self.blob_at(bytes(size), name)

    def blob_at_bank(self, data, name=None):
        """DATA in the payload, inside one 64 KB bank."""
        address = 0x20000 + len(self.blob)
        if (address & 0xFFFF) + len(data) > 0x10000:
            self.blob.extend(bytes(0x10000 - (address & 0xFFFF)))
        return self.blob_at(data, name)

    def blob_at_padding_or_bank(self, data, name=None):
        """DATA in the input alignment hole when it fits, else in the payload
        inside one 64 KB bank."""
        try:
            return self.blob_at_input_padding(data, name=name)
        except ValueError:
            return self.blob_at_bank(data, name)

    def blob_at_status_gap(self, data, name=None):
        # Production-only opt-in; $0503FE and $050440-$05047F remain markers.
        assert len(self.blob) >= 0x32000
        if not hasattr(self, "production_status_gaps"):
            self.production_status_gaps = [[0x050330, 0x0503FE], [0x050480, 0x050500]]
        for hole in self.production_status_gaps:
            start, end = hole
            if len(data) <= end - start:
                data = self._late(start, data)
                offset = start - 0x20000
                assert not any(self.blob[offset : offset + len(data)]), "status-gap overlap"
                self.blob[offset : offset + len(data)] = data
                hole[0] += len(data)
                return self.label(start, name, data)
        raise ValueError("production status gaps are full")

    def slow_blob_at(self, data, name=None):
        if isinstance(data, HostData):
            return self._data(self.slow_blob_at, data, name)
        # Card-only display leaves these two IIgs video ranges unused. Keep text,
        # vectors and I/O out. Each event table stays wholly within one bank.
        if not hasattr(self, "slow_blobs"):
            self.slow_blobs = [bytearray(), bytearray()]
        for bank, blob in zip((0xE0, 0xE1), self.slow_blobs):
            if len(blob) + len(data) <= 0xA000:
                address = (bank << 16) + 0x2000 + len(blob)
                blob.extend(data)
                return self.label(address, name, data)
        raise ValueError("IIgs video-bank data exceeds 81920 bytes")

    def upload(self, dst, data):
        """Load DATA at load address DST. Bytes become a section at that place
        of the memory map (card_link.load); card_link.Late bytes become a
        load record."""
        from card_link import Late, load

        if not isinstance(data, Late):
            load(dst, data)
            return
        self.record(dst, data)

    def record(self, dst, data):
        """One card load record: DST and DATA, staged when DST is in an SRAM
        range that the firmware owns until entry."""
        from card_link import Late

        for start, block in getattr(self, "deferred_card_sram", {}).items():
            lo = max(dst, start)
            hi = min(dst + len(data), start + len(block))
            if lo < hi:
                if dst < lo:
                    self.record(dst, data[: lo - dst])
                part = data[lo - dst : hi - dst]
                block.write(lo - start, part if isinstance(part, Late) else bytes(part))
                if hi < dst + len(data):
                    self.record(hi, data[hi - dst :])
                return
        n = len(data)
        assert n > 0
        for offset in range(0, n, 16384):
            part = data[offset : offset + 16384]
            self.card_startup.append((dst + offset, part if isinstance(part, Late) else bytes(part)))

    def check_card_loads(self, loads):
        """Every byte of LOADS, (load address, bytes), is in a load record or
        in a staged range."""
        have = {}
        for start, block in getattr(self, "deferred_card_sram", {}).items():
            for offset, data in block.writes:
                for i, value in enumerate(bytes(data)):
                    have[start + offset + i] = value
        for address, data in self.card_startup:
            for i, value in enumerate(bytes(data)):
                have[address + i] = value
        for address, data in loads:
            bad = [address + i for i, value in enumerate(bytes(data)) if have.get(address + i) != value]
            if bad:
                raise RuntimeError(f"{len(bad)} card bytes do not load, first at {bad[0]:06X}")

    def run(self, entry, cbr=0x84, cbar=0xC2, bbr=0x10, wait=True):
        self.cmd(9, [cbr, cbar, bbr, *entry.to_bytes(2, "little")], wait)

    def palette(self, data):
        (self.out / "palette.bin").write_bytes(data)
        self.cmd(6, [0, 0, 0])
        self.blob_at(data, "card_palette")
        self.emit("  jsr on")
        self.emit(
            "  ldx #0\npalette:\n  lda f:card_palette,x\n  sta f:$e0c0b1\n  inx\n  cpx #768\n  bne palette\n  jsr off"
        )

    def save(self):
        for address, data in getattr(self, "late_blobs", []):
            self.blob[address - 0x20000 : address - 0x20000 + len(data)] = bytes(data)
        if getattr(self, "production_c_world", None):
            self.ops.insert(0, "PRODUCTION_C_WORLD = 1")
        if getattr(self, "production_d_world", None):
            assert getattr(self, "production_c_world", None), "D staging requires C handoff"
            self.ops.insert(0, "PRODUCTION_D_STAGE = $001800")
            self.ops.insert(0, "PRODUCTION_D_WORLD = 1")
        self.emit("  lda #$a5\n  sta $050300\nfinished:\n  bra finished")
        self.emit('.segment "NATIVE"')
        for routine in getattr(self, "routines", []):
            self.emit(routine)
        # The loader itself occupies $A000. Move staged application data there
        # only after the loader has handed execution to this bank-zero stub.
        self.emit(""".segment "CODE"
.a8
.i8
.export production_handoff
production_handoff:
  sei
  clc
  xce
  rep #$30
  ldx #$9400
  ldy #$a000
  lda #$0bff
  mvn #$00,#$00
.ifdef PRODUCTION_C_WORLD
  sep #$20
  lda f:$e0c035
  pha
  ora #$40
  sta f:$e0c035
  rep #$30
  ldx #$0bfe
@swap_c_first:
  lda f:$008000,x
  pha
  lda f:$00c000,x
  sta f:$008000,x
  pla
  sta f:$00c000,x
  dex
  dex
  bpl @swap_c_first
  ldx #$03fe
@swap_c_last:
  lda f:$000c00,x
  pha
  lda f:$00cc00,x
  sta f:$000c00,x
  pla
  sta f:$00cc00,x
  dex
  dex
  bpl @swap_c_last
  ldx #$8000
  ldy #$9400
  lda #$0bff
  mvn #$00,#$00
  ldx #$0c00
  ldy #$ac00
  lda #$03ff
  mvn #$00,#$00
.ifdef PRODUCTION_D_WORLD
  ; Last startup data is staged in transient state, pool, packet and audio scratch.
  ldx #$8000
  ldy #$d000
  lda #$0fff
  mvn #$01,#$00
  ldx #$5000
  ldy #$e000
  lda #$0fff
  mvn #$00,#$00
  ldx #.loword(PRODUCTION_D_STAGE)
  ldy #$f000
  lda #$06ff
  mvn #.bankbyte(PRODUCTION_D_STAGE),#$00
  ldx #$8c00
  ldy #$f700
  lda #$03ff
  mvn #$00,#$00
  ; Clear the startup pool and game-state scratch before game initialization.
  ldx #$0ffe
  lda #0
@clear_d_scratch:
  sta $5000,x
  cpx #$0700
  bcs :+
  sta $1800,x
:
  dex
  dex
  bpl @clear_d_scratch
.endif
  sep #$20
  pla
  sta f:$e0c035
.endif
  sep #$30
  lda #0
  pha
  plb
  sec
  xce
  jml $006000
.a8
.i16""")
        (self.out / "operations.s").write_text("\n".join(self.ops) + "\n")
        (self.out / "host_labels.inc").write_text(
            "; Generated by scripts/harness.py: the places of the host data.\n"
            + "".join(f"{name} = ${address:06x}\n" for name, address in self.labels)
        )
        limit = getattr(self, "native_limit", 0x4000)
        ext_size = 0x8000
        extra_memory = f' EXT: start=$010000,size=${ext_size:x},file="{self.out}/gameplay.bin";'
        extra_segment = " GAMEPLAY: load=EXT,type=rw;"
        sound_start, sound_size = (0x6200, 0x1E00)
        extra_memory += (
            f' SND: start=${sound_start:06x},size=${sound_size:x},file="{self.out}/sound.bin";'
        )
        extra_segment += " SOUND: load=SND,type=rw;"
        extra_memory += f' SP: start=${self.special_code_source.value:06x},size=${self.special_code_size:x},file="{self.out}/special.bin";'
        extra_segment += " SPECIAL: load=SP,type=rw;"
        flow_size = 0x3400
        extra_memory += f' FLOW: start=$01c000,size=${flow_size:x},file="{self.out}/gameflow.bin";'
        extra_segment += " GAMEFLOW: load=FLOW,type=rw;"
        extra_memory += f' CAB: start=${self.cabinet_data_source.value:06x},size=${self.cabinet_data_size:x},file="{self.out}/cabinet-data.bin";'
        extra_segment += " CABDATA: load=CAB,type=rw;"
        extra_memory += f' INP: start=${self.input_code_source.value:06x},size=${self.input_code_size:x},file="{self.out}/input.bin";'
        extra_segment += " INPUT: load=INP,type=rw; INPUT_LATE: load=INP,type=rw,optional=yes;"
        extra_memory += f' FMEXT: start=${self.fm_extra_source.value:06x},size=${self.fm_extra_size:x},file="{self.out}/fm-extra.bin";'
        extra_segment += " SOUND_EXTRA: load=FMEXT,type=rw;"
        extra_memory += f' MIR: start=${self.menu_mirror_code_source:06x},size=$400,file="{self.out}/menu-mirror-host.bin";'
        extra_segment += " MIRROR: load=MIR,type=rw;"
        extra_memory += f' DISP: start=${self.display_code_source.value:06x},size=${self.display_code_size:x},file="{self.out}/display.bin";'
        extra_segment += " DISPLAY: load=DISP,type=rw;"
        code_size = 0x200
        (self.out / "host.cfg").write_text(
            f'MEMORY {{ RAM: start=$6000, size=${code_size:x}, file=%O; GAME: start=$2000,size=${limit:04x},file="{self.out}/native.bin";{extra_memory} }}\nSEGMENTS {{ CODE: load=RAM,type=rw; NATIVE: load=GAME,type=rw;{extra_segment} }}\n'
        )
        files = sorted(
            p
            for folder in ("scripts", "src")
            for p in (ROOT / folder).iterdir()
            if p.is_file()
            and p.suffix in (".py", ".lua", ".c", ".s", ".inc", ".cpp", ".h", ".json")
        )
        hashes = {}
        with zipfile.ZipFile(
            self.out / "sources.zip", "w", compression=zipfile.ZIP_DEFLATED
        ) as archive:
            for p in files:
                name = str(p.relative_to(ROOT))
                data = p.read_bytes()
                hashes[name] = hashlib.sha256(data).hexdigest()
                info = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(info, data)
        (self.out / "source-hashes.json").write_text(json.dumps(hashes, indent=2) + "\n")
        check("build")
        subprocess.run(
            [
                cc65("ca65"),
                "-g",
                "-I",
                str(self.out),
                "-I",
                str(ROOT / "src"),
                "-o",
                str(self.out / "host.o"),
                str(ROOT / "src/host.s"),
            ],
            check=True,
        )
        subprocess.run(
            [
                cc65("ld65"),
                "-C",
                str(self.out / "host.cfg"),
                "-Ln",
                str(self.out / "host.lbl"),
                "-o",
                str(self.out / "host.bin"),
                str(self.out / "host.o"),
            ],
            check=True,
        )
        data = (self.out / "special.bin").read_bytes()
        assert len(data) <= self.special_code_size
        start = self.special_code_source.value - 0x20000
        self.blob[start : start + len(data)] = data
        assert (self.out / "gameflow.bin").stat().st_size <= 16384, (
            "GAMEFLOW exceeds its reserved 16KB"
        )
        data = (self.out / "cabinet-data.bin").read_bytes()
        assert len(data) <= self.cabinet_data_size
        start = self.cabinet_data_source.value - 0x20000
        assert not any(self.blob[start : start + self.cabinet_data_size]), (
            "cabinet data overlaps payload"
        )
        self.blob[start : start + len(data)] = data
        data = (self.out / "input.bin").read_bytes()
        assert len(data) <= self.input_code_size
        start = self.input_code_source.value - 0x20000
        self.blob[start : start + len(data)] = data
        data = (self.out / "fm-extra.bin").read_bytes()
        assert len(data) <= self.fm_extra_size
        start = self.fm_extra_source.value - 0x20000
        self.blob[start : start + len(data)] = data
        data = (self.out / "menu-mirror-host.bin").read_bytes()
        assert len(data) <= 0x400
        start = self.menu_mirror_code_source - 0x20000
        assert not any(self.blob[start : start + 0x400]), "mirror code overlaps payload"
        self.blob[start : start + len(data)] = data
        data = (self.out / "display.bin").read_bytes()
        assert len(data) <= self.display_code_size
        start = self.display_code_source.value - 0x20000
        assert not any(self.blob[start : start + self.display_code_size]), (
            "display code overlaps payload"
        )
        self.blob[start : start + len(data)] = data
        (self.out / "payload.bin").write_bytes(self.blob)
        (self.out / "input-padding.json").write_text(
            json.dumps(
                dict(
                    start=self.input_padding_hole[0],
                    end=self.input_padding_hole[1],
                    bytes=self.input_padding_hole[1] - self.input_padding_hole[0],
                ),
                indent=2,
            )
            + "\n"
        )
        low = bytes(self.production_low_world)
        assert 0 < len(low) <= 0x2000
        for item in self.production_low_allocations:
            start = item["address"] - 0x19000
            assert hashlib.sha256(low[start : start + item["bytes"]]).hexdigest() == item["sha256"]
        (self.out / "production-low-world.json").write_text(
            json.dumps(self.production_low_allocations, indent=2) + "\n"
        )
        for item in self.production_b_allocations:
            start = item["address"] - 0x01B000
            assert (
                hashlib.sha256(self.production_b_world[start : start + item["bytes"]]).hexdigest()
                == item["sha256"]
            )
        (self.out / "production-b-world.json").write_text(
            json.dumps(self.production_b_allocations, indent=2) + "\n"
        )
        (self.out / "low-world.bin").write_bytes(low.ljust(0x2000, b"\0") + self.production_b_world)
        code = (self.out / "host.bin").read_bytes()
        sound = (self.out / "sound.bin").read_bytes()
        assert len(code) <= 0x200 and len(sound) <= 0x1E00
        (self.out / "host-boot.bin").write_bytes(code.ljust(0x200, b"\0") + sound)
        low = bytes(self.production_lc_world)
        assert 0 < len(low) <= 0x0C00
        for item in self.production_lc_allocations:
            start = item["address"] - 0x01F400
            assert hashlib.sha256(low[start : start + item["bytes"]]).hexdigest() == item["sha256"]
        (self.out / "production-lc-world.json").write_text(
            json.dumps(self.production_lc_allocations, indent=2) + "\n"
        )
        (self.out / "lc-world.bin").write_bytes(low)
        bc = bytes(getattr(self, "production_bc_world", b""))
        for item in getattr(self, "production_bc_allocations", []):
            start = item["address"] - 0x00BC00
            assert hashlib.sha256(bc[start : start + item["bytes"]]).hexdigest() == item["sha256"]
        (self.out / "production-bc-world.json").write_text(
            json.dumps(getattr(self, "production_bc_allocations", []), indent=2) + "\n"
        )
        (self.out / "boot-lc-world.bin").write_bytes(low.ljust(0x0C00, b"\0") + bc)
        early = bytes(getattr(self, "production_a_world", b""))
        for item in getattr(self, "production_a_allocations", []):
            start = item["address"] - 0x00A000
            assert (
                hashlib.sha256(early[start : start + item["bytes"]]).hexdigest() == item["sha256"]
            )
        (self.out / "production-a-world.json").write_text(
            json.dumps(getattr(self, "production_a_allocations", []), indent=2) + "\n"
        )
        (self.out / "boot-a-world.bin").write_bytes(early.ljust(0x0C00, b"\0"))
        cdata = bytes(getattr(self, "production_c_world", b""))
        for item in getattr(self, "production_c_allocations", []):
            start = item["address"] - 0x00C000
            assert (
                hashlib.sha256(cdata[start : start + item["bytes"]]).hexdigest() == item["sha256"]
            )
        (self.out / "production-c-world.json").write_text(
            json.dumps(getattr(self, "production_c_allocations", []), indent=2) + "\n"
        )
        if cdata:
            (self.out / "boot-c-world.bin").write_bytes(cdata.ljust(0x1000, b"\0"))
        ddata = bytes(getattr(self, "production_d_world", b""))
        for item in getattr(self, "production_d_allocations", []):
            start = item["address"] - 0x00D000
            assert (
                hashlib.sha256(ddata[start : start + item["bytes"]]).hexdigest() == item["sha256"]
            )
        (self.out / "production-d-world.json").write_text(
            json.dumps(getattr(self, "production_d_allocations", []), indent=2) + "\n"
        )
        if ddata:
            (self.out / "boot-d-world.bin").write_bytes(ddata.ljust(0x2B00, b"\0"))
        for item in self.production_world_allocations:
            start = item["address"] - 0x20000
            assert (
                hashlib.sha256(self.blob[start : start + item["bytes"]]).hexdigest()
                == item["sha256"]
            )
        (self.out / "production-world-reuse.json").write_text(
            json.dumps(self.production_world_allocations, indent=2) + "\n"
        )
        for bank, blob in zip((0xE0, 0xE1), getattr(self, "slow_blobs", [])):
            (self.out / f"video-{bank:02x}.bin").write_bytes(blob)
        (self.out / "card-startup.bin").write_bytes(
            b"".join(
                a.to_bytes(3, "little") + len(d).to_bytes(3, "little") + bytes(d)
                for a, d in self.card_startup
            )
            + bytes(6)
        )

