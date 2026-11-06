"""QAM edge timing on the existing 300 MHz clock; 100 MHz SHCP unchanged."""
from fractions import Fraction
import struct

CLOCK_HZ = 300_000_000
MIN_EVENT_TICKS = 29


def period_ticks(book):
    ticks = Fraction(CLOCK_HZ) / Fraction(str(book.pwm_hz))
    if ticks.denominator != 1 or not 1 <= ticks <= 65535:
        raise ValueError("64QAM原速周期须对应300 MHz整数时钟且不超过65535 tick")
    ticks = int(ticks)
    if ticks // book.slots < MIN_EVENT_TICKS:
        raise ValueError("64QAM最短时间片不足29 tick，100 MHz移位路径不能播放")
    return ticks


def edge_tick(q, period, slots):
    # Round half up; exact endpoints at every PWM boundary, no cumulative drift.
    return (2*q*period + slots)//(2*slots)


def clock_events(events, symbols, base_slots, period):
    """Convert each descriptor independently, including aliases and supercycles."""
    converted = bytearray(events)
    source = tuple(struct.iter_unpack('<HH', events))
    done = set()
    for first, count in struct.iter_unpack('<HH', symbols):
        q = 0
        for i in range(first, first+count):
            fid, duration = source[i]
            n = edge_tick(q+duration, period, base_slots)-edge_tick(q, period, base_slots)
            if n < MIN_EVENT_TICKS or n > 65535:
                raise ValueError("QAM边沿间隔超出29–65535 tick；请调整码本或前导码")
            if i in done and struct.unpack_from('<HH', converted, i*4) != (fid,n):
                raise ValueError("共享事件描述的时间原点不一致")
            struct.pack_into('<HH', converted, i*4, fid, n)
            done.add(i);q += duration
    return bytes(converted)
