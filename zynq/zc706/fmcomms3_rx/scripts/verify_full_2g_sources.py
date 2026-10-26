#!/usr/bin/env python3
"""Check the full-capacity extension against the tested 2GiB/1GiB-window build."""
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
report = Path((root / "reports/full2g_active.txt").read_text().strip())
relative = "PZ_UART.srcs/sources_1/bd/design_1/design_1.bd"
old = json.loads((report / "before" / relative).read_text())["design"]
new = json.loads((root / relative).read_text())["design"]
assert set(new["components"]) - set(old["components"]) == {"ddr_cpu_window", "axi_gpio_ddr_bank"}
assert set(old["components"]) <= set(new["components"])
for cell in ["processing_system7_0", "ad9361_rx_axis_0", "axi_dma_0",
             "axis_data_fifo_0", "axi_gpio_9361", "axi_gpio_ris_ctl", "mig_7series_0"]:
    before_params = dict(old["components"][cell].get("parameters", {}))
    after_params = dict(new["components"][cell].get("parameters", {}))
    if cell == "processing_system7_0":
        # Vivado omits default data widths for disabled HP interfaces when
        # serializing the refreshed BD. These ports remain disabled.
        for index in range(4):
            enable = f"PCW_USE_S_AXI_HP{index}"
            assert before_params.get(enable, {"value": "0"}) == after_params.get(enable, {"value": "0"}) == {"value": "0"}
            key = f"PCW_S_AXI_HP{index}_DATA_WIDTH"
            assert before_params.get(key, {"value": "64"}) == after_params.get(key, {"value": "64"}) == {"value": "64"}
            before_params.pop(key, None)
            after_params.pop(key, None)
    assert before_params == after_params, cell
for name, value in old["interface_nets"].items():
    if name != "processing_system7_0_M_AXI_GP0":
        assert new["interface_nets"].get(name) == value, name
address = new["addressing"]
def segments(design, cell, space):
    return design["addressing"]["/" + cell]["address_spaces"][space]["segments"]
for space in ["Data_SG", "Data_S2MM"]:
    seg = segments(new, "axi_dma_0", space)
    assert len(seg) == 1
    entry = next(iter(seg.values()))
    assert int(entry["offset"], 0) == 0 and entry["range"] == "2G", entry
seg = next(iter(segments(new, "ddr_cpu_window", "M_AXI").values()))
assert int(seg["offset"], 0) == 0 and seg["range"] == "2G"
before = segments(old, "processing_system7_0", "Data")
after = segments(new, "processing_system7_0", "Data")
for name, value in before.items():
    if "mig_7series" not in name:
        assert after[name] == value, name
assert after["SEG_ddr_cpu_window_reg0"]["offset"] == "0x40000000"
assert after["SEG_ddr_cpu_window_reg0"]["range"] == "1G"
assert after["SEG_axi_gpio_ddr_bank_Reg"]["offset"] == "0x83000000"
protected = json.loads((report / "protected_rf_sha256.json").read_text())
for name, expected in protected.items():
    assert hashlib.sha256((root / name).read_bytes()).hexdigest() == expected, name
actual = ET.parse(root / "constraints/zc706_mig.prj").getroot()
known = ET.parse(root.parent / "ddr2g_test/constraints/ddr2g_mig.prj").getroot()
assert [p.attrib for p in actual.iter("Pin")] == [p.attrib for p in known.iter("Pin")]
def parameters(tree):
    return {x.tag: (x.text or "").strip() for x in tree.iter() if not len(x) and x.tag != "Pin"}
a, b = parameters(actual), parameters(known)
assert all(a.get(k) == b.get(k) for k in set(a) | set(b)
           if k not in {"ModuleName", "C0_S_AXI_ID_WIDTH", "C0_S_AXI_SUPPORTS_NARROW_BURST"})
for manifest in ["application_sources.sha256.json", "hardware_sources.sha256.json"]:
    expected = json.loads((report / manifest).read_text())
    for name, digest in expected.items():
        assert hashlib.sha256((root / name).read_bytes()).hexdigest() == digest, name
checks = {"full_2g_dma_and_window_master": True, "one_gib_cpu_window": True,
          "peripheral_addresses_unchanged": True, "ps_rf_dma_parameters_unchanged": True,
          "mig_physical_timing_and_pins_match_tested_2g": True,
          "protected_rf_files": len(protected), "application_and_window_sources_pinned": True}
(report / "source_checks.json").write_text(json.dumps(checks, indent=2) + "\n")
print(json.dumps(checks, indent=2))
print("FULL_DDR2G_SOURCE_CHECKS_PASS")
