#!/usr/bin/env python3
"""Build a small preamble/QAM fixture for the unchanged QAM1 hardware."""
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
HOST = ROOT.parents[1] / "RIS_CTRL/ris_control_ui_v2"
sys.path.insert(0, str(HOST))
sys.path.insert(0, str(ROOT / "scripts"))
from ris_qam256 import QamCodebook, export_plan
from ris_mapping import RisMapping
from ris_mt import parse_mt
from compile_qam_plan import emit_plan

out = ROOT / "build/preamble_fixture"
out.mkdir(parents=True, exist_ok=True)
target = out / "retimed"
if target.exists():
    shutil.rmtree(target)
rows = parse_mt("\n".join(f"({m},0);" for m in (0, 100, 20, 50, 80, 25, 75, 37.5, 62.5, 50)))
book = QamCodebook.load(ROOT.parents[1] / "QAM_RULES/256QAM/ris_256qam_codebook_0deg.zip")
mapping = RisMapping.load(HOST / "mappings/ris_mapping.json")
path = out / "host_plan.zip"
export_plan(path, book, mapping, 0, "identity", True, 3, True, b"\x3f\xa5", rows)
report = emit_plan(path, target, 60, True)
assert report["L"] == 256 and report["K"] == 1
print(f"PASS prefix fixture: 10 prefix cycles, 2 QAM symbols x K3; {report['events']} stored events")
