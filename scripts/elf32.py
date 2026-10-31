"""Read 32-bit little-endian ELF files: object files and executables of
GNU binutils."""

import struct

SHT_PROGBITS, SHT_SYMTAB, SHT_RELA, SHT_NOBITS = 1, 2, 4, 8
SHN_UNDEF, SHN_ABS = 0, 0xFFF1
STT_SECTION = 3
BINDS = {0: "LOCAL", 1: "GLOBAL", 2: "WEAK"}


def read(path):
    """The bytes and section headers of a 32-bit little-endian ELF file, and
    a function that reads a name from a string table."""
    data = path.read_bytes()
    assert data[:6] == b"\x7fELF\x01\x01", path
    (offset,) = struct.unpack_from("<I", data, 0x20)
    size, count, names = struct.unpack_from("<HHH", data, 0x2E)
    headers = [struct.unpack_from("<10I", data, offset + i * size) for i in range(count)]

    def string(table, at):
        start = headers[table][4] + at
        return data[start : data.index(b"\0", start)].decode()

    return data, headers, lambda header: string(names, header[0]), string


def sections(path):
    """Contents of the PROGBITS sections of an ELF file."""
    data, headers, name, _ = read(path)
    return {name(h): data[h[4] : h[4] + h[5]] for h in headers if h[1] == SHT_PROGBITS}


def loads(path):
    """Run address, load address and contents of each PROGBITS section of an
    executable: the load address comes from the program header that holds it."""
    data, headers, name, _ = read(path)
    (offset,) = struct.unpack_from("<I", data, 0x1C)
    size, count = struct.unpack_from("<HH", data, 0x2A)
    segments = [struct.unpack_from("<8I", data, offset + i * size) for i in range(count)]
    loads = {}
    for h in headers:
        if h[1] != SHT_PROGBITS or not h[5]:
            continue
        segment = next(s for s in segments if s[0] == 1 and s[1] <= h[4] < s[1] + s[4])
        loads[name(h)] = (h[3], segment[3] + h[4] - segment[1], data[h[4] : h[4] + h[5]])
    return loads


def read_object(path):
    """The symbol table of an object file, name -> (value, section, bind,
    type), with the section "UND" or "ABS" for those symbols; and its
    relocations, section -> [(offset, type, symbol, addend)]. A relocation
    against a section symbol names that section."""
    data, headers, name, string = read(path)
    table = next(i for i, h in enumerate(headers) if h[1] == SHT_SYMTAB)
    entries = []
    for at in range(headers[table][4], headers[table][4] + headers[table][5], 16):
        st_name, value, _, info, _, index = struct.unpack_from("<IIIBBH", data, at)
        where = "UND" if index == SHN_UNDEF else "ABS" if index == SHN_ABS else name(headers[index])
        label = name(headers[index]) if info & 15 == STT_SECTION else string(headers[table][6], st_name)
        entries.append((label, value, where, BINDS.get(info >> 4, "OTHER"), info & 15))
    symbols = {
        label: (value, where, bind, kind)
        for label, value, where, bind, kind in entries
        if label and kind != STT_SECTION
    }
    relocs = {}
    for header in headers:
        if header[1] == SHT_RELA and header[6] == table:
            target = relocs.setdefault(name(headers[header[7]]), [])
            for at in range(header[4], header[4] + header[5], 12):
                offset, info, addend = struct.unpack_from("<IIi", data, at)
                target.append((offset, info & 255, entries[info >> 8][0], addend))
    return symbols, relocs


def global_symbols(path):
    data, headers, _, string = read(path)
    table = next(h for h in headers if h[1] == SHT_SYMTAB)
    found = {}
    for at in range(table[4], table[4] + table[5], 16):
        st_name, value, _, info, _, index = struct.unpack_from("<IIIBBH", data, at)
        label = string(table[6], st_name)
        if info >> 4 == 1 and index != SHN_UNDEF:
            found[label] = value
    return found


def section_list(obj):
    """(name, size, alignment) of each section of an object file."""
    data, headers, name, _ = read(obj)
    return [(name(h), h[5], h[8]) for h in headers if h[1] in (SHT_PROGBITS, SHT_NOBITS)]
