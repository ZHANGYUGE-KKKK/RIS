"""Real Tk + Python TCP client + real C protocol/driver + host AXI model."""
import socketserver
import subprocess
import threading
from unittest.mock import patch
import unittest

import test_console_gui as baseline
from qam_device_model import DeviceModel, BACKEND
from ris_client import RisClient
from ris_qam256 import ORIENTATIONS


class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        self.server.model.exchange("_NEW_SESSION")
        for line in self.rfile:
            text = line.decode("ascii").rstrip("\n")
            self.server.commands.append(text.split(" ", 1)[1])
            if self.server.gate and text.split()[1] == self.server.gate:
                self.server.blocked.set()
                self.server.release.wait(10)
            reply = self.server.model.exchange(text)
            if self.server.bad_ack and text.split()[1] == "QDATA":
                import json
                data = json.loads(reply);data["qam_received"] += 4;reply = json.dumps(data)+"\n"
            self.wfile.write(reply.encode("ascii"));self.wfile.flush()
        self.server.model.exchange("_NEW_SESSION")


class FullChainTests(unittest.TestCase):
    wait = baseline.ConsoleTests.wait
    settle = baseline.ConsoleTests.settle
    connect = baseline.ConsoleTests.connect
    apply = baseline.ConsoleTests.apply

    @classmethod
    def setUpClass(cls):
        subprocess.run(["bash", str(BACKEND / "tests/build_host_model.sh")], check=True)

    def setUp(self):
        baseline.ConsoleTests.setUp(self)
        self.patch.stop()
        self.model = DeviceModel()
        self.server = socketserver.ThreadingTCPServer(("127.0.0.1", 0), Handler)
        self.server.daemon_threads = True
        self.server.model = self.model
        self.server.commands = []
        self.server.gate = None
        self.server.bad_ack = False
        self.server.blocked = threading.Event();self.server.release = threading.Event()
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        host, port = self.server.server_address
        self.patch = patch("ris_gui.RisClient", lambda *_: RisClient(host, port))
        self.patch.start()
        self.page = self.app.qam_page
        self.assertTrue(self.page.load(self.page.default_path))
        self.app.qam_orientation.set(ORIENTATIONS["identity"])
        self.app.qam_state1.set("驱动高");self.app.qam_confirmed.set(True)
        self.app.open_qam()
        self.page.source.set("十六进制字节序列");self.page.sequence.set("3F A5 00")
        self.page.repeats.set("3");self.page.loop.set(False)
        self.root.update()

    def tearDown(self):
        self.server.release.set()
        if not self.app.closed:
            if self.app.busy:self.wait(lambda: not self.app.busy, timeout=15)
            self.app.disconnect()
            self.wait(lambda: not self.app.busy)
        baseline.ConsoleTests.tearDown(self)
        self.server.shutdown();self.server.server_close();self.model.close()

    def writes(self):return [x for x in self.server.commands if x!="STATUS"]

    def test_phase_reference_frames_use_total_gate_and_freeze_both_qam_modes(self):
        self.connect()
        for order,refs in ((256,b"\x00\x08\x88\x80"),(64,b"\x00\x04\x24\x20")):
            with self.subTest(order=order):
                page=self.app.qam_page if order==256 else self.app.qam64_page
                if order==64:self.assertTrue(page.load(page.default_path))
                self.app.open_qam(order);page.action.set("play")
                page.source.set("十六进制字节序列");page.sequence.set("01 2A")
                page.repeats.set("2");page.loop.set(True)
                page.pwm_frequency.set("9.765625" if order==256 else "150")
                prefix=self.directory/f"phase_prefix_{order}.txt"
                prefix.write_text("(25,0);\n(75,0);")
                self.assertTrue(page.load_preamble(prefix))
                before=len(self.writes());page.phase_checkbox.invoke();self.root.update()
                self.assertEqual(len(self.writes()),before)
                self.server.blocked.clear();self.server.release.clear();self.server.gate="QDATA"
                self.assertTrue(self.app.apply_current());plan=self.app.inflight_action.payload
                self.wait(self.server.blocked.is_set)
                page.phase_compensation.set(False);page.sequence.set("02")
                page.repeats.set("3");page.preamble_enabled.set(False);self.root.update()
                page.pwm_frequency.set("19.53125" if order==256 else "160")
                self.server.release.set();self.wait(lambda:not self.app.busy,timeout=20)
                self.assertEqual(plan.phase_symbols,refs)
                self.assertEqual(plan.data_payload,b"\x01\x2a")
                self.assertEqual(plan.data_repeats,2)
                self.assertEqual(plan.frame_cycles,14)
                self.assertEqual(plan.actual_pwm_hz, 9765.625 if order==256 else 150000)
                self.assertEqual(self.app.latest["qam_crc"],plan.crc)
                self.assertIn("相偏补偿",self.app.status_title.get())
                self.assertIn(refs.hex(" ").upper(),self.app.status_detail.get())
                self.assertIn("正式2符号×K2",self.app.status_detail.get())
                self.server.gate=None;page.action.set("stop");self.root.update();self.apply()
                self.assertEqual(self.writes()[-1],"STOP")

    def test_qam64_total_gate_exact_rate_prefix_and_legacy_takeover(self):
        self.page = self.app.qam64_page
        self.assertTrue(self.page.load(self.page.default_path))
        self.app.open_qam(64)
        self.page.source.set("十六进制字节序列");self.page.sequence.set("00 1B 3F")
        prefix=self.directory/"prefix64.txt";prefix.write_text("(25,0);\n(50,0);\n(75,0);")
        self.assertTrue(self.page.load_preamble(prefix))
        self.root.update();self.connect()
        self.assertEqual(self.writes(),[])
        self.assertTrue(self.app.apply_current())
        plan=self.app.inflight_action.payload
        self.wait(lambda: not self.app.busy, timeout=20)
        self.assertEqual(self.app.latest["qam_order"],64)
        self.assertEqual(self.app.latest["qam_crc"],plan.crc)
        self.assertEqual(plan.actual_pwm_hz,160000)
        self.assertIn("64QAM",self.app.status_title.get())
        self.assertIn("160 kHz",self.app.status_detail.get())
        self.assertTrue(any(x.startswith("Q64BEGIN ") for x in self.writes()))
        self.page.action.set("stop");self.root.update();self.apply()
        self.assertFalse(self.app.latest["qam_status"]&3)
        self.app.open_qam();self.page=self.app.qam_page
        self.assertTrue(self.app.apply_current())
        self.wait(lambda: not self.app.busy, timeout=20)
        self.assertEqual(self.app.latest["qam_order"],64)  # board field is a timing profile
        self.assertIn("256QAM",self.app.status_title.get())
        self.assertTrue(any(x.startswith("Q64BEGIN ") for x in self.writes()))

    def test_256qam_64slice_160khz_and_import_validation_keeps_running_output(self):
        path = self.page.default_path.parent/'ris_256qam_64slice_codebook'
        self.assertTrue(self.page.load(path))
        self.page.pwm_frequency.set('160'); self.page.pwm_unit.set('kHz')
        self.page.source.set('十六进制字节序列'); self.page.sequence.set('00 88 FF')
        self.page.phase_compensation.set(True); self.page.loop.set(True)
        prefix = self.directory/'prefix_256_64.txt'; prefix.write_text('(25,0);\n(75,0);')
        self.assertTrue(self.page.load_preamble(prefix))
        self.root.update(); self.connect()
        self.assertEqual(self.writes(), [])
        self.assertTrue(self.app.apply_current())
        plan = self.app.inflight_action.payload
        self.wait(lambda:not self.app.busy, timeout=20)
        self.assertEqual((plan.modulation_order, plan.actual_pwm_hz, plan.base_period_ticks), (256,160000,1875))
        self.assertEqual(plan.phase_symbols, bytes.fromhex('00 08 88 80'))
        self.assertEqual(plan.data_payload, bytes.fromhex('00 88 FF'))
        self.assertEqual(self.app.latest['qam_crc'], plan.crc)
        self.assertIn('256QAM', self.app.status_title.get())
        self.assertIn('160 kHz', self.app.status_detail.get())
        count = len(self.writes())
        self.assertTrue(self.page.load(self.page.default_path)); self.root.update()
        self.assertEqual(self.page.pwm_frequency.get(), '160')
        self.assertIn('256 slice', self.app.pending_text.get())
        self.assertFalse(self.app.apply_current())
        self.assertEqual(len(self.writes()), count)
        self.assertEqual(self.app.latest['qam_crc'], plan.crc)
        self.assertTrue(self.app.latest['qam_status']&2)

    def test_total_gate_upload_playback_completion_and_frozen_snapshot(self):
        self.connect()
        self.assertTrue(self.app.latest["qam_supported"])
        self.assertEqual(self.writes(), [])
        self.assertFalse(self.app.submit("qam", None))
        self.server.gate = "QDATA"
        self.assertTrue(self.app.apply_current())
        plan = self.app.inflight_action.payload
        self.wait(self.server.blocked.is_set)
        self.page.sequence.set("FF");self.page.repeats.set("1")
        self.page.loop.set(True);self.root.update()
        self.assertIn("256QAM上传", self.app.status_title.get())
        self.server.release.set()
        self.wait(lambda: not self.app.busy, timeout=20)
        self.assertTrue(self.app.connected, self.app.notice.get())
        self.assertEqual(self.app.latest["qam_crc"], plan.crc)
        self.assertEqual(self.app.latest["qam_payload"], 3)
        self.assertEqual(self.app.latest["qam_repeats"], 3)
        self.assertFalse(self.app.latest["qam_loop"])
        self.assertIn("播放一次", self.app.status_title.get())
        self.assertEqual(plan.payload, b"\x3f\xa5\0")
        self.model.exchange("_FINISH")
        self.app.submit("poll");self.wait(lambda: not self.app.busy)
        self.assertIn("单次完成", self.app.status_title.get())
        self.page.action.set("stop");self.apply()
        self.assertEqual(self.app.latest["qam_status"] & 15, 0)
        self.app.show_page("board");self.app.board_mode.set("all1");self.apply()
        self.assertEqual(self.app.latest["image"], "FF"*50)

    def test_cancel_upload_only_via_total_button_and_no_start(self):
        self.connect();self.server.gate="QDATA"
        self.app.apply_current();self.wait(self.server.blocked.is_set)
        self.page.action.set("stop");self.root.update()
        self.assertEqual(self.app.apply_button.cget("text"), "取消上传并停止")
        self.assertTrue(self.app.apply_current())
        self.server.release.set();self.wait(lambda:not self.app.busy,timeout=15)
        self.assertFalse(any(c.startswith("QSTART") for c in self.writes()))
        self.assertEqual(self.writes()[-1], "STOP")
        self.assertFalse(self.app.latest["qam_uploading"])

    def test_unsupported_frequency_blocks_before_network_mutation(self):
        self.connect();self.page.pwm_frequency.set("1000");self.root.update()
        self.assertFalse(self.app.apply_current())
        self.assertEqual(self.writes(), [])

    def test_bad_packet_ack_aborts_without_start_or_retry(self):
        self.connect();self.server.bad_ack=True
        self.app.apply_current();self.wait(lambda:not self.app.busy,timeout=15)
        self.assertFalse(self.app.connected)
        self.assertEqual(sum(c.startswith("QDATA") for c in self.writes()),1)
        self.assertFalse(any(c.startswith("QSTART") for c in self.writes()))
        self.assertIn("字节数",self.app.notice.get())

    def test_preamble_upload_snapshot_and_status_use_existing_firmware(self):
        prefix = self.directory / "preamble.txt"
        prefix.write_text("(20,0);\n(50,0);\n(80,0);")
        self.assertTrue(self.page.load_preamble(prefix))
        self.page.loop.set(True)
        self.root.update()
        self.assertIn("含前导码帧平均39,062.500 bit/s",self.page.payload_text.get())
        self.assertEqual(self.writes(), [])
        self.connect();self.server.gate="QDATA"
        self.assertTrue(self.app.apply_current())
        plan = self.app.inflight_action.payload
        self.wait(self.server.blocked.is_set)
        self.page.clear_preamble();self.page.sequence.set("FF");self.root.update()
        self.server.release.set();self.wait(lambda:not self.app.busy,timeout=20)
        self.assertTrue(self.app.connected, self.app.notice.get())
        self.assertEqual(self.app.latest["qam_crc"], plan.crc)
        self.assertEqual(plan.logical_payload, b"\x3f\xa5\0")
        self.assertEqual(len(plan.preamble.rows), 3)
        self.assertEqual(self.app.latest["qam_repeats"], 1)
        self.assertIn("前导码",self.app.status_title.get())
        self.assertIn("19.53125 kHz",self.app.status_detail.get())
        self.assertIn("K3",self.app.status_detail.get())
        self.assertFalse(any(x.startswith("MT") for x in self.writes()))
        self.assertEqual(sum(x.startswith("QSTART") for x in self.writes()),1)


if __name__ == "__main__":unittest.main()
