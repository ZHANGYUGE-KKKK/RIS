from pathlib import Path
import shutil,hashlib,json
r=Path(__file__).resolve().parents[2]
p=r/'reports/dma_board_20261021/before';p.mkdir(exist_ok=True)
names=['vitis_code/key_ctrlll/src/helloworld.c','export/key_ctrlll.elf','export/key_ctrlll_dma_debug.elf','reports/network_capture/release.sha256.json','reports/rx_external_test/application_sources.sha256.json']
x={}
for name in names:
 f=r/name;t=p/name;t.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(f,t);x[name]=hashlib.sha256(f.read_bytes()).hexdigest()
(p/'sha256.json').write_text(json.dumps(x,indent=2)+'\n')
