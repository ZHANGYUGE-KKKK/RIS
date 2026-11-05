"""Analyze register/ILA experiments, with checks bounded to each RX batch."""
import csv
import hashlib
import json
import struct
from collections import Counter, defaultdict
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT=Path(__file__).resolve().parent
FIELDS='group arg0 arg1 pn_result axi_status_low axi_status_polls axi_status edge_delta sample_delta elapsed_ticks clock_mon clock_ratio pn_i1 pn_q1 pn_i2 pn_q2 core_control data_tap frame_tap spi_006 spi_010 spi_009 gpio_status reserved'.split()

def load_ila(path):
    with path.open() as f:
        rd=csv.reader(f); header=next(rd); radices=next(rd)
        keys=[h.rsplit('/',1)[-1].split('[')[0] for h in header]
        return [{k:int(value,16 if radix.strip()=='HEX' else 10)
                 for k,value,radix in zip(keys,row,radices)} for row in rd]

def ila_summary(paths):
    summary=dict(captures=0,valid_rows=0,status_low=0,frame_mixed=0,iq_rows=0,
                 counter_errors=0,batches=0,excluded_batches=0,
                 previous_frame_checks=0,previous_frame_errors=0,
                 valid_pipeline_checks=0,valid_pipeline_errors=0,
                 iq_deframe_checks=0,iq_deframe_errors=0,
                 sample_pack_checks=0,sample_pack_errors=0)
    frames=Counter(); runs=Counter(); spacing=Counter()
    for path in paths:
        summary['captures']+=1
        groups=defaultdict(list)
        for r in load_ila(path):
            if not r['prefifo_valid_ref']:continue
            summary['valid_rows']+=1
            summary['status_low']+=not r['prefifo_official_status_ref']
            frame=r['prefifo_raw_frame_ref'];frames[frame]+=1
            summary['frame_mixed']+=frame in (1,2)
            summary['iq_rows']+=r['prefifo_official_valid_ref']
            groups[r['prefifo_batch_ref']].append(r)
        for rows in groups.values():
            summary['batches']+=1
            bad=sum(((b['prefifo_rx_edge_counter_ref']-a['prefifo_rx_edge_counter_ref'])&0xffffff)!=1
                    or b['prefifo_index_ref']!=a['prefifo_index_ref']+1
                    for a,b in zip(rows,rows[1:]))
            summary['counter_errors']+=bad
            if bad:
                summary['excluded_batches']+=1;continue
            for a,b in zip(rows,rows[1:]):
                summary['previous_frame_checks']+=1
                summary['previous_frame_errors']+=a['prefifo_raw_frame_ref']!=b['prefifo_raw_frame_previous_ref']
            starts=[];last=None
            for i,r in enumerate(rows):
                frame=r['prefifo_raw_frame_ref']
                if frame!=last:starts.append((i,frame));last=frame
            for (a,frame),(b,_) in zip(starts[1:-1],starts[2:]):runs[f'{frame:02b}:{b-a}']+=1
            valid_indices=[i for i,r in enumerate(rows) if r['prefifo_official_valid_ref']]
            spacing.update(b-a for a,b in zip(valid_indices,valid_indices[1:]))
            known=0;predicted=0
            for i in range(1,len(rows)-2):
                r=rows[i];prior=rows[i-1];observed=rows[i+2]
                if r['prefifo_official_rst_ref'] or observed['prefifo_official_rst_ref']:continue
                pair=(r['prefifo_raw_frame_ref']<<2)|r['prefifo_raw_frame_previous_ref']
                expected_valid=int(pair==0)
                summary['valid_pipeline_checks']+=1
                summary['valid_pipeline_errors']+=expected_valid!=observed['prefifo_official_valid_ref']
                iq=((prior['prefifo_raw_data_rise_ref']<<6)|r['prefifo_raw_data_rise_ref'])<<12
                iq|=(prior['prefifo_raw_data_fall_ref']<<6)|r['prefifo_raw_data_fall_ref']
                if pair==15:
                    predicted=(predicted&~0xffffff)|iq;known|=0xffffff
                elif pair==0:
                    predicted=(predicted&0xffffff)|(iq<<24);known|=0xffffff000000
                if known==0xffffffffffff:
                    summary['iq_deframe_checks']+=1
                    summary['iq_deframe_errors']+=predicted!=observed['prefifo_official_data_ref']
            for r in rows:
                if r['prefifo_official_rst_ref']:continue
                word=r['prefifo_official_data_ref'];packed=0
                for component in range(4):
                    value=(word>>(12*component))&0xfff
                    if value&0x800:value|=0xf000
                    packed|=value<<(16*component)
                summary['sample_pack_checks']+=1
                summary['sample_pack_errors']+=packed!=r['prefifo_sample_data_ref']
    summary['frame_histogram']=dict(sorted(frames.items()))
    summary['interior_frame_run_lengths']=dict(sorted(runs.items()))
    summary['iq_valid_spacing']=dict(sorted(spacing.items()))
    return summary

if __name__=='__main__':
    header=struct.unpack('<128I',(ROOT/'arm/header_final.bin').read_bytes())
    spi=struct.unpack('<1024I',(ROOT/'arm/spi_baseline.bin').read_bytes())
    rows=[]
    for values in struct.iter_unpack('<24I',(ROOT/'arm/rows_final.bin').read_bytes()):
        row=dict(zip(FIELDS,values))
        if row['pn_result']&0x80000000:row['pn_result']-=1<<32
        row['measured_rx_mhz']=row['edge_delta']*header[21]/row['elapsed_ticks']/1e6
        row['monitor_rx_mhz']=row['clock_mon']*100/65536
        rows.append(row)
    with (ROOT/'scan_points.csv').open('w') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
    groups={}
    for group in sorted({r['group'] for r in rows}):
        points=[r for r in rows if r['group']==group];frequencies=[r['measured_rx_mhz'] for r in points]
        groups[group]=dict(points=len(points),pn_pass=sum(r['pn_result']==0 for r in points),
            frequency_min_mhz=min(frequencies),frequency_mean_mhz=sum(frequencies)/len(frequencies),
            frequency_max_mhz=max(frequencies))
    bbpll=40_000_000*spi[0x44]+40_000_000*((spi[0x41]<<16)|(spi[0x42]<<8)|spi[0x43])/2088960
    adc=bbpll/(1<<(spi[0x0a]&7)); rx=spi[3]
    sample_rate=adc/(1+((rx>>4)&3))/(1+((rx>>3)&1))/(1+((rx>>2)&1))/(1<<((rx&3)-1) if rx&3 else 1)
    ila={}
    for condition in range(7):
        paths=sorted((ROOT/'ila').glob(f'condition_{condition:02d}_*.csv'))
        ila[condition]=ila_summary(paths)
    result=dict(rows=len(rows),pn_tested=sum(r['pn_result']!=-999 for r in rows),
                pn_pass=header[7],restore_result=header[5],timer_counts_per_second=header[21],
                spi={f'{a:03x}':spi[a] for a in [2,3,6,9,10,16,17,18,0x3c,0x3d,0x3e,0x3f4,0x3f5,0x3f6]},
                bbpll_hz=bbpll,adc_hz=adc,sample_rate_hz=sample_rate,
                expected_minimum_2r2t_data_clock_hz=4*sample_rate,groups=groups,ila=ila)
    (ROOT/'analysis.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='ila'},indent=2))
    for c,s in ila.items():
        print('ILA',c,'rows',s['valid_rows'],'mixed_frame',s['frame_mixed'],'status_low',s['status_low'],
              'counter_bad',s['counter_errors'],'valid_errors',s['valid_pipeline_errors'],
              'deframe_errors',s['iq_deframe_errors'],'pack_errors',s['sample_pack_errors'])
    labels=['Original RF','Original PRBS','FRAME tap 0','FRAME tap 16','CLK inverted','Device delay 0x88','Restored RF']
    means=[groups[g]['frequency_mean_mhz'] for g in [0,6,4,4,5,5,7]]
    # Single selected rows distinguish the two points sharing a group.
    for index,condition in [(2,(4,0)),(3,(4,16)),(4,(5,1)),(5,(5,0))]:
        means[index]=next(r['measured_rx_mhz'] for r in rows if (r['group'],r['arg0'])==condition)
    fig,axes=plt.subplots(2,1,figsize=(11,7),layout='constrained')
    axes[0].bar(labels,means,color='#476a99');axes[0].axhline(4*sample_rate/1e6,color='red',linestyle='--',label='4 x configured Fs')
    axes[0].set_ylabel('Counted RX edges (MHz)');axes[0].legend();axes[0].tick_params(axis='x',labelsize=8)
    ratios=[100*ila[i]['frame_mixed']/ila[i]['valid_rows'] for i in range(7)]
    axes[1].bar(labels,ratios,color='#b46839');axes[1].set_ylabel('FRAME 01/10 (% of valid rows)');axes[1].tick_params(axis='x',labelsize=8)
    fig.suptitle('Sampling phase/delay experiments: no PRBS passing window')
    fig.savefig(ROOT/'sampling_comparison.png',dpi=160);plt.close(fig)
