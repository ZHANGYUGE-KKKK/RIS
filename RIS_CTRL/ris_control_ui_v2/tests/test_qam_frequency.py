"""Frequency conversion, unchanged player protocols and portable output snapshots."""
from fractions import Fraction
from pathlib import Path
import struct
import sys
import tempfile
from types import SimpleNamespace
import unittest

BASE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BASE))
sys.path.insert(0, str(BASE.parents[1] / 'FPGA/ris_qam_backend/scripts'))
from compile_qam_plan import compile_plan
from ris_mapping import RisMapping
from ris_mt import parse_mt
from ris_qam256 import QamCodebook, export_plan
from ris_qam_frequency import frequency_limits, plan_qam_frequency, GLOBAL_MAX_HZ, range_text
from ris_qam_transport import make_plan


class FrequencyArithmeticTests(unittest.TestCase):
    def test_units_limits_and_rounding(self):
        for order, slots, hz in ((256, 256, 1000000), (64, 64, 160000)):
            b = SimpleNamespace(order=order, slots=slots, pwm_hz=hz)
            p = plan_qam_frequency(b, '19.53125' if slots==256 else '160', 'kHz')
            self.assertEqual(p.actual_hz, 19531.25 if order == 256 else 160000)
            for text in ('', '0', '-1', 'NaN', 'inf', '1e4', '1000000000'):
                with self.subTest(order=order, text=text), self.assertRaises(ValueError):
                    plan_qam_frequency(b, text)
            low, high = frequency_limits(b)
            for hz in (low/2, high*2):
                with self.assertRaisesRegex(ValueError, '支持'):
                    plan_qam_frequency(b, str(float(hz)))
            for unit, text in (('Hz', '15000'), ('kHz', '15'), ('MHz', '.015')):
                q = plan_qam_frequency(b, text, unit)
                self.assertEqual(q.actual_hz, plan_qam_frequency(b, '15000').actual_hz)
                divisor = Fraction(300000000, 15000)
                n = (divisor.numerator*2+divisor.denominator)//(2*divisor.denominator)
                self.assertEqual(q.period_ticks or q.slot_ticks, n)
                self.assertAlmostEqual(q.actual_hz*q.period_seconds, 1)

    def test_limits_only_depend_on_slices_and_global_64slice_ceiling(self):
        for slices in (16, 64, 256, 4096):
            books = [SimpleNamespace(order=order, slots=slices) for order in (64, 256)]
            self.assertEqual(frequency_limits(books[0]), frequency_limits(books[1]))
            for text in range_text(books[0]).split('～'):
                number, unit = text.split()
                plan_qam_frequency(books[0], number, unit)
            for hz in ('100', '10000', '160000'):
                try:
                    a = plan_qam_frequency(books[0], hz)
                except ValueError:
                    with self.assertRaises(ValueError): plan_qam_frequency(books[1], hz)
                else:
                    self.assertEqual(a, plan_qam_frequency(books[1], hz))
        self.assertEqual(frequency_limits(SimpleNamespace(slots=64))[1], GLOBAL_MAX_HZ)
        self.assertEqual(frequency_limits(SimpleNamespace(slots=256))[1], GLOBAL_MAX_HZ/4)


class FrequencyPacketTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.books = {256: QamCodebook.load(BASE.parents[1]/'QAM_RULES/256QAM/ris_256qam_256slice_codebook_0deg.zip'),
                     64: QamCodebook.load(BASE.parents[1]/'QAM_RULES/64QAM/ris_64qam_64slice_codebook')}
        cls.mapping = RisMapping.load(BASE/'mappings/ris_mapping.json')

    def test_default_commands_crc_and_tables_match_existing_players(self):
        for order, book in self.books.items():
            with self.subTest(order=order):
                old = make_plan(book, self.mapping, 0, 'identity', True, 3, True, b'\x01\x2a',
                                mode='bench' if order==256 else 'source')
                new = make_plan(book, self.mapping, 0, 'identity', True, 3, True, b'\x01\x2a',
                                pwm_hz='19531.25' if order==256 else '160000')
                self.assertEqual(new.actual_pwm_hz, old.actual_pwm_hz)
                if order==64:
                    self.assertEqual(list(new.commands()), list(old.commands()))
                else:
                    self.assertEqual(new.blocks[0], old.blocks[0])
                    self.assertEqual(new.blocks[2:], old.blocks[2:])
                    for (fid, n), (old_fid, old_n) in zip(struct.iter_unpack('<HH', new.blocks[1]), struct.iter_unpack('<HH', old.blocks[1])):
                        self.assertEqual((fid, n), (old_fid, old_n*60))

    def test_256qam_64slice_book_import_and_existing_profile_limits(self):
        book = QamCodebook.load(BASE.parents[1]/'QAM_RULES/256QAM/ris_256qam_64slice_codebook')
        self.assertEqual((book.order, book.slots, book.pwm_hz), (256, 64, 160000))
        plan = make_plan(book, self.mapping, 0, 'identity', True, 3, True, b'\x00\x88\xff', pwm_hz='160000')
        self.assertEqual((plan.modulation_order, plan.slot_ticks, plan.slots), (256, 1, 1875))
        self.assertEqual(plan.actual_pwm_hz, 160000)
        self.assertEqual(next(plan.commands()), 'Q64BEGIN 1 3 1875 1')
        self.assertEqual((plan.frames, plan.events), (585, 8687))
        with self.assertRaisesRegex(ValueError, '支持'):
            make_plan(self.books[256], self.mapping, 0, 'identity', True, 3, True, b'\x00', pwm_hz='160000')

    def test_changed_frequency_prefix_phase_and_export_match_live(self):
        rows = parse_mt('(25,0);\n(75,0);')
        with tempfile.TemporaryDirectory() as temp:
            for order, book in self.books.items():
                with self.subTest(order=order):
                    hz = '12345' if order==256 else '150123'
                    plan = make_plan(book, self.mapping, 0, 'identity', True, 2, True, b'\x01\x2a',
                                     preamble_rows=rows, phase_compensation=True, pwm_hz=hz)
                    timing = plan_qam_frequency(book, hz)
                    self.assertEqual(plan.actual_pwm_hz, timing.actual_hz)
                    self.assertEqual(plan.frame_cycles, 14)
                    # Decode the complete compiled frame: every logical PWM boundary
                    # remains on the same exact period, including the prefix transition.
                    descriptors = list(struct.iter_unpack('<HH', plan.blocks[2]))
                    events = list(struct.iter_unpack('<HH', plan.blocks[1]))
                    physical_duration = 0
                    for symbol in plan.payload:
                        first, count = descriptors[symbol]
                        physical_duration += sum(n for _, n in events[first:first+count])*plan.repeats
                    expected = plan.frame_cycles*(timing.period_ticks or book.slots)*plan.frame_copies
                    self.assertEqual(physical_duration, expected)
                    path = Path(temp)/f'frequency{order}.zip'
                    manifest = export_plan(path, book, self.mapping, 0, 'identity', True, 2, True, b'\x01\x2a',
                                           preamble_rows=rows, phase_compensation=True, pwm_hz=hz)
                    report, writes, frames, events, symbols, payload = compile_plan(path)
                    self.assertEqual(report['actual_pwm_hz'], plan.actual_pwm_hz)
                    self.assertEqual(manifest['output_timing'], timing.document())
                    self.assertAlmostEqual(manifest['one_pass_seconds'], 14/plan.actual_pwm_hz)
                    self.assertEqual(struct.pack(f'<{len(frames)}I', *frames), plan.blocks[0])
                    self.assertEqual(struct.pack(f'<{len(events)}I', *events), plan.blocks[1])
                    self.assertEqual(struct.pack('<256I', *symbols), plan.blocks[2])
                    self.assertEqual(bytes(payload), plan.payload)

    def test_low_frequency_export_uses_same_divider_for_both_orders(self):
        with tempfile.TemporaryDirectory() as temp:
            for order, book in self.books.items():
                plan = make_plan(book, self.mapping, 0, 'identity', True, 2, True, b'\x01\x2a',
                                 pwm_hz='100', phase_compensation=True)
                self.assertEqual(plan.base_period_ticks, 0)
                self.assertTrue(next(plan.commands()).startswith('QBEGIN '))
                path = Path(temp)/f'low{order}.zip'
                export_plan(path, book, self.mapping, 0, 'identity', True, 2, True, b'\x01\x2a',
                            pwm_hz='100', phase_compensation=True)
                report, _, frames, events, symbols, data = compile_plan(path)
                self.assertEqual(report['actual_pwm_hz'], plan.actual_pwm_hz)
                self.assertFalse(report['edge_tick_mode'])
                self.assertEqual(struct.pack(f'<{len(events)}I', *events), plan.blocks[1])
                self.assertEqual(bytes(data), plan.payload)


if __name__ == '__main__': unittest.main()
