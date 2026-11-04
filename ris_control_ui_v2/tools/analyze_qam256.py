"""Read-only audit of a ris-qam256-pwm-v1 export; no hardware interface."""
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import statistics
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ris_mapping import RisMapping, source


def audit(directory, mapping_path):
    checks = {}
    for line in (directory / "SHA256SUMS.txt").read_text().splitlines():
        digest, name = line.split(maxsplit=1)
        checks[name] = hashlib.sha256((directory / name).read_bytes()).hexdigest() == digest
    assert len(checks) == 6 and all(checks.values()), checks
    metadata = json.loads((directory / "metadata.json").read_text())
    assert metadata["format"] == "ris-qam256-pwm-v1"
    config = metadata["config"]
    rows, columns, slots = config["rows"], config["cols"], config["slots"]
    directions = len(metadata["directions"])
    units, frame_bytes = rows * columns, (rows * columns + 7) // 8
    assert metadata["shape"] == [directions, 256, slots, units]
    assert metadata["binary_layout"]["frame_bytes"] == frame_bytes
    binary = (directory / "codebook_frames.bin").read_bytes()
    assert len(binary) == directions * 256 * slots * frame_bytes
    def records(name):
        with (directory / name).open(newline="", encoding="utf-8-sig") as stream:
            return list(csv.DictReader(stream))
    symbols = records("symbols.csv")
    assert len(symbols) == 256
    def gray_decode(value):
        result = 0
        while value:
            result ^= value
            value >>= 1
        return result
    for index, symbol in enumerate(symbols):
        assert int(symbol["symbol"]) == index
        assert int(symbol["hex_byte"], 16) == index
        assert int(symbol["I"]) == 2 * gray_decode(index >> 4) - 15
        assert int(symbol["Q"]) == 2 * gray_decode(index & 15) - 15
    elements = records("elements.csv")
    assert len(elements) == units
    for index, element in enumerate(elements):
        row, column = divmod(index, columns)
        assert int(element["unit"]) == index
        assert (int(element["row"]), int(element["col"])) == (row, column)
        assert math.isclose(float(element["x_m"]), (column - (columns - 1) / 2) * config["col_pitch_mm"] / 1000, abs_tol=1e-12)
        assert math.isclose(float(element["y_m"]), (row - (rows - 1) / 2) * config["row_pitch_mm"] / 1000, abs_tol=1e-12)
        assert float(element["z_m"]) == 0
    pulse_rows = records("pulse_parameters.csv")
    assert len(pulse_rows) == directions * 256 * units
    parameters = [[[None] * units for _ in range(256)] for _ in range(directions)]
    for item in pulse_rows:
        direction, symbol, unit = (int(item[key]) for key in ("direction", "symbol", "unit"))
        width, start = int(item["width_slots"]), int(item["start_slot"])
        assert 0 <= direction < directions and 0 <= symbol < 256 and 0 <= unit < units
        assert 0 <= width <= slots and 0 <= start < slots
        assert parameters[direction][symbol][unit] is None
        parameters[direction][symbol][unit] = (width, start)

    mapping = RisMapping.load(mapping_path)
    assert mapping.count() == units
    # The FPC-group audit and wiring examples assume export row0 is the GUI's
    # upper row, col0 is its left column. This does not establish orientation.
    group_masks = [0] * 10
    permutation = []
    for unit in range(units):
        row, column = divmod(unit, columns)
        fpc, channel = mapping.at(row + 1, column + 1)
        output = source(fpc, channel)
        permutation.append(output["chip"] * 8 + output["bit"])
        group_masks[fpc - 1] |= 1 << unit
    assert len(set(permutation)) == units

    all_ones = (1 << units) - 1
    min_gap, min_group_gap = slots, slots
    transition_counts, independent_counts, uniform_frames = [], [], 0
    linear_segment_count, max_gap = 0, 0
    unique_frames = set()
    widths, low_widths, boundary_fragments = [], [], []
    for direction in range(directions):
        for symbol in range(256):
            edges, state = [0] * slots, 0
            period = parameters[direction][symbol]
            assert all(item is not None for item in period)
            independent_counts.append(len(set(period)))
            for unit, (width, start) in enumerate(period):
                bit = 1 << unit
                if width:
                    widths.append(width)
                if width < slots:
                    low_widths.append(slots - width)
                if (-start) % slots < width:
                    state |= bit
                if 0 < width < slots:
                    end = (start + width) % slots
                    edges[start] ^= bit
                    edges[end] ^= bit
                    inside = sorted(q for q in (start, end) if q)
                    if inside:
                        boundary_fragments.extend((inside[0], slots - inside[-1]))
            frames = []
            for slot in range(slots):
                if slot:
                    state ^= edges[slot]
                offset = ((direction * 256 + symbol) * slots + slot) * frame_bytes
                actual = int.from_bytes(binary[offset:offset + frame_bytes], "little")
                assert actual == state, (direction, symbol, slot)
                frames.append(actual)
                unique_frames.add(actual)
                uniform_frames += int(actual in (0, all_ones))
            transitions = [q for q in range(slots) if frames[q] != frames[q - 1]]
            transition_counts.append(len(transitions))
            linear_segment_count += 1 + sum(frames[q] != frames[q - 1] for q in range(1, slots))
            if transitions:
                gaps = [(transitions[(i + 1) % len(transitions)] - q) % slots or slots
                        for i, q in enumerate(transitions)]
                min_gap, max_gap = min(min_gap, min(gaps)), max(max_gap, max(gaps))
            for mask in group_masks:
                changed = [q for q in range(slots) if (frames[q] ^ frames[q - 1]) & mask]
                if changed:
                    min_group_gap = min(min_group_gap, min((changed[(i + 1) % len(changed)] - q) % slots or slots
                                                           for i, q in enumerate(changed)))

    pwm_hz, repeats = config["pwm_mhz"] * 1e6, config["repeats"]
    slot_ns = 1e9 / (pwm_hz * slots)
    examples = []
    for unit in (0, 1, 19, 20, 399):
        physical = permutation[unit]
        examples.append({"unit": unit, "source_byte": unit // 8, "source_bit": unit % 8,
                         "row_if_row0_is_top": unit // columns + 1, "column": unit % columns + 1,
                         "controller_chip_0based": physical // 8, "controller_byte": physical // 8,
                         "controller_bit": physical % 8})
    return {"format": metadata["format"], "sha256_checks": checks,
            "all_binary_frames_match_pulse_csv": True, "gray_mapping_verified": True,
            "geometry_coordinates_verified": True, "directions": config["scan_angles_deg"],
            "units": units, "symbols": 256, "slots_per_period": slots, "repeats": repeats,
            "pwm_hz": pwm_hz, "slot_ns": slot_ns, "symbol_rate_baud": pwm_hz / repeats,
            "gross_bit_rate_bps": 8 * pwm_hz / repeats, "binary_bytes": len(binary),
            "frame_count": len(binary) // frame_bytes, "frame_bytes": frame_bytes,
            "pulse_records": len(pulse_rows), "unique_spatial_frames": len(unique_frames),
            "uniform_all0_or_all1_frames": uniform_frames,
            "distinct_unit_pulses_per_symbol_min": min(independent_counts),
            "distinct_unit_pulses_per_symbol_max": max(independent_counts),
            "quantized_high_slots_min": min(widths), "quantized_high_ns_min": min(widths) * slot_ns,
            "low_ns_min_cyclic_period": min(low_widths) * slot_ns,
            "possible_boundary_fragment_ns_min": min(boundary_fragments) * slot_ns,
            "spatial_transitions_per_period_min": min(transition_counts),
            "spatial_transitions_per_period_max": max(transition_counts),
            "spatial_transitions_per_period_mean": statistics.mean(transition_counts),
            "linear_rle_segments_all_symbols": linear_segment_count,
            "dictionary_frame_bytes": len(unique_frames) * frame_bytes,
            "dictionary_and_rle_uint16_frame_uint16_slots_bytes_excluding_headers": len(unique_frames) * frame_bytes + linear_segment_count * 4,
            "full_array_transition_gap_slots_min": min_gap,
            "full_array_transition_gap_ns_min": min_gap * slot_ns,
            "full_array_transition_gap_slots_max": max_gap,
            "fpc_group_transition_gap_slots_min": min_group_gap,
            "fpc_group_transition_gap_ns_min": min_group_gap * slot_ns,
            "fpc_group_audit_orientation_assumption": "export row0 -> GUI top row; col0 -> GUI left column",
            "existing_uniform_engine_min_update_ns": 100,
            "hypothetical_vector_engine_100ns_limit_hz": min_gap * 1e9 / (100 * slots),
            "hypothetical_vector_engine_exact_slot_ticks_at_limit": 30,
            "p_r_uint8_table_bytes": len(pulse_rows) * 2 if max(widths) <= 255 and slots <= 256 else None,
            "row0_physical_orientation_confirmed": False,
            "wiring_permutation_nonidentity_units_if_row0_top": sum(i != p for i, p in enumerate(permutation)),
            "mapping_examples_row0_top_assumption": examples,
            "source_warnings": metadata["warnings"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--mapping", type=Path, default=Path(__file__).resolve().parents[1] / "mappings/ris_mapping.json")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = audit(args.directory, args.mapping)
    text = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text)
    print(text, end="")


if __name__ == "__main__":
    main()
