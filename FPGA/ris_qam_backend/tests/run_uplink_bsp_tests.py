#!/usr/bin/env python3
"""Offline host fault tests for the project-local dual-GEM BSP patch.
No board, JTAG, MDIO, or I2C access. Requires a host C99 compiler. If a generated
uplink BSP is available, also checks patch idempotence/tamper rejection in a
private temporary copy and validates the generated initialization error gates.
"""
import importlib.util
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile

project = Path(__file__).resolve().parents[1]
script = project / 'scripts/patch_uplink_bsp.py'
spec = importlib.util.spec_from_file_location('ris_bsp_patch', script)
patch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patch)
bundled = '/home/wenhan/SOFTWARE/VIVADO2022.2/Vivado/2022.2/tps/lnx64/gcc-8.3.0/bin/gcc'
cc = shlex.split(os.environ.get('CC') or os.environ.get('RIS_HOST_GCC') or shutil.which('cc') or bundled)
if os.sys.platform.startswith('linux'):
    cc += ['-isystem', '/usr/include/x86_64-linux-gnu', '-B/usr/lib/x86_64-linux-gnu/']
with tempfile.TemporaryDirectory(prefix='ris-uplink-bsp-test-') as tmp:
    temp = Path(tmp)
    (temp / 'sleep.h').write_text('void usleep(unsigned int delay);\n')
    (temp / 'ris_dual_gem.inc').write_text(patch.HELPER)
    test = project / 'tests/uplink_bsp/test_phy.c'
    exe = temp / 'test_phy'
    subprocess.run(cc + ['-std=c99', '-Wall', '-Wextra', '-Werror', '-I' + str(temp),
                        str(test), '-o', str(exe)], check=True)
    subprocess.run([str(exe)], check=True)

    originals = project / 'vitis_uplink/ris_uplink_platform/ps7_cortexa9_0/standalone_domain/bsp/ps7_cortexa9_0/libsrc/lwip211_v1_8/src/contrib/ports/xilinx/netif'
    if not originals.is_dir():
        print('SKIP: generated BSP-specific patch integration checks (generate platform first)')
    else:
        local_script = temp / 'scripts/patch_uplink_bsp.py'
        local_script.parent.mkdir()
        shutil.copy2(script, local_script)
        bsp = temp / 'platform/standalone_domain/bsp'
        port = bsp / 'ps7_cortexa9_0/libsrc/lwip211_v1_8/src/contrib/ports/xilinx'
        netif = port / 'netif'
        netif.mkdir(parents=True)
        (port / 'include/netif').mkdir(parents=True)
        for name in patch.EXPECTED:
            backup = originals / (name + '.ris-original')
            shutil.copy2(backup if backup.exists() else originals / name, netif / name)
        command = [os.sys.executable, str(local_script), '--bsp', str(bsp)]
        subprocess.run(command, check=True, stdout=subprocess.DEVNULL)
        first = {p.name: p.read_bytes() for p in netif.iterdir()}
        subprocess.run(command, check=True, stdout=subprocess.DEVNULL)
        assert first == {p.name: p.read_bytes() for p in netif.iterdir()}, 'not idempotent'
        source = (netif / 'xemacpsif.c').read_text()
        begin = source.index('static err_t low_level_init(')
        fn = source[begin:source.index('void HandleEmacPsError(', begin)]
        assert fn.index('if (!ris_gem_get(&xemacpsif->emacps)->configured)') < fn.index('if (init_dma(') < fn.index('start_emacps(')
        for branch in ('if (!ris_gem_get(&xemacpsif->emacps)->configured)', 'if (init_dma('):
            body = fn[fn.index(branch):]
            body = body[:body.index('\n\t}')]
            assert 'return ERR_IF;' in body and 'XEmacPs_Stop' in body
        altered = netif / 'xadapter.c'
        altered.write_bytes(altered.read_bytes() + b'/* manual change */\n')
        result = subprocess.run(command, capture_output=True)
        assert result.returncode and b'changed outside this script' in result.stderr
        assert altered.read_bytes().endswith(b'/* manual change */\n')
        print('PASS: patch idempotence, manual-change rejection, PHY/DMA failure propagation before MAC start')
