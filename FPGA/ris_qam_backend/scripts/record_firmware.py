#!/usr/bin/env python3
"""Record a completed build only when its copied sources and ELF still match."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
if "\nRIS_NETWORK_APPLICATION_BUILD_PASS\n" not in (root / "reports/firmware/build.log").read_text():
    raise SystemExit("firmware build did not pass")
workspace = root / "vitis_qam/ris_qam_network"
sources = {}
for path in sorted((root / "software").rglob("*")):
    if path.suffix not in (".c", ".h", ".inc"):
        continue
    expected = sha(path)
    if sha(workspace / "src" / path.name) != expected:
        raise SystemExit(f"source changed since build: {path}")
    sources[str(path.relative_to(root))] = expected
export = root / "export_qam"
if sha(export / "ris_all_io.elf") != sha(workspace / "Debug/ris_qam_network.elf"):
    raise SystemExit("exported ELF does not match the application build")
artifacts = json.loads((export / "manifest.json").read_text())
for name, expected in artifacts.items():
    if sha(export / name) != expected:
        raise SystemExit(f"export artifact changed: {name}")
manifest = {
    "format": "ris-qam1-network-firmware-v1",
    "recorded_utc": datetime.now(timezone.utc).isoformat(),
    "application": "ris_qam_network", "processor": "ps7_cortexa9_0",
    "defines": ["RIS_ENABLE_NETWORK", "RIS_FAST_TOGGLE", "RIS_MT_TABLE", "RIS_QAM_TABLE"],
    "lwip211_version": "1.8", "tcp_address": "192.168.1.11:7060",
    "protocol": "RIS706 v1 + QAM ABI 1", "programmed_to_board": False,
    "sources_sha256": sources, "artifacts_sha256": artifacts,
    "build_scripts_sha256": {str(p.relative_to(root)): sha(p) for p in
                              (root / "scripts").iterdir() if p.name in
                              ("build_firmware.sh", "build_network_application.tcl", "finalize_export.py", "record_firmware.py")},
}
(export / "firmware_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("RIS_QAM_FIRMWARE_PROVENANCE_PASS")
