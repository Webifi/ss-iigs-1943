"""The host data of the asset builder, as sources for the IIgs link.

The asset builder gives the host data as blobs (blob_at and the others). Each
blob goes into a segment of src/iigs.cfg with room for it, by its rule; the
room of each area comes from the label file of a link of the config alone
(build/game/areas/areas.lbl, the __NAME_START__ and __NAME_SIZE__ symbols).
save() writes the blobs as build/game/host_data.s, host_data.bin and
host_data.inc; "make iigs" links them with the 65816 program (src/game.s).

Host data can name Second Sight symbols (secondsight_NAME of
build/game/secondsight_symbols.inc) and the linked helpers of
build/secondsight/regions (src/host_jobs.inc): ld65 gives those values. A
blob whose size the Second Sight link decides goes into the LINKED area.
"""

import re

from startup_pack import pack

BANK = 0x10000  # a 65816 bank: a blob stays inside one

# The segments of each rule, in the order of use.
DATA = [f"DATA{bank:02X}" for bank in range(0x02, 0x0F)]
WORLD = ["LOW_WORLD", "B_WORLD0", "B_WORLD1", "B_WORLD2", "LC_WORLD", "BC_WORLD", "A_WORLD", "C_WORLD", "D_WORLD"]
SLOW = ["VIDEO_E0", "VIDEO_E1"]
LINKED = "LINKED"
SIZES = {"byte": 1, "word": 2, "faraddr": 3, "dword": 4}  # bytes of each HostData directive


class Address:
    """A host address: the label of host data, plus an offset. Host data
    refers to other host data by label; ld65 gives the values."""

    def __init__(self, label):
        self.label = label

    def __add__(self, offset):
        assert isinstance(offset, int) and not isinstance(offset, bool), offset
        return Address(f"{self.label}+{offset}" if offset >= 0 else f"{self.label}-{-offset}")

    __radd__ = __add__

    def __repr__(self):
        return f"Address({self.label})"


def card(label):
    """The physical SRAM address of Second Sight label LABEL (src/host_jobs.inc)."""
    return f"card_physical(secondsight_{label})"


class HostData:
    """Host data: bytes, values (numbers, Addresses or ca65 expressions) and
    Second Sight SRAM jobs."""

    def __init__(self):
        self.parts = []  # (kind, values)

    def _add(self, kind, values):
        self.parts.append((kind, values))
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

    def sram_job(self, label, data, offset=0, literal=False):
        """A job that writes DATA at Second Sight label LABEL + OFFSET, packed,
        or as one literal run with LITERAL (the host can fill it in the
        packet)."""
        packed = bytes((len(data) - 1,)) + bytes(data) if literal else pack(data)
        return self._add("job", (f"{card(label)}+{offset}", len(data), packed))

    def linked_job(self, region):
        """A job that writes the linked helper REGION (an output section of
        secondsight.ld) at its run address, packed and padded to an even
        length."""
        return self._add("linked_job", (region,))

    def linked_literal(self, label, region, at, count=3):
        """A job that writes the COUNT linked bytes at label AT of output
        section REGION to Second Sight label LABEL."""
        return self._add("linked_literal", (label, region, at, count))

    def linked_bytes(self, region):
        """The bytes of the linked output section REGION, padded to an even
        length."""
        return self._add("linked_bytes", (region,))

    def __add__(self, other):
        joined = HostData()
        joined.parts = self.parts + (other.parts if isinstance(other, HostData) else [("data", bytes(other))])
        return joined

    def size(self):
        """The bytes of the data, or None when the Second Sight link decides it."""
        total = 0
        for kind, values in self.parts:
            if kind in ("linked_job", "linked_bytes"):
                return None
            total += (
                len(values) if kind == "data"
                else 10 + len(values[2]) if kind == "job"
                else 11 + values[3] if kind == "linked_literal"
                else SIZES[kind] * len(values)
            )
        return total

    def __len__(self):
        size = self.size()
        assert size is not None, "the Second Sight link decides the size of this host data"
        return size

    def key(self):
        """A key that is equal for equal data."""
        return tuple(
            (kind, values if kind == "data" else tuple(v.label if isinstance(v, Address) else v for v in values))
            for kind, values in self.parts
        )

    def source(self, incbin):
        """The ca65 lines of the data; INCBIN(bytes) gives the line of raw bytes."""
        value = lambda v: v.label if isinstance(v, Address) else v if isinstance(v, str) else f"${v:X}"
        lines = []
        for kind, values in self.parts:
            if kind == "data":
                lines += incbin(values)
            elif kind == "job":
                address, count, packed = values
                lines.append(f"  sram_job_header {address}, {count}, {len(packed)}")
                lines += incbin(packed)
            elif kind == "linked_job":
                (region,) = values
                lines.append(
                    f'  sram_packed_job card_physical(secondsight_{region}__run), secondsight_{region}__size, "{region}.lz"'
                )
            elif kind == "linked_literal":
                label, region, at, count = values
                base = region.replace(".", "_")
                lines.append(
                    f'  sram_literal_job {card(label)}, "{region}.bin", secondsight_{at}-secondsight_{base}__run, {count}'
                )
            elif kind == "linked_bytes":
                (region,) = values
                lines += [f"@{region}:", f'  .incbin "{region}.bin"', f"  .res (*-@{region}) .mod 2"]
            else:
                lines.append(f"  .{kind} " + ", ".join(value(v) for v in values))
        return lines


def content_key(data):
    """A key that is equal for equal host data: bytes, or HostData.key."""
    return data.key() if isinstance(data, HostData) else bytes(data)


def areas(labels):
    """{area: (start, size)} of the ld65 label file LABELS (define = yes)."""
    symbols, found = {}, {}
    for value, name in re.findall(r"^al ([0-9A-Fa-f]+) \.__(\w+)__$", labels.read_text(), re.MULTILINE):
        symbols[name] = int(value, 16)
    for name, start in symbols.items():
        if name.endswith("_START"):
            area = name[: -len("_START")]
            found[area] = (start, symbols[f"{area}_SIZE"])
    return found


class Host:
    def __init__(self, out):
        self.out = out
        out.mkdir(parents=True, exist_ok=True)
        self.area = areas(out / "areas/areas.lbl")  # area -> (start, size)
        self.used = dict.fromkeys(self.area, 0)
        self.segments = {}  # segment -> [(label, data, end)]: the blobs in order
        self.names = set()
        self.data_sources = {}  # label -> HostData: data that holds addresses
        self.contents = {}  # label -> the bytes of the host data

    def _place(self, data, name, segments, length=None):
        """DATA in the first of SEGMENTS with room, or in LINKED when the
        Second Sight link decides its size: its Address, or None. LENGTH
        names a 16-bit constant: the bytes of the blob (LABEL_END - LABEL)."""
        size = data.size() if isinstance(data, HostData) else len(data)
        if size is None:
            segment = LINKED
        else:
            segment = next((s for s in segments if self.used[s] + size <= self.area[s][1]), None)
            if segment is None:
                return None
            assert size <= BANK
            self.used[segment] += size
        label = name or f"host_data_{len(self.names)}"
        assert label not in self.names, label
        self.names.add(label)
        self.segments.setdefault(segment, []).append((label, data, length))
        if isinstance(data, HostData):
            self.data_sources[label] = data
        else:
            self.contents[label] = data
        return Address(label)

    def _fit(self, data, name, segments, length=None):
        address = self._place(data, name, segments, length)
        if address is None:
            room = ", ".join(f"{s} {self.area[s][1] - self.used[s]}" for s in segments)
            raise RuntimeError(f"no room for host data {name} ({len(data)} bytes). Free: {room}")
        return address

    def address(self, name):
        """The Address of the host data with label NAME."""
        assert name in self.names, name
        return Address(name)

    def blob_at(self, data, name=None, length=None):
        """DATA in the payload, inside one bank."""
        return self._fit(data, name, DATA, length)

    blob_at_bank = blob_at

    def world_blob_at(self, data, name=None):
        """DATA in the first world area with room, else in the payload. Only
        for immutable world packets that the main CPU reads, never DMA or an
        interrupt."""
        return self._place(data, name, WORLD) or self.blob_at(data, name)

    def slow_blob_at(self, data, name=None):
        """DATA in a video bank area (inside one bank)."""
        address = self._place(data, name, SLOW)
        if address is None:
            raise ValueError("IIgs video-bank data does not fit")
        return address

    def reserve(self, segment, size, name):
        """SIZE bytes of RAM NAME at the start of SEGMENT (before its data)."""
        assert not self.segments.get(segment), segment
        self.used[segment] += size
        self.segments[segment] = [(name, size, None)]
        self.names.add(name)

    def save(self):
        """host_data.s, host_data.bin and host_data.inc: the blobs of each
        segment in order. A segment in bank 0 is absolute, the others far."""
        raw = bytearray()

        def incbin(data):
            raw.extend(data)
            return [f'  .incbin "host_data.bin", {len(raw) - len(data)}, {len(data)}'] if data else []

        size = lambda segment: "absolute" if self.area[segment][0] < BANK else "far"
        lines = [
            "; Generated by scripts/iigs_payload.py: the host data.",
            ".p816",
            '.include "secondsight_symbols.inc"',
            '.include "host_jobs.inc"',
            '.include "host_data.inc"',
        ]
        names = []
        for segment in DATA + WORLD + SLOW + [LINKED]:
            if not self.segments.get(segment):
                continue
            lines.append(f'.segment "{segment}": {size(segment)}')
            for label, data, length in self.segments[segment]:
                names.append(f".global {label}: {size(segment)}")
                lines.append(f"{label}:")
                if isinstance(data, int):
                    lines.append(f"  .res {data}")
                elif isinstance(data, HostData):
                    lines += data.source(incbin)
                else:
                    lines += incbin(bytes(data))
                if length:
                    names.append(f".global {length}: absolute")
                    lines += [f"{label}_END:", f"{length} = .loword({label}_END-{label})"]
        (self.out / "host_data.bin").write_bytes(raw)
        (self.out / "host_data.s").write_text("\n".join(lines) + "\n")
        (self.out / "host_data.inc").write_text(
            "; Generated by scripts/iigs_payload.py: the labels of the host data.\n" + "\n".join(names) + "\n"
        )
