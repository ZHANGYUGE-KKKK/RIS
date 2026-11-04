#!/usr/bin/env python3
"""Read-only integrity check before manually downloading a QAM1 package."""
import hashlib
import json
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
export = root / "export_qam"
sha = lambda data: hashlib.sha256(data).hexdigest()
for filename in ("build_manifest.json", "firmware_manifest.json"):
    manifest = json.loads((export / filename).read_text())
    for name, expected in manifest["sources_sha256"].items():
        if sha((root / name).read_bytes()) != expected:
            raise SystemExit(f"Rebuild required: {name}")
    for name, expected in manifest["artifacts_sha256"].items():
        if sha((export / name).read_bytes()) != expected:
            raise SystemExit(f"Artifact mismatch: {filename}: {name}")
if (root / "software/ris_qam_regs.h").read_bytes() != (root / "include/ris_qam_regs.h").read_bytes():
    raise SystemExit("Firmware and RTL register headers differ")
with zipfile.ZipFile(export / "ris_ctrl_unit.xsa") as archive:
    names = [name for name in archive.namelist() if name.endswith(".bit")]
    if len(names) != 1 or archive.read(names[0]) != (export / "ris_ctrl_unit.bit").read_bytes():
        raise SystemExit("BIT/XSA mismatch")
    if archive.read("ps7_init.tcl") != (export / "ps7_init.tcl").read_bytes():
        raise SystemExit("PS initialization/XSA mismatch")
print("RIS_QAM_PACKAGE_VERIFY_PASS: source, BIT/XSA/ELF/PS-init and headers match; no hardware accessed")
