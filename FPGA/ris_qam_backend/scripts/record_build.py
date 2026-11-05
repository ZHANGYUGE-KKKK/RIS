#!/usr/bin/env python3
"""Record provenance only for a completed, source-matching QAM hardware build."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
log = root / "reports/qam/hardware_build.log"
if "\nRIS_QAM_BUILD_PASS\n" not in log.read_text():
    raise SystemExit("hardware build did not pass; no provenance written")
sources = {}
for line in (root / "reports/qam/source_sha256.txt").read_text().splitlines():
    expected, name = line.split("  ", 1)
    if digest(root / name) != expected:
        raise SystemExit(f"source changed since build: {name}")
    sources[name] = expected
artifacts = {name: digest(root / "export_qam" / name)
             for name in ["ris_ctrl_unit.bit", "ris_ctrl_unit.xsa"]}
reports = {str(path.relative_to(root)): digest(path) for path in (root / "reports/qam").glob("*.rpt")}
manifest = {"format": "ris-qam1-hardware-build-v1", "recorded_utc": datetime.now(timezone.utc).isoformat(),
            "part": "xc7z045ffg900-2", "timing_and_drc_passed": True,
            "requires_qam_firmware": True, "programmed_to_board": False,
            "sources_sha256": sources, "artifacts_sha256": artifacts, "reports_sha256": reports}
(root / "export_qam/build_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("RIS_QAM_PROVENANCE_PASS")
