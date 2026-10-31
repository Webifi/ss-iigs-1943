"""Fold fixed stage-spawn choices into native allocation/template plans.

Only data is emitted. Pool choice, camera subtraction, persistent damage and
multi-part initialization remain native operations.
"""

import struct
from roms import load
from stage_controls import event_tables

EXTENDED_POOL = 0x5A00
# Flags: camera-relative X, persistent group, four-piece, all attrs/blank tails,
# difficulty >=9 clears field12.
RELATIVE, GROUP, QUAD, CLEAR, DIFFICULTY = 1, 2, 4, 8, 16


def collect():
    rom = load()[0]["maincpu"]
    result = {}

    def read(bank, p, n):
        return (
            rom[p : p + n]
            if p < 0x8000
            else rom[
                0x10000 + bank * 0x4000 + p - 0x8000 : 0x10000 + bank * 0x4000 + p - 0x8000 + n
            ]
        )

    def item(bank, p, kind=0, flags=0, patch=None):
        data = bytearray(read(bank, p, 32))
        for k, v in (patch or {}).items():
            data[k] = v
        return kind, flags, bytes(data)

    tables, metadata = event_tables()
    events = set()
    for table, meta in zip(tables, metadata):
        for i in range(0, meta["final_end_offset"] + 1, 6):
            _, p, b, _ = struct.unpack_from("<HHBB", table, i)
            events.add((b // 4 if p >= 0x8000 else 0, p))
    # Recognize just the constant prefixes, stopping at the documented common
    # native operation. Unknown source shapes are not silently accepted.
    tails = {
        (0, 0xAD0A): (0xAD22, 0, RELATIVE | GROUP),
        (0, 0xAECE): (0xAEE9, 0, RELATIVE),
        (0, 0xB316): (0xB32E, 0, RELATIVE | GROUP),
        (0, 0xB4B5): (0xB4CD, 0, RELATIVE | GROUP),
        (0, 0xB647): (0xB66D, 2, RELATIVE | GROUP | QUAD),
        (0, 0xB7CD): (0xB7F3, 2, RELATIVE | GROUP | QUAD),
        (0, 0xB978): (0xB990, 0, RELATIVE | GROUP),
        (0, 0xBB11): (0xBB2C, 0, RELATIVE),
        (4, 0xA8BA): (0xA8DC, 1, QUAD),
        (4, 0xAA04): (0xAA29, 1, QUAD),
        (6, 0x8929): (0x8952, 2, RELATIVE | QUAD),
    }
    for bank, address in sorted(events):
        pc = address
        values = {}
        for _ in range(4):
            op = read(bank, pc, 1)[0]
            if op in (6, 14):
                values["b" if op == 6 else "c"] = read(bank, pc + 1, 1)[0]
                pc += 2
            elif op == 0xC3:
                pc = int.from_bytes(read(bank, pc + 1, 2), "little")
            else:
                break
        if (bank, pc) in tails and "b" in values:
            p, kind, flags = tails[bank, pc]
            patch = {2: values["b"]}
            if pc == 0xAA04:
                patch[17] = values["c"]
            result[bank, address] = [item(bank, p, kind, flags, patch)]
        elif bank == 0 and pc == 0xB11C and set(values) == {"b", "c"}:
            group = values["c"] != 0
            result[bank, address] = [
                item(
                    0,
                    0xB165 if group else 0xB145,
                    0,
                    RELATIVE | (GROUP if group else 0),
                    {2: values["b"]},
                )
            ]
        elif bank == 4 and pc == 0xA5CE and set(values) == {"b", "c"}:
            table = int.from_bytes(read(4, 0xA60A + values["c"], 2), "little")
            result[bank, address] = [
                item(4, 0xA63F, 0, DIFFICULTY, dict(zip((4, 2, 17, 18), read(4, table + 4 * n, 4))))
                for n in range(2, -1, -1)
            ]
        elif bank == 4 and pc == 0xBA49 and "b" in values:
            result[bank, address] = [item(4, p, 0, 0, {2: values["b"]}) for p in (0xBA70, 0xBA90)]
    for bank, address, p, kind, flags in [
        (0, 0xBC86, 0xBC95, 0, 0),
        (4, 0xAB66, 0xAB85, 1, QUAD),
        *((4, 0xADE4 + 12 * i, 0xAE43 + 32 * i, 1, QUAD | CLEAR) for i in range(5)),
        (6, 0xB00C, 0xB049, 1, QUAD | CLEAR),
        (6, 0xB019, 0xB069, 1, QUAD | CLEAR),
    ]:
        if (bank, address) in events:
            result[bank, address] = [item(bank, p, kind, flags)]
    for address, p in ((0xB91D, 0xB948), (0xB9A8, 0xB9D3)):
        result[4, address] = [item(4, p + 32 * i) for i in range(3)]
    for address, template, table in ((0xAFCB, 0xB054, 0xB028), (0xAFF8, 0xB074, 0xB025)):
        result[4, address] = [
            item(
                4,
                template,
                1,
                QUAD | CLEAR,
                {2: read(4, table + n, 1)[0], 4: read(4, 0xB02B + n, 1)[0]},
            )
            for n in range(2, -1, -1)
        ]
    for address, template in (
        (0xA43F, 0xA47F),
        (0xA473, 0xA49F),
        (0xA043, 0xA083),
        (0xA077, 0xA0A3),
    ):
        result[0, address] = [item(0, template, 3, QUAD)]
    result[6, 0x85D6] = [item(6, 0x85FE, 2, RELATIVE | GROUP | QUAD, {2: 0x80})]
    from boss_cores import SPAWNS as cores, TEMPLATES

    for address, index in cores.items():
        assert read(4, address, 1) == b"\x06"
        result[4, address] = [
            item(4, TEMPLATES[index + 1], 1, RELATIVE | QUAD, {2: read(4, address + 1, 1)[0]})
        ]
    return dict(sorted(result.items()))


def prepare(out):
    plans = collect()
    lines = [f"EXTENDED_SPAWN_COUNT = {len(plans)}", "extended_spawn_ids:"]
    roots = []
    lines += [
        "  .word " + ",".join(f"${p:04x}" for bank, p in plans),
        "extended_spawn_banks:",
        "  .byte " + ",".join(str(bank * 4) for bank, p in plans),
        "extended_spawn_plans:",
        "  .addr " + ",".join(f"extended_spawn_plan{i}" for i in range(len(plans))),
    ]
    templates = {}
    data = []
    for i, ((bank, address), records) in enumerate(plans.items()):
        lines += [
            f"; Original US bank {bank}, ${address:04X}",
            f"extended_spawn_plan{i}:",
            f"  .byte {len(records)}",
        ]
        for kind, flags, record in records:
            if record not in templates:
                templates[record] = len(data)
                data.extend(record)
            lines += [
                f"  .byte {kind},{flags}",
                f"  .addr extended_spawn_templates+{templates[record]}",
            ]
            roots.append((bank, int.from_bytes(record[30:32], "little") + 7))
    lines += ["extended_spawn_templates:"]
    lines += [
        "  .byte " + ",".join(str(v) for v in data[i : i + 32]) for i in range(0, len(data), 32)
    ]
    (out / "extended_spawn_data.inc").write_text("\n".join(lines) + "\n")
    return roots
