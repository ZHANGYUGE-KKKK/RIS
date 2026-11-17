#!/usr/bin/env python3
"""Verify the authorized DDR-only adaptation against its saved baseline."""
from pathlib import Path
import hashlib
import json
import xml.etree.ElementTree as ET

root=Path(__file__).resolve().parent.parent
report=Path((root/'reports/mig2g_active.txt').read_text().strip())
old=json.loads((report/'before/PZ_UART.srcs/sources_1/bd/design_1/design_1.bd').read_text())['design']
new=json.loads((root/'PZ_UART.srcs/sources_1/bd/design_1/design_1.bd').read_text())['design']
assert old['addressing']==new['addressing'], 'PS/DMA aperture changed'
assert old['interface_nets']==new['interface_nets'], 'Data/control AXI connections changed'
assert set(new['components'])-set(old['components'])=={'mig2g_clock','mig2g_reset_gate','ddr_status_monitor'}
for name in ['axi_dma_0','axis_data_fifo_0','processing_system7_0','ad9361_rx_axis_0','axi_gpio_9361']:
    assert old['components'][name].get('parameters')==new['components'][name].get('parameters'),name
protected=json.loads((report/'protected_rf_sha256.json').read_text())
for name,expected in protected.items():
    assert hashlib.sha256((root/name).read_bytes()).hexdigest()==expected,name
application=json.loads((report/'application_sources.sha256.json').read_text())
actual_application={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in (root/'vitis_code/key_ctrlll/src').rglob('*') if p.is_file()}
assert actual_application==application, 'Application differs from the tested 2GiB build'
known=ET.parse(root.parent/'ddr2g_test/constraints/ddr2g_mig.prj').getroot()
actual=ET.parse(root/'constraints/zc706_mig.prj').getroot()
assert [x.attrib for x in known.iter('Pin')]==[x.attrib for x in actual.iter('Pin')]
def parameters(tree):
    return {x.tag:(x.text or '').strip() for x in tree.iter() if len(x)==0 and x.tag!='Pin'}
a,b=parameters(known),parameters(actual)
# AXI ID and narrow-burst adaptation follow the attached masters; they do not
# change physical DRAM organization, clock, timing or termination.
allowed={'ModuleName','C0_S_AXI_ID_WIDTH','C0_S_AXI_SUPPORTS_NARROW_BURST'}
assert all(a.get(k)==b.get(k) for k in set(a)|set(b) if k not in allowed)
checks={'physical_mig_matches_tested_2g':True,'pins_match_tested_2g':True,
        'ps_dma_aperture_unchanged':True,'axi_connections_unchanged':True,
        'dma_and_receiver_parameters_unchanged':True,'rf_files_unchanged':len(protected),
        'tested_application_files':len(application),
        'interface_adaptation':{k:{'bist':a.get(k),'receiver':b.get(k)} for k in allowed if a.get(k)!=b.get(k)}}
(report/'source_checks.json').write_text(json.dumps(checks,indent=2)+'\n')
print(json.dumps(checks,indent=2))
print('RX_DDR2G_SOURCE_CHECKS_PASS')
