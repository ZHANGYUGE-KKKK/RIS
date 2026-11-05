#!/usr/bin/env python3
"""Check implemented Vivado 2020.2 receiver ILA port/bit connections."""
import json
from pathlib import Path
import sys

document = json.loads(Path(sys.argv[1]).read_text())
cores = [core for group in document["ltx_root"]["ltx_data"]
         for core in group["debug_cores"] if core["name"] == "ila_ad9361_rx"]
assert len(cores) == 1, "Expected exactly one implemented receiver ILA"
core = cores[0]
assert core.get("uuid"), "Receiver ILA must have an implemented UUID"
pins = {pin["name"]: pin for pin in core["pins"]}
assert set(pins) == {"probe0", "probe1", "probe2", "probe3", "probe4"}, pins.keys()
prefix = "u_design_1_wrapper/design_1_i/ad9361_rx_axis_0/inst"
expected = (("debug_axis_data", 64), ("debug_axis_flags", 10),
            ("debug_sample_count", 24), ("debug_clock_count", 24),
            ("debug_raw_rx", 49))
for index, (signal, width) in enumerate(expected):
    pin = pins[f"probe{index}"]
    assert pin["portIndex"] == index, pin
    assert pin["isVector"] and pin["leftIndex"] == 0 and pin["rightIndex"] == width - 1, pin
    assert len(pin["nets"]) == 1, pin
    net = pin["nets"][0]
    assert net["name"] == f"{prefix}/{signal}" and net["isBus"], net
    actual_bits = [bit["name"] for bit in net["subnets"]]
    expected_bits = [f"{prefix}/{signal}[{bit}]" for bit in range(width - 1, -1, -1)]
    assert actual_bits == expected_bits, (signal, actual_bits)
    print(f"PASS probe{index}: {signal}[{width - 1}:0], {width} connected bits")
print(f"PASS receiver ILA UUID={core['uuid']}; all 171 probe bits match")
