#!/usr/bin/env python3
"""Create a digital-only, retimed 00..FF fixture using the supplied host codebook.
The existing mapping is used as a deterministic test input, not a physical claim.
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
HOST = ROOT.parents[1] / "RIS_CTRL/ris_control_ui_v2"
sys.path.insert(0, str(HOST))
sys.path.insert(0, str(ROOT / "scripts"))
from ris_qam256 import QamCodebook, export_plan
from ris_mapping import RisMapping
from compile_qam_plan import compile_plan, emit_plan

if __name__ == "__main__":
    out = ROOT / "build" / "codebook_fixture"
    out.mkdir(parents=True, exist_ok=True)
    plan = out / "host_plan.zip"
    book = QamCodebook.load(ROOT.parents[1] / "QAM_RULES/256QAM/ris_256qam_codebook_0deg.zip")
    mapping = RisMapping.load(HOST / "mappings" / "ris_mapping.json")
    export_plan(plan, book, mapping, 0, "identity", True, 1, False, bytes(range(256)))
    try:
        compile_plan(plan)
    except ValueError as error:
        assert "source timing incompatible" in str(error), str(error)
        print(f"PASS native 1 MHz timing rejected: {error}")
    else:
        raise AssertionError("incompatible native codebook accepted")
    destination = out / "retimed"
    if not destination.exists():
        report = emit_plan(plan, destination, 60, True)
    else:
        # Avoid stale fixtures: compare a freshly compiled image before reuse.
        import struct
        report, writes, *_ = compile_plan(plan, 60, True)
        assert (destination / "upload.bin").read_bytes() == b"".join(struct.pack("<II", *w) for w in writes)
    print(f"PASS fixture: {report['frames']} frames, {report['events']} events, "
          f"actual {report['actual_pwm_hz']:.6f} Hz; digital bench only")
