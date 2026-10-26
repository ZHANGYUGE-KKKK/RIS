#!/usr/bin/env python3
"""Build the real application with a new BSP without locking Eclipse's workspace."""
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
report = Path(sys.argv[1]).resolve()
application = root / "vitis_code/key_ctrlll"
build = report / "app_build"
build.mkdir(exist_ok=True)
source_link = report / "src"
if not source_link.exists():
    source_link.symlink_to(application / "src", target_is_directory=True)
old = str(root / "vitis_code/key_ctrl/export/key_ctrl/sw/key_ctrl/standalone_domain")
cpu = report / "network_bsp/ps7_cortexa9_0"
assert (cpu / "lib/liblwip4.a").is_file()
def adapt(text):
    return text.replace(old + "/bspinclude/include", str(cpu / "include")).replace(
        old + "/bsplib/lib", str(cpu / "lib")).replace(
        "-specs=Xilinx.spec", "-specs=" + str(application / "src/Xilinx.spec"))
for path in (application / "Debug").rglob("*"):
    if path.is_file() and (path.suffix == ".mk" or path.name == "makefile"):
        target = build / path.relative_to(application / "Debug")
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(adapt(path.read_text()))
(report / "makefile.defs").write_text(adapt((application / "makefile.defs").read_text()))
environment = dict(os.environ)
environment["PATH"] = "/home/yyz/vivado2020.2/main/Vitis/2020.2/gnu/aarch32/lin/gcc-arm-none-eabi/bin:" + environment["PATH"]
subprocess.run(["make", "-C", str(build), "-j2", "all"], env=environment, check=True)
print("STAGED_APPLICATION_BUILT", build / "key_ctrlll.elf")
