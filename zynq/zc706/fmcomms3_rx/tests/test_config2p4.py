#!/usr/bin/env python3
"""Verify GUI conversion against the independently preserved 915 table,
then check 2.4 GHz clock/interface compatibility and source fidelity.
"""
import hashlib
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "generate_ad9361_script", ROOT / "scripts/generate_ad9361_script.py")
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)
SOURCE = ROOT / "config/config2p4"
TABLE = ROOT / "vitis_code/key_ctrlll/src/ad_config/config2p4_data.h"
LEGACY = ROOT / "vitis_code/key_ctrlll/src/ad_config/config915_data.h"


def stored_operations(path):
    return [tuple(int(value, 16 if index in (0, 4, 5) else 10)
                  for index, value in enumerate(match))
            for match in re.findall(
                r"\{0x([\dA-F]+), (\d+), (\d+), (\d+), 0x([\dA-F]+), 0x([\dA-F]+)\}",
                path.read_text())]


class ConfigurationTests(unittest.TestCase):
    def test_generated_table_matches_source_and_digest(self):
        source = SOURCE.read_bytes()
        self.assertEqual(hashlib.sha256(source).hexdigest(),
                         "435fb5daa36453aaaa842b8cefa60a3e8110c80d6e772f70b78c9d6f9c4a8592")
        self.assertEqual(TABLE.read_text(), generator.render_header(source, "config2p4"))
        self.assertEqual(len(stored_operations(TABLE)), 2568)

    def test_converter_matches_preserved_915_operation_sequence(self):
        source915 = ROOT / "../../z035/config915"
        self.assertEqual(generator.parse_script(source915.read_bytes()),
                         stored_operations(LEGACY))

    def test_rf_changes_preserve_interface_fir_and_calibrations(self):
        old, new = stored_operations(LEGACY), stored_operations(TABLE)
        self.assertEqual(len(old), len(new))
        diffs = [(a, b) for a, b in zip(old, new) if a != b]
        self.assertEqual(len(diffs), 53)
        allowed = {0x005, 0x0AA, 0x131, 0x132, 0x133,
                   0x231, 0x233, 0x234, 0x235, 0x238, 0x239,
                   0x23A, 0x23B, 0x242, 0x251, 0x271, 0x273,
                   0x274, 0x275, 0x278, 0x279, 0x27A, 0x27B, 0x282, 0x291}
        for a, b in diffs:
            self.assertEqual(a[3], 1)
            self.assertEqual(b[3], 1)
            self.assertEqual(a[:1] + a[1:4] + a[5:], b[:1] + b[1:4] + b[5:])
            self.assertIn(b[0], allowed)
        self.assertEqual([op for op in old if op[3] == 4],
                         [op for op in new if op[3] == 4])

    def test_clock_and_lo_decode(self):
        registers = {r: v for r, _, _, op, v, _ in stored_operations(TABLE) if op == 1}
        fraction = (registers[0x041] << 16) | (registers[0x042] << 8) | registers[0x043]
        bbpll = 40_000_000 * (registers[0x044] + fraction / 2_088_960)
        adc = bbpll / (2 ** (registers[0x00A] & 7))
        self.assertAlmostEqual(adc / 16, 15_360_000, delta=1)
        for base, shift in [(0x231, 0), (0x271, 4)]:
            integer = registers[base] | ((registers[base + 1] & 7) << 8)
            fractional = (registers[base + 2] | (registers[base + 3] << 8)
                          | ((registers[base + 4] & 127) << 16))
            frequency = 80_000_000 * (integer + fractional / 8_388_593)
            frequency /= 2 ** (1 + ((registers[0x005] >> shift) & 15))
            self.assertEqual(frequency, 2_400_000_000)
        for reg, expected in [(0x002, 0xDE), (0x003, 0xDE), (0x004, 3),
                              (0x006, 15), (0x010, 0xC8), (0x011, 0), (0x012, 0x10)]:
            self.assertEqual(registers[reg], expected)

    def test_unknown_commands_and_invalid_operands_rejected(self):
        for text in [b"SPIWrite 400,00", b"SPIWrite 006,100", b"SPIRead 400",
                     b"WAIT -1", b"WAIT 65536", b"WAIT_CALDONE MYSTERY,1",
                     b"BlockWrite 2,7", b"REFCLK_Scale 80.000000,1,2", b"UNKNOWN", b""]:
            with self.subTest(text=text), self.assertRaises(ValueError):
                generator.parse_script(text)


if __name__ == "__main__":
    unittest.main()
