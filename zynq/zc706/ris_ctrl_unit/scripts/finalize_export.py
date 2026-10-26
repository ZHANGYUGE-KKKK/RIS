#!/usr/bin/env python3
"""Check BIT/XSA agreement and export the exact PS initialization script."""
import hashlib
import json
import sys
import zipfile
from pathlib import Path

root = Path(sys.argv[1]).resolve()
export = root if (root / "ris_ctrl_unit.xsa").is_file() else root / "export"
bit = export / "ris_ctrl_unit.bit"
with zipfile.ZipFile(export / "ris_ctrl_unit.xsa") as archive:
    names = [n for n in archive.namelist() if n.endswith(".bit")]
    if len(names) != 1:
        raise RuntimeError("Expected one bitstream in the XSA")
    embedded = archive.read(names[0])
    original = bit.read_bytes()
    marker = b"\xff\xff\xff\xff\xaa\x99\x55\x66"
    def payload(data):
        start = data.find(marker)
        if start < 0:
            raise RuntimeError("Bitstream synchronization marker missing")
        return data[start:]
    if payload(original) != payload(embedded):
        raise RuntimeError("BIT/XSA configuration payload mismatch")
    bit.write_bytes(embedded)
    (export / "ps7_init.tcl").write_bytes(archive.read("ps7_init.tcl"))

paths = sorted(p for p in export.iterdir() if p.suffix in (".bit", ".xsa", ".elf", ".tcl"))
manifest = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
(export / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("PASS: exact BIT/XSA agreement; PS init and SHA256 manifest exported")
