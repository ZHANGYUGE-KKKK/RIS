#!/usr/bin/env python3
from pathlib import Path
import json
import numpy as np
import zlib
root=Path(__file__).resolve().parent
all_modes={}
for mode in ['running','halted']:
    rows=[];summary={}
    for f in sorted((root/f'patterns_{mode}').glob('*.bin')):
        addr,pattern,trial=f.stem.split('_')
        a=np.frombuffer((root/'patterns'/f'{pattern}.bin').read_bytes(),dtype='u1')
        b=np.frombuffer(f.read_bytes(),dtype='u1')
        if b.size!=a.size:raise RuntimeError(f'Incomplete read {f}')
        bad=a!=b;ix=np.flatnonzero(bad)
        row={'address':addr,'pattern':pattern,'trial':int(trial),'bytes':int(b.size),'bad_bytes':int(bad.sum()),'bad_by_lane_mod8':[int(bad[i::8].sum()) for i in range(8)],'crc32':f'{zlib.crc32(b):08x}','first_mismatches':[{'address':f'{int(addr,16)+int(i):08x}','expected':int(a[i]),'actual':int(b[i])} for i in ix[:8]]}
        rows.append(row)
        s=summary.setdefault(addr,{'reads':0,'failed_reads':0,'total_bad_bytes':0,'bad_by_lane_mod8':[0]*8})
        s['reads']+=1;s['failed_reads']+=int(row['bad_bytes']>0);s['total_bad_bytes']+=row['bad_bytes']
        s['bad_by_lane_mod8']=[x+y for x,y in zip(s['bad_by_lane_mod8'],row['bad_by_lane_mod8'])]
    all_modes[mode]={'read_count':len(rows),'failed_read_count':sum(x['bad_bytes']>0 for x in rows),'summary':summary,'rows':rows}
    print(mode, json.dumps({'reads':len(rows),'failed':all_modes[mode]['failed_read_count'],'by_address':{k:{'reads':v['reads'],'failed':v['failed_reads'],'bad_bytes':v['total_bad_bytes'],'lanes':v['bad_by_lane_mod8']} for k,v in summary.items()}},indent=2))
(root/'patterns_result.json').write_text(json.dumps(all_modes,indent=2)+'\n')
