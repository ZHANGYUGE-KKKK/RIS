"""Hidden Tk window and fake board: no connection to physical hardware."""
from pathlib import Path
import sys
import tempfile
import time
import tkinter as tk
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parents[1] / 'host'))
from ris_gui import RisGui
from test_ris_manual_control import Client


class MTClient(Client):
    reject_segment = False
    bad_ack = False
    def __init__(self, *args):
        super().__init__(*args)
        self.loaded, self.running, self.period = 0, False, 300

    def command(self, command):
        fields = command.split()
        if fields[0] == 'MTBEGIN':
            self.loaded, self.running, self.period = 0, False, int(fields[3])
        if fields[0] == 'MTSEG':
            self.loaded += 1
        if fields[0] == 'MTSTART':
            self.running = True
        if fields[0] == 'STOP':
            self.running = False
        reply = super().command(command)
        reply.update(fast_supported=True, fast_variable=True, fast_mhz=0, fast_ticks=0, fast_edges=0,
                     mt_supported=True, mt_running=self.running, mt_period=self.period,
                     mt_loaded=self.loaded + (1 if self.bad_ack else 0))
        if self.reject_segment and fields[0] == 'MTSEG':
            reply.update(ok=False, rc=-3)
        return reply


class MTGuiTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / 'table.txt'
        self.path.write_text('(50,10);\n(30,0);')
        self.patch = patch('ris_gui.RisClient', MTClient)
        self.patch.start()
        MTClient.reject_segment = MTClient.bad_ack = False
        Client.commands = []
        self.root = tk.Tk()
        self.root.withdraw()
        self.app = RisGui(self.root, pattern_storage=self.temp.name)
        self.app.mapping_page.storage_dir = Path(self.temp.name)
        self.app.mapping_page.recovery_path = Path(self.temp.name) / 'recovery.json'
        self.root.after_cancel(self.app.poll_timer)  # deterministic command/ACK tests
        self.app.fast_value.set('1')
        self.app.fast_unit.set('M')

    def tearDown(self):
        self.app.mapping_page.close(discard=True)
        self.app.close()
        self.patch.stop()
        self.temp.cleanup()

    def wait(self, predicate):
        end = time.monotonic() + 10
        while time.monotonic() < end:
            self.root.update()
            if predicate():
                return
            time.sleep(.005)
        self.fail(self.app.notice.get())

    def connect(self):
        self.app.connect()
        self.wait(lambda: self.app.connected and not self.app.busy)

    def test_load_edit_preview_dont_send_and_existing_frequency_is_retained(self):
        self.assertTrue(self.app.mt_controls.load(self.path))
        self.assertEqual(self.app.fast_value.get(), '1')
        self.app.mt_controls.loop.set(False)
        self.app.preview_frequency()
        self.assertIn('播放一次', self.app.fast_notice.get())
        self.assertFalse(Client.commands)
        self.assertEqual(self.app.mt_controls.mode.get(), 'uniform')
        self.path.write_text('(101,0);')
        self.assertFalse(self.app.mt_controls.load(self.path))
        self.assertEqual(len(self.app.mt_controls.rows), 2)

    def test_upload_order_ack_then_start_shared_worker(self):
        self.connect()
        self.app.mt_controls.load(self.path)
        plan = self.app.mt_controls.plan()
        self.assertTrue(self.app.start_fast())
        self.wait(lambda: not self.app.busy)
        self.assertEqual([c for c in Client.commands if c != 'STATUS'], list(plan.commands()))
        self.assertTrue(self.app.latest['mt_running'])
        self.assertIn('MT 统一播放', self.app.state.get())
        self.app.command('STOP')
        self.wait(lambda: not self.app.busy)
        self.assertFalse(self.app.latest['mt_running'])

    def test_loop_button_uploads_once_and_stops_on_explicit_stop(self):
        self.connect()
        self.app.mt_controls.load(self.path)
        self.app.mt_controls.loop.set(False)
        self.app.mt_controls.loop_button.invoke()
        self.wait(lambda: not self.app.busy)
        commands = [c for c in Client.commands if c != 'STATUS']
        self.assertEqual(commands, list(self.app.mt_controls.plan().commands()))
        self.assertEqual(len([c for c in commands if c.startswith('MTBEGIN ')]), 1)
        self.assertTrue(commands[-1].startswith('MTSTART 1 '))
        self.assertIn('FPGA 正在循环整表', self.app.notice.get())
        # Polling during playback reads status; the GUI never re-uploads a tour.
        self.app.submit('poll')
        self.wait(lambda: not self.app.busy)
        self.assertEqual([c for c in Client.commands if c != 'STATUS'], commands)
        self.app.mt_controls.stop_button.invoke()
        self.wait(lambda: not self.app.busy)
        self.assertEqual(Client.commands[-1], 'STOP')
        self.assertFalse(self.app.latest['mt_running'])

    def test_once_button_overrides_loop_default_and_requires_a_table(self):
        self.connect()
        self.assertTrue(self.app.mt_controls.loop_button.instate(['disabled']))
        self.app.mt_controls.load(self.path)
        self.assertTrue(self.app.mt_controls.loop.get())
        self.app.mt_controls.once_button.invoke()
        self.wait(lambda: not self.app.busy)
        self.assertTrue(Client.commands[-1].startswith('MTSTART 0 '))
        self.assertFalse(self.app.mt_controls.loop.get())
        self.assertIn('播放一次', self.app.notice.get())
        self.app.mt_controls.clear()
        self.assertTrue(self.app.mt_controls.once_button.instate(['disabled']))
        self.assertTrue(self.app.mt_controls.loop_button.instate(['disabled']))

    def test_old_firmware_and_unachievable_pulse_never_upload(self):
        self.connect()
        self.app.mt_controls.load(self.path)
        self.app.latest['mt_supported'] = False
        self.assertFalse(self.app.start_fast())
        self.app.latest['mt_supported'] = True
        self.app.fast_value.set('5')
        self.assertFalse(self.app.start_fast())
        self.assertTrue(all(c == 'STATUS' for c in Client.commands))

    def test_error_or_bad_ack_prevents_start(self):
        self.connect()
        self.app.mt_controls.load(self.path)
        MTClient.reject_segment = True
        self.app.start_fast()
        self.wait(lambda: not self.app.busy)
        self.assertFalse(any(c.startswith('MTSTART') for c in Client.commands))
        self.assertFalse(self.app.connected)
        MTClient.reject_segment = False
        MTClient.bad_ack = True
        self.connect()
        self.app.start_fast()
        self.wait(lambda: not self.app.busy)
        self.assertFalse(any(c.startswith('MTSTART') for c in Client.commands))

    def test_cancel_does_not_send_start(self):
        self.connect()
        self.app.mt_controls.load(self.path)
        self.app.mt_cancel.set()
        self.app.mt_uploading = True
        self.app.submit('mt', self.app.mt_controls.plan())
        self.wait(lambda: not self.app.busy)
        self.assertEqual([c for c in Client.commands if c != 'STATUS'], ['STOP'])
        self.assertIn('已取消', self.app.notice.get())

    def test_clear_table_restores_legacy_fast_command(self):
        self.connect()
        self.app.mt_controls.load(self.path)
        self.app.mt_controls.clear()
        self.app.start_fast()
        self.wait(lambda: not self.app.busy)
        self.assertEqual(Client.commands[-1], 'FASTTICKS 150')


if __name__ == '__main__':
    unittest.main()
