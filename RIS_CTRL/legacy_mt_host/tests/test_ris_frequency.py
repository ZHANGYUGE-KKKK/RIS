from pathlib import Path
import sys
import unittest
import json
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ris_frequency import active_frequency, frequency_text, plan_frequency
from ris_client import RisClient, ProtocolError


class FrequencyTests(unittest.TestCase):
    def test_range_units_and_half_tick_rounding(self):
        self.assertEqual(plan_frequency("1", "Hz").ticks, 150_000_000)
        self.assertEqual(plan_frequency("5", "M").ticks, 30)
        self.assertEqual(plan_frequency("2400", "k").ticks, 63)
        self.assertEqual(plan_frequency("0.005", "G").ticks, 30)
        self.assertEqual(plan_frequency(".125", "k").ticks, 1_200_000)
        self.assertEqual(frequency_text(plan_frequency("2400", "k").actual), "2.38095238 MHz")

    def test_rejects_outside_range_or_non_numeric_input(self):
        for text, unit in (("NaN", "M"), ("inf", "M"), ("1e6", "Hz"), ("-1", "Hz"),
                           ("0", "Hz"), (".99", "Hz"), ("5.00001", "M"), ("1", "G"),
                           ("1.2.3", "Hz"), ("1", "unknown"), ("1" * 65, "Hz")):
            with self.subTest(text=text, unit=unit), self.assertRaises(ValueError):
                plan_frequency(text, unit)

    def test_new_and_legacy_running_status(self):
        self.assertEqual(active_frequency({"fast_mhz": 3}), 3_000_000)
        self.assertEqual(active_frequency({"fast_variable": True, "fast_mhz": 0, "fast_ticks": 1200}), 125_000)
        self.assertEqual(active_frequency({"fast_variable": True, "fast_ticks": 0}), 0)

    def test_wire_status_checks_custom_frequency_and_invalid_dividers(self):
        reply = dict(device="RIS706", version=1, id=1, image="00" * 50, rc=0,
                     status=194, errors=0, frames=1, blink_ms=0, slots=16, ok=True, oe=True,
                     fast_supported=True, fast_variable=True, fast_mhz=0, fast_ticks=63, fast_edges=100)

        def receive(value):
            sock = Mock()
            sock.recv.return_value = json.dumps(value).encode() + b"\n"
            with patch("ris_client.socket.create_connection", return_value=sock), RisClient() as client:
                return client.command("STATUS")

        self.assertEqual(active_frequency(receive(reply)), 150_000_000 / 63)
        for bad in (dict(fast_ticks=29), dict(fast_ticks=150_000_001), dict(fast_ticks=True),
                    dict(blink_ms=100), dict(fast_variable=False), dict(fast_mhz=3)):
            with self.subTest(bad=bad), self.assertRaises(ProtocolError):
                receive(dict(reply, **bad))
