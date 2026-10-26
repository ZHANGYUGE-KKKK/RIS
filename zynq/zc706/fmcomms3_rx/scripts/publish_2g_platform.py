#!/usr/bin/env python3
"""Publish the staged platform only after matching the final routed handoff."""
from pathlib import Path
import json
import shutil
import zipfile
import sys

root=Path(__file__).resolve().parent.parent
report=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path((root/'reports/mig2g_active.txt').read_text().strip())
src=report/'vitis_stage/key_ctrl'
dst=root/'vitis_code/key_ctrl'
with zipfile.ZipFile(root/'export/zc706_top.xsa') as final, zipfile.ZipFile(report/'bsp_preview.xsa') as preview:
    hwh=next(n for n in final.namelist() if n.endswith('.hwh'))
    assert final.read(hwh)==preview.read(hwh),'Staged BSP differs from routed hardware'
    assert final.read('zc706_top.bit')==(root/'export/zc706_top.bit').read_bytes()
    backup=report/'before/vitis_code/key_ctrl'
    backup.mkdir(parents=True,exist_ok=True)
    for folder in ['hw','export','ps7_cortexa9_0','zynq_fsbl']:
        if (dst/folder).exists(): shutil.copytree(dst/folder,backup/folder,dirs_exist_ok=True)
        shutil.copytree(src/folder,dst/folder,dirs_exist_ok=True)
    description=json.loads((src/'platform.spr').read_text())
    description['platHandOff']=str(root/'export/zc706_top.xsa')
    description['platIntHandOff']='<platformDir>/hw/zc706_top.xsa'
    (dst/'platform.spr').write_text(json.dumps(description,separators=(',',':'))+'\n')
    for directory in [dst/'hw',dst/'export/key_ctrl/hw']:
        directory.mkdir(parents=True,exist_ok=True)
        shutil.copy2(root/'export/zc706_top.xsa',directory/'zc706_top.xsa')
        for name in final.namelist():
            if name.startswith('ps7_init') and '/' not in name:
                (directory/name).write_bytes(final.read(name))
    for name in final.namelist():
        if name.startswith('ps7_init') and '/' not in name:
            (root/'export'/name).write_bytes(final.read(name))
shutil.copytree(report/'network_bsp',root/'vitis_code/network_bsp',dirs_exist_ok=True)
print('RX_DDR2G_PLATFORM_PUBLISHED: final XSA, PS init, FSBL, lwIP BSP and platform exports')
