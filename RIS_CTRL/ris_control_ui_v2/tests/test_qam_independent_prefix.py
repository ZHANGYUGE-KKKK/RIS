"""Full-capacity QPR1 and real firmware parser; no board access."""
from dataclasses import replace
from pathlib import Path
import struct
import subprocess
import sys
import threading
import unittest
BASE=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(BASE),str(BASE/'tests')]
from ris_qam256 import QamCodebook
from ris_qam_transport import make_plan
from ris_mapping import RisMapping
from ris_client import RisClient
from qam_device_model import DeviceModel,BACKEND

class PrefixTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run(['bash',str(BACKEND/'tests/build_host_model.sh')],check=True)
        cls.books={order:QamCodebook.load(BASE.parents[1]/f'QAM_RULES/{order}QAM/ris_{order}qam_64slice_codebook') for order in (64,256)}
        cls.mapping=RisMapping.load(BASE/'mappings/ris_mapping.json')
    def setUp(self):
        self.device=DeviceModel();self.addCleanup(self.device.close)
    def plan(self,order=256,data=None,rows=(('25','0'),('50','0'),('75','0')),k=1,phase=True,freq=120000):
        return make_plan(self.books[order],self.mapping,0,'identity',True,k,True,
                         bytes(range(order)) if data is None else data,preamble_rows=rows,
                         phase_compensation=phase,pwm_hz=freq,independent_prefix=True)
    def upload(self,plan):
        client=RisClient.__new__(RisClient);client.command=self.device.command
        reply,cancelled=client.upload_qam(plan,threading.Event())
        self.assertFalse(cancelled);self.assertEqual(reply['qam_received'],plan.total_bytes)
        return reply
    def test_user_263_cycle_frame_preserves_all_symbols(self):
        p=self.plan();r=self.upload(p)
        self.assertEqual((p.frame_cycles,p.actual_pwm_hz,len(p.payload)),(263,120000,256))
        self.assertEqual(p.payload,bytes(range(256)))
        self.assertEqual((r['qam_symbols'],r['qam_prefix_count'],r['qam_preamble_rows']),(256,7,3))
        for i,symbol in enumerate(p.phase_symbols):
            self.assertEqual(p.prefix_descriptors[(3+i)*4:(4+i)*4],p.blocks[2][symbol*4:symbol*4+4])
        self.assertEqual(r['qam_crc'],p.crc)
    def test_maximum_formal_payload_and_ten_preamble_rows_k3(self):
        for order in (64,256):
            p=self.plan(order,bytes(i%order for i in range(4096)),rows=(('0','0'),('100','0'))*5,k=3,freq=160000)
            r=self.upload(p)
            self.assertEqual((r['qam_payload'],r['qam_prefix_count'],p.frame_cycles),(4096,14,12310))
            self.assertTrue(self.device.command('STOP')['ok'])
    def test_prefix_optional_and_legacy_timing_path(self):
        for rows,phase in (((),False),((),True),((('50','0'),),False)):
            p=self.plan(data=b'\x88',rows=rows,phase=phase,freq=100)
            r=self.upload(p)
            self.assertEqual(r['qam_prefix_count'],len(rows)+(4 if phase else 0))
            self.assertFalse(p.base_period_ticks)
            self.assertTrue(self.device.command('STOP')['ok'])
    def test_old_device_rejected_before_mutation(self):
        p=self.plan();client=RisClient.__new__(RisClient)
        status=self.device.command('STATUS');status.pop('qam_prefix_supported')
        calls=[]
        def command(c):calls.append(c);return status
        client.command=command
        with self.assertRaisesRegex(ValueError,'独立前导码'):client.upload_qam(p,threading.Event())
        self.assertEqual(calls,['STATUS'])
    def test_prefix_content_and_metadata_protected_by_crc(self):
        p=self.plan()
        for metadata in (False,True):
            commands=list(p.commands())
            i=0 if metadata else next(i for i,c in enumerate(commands) if c.startswith('QDATA B'))
            if metadata:
                fields=commands[i].split();fields[6]='64';commands[i]=' '.join(fields)
            else:
                fields=commands[i].split();raw=bytearray.fromhex(fields[3]);raw[0]^=1;fields[3]=raw.hex();commands[i]=' '.join(fields)
            for c in commands[:-1]:self.assertTrue(self.device.command(c)['ok'],c[:50])
            r=self.device.command(commands[-1]);self.assertFalse(r['ok']);self.assertFalse(r['qam_status']&3)
    def test_invalid_prefix_preflight_and_incomplete_upload(self):
        p=self.plan();bad=replace(p,prefix_descriptors=struct.pack('<HH',p.events,1)+p.prefix_descriptors[4:])
        commands=list(bad.commands())
        for c in commands[:-1]:
            r=self.device.command(c)
            if not r['ok']:break
        self.assertFalse(r['ok'])
        self.assertFalse(self.device.command(commands[-1])['ok'])
        self.assertTrue(self.device.command('STOP')['ok'])
        # Firmware may accept a well formed descriptor with a wrong duration;
        # preflight must reject it before any output ownership.
        events=p.blocks[1]+struct.pack('<HH',0,p.slots+1)
        bad=replace(p,blocks=(p.blocks[0],events,p.blocks[2],p.payload),prefix_descriptors=struct.pack('<HH',p.events,1)+p.prefix_descriptors[4:])
        commands=list(bad.commands())
        for c in commands[:-1]:self.assertTrue(self.device.command(c)['ok'],c[:50])
        r=self.device.command(commands[-1]);self.assertFalse(r['ok']);self.assertEqual(r['qam_error'],3)
        self.assertFalse(r['qam_status']&3)

if __name__=='__main__':unittest.main()
