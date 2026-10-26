#!/usr/bin/env python3
"""Compare independent JTAG reads with the saved frozen TCP capture."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

here = Path(__file__).resolve().parent
label = sys.argv[1]
status = json.loads((here / f"{label}_status.json").read_text())
debug = json.loads((here / f"{label}_debug.json").read_text())
base, size = status["data_base"], status["bytes"]
offsets = {p["offset"] for p in debug["probes"]}
offsets.update([0, 32768 - 4096, 32768, size - 4096])
offsets.update(a - base for a in [0x404e4000, 0x40580000, 0x41184000,
                               0x425c4000, 0x4792f000] if base <= a <= base + size - 4096)
folder = here / f"frozen_{label}"
folder.mkdir(exist_ok=True)
lines = ["connect -url tcp:127.0.0.1:3121",
         'targets -set -filter {name == "APU"}',
         "configparams force-mem-access 1",
         'puts "DMA frozen regs [mrd -force -address-space AP0 0x81000030 12]"',
         "set result [catch {"]
for offset in sorted(offsets):
    address = base + offset
    for trial in range(3):
        dest = folder / f"{address:08x}_{trial}.bin"
        if dest.exists():
            raise FileExistsError(dest)
        lines += [f"mrd -force -address-space AP0 -bin -file {{{dest}}} 0x{address:08x} 1024",
                  "after 50"]
    lines.append(f'puts "FROZEN {address:08x} saved3reads"')
lines += ["} message options]", "configparams force-mem-access 0", "disconnect",
          "if {$result} {return -options $options $message}", "exit"]
script = here / f"frozen_{label}.tcl"
script.write_text("\n".join(lines) + "\n")
with (here / f"frozen_{label}.log").open("w") as log:
    subprocess.run(["/home/yyz/vivado2020.2/main/Vitis/2020.2/bin/xsct", str(script)],
                   stdout=log, stderr=subprocess.STDOUT, check=True, timeout=120)
rows = []
with (here / "captures" / f"rx_2g_{label}_read1.bin").open("rb") as reference:
    for offset in sorted(offsets):
        reference.seek(offset)
        expected = reference.read(4096)
        reads = [(folder / f"{base+offset:08x}_{trial}.bin").read_bytes()
                 for trial in range(3)]
        rows.append({"address": f"{base+offset:08x}", "offset": offset,
                     "reads": len(reads), "bytes_per_read": 4096,
                     "match_tcp": [data == expected for data in reads],
                     "readbacks_identical": len(set(reads)) == 1,
                     "sha256": hashlib.sha256(expected).hexdigest()})
result = {"capture_id": status["capture_id"], "sampled_only": True,
          "pages": len(rows), "readbacks": len(rows) * 3,
          "checks_pass": bool(rows) and all(all(row["match_tcp"]) and
                                           row["readbacks_identical"] for row in rows),
          "rows": rows}
(here / f"frozen_{label}_result.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps({k: v for k, v in result.items() if k != "rows"}))
if not result["checks_pass"]:
    raise SystemExit(1)
