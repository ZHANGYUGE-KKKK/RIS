"""Immutable QAM1 upload snapshots. ASCII chunks fit the existing 160-byte line.

CRC32 canonical order: seven LE u32 values (ticks,K,L,loop,frames,events,bytes),
then F (52 bytes/frame), E (4 bytes/event), S (256 LE words), P (raw bytes).
"""
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from fractions import Fraction
import struct
import zlib

from ris_qam256 import compile_tables, integer
from ris_qam_preamble import Preamble, assemble

CLOCK_HZ = 300_000_000
MIN_TICKS = 60
MAX_TICKS = 1_000_000
CHUNK_BYTES = 48


def timing_ticks(book, mode="source", slot_ns="200"):
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

    @property
    def frames(self): return len(self.blocks[0]) // 52
    @property
    def events(self): return len(self.blocks[1]) // 4
    @property
    def payload(self): return self.blocks[3]
    @property
    def actual_pwm_hz(self): return CLOCK_HZ / (self.slot_ticks * (self.logical_slots or self.slots))
    @property
    def data_repeats(self): return self.logical_repeats or self.repeats
    @property
    def data_payload(self): return self.logical_payload if self.preamble else self.payload
    @property
    def frame_cycles(self):
        return len(self.preamble.rows) + len(self.logical_payload)*self.logical_repeats if self.preamble else len(self.payload)*self.repeats
    @property
    def total_bytes(self): return sum(map(len, self.blocks))
    @property
    def crc(self):
        crc = zlib.crc32(struct.pack("<7I", self.slot_ticks, self.repeats, self.slots,
                                    int(self.loop), self.frames, self.events, len(self.payload)))
        for block in self.blocks: crc = zlib.crc32(block, crc)
        return crc

    def commands(self):
        yield f"QBEGIN {self.slot_ticks} {self.repeats} {self.slots} {int(self.loop)}"
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
        if reply.get("qam_clock_hz") != CLOCK_HZ or not reply.get("qam_min_ticks", MAX_TICKS + 1) <= self.slot_ticks <= reply.get("qam_max_ticks", 0):
            raise ValueError("播放片长与板端实际时钟/时序能力不匹配")


def make_plan(book, mapping, direction, orientation, state1_high, repeats, loop, payload, mode="source", slot_ns="200", preamble_rows=()):
    integer(repeats, 1, 1_000_000, "K")
    if type(loop) is not bool: raise ValueError("循环参数须为布尔值")
    integer(len(payload), 1, 4096, "QAM1待发数据字节数")
    ticks = timing_ticks(book, mode, slot_ns)
    patterns, events, index = compile_tables(book, mapping, direction, orientation, state1_high)
    integer(len(patterns) // 50, 1, 2048, "QAM1图案数")
    integer(len(events) // 4, 1, 32768, "QAM1时段数")
    if preamble_rows:
        preamble = Preamble.compile(preamble_rows, book.slots)
        blocks, group, copies = assemble(patterns, events, index, bytes(payload), repeats, loop, preamble)
        return QamPlan(blocks, ticks, 1, book.slots*group, loop, book.pwm_hz, book.fingerprint, book.angles[direction],
                       preamble, bytes(payload), repeats, book.slots, copies)
    frames = b"".join(patterns[p:p+50] + b"\0\0" for p in range(0, len(patterns), 50))
    symbols = b"".join(struct.pack("<HH", row["first_record"], row["record_count"]) for row in index)
    return QamPlan((frames, events, symbols, bytes(payload)), ticks, repeats, book.slots, loop,
                   book.pwm_hz, book.fingerprint, book.angles[direction])
