"""Frequency edits are drafts; long header content stays within its panels."""
import unittest
import test_console_gui as baseline
from ris_qam256 import ORIENTATIONS


class FrequencyGuiTests(unittest.TestCase):
    tearDown = baseline.ConsoleTests.tearDown
    wait = baseline.ConsoleTests.wait
    writes = baseline.ConsoleTests.writes

    def setUp(self):
        baseline.ConsoleTests.setUp(self)
        self.app.qam_orientation.set(ORIENTATIONS['identity'])
        self.app.qam_state1.set('驱动高')
        self.app.qam_confirmed.set(True)

    def test_both_frequency_drafts_export_preview_and_invalid_apply(self):
        for order, value, expected in ((256, '9.765625', 9765.625), (64, '150', 150000)):
            with self.subTest(order=order):
                p = self.app.qam_page if order==256 else self.app.qam64_page
                self.assertTrue(p.load(p.default_path))
                self.app.open_qam(order)
                p.tabs.select(1)
                p.pwm_frequency.set(value)
                p.pwm_unit.set('kHz')
                self.root.update()
                action = p.prepare_action()
                self.assertEqual(action.payload.actual_pwm_hz, expected)
                self.assertIn('实际PWM', p.frequency_preview.get())
                self.assertEqual(self.writes(), [])
                self.assertEqual(baseline.Board.instances, 0)
                p.pwm_frequency.set('1000000')
                self.root.update()
                self.assertIn('支持', self.app.pending_text.get())
                self.assertTrue(self.app.apply_button.instate(['disabled']))
                self.assertFalse(self.app.apply_current())
                p.action.set('stop')
                self.assertEqual(p.prepare_action().payload, 'STOP')
                p.action.set('play')
                p.pwm_frequency.set(value)
                self.root.update()
        self.app.open_qam()
        self.assertEqual(self.app.qam_page.pwm_frequency.get(), '9.765625')
        self.assertEqual(self.app.qam64_page.pwm_frequency.get(), '150')

    def test_responsive_status_and_pending_text_do_not_clip(self):
        self.root.deiconify()
        for width in (1460, 1180):
            self.root.geometry(f'{width}x980')
            self.root.update()
            self.app.status_title.set('64QAM帧循环 · 含前导码及相偏补偿')
            self.app.status_detail.set('PWM 160 kHz · 前导10周期 + 相偏00 04 24 20×K3 + 正式4096符号×K3 · CRC 12345678 · 输出已使能')
            self.app.status_meta.set('板端确认 · 帧数 123456789 · 10:50:19 · 64QAM已完成校验，当前运行正常')
            self.app.pending_text.set('当前256QAM输出PWM频率超出支持范围，请设置为1.171875 Hz～40.4094828 kHz。参数只在点击下发指令后应用。')
            self.root.update()
            for panel, labels in ((self.app.status_panel, (self.app.monitor_title, self.app.monitor_detail, self.app.monitor_meta)),
                                  (self.app.output_panel, (self.app.apply_button, self.app.pending_label))):
                for label in labels:
                    self.assertGreaterEqual(label.winfo_height(), label.winfo_reqheight())
                    self.assertLessEqual(label.winfo_y()+label.winfo_height(), panel.winfo_height())
                    self.assertLessEqual(label.winfo_x()+label.winfo_width(), panel.winfo_width())
            self.assertGreater(self.app.status_panel.winfo_width(), 440)
            self.assertGreater(self.app.output_panel.winfo_height(), 160)
        self.assertEqual(self.writes(), [])

    def test_import_preserves_frequency_and_revalidates_slice_grid(self):
        p = self.app.qam_page
        p.pwm_frequency.set('160'); p.pwm_unit.set('kHz')
        from pathlib import Path
        book64 = Path(p.default_path).parent/'ris_256qam_64slice_codebook'
        self.assertTrue(p.load(book64))
        self.app.open_qam(); self.root.update()
        self.assertEqual(p.prepare_action().payload.actual_pwm_hz, 160000)
        self.assertTrue(p.load(p.default_path))
        self.root.update()
        self.assertEqual(p.pwm_frequency.get(), '160')
        self.assertIn('256 slice', self.app.pending_text.get())
        self.assertFalse(self.app.apply_current())
        p.pwm_frequency.set('40')
        self.root.update()
        self.assertEqual(p.prepare_action().payload.actual_pwm_hz, 40000)
        self.assertEqual(self.writes(), [])


if __name__ == '__main__': unittest.main()
