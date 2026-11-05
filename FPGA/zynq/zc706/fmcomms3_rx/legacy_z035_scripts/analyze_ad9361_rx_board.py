#!/usr/bin/env python3
"""Decode XSDB dumps produced by run_ad9361_rx_board.tcl."""
import argparse
import hashlib
import json
import struct
from pathlib import Path

HEADER = "magic done result pn_enabled completed_windows requested_windows interval_us timer_hz elapsed_us sample_hz_min sample_hz_max clock_hz_min clock_hz_max frame_hz_min frame_hz_max worst_ratio_error worst_frame_sample_error no_progress_windows unlocked_windows rate_error_windows pn_error_windows pn_ch0 pn_ch1 pn_ch2 pn_ch3 frame_fault_total unlocked_cycle_total delay_not_ready_total".split()
WINDOW = "ticks_low ticks_high samples clocks frame_rises frame_faults unlocked_cycles delay_bad pair00 pair01 pair10 pair11 sample_hz clock_hz frame_hz ratio_error frame_sample_error interface_status ch0 ch1 ch2 ch3".split()


def words(path):
    data = path.read_bytes()
    return list(struct.unpack(f"<{len(data)//4}I", data))


def signed(value):
    return value if value < 0x80000000 else value - 0x100000000


def monitor(path):
    data = words(path)
    if len(data) != len(HEADER) + 50 * len(WINDOW):
        raise ValueError(f"Unexpected monitor size: {path}: {len(data)} words")
    result = dict(zip(HEADER, data))
    result["result"] = signed(result["result"])
    result["windows"] = [dict(zip(WINDOW, data[n:n+len(WINDOW)]))
                         for n in range(len(HEADER), len(data), len(WINDOW))]
    result["frame_pair_totals"] = [sum(w[f"pair{pair}"] for w in result["windows"])
                                   for pair in ("00", "01", "10", "11")]
    result["total_samples"] = sum(w["samples"] for w in result["windows"])
    result["total_clocks"] = sum(w["clocks"] for w in result["windows"])
    result["total_frame_rises"] = sum(w["frame_rises"] for w in result["windows"])
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    args = parser.parse_args()
    result = {name: monitor(args.report / f"{name}.bin") for name in
              ("rx_baseline_report", "rx_pn_stability_report", "rx_restored_report")}
    raw = words(args.report / "official_rx_report.bin")
    prefix = "magic done result restore_status core_version tested_points pass_count saved_port saved_delay saved_bist saved_mask saved_observe selected_port selected_delay selected_data_taps selected_frame_taps ch0 ch1 ch2 ch3 sample_delta edge_delta".split()
    pn = dict(zip(prefix, raw))
    pn["result"] = signed(pn["result"])
    pn["restore_status"] = signed(pn["restore_status"])
    offset = len(prefix)
    for field, count in (("fpga_pass", 32), ("lane_pass", 7), ("selected_lane", 7),
                         ("saved_lane", 7), ("stage", 1), ("protected_registers", 8),
                         ("protected_before", 8), ("protected_after", 8),
                         ("protected_mismatch_mask", 1), ("pn_channel_failed_trials", 4)):
        pn[field] = raw[offset] if count == 1 else raw[offset:offset+count]
        offset += count
    if offset != len(raw):
        raise ValueError(f"Unexpected PN report size: {len(raw)} instead of {offset}")
    result["pn_scan"] = pn
    manifest = args.report / "immutable_rf_sources_before.json"
    if manifest.exists():
        repository = Path(__file__).resolve().parents[3]
        changed = [name for name, digest in json.loads(manifest.read_text()).items()
                   if hashlib.sha256((repository / name).read_bytes()).hexdigest() != digest]
        result["changed_rf_sources"] = changed
    (args.report / "board_results.json").write_text(json.dumps(result, indent=2) + "\n")
    for name, item in result.items():
        if isinstance(item, dict):
            print(name, json.dumps({key: value for key, value in item.items()
                                   if key != "windows"}, separators=(",", ":")))
        else:
            print(name, item)


if __name__ == "__main__":
    main()
