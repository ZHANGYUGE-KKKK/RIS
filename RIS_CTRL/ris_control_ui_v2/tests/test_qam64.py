"""64QAM Gray labels, exact period boundaries and additive firmware protocol."""
from pathlib import Path
from decimal import Decimal
import json, struct, subprocess, sys, unittest
from ris_qam256 import QamCodebook, payload_bytes, gray_decode, export_plan
from ris_qam_transport import make_plan
from ris_qam64_timing import edge_tick
from ris_mapping import RisMapping
from ris_patterns import compile_frame
from qam_device_model import DeviceModel, BACKEND

HOST=Path(__file__).resolve().parents[1]
ROOT=HOST.parents[1]

class Qam64Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.book=QamCodebook.load(ROOT/'QAM_RULES/64QAM/ris_64qam_64slice_codebook')
        cls.mapping=RisMapping.load(HOST/'mappings/ris_mapping.json')
        subprocess.run(['bash',str(BACKEND/'tests/build_host_model.sh')],check=True,stdout=subprocess.DEVNULL)

    def plan(self,data=bytes(range(64)),k=1,loop=True,prefix=()):
        return make_plan(self.book,self.mapping,0,'identity',True,k,loop,data,preamble_rows=prefix)

    def test_gray_mapping_and_reject_high_bits(self):
        b=self.book
        self.assertEqual((b.order,b.slots,b.bits_per_symbol),(64,64,6))
        for n,item in enumerate(b.symbols):
            self.assertEqual((item.i,item.q),(2*gray_decode(n>>3)-7,2*gray_decode(n&7)-7))
        self.assertEqual(payload_bytes('sweep','00','',order=64),bytes(range(64)))
        for mode,symbol,text,data in [('fixed','40','',None),('hex','00','3F 40',None),('file','00','',b'\xff')]:
            with self.assertRaises(ValueError):payload_bytes(mode,symbol,text,data,64)
        with self.assertRaises(ValueError):self.plan(b'\x40')
        with self.assertRaises(ValueError):b.frame(0,64,0)

    def test_all_source_vectors_and_1875_tick_boundaries(self):
        p=self.plan()
        self.assertEqual(p.actual_pwm_hz,160000)
        self.assertEqual((p.slot_ticks,p.slots,p.modulation_order),(1,1875,64))
        self.assertTrue(next(p.commands()).startswith('Q64BEGIN '))
        # Independent source pulse / spatial mapping oracle at each source slot.
        for symbol,(first,count) in enumerate(list(struct.iter_unpack('<HH',p.blocks[2]))[:64]):
            timeline=[]
            for fid,ticks in list(struct.iter_unpack('<HH',p.blocks[1]))[first:first+count]:
                self.assertGreaterEqual(ticks,29)
                timeline.extend([p.blocks[0][fid*52:fid*52+50]]*ticks)
            self.assertEqual(len(timeline),1875)
            for q in range(64):
                # Independent rational half-up boundary formula.
                at=(q*1875*2+64)//128
                expected=compile_frame(self.book.pattern(0,symbol,q),self.mapping)
                self.assertEqual(timeline[at],expected,(symbol,q))
        self.assertEqual(sum(edge_tick(q+1,1875,64)-edge_tick(q,1875,64) for q in range(64)),1875)

    def test_prefix_and_data_repeat_on_one_exact_clock_grid(self):
        prefix=tuple((Decimal(n),Decimal(0)) for n in (25,50,75))
        p=self.plan(b'\x00\x3f',3,True,prefix)
        self.assertEqual((p.actual_pwm_hz,p.frame_cycles,p.data_repeats),(160000,9,3))
        self.assertEqual(p.data_payload,b'\x00\x3f')
        total=0;events=list(struct.iter_unpack('<HH',p.blocks[1]));desc=list(struct.iter_unpack('<HH',p.blocks[2]))
        for token in p.payload:
            first,count=desc[token];total+=sum(n for _,n in events[first:first+count])*p.repeats
        self.assertEqual(total,9*1875)
        self.assertEqual(p.slots%1875,0)

    def test_real_c_firmware_crc_mode_stop_and_legacy_takeover(self):
        model=DeviceModel()
        try:
            status=model.command('STATUS');self.assertTrue(status['qam64_supported'])
            p=self.plan(b'\x00\x3f',2,False)
            p.check_capability(status)
            for command in p.commands():
                reply=model.command(command)
                self.assertTrue(reply['ok'],(command,reply))
            self.assertEqual((reply['qam_order'],reply['qam_crc'],reply['qam_slot_ticks']),(64,p.crc,1))
            self.assertEqual(reply['qam_period_slots'],1875)
            model.exchange('_FINISH')
            self.assertTrue(model.command('STOP')['ok'])
            self.assertTrue(model.command('QBEGIN 60 3 256 1')['ok'])
            self.assertEqual(model.command('STATUS')['qam_order'],256)
            self.assertTrue(model.command('STOP')['ok'])
            self.assertTrue(model.command('FASTHZ 1000000')['ok'])
            self.assertFalse(model.command('Q64BEGIN 2 1 1875 1')['ok'])
        finally:model.close()

    def test_bench_mode_keeps_64qam_identity_and_explicit_retiming(self):
        p=make_plan(self.book,self.mapping,0,'identity',True,1,True,b'\0',mode='bench',slot_ns='200')
        self.assertEqual((p.modulation_order,p.slot_ticks,p.slots),(64,1,3840))
        self.assertEqual(p.actual_pwm_hz,78125)
        self.assertTrue(next(p.commands()).startswith('Q64BEGIN '))
        self.assertTrue(all(n%60==0 for _,n in struct.iter_unpack('<HH',p.blocks[1])))

    def test_old_firmware_capability_rejected_before_upload(self):
        status=dict(qam_supported=True,qam_abi=1,qam_max_frames=2048,qam_max_events=32768,qam_max_payload=4096,qam_clock_hz=300000000)
        with self.assertRaises(ValueError):self.plan().check_capability(status)
