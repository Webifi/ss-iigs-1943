"""Check the native flight routine against unmodified original-US executions."""

import struct

from roms import load


def prepare_tables(out):
    regions, roms = load()
    program = regions["maincpu"]
    bank = program[0x14000:0x18000]
    pointers = struct.unpack_from("<6H", bank, 0x735)
    assert pointers == tuple(0x8000 + i * 96 for i in range(6)), pointers
    # STAGE_PLAYER_SPEED ($E14A) comes from stage_difficulty_values ($6D11,
    # src/stage_flow.s): only the tables that it can select are kept.
    tables = max(program[0x6D11 : 0x6D11 + 256]) + 1
    moves = bank[: tables * 96]
    delays = bank[0x79B:0x7A1]

    def db(label, b):
        return (
            label
            + ":\n"
            + "\n".join(
                "  .byte " + ",".join(f"${v:02x}" for v in b[i : i + 16])
                for i in range(0, len(b), 16)
            )
            + "\n"
        )

    (out / "flight_data.inc").write_text(
        "flight_speed_offsets:\n  .word " + ",".join(str(i * 96) for i in range(tables)) + "\n"
        + db("flight_moves", moves)
        + db("flight_delays", delays)
    )
    return roms
