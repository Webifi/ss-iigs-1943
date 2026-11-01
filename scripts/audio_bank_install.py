"""Install the shared SSG tables and the native effect command directory.

Each effect part is a list of build-resolved DOC writes (scripts/ssg_writes.py)
that src/audio_ssg.s plays without per-tick SSG logic. FM data is placed
separately by scripts/fm_native.py.
"""

import json, struct
from audio_config import volume_register
from iigs_payload import HostData
from audio_preview import layout
from sound_files import BANK
from ssg_logic import ROTATIONS
import ssg_writes
import numpy as np


def install(out, host, law="knee"):
    data = (BANK / "bank.bin").read_bytes()
    models = json.loads((BANK / "models.json").read_text())
    nm, nt, nr, nw = struct.unpack_from("<HHII", data, 8)
    wave_base = 20 + 6 * nm + 9 * nt + nr
    effects = [m for m in models if m["source"]["kind"] == "effect"]
    names = ["stage_noise", "stage_gate", "stage_on"] + [
        f"stage_square_{k}" for k in range(ROTATIONS)
    ]
    ids = effects[0]["pool_ids"]
    assert all(all(m["pool_ids"][n] == ids[n] for n in names) for m in effects), (
        "one shared SSG table set"
    )
    entries = [struct.unpack_from("<IHHB", data, 20 + 6 * nm + 9 * ids[name]) for name in names]
    _, places = layout({name: np.zeros(raw, "u1") for name, (_, _, raw, _) in zip(names, entries)})
    squares = [places[f"stage_square_{k}"] >> 8 for k in range(ROTATIONS)]
    assert squares == list(range(squares[0], squares[0] + ROTATIONS))
    # Binary pages expand straight to DOC RAM; the gate's levels go through the law.
    tables = HostData()
    for name, (offset, size, raw, kind) in zip(names, entries):
        assert kind == 1 and places[name] % 256 == 0
        tables.faraddr(host.blob_at(data[wave_base + offset : wave_base + offset + size]))
        tables.byte(places[name] >> 8, int(name == "stage_gate"), raw // 256)
    host.blob_at(tables, "audio_tables")
    levels = host.blob_at(bytes(max(1, volume_register(v, law)) for v in range(256)))
    noise_size = effects[0]["noise_size"]
    assert all(m["noise_size"] == noise_size for m in effects)
    pages = (
        places["stage_gate"] >> 8,
        places["stage_noise"] >> 8,
        places["stage_on"] >> 8,
        squares[0],
        noise_size,
        noise_size & 7,
    )
    # Command directory: per command six parts of (record24, bytes16).
    parts = {}
    records = {}
    lists, masks, fields = ssg_writes.lists(effects, pages)
    for m, packed in zip(effects, lists):
        key = (m["source"]["command"], m["source"]["channel"])
        assert key not in parts, key
        body = (
            struct.pack(
                "<BBHHH", 3, m["tone_size"], ids["stage_gate"], ids["stage_noise"], ids["stage_on"]
            )
            + b"".join(struct.pack("<H", ids[f"stage_square_{k}"]) for k in range(ROTATIONS))
            + packed
        )
        if body not in records:
            records[body] = host.blob_at(body)
        parts[key] = (records[body], len(body))
    commands = sorted({c for c, _ in parts})
    index = bytearray([255]) * 64
    directory = HostData()
    for i, cmd in enumerate(commands):
        index[cmd] = i
        for ch in range(6):
            ptr, n = parts.get((cmd, ch), (0, 0))
            directory.faraddr(ptr).word(n)
    # All six SSG pairs start halted and silent; a command starts its pair.
    registers = []
    for ch in range(6):
        odd = 13 + 2 * ch
        even = odd + 1
        registers += [(0x40 + odd, 0), (0x40 + even, 0), (0xA0 + odd, 3), (0xA0 + even, 3)]
    host.blob_at(bytes(v for pair in registers for v in pair), "audio_registers")
    host.blob_at(bytes(index), "SSG_COMMAND_INDEX")
    host.blob_at(directory, "SSG_COMMAND_ENTRIES")
    host.blob_at(masks, "SSG_MASKS")
    host.blob_at(fields, "SSG_FIELDS")
    host.blob_at(ssg_writes.kinds(), "SSG_KINDS")
    text = [
        # An audio_tables record: faraddr(source), then the three bytes above.
        "AT_SOURCE = 0",
        "AT_PAGE = 3",
        "AT_AM = 4",
        "AT_PAGES = 5",
        "AT_SIZE = 6",
        # The effect lists (scripts/ssg_writes.py) for src/audio_ssg.s.
        f"SSG_HEAD = {struct.calcsize('<BBHHH') + 2 * ROTATIONS}",
        "SSG_HEAD_TONE_SIZE = 1",
        f"SSG_EXPLICIT = {ssg_writes.EXPLICIT}",
        f"SSG_DELAY_UNIT = {ssg_writes.DELAY_UNIT}",
        f"SSG_END_HEADER = ${ssg_writes.END_HEADER:02x}",
        f"SSG_REPEAT_HEADER = ${ssg_writes.REPEAT_HEADER:02x}",
        f"SSG_COMMANDS = {len(index)}",
        "SSG_NO_COMMAND = $ff",
        "SSG_ENTRY_SIZE = 5",
        f"AUDIO_VOLUME_MAP = {levels.label}",
        f"SSG_NOISE_SIZE = {noise_size}",
        f"AUDIO_TABLE_BYTES = {len(tables)}",
        f"AUDIO_REGISTER_BYTES = {2 * len(registers)}",
    ]
    (out / "audio_bank_data.inc").write_text("\n".join(text) + "\n")
