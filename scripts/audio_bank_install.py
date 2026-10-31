"""Install the shared SSG tables and the native effect command directory.

Each effect part is a list of build-resolved DOC writes (scripts/ssg_writes.py)
that src/audio_ssg.s plays without per-tick SSG logic. FM data is placed
separately by scripts/fm_native.py.
"""

import json, struct
from audio_config import volume_register
from harness import HostData
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
    init = [
        ".a8",
        ".i16",
        "audio_bank_init:",
        "  ldx #0",
        "@table:",
        "  phx",
        "  rep #$20",
        "  lda f:audio_tables,x",
        "  sta AUDIO_BINARY_SOURCE",
        "  sep #$20",
        "  lda f:audio_tables+2,x",
        "  sta AUDIO_BINARY_SOURCE+2",
        "  lda f:audio_tables+4,x",
        "  sta AUDIO_BINARY_AM",
        "@ready:",
        "  lda f:$e0c03c",
        "  bmi @ready",
        "  lda DOC_MASTER",
        "  ora #$60",
        "  sta f:$e0c03c",
        "  lda #0",
        "  sta f:$e0c03e",
        "  lda f:audio_tables+3,x",
        "  sta f:$e0c03f",
        "  lda f:audio_tables+5,x",
        "  rep #$20",
        "  and #255",
        "  tax",
        "  sep #$20",
        "  jsl audio_binary_upload",
        "  rep #$21",
        "  pla",
        "  adc #6",
        "  tax",
        "  sep #$20",
        f"  cpx #{len(tables)}",
        "  bne @table",
    ]
    # All six SSG pairs start halted and silent; a command starts its pair.
    registers = []
    for ch in range(6):
        odd = 13 + 2 * ch
        even = odd + 1
        registers += [(0x40 + odd, 0), (0x40 + even, 0), (0xA0 + odd, 3), (0xA0 + even, 3)]
    host.blob_at(bytes(v for pair in registers for v in pair), "audio_registers")
    init += [
        "@register_mode:",
        "  lda f:$e0c03c",
        "  bmi @register_mode",
        "  lda DOC_MASTER",
        "  sta f:$e0c03c",
        "  ldx #0",
        "@registers:",
        "  lda f:$e0c03c",
        "  bmi @registers",
        "  lda f:audio_registers,x",
        "  sta f:$e0c03e",
        "  inx",
        "  lda f:audio_registers,x",
        "  sta f:$e0c03d",
        "  inx",
        f"  cpx #{2 * len(registers)}",
        "  bne @registers",
    ]
    init += [
        "  rep #$20",
        "  ldx #190",
        "  lda #0",
        "@clear:",
        "  sta f:SSG_STATES|$010000,x",
        "  dex",
        "  dex",
        "  bpl @clear",
        "  sep #$20",
        "  stz SSG_PENDING",
        "  stz SSG_ACTIVE",
        "  stz a:$1ebe",
        "  stz a:$1ebf",
        "  rtl",
    ]
    host.blob_at(bytes(index), "SSG_COMMAND_INDEX")
    host.blob_at(directory, "SSG_COMMAND_ENTRIES")
    host.blob_at(masks, "SSG_MASKS")
    host.blob_at(fields, "SSG_FIELDS")
    host.blob_at(ssg_writes.kinds(), "SSG_KINDS")
    text = [
        f"AUDIO_VOLUME_MAP = {levels.label}",
        "SSG_PENDING = $1eb8",
        f"SSG_GATE_PAGE = ${places['stage_gate'] >> 8:02x}",
        f"SSG_NOISE_PAGE = ${places['stage_noise'] >> 8:02x}",
        f"SSG_ON_PAGE = ${places['stage_on'] >> 8:02x}",
        f"SSG_SQUARE_PAGE = ${squares[0]:02x}",
        f"SSG_NOISE_SIZE = {noise_size}",
        f"SSG_ON_SIZE = {noise_size & 7}",
    ] + init
    (out / "audio_bank.inc").write_text("\n".join(text) + "\n")
    receipt = dict(
        commands=len(commands),
        effect_parts=len(parts),
        effect_record_bytes=sum(len(b) for b in records),
        ssg_shared_table_bytes=len(masks) + len(fields) + 32,
        directory_bytes=len(index) + len(directory),
        ssg_table_bytes=sum(size for _, size, _, _ in entries),
        table_places={n: places[n] for n in names},
        code_sources=["src/audio_binary.s", "src/audio_ssg.s"],
        scope="Shared SSG tables and native effect commands",
    )
    (out / "audio-bank-install.json").write_text(json.dumps(receipt, indent=2) + "\n")
    return receipt
