"""Immutable QAM1 upload snapshots. ASCII chunks fit the existing 160-byte line.

CRC32 canonical order: seven LE u32 values (ticks,K,L,loop,frames,events,bytes),
then F (52 bytes/frame), E (4 bytes/event), S (256 LE words), P (raw bytes).
"""
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from fractions import Fraction
import struct
import zlib

from ris_qam256 import compile_tables, integer, phase_reference_symbols
from ris_qam_preamble import Preamble, assemble
from ris_qam64_timing import period_ticks, clock_events
from ris_qam_frequency import plan_qam_frequency

CLOCK_HZ = 300_000_000
MIN_TICKS = 60
MAX_TICKS = 1_000_000
CHUNK_BYTES = 48


def timing_ticks(book, mode="source", slot_ns="200"):
    if getattr(book, "order", 256) == 64 and mode == "source":
        period_ticks(book)
        return 1  # physical event durations are compiled in 300 MHz ticks
    if mode == "source":
        ticks = Fraction(CLOCK_HZ) / (Fraction(str(book.pwm_hz)) * book.slots)
        if ticks.denominator != 1 or not MIN_TICKS <= ticks <= MAX_TICKS:
            raise ValueError("码本原速不满足当前独立播放器时序；原速不会自动改动。可明确选择低速数字核线。")
        return int(ticks)
    if mode != "bench":
        raise ValueError("请选择播放时序")
    try:
        value = Decimal(str(slot_ns))
        if not value.is_finite():
            raise InvalidOperation
        ticks = value * Decimal("0.3")
        if ticks != ticks.to_integral_value() or not MIN_TICKS <= ticks <= MAX_TICKS:
            raise InvalidOperation
    except (InvalidOperation, ValueError):
        raise ValueError("核线片长须精确对应300 MHz整数时钟，范围200 ns～3333333.333… ns，例如200或400 ns。") from None
    return int(ticks)


@dataclass(frozen=True)
class QamPlan:
    blocks: tuple  # F, E, S, P; every item is immutable bytes
    slot_ticks: int
    repeats: int
    slots: int
    loop: bool
    source_pwm_hz: float
    fingerprint: str
    angle: float
    preamble: object = None
    logical_payload: bytes = b""
    logical_repeats: int = 0
    logical_slots: int = 0
    frame_copies: int = 1
    modulation_order: int = 256
    base_period_ticks: int = 0
    phase_symbols: bytes = b""

    @property
    def frames(self): return len(self.blocks[0]) // 52
    @property
    def events(self): return len(self.blocks[1]) // 4
    @property
    def payload(self): return self.blocks[3]
    @property
    def actual_pwm_hz(self): return CLOCK_HZ / (self.base_period_ticks or self.slot_ticks * (self.logical_slots or self.slots))
    @property
    def data_repeats(self): return self.logical_repeats or self.repeats
    @property
    def data_payload(self): return self.logical_payload if self.preamble or self.phase_symbols else self.payload
    @property
    def frame_cycles(self):
        return (len(self.preamble.rows) if self.preamble else 0) + (len(self.phase_symbols)+len(self.data_payload))*self.data_repeats
    @property
    def total_bytes(self): return sum(map(len, self.blocks))
    @property
    def crc(self):
        crc = zlib.crc32(struct.pack("<7I", self.slot_ticks, self.repeats, self.slots,
                                    int(self.loop), self.frames, self.events, len(self.payload)))
        if self.base_period_ticks: crc = zlib.crc32(struct.pack("<I", 64), crc)
        for block in self.blocks: crc = zlib.crc32(block, crc)
        return crc

    def commands(self):
        yield f"{'Q64BEGIN' if self.base_period_ticks else 'QBEGIN'} {self.slot_ticks} {self.repeats} {self.slots} {int(self.loop)}"
        yield f"QCOUNTS {self.frames} {self.events} {len(self.payload)} {self.crc}"
        for kind, block in zip("FESP", self.blocks):
            for offset in range(0, len(block), CHUNK_BYTES):
                yield f"QDATA {kind} {offset} {block[offset:offset+CHUNK_BYTES].hex().upper()}"
        yield f"QSTART {self.crc}"

    def check_capability(self, reply):
        if not reply or reply.get("qam_supported") is not True or reply.get("qam_abi") != 1:
            raise ValueError("板端未提供QAM1播放协议；请使用新副本配套的BIT和ELF。")
        for key, required in (("qam_max_frames", self.frames), ("qam_max_events", self.events),
                              ("qam_max_payload", len(self.payload))):
            if type(reply.get(key)) is not int or reply[key] < required:
                raise ValueError(f"播放包超过板端容量：{key}")
        if self.base_period_ticks:
            if reply.get("qam64_supported") is not True or reply.get("qam64_min_event_ticks") != 29 or reply.get("qam_clock_hz") != CLOCK_HZ:
                raise ValueError("板端未提供QAM边沿计时能力；请使用配套BIT和ELF")
            return
        if reply.get("qam_clock_hz") != CLOCK_HZ or not reply.get("qam_min_ticks", MAX_TICKS + 1) <= self.slot_ticks <= reply.get("qam_max_ticks", 0):
            raise ValueError("播放片长与板端实际时钟/时序能力不匹配")


def make_plan(book, mapping, direction, orientation, state1_high, repeats, loop, payload, mode="source", slot_ns="200", preamble_rows=(), phase_compensation=False, pwm_hz=None):
    integer(repeats, 1, 1_000_000, "K")
    if type(loop) is not bool: raise ValueError("循环参数须为布尔值")
    integer(len(payload), 1, 4096, "QAM1待发数据字节数")
    if any(value >= book.order for value in payload):
        raise ValueError(f"{book.order}QAM数据包含越界符号ID")
    phase = phase_reference_symbols(book.order, phase_compensation)
    stream = phase + bytes(payload)
    frequency = plan_qam_frequency(book, pwm_hz) if pwm_hz is not None else None
    ticks = frequency.slot_ticks if frequency else timing_ticks(book, mode, slot_ns)
    clock_period = frequency.period_ticks if frequency else 0
    if not frequency and book.order == 64:
        clock_period = period_ticks(book) if mode == "source" else ticks*book.slots
        integer(clock_period, 1, 65535, "64QAM每PWM周期时钟数")
        ticks = 1
    patterns, events, index = compile_tables(book, mapping, direction, orientation, state1_high)
    integer(len(patterns) // 50, 1, 2048, "QAM1图案数")
    integer(len(events) // 4, 1, 32768, "QAM1时段数")
    preamble = Preamble.compile(preamble_rows, book.slots) if preamble_rows else None
    if preamble or len(stream) > 4096:
        blocks, group, copies = assemble(patterns, events, index, stream, repeats, loop,
                                         preamble or Preamble((), (), book.slots),
                                         max_group=65535//clock_period if clock_period else None)
        if clock_period:
            blocks = (blocks[0], clock_events(blocks[1], blocks[2], book.slots, clock_period), blocks[2], blocks[3])
        return QamPlan(blocks, ticks, 1, (clock_period or book.slots)*group, loop, book.pwm_hz, book.fingerprint, book.angles[direction],
                       preamble, bytes(payload), repeats, book.slots, copies, book.order, clock_period, phase)
    frames = b"".join(patterns[p:p+50] + b"\0\0" for p in range(0, len(patterns), 50))
    symbols = b"".join(struct.pack("<HH", row["first_record"], row["record_count"]) for row in index)
    if book.order < 256:
        symbols += symbols[:4] * (256-book.order)  # unused hardware entries alias symbol 00
    if clock_period:
        events = clock_events(events, symbols, book.slots, clock_period)
    return QamPlan((frames, events, symbols, stream), ticks, repeats, clock_period or book.slots, loop,
                   book.pwm_hz, book.fingerprint, book.angles[direction], modulation_order=book.order,
                   base_period_ticks=clock_period, phase_symbols=phase,
                   logical_payload=bytes(payload) if phase else b"", logical_repeats=repeats if phase else 0,
                   logical_slots=book.slots if phase else 0)
