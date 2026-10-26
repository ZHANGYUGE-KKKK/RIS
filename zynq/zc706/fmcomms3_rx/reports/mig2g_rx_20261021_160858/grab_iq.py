#!/usr/bin/env python3
import sys,time,json,hashlib
from pathlib import Path
import numpy as np
root=Path(__file__).resolve().parent
sys.path.insert(0,str(root.parent.parent/'host'))
from rx706 import Client,download,validate_capture
size=int(sys.argv[1]);label=sys.argv[2]
summary={"requested_bytes":size,"label":label,"physical_ddr":"2GiB 2Rx8 DDR3-1333","mapped_aperture":"0x40000000..0x7fffffff","continuity_proven":False}
with Client('192.168.1.10',timeout=60) as client:
    before=client.request('STATUS')
    (root/f'{label}_before.json').write_text(json.dumps(before,indent=2)+'\n')
    if before['state']!='empty': raise RuntimeError('Capture is not empty; release explicitly before running')
    client.request(f'CAPTURE {size}')
    limit=time.monotonic()+90
    while True:
        info=client.request('STATUS')
        if info['state']!='capturing':break
        if time.monotonic()>limit:raise TimeoutError('DMA did not finish')
        time.sleep(.2)
    (root/f'{label}_status.json').write_text(json.dumps(info,indent=2)+'\n')
    validate_capture(info)
    if info['bytes']!=size:raise RuntimeError('Unexpected capture size')
    summary['capture_id']=info['capture_id']
    summary['status']=info
    debug=client.request('DEBUG');(root/f'{label}_debug.json').write_text(json.dumps(debug,indent=2)+'\n')
    hashes=[];file_stats=[]
    for attempt in range(2):
        name=root/'captures'/f'rx_2g_{label}_read{attempt+1}.bin'
        meta=download(client,name,progress=False,note='2GiB MT16JSF25664HZ-1G4F1; tested DDR3-1333 settings; original RF CONFIG2P4 unchanged')
        values=np.memmap(name,dtype='<i2',mode='r').reshape(-1,4)
        bad=[int(np.count_nonzero((values[:,i]<-2048)|(values[:,i]>2047))) for i in range(4)]
        stats={'file':str(name),'sha256':meta['sha256'],'bytes':name.stat().st_size,'tuples':len(values),'bad_I1_Q1_I2_Q2':bad,
               'min':[int(values[:,i].min()) for i in range(4)],'max':[int(values[:,i].max()) for i in range(4)],
               'nonzero':[int(np.count_nonzero(values[:,i])) for i in range(4)]}
        hashes.append(meta['sha256']);file_stats.append(stats);del values
        print(json.dumps(stats),flush=True)
    final=client.request('STATUS');summary['final_status']=final
    summary['readbacks_identical']=hashes[0]==hashes[1]
    summary['files']=file_stats
    summary['rf_registers_unchanged']=info['rf_before']==info['rf_after']
    summary['sampled_ddr_ok']=(info['debug_phases']==7 and info['debug_probe_bytes']>0 and debug['phases']==7 and bool(debug['probes']) and all(info[k]==0 for k in ['debug_changed_dma','debug_changed_pl','debug_unstable','debug_memcpy_diff']) and all(len(p['measurements'])==3 and all(len(set(m[:3]))==1 and not any(m[3:7]) for m in p['measurements']) for p in debug['probes']))
    summary['all_words_valid']=all(not any(x['bad_I1_Q1_I2_Q2']) for x in file_stats)
    summary['bd_ok']=info['debug_bd_issues']==0
    summary['checks_pass']=summary['readbacks_identical'] and summary['rf_registers_unchanged'] and summary['sampled_ddr_ok'] and summary['all_words_valid'] and summary['bd_ok']
(root/f'{label}_result.json').write_text(json.dumps(summary,indent=2)+'\n')
print('CAPTURE_RESULT',json.dumps({k:v for k,v in summary.items() if k not in ['files','status','final_status']}),flush=True)
