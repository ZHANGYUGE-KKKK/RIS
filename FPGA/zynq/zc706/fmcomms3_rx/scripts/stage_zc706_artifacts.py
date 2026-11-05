#!/usr/bin/env python3
import hashlib
import json
import shutil
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
app = root / "vitis_code/key_ctrlll"
platform = root / "vitis_code/key_ctrl/export/key_ctrl"
for directory in (app / "_ide/bitstream", app / "_ide/psinit"):
    directory.mkdir(parents=True, exist_ok=True)
for name in ("zc706_top.bit", "zc706_top.ltx"):
    shutil.copy2(root / "export" / name, app / "_ide/bitstream" / name)
shutil.copy2(platform / "hw/ps7_init.tcl", app / "_ide/psinit/ps7_init.tcl")
for name in ("key_ctrlll.elf", "key_ctrlll_2p4.elf", "key_ctrlll_dma_debug.elf"):
    shutil.copy2(app / "Debug/key_ctrlll.elf", root / "export" / name)
shutil.copy2(root / "vitis_code/key_ctrl/zynq_fsbl/fsbl.elf", root / "export/fsbl.elf")
xsa = root / "export/zc706_top.xsa"
assert xsa.read_bytes() == (platform / "hw/zc706_top.xsa").read_bytes()
with zipfile.ZipFile(xsa) as package:
    assert package.read("zc706_top.bit") == (root / "export/zc706_top.bit").read_bytes()
files = ["export/zc706_top.bit", "export/zc706_top.ltx", "export/zc706_top.xsa",
         "export/key_ctrlll.elf", "export/key_ctrlll_2p4.elf", "export/key_ctrlll_dma_debug.elf", "export/fsbl.elf",
         "vitis_code/key_ctrl/export/key_ctrl/hw/zc706_top.xsa",
         "vitis_code/key_ctrl/export/key_ctrl/hw/ps7_init.tcl",
         "vitis_code/key_ctrlll/Debug/key_ctrlll.elf",
         "vitis_code/key_ctrlll/_ide/bitstream/zc706_top.bit"]
manifest = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in files}
(root / "export/manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("PASS: staged matching hardware, platform, debug and executable files")
