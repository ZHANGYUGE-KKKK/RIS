"""Independent 400-bit waveform checks for host-only phase reference insertion."""
from decimal import Decimal
import hashlib,json
from pathlib import Path
import struct,sys,tempfile,unittest,zipfile,subprocess

BASE=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(BASE.parents[1]/'FPGA/ris_qam_backend/scripts'))
from compile_qam_plan import compile_plan
from ris_mapping import RisMapping
from ris_patterns import compile_frame
from ris_qam256 import QamCodebook,export_plan,phase_reference_symbols
from ris_qam_transport import make_plan
from ris_mt import parse_mt
from qam_device_model import DeviceModel,BACKEND

REF={256:bytes.fromhex('00 08 88 80'),64:bytes.fromhex('00 04 24 20')}
ROWS=parse_mt('(25,0);\n(75,0);')
DATA=b'\x01\x2a'


def expand(plan, loops=1, limit=None):
    frames=[plan.blocks[0][p:p+50] for p in range(0,len(plan.blocks[0]),52)]
    events=list(struct.iter_unpack('<HH',plan.blocks[1]))
    symbols=list(struct.iter_unpack('<HH',plan.blocks[2]))
    result=[]
    for _ in range(loops):
        for token in plan.payload:
            first,count=symbols[token]
            for _ in range(plan.repeats):
                for fid,n in events[first:first+count]:
                    take=n if limit is None else min(n,limit-len(result))
                    result.extend([frames[fid]]*take)
                    if limit is not None and len(result)==limit:return result
    return result


class PhaseCompensationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run(['bash',str(BACKEND/'tests/build_host_model.sh')],check=True,stdout=subprocess.DEVNULL)
        cls.mapping=RisMapping.load(BASE/'mappings/ris_mapping.json')
        cls.books={256:QamCodebook.load(BASE.parents[1]/'QAM_RULES/256QAM/ris_256qam_256slice_codebook_0deg.zip'),
                   64:QamCodebook.load(BASE.parents[1]/'QAM_RULES/64QAM/ris_64qam_64slice_codebook')}

    def plan(self,order,rows=(),k=3,loop=True,data=DATA,enabled=True):
        return make_plan(self.books[order],self.mapping,0,'cw90',False,k,loop,data,
                         mode='bench' if order==256 else 'source',preamble_rows=rows,phase_compensation=enabled)

    def oracle(self,order,rows,data,k):
        book=self.books[order];base=book.slots
        # Source frames and independent half-up rational timing, not the encoder.
        boundaries=[(2*q*1875+base)//(2*base) if order==64 else q for q in range(base+1)]
        result=[]
        for m,_ in rows:
            width=int(Decimal(m)*base/100+Decimal('.5'))
            for q in range(base):
                result.extend([bytes([255 if q<width else 0])*50]*(boundaries[q+1]-boundaries[q]))
        for symbol in REF[order]+data:
            cycle=[]
            for q in range(base):
                image=compile_frame(book.pattern(0,symbol,q,'cw90',False),self.mapping)
                cycle.extend([image]*(boundaries[q+1]-boundaries[q]))
            result.extend(cycle*k)
        return result

    def test_corner_ids_match_actual_book_coordinates(self):
        for order,b in self.books.items():
            self.assertEqual(phase_reference_symbols(order,True),REF[order])
            maximum=15 if order==256 else 7
            self.assertEqual([(b.symbols[s].i,b.symbols[s].q) for s in REF[order]],
                             [(-maximum,-maximum),(-maximum,maximum),(maximum,maximum),(maximum,-maximum)])
            with self.assertRaises(ValueError):phase_reference_symbols(order,1)

    def test_waveforms_order_k_and_whole_frame_repeat(self):
        for order in (256,64):
            for rows in ((),ROWS):
                for k in (1,3):
                    with self.subTest(order=order,prefix=bool(rows),k=k):
                        p=self.plan(order,rows,k)
                        expected=self.oracle(order,rows,DATA,k)
                        self.assertEqual(expand(p,2),expected*2)
                        self.assertEqual(p.data_payload,DATA)
                        self.assertEqual(p.data_repeats,k)
                        self.assertEqual(p.phase_symbols,REF[order])
                        self.assertEqual(p.frame_cycles,len(rows)+(4+len(DATA))*k)
                        self.assertEqual(p.actual_pwm_hz,160000 if order==64 else 19531.25)
                        self.assertEqual(p.phase_symbols.hex(' ').upper(), '00 04 24 20' if order==64 else '00 08 88 80')

    def test_disabled_is_identical_and_flat_payload_is_reference_then_data(self):
        for order,b in self.books.items():
            p=self.plan(order,k=2,loop=False)
            self.assertEqual(p.payload,REF[order]+DATA)
            self.assertEqual(p.repeats,2)
            off=self.plan(order,enabled=False)
            old=make_plan(b,self.mapping,0,'cw90',False,3,True,DATA,mode='bench' if order==256 else 'source')
            self.assertEqual((off.blocks,off.crc,list(off.commands())),(old.blocks,old.crc,list(old.commands())))
            self.assertEqual(off.data_payload,DATA)
            self.assertEqual(off.phase_symbols,b'')

    def test_max_formal_data_not_truncated_with_reference_overhead(self):
        for order in (256,64):
            data=b'\x00'*4096
            p=self.plan(order,k=1,loop=False,data=data)
            self.assertEqual(p.data_payload,data)
            self.assertLessEqual(len(p.payload),4096)
            self.assertEqual(p.frame_cycles,4100)
            self.assertIsNone(p.preamble)
            expected=self.oracle(order,(),b'',1)
            self.assertEqual(expand(p,limit=len(expected)),expected)

    def test_export_keeps_formal_payload_and_offline_tables_match_live(self):
        for order,b in self.books.items():
            for rows in ((),ROWS):
                p=self.plan(order,rows,k=2)
                with tempfile.TemporaryDirectory() as d:
                    path=Path(d)/'plan.zip'
                    m=export_plan(path,b,self.mapping,0,'cw90',False,2,True,DATA,rows,phase_compensation=True)
                    self.assertEqual(m['phase_compensation']['symbols'],list(REF[order]))
                    self.assertEqual(m['phase_compensation']['repeats_per_symbol'],2)
                    self.assertAlmostEqual(m['one_pass_seconds'],(len(rows)+12)/b.pwm_hz)
                    with zipfile.ZipFile(path) as z:self.assertEqual(z.read('payload.bin'),DATA)
                    r,w,f,e,s,data=compile_plan(path,*((60,True) if order==256 else ()))
                    blocks=tuple(struct.pack(f'<{len(v)}I',*v) for v in (f,e,s))+(bytes(data),)
                    self.assertEqual(blocks,p.blocks)
                    self.assertEqual(r['logical_payload_bytes'],len(DATA))
                    self.assertEqual(r['phase_compensation_cycles'],8)
                    self.assertEqual(r['phase_compensation_symbols'],list(REF[order]))
                    self.assertFalse(any(a==0x204 and v in (1,2) for a,v in w))

    def test_existing_c_firmware_accepts_phase_frames_without_new_commands(self):
        for order in (256,64):
            p=self.plan(order,ROWS,2,False)
            model=DeviceModel()
            try:
                p.check_capability(model.command('STATUS'))
                commands=list(p.commands())
                self.assertTrue(commands[0].startswith('Q64BEGIN ' if order==64 else 'QBEGIN '))
                for command in commands:
                    reply=model.command(command)
                    self.assertTrue(reply['ok'],(command,reply))
                self.assertEqual(reply['qam_crc'],p.crc)
                self.assertTrue(reply['qam_status']&1)
                self.assertFalse(reply['qam_loop'])
                self.assertTrue(model.command('STOP')['ok'])
            finally:model.close()
