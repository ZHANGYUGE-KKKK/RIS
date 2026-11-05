"""Real Tk: parallel QAM pages, draft isolation, 6-bit validation and total gate."""
import unittest
import test_console_gui as baseline
from ris_qam256 import ORIENTATIONS
from ris_qam256_gui import UNIFORM_TYPE,QAM_TYPE,QAM64_TYPE

class Qam64GuiTests(unittest.TestCase):
    tearDown=baseline.ConsoleTests.tearDown
    wait=baseline.ConsoleTests.wait
    settle=baseline.ConsoleTests.settle
    writes=baseline.ConsoleTests.writes
    def setUp(self):
        baseline.ConsoleTests.setUp(self)
        self.page=self.app.qam64_page
        self.assertTrue(self.page.load(self.page.default_path),self.page.notice.get())
        self.app.open_qam(64)
        self.app.qam_orientation.set(ORIENTATIONS['identity'])
        self.app.qam_state1.set('驱动高');self.app.qam_confirmed.set(True)
        self.root.update()
    def test_parallel_pages_and_independent_drafts_no_writes(self):
        self.page.symbol.set('3F');self.page.repeats.set('2')
        self.app.qam_page.symbol.set('FF');self.app.qam_page.repeats.set('7')
        for name in (UNIFORM_TYPE,QAM_TYPE,QAM64_TYPE,QAM_TYPE,QAM64_TYPE):
            self.app.show_mt_type(name);self.root.update()
            self.assertEqual(self.app.mt_content.pack_slaves(),[self.app.mt_panels[name]])
        self.assertEqual(self.page.symbol.get(),'3F')
        self.assertEqual(self.app.qam_page.symbol.get(),'FF')
        self.assertEqual(self.writes(),[])
        self.assertEqual(baseline.Board.instances,0)
        self.assertIn('160 kHz',self.page.prepare_action().summary)
    def test_valid_range_sweep_prefix_and_global_action(self):
        self.page.source.set('测试序列00–3F');self.root.update()
        plan=self.app._prepare_action().payload
        self.assertEqual(plan.data_payload,bytes(range(64)))
        self.assertEqual(plan.modulation_order,64)
        self.assertEqual(plan.actual_pwm_hz,160000)
        self.assertIn('960,000.000 bit/s',self.page.payload_text.get())
        path=self.directory/'prefix64.txt';path.write_text('(25,0);\n(50,0);\n(75,0);')
        self.assertTrue(self.page.load_preamble(path));self.root.update()
        plan=self.app._prepare_action().payload
        self.assertEqual(len(plan.preamble.rows),3)
        self.assertEqual(plan.frame_cycles,67)
        self.page.source.set('十六进制字节序列');self.page.sequence.set('40')
        with self.assertRaises(ValueError):self.app._prepare_action()
        self.assertEqual(self.writes(),[])
        self.assertEqual(baseline.Board.instances,0)
