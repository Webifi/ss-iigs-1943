"""Build original-US template-only enemy spawns as native data operations.

Recognized source shapes are fixed $06EC/$06DF allocation, a 32-byte
copy, optional further copies, and return. No program bytes are executed.
"""

import struct
from roms import load
from stage_controls import event_tables

BASE = 160


def collect():
    rom = load()[0]["maincpu"]
    tables, meta = event_tables()
    events = set()
    for data, row in zip(tables, meta):
        for i in range(0, row["final_end_offset"] + 1, 6):
            _, address, bank, _ = struct.unpack_from("<HHBB", data, i)
            if address >= 0x8000:
                events.add((bank // 4, address))
    result = {}
    for bank, address in sorted(events):
        image = rom[0x10000 + bank * 0x4000 : 0x14000 + bank * 0x4000]
        pos = address - 0x8000
        records = []
        source = None
        # Bank-six $8B2F-$8B6B select the template before the common allocator.
        if image[pos : pos + 1] == b"\x21":
            source = int.from_bytes(image[pos + 1 : pos + 3], "little")
            pos += 3
            if image[pos] == 0xC3:
                pos = int.from_bytes(image[pos + 1 : pos + 3], "little") - 0x8000
            records = [(0, image[source - 0x8000 : source - 0x8000 + 32])]
        else:
            for _ in range(8):
                if image[pos : pos + 6] not in (
                    bytes.fromhex("cd ec 06 c9 00 00"),
                    bytes.fromhex("cd df 06 c9 00 00"),
                ):
                    break
                capacity = 0
                pos += 6
                source = int.from_bytes(image[pos + 1 : pos + 3], "little")
                pos += 3
                pos += 5
                records.append((capacity, image[source - 0x8000 : source - 0x8000 + 32]))
                if image[pos] == 0xC9:
                    break
            else:
                pass
            if not records or image[pos] != 0xC9:
                continue
        assert all(len(data) == 32 for _, data in records)
        result[bank, address] = records
    result.update(parameterized(rom))
    result = dict(sorted(result.items()))
    assert BASE + len(result) <= 255, len(result)
    return result


def prepare(out):
    operations = collect()
    text = [
        f"SIMPLE_SPAWN_COUNT = {len(operations)}",
        "simple_spawn_plans:",
        "  .addr " + ",".join(f"simple_spawn_{i}" for i in range(len(operations))),
    ]
    roots = []
    templates = []
    for i, ((bank, address), records) in enumerate(operations.items()):
        text += [
            f"; Original US bank {bank}, ${address:04X}",
            f"simple_spawn_{i}:",
            f"  .byte {len(records)}",
        ]
        for capacity, data in records:
            candidates = [
                ([(n, v) for n, v in enumerate(data) if t[n] != v], j)
                for j, t in enumerate(templates)
            ]
            changes, j = (
                min(candidates, key=lambda v: len(v[0]))
                if candidates
                else (list(enumerate(data)), 0)
            )
            if len(changes) > 6:
                j = len(templates)
                templates.append(data)
                changes = []
            text += [
                f"  .byte {capacity}",
                f"  .addr simple_spawn_templates+{j * 32}",
                f"  .byte {len(changes)}",
            ]
            if changes:
                text += ["  .byte " + ",".join(str(v) for pair in changes for v in pair)]
            rebuilt = bytearray(templates[j])
            for offset, value in changes:
                rebuilt[offset] = value
            assert rebuilt == data
            roots.append((bank, int.from_bytes(data[30:32], "little") + 7))
    text += ["simple_spawn_templates:"]
    text += ["  .byte " + ",".join(str(v) for v in d) for d in templates]
    (out / "simple_spawn_data.inc").write_text("\n".join(text) + "\n")
    return roots


def parameterized(rom):
    """Fixed arguments folded into original template copies at build time."""

    def read(bank, address, n):
        p = address if address < 0x8000 else 0x10000 + bank * 0x4000 + address - 0x8000
        return rom[p : p + n]

    def item(bank, address, patch):
        data = bytearray(read(bank, address, 32))
        for offset, value in patch.items():
            data[offset] = value
        return bytes(data)

    result = {}
    for addresses, template in (
        ((0x6F4D, 0x6F52), 0x6F68),
        ((0x7304, 0x7309, 0x730E, 0x7313, 0x7318), 0x732E),
        ((0x758F, 0x7594, 0x7599, 0x759E, 0x75A3, 0x75A8), 0x75BE),
        ((0x7607, 0x760C, 0x7611, 0x7616), 0x762C),
    ):
        for address in addresses:
            assert rom[address] == 6
            result[0, address] = [(16, item(0, template, {2: rom[address + 1]}))]
    result[6, 0x9972] = [
        (16, item(6, 0x99C6, {3: read(6, 0x99B6 + 2 * n, 2)[0], 4: read(6, 0x99B6 + 2 * n, 2)[1]}))
        for n in range(7, -1, -1)
    ]
    result[0, 0x7377] = [(16, item(0, 0x7398, {}))]
    for i, variant in enumerate((0, 1, 2, 2, 2, 2, 3, 3)):
        direction, x, y = read(0, 0x8455 + 3 * i, 3)
        path = read(0, 0x846D + 2 * variant, 2)
        result[0, 0x83E5 + 7 * i] = [
            (0, item(0, 0x8477, {0x13: direction, 2: x, 3: y, 30: path[0], 31: path[1]}))
        ]
    records = []
    for i in range(5):
        x, delay = read(0, 0x93AC + 2 * i, 2)
        records.append((0, item(0, 0x93B6, {2: x, 0x11: delay})))
    result[0, 0x9382] = records
    for side, address in enumerate((0x9690, 0x9695)):
        records = []
        for n in range(6, -1, -1):
            delay, x = read(0, (0x96ED if side == 0 else 0x96FB) + 2 * n, 2)
            patch = {4: delay, 2: x, 0x11: side}
            if side == 0:
                patch.update({30: 0x58, 31: 0x98, 16: 2})
            records.append((0 if n == 6 else 16, item(0, 0x9709, patch)))
        result[0, address] = records
    for address, side, x in ((0x8FCE, 1, 0x10), (0x8FD5, 0, 0xE0)):
        result[6, address] = [(0, item(6, 0x8FF0, {0x12: side, 2: x}))]
    for address, template, table in ((0xB3E3, 0xB44F, 0xB433), (0xB40B, 0xB46F, 0xB441)):
        result[6, address] = [
            (
                16,
                item(
                    6, template, {4: read(6, table + 2 * n, 2)[0], 2: read(6, table + 2 * n, 2)[1]}
                ),
            )
            for n in range(6, -1, -1)
        ]
    for address, positions in (
        (0x8130, ((0x48, 2), (0x60, 1), (0x91, 1), (0xA9, 2))),
        (0x814F, ((0x40, 3), (0x50, 2), (0x60, 1), (0x90, 1), (0xA0, 2), (0xB0, 3))),
        (0x817C, ((0x40, 4), (0x50, 3), (0x60, 2), (0x91, 1), (0xA1, 3), (0xB1, 4))),
    ):
        result[4, address] = [(0, item(4, 0x81C6, {2: x, 17: life})) for x, life in positions]
    result[0, 0x722F] = [(16, item(0, 0x724B, {}))]
    result[0, 0x737D] = [(16, item(0, 0x73B8, {}))]
    for address, template, group in ((0xA0F7, 0xA133, 9), (0xAD7E, 0xADC8, 13)):
        result[6, address] = [(16, item(6, template, {4: 16 * n})) for n in range(8)]
    for address in (0x9D8A, 0x9D98):
        result[6, address] = [
            (16, item(6, 0x9DF1, {4: 8 * n, 19: n, 18: read(6, 0x9DE9 + n, 1)[0]}))
            for n in range(8)
        ]
    for address, template, table in (
        (0xA377, 0xA3DE, 0xA3CE),
        (0xA385, 0xA3DE, 0xA3CE),
        (0xA6E5, 0xA73E, 0xA72E),
    ):
        result[6, address] = [
            (
                16,
                item(
                    6,
                    template,
                    {4: read(6, table + 2 * n, 2)[0], 2: read(6, table + 2 * n, 2)[1], 18: n},
                ),
            )
            for n in range(7, -1, -1)
        ]
    for address, positions in ((0xA0F4, (0xB0, 0xC0)), (0xA108, (0x50, 0x60))):
        result[4, address] = [
            (
                0,
                item(
                    4,
                    0xA14C,
                    {
                        2: positions[(5 - n) % 2],
                        4: read(4, 0xA11C + 2 * n, 2)[0],
                        17: read(4, 0xA11C + 2 * n, 2)[1],
                    },
                ),
            )
            for n in range(5, -1, -1)
        ]
    return result
