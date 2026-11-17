"""Compile uniform MT preambles: QPR1 independent prefix and legacy QAM1 exports."""
from array import array
from dataclasses import dataclass
import struct

from ris_qam256 import integer
from ris_mt import MAX_PREAMBLE_ROWS, pulse_ticks, validate_preamble


@dataclass(frozen=True)
class Preamble:
    rows: tuple
    widths: tuple
    slots: int

    @classmethod
    def compile(cls, rows, slots):
        integer(slots, 1, 65535, "每周期片数")
        saved, widths = validate_preamble(rows), []
        for i, (m, t) in enumerate(saved, 1):
            _, width = pulse_ticks(m, t, slots)
            if (m > 0 and width == 0) or (m < 100 and width == slots):
                raise ValueError(f"前导码第{i}行：脉冲或低电平不足一个时间片，请调整占空比")
            widths.append(width)
        return cls(tuple(saved), tuple(widths), slots)

    @property
    def delays(self):
        return tuple(pulse_ticks(m, t, self.slots)[0] for m, t in self.rows)

    def runs(self, index, clock_period=0):
        """One complete cycle: leading low, pulse, trailing low; no wrap."""
        from ris_qam64_timing import edge_tick
        width, delay = self.widths[index], self.delays[index]
        period = clock_period or self.slots
        if not width:
            return ((0, period),)
        start = edge_tick(delay, period, self.slots) if clock_period else delay
        end = edge_tick(delay+width, period, self.slots) if clock_period else delay+width
        return tuple((level, n) for level, n in ((0, start), (1, end-start), (0, period-end)) if n)


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
    for i in range(len(preamble.rows)):
        wave = tuple((high if level else low, n) for level, n in preamble.runs(i))
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


def independent_blocks(patterns, events, index, payload, preamble, phase, clock_period=0):
    """Full QAM dictionary plus a separate, fixed-period prefix descriptor bank.

    Prefix entries do not consume symbol IDs or payload bytes. Preamble is in
    physical high/low levels, independent of the QAM state polarity mapping.
    """
    from ris_qam64_timing import clock_events
    frames = [patterns[i:i+50] for i in range(0, len(patterns), 50)]
    symbols = b"".join(struct.pack("<HH", row["first_record"], row["record_count"]) for row in index)
    symbols += symbols[:4] * (256-len(index))
    physical = bytearray(clock_events(events, symbols, preamble.slots, clock_period) if clock_period else events)
    prefix = bytearray()
    def frame_id(value):
        if value not in frames:
            frames.append(value)
        return frames.index(value)
    if preamble.rows:
        low, high = frame_id(bytes(50)), frame_id(b"\xff"*50)
        for i in range(len(preamble.rows)):
            wave = [(high if level else low, n) for level, n in preamble.runs(i, clock_period)]
            if clock_period and any(n < 29 for _, n in wave):
                raise ValueError("前导码脉冲或低电平短于595更新时间，请调整占空比或降低PWM频率")
            prefix.extend(struct.pack("<HH", len(physical)//4, len(wave)))
            physical.extend(b"".join(struct.pack("<HH", *event) for event in wave))
    for symbol in phase:
        prefix.extend(symbols[symbol*4:symbol*4+4])
    if len(frames)>2048 or len(physical)//4>32768:
        raise ValueError("QAM和前导码超过2048幅图案或32768个时段容量")
    return (b"".join(frame+b"\0\0" for frame in frames), bytes(physical), symbols, bytes(payload)), bytes(prefix)
