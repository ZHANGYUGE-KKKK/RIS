"""Delayed uniform prefixes: source-phase oracle, offline exports and presets."""
from copy import deepcopy
from decimal import Decimal, ROUND_HALF_UP
import hashlib
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import zipfile

BASE = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(BASE), str(BASE.parents[1]/'FPGA/ris_qam_backend/scripts')]
from compile_qam_plan import compile_plan
from ris_actions import OutputAction
from ris_mapping import RisMapping
from ris_mt import parse_mt
from ris_presets import action_from_document, document_for_action
from ris_qam256 import QamCodebook, export_plan
from ris_qam_preamble import Preamble
from ris_qam_transport import make_plan

ROWS = parse_mt('(25,25);\n(50,50);\n(0,100);\n(100,0);\n(12.5,37.5);\n(75,25);\n(49.21875,50.78125);')


class DelayTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mapping = RisMapping.load(BASE/'mappings/ris_mapping.json')
        cls.books = {order: QamCodebook.load(BASE.parents[1]/f'QAM_RULES/{order}QAM/ris_{order}qam_64slice_codebook')
                     for order in (64, 256)}

    def plan(self, order, frequency=120000, rows=ROWS):
        return make_plan(self.books[order], self.mapping, 0, 'identity', True, 3, True, bytes(range(order)),
                         preamble_rows=rows, phase_compensation=True, pwm_hz=frequency, independent_prefix=True)

    def test_nonwrapping_grid_and_rounding_boundary(self):
        prefix = Preamble.compile(parse_mt('(50,50);\n(0,100);\n(100,0);'), 125)
        self.assertEqual(prefix.delays, (63,125,0))
        self.assertEqual(prefix.widths, (62,0,125))
        self.assertEqual(prefix.runs(0), ((0,63),(1,62)))
        self.assertEqual(prefix.runs(1), ((0,125),))
        self.assertEqual(prefix.runs(2), ((1,125),))
        for rows in (parse_mt('(50,50.01);'), parse_mt('(0,100);')*11,
                     ((Decimal(25),Decimal('NaN')),), ((Decimal(-1),Decimal(0)),)):
            with self.assertRaises(ValueError): Preamble.compile(rows,64)

    def test_both_qam_orders_timing_modes_and_all_400_prefix_bits(self):
        for order in (64,256):
            for frequency in (120000,100):
                plan = self.plan(order,frequency)
                frames = [plan.blocks[0][i:i+50] for i in range(0,len(plan.blocks[0]),52)]
                events = tuple(struct.iter_unpack('<HH',plan.blocks[1]))
                prefix = tuple(struct.iter_unpack('<HH',plan.prefix_descriptors))
                slots, period = self.books[order].slots, plan.slots
                for i,(m,t) in enumerate(ROWS):
                    # Independent oracle from input phase percentages and source
                    # slot boundaries, without the prefix compiler's runs helper.
                    start = int((t*slots/100).to_integral_value(rounding=ROUND_HALF_UP))
                    width = min(int((m*slots/100).to_integral_value(rounding=ROUND_HALF_UP)),slots-start)
                    expected = []
                    for q in range(slots):
                        a,b = ((2*q*period+slots)//(2*slots),(2*(q+1)*period+slots)//(2*slots))
                        expected.extend([b'\xff'*50 if start<=q<start+width else bytes(50)]*(b-a))
                    first,count = prefix[i]
                    actual = [frames[fid] for fid,n in events[first:first+count] for _ in range(n)]
                    self.assertEqual(actual,expected,(order,frequency,i))
                    self.assertEqual(sum(n for _,n in events[first:first+count]),period)
                self.assertEqual(plan.payload,bytes(range(order)))
                self.assertEqual(plan.frame_cycles,len(ROWS)+(4+order)*3)
                self.assertEqual(len(plan.blocks[2]),1024)

    def test_delay_metadata_and_memory_match_json_and_zip_compilation(self):
        for order in (64,256):
            plan = self.plan(order)
            document = document_for_action(OutputAction('qam',plan,'延时前导码'))
            self.assertEqual(action_from_document(document).payload,plan)
            damaged = deepcopy(document)
            damaged['action']['payload']['preamble']['rows'][0][1] = '50'
            with self.assertRaisesRegex(ValueError,'前导码'): action_from_document(damaged)
            with tempfile.TemporaryDirectory() as temp:
                path = Path(temp)/'delayed.zip'
                manifest = export_plan(path,self.books[order],self.mapping,0,'identity',True,3,True,
                                       bytes(range(order)),ROWS,True,120000,independent_prefix=True)
                self.assertFalse(manifest['preamble']['delay_zero'])
                self.assertEqual(manifest['preamble']['delay_slots'],list(plan.preamble.delays))
                with zipfile.ZipFile(path) as archive:
                    self.assertEqual(parse_mt(archive.read('preamble_mt.txt').decode()),ROWS)
                _,writes,*_ = compile_plan(path)
                for address,block,size in zip((0x240,0x244,0x248,0x268,0x24c),plan.upload_blocks,(4,4,4,4,1)):
                    actual = b''.join(v.to_bytes(size,'little') for a,v in writes if a==address)
                    self.assertEqual(actual,block)

    def test_old_zero_delay_offline_zip_remains_compatible(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)/'legacy_prefix.zip'
            rows = parse_mt('(25,0);\n(75,0);')
            export_plan(path,self.books[256],self.mapping,0,'identity',True,3,True,b'\x3f',rows,
                        False,120000,independent_prefix=True)
            with zipfile.ZipFile(path) as archive:
                files = {name:archive.read(name) for name in archive.namelist() if name!='SHA256SUMS.txt'}
            manifest = json.loads(files['manifest.json'])
            del manifest['preamble']['delay_slots']
            files['manifest.json'] = json.dumps(manifest).encode()
            files['SHA256SUMS.txt'] = ''.join(f'{hashlib.sha256(raw).hexdigest()}  {name}\n' for name,raw in files.items()).encode()
            with zipfile.ZipFile(path,'w') as archive:
                for name,raw in files.items(): archive.writestr(name,raw)
            _,writes,*_ = compile_plan(path)
            self.assertEqual(sum(a==0x268 for a,_ in writes),2)


if __name__ == '__main__': unittest.main()
