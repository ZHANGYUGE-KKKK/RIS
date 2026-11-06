"""Checkbox edits stay local; both QAM pages show correct frame overhead."""
import json,unittest,zipfile
import test_console_gui as baseline
from ris_qam256 import ORIENTATIONS

class PhaseGuiTests(unittest.TestCase):
    tearDown=baseline.ConsoleTests.tearDown
    wait=baseline.ConsoleTests.wait
    settle=baseline.ConsoleTests.settle
    writes=baseline.ConsoleTests.writes
    def setUp(self):
        baseline.ConsoleTests.setUp(self)
        self.app.qam_orientation.set(ORIENTATIONS['identity'])
        self.app.qam_state1.set('驱动高');self.app.qam_confirmed.set(True)

    def test_checkbox_is_offline_and_independent_with_correct_order_k_and_export(self):
        for order,refs in ((256,b'\x00\x08\x88\x80'),(64,b'\x00\x04\x24\x20')):
            with self.subTest(order=order):
                p=self.app.qam_page if order==256 else self.app.qam64_page
                self.assertTrue(p.load(p.default_path));self.app.open_qam(order)
                p.tabs.select(1);p.symbol.set('01');p.repeats.set('2');self.root.update()
                self.assertFalse(p.phase_compensation.get())
                p.phase_checkbox.invoke();self.root.update()
                self.assertTrue(p.phase_compensation.get())
                self.assertEqual(p.symbol.get(),'01')
                self.assertEqual(p.sequence.get(),'00 11 22 33 44 55 66 77 88 99 AA BB CC DD EE FF' if order==256 else '00 01 07 08 1B 3F')
                self.assertIn('相偏补偿4点',p.payload_text.get())
                self.assertIn('一帧512 µs' if order==256 else '一帧62.5 µs',p.payload_text.get())
                plan=self.app._prepare_action().payload
                self.assertEqual(plan.payload,refs+b'\x01')
                self.assertEqual(plan.data_payload,b'\x01')
                self.assertEqual(plan.frame_cycles,10)
                path=self.directory/f'phase{order}.zip'
                self.assertTrue(p.export(path))
                with zipfile.ZipFile(path) as z:
                    manifest=json.loads(z.read('manifest.json'))
                    self.assertEqual(z.read('payload.bin'),b'\x01')
                    self.assertEqual(manifest['phase_compensation']['symbols'],list(refs))
                p.phase_checkbox.invoke();self.root.update()
                self.assertFalse(p.phase_compensation.get())
                self.assertEqual(plan.phase_symbols,refs)
                self.assertEqual(self.writes(),[])
                self.assertEqual(baseline.Board.instances,0)
