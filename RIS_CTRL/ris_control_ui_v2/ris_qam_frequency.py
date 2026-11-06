"""PWM timing depends on the slice grid, independently of constellation order."""
from dataclasses import dataclass
from decimal import Decimal, ROUND_CEILING, ROUND_FLOOR
from fractions import Fraction
import re

from ris_frequency import frequency_text

CLOCK_HZ = 300_000_000
GLOBAL_MAX_HZ = Fraction(CLOCK_HZ, 29 * 64)
UNITS = {"Hz": 1, "kHz": 1000, "MHz": 1_000_000}


def frequency_limits(book):
    minimum_ticks = 29 if 29 * book.slots <= 65535 else 60
    return Fraction(CLOCK_HZ, 1_000_000 * book.slots), min(
        GLOBAL_MAX_HZ, Fraction(CLOCK_HZ, minimum_ticks * book.slots))


def range_text(book):
    low, high = frequency_limits(book)
    def inside(value, rounding):
        hz = Decimal(value.numerator)/Decimal(value.denominator)
        # Display endpoints that can be copied back without crossing a limit.
        step = Decimal(1).scaleb(hz.adjusted()-8)
        return frequency_text(hz.quantize(step, rounding=rounding))
    return f"{inside(low, ROUND_CEILING)}～{inside(high, ROUND_FLOOR)}"


@dataclass(frozen=True)
class QamFrequency:
    requested_hz: Decimal
    slot_ticks: int
    period_ticks: int  # nonzero for edge timing; unrelated to modulation order
    slots: int

    @property
    def actual_hz(self):
        return CLOCK_HZ / (self.period_ticks or self.slot_ticks * self.slots)

    @property
    def period_seconds(self):
        return (self.period_ticks or self.slot_ticks * self.slots) / CLOCK_HZ

    @property
    def error_ppm(self):
        return (self.actual_hz / float(self.requested_hz) - 1) * 1e6

    def document(self):
        return {"requested_pwm_hz": str(self.requested_hz), "actual_pwm_hz": self.actual_hz,
                "slot_ticks": self.slot_ticks, "period_ticks": self.period_ticks}


def plan_qam_frequency(book, text, unit="Hz"):
    text = str(text).strip()
    if (len(text) > 64 or not re.fullmatch(r"(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)", text)
            or unit not in UNITS):
        raise ValueError("请输入正数PWM频率，并选择Hz / kHz / MHz单位")
    hz = Decimal(text) * UNITS[unit]
    low, high = frequency_limits(book)
    if not low <= Fraction(hz) <= high:
        raise ValueError(f"当前码本{book.slots} slice，输出PWM频率支持 {range_text(book)}；请调整频率")
    divider = Fraction(CLOCK_HZ, 1) / Fraction(hz)
    ticks = (2 * divider.numerator + divider.denominator) // (2 * divider.denominator)
    if 29 * book.slots <= ticks <= 65535:
        return QamFrequency(hz, 1, ticks, book.slots)
    # Longer periods use the existing integer-slice divider. The selection is
    # identical for both modulation orders; neither profile changes SHCP.
    divider /= book.slots
    ticks = (2 * divider.numerator + divider.denominator) // (2 * divider.denominator)
    if not 60 <= ticks <= 1_000_000:
        raise ValueError(f"当前码本{book.slots} slice无法实现该频率；请调整输出PWM频率")
    return QamFrequency(hz, ticks, 0, book.slots)


