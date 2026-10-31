"""Native ship-destruction data; original-US fixed tables $343F-$38A7."""

import struct
from roms import load


def prepare(out):
    rom = load()[0]["maincpu"]
    pointers = struct.unpack_from("<9H", rom, 0x343F)
    text = ["ship_finish_paths:", "  .addr " + ",".join("ship_finish_path%d" % i for i in range(9))]
    lengths = []
    for i, p in enumerate(pointers):
        end = p
        while rom[end] != 255:
            end += 3
        data = rom[p : end + 1]
        lengths.append((len(data) - 1) // 3)
        text += ["ship_finish_path%d:" % i, "  .byte " + ",".join("$%02x" % v for v in data)]
    for name, p, n in (("ship_finish_offsets", 0x3451, 18), ("ship_finish_templates", 0x3868, 64)):
        text += [name + ":", "  .byte " + ",".join("$%02x" % v for v in rom[p : p + n])]
    (out / "ship_finish_data.inc").write_text("\n".join(text) + "\n")
    return dict(pattern_lengths=lengths, roots=[(8, 0x5E91), (8, 0x6623), (8, 0x663B), (8, 0x6674)])
