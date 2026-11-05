#!/usr/bin/env python3
"""Package matching QAM1 FSBL/BIT/ELF for QSPI. Never access hardware."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

from verify_zynq_boot import require, verify

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def json_file(path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def build(output):
    source = ROOT / "export_qam"
    platform = ROOT / "vitis_qam/ris_qam_platform"
    bootgen = Path(os.environ.get("RIS_BOOTGEN", "/home/wenhan/SOFTWARE/VIVADO2022.2/Vitis/2022.2/bin/bootgen"))
    require(bootgen.is_file(), "Set RIS_BOOTGEN to the installed Bootgen")
    subprocess.run([sys.executable, str(ROOT / "scripts/verify_package.py")], check=True)
    accepted = json.loads((source / "manifest.json").read_text())
    require(digest(platform / "hw/ris_ctrl_unit.xsa") == accepted["ris_ctrl_unit.xsa"], "FSBL platform XSA differs")
    fsbl = platform / "zynq_fsbl/fsbl.elf"
    require(digest(fsbl) == digest(platform / "export/ris_qam_platform/sw/ris_qam_platform/boot/fsbl.elf"), "Exported FSBL is stale")
    with zipfile.ZipFile(source / "ris_ctrl_unit.xsa") as archive:
        for name in ("ps7_init.c", "ps7_init.h"):
            require(archive.read(name) == (platform / "zynq_fsbl" / name).read_bytes(), f"FSBL {name} differs from XSA")
    parameters = platform / "zynq_fsbl/zynq_fsbl_bsp/ps7_cortexa9_0/include/xparameters.h"
    require(re.search(r"#define\s+XPAR_PS7_QSPI_0_QSPI_MODE\s+2\b", parameters.read_text()), "FSBL must enable dual-parallel QSPI")
    firmware = json.loads((source / "firmware_manifest.json").read_text())
    for name, sha in firmware["sources_sha256"].items():
        path = ROOT / name
        require(digest(path) == sha == digest(ROOT / "vitis_qam/ris_qam_network/src" / path.name), f"Rebuild firmware: {name}")
    require(digest(source / "ris_all_io.elf") == digest(ROOT / "vitis_qam/ris_qam_network/Debug/ris_qam_network.elf"), "Application ELF export is stale")

    bundle = output.with_name(f"RIS_ZC706_QAM_QSPI_{output.name}.zip")
    checksum = bundle.with_suffix(".zip.sha256")
    require(not any(p.exists() for p in (output, bundle, checksum)), "Output already exists; choose a new directory")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=f".{output.name}-", dir=output.parent) as temp:
        staging = Path(temp) / output.name
        staging.mkdir()
        for name in accepted:
            shutil.copy2(source / name, staging / name)
        for name in ("build_manifest.json", "firmware_manifest.json"):
            shutil.copy2(source / name, staging / name)
        json_file(staging / "accepted_artifacts.json", accepted)
        shutil.copy2(fsbl, staging / "fsbl.elf")
        shutil.copy2(ROOT / "scripts/verify_zynq_boot.py", staging / "verify_zynq_boot.py")
        (staging / "BOOT.bif").write_text("the_ROM_image:\n{\n    [bootloader] fsbl.elf\n    ris_ctrl_unit.bit\n    ris_all_io.elf\n}\n")
        for args, name in ((["-image", "BOOT.bif", "-o", "BOOT.bin", "-w", "on"], "bootgen_build.log"),
                           (["-read", "BOOT.bin"], "bootgen_inspect.log")):
            with (staging / name).open("w") as log:
                subprocess.run([str(bootgen), "-arch", "zynq", *args], cwd=staging, stdout=log, stderr=subprocess.STDOUT, check=True)
        result = verify(staging)
        json_file(staging / "validation.json", result)
        json_file(staging / "source_provenance.json", {
            "format": "ris-qam1-qspi-package-v1", "generated_utc": datetime.now(timezone.utc).isoformat(),
            "accepted_qam_artifacts": accepted, "fsbl_sha256": digest(fsbl),
            "fsbl_platform_xsa_sha256": digest(platform / "hw/ris_ctrl_unit.xsa"),
            "fsbl_ps_init_matches_xsa": True, "fsbl_qspi_mode": 2,
            "qspi_parameters_sha256": digest(parameters), "firmware_sources_match_build": True,
            "hardware_access_performed": False,
            "packaging_scripts_sha256": {p.name: digest(p) for p in (Path(__file__), ROOT / "scripts/verify_zynq_boot.py")},
        })
        (staging / "README.md").write_text("""# RIS ZC706 QAM1 Flash启动包

烧写文件为 `BOOT.bin`，目标ZC706 / XC7Z045，Flash类型 `qspi-x8-dual_parallel`，写入偏移 `0x0`，总容量32 MiB。
镜像按顺序包含：匹配当前XSA的FSBL、QAM1 FPGA BIT、RIS706 TCP网络ELF。
`fsbl.elf`可供烧写工具的FSBL辅助程序选项使用；`BOOT.bif`是构建输入，不是Flash镜像。

本包只在离线生成和校验，尚未烧写或完成板上/断电启动验收。烧写会替换Flash中的旧程序。
启动后TCP地址沿用 `192.168.1.11:7060`；初始化输出全0，不自动开始QAM播放。
电脑使用新版控制台 `/home/wenhan/PROJECTS/RIS/RIS_CTRL/ris_control_ui_v2/start_gui.sh --qam`，由总下发按钮上传码本和数据后播放。
码本/数据运行时经TCP写入FPGA RAM，不内置在BOOT.bin中，掉电后需要重新下发。
原1 MHz码本仍不能原速播放；低速数字核线需明确选择200 ns/片，对应PWM 19.53125 kHz，不能当作来源模型射频性能验收。

离线复核（不访问硬件）：

```bash
sha256sum --check SHA256SUMS
python3 verify_zynq_boot.py .
```

`validation.json`记录三个分区与输入文件逐字节匹配、头校验、分区地址和BIT/XSA匹配结果。
`source_provenance.json`记录FSBL来源、双并行QSPI配置和配套硬件/固件指纹。
本包不附带自动烧写脚本；用户执行烧写工具时才会操作板卡。
""", encoding="utf-8")
        files = sorted(p for p in staging.iterdir() if p.is_file())
        json_file(staging / "manifest.json", {p.name: digest(p) for p in files})
        files.append(staging / "manifest.json")
        (staging / "SHA256SUMS").write_text("".join(f"{digest(p)}  {p.name}\n" for p in sorted(files)))
        zipped = Path(temp) / bundle.name
        with zipfile.ZipFile(zipped, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for path in sorted(staging.iterdir()):
                archive.write(path, f"{output.name}/{path.name}")
        with zipfile.ZipFile(zipped) as archive:
            require(archive.testzip() is None, "ZIP CRC failed")
            require(len(archive.namelist()) == len(list(staging.iterdir())), "ZIP members differ")
            for name in archive.namelist():
                require(hashlib.sha256(archive.read(name)).hexdigest() == digest(staging / Path(name).name), f"ZIP content differs: {name}")
        archive_sha = digest(zipped)
        staging.rename(output)
        zipped.rename(bundle)
        checksum.write_text(f"{archive_sha}  {bundle.name}\n")
    print(f"RIS_QAM_BOOT_PACKAGE_PASS: {output / 'BOOT.bin'} ({result['image_bytes']} bytes)")
    print(f"ZIP verified: {bundle}")
    print("No hardware accessed; Flash has not been programmed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", nargs="?", type=Path, default=ROOT / "export_flash" / f"{datetime.now():%Y%m%d}_qam")
    args = parser.parse_args()
    build(args.output.resolve())
