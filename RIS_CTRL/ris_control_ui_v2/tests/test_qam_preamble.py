"""Independent waveform reconstruction of host-only preamble/QAM programs."""
from decimal import Decimal
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import zipfile

BASE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BASE))
sys.path.insert(0, str(BASE.parents[1] / "FPGA/ris_qam_backend/scripts"))
from compile_qam_plan import compile_plan
from ris_actions import OutputAction, confirmed_status
from ris_mapping import RisMapping
from ris_mt import parse_mt
from ris_patterns import compile_frame
from ris_qam256 import QamCodebook, export_plan
from ris_qam_preamble import Preamble
from ris_qam_transport import make_plan


def decode(plan, loops=1):
    frames = [plan.blocks[0][p:p+50] for p in range(0, len(plan.blocks[0]), 52)]
    events = tuple(struct.iter_unpack("<HH", plan.blocks[1]))
    symbols = tuple(struct.iter_unpack("<HH", plan.blocks[2]))
    result = []
    for _ in range(loops):
        for symbol in plan.payload:
            first, count = symbols[symbol]
            for _ in range(plan.repeats):
                for fid, duration in events[first:first+count]:
                    result.extend([frames[fid]]*duration)
    return result


class PreambleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.book = QamCodebook.load(BASE.parents[1] / "QAM_RULES/256QAM/ris_256qam_256slice_codebook_0deg.zip")
        cls.mapping = RisMapping.load(BASE / "mappings/ris_mapping.json")

    def plan(self, rows, data=b"\x3f\xa5", k=3, loop=True, high=True):
        return make_plan(self.book, self.mapping, 0, "identity", high, k, loop, data, "bench", "200", rows)

    def oracle(self, rows, data, k, high=True):
        prefix = Preamble.compile(rows, self.book.slots)
        expected = []
        for width in prefix.widths:
            expected.extend([bytes([255])*50]*width + [bytes(50)]*(256-width))
        for symbol in data:
            cycle = [compile_frame(self.book.pattern(0, symbol, q, "identity", high), self.mapping) for q in range(256)]
            expected.extend(cycle*k)
        return expected

    def test_exact_cycles_and_frame_looping_for_all_400_bits(self):
        rows = parse_mt("(20,0);\n(50,0);\n(80,0);")
        plan = self.plan(rows)
        expected = self.oracle(rows, b"\x3f\xa5", 3)
        self.assertEqual(decode(plan, 2), expected*(2*plan.frame_copies))
        self.assertEqual(plan.actual_pwm_hz, 19531.25)
        self.assertEqual(plan.data_repeats, 3)
        self.assertEqual(plan.repeats, 1)
        self.assertEqual(plan.logical_payload, b"\x3f\xa5")
        self.assertEqual(len(expected), (3+2*3)*256)
        self.assertEqual(plan.preamble.widths, (51, 128, 205))
        self.assertEqual(plan.frame_cycles, 9)
        descriptors = tuple(struct.iter_unpack("<HH", plan.blocks[2]))
        events = tuple(struct.iter_unpack("<HH", plan.blocks[1]))
        self.assertEqual(len(descriptors), 256)
        for first, count in descriptors:
            self.assertEqual(sum(d for _, d in events[first:first+count]), plan.slots)

    def test_prefix_is_electrical_high_and_not_qam_polarity(self):
        rows = parse_mt("(0,0);\n(100,0);\n(37.5,0);")
        plan = self.plan(rows, b"\0", 1, False, False)
        self.assertEqual(decode(plan), self.oracle(rows, b"\0", 1, False))

    def test_max_ten_rows_and_zero_delay_are_strict(self):
        self.assertEqual(len(Preamble.compile(parse_mt("(50,0);\n"*10), 256).widths), 10)
        for rows in ((), parse_mt("(50,0);\n"*11), parse_mt("(50,0.1);"),
                     ((Decimal("NaN"), Decimal(0)),), parse_mt("(.01,0);"), parse_mt("(99.99,0);")):
            with self.subTest(rows=rows), self.assertRaises(ValueError):
                Preamble.compile(rows, 256)

    def test_capacity_failure_is_explicit_and_no_padding_is_inserted(self):
        rows = parse_mt("(50,0);")
        with self.assertRaisesRegex(ValueError, "容量"):
            self.plan(rows, b"\x3f\xa5", 1000000)
        # 257 distinct PWM cycle types cannot all be represented by 256
        # descriptors at any common block size allowed by the 16-bit period.
        with self.assertRaisesRegex(ValueError, "容量"):
            self.plan(rows, bytes(range(256)), 1, False)

    def test_grouped_virtual_symbols_support_longer_frames(self):
        rows = parse_mt("(20,0);\n(80,0);")
        data = bytes(range(256))
        plan = self.plan(rows, data, 1, False)
        self.assertGreater(plan.slots, 256)
        self.assertLessEqual(plan.events, 32768)
        self.assertLessEqual(len(plan.payload), 4096)
        self.assertEqual(decode(plan), self.oracle(rows, data, 1))

    def test_source_export_offline_compiler_matches_live_tables(self):
        rows = parse_mt("(25,0);\n(75,0);")
        plan = self.plan(rows, b"\x3f", 3)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "plan.zip"
            manifest = export_plan(path, self.book, self.mapping, 0, "identity", True, 3, True, b"\x3f", rows)
            self.assertEqual(manifest["preamble"]["cycles"], 2)
            with zipfile.ZipFile(path) as archive:
                self.assertEqual(archive.read("preamble_mt.txt"), b"(25,0);\n(75,0);\n")
            report, writes, f, e, s, p = compile_plan(path, 60, True)
            self.assertEqual(struct.pack(f"<{len(f)}I", *f), plan.blocks[0])
            self.assertEqual(struct.pack(f"<{len(e)}I", *e), plan.blocks[1])
            self.assertEqual(struct.pack("<256I", *s), plan.blocks[2])
            self.assertEqual(p, plan.payload)
            self.assertEqual(report["actual_pwm_hz"], plan.actual_pwm_hz)
            self.assertEqual(report["logical_K"], 3)
            self.assertEqual(report["K"], 1)
            self.assertEqual([v for a,v in writes if a==0x204], [16])


if __name__ == "__main__": unittest.main()
