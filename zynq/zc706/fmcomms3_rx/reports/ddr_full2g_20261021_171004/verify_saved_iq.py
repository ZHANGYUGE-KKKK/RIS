#!/usr/bin/env python3
"""Offline verification of the already saved full capture; no board connection."""
import hashlib
import json
from pathlib import Path
import zlib

import numpy as np

here = Path(__file__).resolve().parent
path = here / "captures/rx_full2g_full_read1.bin"
metadata = json.loads(path.with_suffix(".bin.json").read_text())
capture = metadata["capture"]
chunk_bytes = capture["chunk_bytes"]
sha = hashlib.sha256()
bad = np.zeros(4, dtype=np.uint64)
lo = np.full(4, 32767, dtype=np.int32)
hi = np.full(4, -32768, dtype=np.int32)
clipped = np.zeros(4, dtype=np.uint64)
crc_failures = []
first_bad = None
chunks = 0
with path.open("rb") as binary:
    while block := binary.read(chunk_bytes):
        sha.update(block)
        crc = f"{zlib.crc32(block) & 0xffffffff:08x}"
        if chunks >= len(metadata["chunk_crc32"]) or crc != metadata["chunk_crc32"][chunks]:
            crc_failures.append(chunks)
        raw = np.frombuffer(block, dtype="<i2").reshape(-1, 4)
        malformed = (raw < -2048) | (raw > 2047)
        if first_bad is None and malformed.any():
            sample, channel = np.argwhere(malformed)[0]
            first_bad = {"file_offset": chunks * chunk_bytes + int(sample) * 8 + int(channel) * 2,
                         "channel": int(channel), "raw": int(raw[sample, channel])}
        bad += malformed.sum(axis=0, dtype=np.uint64)
        clipped += ((raw == -2048) | (raw == 2047)).sum(axis=0, dtype=np.uint64)
        lo = np.minimum(lo, raw.min(axis=0))
        hi = np.maximum(hi, raw.max(axis=0))
        chunks += 1

final = metadata["capture_final"]
result = {"capture_id": capture["capture_id"], "file": str(path), "bytes": path.stat().st_size,
          "tuples": path.stat().st_size // 8, "sha256": sha.hexdigest(),
          "sha256_matches_saved_metadata": sha.hexdigest() == metadata["sha256"],
          "chunk_bytes": chunk_bytes, "checked_chunks": chunks,
          "crc_failure_chunks": crc_failures, "bad_I1_Q1_I2_Q2": bad.tolist(),
          "first_bad": first_bad, "min": lo.tolist(), "max": hi.tolist(),
          "rail_counts_I1_Q1_I2_Q2": clipped.tolist(),
          "rf_registers_unchanged": capture["rf_before"] == capture["rf_after"],
          "continuous_sample_sequence_proven": False,
          "scope": "All saved bytes: format, chunk CRC32, SHA256. Unknown RF IQ cannot certify sample continuity."}
result["checks_pass"] = (metadata["complete"] and result["bytes"] == capture["bytes"] == 2143289344
    and chunks == len(metadata["chunk_crc32"]) == 8176 and not crc_failures and not bad.any()
    and result["sha256_matches_saved_metadata"] and result["rf_registers_unchanged"]
    and final["capture_id"] == capture["capture_id"] and not any(final["debug_read_bad"]))
(here / "full_file_result.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
if not result["checks_pass"]:
    raise SystemExit(1)
