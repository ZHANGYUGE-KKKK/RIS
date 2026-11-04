from dataclasses import replace
from pathlib import Path
import json
import struct
import subprocess
import sys
import threading
import unittest

BASE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BASE))
from ris_qam256 import QamCodebook
from ris_mapping import RisMapping
from ris_qam_transport import QamPlan, make_plan, timing_ticks
from ris_actions import confirmed_status
from qam_device_model import DeviceModel, BACKEND


def tiny_plan(loop=False):
    frame = bytes((i*7) % 256 for i in range(50)) + b"\0\0"
    return QamPlan((frame, struct.pack("<HH", 0, 256), struct.pack("<HH", 0, 1)*256, b"\x3f\xa5\0"),
                   60, 3, 256, loop, 1e6, "test", 0)


class TransportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run(["bash", str(BACKEND / "tests/build_host_model.sh")], check=True)
        cls.book = QamCodebook.load(BASE / "codebooks/ris_256qam_0deg.zip")
        cls.mapping = RisMapping.load(BASE / "mappings/ris_mapping.json")

    def setUp(self):
        self.device = DeviceModel()
        self.addCleanup(self.device.close)

    def upload(self, plan):
        reply = None
        for command in plan.commands():
            reply = self.device.command(command)
            self.assertTrue(reply["ok"], (command[:32], reply))
        return reply

    def test_native_timing_and_payload_capacity(self):
        with self.assertRaisesRegex(ValueError, "原速"):
            timing_ticks(self.book)
        self.assertEqual(timing_ticks(self.book, "bench", "200"), 60)
        for value in ["199", "nan", "201", "0", "-200"]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                timing_ticks(self.book, "bench", value)
        with self.assertRaises(ValueError):
            make_plan(self.book, self.mapping, 0, "identity", True, 3, False, bytes(4097), "bench", "200")

    def test_full_codebook_real_c_upload_crc_and_one_shot(self):
        plan = make_plan(self.book, self.mapping, 0, "identity", True, 3, False, b"\x3f\xa5\0", "bench", "200")
        self.assertEqual((plan.frames, plan.events), (1119, 26103))
        for command in plan.commands():
            self.assertLess(len(f"4294967295 {command}\n"), 160)
        reply = self.upload(plan)
        self.assertEqual(reply["qam_crc"], plan.crc)
        self.assertEqual(reply["qam_received"], plan.total_bytes)
        self.assertEqual(reply["qam_status"] & 3, 3)
        self.assertIn("播放一次", confirmed_status(True, reply)[0])
        self.device.exchange("_FINISH")
        reply = self.device.command("STATUS")
        self.assertEqual(reply["qam_status"], 1)
        self.assertIn("单次完成", confirmed_status(True, reply)[0])
        self.assertLess(len(json.dumps(reply)), 1536)

    def test_stop_preserves_all_400_bits_and_legacy_takeover(self):
        plan = tiny_plan(True)
        self.upload(plan)
        reply = self.device.command("STOP")
        self.assertTrue(reply["ok"])
        self.assertEqual(reply["qam_status"] & 15, 0)
        self.assertEqual(bytes.fromhex(reply["image"]), plan.blocks[0][:50])
        reply = self.device.command("ALL 1")
        self.assertTrue(reply["ok"])
        self.assertEqual(bytes.fromhex(reply["image"]), bytes([255])*50)
        self.assertTrue(self.device.command("FASTTICKS 60")["ok"])
        self.assertTrue(self.device.command("STOP")["ok"])
        self.upload(plan)

    def test_crc_corruption_cannot_start(self):
        plan = tiny_plan()
        commands = list(plan.commands())
        # A syntactically valid payload mutation reaches RAM but invalidates CRC.
        commands[-2] = commands[-2][:-2] + "01"
        for command in commands[:-1]: self.assertTrue(self.device.command(command)["ok"])
        reply = self.device.command(commands[-1])
        self.assertFalse(reply["ok"])
        self.assertFalse(reply["qam_uploading"])
        self.assertFalse(reply["qam_status"] & 3)

    def test_invalid_order_duplicate_and_incomplete_upload(self):
        plan = tiny_plan()
        commands = list(plan.commands())
        for bad in ["QDATA E 0 00000001", "QDATA F 4 00000000", "QDATA F 0 ZZ", "QSTART 0"]:
            with self.subTest(bad=bad):
                self.assertTrue(self.device.command(commands[0])["ok"])
                self.assertTrue(self.device.command(commands[1])["ok"])
                self.assertFalse(self.device.command(bad)["ok"])
                self.assertFalse(self.device.command(commands[-1])["ok"])
        self.device.command(commands[0]);self.device.command(commands[1]);self.device.command(commands[2])
        self.assertFalse(self.device.command(commands[2])["ok"])

    def test_preflight_rejects_bad_period_and_no_output(self):
        plan = tiny_plan()
        plan = replace(plan, blocks=(plan.blocks[0], struct.pack("<HH", 0, 255), plan.blocks[2], plan.blocks[3]))
        commands = list(plan.commands())
        for command in commands[:-1]:self.assertTrue(self.device.command(command)["ok"])
        reply = self.device.command(commands[-1])
        self.assertFalse(reply["ok"])
        self.assertEqual(reply["qam_error"], 3)
        self.assertFalse(reply["qam_status"] & 3)

    def test_disconnect_invalidates_upload_but_does_not_stop_running(self):
        plan = tiny_plan(True)
        commands = list(plan.commands())
        self.device.command(commands[0]);self.device.command(commands[1]);self.device.command(commands[2])
        self.device.exchange("_NEW_SESSION")
        self.assertFalse(self.device.command(commands[-1])["ok"])
        self.upload(plan)
        self.device.exchange("_NEW_SESSION")
        reply = self.device.command("STATUS")
        self.assertEqual(reply["qam_status"] & 3, 3)

    def test_host_upload_cancel_and_bad_ack(self):
        from ris_client import RisClient, ProtocolError
        class Client:
            command = self.device.command
        plan = tiny_plan(True)
        cancel = threading.Event()
        reply, cancelled = RisClient.upload_qam(Client(), plan, cancel,
                                              lambda *_: cancel.set())
        self.assertTrue(cancelled)
        self.assertEqual(reply["qam_status"] & 3, 0)
        self.assertFalse(any(c.startswith("QSTART") for c in self.device.commands))
        cancel.clear()
        def wrong(command):
            reply = self.device.command(command)
            if command.startswith("QDATA"):reply["qam_received"] += 4
            return reply
        Client.command = staticmethod(wrong)
        with self.assertRaisesRegex(ProtocolError, "字节数"):
            RisClient.upload_qam(Client(), plan, cancel)

    def test_invalid_begin_keeps_existing_blink(self):
        self.assertTrue(self.device.command("BLINK 1000")["ok"])
        for command in ("QBEGIN 59 3 256 0", "QBEGIN invalid 3 256 0", "QUNKNOWN"):
            with self.subTest(command=command):
                reply = self.device.command(command)
                self.assertFalse(reply["ok"])
                self.assertEqual(reply["blink_ms"], 1000)

    def test_cancel_during_start_ack_requires_confirmed_stop(self):
        from ris_client import RisClient, ProtocolError
        cancel = threading.Event()
        def command(text):
            reply = self.device.command(text)
            if text.startswith("QSTART"):cancel.set()
            return reply
        class Client:
            pass
        Client.command = staticmethod(command)
        reply, cancelled = RisClient.upload_qam(Client(), tiny_plan(True), cancel)
        self.assertTrue(cancelled)
        self.assertEqual(self.device.commands[-1], "STOP")
        self.assertEqual(reply["qam_status"] & 15, 0)
        cancel.clear()
        def rejected_stop(text):
            reply = command(text)
            if text == "STOP":reply["ok"] = False
            return reply
        Client.command = staticmethod(rejected_stop)
        with self.assertRaisesRegex(ProtocolError, "STOP未确认"):
            RisClient.upload_qam(Client(), tiny_plan(True), cancel)


if __name__ == "__main__": unittest.main()
