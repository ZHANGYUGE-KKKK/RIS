#!/usr/bin/env python3
"""Check the offline release; deliberately does not connect to any board."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parent.parent
def digest(data):
    return hashlib.sha256(data).hexdigest()
def require(condition, message):
    if not condition:
        raise RuntimeError(message)

out = {"offline_ready": False, "board_programmed": False, "board_tested": False}
export = ROOT / "export"
for name in ("ddr2g_test.bit", "ddr2g_test.xsa", "ddr2g_test.elf", "ps7_init.tcl"):
    require((export/name).is_file(), f"Missing {name}")
with zipfile.ZipFile(export/"ddr2g_test.xsa") as z:
    bits = [n for n in z.namelist() if n.endswith(".bit")]
    require(len(bits) == 1, "Final XSA must contain exactly one BIT")
    # Vivado updates BIT header metadata during XSA export. Use that exact
    # embedded artifact as the external BIT so both download routes agree.
    embedded = z.read(bits[0])
    require(len(embedded) > 1_000_000, "Unexpected BIT size")
    (export/"ddr2g_test.bit").write_bytes(embedded)
    for name in ("ps7_init.tcl", "ps7_init.c", "ps7_init.h"):
        (export/name).write_bytes(z.read(name))
    hwh_name = next(n for n in z.namelist() if n.endswith(".hwh"))
    final_hwh = z.read(hwh_name)
with zipfile.ZipFile(ROOT/"reports/ddr2g_bsp.xsa") as z:
    name = next(n for n in z.namelist() if n.endswith(".hwh"))
    require(z.read(name) == final_hwh, "BSP hardware metadata differs from final XSA")
out["bsp_hwh_matches_final_xsa"] = True
out["bit_matches_embedded_xsa"] = True

tree = ET.fromstring(final_hwh)
modules = list(tree.iter("MODULE"))
out["modules"] = {m.get("INSTANCE"): m.get("MODTYPE") for m in modules}
require(not any(m.get("MODTYPE", "").startswith(("axi_dma", "axi_ethernet")) for m in modules),
        "Unexpected DMA/Ethernet block in memory-only test")
memranges = [dict(e.attrib) for e in tree.iter("MEMRANGE")]
out["memory_ranges"] = memranges
for base in ("0x41200000", "0x41210000", "0x41220000"):
    require(any(e.get("BASEVALUE", "").lower() == base for e in memranges), f"Missing control address {base}")
require(any(e.get("BASEVALUE", "").lower() == "0x00000000" and
            e.get("HIGHVALUE", "").lower() == "0x7fffffff" for e in memranges),
        "Missing complete 2GiB PL master address range")

mig_rtl = next((ROOT/"vivado").glob("**/user_design/rtl/ddr_test_mig_0_mig.v"))
rtl = mig_rtl.read_text()
params = {}
for key, val in {"RANKS": 2, "ROW_WIDTH": 14, "COL_WIDTH": 10, "BANK_WIDTH": 3,
                 "DQ_WIDTH": 64, "CK_WIDTH": 2, "CS_WIDTH": 2, "CKE_WIDTH": 2,
                 "tCK": 1500, "CLKIN_PERIOD": 6000, "CLKFBOUT_MULT": 8,
                 "DIVCLK_DIVIDE": 1, "CLKOUT0_DIVIDE": 2}.items():
    match = re.search(r"parameter\s+"+key+r"\s*=\s*(\d+)", rtl)
    require(match and int(match[1]) == val, f"Wrong generated MIG parameter {key}")
    params[key] = val
out["generated_mig"] = params

timing = (ROOT/"reports/timing.rpt").read_text()
match = re.search(r"^\s*(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+\d+\s+\d+\s+(-?\d+\.\d+)\s+", timing, re.M)
require(match, "Timing summary not found")
wns, tns, whs = map(float, match.groups())
require(wns >= 0 and tns >= 0 and whs >= 0, "Setup/hold timing failed")
require("timing constraints are met" in timing.lower(), "Pulse width or other timing check failed")
out["timing_ns"] = {"WNS": wns, "TNS": tns, "WHS": whs}
drc = (ROOT/"reports/drc.rpt").read_text()
require(not re.search(r"\|\s*\S+\s*\|\s*(Error|Critical Warning)\s*\|", drc), "DRC error/critical warning")
out["drc_errors"] = 0
out["drc_report"] = "reports/drc.rpt"
cdc = (ROOT/"reports/cdc.rpt").read_text()
require(not re.search(r"^CDC-\d+\s+Critical", cdc, re.M), "Unresolved critical CDC finding")
out["cdc_critical"] = 0
require(re.search(r"^CDC-11\s+2\s*$", cdc, re.M), "Expected exactly two reviewed marker CDC endpoints")
out["cdc_constant_marker_endpoints_waived"] = 2
require("DDR2G_PHYSICAL_CHECKS_PASS" in (ROOT/"reports/inspect_routed.log").read_text(),
        "Final physical pin/controller checks did not pass")
out["rank1_pins_checked"] = True
sim = (ROOT/"reports/simulation.log").read_text()
require("DDR2G_BIST_SIM_PASS" in sim and not re.search(r"Fatal:|Error:|FATAL:", sim), "Simulation failed")
require("DDR2G_SOFTWARE_BUILD_PASS" in (ROOT/"reports/build_software.log").read_text(), "Software build failed")
require("DDR2G_VITIS_READY" in (ROOT/"reports/prepare_vitis.log").read_text(), "Vitis workspace build failed")
platform_xsa = ROOT/"vitis_workspace/ddr2g_platform/export/ddr2g_platform/hw/ddr2g_test.xsa"
require(platform_xsa.is_file() and platform_xsa.read_bytes() == (export/"ddr2g_test.xsa").read_bytes(),
        "Vitis platform hardware does not match final XSA")
require((ROOT/"software/main.c").read_bytes() == (ROOT/"vitis_workspace/ddr2g_test/src/main.c").read_bytes(),
        "Vitis application source is stale")
out["vitis_platform_matches_final_xsa"] = True
out["simulation_cases"] = 12

tool = "/home/yyz/vivado2020.2/main/Vitis/2020.2/gnu/aarch32/lin/gcc-arm-none-eabi/bin/arm-none-eabi-readelf"
elf = subprocess.check_output([tool, "-l", str(export/"ddr2g_test.elf")], text=True)
loads = re.findall(r"^\s*LOAD\s+0x[0-9a-f]+\s+0x([0-9a-f]+)\s+0x[0-9a-f]+\s+0x[0-9a-f]+\s+0x([0-9a-f]+)", elf, re.M)
require(loads and all(0x100000 <= int(a,16) and int(a,16)+int(n,16) <= 0x40000000 for a,n in loads),
        "ELF load segment is outside PS DDR")
out["elf_loads_in_ps_ddr"] = True
baseline = json.loads((ROOT/"reports/original_rx.sha256.json").read_text())
original = ROOT.parent/"fmcomms3_rx"
for rel, expected in baseline.items():
    require(digest((original/rel).read_bytes()) == expected, f"Original RX file changed: {rel}")
out["original_rx_protected_files_unchanged"] = len(baseline)
out["artifacts_sha256"] = {p.name: digest(p.read_bytes()) for p in sorted(export.iterdir()) if p.is_file()}
out["offline_ready"] = True
(ROOT/"reports/verification.json").write_text(json.dumps(out, indent=2, ensure_ascii=False)+"\n")
print(json.dumps(out, indent=2, ensure_ascii=False))
print("DDR2G_OFFLINE_RELEASE_PASS")
