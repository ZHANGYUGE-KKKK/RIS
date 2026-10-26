#!/usr/bin/env python3
"""Analyze the rewritten AD9361 RX's 49-bit raw observation probe in ILA CSVs.

Only valid records carry a new RX-clock observation. The split 22-bit cycle
tag, not the ILA row number, is the timebase for all cadence checks. Results
are in RX clock cycles / DDR halfwords; this script does not infer frequency
in Hz from a synchronized AXIS probe or an unspecified ILA sample clock.
"""

import argparse
import csv
import json
import re
from collections import Counter
from pathlib import Path


TAG_MODULUS = 1 << 22
TAG_MASK = TAG_MODULUS - 1


def integer(text, radix="HEX"):
    text = text.strip().replace("_", "")
    if not text or re.search(r"[xz?]", text, re.I):
        # 0x is a numeric prefix, not an unknown logic digit.
        if not re.fullmatch(r"0x[0-9a-f]+", text, re.I):
            raise ValueError(f"unknown/non-numeric probe value {text!r}")
    match = re.fullmatch(r"(?:\d+)?'([hbd])([0-9a-f]+)", text, re.I)
    if match:
        return int(match[2], {"h": 16, "b": 2, "d": 10}[match[1].lower()])
    if text.lower().startswith(("0x", "0b")):
        return int(text, 0)
    base = {"HEX": 16, "BINARY": 2, "BIN": 2, "UNSIGNED": 10,
            "SIGNED": 10, "DECIMAL": 10, "DEC": 10}.get(radix.upper())
    if base is None:
        raise ValueError(f"unsupported CSV radix {radix!r}")
    return int(text, base)


def choose_column(header, requested):
    if requested is not None:
        if requested.isdecimal():
            index = int(requested)
            if 0 <= index < len(header):
                return index
        candidates = [i for i, name in enumerate(header)
                      if name == requested or requested in name]
    else:
        candidates = [i for i, name in enumerate(header) if "debug_raw_rx" in name]
        if not candidates:
            candidates = [i for i, name in enumerate(header)
                          if re.search(r"(?:^|[/_.])probe4(?:\[48:0\])?$", name, re.I)]
        if not candidates:
            candidates = [i for i, name in enumerate(header) if name.endswith("[48:0]")]
    if len(candidates) != 1:
        raise ValueError("cannot uniquely identify raw probe; use --column with its "
                         f"name or zero-based CSV column index; columns={header!r}")
    return candidates[0]


def load_records(path, requested_column=None):
    with path.open(newline="", encoding="utf-8-sig") as stream:
        rows = list(csv.reader(stream))
    header_at = next((n for n, row in enumerate(rows)
                      if any("Sample in Buffer" in value for value in row)), None)
    if header_at is None:
        header_at = next((n for n, row in enumerate(rows)
                          if any("debug_raw_rx" in value or "probe4" in value
                                 for value in row)), None)
    if header_at is None:
        raise ValueError(f"{path}: no ILA CSV header")
    header = [value.strip() for value in rows[header_at]]
    column = choose_column(header, requested_column)
    sample_column = next((n for n, name in enumerate(header)
                          if name == "Sample in Buffer"), None)
    radix = "HEX"
    records, unknowns = [], []
    data_rows = invalid_rows = 0
    for line_index, row in enumerate(rows[header_at + 1:], header_at + 2):
        if not row or not any(value.strip() for value in row):
            continue
        if row[0].strip().lower().startswith("radix"):
            if column < len(row):
                radix = row[column].split("-", 1)[-1].strip()
            continue
        if len(row) != len(header):
            raise ValueError(f"{path}:{line_index}: {len(row)} fields, expected {len(header)}")
        data_rows += 1
        try:
            value = integer(row[column], radix)
            if value < 0 or value >= (1 << 49):
                raise ValueError("raw probe value is outside 49 bits")
        except ValueError as error:
            unknowns.append({"line": line_index, "value": row[column], "error": str(error)})
            continue
        if not (value >> 48) & 1:
            invalid_rows += 1
            continue
        sample = integer(row[sample_column], "UNSIGNED") if sample_column is not None else data_rows - 1
        records.append({
            "csv_line": line_index, "ila_sample": sample,
            "tag": (((value >> 26) & 63) << 16) | ((value >> 32) & 0xffff),
            "ready": (value >> 25) & 1, "fault": (value >> 24) & 1,
            "sample_valid": (value >> 23) & 1, "locked": (value >> 22) & 1,
            "history": (value >> 14) & 255,
            "early_frame": (value >> 13) & 1, "early_data": (value >> 7) & 63,
            "late_frame": (value >> 6) & 1, "late_data": value & 63,
        })
    metadata = {"path": str(path), "raw_column": header[column], "radix": radix,
                "ila_rows": data_rows, "invalid_observation_rows": invalid_rows,
                "unknown_rows": unknowns, "valid_records": len(records)}
    return records, metadata


def histogram(values):
    return dict(sorted(Counter(values).items()))


def analyze(records, metadata):
    result = dict(metadata)
    result["timebase"] = "22-bit RX cycle tag; periods in RX cycles or DDR halfwords, not Hz"
    segments, discontinuities = [], []
    wraps = low16_wraps = missing = duplicates = backwards = 0
    for record in records:
        if not segments:
            segments.append([record])
            continue
        previous = segments[-1][-1]
        delta = (record["tag"] - previous["tag"]) & TAG_MASK
        if delta == 1:
            if record["tag"] < previous["tag"]:
                wraps += 1
            if (record["tag"] & 0xffff) < (previous["tag"] & 0xffff):
                low16_wraps += 1
            segments[-1].append(record)
        else:
            kind = "duplicate" if delta == 0 else "gap" if delta < TAG_MODULUS//2 else "backwards_or_reset"
            duplicates += kind == "duplicate"
            backwards += kind == "backwards_or_reset"
            if kind == "gap":
                missing += delta - 1
            discontinuities.append({"previous_tag": previous["tag"], "tag": record["tag"],
                                    "delta_mod_22bit": delta, "kind": kind,
                                    "ila_sample": record["ila_sample"]})
            segments.append([record])
    result["sequence"] = {
        "continuous": bool(records) and not discontinuities,
        "segments": len(segments), "segment_lengths": [len(segment) for segment in segments],
        "tag_wraps": wraps, "low16_wraps": low16_wraps,
        "missing_records": missing, "duplicate_records": duplicates,
        "backwards_or_reset": backwards, "discontinuities": discontinuities,
    }

    sample_intervals, tuple_periods, rise_periods = [], [], []
    run_lengths = {0: [], 1: []}
    bad_runs, phase, tuple_phase, sample_phase = [], [], [], []
    truncated_runs, rises, tuple_count, history_checks = 0, 0, 0, 0
    history_errors, faults, lock_changes = [], [], []
    for segment_index, segment in enumerate(segments):
        frames = [record[edge + "_frame"] for record in segment for edge in ("early", "late")]
        previous_sample = None
        for index, record in enumerate(segment):
            if record["sample_valid"]:
                sample_phase.append(record["tag"] % 4)
                if previous_sample is not None:
                    sample_intervals.append(index - previous_sample)
                previous_sample = index
            if record["fault"]:
                faults.append({"tag": record["tag"], "ila_sample": record["ila_sample"],
                               "locked": record["locked"], "ready": record["ready"]})
            if index and record["locked"] != segment[index - 1]["locked"]:
                lock_changes.append({"tag": record["tag"], "locked": record["locked"],
                                     "ila_sample": record["ila_sample"]})
            # history is the eight preceding halfwords, before this record's
            # early/late pair. Skip boundaries and unlocked/reset operation.
            if index >= 4 and all(item["ready"] and item["locked"] for item in segment[index - 4:index + 1]):
                expected = 0
                for frame in frames[2*index - 8:2*index]:
                    expected = (expected << 1) | frame
                history_checks += 1
                if record["history"] != expected:
                    history_errors.append({"tag": record["tag"], "expected": expected,
                                           "actual": record["history"], "ila_sample": record["ila_sample"]})
        starts = [0] + [index for index in range(1, len(frames)) if frames[index] != frames[index - 1]]
        for run_index, start in enumerate(starts):
            end = starts[run_index + 1] if run_index + 1 < len(starts) else len(frames)
            # First/last runs can be clipped by the ILA capture or tag gap.
            if run_index == 0 or run_index == len(starts) - 1:
                truncated_runs += 1
                continue
            level, length = frames[start], end - start
            run_lengths[level].append(length)
            if length != 4:
                record = segment[start//2]
                bad_runs.append({"segment": segment_index, "tag": record["tag"],
                                 "edge": "early" if start % 2 == 0 else "late",
                                 "level": level, "halfwords": length})
        previous_rise = previous_tuple = None
        for index in range(1, len(frames)):
            if frames[index - 1] == 0 and frames[index] == 1:
                rises += 1
                record = segment[index//2]
                position = (2*record["tag"] + index % 2) % 8
                phase.append(position)
                if previous_rise is not None:
                    rise_periods.append(index - previous_rise)
                previous_rise = index
                if frames[index:index + 8] == [1, 1, 1, 1, 0, 0, 0, 0]:
                    tuple_count += 1
                    tuple_phase.append(position)
                    if previous_tuple is not None:
                        tuple_periods.append(index - previous_tuple)
                    previous_tuple = index
    result["flags"] = {
        "ready_high": sum(record["ready"] for record in records),
        "ready_low": sum(not record["ready"] for record in records),
        "locked_high": sum(record["locked"] for record in records),
        "locked_low": sum(not record["locked"] for record in records),
        "sample_valid_high": sum(record["sample_valid"] for record in records),
        "fault_high": len(faults), "fault_events": faults, "lock_transitions": lock_changes,
    }
    result["frame"] = {
        "frame_pair_histogram": histogram(f'{r["early_frame"]}{r["late_frame"]}' for r in records),
        "complete_low_run_halfwords": histogram(run_lengths[0]),
        "complete_high_run_halfwords": histogram(run_lengths[1]),
        "boundary_runs_excluded": truncated_runs, "bad_complete_runs": bad_runs,
        "rising_edges": rises, "rise_period_halfwords": histogram(rise_periods),
        "rise_phase_mod8": histogram(phase),
        "complete_11110000_tuples": tuple_count,
        "tuple_period_halfwords": histogram(tuple_periods), "tuple_start_phase_mod8": histogram(tuple_phase),
        "phase_definition": "(2*tag + edge) modulo 8; edge=0 early, edge=1 late",
        "first_halfwords": "".join(str(r[edge + "_frame"]) for r in records[:64] for edge in ("early", "late")),
    }
    result["sample"] = {"interval_rx_cycles": histogram(sample_intervals),
                        "bad_intervals": sum(value != 4 for value in sample_intervals),
                        "phase_tag_mod4": histogram(sample_phase)}
    result["history"] = {"checked": history_checks, "mismatches": history_errors}
    result["physical_data"] = {
        "early_histogram": histogram(record["early_data"] for record in records),
        "late_histogram": histogram(record["late_data"] for record in records),
    }
    # A healthy result needs real coverage, not only absence of errors. It
    # applies to this captured window; it does not prove timing margin/PN.
    result["healthy_captured_window"] = bool(
        records and not metadata["unknown_rows"] and not discontinuities
        and all(record["ready"] and record["locked"] for record in records)
        and not faults and not bad_runs and not history_errors and history_checks > 0
        and tuple_periods and all(period == 8 for period in tuple_periods)
        and rise_periods and all(period == 8 for period in rise_periods)
        and sample_intervals and all(period == 4 for period in sample_intervals))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", nargs="+", type=Path, help="ILA CSV files (shell glob supported)")
    parser.add_argument("--column", help="raw probe name, unique substring, or zero-based column index")
    parser.add_argument("--output", type=Path, help="write combined JSON (otherwise print JSON to stdout)")
    parser.add_argument("--records-dir", type=Path, help="also write decoded valid records as CSVs")
    parser.add_argument("--strict", action="store_true", help="exit 1 if any captured window fails healthy checks")
    args = parser.parse_args()
    results = []
    for path in args.csv:
        records, metadata = load_records(path, args.column)
        result = analyze(records, metadata)
        results.append(result)
        if args.records_dir is not None and records:
            args.records_dir.mkdir(parents=True, exist_ok=True)
            with (args.records_dir / (path.stem + "_raw_records.csv")).open("w", newline="") as stream:
                writer = csv.DictWriter(stream, fieldnames=list(records[0]))
                writer.writeheader()
                writer.writerows(records)
    output = json.dumps({"captures": results}, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output)
        for result in results:
            print(f'{result["path"]}: valid={result["valid_records"]}, '
                  f'healthy={result["healthy_captured_window"]}, '
                  f'tag_gaps={len(result["sequence"]["discontinuities"])}, '
                  f'FRAME_runs_bad={len(result["frame"]["bad_complete_runs"])}, '
                  f'sample_periods={result["sample"]["interval_rx_cycles"]}, '
                  f'faults={result["flags"]["fault_high"]}, '
                  f'phase={result["frame"]["rise_phase_mod8"]}')
    else:
        print(output, end="")
    if args.strict and not all(result["healthy_captured_window"] for result in results):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
