"""Independent offline vs live compilation, source all-symbol + preamble fixture."""
from pathlib import Path
from decimal import Decimal
import sys, shutil, struct
ROOT = Path(__file__).resolve().parents[1]
HOST = ROOT.parents[1]/'RIS_CTRL/ris_control_ui_v2'
sys.path[:0] = [str(HOST),str(ROOT/'scripts')]
from ris_qam256 import QamCodebook, export_plan
from ris_qam_transport import make_plan
from ris_mapping import RisMapping
from compile_qam_plan import emit_plan
b=QamCodebook.load(ROOT.parents[1]/'QAM_RULES/64QAM/ris_64qam_64slice_codebook')
m=RisMapping.load(HOST/'mappings/ris_mapping.json')
prefix=tuple((Decimal(n),Decimal(0)) for n in (0,100,25,50,75,12.5,37.5,62.5,87.5,50))
out=ROOT/'build/qam64_fixture';out.mkdir(parents=True,exist_ok=True)
export_plan(out/'source.zip',b,m,0,'identity',True,1,True,bytes(range(64)),prefix)
if (out/'compiled').exists():shutil.rmtree(out/'compiled')
r=emit_plan(out/'source.zip',out/'compiled')
p=make_plan(b,m,0,'identity',True,1,True,bytes(range(64)),preamble_rows=prefix)
for name,block in zip(('frames','events','symbols','payload'),p.blocks):
 values=[int(x,16) for x in (out/'compiled'/f'{name}.hex').read_text().split()]
 actual=bytes(values) if name=='payload' else struct.pack(f'<{len(values)}I',*values)
 assert actual==block,name
assert r['actual_pwm_hz']==160000 and r['L']==1875 and p.slot_ticks==1
print(f'QAM64_FIXTURE_PASS: {p.frames} frames, {p.events} events, 64 symbols + 10 prefix cycles, PWM 160000 Hz')
