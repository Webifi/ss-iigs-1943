"""Port movement-script data handling without executing original program code."""

from iigs_payload import HostData
from roms import load

# The page table of the motion scripts (src/records.inc, src/enemy_script.s):
# bank n has the rows from n * SCRIPT_BANK_ROWS, the fixed ROM bank 8 the
# rows from SCRIPT_FIXED_ROW. enemy_script_data.inc asserts the same values.
SCRIPT_BANK_ROWS = 64
SCRIPT_FIXED_ROW = 8 * SCRIPT_BANK_ROWS


def prepare_data(out, rows, roots=()):
    regions, _ = load()
    program = regions["maincpu"]
    images = [bytearray(16384) for _ in range(8)] + [bytearray(32768)]
    seen = set()
    callbacks = set()
    art = set()
    used_pages = set()
    extents = {}
    pending = [((r[18] >> 4) & 7, int.from_bytes(r[38:40], "little") + 7) for r in rows] + list(
        roots
    )
    while pending:
        bank, addr = pending.pop()
        if addr < 0x8000:
            bank = 8
        if (bank, addr) in seen:
            continue
        seen.add((bank, addr))
        assert 0 <= addr < 0xC000, (bank, addr)
        source = (
            program[:0x8000]
            if bank == 8
            else program[0x10000 + bank * 0x4000 : 0x14000 + bank * 0x4000]
        )
        off = addr if bank == 8 else addr - 0x8000
        op = source[off]
        n = 3 if op in (0, 255) else 1 if op == 254 else 7
        images[bank][off : off + n] = source[off : off + n]
        used_pages.update((bank, (off + j) // 256) for j in range(n))
        for j in range(n):
            key = (bank, (off + j) // 256)
            position = (off + j) & 255
            lo, hi = extents.get(key, (256, 0))
            extents[key] = (min(lo, position), max(hi, position + 1))
        if op == 255:
            pending.append((bank, int.from_bytes(source[off + 1 : off + 3], "little")))
        elif op == 0:
            callback = int.from_bytes(source[off + 1 : off + 3], "little")
            callbacks.add((bank, callback))
            if (
                callback in (0x8A57, 0x49B5, 0x49BF, 0x80D8, 0x8FBE)
                or bank == 4
                and callback in (0xA33E, 0xA343, 0xA348, 0xB4D5, 0x9F4F)
            ):
                pending.append((bank, addr + 3))
        elif op != 254:
            art.add((source[off + 1] + ((source[off + 2] & 224) << 3), source[off + 2] & 15))
            pending.append((bank, addr + 7))

    def prepare(host, propellers=None, pieces=None):
        """PROPELLERS: {code: pairs} of the propeller art (scripts/propellers.py).
        The card spins propellers with two DAC entries, so a record of
        propeller art keeps the even palette of its pair: the arcade's own
        flips between the two palettes of a pair are dropped. PIECES: the
        piece offsets of the object of each record (default: one piece)."""
        for bank, addr in seen if propellers else ():
            off = addr if bank == 8 else addr - 0x8000
            op, low, attr = images[bank][off : off + 3]
            if op in (0, 254, 255) or not attr & 1:
                continue
            code, pair = low + ((attr & 224) << 3), (attr & 15) >> 1
            if any(pair in propellers.get(code + o, ()) for o in (pieces or {}).get((bank, addr), (0,))):
                images[bank][off + 2] = attr & 0xFE
        # A single page lookup serves an entire seven-byte movement record.
        # The six-byte tail also handles records crossing a page boundary.
        # Empty original address pages occupy no host RAM. The pages form one
        # block in one bank: a page shares its first bytes with the end of the
        # page before it where they are equal (the six-byte next-page guard).
        pages = [0] * 640
        offsets = {}
        stream = bytearray()
        last_data = b""
        overlap_bytes = 0
        for bank, page in sorted(used_pages):
            first, last = extents[bank, page]
            last = min(262, last + 6)
            data = bytes(images[bank][page * 256 + first : page * 256 + last]).ljust(
                last - first, b"\0"
            )
            if data not in offsets:
                overlap = next(
                    (n for n in range(min(len(last_data), len(data)), 2, -1) if last_data[-n:] == data[:n]),
                    0,
                )
                offsets[data] = len(stream) - overlap
                stream += data[overlap:]
                overlap_bytes += overlap
                last_data = data
            assert stream[offsets[data] : offsets[data] + len(data)] == data
            slot = (SCRIPT_FIXED_ROW + page) if bank == 8 else bank * SCRIPT_BANK_ROWS + page
            pages[slot] = (offsets[data] - first, data)
        block = host.blob_at_bank(bytes(stream), "enemy_script_data")
        table = HostData().faraddr(*(block + entry[0] if entry else 0 for entry in pages))
        host.blob_at(table, "enemy_script_pages")
        # The direct pool reader uses the bank of the block, including a page
        # pointer biased into the preceding bank. Other readers consume the
        # 24-bit table.
        (out / "enemy_script_data.inc").write_text(
            "ENEMY_SCRIPT_FAST_BANK = ^enemy_script_data\n"
            f".assert SCRIPT_BANK_ROWS = {SCRIPT_BANK_ROWS} .and SCRIPT_FIXED_ROW = {SCRIPT_FIXED_ROW}, error\n"
        )
        meta.update(
            table_storage_bytes=3 * len(pages) + len(stream),
            bank_padding_bytes=0,
            page_overlap_bytes=overlap_bytes,
            resident_pages=len(offsets),
            original_sparse_bytes=sum(map(len, images)),
        )

    def record(bank, addr):
        if addr < 0x8000:
            bank = 8
        source = (
            program[:0x8000]
            if bank == 8
            else program[0x10000 + bank * 0x4000 : 0x14000 + bank * 0x4000]
        )
        off = addr if bank == 8 else addr - 0x8000
        return bank, source[off : off + 7]

    # Propeller flips (scripts/propellers.py): a record followed by the same
    # code in another palette (both palettes count), or a code in both
    # palettes of a pair.
    flips = {(code, color >> 1) for code, color in art if (code, color ^ 1) in art}
    for bank, addr in seen:
        _, data = record(bank, addr)
        if data[0] in (0, 254, 255):
            continue
        follow, after = record(bank, addr + 7)
        visited = set()
        while after[0] == 255 and (follow, after[1:3]) not in visited:
            visited.add((follow, after[1:3]))
            follow, after = record(follow, int.from_bytes(after[1:3], "little"))
        if after[0] not in (0, 254, 255) and after[1] == data[1] and (after[2] ^ data[2]) & 0xEF:
            if (after[2] ^ data[2]) & 0xE0 == 0:
                code = data[1] + ((data[2] & 224) << 3)
                flips.update(((code, (data[2] & 15) >> 1), (code, (after[2] & 15) >> 1)))
    meta = dict(
        records=seen,
        flips=sorted(flips),
        prepared_records=len(seen),
        data_bytes=sum(sum(bool(b) for b in x) for x in images),
        art_keys=sorted(art),
        callbacks=[dict(bank=b, address=f"{a:04X}") for b, a in sorted(callbacks)],
    )
    return prepare, meta
