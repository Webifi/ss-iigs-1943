"""Eight original-US ship cores share one native policy and build-time data.

Every nonzero-pattern core has the same instruction structure. Only its
local script pointers and destruction-pattern byte differ. Core zero also
cancels task three before starting its final destruction sequence.
"""

import hashlib
from roms import load

TEMPLATES = (0x8634, 0x87CE, 0x895B, 0x8ADE, 0x8C66, 0x8DE9, 0x8F6C, 0x90F4)
SPAWNS = {
    0x87A3: 0,
    0x8926: 1,
    0x892B: 1,
    0x8AB3: 2,
    0x8C36: 3,
    0x8C3B: 3,
    0x8DBE: 4,
    0x8F41: 5,
    0x90C4: 6,
    0x90C9: 6,
}

# The original-US core bodies that share one native routine. Runtime tables
# come from the verified ROM below.
CORE_SHA256 = (
    "26c9e485f8707ce458fd476c99615698073586d7553358ab4d0fc09adcff1803",
    "c1365c3d8eeaafe7b89d7d63e795418fd4fa3fc895ce7677df4b25e3dc9ee5dd",
    "504667ac7ecf879fc6d6d4b70fa575d76f3ba8f95592835785876f5ff6535b34",
    "22e186011f58567ff7526e537bcaa6653242b0b147aa4ad21a8b84d64ff1dddf",
    "027cb954ff3032d80dee99eda0901f128a8f159289bee64f623f179f8b2124f5",
    "63f8025dc3aac58faa958f08d96fd2e4dd48bd253f26d34eec195e0f500adda5",
    "a1117c8906a175a400881fcb6ab6362611b9e6e3081866dc4a23a7544aea8548",
)


def definitions():
    r = load()[0]["maincpu"][0x20000:0x24000]

    def read(p, n):
        return r[p - 0x8000 : p - 0x8000 + n]

    def word(p):
        return int.from_bytes(read(p, 2), "little")

    result = []
    for pattern, template in enumerate(TEMPLATES):
        base = template + 32
        retire = base + (0xD4 if pattern == 0 else 0xCF)
        callbacks = (base, base + 0x35, base + 0x87, base + 0xB8, retire)
        paths = (
            word(base + 1),
            word(base + 0x88),
            word(base + 0xB3),
            word(retire - 5),
            word(retire + 5),
        )
        assert read(base, 1) == b"\x21" and read(base + 0x35, 3) == bytes.fromhex("dd7e0e")
        assert read(base + 0x87, 1) == b"\x21" and read(base + 0xB8, 2) == bytes((0x3E, pattern))
        assert read(retire, 4) == bytes.fromhex("dd360904")
        result.append(
            dict(
                pattern=pattern,
                callbacks=callbacks,
                paths=paths,
                template=template,
                action=6 if pattern == 0 else 4,
                near=read(base + 0x60, 1)[0],
                far=read(base + 0x8E, 1)[0],
            )
        )
    # Reject different core bodies without loading an external disassembler.
    # Whole-ROM checksums also remain mandatory in roms.load(). These hashes
    # preserve the original structural check's accepted inputs for 1943ua.
    for item, expected in zip(result[1:], CORE_SHA256):
        base = item["callbacks"][0]
        assert hashlib.sha256(read(base, 0xD9)).hexdigest() == expected, (
            "changed US core",
            item["pattern"],
        )
    return result


def prepare(out):
    items = definitions()
    rows = {}
    for index, item in enumerate(items):
        for phase, callback in enumerate(item["callbacks"]):
            rows.setdefault(callback >> 8, []).append((callback, index * 14, phase * 2))
    lines = ["ALL_BOSS_CORES = 1", "boss_core_configs:"]
    roots = []
    for item in items:
        lines += [
            "  .word " + ",".join("$%04x" % p for p in item["paths"]),
            f"  .byte {item['pattern']},{item['action']},{item['near']},{item['far']}",
        ]
        roots.extend((4, p) for p in item["paths"])
    lines += [
        "boss_core_pages:",
        "  .addr "
        + ",".join(
            f"boss_core_page_{page:02x}" if page in rows else "boss_core_empty"
            for page in range(0x80, 0xC0)
        ),
    ]
    for page, records in rows.items():
        lines += [f"boss_core_page_{page:02x}:"]
        lines += ["  .word $%04x,%d,%d" % row for row in records]
        lines += ["  .word 0"]
    lines += [
        "boss_core_empty: .word 0",
        "boss_core_vectors:",
        "  .addr ship_core_alive,ship_core_died,ship_core_wait,ship_core_finish,boss_core_retire",
    ]
    (out / "boss_core_data.inc").write_text("\n".join(lines) + "\n")
    return roots
