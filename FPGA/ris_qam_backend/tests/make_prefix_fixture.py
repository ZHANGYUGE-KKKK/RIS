#!/usr/bin/env python3
"""User's exact 263-cycle frame and a 10-row/K3/64QAM fixture."""
from pathlib import Path
import json
import shutil
import struct
import sys
ROOT=Path(__file__).resolve().parents[1]
HOST=ROOT.parents[1]/'RIS_CTRL/ris_control_ui_v2'
sys.path[:0]=[str(HOST),str(ROOT/'scripts')]
from ris_qam256 import QamCodebook,export_plan
from ris_mapping import RisMapping
from ris_qam_transport import make_plan
from compile_qam_plan import emit_plan,compile_plan
mapping=RisMapping.load(HOST/'mappings/ris_mapping.json')
for name,order,rows,k,freq,data in (
 ('user256',256,[('25','0'),('50','0'),('75','0')],1,120000,bytes(range(256))),
 ('full64',64,[(str(m),'0') for m in (0,100,25,50,75,12.5,87.5,37.5,62.5,50)],3,160000,bytes(range(64))),
):
 book=QamCodebook.load(ROOT.parents[1]/f'QAM_RULES/{order}QAM/ris_{order}qam_64slice_codebook')
 out=ROOT/'build/prefix_fixture'/name
 out.mkdir(parents=True,exist_ok=True)
 archive=out/'plan.zip'
 export_plan(archive,book,mapping,0,'identity',True,k,True,data,rows,True,freq,independent_prefix=True)
 plan=make_plan(book,mapping,0,'identity',True,k,True,data,preamble_rows=rows,phase_compensation=True,pwm_hz=freq,independent_prefix=True)
 target=out/'compiled'
 if target.exists():shutil.rmtree(target)
 report=emit_plan(archive,target)
 _,writes,*_=compile_plan(archive)
 # Offline export and live upload must describe the same memories.
 for address,block,size in zip((0x240,0x244,0x248,0x268,0x24c),plan.upload_blocks,(4,4,4,4,1)):
  actual=b''.join(int(v).to_bytes(size,'little') for a,v in writes if a==address)
  assert actual==block,(name,hex(address))
 # Independent oracle from source slot patterns, not compiled F/E/S/B tables.
 # Build expected waveform runs by sampling all 400 mapped bits at q=0..63.
 source=[]
 for symbol in data.__class__(range(order)):
  values=[book.pattern(0,symbol,q,'identity',True) for q in range(book.slots)]
  from ris_patterns import compile_frame
  values=[compile_frame(v,mapping) for v in values]
  source.append(values)
 physical_frames=[plan.blocks[0][i:i+50] for i in range(0,len(plan.blocks[0]),52)]
 expected=[]
 period=plan.slots
 def add_cycle(values):
  start=0
  for q in range(1,len(values)+1):
   if q==len(values) or values[q]!=values[start]:
    a=(2*start*period+book.slots)//(2*book.slots)
    b=(2*q*period+book.slots)//(2*book.slots)
    expected.append((physical_frames.index(values[start]),b-a));start=q
 for width in plan.preamble.widths:
  add_cycle([b'\xff'*50 if q<width else bytes(50) for q in range(book.slots)])
 for symbol in plan.phase_symbols+data:
  for _ in range(k):add_cycle(source[symbol])
 (target/'oracle.hex').write_text(''.join(f'{duration<<16|fid:08x}\n' for fid,duration in expected))
 # Extra fixture parameters: period, number of prefix entries, preamble rows, oracle events.
 (target/'prefix_dimensions.hex').write_text(''.join(f'{v:08x}\n' for v in (period,len(plan.prefix_descriptors)//4,len(rows),len(expected))))
 assert sum(n for _,n in expected)==plan.frame_cycles*period
 (out/'validation.json').write_text(json.dumps(dict(cycles=plan.frame_cycles,events=len(expected),pwm_hz=plan.actual_pwm_hz,upload_bytes=plan.total_bytes,crc=f'{plan.crc:08X}'),indent=2)+'\n')
 print('PREFIX_FIXTURE_PASS',name,plan.frame_cycles,'cycles',len(expected),'events')
