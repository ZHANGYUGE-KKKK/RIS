#!/usr/bin/env python3
"""Validate a routed ZC706 export and use the XSA's exact bitstream bytes."""
import hashlib
import json
import shutil
import sys
import zipfile
from pathlib import Path

root = Path(sys.argv[1])
export = root / "export"
bit = export / "zc706_top.bit"
original = bit.read_bytes()
with zipfile.ZipFile(export / "zc706_top.xsa") as archive:
    names = [name for name in archive.namelist() if name.endswith(".bit")]
    if len(names) != 1:
        raise RuntimeError("Expected exactly one BIT in the XSA")
    embedded = archive.read(names[0])
    marker = b"\xff\xff\xff\xff\xaa\x99\x55\x66"
    def payload(data):
        start = data.find(marker)
        if start < 0:
            raise RuntimeError("Bitstream synchronization marker missing")
        return data[start:]
    if payload(embedded) != payload(original):
        raise RuntimeError("XSA FPGA configuration differs from routed BIT")
shutil.copy2(bit, root / "reports/implementation/zc706_top.pre_xsa.bit")
bit.write_bytes(embedded)
manifest = {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in export.iterdir() if path.suffix in (".bit", ".ltx", ".xsa")}
(export / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("PASS: XSA and BIT configuration payloads and final bytes match")
