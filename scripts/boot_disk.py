"""The boot volume and the native segment file, within 1 MB host RAM.

A ProDOS volume: boot0 (bootloader/) loads SS1943.SYSTEM, which reads
SS1943.DATA and SS1943.CONFIG with bootloader/prodos_read.s.
"""

from toolchain import cc65
import hashlib, json, subprocess, sys
from startup_pack import pack, unpack
from arcade import ROOT
from machine_gate import check

sys.path.insert(0, str(ROOT / "bootloader"))
from prodos_volume import Volume, apm, boot_block


PLANE = 0x200000


def boot_uploads(data):
    """Keep the firmware's text image and renderer until the final handoff.

    UploadData uses the current VGA CPU write path. Text characters/attributes and
    the 256 32-byte font cells occupy the first 32 KB of physical VRAM.
    The firmware still executes its $6000-$CFFF renderer and reads $0400 text.
    Preserve order within each class, including later patches to earlier data.
    A record at 0x200000 + plane * 0x40000 + group writes one VGA plane.
    """

    def linear(address, size):
        """The linear video RAM bytes that a record writes."""
        if address < PLANE:
            return range(address, address + size)
        plane, group = (address - PLANE) >> 18, address & 0x3FFFF
        return range(group * 4 + plane, (group + size) * 4 + plane, 4)

    early = []
    code = []
    video = []
    p = 0
    # The reordered transfer must leave every destination byte unchanged,
    # including overlapping initialization records. This is a build check.
    expected = bytearray(0x120000)
    written = bytearray(0x120000)
    while p < len(data):
        address = int.from_bytes(data[p : p + 3], "little")
        size = int.from_bytes(data[p + 3 : p + 6], "little")
        p += 6
        if not size:
            break
        raw = data[p : p + size]
        p += size
        assert len(raw) == size
        if address >= PLANE:
            where = linear(address, size)
            assert where.stop <= 0x100000 + 3, hex(address)
            expected[where.start : where.stop : 4] = raw
            written[where.start : where.stop : 4] = b"\1" * size
            (video if where.start < 0x8000 else early).append((address, raw))
            continue
        assert address + size <= len(expected)
        expected[address : address + size] = raw
        written[address : address + size] = b"\1" * size
        # Split only at protected boundaries; every original byte is sent.
        boundaries = (
            [address]
            + [v for v in (0x8000, 0x100000, 0x110000) if address < v < address + size]
            + [address + size]
        )
        for lo, hi in zip(boundaries, boundaries[1:]):
            target = video if lo < 0x8000 else code if 0x100000 <= lo < 0x110000 else early
            target.append((lo, raw[lo - address : hi - address]))
    result = bytearray()
    actual = bytearray(len(expected))
    actual_written = bytearray(len(expected))
    # VGA text scanout and unchained CPU writes are independent. Each source
    # plane is prepared here, so the loader never shuffles image bytes.
    for records, flag in ((early, 0), (code, 0x80), (video, 0x40)):
        first = True
        for address, raw in records:
            jobs = []
            if address >= PLANE:
                jobs.append((address & 0x3FFFF, raw, 1 << ((address - PLANE) >> 18)))
            elif address < 0x100000:
                for lane in range(4):
                    offset = (lane - address) & 3
                    part = raw[offset::4]
                    if part:
                        jobs.append(((address + offset) // 4, part, 1 << lane))
            else:
                jobs.append((address, raw, 15))
            for target, part, mask in jobs:
                for off in range(0, len(part), 4096):
                    raw_part = part[off : off + 4096]
                    encoded = pack(raw_part)
                    control = flag if first else 0
                    first = False
                    if len(encoded) + 2 < len(raw_part):
                        assert unpack(encoded) == raw_part
                        control |= 0x20
                        payload = encoded
                    else:
                        payload = raw_part
                    result += (
                        (target + off).to_bytes(3, "little")
                        + len(raw_part).to_bytes(3, "little")
                        + bytes((control, mask))
                        + len(payload).to_bytes(2, "little")
                        + payload
                    )
            where = linear(address, len(raw))
            actual[where.start : where.stop : where.step] = raw
            actual_written[where.start : where.stop : where.step] = b"\1" * len(raw)
    assert actual == expected and actual_written == written, "Boot upload order changed card memory"
    return bytes(result) + bytes(10), dict(
        early_bytes=sum(len(d) for _, d in early),
        handoff_sram_bytes=sum(len(d) for _, d in code),
        handoff_vram_bytes=sum(len(d) for _, d in video),
    )


def build(case, out=None):
    check("build")
    out = out or ROOT / "build/boot"
    out.mkdir(parents=True, exist_ok=True)
    relocated = (case / "low-world.bin").exists()
    regions = [
        (0x20000, "payload.bin"),
        (0x10000, "gameplay.bin"),
        (0x19000, "low-world.bin"),
        (0x1C000, "gameflow.bin"),
        (0x2000, "native.bin"),
        (0x6000, "host-boot.bin"),
        (0xE02000, "video-e0.bin"),
        (0xE12000, "video-e1.bin"),
    ]
    if (case / "boot-lc-world.bin").exists():
        regions.append((0x00B000, "boot-lc-world.bin"))
    if (case / "boot-a-world.bin").exists():
        regions.append((0x009400, "boot-a-world.bin"))
    blobs = [
        (address, (case / name).read_bytes(), name)
        for address, name in regions
        if (case / name).exists()
    ]
    assert len(blobs) <= 10
    for address, data, name in blobs:
        assert (
            address + len(data) <= 0x100000
            or address in (0xE02000, 0xE12000)
            and len(data) <= 0xA000
        ), (name, address, len(data))
    for i, (a, d, _) in enumerate(blobs):
        for b, e, _ in blobs[i + 1 :]:
            assert a + len(d) <= b or b + len(e) <= a
    header = bytearray(512)
    header[:8] = b"SS1943\x01\0"
    header[8] = len(blobs)
    startup = (case / "card-startup.bin").read_bytes()
    startup, startup_phases = boot_uploads(startup)
    header[9] = bool(startup)
    for i, (address, data, _) in enumerate(blobs):
        header[10 + i * 6 : 16 + i * 6] = address.to_bytes(3, "little") + len(data).to_bytes(
            3, "little"
        )
    disk = Volume("SS1943", 8192, boot_block(cc65("ca65"), cc65("ld65"), out / "boot0"))
    labels = {
        t[2].lstrip("."): int(t[1], 16)
        for line in (case / "host.lbl").read_text().splitlines()
        if len(t := line.split()) == 3
    }
    has_lc = (case / "boot-lc-world.bin").exists()
    assert has_lc == (case / "boot-a-world.bin").exists(), "incomplete staged world layout"
    has_c = (case / "boot-c-world.bin").exists()
    has_d = (case / "boot-d-world.bin").exists()
    assert not has_d or has_c
    assert not has_c or has_lc, "bank-zero language-card data needs a handoff"
    if has_lc:
        assert 0x6000 <= labels.get("production_handoff", 0) < 0x6200, (
            "missing staged-world handoff"
        )
    setting_addr = labels["settings"]
    source = next((a, d) for a, d, _ in blobs if a <= setting_addr < a + len(d))
    config = bytearray(source[1][setting_addr - source[0] : setting_addr - source[0] + 512])
    assert len(config) == 512
    checksum = 0x1943
    for offset in range(0, 510, 2):
        checksum = ((checksum << 1) | (checksum >> 15)) & 65535
        checksum ^= int.from_bytes(config[offset : offset + 2], "little")
    config[510:512] = checksum.to_bytes(2, "little")
    config_file = disk.install("SS1943.CONFIG", config, 6)
    (out / "boot_settings.inc").write_text(
        "\n".join(
            f"{name} = ${value:06x}"
            for name, value in {
                "INPUT_SETTINGS": setting_addr,
                "INPUT_SAVE_DRIVER": labels["input_save_driver"],
                "INPUT_SAVE_UNIT": labels["input_save_unit"],
                "INPUT_SAVE_BLOCK": labels["input_save_block"],
                "INPUT_SAVE_SP_ENTRY": labels["input_save_sp_entry"],
                "INPUT_SAVE_SP_UNIT": labels["input_save_sp_unit"],
                "BOOT_LC_WORLD": int((case / "boot-lc-world.bin").exists()),
                "GAME_HANDOFF": labels.get("production_handoff", 0),
                "BOOT_C_WORLD": int(has_c),
                "BOOT_D_WORLD": int(has_d),
                "BOOT_D_STAGE": 0x1800,
            }.items()
        )
        + "\n"
    )
    trailer = (case / "boot-c-world.bin").read_bytes()
    if has_c:
        assert len(trailer) == 4096 and startup, "bank-zero world trailer needs startup stream"
    dtrailer = (case / "boot-d-world.bin").read_bytes()
    if has_d:
        assert len(dtrailer) == 0x2B00
    bundle = bytes(header) + b"".join(data for _, data, _ in blobs) + startup + dtrailer + trailer
    (out / "SS1943.DATA").write_bytes(bundle)
    (out / "boot_progress.inc").write_text(
        "progress_thresholds:\n"
        + "".join(f"  .dword {(len(bundle) * n + 35) // 36}\n" for n in range(1, 37))
    )
    cfg = out / "boot.cfg"
    cfg.write_text(
        "MEMORY { B:start=$2000,size=$100,file=%O,fill=yes; L:start=$A000,size=$1000,file=%O; }\nSEGMENTS { BOOT:load=B,type=ro; LOADER:load=L,type=rw; }\n"
    )
    subprocess.run(
        [
            cc65("ca65"),
            "-I",
            str(out),
            "-I",
            str(ROOT / "bootloader"),
            "-o",
            str(out / "boot.o"),
            str(ROOT / "src/boot.s"),
        ],
        check=True,
    )
    subprocess.run(
        [
            cc65("ld65"),
            "-C",
            str(cfg),
            "-Ln",
            str(out / "boot.lbl"),
            "-o",
            str(out / "SS1943.SYSTEM"),
            str(out / "boot.o"),
        ],
        check=True,
    )
    files = [
        config_file,
        disk.install("SS1943.SYSTEM", (out / "SS1943.SYSTEM").read_bytes(), 0xFF, 0x2000),
        disk.install("SS1943.DATA", bundle, 6),
    ]
    disk.boot("SS1943.SYSTEM")
    image = out / "1943.hdv"
    image.write_bytes(disk.data)
    scsi = out / "1943-scsi.hda"
    scsi.write_bytes(apm(bytes(disk.data), "SS1943"))
    result = dict(
        startup_phases=startup_phases,
        image=str(image),
        image_sha256=hashlib.sha256(disk.data).hexdigest(),
        scsi_image=str(scsi),
        files=files,
        segments=[
            dict(address=a, bytes=len(d), name=n, sha256=hashlib.sha256(d).hexdigest())
            for a, d, n in blobs
        ],
        highest_host_address=max(a + len(d) for a, d, _ in blobs if a < 0x100000),
        video_bank_bytes=sum(len(d) for a, d, _ in blobs if a >= 0xE00000),
        bank0_world_trailer=dict(
            address=0x00C000, bytes=len(trailer), sha256=hashlib.sha256(trailer).hexdigest()
        ),
        bank0_d_world_trailer=dict(
            address=0x00D000,
            bytes=len(dtrailer),
            sha256=hashlib.sha256(dtrailer).hexdigest(),
            staging_scratch=0x1800,
        ),
        scope="Boot packaging and ProDOS file round-trip",
    )
    (out / "manifest.json").write_text(json.dumps(result, indent=2) + "\n")
    return result
