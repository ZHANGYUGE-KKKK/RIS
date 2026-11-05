#!/usr/bin/env python3
"""Record actual Flash evidence and refresh this image's delivery bundle."""
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import zipfile
from zoneinfo import ZoneInfo

from verify_zynq_boot import require, verify

root = Path(__file__).resolve().parents[1]
package = root / "export_flash/20261102_qam"
logs = root / "reports/flash"
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
image = package / "BOOT.bin"
require(sha(image) == "fe97b9c17ec1ff33bc1ac491b1b90eb4ada72da8f0176262fbaa8e6b37e5dd07", "Wrong image")
direct = (logs / "direct_program.log").read_text()
independent = (logs / "independent_verify.log").read_text()
require("RIS_BOOT_MODE 0" in direct and "RIS_QAM_FLASH_DIRECT_PASS 13556752" in direct, "Direct programming not verified")
require("0000600D" in direct and "001860EF" in direct, "Writer result or JEDEC ID differs")
require("Verify Operation successful" in independent and "Flash Operation Successful" in independent, "Independent verify did not pass")
chunks = [int(n) for n in re.findall(r"Total of (\d+) byte\(s\) were the same", independent)]
require(sum(chunks) == image.stat().st_size and len(chunks) == 414, "Independent byte count differs")
cold = logs / "cold_boot.log"
cold_ok = (cold.is_file() and cold.stat().st_mtime >= (logs / "independent_verify.log").stat().st_mtime
           and "RIS_QAM_COLD_BOOT_PASS" in cold.read_text() and "RIS_NETWORK_ACTIVE 1" in cold.read_text())
evidence = [logs / name for name in ("direct_program.log", "independent_verify.log", "inspect_ready.log")]
if cold_ok:
    evidence.append(cold)
report_dir = package / "reports"
report_dir.mkdir(exist_ok=True)
for path in evidence:
    shutil.copy2(path, report_dir / path.name)
record = {
    "verified_at": datetime.now(ZoneInfo("Asia/Shanghai")).isoformat(),
    "board": "ZC706 clone / XC7Z045", "cable_serial": "210299372306",
    "fpga_idcode": "23731093", "jedec_id": "ef6018",
    "flash_type": "qspi-x8-dual_parallel", "flash_offset": 0,
    "image_bytes": image.stat().st_size, "boot_sha256": sha(image),
    "boot_mode_during_programming": "JTAG (0)",
    "direct_full_byte_compare": "PASS", "independent_program_flash_verify": "PASS",
    "independent_verified_bytes": sum(chunks), "independent_comparison_chunks": len(chunks),
    "permanent_protection_bits_set": False, "cold_boot_test": "PASS" if cold_ok else "NOT_YET_TESTED",
    "application_listener_initialized": bool(cold_ok),
    "application_network_test": "NOT_TESTED; host interface is not on the RIS subnet",
    "rf_constellation_test": "NOT_TESTED",
    "programmer_source_sha256": sha(root / "build/flash_qam_20261102/direct_flash.c"),
    "programmer_elf_sha256": sha(root / "build/flash_qam_20261102/direct_flash.elf"),
    "evidence_sha256": {p.name: sha(p) for p in evidence},
}
write_json = lambda path, data: path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
write_json(package / "hardware_programming.json", record)
write_json(logs / "hardware_programming.json", record)
write_json(package / "validation.json", verify(package))
boot_status = "已通过：用户断电切回QSPI后，模式1、QAM1 FPGA标识、配套ARM固件就绪、错误0、TCP监听器初始化均核对成功。" if cold_ok else "尚待断电QSPI启动验收。"
report = f"""# 2026-11-02 QAM1 Flash实板记录

已烧写并通过两次完整读回比较，全部{record['image_bytes']:,}字节与BOOT.bin一致。

- 板卡/线缆：XC7Z045，IDCODE 23731093，下载线210299372306。
- Flash：JEDEC ef6018，qspi-x8-dual_parallel，偏移0x0。
- 镜像SHA-256：`{record['boot_sha256']}`。
- 写入时已读回JTAG启动模式0；沿用该板已验证的直接QSPI流程，仅修改易失配置，未主动设置永久保护位。
- 第一次：擦除后逐块空白检查、写入、全部数据逐字节比较，返回0x600D。
- 第二次：厂商program_flash明确-no_erase -no_program -verify，414个比较块、全部字节相同，退出成功。
- 断电启动：{boot_status}
- 电脑网卡当前不在RIS子网，未进行实际TCP会话/动态QAM播放或空口星座测试。监听器初始化成功不等同于网络收发实测。

证据见hardware_programming.json与reports/内对应日志。BOOT.bin的内容与原打包时相同；本次仅增加烧写/启动验收记录并更新包校验与ZIP。
"""
(package / "FLASH_REPORT.md").write_text(report)
(logs / "FLASH_REPORT.md").write_text(report)
readme = package / "README.md"
content = readme.read_text()
content = content.replace("本包只在离线生成和校验，尚未烧写或完成板上/断电启动验收。烧写会替换Flash中的旧程序。",
                          "2026-11-02已烧写并通过两次完整读回校验。详见FLASH_REPORT.md和hardware_programming.json。")
status = "断电QSPI启动验收已通过；实际TCP收发、动态QAM与射频尚未实测。" if cold_ok else "断电QSPI启动验收尚待完成。"
content = re.sub(r"\n<!-- boot-status -->.*?<!-- /boot-status -->\n", "\n", content, flags=re.S)
readme.write_text(content + f"\n<!-- boot-status -->{status}<!-- /boot-status -->\n")
files = sorted(p for p in package.rglob("*") if p.is_file() and p.name not in ("manifest.json", "SHA256SUMS"))
write_json(package / "manifest.json", {str(p.relative_to(package)): sha(p) for p in files})
files.append(package / "manifest.json")
(package / "SHA256SUMS").write_text("".join(f"{sha(p)}  {p.relative_to(package)}\n" for p in sorted(files)))
bundle = package.with_name("RIS_ZC706_QAM_QSPI_20261102_qam.zip")
staging = bundle.with_suffix(".zip.tmp")
with zipfile.ZipFile(staging, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in sorted(package.rglob("*")):
        if path.is_file(): archive.write(path, str(path.relative_to(package.parent)))
with zipfile.ZipFile(staging) as archive:
    require(archive.testzip() is None, "ZIP CRC failed")
    for name in archive.namelist():
        require(archive.read(name) == (package.parent / name).read_bytes(), f"ZIP content differs: {name}")
staging.replace(bundle)
bundle.with_suffix(".zip.sha256").write_text(f"{sha(bundle)}  {bundle.name}\n")
print(f"RIS_QAM_FLASH_RECORD_PASS: two full comparisons, cold_boot={cold_ok}, {sum(chunks)} bytes")
