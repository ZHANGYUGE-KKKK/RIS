#!/usr/bin/env python3
"""Validate a routed RX build, then back up and publish its BIT/LTX/XSA."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
import sys
import time
import zipfile


def digest(data):
    return hashlib.sha256(data).hexdigest()


def bit_fields(data):
    """Parse the Xilinx BIT container, retaining its entire configuration data."""
    offset = 2 + int.from_bytes(data[:2], "big")
    if data[offset:offset + 2] != b"\x00\x01":
        raise ValueError("Invalid BIT header marker")
    offset += 2
    fields = {"prefix": data[:offset]}
    for key in b"abcde":
        if data[offset] != key:
            raise ValueError("Unexpected BIT header field")
        offset += 1
        length_bytes = 4 if key == ord("e") else 2
        length = int.from_bytes(data[offset:offset + length_bytes], "big")
        offset += length_bytes
        fields[chr(key)] = data[offset:offset + length]
        offset += length
    if offset != len(data):
        raise ValueError("Incorrect BIT payload length")
    return fields


root, report, snapshot = (Path(value).resolve() for value in sys.argv[1:4])
expected_rtl_hash = sys.argv[4]
rtl = root / "PZ_UART.srcs/sources_1/new/ad9361_rx_axis.v"
if digest(rtl.read_bytes()) != expected_rtl_hash:
    raise RuntimeError("Receiver RTL changed during the build")
if digest((snapshot / rtl.relative_to(root)).read_bytes()) != expected_rtl_hash:
    raise RuntimeError("Snapshot receiver RTL does not match the build")
if "All user specified timing constraints are met." not in (report / "timing_route.rpt").read_text():
    raise RuntimeError("Routed timing did not close")
if re.search(r"^CDC-\d+\s+Critical\s+[1-9]", (report / "cdc.rpt").read_text(), re.M):
    raise RuntimeError("Critical CDC paths remain")
if re.search(r"^\s+(?:Slow|Fast)\s+[\d.]+\s+[\d.]+\s+-[\d.]+\s*$",
             (report / "bus_skew.rpt").read_text(), re.M):
    raise RuntimeError("Bus skew violation remains")
subprocess.run([sys.executable, str(root / "scripts/check_ad9361_rx_probes.py"),
                str(report / "pz7035_top.ltx")], check=True)

standalone = (report / "pz7035_top.bit").read_bytes()
with zipfile.ZipFile(report / "pz7035_top.xsa") as package:
    names = [name for name in package.namelist() if name.endswith(".bit")]
    if len(names) != 1:
        raise RuntimeError("XSA must contain exactly one bitstream")
    embedded = package.read(names[0])
    hwh = package.read("design_1.hwh")
    snapshot_hwh = snapshot / "PZ_UART.srcs/sources_1/bd/design_1/hw_handoff/design_1.hwh"
    if hwh != snapshot_hwh.read_bytes():
        raise RuntimeError("XSA HWH differs from the regenerated snapshot")
first, second = bit_fields(standalone), bit_fields(embedded)
for field in ("prefix", "a", "b", "e"):
    if first[field] != second[field]:
        raise RuntimeError(f"XSA BIT differs from routed BIT in field {field}")
comparison = dict(
    standalone_sha256=digest(standalone), xsa_bit_sha256=digest(embedded),
    configuration_sha256=digest(first["e"]), configuration_bytes=len(first["e"]),
    payload_equal=True, hwh_matches_snapshot=True, hwh_sha256=digest(hwh),
    standalone_date=first["c"].rstrip(b"\0").decode(),
    standalone_time=first["d"].rstrip(b"\0").decode(),
    xsa_date=second["c"].rstrip(b"\0").decode(),
    xsa_time=second["d"].rstrip(b"\0").decode())
(report / "bitstream_comparison.json").write_text(json.dumps(comparison, indent=2) + "\n")
if standalone != embedded:
    # write_hw_platform performs bitgen again, changing only the date/time.
    shutil.copy2(report / "pz7035_top.bit", report / "pz7035_top.pre_xsa.bit")
    (report / "pz7035_top.bit").write_bytes(embedded)

backup = root / "backups" / ("before_rx_board_publish_" + time.strftime("%Y%m%d_%H%M%S"))
backup.mkdir(parents=True, exist_ok=False)
artifacts = (("pz7035_top.bit", Path("PZ_UART.runs/impl_1/pz7035_top.bit")),
             ("pz7035_top.ltx", Path("PZ_UART.runs/impl_1/pz7035_top.ltx")),
             ("pz7035_top.xsa", Path("pz7035_top.xsa")))
manifest = dict(backup=str(backup), rtl_sha256=expected_rtl_hash,
                snapshot=str(snapshot), artifacts=[])
for name, relative in artifacts:
    canonical = root / relative
    if canonical.exists():
        saved = backup / relative
        saved.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(canonical, saved)
for name, relative in artifacts:
    canonical = root / relative
    canonical.parent.mkdir(parents=True, exist_ok=True)
    pending = canonical.with_name(canonical.name + ".rx_board_pending")
    shutil.copy2(report / name, pending)
    pending.replace(canonical)
    manifest["artifacts"].append(dict(path=str(canonical), sha256=digest(canonical.read_bytes())))
(report / "published_artifacts.json").write_text(json.dumps(manifest, indent=2) + "\n")
with (report / "build_status.txt").open("a") as status:
    status.write(f"PUBLISH_PASS {time.strftime('%Y-%m-%d %H:%M:%S')}\nRTL_SHA256={expected_rtl_hash}\n")
print(json.dumps(manifest))
