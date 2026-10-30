#!/usr/bin/env python3
"""Package the accepted MT handoff and its matching FSBL. Never access hardware."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile

from verify_zynq_boot import require, verify

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build():
    output = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT/'export_flash/20261029_mt'
    source = ROOT/'export_mt'
    platform = ROOT/'vitis_mt/ris_mt_platform'
    bootgen = Path(os.environ.get('RIS_BOOTGEN', '/home/wenhan/SOFTWARE/VIVADO2022.2/Vitis/2022.2/bin/bootgen'))
    require(bootgen.is_file(), 'Set RIS_BOOTGEN to the installed Bootgen executable')
    accepted = json.loads((source/'manifest.json').read_text())
    for name, sha in accepted.items():
        require(digest(source/name) == sha, f'Accepted MT package changed: {name}')
    require(digest(platform/'hw/ris_ctrl_unit.xsa') == accepted['ris_ctrl_unit.xsa'], 'FSBL platform uses a different XSA')
    with zipfile.ZipFile(source/'ris_ctrl_unit.xsa') as archive:
        for name in ('ps7_init.c', 'ps7_init.h'):
            require(archive.read(name) == (platform/'zynq_fsbl'/name).read_bytes(), f'FSBL {name} differs from XSA')
    parameters = platform/'zynq_fsbl/zynq_fsbl_bsp/ps7_cortexa9_0/include/xparameters.h'
    require(re.search(r'#define\s+XPAR_PS7_QSPI_0_QSPI_MODE\s+2\b', parameters.read_text()), 'FSBL must enable dual-parallel QSPI')
    fsbl = platform/'zynq_fsbl/fsbl.elf'
    require(digest(fsbl) == digest(platform/'export/ris_mt_platform/sw/ris_mt_platform/boot/fsbl.elf'), 'Exported FSBL is stale')
    for directory in ('software', 'software/network'):
        for path in (ROOT/directory).iterdir():
            if path.suffix in ('.c', '.h'):
                require(digest(path) == digest(ROOT/'vitis_mt/ris_mt_network/src'/path.name), f'Rebuild firmware: {path.name} changed')
    output.mkdir(parents=True, exist_ok=True)
    for name in accepted:
        shutil.copy2(source/name, output/name)
    shutil.copy2(fsbl, output/'fsbl.elf')
    shutil.copy2(ROOT/'scripts/verify_zynq_boot.py', output/'verify_zynq_boot.py')
    shutil.copy2(ROOT/'README_MT.md', output/'MT_CONTROL.md')
    (output/'matlab').mkdir(exist_ok=True)
    for path in (ROOT/'matlab').iterdir():
        if path.is_file():
            shutil.copy2(path, output/'matlab'/path.name)
    (output/'reports').mkdir(exist_ok=True)
    for name in ('timing.rpt', 'drc.rpt', 'cdc.rpt', 'route_status.rpt', 'hardware_build.log',
                 'firmware_build.log', 'verification.json', 'mt_unisim.log', 'mt_wrap_tests.log', 'mt_wrap_gui_tests.log'):
        shutil.copy2(ROOT/'reports/mt'/name, output/'reports'/name)
    (output/'BOOT.bif').write_text('the_ROM_image:\n{\n    [bootloader] fsbl.elf\n    ris_ctrl_unit.bit\n    ris_all_io.elf\n}\n')
    for args, name in [(['-image', 'BOOT.bif', '-o', 'BOOT.bin', '-w', 'on'], 'bootgen_build.log'),
                       (['-read', 'BOOT.bin'], 'bootgen_inspect.log')]:
        with (output/name).open('w') as log:
            subprocess.run([str(bootgen), '-arch', 'zynq', *args], cwd=output,
                           stdout=log, stderr=subprocess.STDOUT, check=True)
    result = verify(output)
    (output/'validation.json').write_text(json.dumps(result, indent=2)+'\n')
    (output/'source_provenance.json').write_text(json.dumps(dict(
        generated_at=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(),
        accepted_mt_package=accepted, fsbl_sha256=digest(fsbl),
        fsbl_platform_xsa_sha256=digest(platform/'hw/ris_ctrl_unit.xsa'),
        fsbl_ps_init_matches_xsa=True, fsbl_qspi_mode=2,
        qspi_parameters_sha256=digest(parameters),
        mt_semantics='M+T>100 wraps to the beginning of the SAME cycle; each row is independent',
        host_compiler_sha256=digest(ROOT/'host/ris_mt.py'),
        hardware_access_performed=False), indent=2)+'\n')
    require((output/'README.md').is_file(), 'Package README.md is required before delivery')
    files = sorted(p for p in output.rglob('*') if p.is_file() and p.name not in ('manifest.json', 'SHA256SUMS'))
    manifest = {str(p.relative_to(output)): digest(p) for p in files}
    (output/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    files.append(output/'manifest.json')
    (output/'SHA256SUMS').write_text(''.join(f'{digest(p)}  {p.relative_to(output)}\n' for p in sorted(files)))
    bundle = output.parent/'RIS_ZC706_MT_QSPI_20261029.zip'
    with zipfile.ZipFile(bundle, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(output.rglob('*')):
            if path.is_file():
                archive.write(path, str(path.relative_to(output.parent)))
    with zipfile.ZipFile(bundle) as archive:
        require(archive.testzip() is None, 'ZIP CRC verification failed')
        for name in archive.namelist():
            require(hashlib.sha256(archive.read(name)).hexdigest() == digest(output.parent/name), f'ZIP differs: {name}')
    print(f'PASS: {output / "BOOT.bin"} ({result["image_bytes"]} bytes)')
    print(f'PASS: partition contents, matching FSBL/QSPI handoff, checksums, ZIP verified: {bundle}')


if __name__ == '__main__':
    build()
