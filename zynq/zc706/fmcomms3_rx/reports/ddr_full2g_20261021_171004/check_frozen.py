#!/usr/bin/env python3
"""Independent JTAG readback of a frozen capture through both CPU banks.

Run only after every TCP download client has closed: external bank changes
must not race the firmware's own banked reads.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zlib

here = Path(__file__).resolve().parent
label = sys.argv[1]
status = json.loads((here / f"{label}_status.json").read_text())
debug = json.loads((here / f"{label}_debug.json").read_text())
base, size = status["data_base"], status["bytes"]
folder = here / f"frozen_{label}"
folder.mkdir(exist_ok=True)
offsets = sorted({p["offset"] for p in debug["probes"]} | {0, 32768 - 4096, 32768, size - 4096})
lines = ["connect -url tcp:127.0.0.1:3121", 'targets -set -filter {name == "APU"}',
         "configparams force-mem-access 1", "set result [catch {"]
for trial in range(3):
    for offset in offsets:
        physical = base + offset
        cpu = 0x40000000 + (physical & 0x3fffffff)
        target = folder / f"{physical:08x}_{trial}.bin"
        if target.exists():
            raise FileExistsError(target)
        lines += [f"mwr -force -address-space AP0 0x83000000 {physical >> 30}", "after 1",
            f"mrd -force -address-space AP0 -bin -file {{{target}}} 0x{cpu:08x} 1024"]
lines += ["} message options]", "mwr -force -address-space AP0 0x83000000 0",
          'puts "CPU bank restored [mrd -force -address-space AP0 0x83000000 1]"',
          "configparams force-mem-access 0", "disconnect",
          "if {$result} {return -options $options $message}", "exit"]
script = here / f"frozen_{label}.tcl"
script.write_text("\n".join(lines) + "\n")
with (here / f"frozen_{label}.log").open("w") as log:
    subprocess.run(["/home/yyz/vivado2020.2/main/Vitis/2020.2/bin/xsct", str(script)],
                   stdout=log, stderr=subprocess.STDOUT, check=True, timeout=120)
rows = []
probe_by_offset = {p['offset']: p for p in debug['probes']}
with (here / "captures" / f"rx_full2g_{label}_read1.bin").open("rb") as reference:
    for offset in offsets:
        physical = base + offset
        reference.seek(offset)
        expected = reference.read(4096)
        reads = [(folder / f"{physical:08x}_{trial}.bin").read_bytes() for trial in range(3)]
        crcs = [zlib.crc32(data) & 0xffffffff for data in reads]
        probe = probe_by_offset.get(offset)
        matches_firmware = (all(all(crc == measurement[0] == measurement[1] == measurement[2]
            for measurement in probe['measurements']) for crc in crcs) if probe else None)
        rows.append({"dma_address": physical, "cpu_address": 0x40000000 + (physical & 0x3fffffff),
                     "bank": physical >> 30, "offset": offset,
                     "match_saved_file": [len(data) == 4096 and data == expected for data in reads],
                     "crc32": crcs, "match_firmware_three_phases": matches_firmware,
                     "readbacks_identical": len(set(reads)) == 1,
                     "sha256": hashlib.sha256(expected).hexdigest()})
result = {"capture_id": status["capture_id"], "sampled_only": True,
          "pages": len(rows), "readbacks": len(rows)*3,
          "checks_pass": bool(rows) and all(all(row["match_saved_file"]) and row["readbacks_identical"]
              and row["match_firmware_three_phases"] is not False for row in rows),
          "rows": rows}
(here / f"frozen_{label}_result.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps({key: value for key, value in result.items() if key != "rows"}))
if not result["checks_pass"]:
    raise SystemExit(1)
