"""Independent time-domain oracle, parser, limits and command stream tests."""
from pathlib import Path
from decimal import Decimal
import random
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'host'))
from ris_mt import compile_mt, parse_mt, load_mt, MIN_TICKS, MAX_TICKS


def output(plan, time):
    if time < plan.initial_delay:
        return 0
    time -= plan.initial_delay
    for level, duration in plan.segments:
        if time < duration:
            return level
        time -= duration
    if not plan.loop:
        return 0
    tail = plan.segments[plan.loop_start:]
    time %= sum(d for _, d in tail)
    for level, duration in tail:
        if time < duration:
            return level
        time -= duration
    raise AssertionError('unreachable')


class MTTests(unittest.TestCase):
    def test_requested_example(self):
        p = compile_mt(parse_mt('(50,10);\n(30,0);'), '1', 'M', False)
        self.assertEqual(p.period, 300)
        for t in range(900):
            self.assertEqual(output(p, t), int(30 <= t < 180 or 300 <= t < 390), t)

    def test_user_wrap_example_is_present_from_first_cycle(self):
        for loop in (False, True):
            p = compile_mt(parse_mt('(50,80);'), '1', 'M', loop)
            self.assertEqual(p.initial_delay, 0)
            if loop:
                self.assertEqual(p.loop_start, 3)
                self.assertEqual(p.segments, ((1,90),(0,150),(1,150),(0,150),(1,150)))
            else:
                self.assertEqual(p.segments, ((1,90),(0,150),(1,60),(0,30)))
            for t in range(1500):
                expected = (t % 300 < 90 or t % 300 >= 240) if loop or t < 300 else False
                self.assertEqual(output(p, t), expected, (loop, t))

    def test_once_wraps_inside_last_cycle_then_drives_low(self):
        p = compile_mt(parse_mt('(80,80);'), '1', 'M', False)
        for t in range(700):
            self.assertEqual(output(p, t), int(t < 180 or 240 <= t < 300), t)

    def test_adjacent_rows_are_independent_including_zero_and_full_duty(self):
        rows = parse_mt('(50,80);\n(0,0);\n(30,0);\n(100,100);')
        for loop in (False, True):
            p = compile_mt(rows, '1', 'M', loop)
            for t in range(3600):
                cycle, phase = divmod(t, 300)
                m, delay = rows[cycle % len(rows)]
                expected = ((phase - int(delay)*3) % 300 < int(m)*3
                            if loop or cycle < len(rows) else False)
                self.assertEqual(output(p, t), expected, (loop, t))

    def test_random_tables_against_independent_circular_phase_oracle(self):
        rng = random.Random(706)
        for _ in range(80):
            rows = tuple((Decimal(rng.randrange(11) * 10), Decimal(rng.randrange(11) * 10))
                         for _ in range(rng.randrange(1, 6)))
            for loop in (False, True):
                p = compile_mt(rows, '1', 'M', loop)
                n = len(rows)
                for t in range(0, n * 300 * 4, 7):
                    cycle, phase = divmod(t, 300)
                    m, delay = rows[cycle % n]
                    expected = ((phase - int(delay)*3) % 300 < int(m)*3
                                if loop or cycle < n else False)
                    self.assertEqual(output(p, t), expected, (rows, loop, t, p))

    def test_static_zero_full_duty_and_delay_endpoints(self):
        for text in ('(0,100);', '(100,0);', '(100,100);'):
            rows = parse_mt(text)
            for loop in (False, True):
                p = compile_mt(rows, '1', 'Hz', loop)
                self.assertTrue(all(d >= MIN_TICKS for _, d in p.segments))
                self.assertEqual(output(p, 0), int(rows[0][0] == 100))

    def test_short_pulses_and_quantization_rejected(self):
        for text, freq in (('(50,10);\n(30,0);', '5'), ('(.01,0);', '1'), ('(99,0);', '1')):
            with self.assertRaises(ValueError):
                compile_mt(parse_mt(text), freq, 'M')
        p = compile_mt(parse_mt('(50,0);'), '2.4', 'M')
        self.assertEqual(p.period, 125)  # MT uses complete-cycle resolution
        self.assertEqual(p.segments[0][1], 63)

    def test_parser_limits_and_matlab_examples(self):
        self.assertEqual(len(parse_mt('\ufeff% comment\n(50.5,10);\n30,0; # comment')), 2)
        for text in ('', '(nan,0);', '(-1,0);', '(101,0);', '(50,10', '50,10);', '(50,10); junk', '(1,2,3);'):
            with self.assertRaises(ValueError):
                parse_mt(text)
        with self.assertRaises(ValueError):
            parse_mt('(50,0);\n' * 513)
        for path in (Path(__file__).parents[1] / 'matlab').glob('*.txt'):
            self.assertTrue(compile_mt(load_mt(path), '1', 'M').segments)

    def test_long_constant_segments_are_split_without_changing_time(self):
        p = compile_mt(parse_mt('(100,0);\n' * 20), '1', 'Hz')
        self.assertTrue(all(30 <= ticks <= MAX_TICKS for _, ticks in p.segments))
        self.assertEqual(sum(d for _, d in p.segments[p.loop_start:]), 6_000_000_000)
        self.assertTrue(output(p, 99_000_000_000))

    def test_command_stream_checksum_and_bounds(self):
        p = compile_mt(parse_mt('(50,10);\n(30,0);'), '1', 'M')
        commands = list(p.commands())
        self.assertTrue(commands[0].startswith('MTBEGIN '))
        self.assertEqual(commands[-1], f'MTSTART 1 {p.checksum}')
        self.assertTrue(all(len(c) < 140 for c in commands))
        self.assertEqual(len(commands), len(p.segments) + 2)


if __name__ == '__main__':
    unittest.main()
