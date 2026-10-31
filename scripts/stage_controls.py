"""Native US stage controls and complete original event data, build-time only."""

from harness import HostData
import json, struct, os
from roms import load

# Original callback -> native operation and constant. No arcade instructions
# are executed by the resulting game.
CONTROLS = {
    0x6A05: ("pan", 1),
    0x6A0B: ("flag", 17),
    0x6ADC: ("scroll", 0),
    0x6AE3: ("scroll", 255),
    0x6B4A: ("player_2_to_10", 0),
    0x6B5E: ("flag", 16),
    0x6B64: ("boss_hold", 0),
    0x6BE7: ("end", 0),
    0x6BF7: ("player_active_6", 0),
    0x6C13: ("player_lock", 255),
    0x6C2F: ("player_lock", 0),
}
for n in range(17):
    CONTROLS[0x6C4B + 5 * n] = ("difficulty", n)
for n in range(13):
    CONTROLS[0x6CB8 + 5 * n] = ("capacity", n + 4)
for n in range(8):
    CONTROLS[0x6EC5 + 5 * n] = ("modifier", 0xF1 + n)
for n in range(4):
    CONTROLS[0x679B + 30 * n] = ("land_camera", n)
for n, address in enumerate(
    (
        0x6813,
        0x6822,
        0x6831,
        0x683F,
        0x684E,
        0x685D,
        0x686B,
        0x687A,
        0x6889,
        0x6897,
        0x68A6,
        0x68B4,
        0x68C3,
        0x68D2,
        0x68E0,
        0x68EF,
    )
):
    CONTROLS[address] = ("ship_camera", n)
CONTROLS[0x68FE] = ("final_camera", 0)
FLOW_CONTROLS = {
    0x46DA: ("intro", 0),
    0x76F7: ("bonus", 0),
    0x690A: ("boss_camera", 0),
    0x6924: ("boss_camera", 1),
    0x693E: ("boss_camera", 2),
    0x6958: ("boss_reset", 0),
    0x6987: ("boss_replay", 0),
    0x6A11: ("boss_result", 0),
    0x6B41: ("banner", 0),
    0x6B70: ("accelerate", 0),
    0x6B96: ("decelerate", 0),
    0x6BBC: ("boss_departure", 0),
    0x6CFA: ("stage_difficulty", 0),
    0x6E11: ("secret_weapon", 0),
}
for address, command in zip(
    (0x6A31, 0x6A48, 0x6A5F, 0x6A76, 0x6A8D, 0x6A9F, 0x6AB1),
    (0x20, 0x22, 0x24, 0x30, 0x21, 0x23, 0x25),
):
    FLOW_CONTROLS[address] = ("music", command)


def prepare(out, flow=False):
    controls = CONTROLS | FLOW_CONTROLS
    ids = sorted(controls)
    assert len(ids) < 128
    text = (
        "STAGE_CONTROL_COUNT = %d\nstage_control_ids:\n  .word " % len(ids)
        + ",".join("$%04x" % c for c in ids)
        + "\n"
    )
    text += (
        "stage_control_targets:\n  .addr "
        + ",".join("stage_control_" + controls[c][0] for c in ids)
        + "\n"
    )
    # Parameters are words so the identifier, vector and parameter use one X.
    text += "stage_control_values:\n  .word " + ",".join(str(controls[c][1]) for c in ids) + "\n"
    if flow:
        r = load()[0]["maincpu"]
        text += ".ifndef NATIVE_STAGE_FLOW\nNATIVE_STAGE_FLOW = 1\n.endif\n"
        for name, offset, size in (
            ("stage_difficulty_values", 0x6D11, 256),
            ("stage_weapon_secrets", 0x6E85, 64),
        ):
            text += (
                name + ":\n  .byte " + ",".join(str(v) for v in r[offset : offset + size]) + "\n"
            )
    (out / "stage_controls.inc").write_text(text)
    return ids


def event_tables():
    rom = load()[0]["maincpu"]
    pointers = struct.unpack_from("<16H", rom, 0x11A7)
    tables = []
    meta = []
    for stage, ptr in enumerate(pointers):
        bank = 2 if stage < 8 else 5 if stage < 15 else 7
        end = pointers[stage + 1] if stage not in (7, 14, 15) else 0xC000
        base = 0x10000 + bank * 0x4000 - 0x8000
        data = rom[base + ptr : base + end]
        # Retain the complete pointer interval, including post-end branch records.
        # The first end record is an observation, never a truncation rule.
        records = []
        for offset in range(0, len(data) - 5, 6):
            camera, callback, selector, pad = struct.unpack_from("<HHBB", data, offset)
            records.append(
                dict(offset=offset, camera=camera, callback=callback, bank=selector // 4)
            )
            if callback == 0x6BE7:
                break
        assert records[-1]["callback"] == 0x6BE7, (stage, ptr)
        ends = [i for i in range(0, len(data) - 5, 6) if data[i + 2 : i + 4] == b"\xe7\x6b"]
        assert 1 <= len(ends) <= 2, (stage, ends)
        tables.append(data)
        meta.append(
            dict(
                stage=stage,
                original_bank=bank,
                original_pointer=ptr,
                bytes=len(data),
                first_end_offset=ends[0],
                final_end_offset=ends[-1],
                events_through_first_end=len(records),
            )
        )
    return tables, meta


def install(out, host, enemy_spawns=False):
    tables, meta = event_tables()
    pointers = []
    compact = True
    descriptors = {}
    descriptor_bytes = bytearray()
    for data, row in zip(tables, meta):
        # Populate the unused sixth byte with the native control index before
        # optionally packing each event for the production build.
        data = bytearray(data)
        indices = {c: i for i, c in enumerate(sorted(CONTROLS | FLOW_CONTROLS))}
        if enemy_spawns:
            from medium_enemies import SPAWNS

            spawn_indices = {(SPAWNS[c][0], c): 128 + i for i, c in enumerate(sorted(SPAWNS))}
            from large_enemies import SPAWNS as LARGE_SPAWNS

            spawn_indices.update({(4, c): 140 + i for i, c in enumerate(sorted(LARGE_SPAWNS))})
            from ship_turrets import SPAWNS as TURRET_SPAWNS

            spawn_indices.update({(6, c): 149 + i for i, c in enumerate(sorted(TURRET_SPAWNS))})
            from simple_spawns import collect, BASE

            spawn_indices.update({key: BASE + i for i, key in enumerate(collect())})
        if enemy_spawns:
            from extended_spawns import collect as extended_collect

            spawn_indices.update({key: 254 for key in extended_collect()})
        for offset in range(0, len(data) - 5, 6):
            callback = int.from_bytes(data[offset + 2 : offset + 4], "little")
            bank = data[offset + 4] // 4
            data[offset + 5] = (
                indices.get(callback, spawn_indices.get((bank, callback), 255))
                if callback < 0x8000
                else spawn_indices.get((bank, callback), 255)
            )
        if row["first_end_offset"] < row["final_end_offset"]:
            # Retry starts just after the first end. The final end stops the camera;
            # keep it and one following record for a possible final event check.
            # Other consumers use event_tables() unchanged, including retry offsets.
            end = row["final_end_offset"] + 12
            if end < len(data):
                assert data[end - 10 : end - 8] == b"\xe7\x6b"
                row["stored_bytes"] = end
                row["tail_released"] = len(data) - end
                data = data[:end]
        if compact:
            assert len(data) % 6 == 0
            packed = bytearray()
            for i in range(0, len(data), 6):
                descriptor = bytes(data[i + 2 : i + 6])
                if descriptor not in descriptors:
                    descriptors[descriptor] = len(descriptor_bytes)
                    descriptor_bytes.extend(descriptor)
                packed.extend(data[i : i + 2])
                packed.extend(struct.pack("<H", descriptors[descriptor]))
            row["packed_bytes"] = len(packed)
            data = packed
        allocate = host.slow_blob_at
        address = allocate(data)
        pointers.append(address)
        row["host_label"] = address.label
    if compact:
        descriptor_ptr = host.slow_blob_at(descriptor_bytes)
    # Four-byte entries make selection a pair of shifts; pad is not address data.
    table = HostData()
    for pointer in pointers:
        table.faraddr(pointer).byte(0)
    host.blob_at(table, "STAGE_TABLE_POINTERS")
    test_stage = int(os.environ.get("SS1943_START_STAGE", "1"))
    assert 1 <= test_stage <= 16
    test_define = ""
    (out / "stage_data.inc").write_text(
        test_define
        + "STAGE_ALL_TABLES = 1\n"
        + (f"STAGE_COMPACT = 1\nSTAGE_DESCRIPTORS = {descriptor_ptr.label}\n")
    )
    prepare(out, flow=enemy_spawns)
    (out / "stage-tables.json").write_text(json.dumps(meta, indent=2) + "\n")
    return meta
