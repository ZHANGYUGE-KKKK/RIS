#!/usr/bin/env python3
"""Board check of programmable divider/commands, NOT a physical voltage test."""
import json
from pathlib import Path
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "host"))
from ris_client import RisClient
from ris_frequency import active_frequency


def main():
    report = {"scope": "FPGA internal counter only; physical Q/RIS outputs unmeasured", "frequencies": []}
    with RisClient() as client:
        def checked(command):
            r = client.command(command)
            assert r["ok"] and not r["errors"], (command, r)
            return r

        def sample():
            t = time.perf_counter()
            r = checked("STATUS")
            return (t + time.perf_counter()) / 2, r

        report["initial"] = checked("STATUS")
        assert report["initial"].get("fast_variable")
        try:
            for command, ticks in (("FAST 1", 150), ("FAST 3", 50), ("FAST 5", 30),
                                   ("FASTHZ 2400000", 63), ("FASTHZ 125000", 1200),
                                   ("FASTTICKS 120000000", 120000000), ("FASTHZ 1", 150000000)):
                r = checked(command)
                assert r["fast_ticks"] == ticks and r["oe"] and not r["blink_ms"]
                hz = active_frequency(r)
                t0, r0 = sample()
                time.sleep(.5 if hz >= 1000 else 1.2)
                t1, r1 = sample()
                delta = (r1["fast_edges"] - r0["fast_edges"]) & 0xffffffff
                predicted = 2 * hz * (t1 - t0)
                assert abs(delta - predicted) <= max(1.3, predicted * .01), (command, delta, predicted)
                t = time.perf_counter()
                held = checked("STOP")
                latency = time.perf_counter() - t
                assert not held["fast_ticks"] and held["image"] in ("00" * 50, "FF" * 50)
                assert held["oe"] and latency < .25
                time.sleep(.02)
                again = checked("STATUS")
                assert again["fast_edges"] == held["fast_edges"] and again["image"] == held["image"]
                report["frequencies"].append(dict(command=command, half_ticks=ticks, actual_hz=hz,
                    elapsed_s=t1-t0, counter_edges=delta, estimated_hz=delta/(2*(t1-t0)), stop_latency_s=latency))
                print(f"PASS {command}: ticks={ticks}, actual={hz:.9g} Hz, STOP={latency:.4f}s", flush=True)
            checked("FASTTICKS 63")
            for command in ("FASTHZ 0", "FASTHZ 5000001", "FASTHZ -1", "FASTHZ NaN",
                            "FASTTICKS 29", "FASTTICKS 150000001", "FAST 2"):
                rejected = client.command(command)
                assert not rejected["ok"] and rejected["rc"] == -7 and rejected["fast_ticks"] == 63
            report["invalid_commands_preserve_frequency"] = True
            r = checked("BIT 0 0 1")
            image = bytes.fromhex(r["image"])
            assert not r["fast_ticks"] and image[1:] in (bytes(49), b"\xff" * 49)
            assert image[0] == (image[1] | 1)
            report["manual_takeover_preserves_other_bits"] = True
        finally:
            report["final"] = checked("ALL 0")
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("reports/arbitrary_frequency/board_tests.json")
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print("RIS_VARIABLE_FREQUENCY_BOARD_PASS; all400 LOW; external voltage not measured")


if __name__ == "__main__":
    main()
