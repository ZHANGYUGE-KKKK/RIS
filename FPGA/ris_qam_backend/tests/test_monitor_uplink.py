import importlib.util
import json
from pathlib import Path
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("monitor_uplink", ROOT / "scripts/monitor_uplink.py")
monitor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(monitor)


def message(payload=b"hello", kind=1):
    return dict(type="uplink", protocol="RUP1", sequence=7, sender_ms=8,
                payload_type=kind, length=len(payload), payload_hex=payload.hex())


class MonitorTests(unittest.TestCase):
    def test_encoder_independent_crc_and_network_order(self):
        packet = monitor.encode_packet(b"a\0b\n\x1b", 0x12345678, 0x90ABCDEF, 1)
        self.assertEqual(packet[:20].hex(), "5255503101180100123456780005000090abcdef")
        self.assertEqual(struct.unpack("!I", packet[20:24])[0],
                         zlib.crc32(packet[:20] + packet[24:]) & 0xFFFFFFFF)
        self.assertEqual(packet[24:], b"a\0b\n\x1b")

    def test_encoder_boundaries(self):
        self.assertEqual(len(monitor.encode_packet(bytes(1024))), 1048)
        self.assertEqual(len(monitor.encode_packet(b"")), 24)
        for kwargs in ({"sequence": -1}, {"sequence": True}, {"sender_ms": 2**32},
                       {"payload_type": 2}):
            with self.assertRaises(ValueError):
                monitor.encode_packet(b"a", **kwargs)
        with self.assertRaises(ValueError):
            monitor.encode_packet(bytes(1025))

    def test_arbitrary_tcp_fragmentation_and_coalescing(self):
        first, second = message(b"a\0b\n\x1b"), message(bytes(range(256)), 0)
        wire = (json.dumps(first) + "\n" + json.dumps(second) + "\n").encode()
        for split in range(1, len(wire)):
            parser = monitor.JsonLinesReader()
            self.assertEqual(parser.feed(wire[:split]) + parser.feed(wire[split:]),
                             [first, second])
            parser.finish()
        parser = monitor.JsonLinesReader()
        result = []
        for byte in wire:
            result.extend(parser.feed(bytes([byte])))
        self.assertEqual(result, [first, second])

    def test_oversized_and_truncated_lines(self):
        parser = monitor.JsonLinesReader()
        with self.assertRaises(ValueError):
            parser.feed(b"x" * (monitor.MAX_LINE + 1))
        parser = monitor.JsonLinesReader()
        parser.feed(b'{"type":')
        with self.assertRaises(ValueError):
            parser.finish()

    def test_invalid_messages(self):
        for changes in ({"length": 100}, {"payload_type": True}, {"sequence": -1},
                        {"payload_hex": " " * 10}, {"protocol": "OTHER"},
                        {"type": "command"}, {"length": 1025}):
            item = message()
            item.update(changes)
            with self.assertRaises(ValueError):
                monitor.decode_message(json.dumps(item).encode())

    def test_display_preserves_binary_and_escapes_terminal_controls(self):
        rendered = monitor.format_message(message(b"a\0b\n\x1b"))
        self.assertIn('\\u0000', rendered)
        self.assertIn('\\n', rendered)
        self.assertIn('\\u001b', rendered)
        self.assertNotIn('\x1b', rendered)
        self.assertIn("invalid_utf8 hex=ff", monitor.format_message(message(b"\xff")))
        self.assertIn("hex=0001", monitor.format_message(message(b"\0\1", 0)))

    def test_status(self):
        data = dict(type="uplink_status", protocol="RUP1", ready=False, link_up=False,
                    init_error=-9, datagrams=4, accepted=1, invalid=1,
                    source_rejected=1, queue_dropped=1, forwarded=0, queued=1,
                    queue_capacity=8, subscribers=1, disconnects=0)
        self.assertEqual(monitor.decode_message(json.dumps(data).encode()), data)
        self.assertIn("init_error=-9", monitor.format_message(data))
        data["queued"] = 9
        with self.assertRaises(ValueError):
            monitor.decode_message(json.dumps(data).encode())

    def test_cli_monitor_local_tcp_and_jsonl(self):
        item = message("回传内容".encode())
        wire = (json.dumps(item) + "\n").encode()
        with socket.socket() as listener, tempfile.TemporaryDirectory() as directory:
            listener.bind(("127.0.0.1", 0))
            listener.listen(1)
            listener.settimeout(5)
            errors = []

            def serve():
                try:
                    conn, _ = listener.accept()
                    with conn:
                        for piece in (wire[:2], wire[2:19], wire[19:]):
                            conn.sendall(piece)
                except Exception as error:
                    errors.append(error)

            thread = threading.Thread(target=serve)
            thread.start()
            path = Path(directory) / "received.jsonl"
            result = subprocess.run([sys.executable, str(ROOT / "scripts/monitor_uplink.py"),
                "monitor", "--host", "127.0.0.1", "--port", str(listener.getsockname()[1]),
                "--jsonl", str(path), "--no-reconnect"], capture_output=True, text=True, timeout=10)
            thread.join(5)
            self.assertFalse(thread.is_alive())
            self.assertFalse(errors)
            self.assertEqual(result.returncode, 1)  # finite fixture closes the stream
            self.assertIn("回传内容", result.stdout)
            saved = json.loads(path.read_text())
            self.assertEqual(saved["payload_hex"], item["payload_hex"])
            self.assertIn("received_utc", saved)


if __name__ == "__main__":
    unittest.main()
