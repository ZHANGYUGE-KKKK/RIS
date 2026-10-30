"""MT percentages -> circular pulses within each cycle -> hardware segments.

Time zero is a local playback origin after the hardware startup pipeline.
Each row is confined to its own cycle: excess pulse width wraps to that same
cycle's beginning. Playback starts with the complete first cycle waveform.
"""
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
import re

from ris_frequency import UNITS

CLOCK_HZ = 300_000_000
MIN_TICKS = 30  # eight 100 MHz shifts, guard and latch: 100 ns per update
MAX_TICKS = 0x7fffffff
MAX_ROWS = 512
MAX_SEGMENTS = 2048
NUMBER = r"(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)"
ROW = re.compile(rf"\(?\s*({NUMBER})\s*,\s*({NUMBER})\s*\)?\s*;?")


def parse_mt(text):
    rows = []
    for line_number, raw in enumerate(text.lstrip('\ufeff').splitlines(), 1):
        line = raw.split('%', 1)[0].split('#', 1)[0].strip()
        if not line:
            continue
        match = ROW.fullmatch(line)
        if not match or line.startswith('(') != (')' in line):
            raise ValueError(f"第 {line_number} 行：需要 (M,T);，数值单位为百分比")
        m, t = map(Decimal, match.groups())
        if not (0 <= m <= 100 and 0 <= t <= 100):
            raise ValueError(f"第 {line_number} 行：M、T 均需在 0～100% 之间")
        rows.append((m, t))
        if len(rows) > MAX_ROWS:
            raise ValueError(f"本版本最多 {MAX_ROWS} 个周期")
    if not rows:
        raise ValueError("MT 表为空")
    return tuple(rows)


def load_mt(path):
    path = Path(path)
    if path.stat().st_size > 128 * 1024:
        raise ValueError("MT 文件不能超过 128 KiB")
    return parse_mt(path.read_text(encoding='utf-8-sig'))


def rounded(value):
    return int(value.to_integral_value(rounding=ROUND_HALF_UP))


def merge_intervals(intervals):
    result = []
    for start, end in sorted(intervals):
        if end <= start:
            continue
        if result and start <= result[-1][1]:
            result[-1] = (result[-1][0], max(end, result[-1][1]))
        else:
            result.append((start, end))
    return result


@dataclass(frozen=True)
class MTPlan:
    rows: tuple
    requested: Decimal
    period: int
    loop: bool
    initial_delay: int
    loop_start: int
    segments: tuple  # (level, duration); last once segment is low

    @property
    def actual(self):
        return Decimal(CLOCK_HZ) / self.period

    @property
    def checksum(self):
        value = 2166136261
        for level, duration in self.segments:
            value = ((value ^ ((level << 31) | duration)) * 16777619) & 0xffffffff
        return value

    def commands(self):
        yield f"MTBEGIN {len(self.segments)} {self.loop_start} {self.period} {self.initial_delay}"
        for index, (level, ticks) in enumerate(self.segments):
            yield f"MTSEG {index} {level} {ticks}"
        yield f"MTSTART {int(self.loop)} {self.checksum}"


def compile_mt(rows, text, unit, loop=True):
    if not re.fullmatch(NUMBER, text.strip()) or len(text) > 64 or unit not in UNITS:
        raise ValueError("请输入有效频率数值及单位")
    requested = Decimal(text) * UNITS[unit]
    if not 1 <= requested <= 5_000_000:
        raise ValueError("频率范围为 1 Hz～5 MHz")
    if not rows or len(rows) > MAX_ROWS:
        raise ValueError(f"MT 表需要 1～{MAX_ROWS} 行")
    period = rounded(Decimal(CLOCK_HZ) / requested)
    pulse = []
    for index, (m, t) in enumerate(rows):
        m, t = Decimal(m), Decimal(t)
        if not (0 <= m <= 100 and 0 <= t <= 100):
            raise ValueError(f"第 {index + 1} 行：M、T 超出 0～100%")
        delay, width = rounded(t * period / 100), rounded(m * period / 100)
        if m > 0 and width == 0:
            raise ValueError(f"第 {index + 1} 行：高电平不足一个时钟，请降低频率")
        if width:
            delay %= period  # T=100% is the same phase as T=0%.
            base = index * period
            pulse.append((base + delay, base + min(period, delay + width)))
            if delay + width > period:
                pulse.append((base, base + delay + width - period))
    length = len(rows) * period
    # Adjacent equal levels can merge across table boundaries. A prefix and a
    # transition-aligned repeat suffix avoid redundant latches at those joins.
    intervals = merge_intervals([(s + tour * length, e + tour * length)
                                 for tour in range(3 if loop else 1) for s, e in pulse])
    if loop:
        transitions = sorted(x for interval in intervals for x in interval)
        anchor = next((x for x in transitions if length <= x < 2 * length), length)
        end = anchor + length
    else:
        anchor = None
        end = length
    boundaries = sorted({0, end, *([anchor] if anchor is not None else []),
                         *(x for interval in intervals for x in interval if 0 < x < end)})
    runs = []
    j = 0
    for start, stop in zip(boundaries, boundaries[1:]):
        while j < len(intervals) and intervals[j][1] <= start:
            j += 1
        level = int(j < len(intervals) and intervals[j][0] <= start < intervals[j][1])
        if runs and runs[-1][0] == level and start != anchor:
            runs[-1] = (level, runs[-1][1], stop)
        else:
            runs.append((level, start, stop))
    # A short initial low requires no 595 transaction: the driver establishes
    # low before start and the engine delays the first burst by this many ticks.
    initial_delay = 0
    if runs and runs[0][0] == 0 and runs[0][1] != anchor:
        duration = runs[0][2]
        if duration <= MAX_TICKS:
            initial_delay = duration
            runs.pop(0)
    if not loop:
        # Finish low at the exact end of the final cycle, then retain low.
        if runs and runs[-1][0] == 0:
            runs[-1] = (0, runs[-1][1], end + MIN_TICKS)
        else:
            runs.append((0, end, end + MIN_TICKS))
    if not runs:  # all-low once
        runs = [(0, 0, MIN_TICKS)]
    segments, loop_start = [], 0
    for level, start, stop in runs:
        if start == anchor:
            loop_start = len(segments)
        duration = stop - start
        if duration < MIN_TICKS:
            cycle = start // period + 1
            raise ValueError(f"周期 {cycle} 附近的{'高' if level else '低'}电平仅 {duration / .3:.6g} ns；"
                             "595 每次更新至少 100 ns，请降低频率或调整 MT 表")
        while duration > MAX_TICKS:
            chunk = min(MAX_TICKS, duration - MIN_TICKS)
            segments.append((level, chunk))
            duration -= chunk
        segments.append((level, duration))
    if len(segments) > MAX_SEGMENTS:
        raise ValueError(f"编译后超过 {MAX_SEGMENTS} 个时段，请缩短 MT 表")
    return MTPlan(tuple(rows), requested, period, bool(loop), initial_delay,
                  loop_start, tuple(segments))
