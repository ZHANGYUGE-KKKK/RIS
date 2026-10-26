"""Frequency planning for the 300 MHz, equal-half-cycle FPGA divider."""
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
import re

HALF_CLOCK_HZ = 150_000_000
MIN_HZ, MAX_HZ = Decimal(1), Decimal(5_000_000)
UNITS = {"Hz": 1, "k": 1000, "M": 1_000_000, "G": 1_000_000_000}


def frequency_text(hz):
    hz = Decimal(str(hz))
    for scale, unit in ((1_000_000_000, "GHz"), (1_000_000, "MHz"), (1000, "kHz")):
        if hz >= scale:
            return f"{(hz / scale).normalize():.9g} {unit}"
    return f"{hz.normalize():.9g} Hz"


def active_frequency(reply):
    """New firmware reports exact divider ticks; accept legacy preset replies."""
    if not reply:
        return 0
    if reply.get("fast_variable"):
        ticks = reply.get("fast_ticks", 0)
        return HALF_CLOCK_HZ / ticks if ticks else 0
    return reply.get("fast_mhz", 0) * 1_000_000


@dataclass(frozen=True)
class FrequencyPlan:
    requested: Decimal
    ticks: int

    @property
    def actual(self):
        return Decimal(HALF_CLOCK_HZ) / self.ticks


def plan_frequency(text, unit):
    text = text.strip()
    if len(text) > 64 or not re.fullmatch(r"(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)", text) or unit not in UNITS:
        raise ValueError("请输入正数，可带小数；使用右侧 Hz / k / M / G 选择单位。")
    hz = Decimal(text) * UNITS[unit]
    if not MIN_HZ <= hz <= MAX_HZ:
        raise ValueError("支持范围为 1 Hz～5 MHz；G 表示 GHz，例如 0.005 G = 5 MHz。")
    ticks = int((Decimal(HALF_CLOCK_HZ) / hz).to_integral_value(rounding=ROUND_HALF_UP))
    return FrequencyPlan(hz, ticks)
