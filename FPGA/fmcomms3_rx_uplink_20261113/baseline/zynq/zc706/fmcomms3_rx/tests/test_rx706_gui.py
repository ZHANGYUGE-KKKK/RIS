#!/usr/bin/env python3
"""Tk widgets + worker threads + actual C dispatcher through localhost TCP."""
import importlib.util
from pathlib import Path
import socketserver
import sys
import threading
import time
import tkinter as tk
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('network_fixture', ROOT / 'tests/test_rx706.py')
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)  # consumes the shared-library argument
sys.modules['rx706'] = fixture.rx
sys.path.insert(0, str(ROOT / 'host'))
import rx706_gui as gui


class ConsoleHandler(socketserver.BaseRequestHandler):
    def handle(self):
        self.request.sendall(b'RX diagnostic version=3\r\nSTEP 0: g/s/0/1/2/q\r\n')
        try:
            while self.request.recv(64):
                pass
        except OSError:
            pass


class GuiTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixture.TransferTests('test_exact_bin_crc_sha_and_metadata')
        self.fixture.setUp()
        self.console = fixture.Board(('127.0.0.1', 0), ConsoleHandler)
        threading.Thread(target=self.console.serve_forever, kwargs={'poll_interval': 0.01}, daemon=True).start()
        self.root = tk.Tk()
        self.root.withdraw()
        self.errors = []
        self.root.report_callback_exception = lambda *args: self.errors.append(args)
        self.app = gui.Rx706App(self.root)
        self.app.host.set('127.0.0.1')
        self.app.port.set(str(self.fixture.board.server_address[1]))
        self.app.console_port.set(str(self.console.server_address[1]))
        self.app.timeout.set('3')
        self.app.output.set(str(self.fixture.output))
        self.app.connect_button.invoke()
        self.until(lambda: self.app.connected and not self.app.busy)

    def tearDown(self):
        self.app.close()
        deadline = time.monotonic() + 2
        while time.monotonic() < deadline:
            try:
                self.root.update()
                if not self.root.winfo_exists():
                    break
            except tk.TclError:
                break
            time.sleep(0.01)
        try:
            self.app.destroy()
        except tk.TclError:
            pass
        self.console.shutdown()
        self.console.server_close()
        self.fixture.tearDown()
        self.assertFalse(self.app.controller.thread.is_alive())
        self.assertFalse(self.errors, self.errors)

    def until(self, predicate, timeout=5):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            self.root.update()
            if predicate():
                return
            time.sleep(0.01)
        self.fail('GUI condition timed out: ' + self.app.notice.get())

    def test_connected_widgets_and_download(self):
        self.assertEqual(self.app.info['state'], 'ready')
        self.assertTrue(self.app.capture_button.instate(['disabled']))
        self.until(lambda: 'version=3' in self.app.log_text.get('1.0', 'end'))
        self.app.download_button.invoke()
        self.until(lambda: not self.app.busy and self.fixture.output.exists())
        self.assertEqual(self.fixture.output.read_bytes(), fixture.EXPECTED)
        self.assertEqual(float(self.app.progress['value']), 100)
        self.assertIn('校验通过', self.app.notice.get())

    def test_release_then_capture_by_seconds(self):
        self.app.release_button.invoke()
        self.until(lambda: not self.app.busy and self.app.info['state'] == 'empty')
        self.app.preset('0.001', '秒')
        self.assertIn('0.125 MiB', self.app.length_hint.get())
        self.app.capture_button.invoke()
        self.until(lambda: not self.app.busy and self.fixture.output.exists())
        self.assertEqual(self.fixture.output.stat().st_size, 131072)
        self.assertEqual(self.app.info['state'], 'ready')

    def test_disconnect_mid_download_and_resume(self):
        self.fixture.board.drop = True
        self.app.download_button.invoke()
        self.until(lambda: not self.app.busy and not self.app.connected)
        self.assertTrue(Path(str(self.fixture.output) + '.part').is_file())
        self.assertFalse(self.fixture.output.exists())
        self.fixture.board.drop = False
        self.app.connect_button.invoke()
        self.until(lambda: self.app.connected and not self.app.busy)
        self.app.resume_button.invoke()
        self.until(lambda: not self.app.busy and self.fixture.output.exists())
        self.assertEqual(self.fixture.output.read_bytes(), fixture.EXPECTED)

    def test_abort_capture_keeps_ui_responsive(self):
        self.app.release_button.invoke()
        self.until(lambda: not self.app.busy and self.app.info['state'] == 'empty')
        self.app.preset('8', 'MiB')
        self.app.auto_download.set(False)
        self.app.capture_button.invoke()
        self.until(lambda: self.app.info.get('state') == 'capturing')
        self.app.stop_button.invoke()
        self.until(lambda: not self.app.busy)
        self.assertEqual(self.app.info['state'], 'failed')
        self.assertIn('无效', self.app.notice.get())
        self.assertTrue(self.app.capture_button.instate(['!disabled']))

    def test_pause_download_keeps_connection_then_resume(self):
        self.fixture.board.read_delay = 0.15
        self.app.download_button.invoke()
        self.until(lambda: 0 < float(self.app.progress['value']) < 100)
        self.app.stop_button.invoke()
        self.until(lambda: not self.app.busy)
        self.assertTrue(self.app.connected)
        self.assertFalse(self.fixture.output.exists())
        self.assertIn('暂停', self.app.notice.get())
        self.fixture.board.read_delay = 0
        self.app.resume_button.invoke()
        self.until(lambda: not self.app.busy and self.fixture.output.exists())
        self.assertEqual(self.fixture.output.read_bytes(), fixture.EXPECTED)

    def test_layout_smoke_and_preview(self):
        self.root.deiconify()
        self.root.update()
        self.assertLessEqual(self.app.status_button.winfo_rootx() + self.app.status_button.winfo_width(),
                             self.root.winfo_rootx() + self.root.winfo_width())
        try:
            from PIL import ImageGrab
            x, y = self.root.winfo_rootx(), self.root.winfo_rooty()
            ImageGrab.grab(bbox=(x, y, x+self.root.winfo_width(), y+self.root.winfo_height())).save(
                ROOT / 'reports/tk_gui/preview.png')
        except ImportError:
            pass

    def test_fft_download_follow_rx2_and_offline_analysis(self):
        self.app.spectrum_button.invoke()
        panel = self.app.spectrum_window
        panel.auto.set(True)
        panel.nfft.set('4096')
        panel.averages.set('2')
        self.app.download_button.invoke()
        self.until(lambda: not self.app.busy and panel.result is not None, timeout=15)
        self.assertEqual(panel.result.path, self.fixture.output)
        self.assertEqual(panel.result.samples, 8192)
        self.assertEqual(panel.result.channel, 1)
        self.assertEqual(panel.result.rate_source, '同名 JSON')
        self.app.controller.disconnect()
        self.until(lambda: not self.app.connected)
        panel.channel.set('RX2')
        panel.analyze_button.invoke()
        self.until(lambda: not panel.busy)
        self.assertEqual(panel.result.channel, 2)
        self.assertIn('RX2', panel.status.get())
        # A bad selection must not leave the old spectrum visible as new data.
        panel.filename.set(str(self.fixture.output) + '.part')
        panel.analyze_button.invoke()
        self.until(lambda: not panel.busy)
        self.assertIsNone(panel.result)
        self.assertIn('分析失败', panel.status.get())
        self.assertEqual(len(panel.axes.lines), 0)

    def test_close_fft_during_analysis(self):
        from unittest.mock import patch
        import rx706_spectrum_gui as spectrum_gui
        from rx706_spectrum import AnalysisCancelled
        self.app.spectrum_button.invoke()
        panel = self.app.spectrum_window
        started = threading.Event()

        def waiting_analysis(*args, cancel_event=None, **kwargs):
            started.set()
            cancel_event.wait(3)
            raise AnalysisCancelled('stopped')

        with patch.object(spectrum_gui, 'analyze_bin', side_effect=waiting_analysis):
            panel.analyze_button.invoke()
            self.until(started.is_set)
            panel.close()
            self.until(lambda: not panel.thread.is_alive())
        self.assertTrue(panel.closed)
        self.assertIsNone(panel.poll_after)


class LengthTests(unittest.TestCase):
    def test_duration_alignment_and_limits(self):
        self.assertEqual(gui.capture_length('1', '秒'), 122880000)
        self.assertEqual(gui.capture_length('2044', 'MiB'), fixture.rx.MAX_BYTES)
        self.assertEqual(gui.capture_length('0.001', '秒'), 131072)
        self.assertEqual(gui.capture_length('0.125', 'MiB'), 131072)
        self.assertEqual(gui.capture_length('0.000001', '秒'), 32768)
        for value, unit in [('nan','秒'), ('inf','MiB'), ('-1','秒'), ('0','MiB'),
                            ('17.443','秒'), ('2045','MiB'), ('1e999999','秒')]:
            with self.assertRaises(ValueError):
                gui.capture_length(value, unit)


if __name__ == '__main__':
    unittest.main(verbosity=2)
