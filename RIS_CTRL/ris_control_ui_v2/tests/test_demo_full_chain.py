"""Demo presets through the actual TCP client and C firmware model, localhost only."""
from pathlib import Path
import subprocess
import unittest
import test_qam_full_chain as chain
from qam_device_model import BACKEND

class DemoFullChainTests(unittest.TestCase):
    setUp=chain.FullChainTests.setUp
    tearDown=chain.FullChainTests.tearDown
    wait=chain.FullChainTests.wait
    connect=chain.FullChainTests.connect
    apply=chain.FullChainTests.apply
    writes=chain.FullChainTests.writes
    @classmethod
    def setUpClass(cls):
        subprocess.run(['bash',str(BACKEND/'tests/build_host_model.sh')],check=True)
    def export_qam(self,order,row):
        self.app.open_qam(order);p=self.app.active_qam_page()
        book=p.default_path.parent/'ris_256qam_64slice_codebook' if order==256 else p.default_path
        self.assertTrue(p.load(book));p.source.set('测试序列00–FF' if order==256 else '测试序列00–3F')
        p.repeats.set('1');p.loop.set(True);p.pwm_frequency.set('120' if order==256 else '160');p.pwm_unit.set('kHz')
        p.phase_compensation.set(True)
        prefix=self.directory/f'prefix_{order}.txt';prefix.write_text('(25,0);\n(50,0);\n(75,0);')
        self.assertTrue(p.load_preamble(prefix));expected=p.prepare_action().payload
        path=self.directory/f'演示{order}QAM.json';self.assertTrue(self.app.export_config(path))
        self.assertTrue(self.app.demo_page.load(row,path));return expected
    def test_two_qam_modes_keep_complete_prefix_phase_data_and_same_crc(self):
        plans=[self.export_qam(256,0),self.export_qam(64,1)]
        self.app.show_page('demo');self.assertEqual(self.writes(),[]);self.connect();self.assertEqual(self.writes(),[])
        for i,plan in enumerate(plans):
            before=list(self.writes());self.app.demo_page.select(i);self.root.update()
            self.assertEqual(self.writes(),before)
            self.assertTrue(self.app.apply_current());self.wait(lambda:not self.app.busy,timeout=20)
            self.assertTrue(self.app.connected,self.app.notice.get())
            self.assertEqual(self.app.latest['qam_crc'],plan.crc)
            self.assertEqual(self.app.latest['qam_prefix_count'],7)
            self.assertEqual(self.app.latest['qam_payload'],len(plan.payload))
            self.assertIn(str(plan.modulation_order)+'QAM',self.app.status_title.get())
            self.assertEqual(self.app.applied_action.payload,plan)
    def test_selection_during_qam_upload_does_not_change_active_snapshot(self):
        first=self.export_qam(256,0);second=self.export_qam(64,1)
        self.app.show_page('demo');p=self.app.demo_page;p.select(0);self.connect()
        self.server.gate='QDATA';self.assertTrue(self.app.apply_current());self.wait(self.server.blocked.is_set)
        p.select(1);self.root.update();self.server.release.set();self.wait(lambda:not self.app.busy,timeout=20)
        self.assertEqual(self.app.latest['qam_crc'],first.crc)
        self.assertEqual(self.app.applied_action.payload,first)
        self.assertEqual(p.prepare_action().payload,second)
        self.assertEqual(sum(c.startswith('QSTART') for c in self.writes()),1)
    def test_qam_upload_cancel_from_demo_requires_total_button_and_no_start(self):
        self.export_qam(256,0);self.app.show_page('demo');p=self.app.demo_page;p.select(0);self.connect()
        self.server.gate='QDATA';self.app.apply_current();self.wait(self.server.blocked.is_set)
        p.stage_stop();self.root.update();self.assertEqual(self.app.apply_button.cget('text'),'取消上传并停止')
        self.assertTrue(self.app.apply_current());self.server.release.set();self.wait(lambda:not self.app.busy,timeout=20)
        self.assertFalse(any(c.startswith('QSTART') for c in self.writes()));self.assertEqual(self.writes()[-1],'STOP')
        self.assertFalse(self.app.latest['qam_uploading'])

if __name__=='__main__':unittest.main()
