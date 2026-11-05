#!/usr/bin/env python3
"""Validate an offline host ZIP and emit QAM1 MMIO writes / simulation memories.

This tool never opens a device. Retiming is an explicit bench operation, not a
claim that the original RF model remains valid at a different PWM frequency.
"""
import argparse
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import struct
import sys
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "RIS_CTRL/ris_control_ui_v2"))
from ris_qam_preamble import Preamble, assemble
from ris_mt import parse_mt
from ris_qam64_timing import clock_events

CLOCK_HZ = 300_000_000
MIN_TICKS = 60


def integer(value, low, high, name):
    if type(value) is not int or not low <= value <= high:
        raise ValueError(f"{name}: expected integer {low}..{high}")
    return value


def compile_plan(path, slot_ticks=None, retime_for_bench=False):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or len(names) > 16:
            raise ValueError("duplicate/extra ZIP entries")
        if sum(entry.file_size for entry in archive.infolist()) > 64 * 1024 * 1024:
            raise ValueError("ZIP exceeds 64 MiB")
        files = {name: archive.read(name) for name in names}
    checks = files.pop("SHA256SUMS.txt").decode("ascii").splitlines()
    hashes = {}
    for line in checks:
        digest, name = line.split("  ", 1)
        if name in hashes:
            raise ValueError("duplicate checksum")
        hashes[name] = digest
    if set(files) != set(hashes) or any(hashlib.sha256(data).hexdigest() != hashes[name]
                                      for name, data in files.items()):
        raise ValueError("package checksum mismatch")
    m = json.loads(files["manifest.json"])
    if m["format"] not in ("ris-qam256-host-plan-v1", "ris-qam64-host-plan-v1") or m["frame_bytes"] != 50:
        raise ValueError("unsupported host plan")
    order = 64 if m["format"] == "ris-qam64-host-plan-v1" else 256
    slots = integer(m["slots_per_period"], 1, 65535, "L")
    repeats = integer(m["repeats_per_symbol"], 1, 1000000, "K")
    if type(m["loop"]) is not bool:
        raise ValueError("loop must be boolean")
    frequency = Fraction(str(m["pwm_hz"]))
    if frequency <= 0:
        raise ValueError("PWM frequency must be positive")
    requested = Fraction(CLOCK_HZ, 1) / (frequency * slots)
    clock_period = 0
    if order == 64 and slot_ticks is None:
        period = Fraction(CLOCK_HZ)/frequency
        if period.denominator != 1 or not 1 <= period <= 65535 or period//slots < 29:
            raise ValueError("64QAM period/edge timing incompatible")
        clock_period = int(period)
        slot_ticks = 1
    if slot_ticks is None:
        if requested.denominator != 1 or not MIN_TICKS <= requested <= 1000000:
            raise ValueError(f"source timing incompatible: {requested} fast ticks/slot; "
                             f"requires an integer >= {MIN_TICKS}. No implicit retiming.")
        slot_ticks = int(requested)
    integer(slot_ticks, 1 if clock_period else MIN_TICKS, 1000000, "slot_ticks")
    retimed = not clock_period and Fraction(slot_ticks) != requested
    if retimed and not retime_for_bench:
        raise ValueError("changed timing requires --retime-for-bench")
    if order == 64 and not clock_period:
        clock_period = integer(slots*slot_ticks,1,65535,"64QAM period ticks")
        slot_ticks = 1
    patterns, event_bytes, payload = (files[name] for name in ("patterns.bin", "events.bin", "payload.bin"))
    if len(patterns) % 50 or len(event_bytes) % 4:
        raise ValueError("truncated dictionary/events")
    nframes = integer(len(patterns) // 50, 1, 2048, "dictionary frames")
    nevents = integer(len(event_bytes) // 4, 1, 32768, "event records")
    integer(len(payload), 1, 4096, "payload bytes")
    if (nframes, nevents, len(payload)) != (m["dictionary_frames"], m["event_records"], m["payload_bytes"]):
        raise ValueError("manifest counts mismatch")
    events = list(struct.unpack(f"<{nevents}I", event_bytes))
    for event in events:
        if event & 65535 >= nframes or event >> 16 == 0:
            raise ValueError("invalid event frame/duration")
    index = json.loads(files["symbol_index.json"])
    if any(value >= order for value in payload):
        raise ValueError("payload symbol exceeds QAM order")
    if len(index) != order:
        raise ValueError("unexpected symbol descriptor count")
    symbols = []
    for symbol, descriptor in enumerate(index):
        if descriptor["symbol"] != symbol:
            raise ValueError("symbol index out of order")
        first = integer(descriptor["first_record"], 0, nevents - 1, "first event")
        count = integer(descriptor["record_count"], 1, nevents - first, "event count")
        if sum(event >> 16 for event in events[first:first + count]) != slots:
            raise ValueError("symbol period does not equal L")
        symbols.append(first | count << 16)
    if order < 256:
        symbols += symbols[:1] * (256-order)
    frames = []
    for offset in range(0, len(patterns), 50):
        frames.extend(struct.unpack("<13I", patterns[offset:offset + 50] + b"\0\0"))
    base_slots, logical_repeats, logical_bytes = slots, repeats, len(payload)
    preamble_cycles, frame_copies = 0, 1
    if "preamble" in m:
        prefix = Preamble.compile(parse_mt(files["preamble_mt.txt"].decode("utf-8")), slots)
        if (m["preamble"].get("cycles") != len(prefix.rows) or m["preamble"].get("width_slots") != list(prefix.widths)
                or m["preamble"].get("repeat_with_each_frame") is not True or m["preamble"].get("delay_zero") is not True):
            raise ValueError("preamble manifest mismatch")
        blocks, group, frame_copies = assemble(patterns, event_bytes, index, payload, repeats, m["loop"], prefix, max_group=65535//clock_period if clock_period else None)
        frames = list(struct.unpack(f"<{len(blocks[0])//4}I", blocks[0]))
        events = list(struct.unpack(f"<{len(blocks[1])//4}I", blocks[1]))
        symbols = list(struct.unpack("<256I", blocks[2]))
        payload = blocks[3]
        slots *= group
        repeats = 1
        nframes, nevents = len(frames)//13, len(events)
        preamble_cycles = len(prefix.rows)
    if clock_period:
        symbols_bytes = struct.pack("<256I", *symbols)
        events_bytes = clock_events(struct.pack(f"<{len(events)}I", *events), symbols_bytes, base_slots, clock_period)
        events = list(struct.unpack(f"<{len(events)}I", events_bytes))
        slots = slots//base_slots * clock_period
    writes = [(0x204, 16), (0x208, slot_ticks), (0x20c, repeats), (0x210, slots)]
    if clock_period: writes.insert(1, (0x250,64))
    for address, data in ((0x240, frames), (0x244, events), (0x248, symbols), (0x24c, payload)):
        writes.extend((address, value) for value in data)
    # No START in upload file. The global GUI apply must own START/STOP later.
    report = {"format": "ris-qam1-mmio-upload-v1", "register_base": "0x41200000",
              "transport_ready": False, "qam_order": order, "edge_tick_mode": bool(clock_period), "source_pwm_hz": float(frequency),
              "actual_pwm_hz": CLOCK_HZ / (clock_period or base_slots * slot_ticks), "slot_ticks": slot_ticks,
              "slot_ns": (clock_period/base_slots if clock_period else slot_ticks) * 1e9 / CLOCK_HZ, "retimed_for_bench": retimed,
              "rf_performance_validated": False, "frames": nframes, "events": nevents,
              "payload_bytes": len(payload), "K": repeats, "L": slots, "loop": m["loop"],
              "start_command": 2 if m["loop"] else 1,
              "mmio_format": "little-endian uint32 register_offset, uint32 value; no START",
              "source_zip_sha256": hashlib.sha256(Path(path).read_bytes()).hexdigest()}
    if clock_period:
        report.update(base_period_ticks=clock_period,base_period_slots=base_slots,event_unit_ns=1e9/CLOCK_HZ,edge_error_bound_ns=1e9/(2*CLOCK_HZ))
    if preamble_cycles:
        report.update(preamble_cycles=preamble_cycles, logical_K=logical_repeats, logical_payload_bytes=logical_bytes,
                      base_period_slots=base_slots, frame_copies_in_program=frame_copies)
    return report, writes, frames, events, symbols, payload


def emit_plan(path, destination, slot_ticks=None, retime_for_bench=False):
    report, writes, frames, events, symbols, payload = compile_plan(path, slot_ticks, retime_for_bench)
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=False)
    (destination / "upload.bin").write_bytes(b"".join(struct.pack("<II", *pair) for pair in writes))
    (destination / "manifest.json").write_text(json.dumps(report, indent=2) + "\n")
    for name, values, digits in (("frames", frames, 8), ("events", events, 8),
                                 ("symbols", symbols, 8), ("payload", payload, 2),
                                 ("dimensions", [report["frames"], report["events"],
                                                  len(payload), report["K"], report["slot_ticks"]], 8)):
        (destination / f"{name}.hex").write_text("".join(f"{value:0{digits}x}\n" for value in values))
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--slot-ticks", type=int)
    parser.add_argument("--retime-for-bench", action="store_true")
    args = parser.parse_args()
    try:
        result = emit_plan(args.plan, args.output, args.slot_ticks, args.retime_for_bench)
    except (ValueError, KeyError, OSError, zipfile.BadZipFile) as error:
        parser.exit(2, f"QAM1: {error}\n")
    print(json.dumps(result, indent=2))
