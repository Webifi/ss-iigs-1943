"""Read the user's 1943 ROM files from the project's roms/ folder.

Put the 1943 (US, 1943ua) ROM set into roms/ as it comes: a split set
(1943ua.zip with its parent 1943.zip), a merged 1943.zip or a non-merged
1943ua.zip. Each file is found by its CRC-32 in any zip in that folder and is
checked with SHA-1 before the build uses it. scripts/rom-manifest.json lists
the files. The protection MCU is not used by the port.
"""

import hashlib
import json
import zipfile
import zlib
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROM_DIR = ROOT / "roms"
BASE_SET = "1943ua"


def declarations(name=BASE_SET):
    manifest = json.loads((ROOT / "scripts/rom-manifest.json").read_text())
    if name not in manifest["sets"]:
        raise ValueError(f"Unsupported ROM set: {name}")
    return [dict(record) for record in manifest["sets"][name]]


def _members():
    """CRC-32 -> (zip path, member name) for every file in every zip in roms/."""
    found = {}
    for archive in sorted(ROM_DIR.glob("*.zip")):
        with zipfile.ZipFile(archive) as z:
            for info in z.infolist():
                found.setdefault(f"{info.CRC:08x}", (archive, info.filename))
    return found


@lru_cache(maxsize=4)
def load(name=BASE_SET):
    found = _members()
    regions = {}
    records = []
    missing = []
    for r in declarations(name):
        hit = found.get(r["crc32"])
        if not hit:
            missing.append(r["name"])
            continue
        archive, member = hit
        with zipfile.ZipFile(archive) as z:
            data = z.read(member)
        r.update(
            source_archive=archive.name,
            source_member=member,
            actual_sha1=hashlib.sha1(data).hexdigest(),
            actual_crc32=f"{zlib.crc32(data):08x}",
            actual_size=len(data),
        )
        r["status"] = (
            "verified"
            if (r["actual_size"], r["actual_crc32"], r["actual_sha1"]) == (r["size"], r["crc32"], r["sha1"])
            else "mismatch"
        )
        records.append(r)
        if r["status"] != "verified":
            raise ValueError(
                f"{archive.name}: {member} does not match {r['name']} (size, CRC-32 or SHA-1)"
            )
        target = regions.setdefault(r["region"], bytearray(r["region_size"]))
        target[r["offset"] : r["offset"] + r["size"]] = data
    if missing:
        raise SystemExit(
            f"The 1943 ({name}) ROM files are missing from {ROM_DIR}:\n  "
            + " ".join(missing)
            + f"\nPut the ROM set zip(s) into {ROM_DIR} (see roms/README.md)."
        )
    receipt = dict(
        base_set=name,
        description="US release with no revision designation",
        archives=sorted({r["source_archive"] for r in records if "source_archive" in r}),
        declaration="scripts/rom-manifest.json",
        records=records,
        protection_used_by_native_port=False,
    )
    return {k: bytes(v) for k, v in regions.items()}, receipt
