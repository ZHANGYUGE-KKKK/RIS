#!/usr/bin/env python3
"""Install the HSI-generated lwIP BSP in the existing Vitis platform export."""
import json
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[1]
generated = root / 'vitis_code/network_bsp'
platform = root / 'vitis_code/key_ctrl'
bsp = platform / 'ps7_cortexa9_0/standalone_domain/bsp'
cpu = generated / 'ps7_cortexa9_0'
export = platform / 'export/key_ctrl/sw/key_ctrl/standalone_domain'
assert (cpu / 'lib/liblwip4.a').is_file(), 'Build scripts/build_network_bsp.tcl first'
shutil.copytree(cpu, bsp / 'ps7_cortexa9_0', dirs_exist_ok=True)
shutil.copy2(generated / 'network_bsp.mss', bsp / 'system.mss')
shutil.copytree(cpu / 'include', export / 'bspinclude/include', dirs_exist_ok=True)
shutil.copytree(cpu / 'lib', export / 'bsplib/lib', dirs_exist_ok=True)
spr = platform / 'platform.spr'
project = json.loads(spr.read_text())
options = dict(api_mode='RAW_API', lwip_dhcp='false', phy_link_speed='CONFIG_LINKSPEED_AUTODETECT',
               no_sys_no_timers='true', mem_size='1048576', memp_n_tcp_seg='1024',
               tcp_snd_buf='65535', tcp_wnd='32768', pbuf_pool_size='512',
               use_axieth_on_zynq='0', use_emaclite_on_zynq='0')
for system in project['systems']:
    for domain in system['domains']:
        if domain['domainName'] == 'standalone_domain':
            libs = domain.setdefault('addedLibs', [])
            if 'lwip211:1.2' not in libs:
                libs.append('lwip211:1.2')
            config = domain.setdefault('libOptions', {})
            config['lwip211'] = dict(options, libOptionNames=list(options))
            containing = config.setdefault('libsContainingOptions', [])
            if 'lwip211' not in containing:
                containing.append('lwip211')
spr.write_text(json.dumps(project, separators=(',', ':')) + '\n')
print('Installed lwIP 2.1.1 BSP and Vitis platform library settings')
