"""Read-only compilation regression for 64QAM source and explicit bench timing."""
from pathlib import Path
import sys,tempfile,struct
root=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(root/'RIS_CTRL/ris_control_ui_v2'),str(root/'FPGA/ris_qam_backend/scripts')]
from ris_qam256 import QamCodebook,export_plan
from ris_qam_transport import make_plan
from ris_mapping import RisMapping
from ris_mt import parse_mt
from compile_qam_plan import compile_plan
b=QamCodebook.load(root/'QAM_RULES/64QAM/ris_64qam_64slice_codebook')
m=RisMapping.load(root/'RIS_CTRL/ris_control_ui_v2/mappings/ris_mapping.json')
prefix=parse_mt('(25,0);\n(50,0);\n(75,0);')
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'plan.zip';export_plan(p,b,m,0,'identity',True,2,True,b'\x00\x1b\x3f',prefix)
 for mode,args in [('source',()),('bench',(60,True))]:
  live=make_plan(b,m,0,'identity',True,2,True,b'\x00\x1b\x3f',mode=mode,preamble_rows=prefix)
  r,w,f,e,s,payload=compile_plan(p,*args)
  blocks=tuple(struct.pack(f'<{len(v)}I',*v) for v in (f,e,s))+(bytes(payload),)
  assert blocks==live.blocks
  assert r['actual_pwm_hz']==live.actual_pwm_hz
  assert r['L']==live.slots and r['slot_ticks']==live.slot_ticks
  assert (0x250,64) in w
  print('PASS 64QAM offline/live source/bench, prefix and exact physical registers:',mode,r['actual_pwm_hz'])
