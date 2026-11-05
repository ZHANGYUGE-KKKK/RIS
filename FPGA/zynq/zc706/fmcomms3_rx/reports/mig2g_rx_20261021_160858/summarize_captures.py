#!/usr/bin/env python3
"""Reproduce complete saved-file checks without rearming the receiver."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys
import zlib

import numpy as np

here = Path(__file__).resolve().parent
sys.path.insert(0, str(here.parent.parent / "host"))
from rx706 import validate_capture

for label, attempts in [("8m", 2), ("1s", 3)]:
    status = json.loads((here / f"{label}_status.json").read_text())
    debug = json.loads((here / f"{label}_debug.json").read_text())
    validate_capture(status)
    stats = []
    for attempt in range(1, attempts + 1):
        name = here / "captures" / f"rx_2g_{label}_read{attempt}.bin"
        metadata = json.loads(Path(str(name) + ".json").read_text())
        for snapshot in [metadata["capture"], metadata["capture_final"]]:
            validate_capture(snapshot)
            assert snapshot["capture_id"] == status["capture_id"]
            assert snapshot["bytes"] == status["bytes"]
            assert snapshot["rf_before"] == status["rf_before"] == snapshot["rf_after"]
        digest = hashlib.sha256()
        chunk_crcs = []
        packet_hashes = []
        with name.open("rb") as binary:
            while block := binary.read(262144):
                digest.update(block)
                chunk_crcs.append(f"{zlib.crc32(block) & 0xffffffff:08x}")
                packet_hashes.extend(hashlib.sha256(block[n:n + 32768]).digest()
                                     for n in range(0, len(block), 32768))
        raw = np.memmap(name, dtype="<i2", mode="r").reshape(-1, 4)
        bad = [int(np.count_nonzero((raw[:, i] < -2048) | (raw[:, i] > 2047)))
               for i in range(4)]
        rails = [int(np.count_nonzero(np.any((raw[:, 2 * c:2 * c + 2] <= -2048) |
                                             (raw[:, 2 * c:2 * c + 2] >= 2047), axis=1)))
                 for c in range(2)]
        row = {"file": str(name), "bytes": name.stat().st_size, "tuples": len(raw),
               "sha256": digest.hexdigest(), "bad_I1_Q1_I2_Q2": bad,
               "min": [int(raw[:, i].min()) for i in range(4)],
               "max": [int(raw[:, i].max()) for i in range(4)],
               "rail_tuples_RX1_RX2": rails,
               "duplicate_packet_copies": sum(n - 1 for n in Counter(packet_hashes).values()),
               "adjacent_duplicate_packets": sum(a == b for a, b in zip(packet_hashes, packet_hashes[1:])),
               "stored_file_sha_matches": digest.hexdigest() == metadata["sha256"],
               "stored_chunk_crcs_match": chunk_crcs == metadata["chunk_crc32"],
               "network_read_bad": metadata["capture_final"]["debug_read_bad"]}
        row["checks_pass"] = (row["bytes"] == status["bytes"] and not any(bad) and
                              row["stored_file_sha_matches"] and row["stored_chunk_crcs_match"] and
                              not any(row["network_read_bad"]))
        stats.append(row)
        del raw
    frozen = json.loads((here / f"frozen_{label}_result.json").read_text())
    result = {"requested_bytes": status["bytes"], "capture_id": status["capture_id"],
              "label": label, "status": status, "files": stats,
              "rf_registers_unchanged": status["rf_before"] == status["rf_after"],
              "readbacks_identical": len({row["sha256"] for row in stats}) == 1,
              "bd_ok": status["debug_bd_issues"] == 0,
              "sampled_ddr_ok": status["debug_phases"] == 7 and debug["phases"] == 7 and
                  bool(debug["probes"]) and all(status[k] == 0 for k in
                  ["debug_changed_dma", "debug_changed_pl", "debug_unstable", "debug_memcpy_diff"]) and
                  all(len(p["measurements"]) == 3 and all(len(set(m[:3])) == 1 and
                      not any(m[3:7]) for m in p["measurements"]) for p in debug["probes"]),
              "all_words_valid": all(not any(row["bad_I1_Q1_I2_Q2"]) for row in stats),
              "jtag_frozen": frozen,
              "continuity_proven": False,
              "network_transfer": {"complete_downloads": attempts,
                  "resumed_after_one_timeout": label == "1s",
                  "additional_uninterrupted_transfer": label == "1s"}}
    result["checks_pass"] = (all(row["checks_pass"] for row in stats) and
        all(result[k] for k in ["rf_registers_unchanged", "readbacks_identical", "bd_ok",
                               "sampled_ddr_ok", "all_words_valid"]) and frozen["checks_pass"])
    (here / f"{label}_result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({k: result[k] for k in ["label", "capture_id", "checks_pass",
                     "readbacks_identical", "all_words_valid", "bd_ok", "continuity_proven"]}))
    if not result["checks_pass"]:
        raise SystemExit(1)
