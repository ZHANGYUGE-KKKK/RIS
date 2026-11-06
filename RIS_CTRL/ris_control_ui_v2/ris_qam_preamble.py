"""Compile uniform MT preambles and QAM cycles into one existing QAM1 program."""
from array import array
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
import struct

from ris_qam256 import integer

MAX_PREAMBLE_ROWS = 10


@dataclass(frozen=True)
class Preamble:
    rows: tuple
    widths: tuple
    slots: int

    @classmethod
    def compile(cls, rows, slots):
        integer(slots, 1, 65535, "每周期片数")
        if not 1 <= len(rows) <= MAX_PREAMBLE_ROWS:
            raise ValueError("前导码MT表需要1–10行，每行对应一个PWM周期")
        saved, widths = [], []
        for i, (m, t) in enumerate(rows, 1):
            m, t = Decimal(m), Decimal(t)
            if not m.is_finite() or not t.is_finite() or not 0 <= m <= 100:
                raise ValueError(f"前导码第{i}行：占空比需要在0–100%之间")
            if t != 0:
                raise ValueError(f"前导码第{i}行：延时T必须为0")
            width = int((m * slots / 100).to_integral_value(rounding=ROUND_HALF_UP))
            if (m > 0 and width == 0) or (m < 100 and width == slots):
                raise ValueError(f"前导码第{i}行：脉冲或低电平不足一个时间片，请调整占空比")
            saved.append((m, t)); widths.append(width)
        return cls(tuple(saved), tuple(widths), slots)


def assemble(patterns, events, index, data, repeats, loop, preamble, max_group=None):
    """Equal-duration virtual symbols; one engine, one time grid, no host switch.

    A virtual symbol contains g whole PWM cycles; g divides the frame length.
    Every hardware payload pass is exactly one preamble plus the QAM cycles.
    """
    base = preamble.slots
    cycles_count = len(preamble.widths) + len(data) * repeats
    max_group = min(65535 // base, max_group) if max_group is not None else 65535 // base
    if not max_group or cycles_count > 4096 * max_group:
        raise ValueError("前导码与数据合帧超出现有播放器容量；请缩短数据或减小K")
    frames = [patterns[i:i+50] for i in range(0, len(patterns), 50)]
    frame_ids = {value: i for i, value in enumerate(frames)}
    def frame_id(value):
        if value not in frame_ids:
            frame_ids[value] = len(frames); frames.append(value)
        return frame_ids[value]
    low, high = (frame_id(bytes(50)), frame_id(bytes([255])*50)) if preamble.widths else (None, None)
    if len(frames) > 2048:
        raise ValueError("合帧后的图案字典超过2048幅")
    raw_events = tuple(struct.iter_unpack("<HH", events))
    waveforms = [raw_events[row["first_record"]:row["first_record"]+row["record_count"]] for row in index]
    aliases = {wave: i for i, wave in enumerate(waveforms)}
    sequence = array("H")
    for width in preamble.widths:
        wave = tuple((fid, n) for fid, n in ((high, width), (low, base-width)) if n)
        if wave not in aliases:
            aliases[wave] = len(waveforms); waveforms.append(wave)
        sequence.append(aliases[wave])
    for symbol in data:
        sequence.extend(array("H", [symbol]) * repeats)

    for group in range(max(1, (cycles_count + 4095)//4096), min(max_group, cycles_count)+1):
        if cycles_count % group:
            continue
        copies = 1
        count = cycles_count // group
        if count > 4096:
            continue
        chunks, program, descriptors, stream = {}, bytearray(), [], bytearray()
        fits = True
        for pos in range(count):
            start = pos * group
            key = tuple(sequence[(start+j) % cycles_count] for j in range(group))
            if key not in chunks:
                if len(chunks) == 256:
                    fits = False; break
                merged = []
                for cycle in key:
                    for fid, duration in waveforms[cycle]:
                        if merged and merged[-1][0] == fid:
                            merged[-1] = (fid, merged[-1][1]+duration)
                        else:
                            merged.append((fid, duration))
                if len(program)//4 + len(merged) > 32768:
                    fits = False; break
                chunks[key] = len(descriptors)
                descriptors.append((len(program)//4, len(merged)))
                program.extend(b"".join(struct.pack("<HH", *event) for event in merged))
            stream.append(chunks[key])
        if fits:
            # QAM1 preflights all 256 entries. Unused entries alias entry zero.
            symbols = b"".join(struct.pack("<HH", *(descriptors[i] if i < len(descriptors) else descriptors[0])) for i in range(256))
            padded = b"".join(frame+b"\0\0" for frame in frames)
            return (padded, bytes(program), symbols, bytes(stream)), group, copies
    raise ValueError("前导码与数据合帧超过256项索引或32768个时段容量；请缩短数据或减小K")
