#!/usr/bin/env python3
"""Board integration check; changes outputs and finishes all LOW.

Measures the FPGA's internal edge counter against PC elapsed time; this is not
an oscilloscope measurement of the 595 outputs or RIS voltage.
"""
import argparse
import json
from pathlib import Path
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "host"))
from ris_client import RisClient


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="192.168.1.11")
    parser.add_argument("--port", type=int, default=7060)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    result = {"measurement": "internal FPGA edge counter; physical output unmeasured", "presets": []}
    with RisClient(args.host, args.port) as client:
        def checked(command):
            reply = client.command(command)
            assert reply["ok"] and reply["errors"] == 0, (command, reply)
            return reply

        def sample():
            start = time.perf_counter()
            reply = checked("STATUS")
            return (start + time.perf_counter()) / 2, reply

        result["initial"] = checked("STATUS")
        assert result["initial"].get("fast_supported")
        try:
            for mhz in (1, 3, 5):
                reply = checked(f"FAST {mhz}")
                assert reply["fast_mhz"] == mhz and reply["oe"] and not reply["blink_ms"]
                t0, r0 = sample()
                time.sleep(.5)
                t1, r1 = sample()
                delta = (r1["fast_edges"] - r0["fast_edges"]) & 0xffffffff
                estimated_hz = delta / (2 * (t1 - t0))
                assert abs(estimated_hz / (mhz * 1e6) - 1) < .01, estimated_hz
                stopped = checked("STOP")
                assert stopped["fast_mhz"] == 0 and stopped["oe"]
                assert stopped["image"] in ("00" * 50, "FF" * 50)
                time.sleep(.03)
                held = checked("STATUS")
                assert held["fast_edges"] == stopped["fast_edges"] and held["image"] == stopped["image"]
                item = {"preset_mhz": mhz, "elapsed_s": t1 - t0, "edges": delta,
                        "internal_estimate_hz": estimated_hz, "stop_hold_passed": True}
                result["presets"].append(item)
                print(f"PASS {mhz} MHz: internal counter estimate {estimated_hz:.1f} Hz; STOP holds", flush=True)
            checked("FAST 5")
            invalid = client.command("FAST 2")
            assert not invalid["ok"] and invalid["rc"] == -7 and invalid["fast_mhz"] == 5
            reply = checked("BIT 0 0 1")
            image = bytes.fromhex(reply["image"])
            assert not reply["fast_mhz"] and image[1:] in (bytes(49), b"\xff" * 49)
            assert image[0] == (image[1] | 1)
            result["invalid_preset_preserves_mode"] = True
            result["manual_takeover_preserves_other_bits"] = True
        finally:
            result["final"] = checked("ALL 0")
            assert not result["final"]["fast_mhz"] and result["final"]["image"] == "00" * 50 and result["final"]["oe"]
    if args.report:
        args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print("RIS_FAST_BOARD_PASS; final all400 LOW, OE enabled; physical voltage unmeasured")


if __name__ == "__main__":
    main()
