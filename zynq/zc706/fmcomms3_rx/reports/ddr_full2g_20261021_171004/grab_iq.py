#!/usr/bin/env python3
"""Capture, verify the boundary, and download the same frozen IQ twice."""
import hashlib
import json
from pathlib import Path
import sys
import time

import numpy as np

here = Path(__file__).resolve().parent
sys.path.insert(0, str(here.parent.parent / "host"))
from rx706 import Client, download, validate_capture

size, label = int(sys.argv[1]), sys.argv[2]
def save(name, value):
    (here / name).write_text(json.dumps(value, indent=2) + "\n")
with Client("192.168.1.10", timeout=120) as client:
    before = client.request("STATUS")
    save(f"{label}_before.json", before)
    assert before["state"] == "empty", "Release the previous frozen capture explicitly"
    assert before["max_bytes"] == 2143289344 and before["address_mode"] == "banked-gp0"
    start = time.monotonic()
    client.request(f"CAPTURE {size}")
    while True:
        info = client.request("STATUS")
        if info["state"] != "capturing":
            break
        if time.monotonic() - start > 180:
            raise TimeoutError("Capture did not finish")
        time.sleep(.2)
    save(f"{label}_status.json", info)
    validate_capture(info)
    assert info["bytes"] == size
    debug = client.request("DEBUG")
    save(f"{label}_debug.json", debug)
    print("CAPTURE_READY", json.dumps({key: info[key] for key in
        ["capture_id", "bytes", "completed_packets", "elapsed_us", "debug_bd_issues",
         "debug_changed_dma", "debug_changed_pl", "debug_unstable", "debug_memcpy_diff"]}), flush=True)
interruptions = []
files = []
for attempt in range(1, 3):
    name = here / "captures" / f"rx_full2g_{label}_read{attempt}.bin"
    for retry in range(2):
        try:
            last_progress = [0]
            def progress(done, total, rate, stage):
                if stage == "download" and (done-last_progress[0] >= 64*1048576 or done == total):
                    last_progress[0] = done
                    print(f"READ{attempt} {done}/{total} bytes {rate/1048576:.2f} MiB/s", flush=True)
            with Client("192.168.1.10", timeout=120) as client:
                metadata = download(client, name, resume=retry > 0, progress=False,
                    note="Full 2GiB banked GP0; CONFIG2P4 unchanged; raw I1 Q1 I2 Q2",
                    progress_callback=progress)
            break
        except (OSError, TimeoutError) as error:
            interruptions.append({"read": attempt, "retry": retry, "error": repr(error)})
            save(f"{label}_transport_interruptions.json", interruptions)
            if retry:
                raise
            print("RECONNECT_AND_RESUME", repr(error), flush=True)
            time.sleep(.2)
    digest = hashlib.sha256()
    with name.open("rb") as binary:
        while block := binary.read(1048576):
            digest.update(block)
    raw = np.memmap(name, dtype="<i2", mode="r").reshape(-1, 4)
    bad = [int(np.count_nonzero((raw[:, i] < -2048) | (raw[:, i] > 2047))) for i in range(4)]
    row = {"file": str(name), "bytes": name.stat().st_size, "tuples": len(raw),
           "sha256": digest.hexdigest(), "bad_I1_Q1_I2_Q2": bad,
           "min": [int(raw[:, i].min()) for i in range(4)],
           "max": [int(raw[:, i].max()) for i in range(4)],
           "file_sha_matches": digest.hexdigest() == metadata["sha256"],
           "read_bad": metadata["capture_final"]["debug_read_bad"]}
    files.append(row)
    del raw
    print("FILE_VERIFIED", json.dumps(row), flush=True)
boundary = 0x40000000 - info["data_base"]
cross = []
with Client("192.168.1.10", timeout=120) as client:
    if size > boundary + 8:
        with Path(files[0]["file"]).open("rb") as binary:
            for offset, length in [(boundary-8, 16), (boundary-4096, 8192), (size-8, 8)]:
                data, crc = client.read_chunk(info["capture_id"], offset, length)
                binary.seek(offset)
                same = data == binary.read(length)
                cross.append({"offset": offset, "length": length, "crc32": crc,
                              "match_saved_file": same})
    final = client.request("STATUS")
save(f"{label}_final_status.json", final)
result = {"requested_bytes": size, "label": label, "capture_id": info["capture_id"],
          "files": files, "cross_bank_and_last_tuple": cross,
          "readbacks_identical": len({row["sha256"] for row in files}) == 1,
          "rf_registers_unchanged": info["rf_before"] == info["rf_after"],
          "transport_interruptions": interruptions, "continuity_proven": False}
sampled_ok = (info["debug_phases"] == 7 and debug["phases"] == 7 and bool(debug["probes"]) and
    all(info[key] == 0 for key in ["debug_changed_dma", "debug_changed_pl", "debug_unstable", "debug_memcpy_diff"]) and
    all(len(probe["measurements"]) == 3 and all(len(set(m[:3])) == 1 and not any(m[3:7])
        for m in probe["measurements"]) for probe in debug["probes"]))
result["checks_pass"] = (result["readbacks_identical"] and result["rf_registers_unchanged"] and sampled_ok and
    info["debug_bd_issues"] == 0 and all(row["file_sha_matches"] and not any(row["bad_I1_Q1_I2_Q2"]) and
    not any(row["read_bad"]) and row["bytes"] == size for row in files) and
    all(row["match_saved_file"] for row in cross) and final["capture_id"] == info["capture_id"] and
    not any(final["debug_read_bad"]))
save(f"{label}_result.json", result)
print("CAPTURE_RESULT", json.dumps({key: value for key, value in result.items() if key != "files"}), flush=True)
if not result["checks_pass"]:
    raise SystemExit(1)
