"""Event evidence and bounded in-batch tone test; excludes stale timeout data."""
import csv
import json
from collections import defaultdict
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from analyze_ila import analyze

ROOT = Path(__file__).resolve().parent

def load(path):
    with path.open() as f:
        reader=csv.reader(f)
        header=next(reader); radices=next(reader)
        keys=[h.rsplit('/',1)[-1].split('[')[0] for h in header]
        return [{k:int(v, 16 if radix.strip()=='HEX' else 10)
                 for k,v,radix in zip(keys,row,radices)} for row in reader]

if __name__ == '__main__':
    valid=[ROOT/'ila'/f'event_{n:02d}.csv' for n in [0,1,2,3,5]]
    events={p.name:analyze([p]) for p in valid}
    (ROOT/'event_analysis.json').write_text(json.dumps(events,indent=2)+'\n')
    (ROOT/'invalid_captures.json').write_text(json.dumps({
        'event_04.csv': 'Trial 4 failed its GPIO readiness recheck before issuing ARM. ILA did not trigger; the original timeout handling exported the previous capture. SHA256 equals event_03.csv. Excluded from all evidence and statistics.',
        'event_04.ila': 'Same stale timeout data; do not use as trial 4 evidence.'
    },indent=2)+'\n')
    tone={}
    for name in ['event_03.csv','event_05.csv']:
        groups=defaultdict(list)
        for r in load(ROOT/'ila'/name):
            if r['prefifo_valid_ref']: groups[r['prefifo_batch_ref']].append(r)
        checks=errors=skipped=tuples=0
        for rows in groups.values():
            if any(((b['prefifo_rx_edge_counter_ref']-a['prefifo_rx_edge_counter_ref'])&0xffffff)!=1
                   for a,b in zip(rows,rows[1:])):
                skipped+=1; continue
            data=[r['prefifo_official_data_ref'] for r in rows
                  if r['prefifo_official_valid_ref'] and not r['prefifo_official_rst_ref']]
            tuples+=len(data)
            for n in range(16,len(data)):
                for c in range(4):
                    checks+=1
                    errors+=((data[n]>>(12*c))&0xfff)!=((data[n-16]>>(12*c))&0xfff)
        tone[name]=dict(valid_tuples=tuples,component_checks=checks,
                        component_mismatches=errors,skipped_bad_counter_batches=skipped)
    (ROOT/'tone_period_analysis.json').write_text(json.dumps({
        'method':'Project BIST Fs/16 test: compare each component with 16 valid tuples earlier, only within one batch with consecutive RX counters. No joins across batches. This checks the recorded IQ sequence, not completed DMA payload.',
        'captures':tone},indent=2)+'\n')

    rows=[r for r in load(ROOT/'ila/event_02.csv')
          if r['prefifo_valid_ref'] and r['prefifo_batch_ref']==18796]
    signals=[('prefifo_raw_frame_ref','FRAME_DDR'),
             ('prefifo_raw_frame_previous_ref','FRAME_PREVIOUS'),
             ('prefifo_official_status_ref','ADI_STATUS'),
             ('prefifo_armed_rx_ref','ARM'),
             ('prefifo_frame_error_rx_ref','FRAME_ERROR')]
    fig,axes=plt.subplots(5,1,figsize=(11,6),sharex=True,layout='constrained')
    x=[r['prefifo_index_ref'] for r in rows]
    for ax,(key,label) in zip(axes,signals):
        ax.step(x,[r[key] for r in rows],where='post',linewidth=1.7)
        ax.axvspan(14,15,color='orange',alpha=.2)
        ax.axvline(15,color='red',alpha=.5,linestyle='--')
        ax.set_ylabel(label,rotation=0,ha='right',va='center',fontsize=9)
        ax.set_yticks([0,1,2,3] if 'frame_ref' in key or 'previous_ref' in key else [0,1])
        ax.grid(alpha=.2)
    axes[-1].set_xlabel('Original RX-cycle index within one 64-cycle recorder batch')
    axes[-1].set_xlim(5,25)
    fig.suptitle('Captured fault: ADI_STATUS=0 at index 14; FRAME_ERROR latches at index 15\nevent_02.csv, batch 18796, consecutive RX counters')
    fig.savefig(ROOT/'frame_error_event.png',dpi=170)
    plt.close(fig)
    with (ROOT/'frame_error_event_rows.csv').open('w') as f:
        fields=['prefifo_index_ref','prefifo_rx_edge_counter_ref']+[s[0] for s in signals]
        writer=csv.DictWriter(f,fieldnames=fields);writer.writeheader()
        writer.writerows({k:r[k] for k in fields} for r in rows)
    print('Saved five valid event summaries, tone comparison and fault plot.')
