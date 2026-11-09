"""Validated, read-only PWM codebooks and offline controller plan export.

This module has no transport API. Output uses the existing GUI's total button.
"""
from dataclasses import dataclass
import csv
import hashlib
import io
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import struct
import tempfile
import zipfile
import zlib

from ris_mapping import source
from ris_patterns import Pattern, compile_frame

CONTENT = ("metadata.json", "symbols.csv", "elements.csv", "pulse_parameters.csv", "codebook_frames.bin", "README.txt")
MEMBERS = (*CONTENT, "SHA256SUMS.txt")
MAX_TOTAL = 64 * 1024 * 1024
MAX_PAYLOAD = 1024 * 1024
ORIENTATIONS = {
    "identity": "原向：行0在上、列0在左", "cw90": "顺时针旋转90°", "rotate180": "旋转180°",
    "ccw90": "逆时针旋转90°", "mirror_x": "左右镜像", "mirror_y": "上下镜像",
    "transpose": "主对角转置", "anti_transpose": "副对角转置",
}


def integer(value, minimum, maximum, label):
    if type(value) is not int or not minimum <= value <= maximum:
        raise ValueError(f"{label}需要在{minimum}–{maximum}之间")
    return value


def finite(value, label, positive=False):
    if type(value) not in (int, float) or not math.isfinite(value) or (positive and value <= 0):
        raise ValueError(f"{label}不是有效数值")
    return value


def transform_cell(row, column, orientation):
    """Zero-based codebook cell -> zero-based physical GUI cell."""
    integer(row, 0, 19, "行")
    integer(column, 0, 19, "列")
    transforms = {"identity": (row, column), "cw90": (column, 19 - row),
                  "rotate180": (19 - row, 19 - column), "ccw90": (19 - column, row),
                  "mirror_x": (row, 19 - column), "mirror_y": (19 - row, column),
                  "transpose": (column, row), "anti_transpose": (19 - column, 19 - row)}
    if orientation not in transforms:
        raise ValueError("请先选择码本相对实物的方向")
    return transforms[orientation]


def _read_members(path):
    path = Path(path).resolve()
    if path.is_dir():
        sizes = []
        for name in MEMBERS:
            item = path / name
            if item.is_symlink() or not item.is_file():
                raise ValueError(f"缺少普通码本文件：{name}")
            sizes.append(item.stat().st_size)
        if sum(sizes) > MAX_TOTAL:
            raise ValueError("码本文件总量不能超过64 MiB")
        data = {name: (path / name).read_bytes() for name in MEMBERS}
    else:
        with zipfile.ZipFile(path) as archive:
            infos = archive.infolist()
            names = [item.filename for item in infos]
            if len(names) != len(set(names)):
                raise ValueError("ZIP含重复文件名")
            for item in infos:
                name = PurePosixPath(item.filename)
                if name.is_absolute() or ".." in name.parts or "\\" in item.filename or (item.external_attr >> 16) & 0o170000 == 0o120000:
                    raise ValueError("ZIP包含不安全的文件路径或符号链接")
            candidates = [name[:-len("metadata.json")] for name in names if name.endswith("metadata.json")
                          and (name == "metadata.json" or name.endswith("/metadata.json"))]
            prefixes = [prefix for prefix in candidates if all(prefix + name in names for name in MEMBERS)]
            if len(prefixes) != 1:
                raise ValueError("ZIP必须包含唯一完整码本目录")
            prefix = prefixes[0]
            selected = [archive.getinfo(prefix + name) for name in MEMBERS]
            if sum(item.file_size for item in selected) > MAX_TOTAL:
                raise ValueError("ZIP解压后的码本总量不能超过64 MiB")
            data = {name: archive.read(prefix + name) for name in MEMBERS}
    if sum(map(len, data.values())) > MAX_TOTAL or len(data["metadata.json"]) > 256 * 1024 or len(data["SHA256SUMS.txt"]) > 16 * 1024:
        raise ValueError("码本大小超出限制")
    return data


def _csv(data, name, fields):
    reader = csv.DictReader(io.StringIO(data[name].decode("utf-8-sig"), newline=""))
    if reader.fieldnames is None or len(reader.fieldnames) != len(set(reader.fieldnames)) or not fields <= set(reader.fieldnames):
        raise ValueError(f"{name}缺少必要列")
    return reader


def gray_decode(value):
    decoded = 0
    while value:
        decoded ^= value
        value >>= 1
    return decoded


@dataclass(frozen=True)
class QamSymbol:
    i: int
    q: int
    real: float
    imag: float


@dataclass(frozen=True)
class QamCodebook:
    origin: Path
    metadata: dict
    frames: bytes
    symbols: tuple
    pulses: tuple
    checksums: dict
    fingerprint: str
    slots: int
    pwm_hz: float
    default_repeats: int
    angles: tuple

    @property
    def order(self): return len(self.symbols)

    @property
    def bits_per_symbol(self): return self.order.bit_length() - 1

    @classmethod
    def load(cls, path):
        """No extraction, file writes, dynamic imports, or hardware operations."""
        try:
            return cls._load(path)
        except (OSError, ValueError, KeyError, TypeError, IndexError, OverflowError, UnicodeError,
                csv.Error, zipfile.BadZipFile, RuntimeError, NotImplementedError, EOFError, zlib.error) as error:
            raise ValueError(f"码本未载入：{error}") from error

    @classmethod
    def _load(cls, path):
        data = _read_members(path)
        hashes = {}
        for line in data["SHA256SUMS.txt"].decode("utf-8-sig").splitlines():
            if not line.strip():
                continue
            match = re.fullmatch(r"([0-9a-fA-F]{64})\s+\*?([^\s]+)", line)
            if not match or match[2] not in CONTENT or match[2] in hashes:
                raise ValueError("SHA256清单格式、文件名或唯一性有误")
            hashes[match[2]] = match[1].lower()
        if set(hashes) != set(CONTENT):
            raise ValueError("SHA256清单未覆盖全部6个码本文件")
        for name, digest in hashes.items():
            if hashlib.sha256(data[name]).hexdigest() != digest:
                raise ValueError(f"文件校验失败：{name}")
        def reject_constant(value):
            raise ValueError(f"元数据含非有限数值：{value}")
        metadata = json.loads(data["metadata.json"], parse_constant=reject_constant)
        if metadata["format"] not in ("ris-qam256-pwm-v1", "ris-qam64-pwm-v1"):
            raise ValueError("不支持的码本格式")
        order = 64 if metadata["format"] == "ris-qam64-pwm-v1" else 256
        axis_bits = 3 if order == 64 else 4
        axis_max = (1 << axis_bits) - 1
        config, layout = metadata["config"], metadata["binary_layout"]
        if config.get("qam_order", order) != order:
            raise ValueError("QAM阶数与格式不一致")
        if config["rows"] != 20 or config["cols"] != 20:
            raise ValueError("本控制台仅支持20×20码本")
        slots = integer(config["slots"], 2, 4096, "每周期时间片数")
        repeats = integer(config["repeats"], 1, 1000000, "重复次数K")
        pwm = finite(config["pwm_mhz"], "PWM频率", positive=True) * 1e6
        integer(config["harmonic"], -1, 1, "谐波阶数")
        if config["harmonic"] == 0:
            raise ValueError("当前码本须为±1阶谐波")
        pitch_x = finite(config["col_pitch_mm"], "列距", positive=True) / 1000
        pitch_y = finite(config["row_pitch_mm"], "行距", positive=True) / 1000
        finite(config["carrier_ghz"], "载波频率", positive=True)
        amplitude = finite(config["amplitude_scale"], "幅度系数")
        if not 0 <= amplitude <= 1:
            raise ValueError("幅度系数应为0–1")
        directions = metadata["directions"]
        integer(len(directions), 1, 16, "方向数量")
        angles = tuple(finite(item["angle_deg"], "方向角") for item in directions)
        for item in directions:
            for key in ("evm_raw_percent", "evm_equalized_percent", "element_evm_percent"):
                if item.get(key) is not None and finite(item[key], key) < 0:
                    raise ValueError("模型EVM不能为负数")
        if any(type(item["index"]) is not int or item["index"] != index for index, item in enumerate(directions)):
            raise ValueError("方向索引不连续")
        if config["scan_angles_deg"] != list(angles) or metadata["shape"] != [len(directions), order, slots, 400]:
            raise ValueError("方向列表或shape与实际参数不一致")
        if layout["axes"] != ["direction", "symbol", "slot", "packed_unit"] or layout["frame_bytes"] != 50:
            raise ValueError("不支持的二进制轴顺序或帧大小")
        if layout["bit_order"] != "little: unit i at byte i//8 bit i%8; unused high bits zero" or layout["unit_order"] != "unit=row*cols+col, zero based":
            raise ValueError("不支持的位序或单元顺序")
        if layout["repeats_stored"] != 1 or layout["play_each_symbol_period_times"] != repeats:
            raise ValueError("文件内周期重复方式不一致")
        for name, expected in (("slot_seconds", 1 / (pwm * slots)), ("symbol_rate_baud", pwm / repeats), ("gross_bit_rate_bps", (axis_bits*2) * pwm / repeats)):
            if not math.isclose(finite(metadata[name], name, positive=True), expected, rel_tol=1e-9):
                raise ValueError(f"{name}与配置不一致")
        frames = data["codebook_frames.bin"]
        if len(frames) != len(directions) * order * slots * 50:
            raise ValueError("二进制文件长度与shape不一致")
        symbols = [None] * order
        for item in _csv(data, "symbols.csv", {"symbol", "hex_byte", "I", "Q", "normalized_real", "normalized_imag"}):
            symbol = integer(int(item["symbol"]), 0, order-1, "符号")
            if symbols[symbol] is not None or int(item["hex_byte"], 16) != symbol:
                raise ValueError("符号重复或字节标签不一致")
            if order == 64 and item.get("bits_IIIQQQ") != f"{symbol:06b}":
                raise ValueError("64QAM六位标签与符号ID不一致")
            i, q = int(item["I"]), int(item["Q"])
            if (i, q) != (2 * gray_decode(symbol >> axis_bits) - axis_max, 2 * gray_decode(symbol & axis_max) - axis_max):
                raise ValueError("符号Gray映射不一致")
            real, imag = float(item["normalized_real"]), float(item["normalized_imag"])
            if not math.isclose(real, i / (axis_max * math.sqrt(2)) * amplitude, abs_tol=1e-10) or not math.isclose(imag, q / (axis_max * math.sqrt(2)) * amplitude, abs_tol=1e-10):
                raise ValueError("符号归一化坐标不一致")
            symbols[symbol] = QamSymbol(i, q, real, imag)
        if any(item is None for item in symbols):
            raise ValueError("符号表不完整")
        seen = set()
        for item in _csv(data, "elements.csv", {"unit", "row", "col", "x_m", "y_m", "z_m"}):
            unit = integer(int(item["unit"]), 0, 399, "单元")
            row, column = divmod(unit, 20)
            expected = ((column - 9.5) * pitch_x, (row - 9.5) * pitch_y, 0)
            actual = tuple(float(item[key]) for key in ("x_m", "y_m", "z_m"))
            if unit in seen or (int(item["row"]), int(item["col"])) != (row, column) or not all(math.isclose(a, b, abs_tol=1e-10) for a, b in zip(actual, expected)):
                raise ValueError("单元索引或几何坐标不一致")
            seen.add(unit)
        if len(seen) != 400:
            raise ValueError("单元坐标表不完整")
        pulses = [None] * (len(directions) * order * 400)
        for item in _csv(data, "pulse_parameters.csv", {"direction", "symbol", "unit", "width_slots", "start_slot"}):
            direction = integer(int(item["direction"]), 0, len(directions) - 1, "方向索引")
            symbol = integer(int(item["symbol"]), 0, order-1, "符号")
            unit = integer(int(item["unit"]), 0, 399, "单元")
            index = (direction * order + symbol) * 400 + unit
            if pulses[index] is not None:
                raise ValueError("脉冲参数重复")
            pulses[index] = (integer(int(item["width_slots"]), 0, slots, "脉宽"), integer(int(item["start_slot"]), 0, slots - 1, "起点"))
        if any(item is None for item in pulses):
            raise ValueError("脉冲参数表不完整")
        # Reconstruct every 400-bit frame from the two transitions per cell.
        for direction in range(len(directions)):
            for symbol in range(order):
                edges, state = [0] * slots, 0
                for unit in range(400):
                    width, start = pulses[(direction * order + symbol) * 400 + unit]
                    bit = 1 << unit
                    if (-start) % slots < width:
                        state |= bit
                    if 0 < width < slots:
                        edges[start] ^= bit
                        edges[(start + width) % slots] ^= bit
                for slot in range(slots):
                    if slot:
                        state ^= edges[slot]
                    offset = ((direction * order + symbol) * slots + slot) * 50
                    if int.from_bytes(frames[offset:offset + 50], "little") != state:
                        raise ValueError(f"脉冲表与二进制图案不一致：方向{direction}，符号{symbol}，片{slot}")
        fingerprint = hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest()
        return cls(Path(path).resolve(), metadata, frames, tuple(symbols), tuple(pulses), hashes, fingerprint, slots, pwm, repeats, angles)

    def frame(self, direction, symbol, slot):
        integer(direction, 0, len(self.angles) - 1, "方向")
        integer(symbol, 0, self.order-1, "符号")
        integer(slot, 0, self.slots - 1, "时间片")
        offset = ((direction * self.order + symbol) * self.slots + slot) * 50
        return self.frames[offset:offset + 50]

    def pulse(self, direction, symbol, unit):
        self.frame(direction, symbol, 0)
        integer(unit, 0, 399, "单元")
        return self.pulses[(direction * self.order + symbol) * 400 + unit]

    def pattern(self, direction, symbol, slot, orientation="identity", state1_high=True):
        state = int.from_bytes(self.frame(direction, symbol, slot), "little")
        grid = [["0"] * 20 for _ in range(20)]
        for unit in range(400):
            row, column = transform_cell(*divmod(unit, 20), orientation)
            grid[row][column] = str(((state >> unit) & 1) ^ int(not state1_high))
        return Pattern(["".join(row) for row in grid])


def parse_symbol(text, order=256):
    if not re.fullmatch(r"[0-9a-fA-F]{1,2}", text.strip()):
        raise ValueError("符号需要是00–FF的十六进制字节")
    value = int(text, 16)
    if value >= order:
        raise ValueError(f"{order}QAM符号范围为00–{order-1:02X}，高位不能包含其他数据")
    return value


def payload_bytes(mode, symbol, text, file_bytes=None, order=256):
    if mode == "fixed":
        return bytes([parse_symbol(symbol, order)])
    if mode == "sweep":
        return bytes(range(order))
    if mode == "file":
        data = file_bytes
    elif mode == "hex":
        compact = re.sub(r"[\s,;]+", "", text)
        if not compact or len(compact) % 2 or not re.fullmatch(r"[0-9a-fA-F]+", compact):
            raise ValueError("序列需要完整十六进制字节，例如00 3F FF")
        if len(compact) > MAX_PAYLOAD * 2:
            raise ValueError("发送数据不能超过1 MiB")
        data = bytes.fromhex(compact)
    else:
        raise ValueError("请选择发送数据源")
    if not data or len(data) > MAX_PAYLOAD:
        raise ValueError("发送数据应为1字节–1 MiB，请先加载有效数据")
    if any(value >= order for value in data):
        raise ValueError(f"{order}QAM数据每字节保存一个符号ID，范围00–{order-1:02X}；不会截断高位")
    return bytes(data)


def read_payload(path):
    with Path(path).open("rb") as stream:
        data = stream.read(MAX_PAYLOAD + 1)
    if not data or len(data) > MAX_PAYLOAD:
        raise ValueError("二进制数据应为1字节–1 MiB")
    return data


def controller_permutation(mapping, orientation):
    compile_frame(Pattern(), mapping)  # Preserve the existing mapping checks.
    cells = {(entry["row"] - 1, entry["column"] - 1): source(*key) for key, entry in mapping.channels.items()}
    permutation = []
    for unit in range(400):
        key = transform_cell(*divmod(unit, 20), orientation)
        output = cells[key]
        permutation.append(output["chip"] * 8 + output["bit"])
    return tuple(permutation)


def compile_tables(book, mapping, direction, orientation, state1_high):
    """Return mapped dictionary, RLE events and immutable symbol descriptors."""
    permutation = controller_permutation(mapping, orientation)
    cache, dictionary, identifiers, events, index = {}, [], {}, bytearray(), []
    full_mask = (1 << 400) - 1
    for symbol in range(book.order):
        first_record, previous, duration = len(events) // 4, None, 0
        for slot in range(book.slots):
            original = book.frame(direction, symbol, slot)
            if original not in cache:
                bits, board = int.from_bytes(original, "little"), 0
                while bits:
                    low = bits & -bits
                    board |= 1 << permutation[low.bit_length() - 1]
                    bits ^= low
                if not state1_high:
                    board ^= full_mask
                cache[original] = board.to_bytes(50, "little")
            frame = cache[original]
            if frame not in identifiers:
                if len(dictionary) >= 65536:
                    raise ValueError("图案字典超过16位索引容量")
                identifiers[frame] = len(dictionary)
                dictionary.append(frame)
            current = identifiers[frame]
            if previous is not None and current != previous:
                events.extend(struct.pack("<HH", previous, duration))
                duration = 0
            previous, duration = current, duration + 1
        events.extend(struct.pack("<HH", previous, duration))
        index.append({"symbol": symbol, "first_record": first_record, "record_count": len(events) // 4 - first_record})
    return b"".join(dictionary), bytes(events), tuple(index)


def phase_reference_symbols(order, enabled=False):
    """Reference corners: bottom-left, top-left, top-right, bottom-right."""
    if type(enabled) is not bool:
        raise ValueError("相偏补偿开关须为布尔值")
    if not enabled:
        return b""
    if order == 256:
        return bytes.fromhex("00 08 88 80")
    if order == 64:
        return bytes.fromhex("00 04 24 20")
    raise ValueError("相偏补偿仅支持64QAM和256QAM")


def export_plan(path, book, mapping, direction, orientation, state1_high, repeats, loop, payload, preamble_rows=(), phase_compensation=False, pwm_hz=None, independent_prefix=False):
    """Export an offline snapshot. No claim of a currently supported wire protocol."""
    integer(repeats, 1, 1000000, "重复次数K")
    if type(state1_high) is not bool or type(loop) is not bool:
        raise ValueError("状态极性和循环方式须为布尔值")
    book.frame(direction, 0, 0)
    if not payload or len(payload) > MAX_PAYLOAD:
        raise ValueError("发送数据应为1字节–1 MiB")
    if any(value >= book.order for value in payload):
        raise ValueError("数据含超出码本范围的符号ID")
    destination = Path(path).resolve()
    if destination.suffix.lower() != ".zip":
        raise ValueError("播放配置包须保存为ZIP文件")
    if destination == book.origin or (book.origin.is_dir() and destination.is_relative_to(book.origin)):
        raise ValueError("请保存到新的位置，不能覆盖源码本")
    patterns, events, index = compile_tables(book, mapping, direction, orientation, state1_high)
    phase = phase_reference_symbols(book.order, phase_compensation)
    from ris_qam_frequency import plan_qam_frequency
    frequency = plan_qam_frequency(book, pwm_hz) if pwm_hz is not None else None
    document = mapping.document()
    encode = lambda value: (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode("utf-8")
    manifest = {"format": f"ris-qam{book.order}-host-plan-v1", "qam_order": book.order, "transport_ready": False,
                "purpose": "offline configuration snapshot for QAM1 compilation; does not start a device",
                "source_fingerprint": book.fingerprint, "source_checksums": book.checksums,
                "direction_index": direction, "angle_deg": book.angles[direction],
                "orientation": orientation, "state1_high": bool(state1_high),
                "mapping_sha256": hashlib.sha256(encode(document)).hexdigest(),
                "pwm_hz": book.pwm_hz, "slots_per_period": book.slots, "slot_seconds": 1 / (book.pwm_hz * book.slots),
                "repeats_per_symbol": repeats, "loop": bool(loop), "payload_bytes": len(payload),
                "one_pass_seconds": len(payload) * repeats / book.pwm_hz,
                "frame_bytes": 50, "frame_order": "controller chip index then Q0..Q7, little bit order",
                "dictionary_frames": len(patterns) // 50, "event_records": len(events) // 4,
                "event_format": "little-endian uint16 frame_id, uint16 duration_slots; symbol starts at q=0",
                "payload_format": f"bytes; each byte is an {'IIIQQQ' if book.order == 64 else 'IIIIQQQQ'} Gray label; repeat its PWM period K times"}
    files = {"manifest.json": encode(manifest), "source_metadata.json": encode(book.metadata),
             "mapping.json": encode(document), "patterns.bin": patterns,
             "events.bin": bytes(events), "symbol_index.json": encode(index), "payload.bin": bytes(payload)}
    if preamble_rows:
        from ris_qam_preamble import Preamble
        prefix = Preamble.compile(preamble_rows, book.slots)
        manifest["preamble"] = {"cycles": len(prefix.rows), "width_slots": list(prefix.widths),
                                "repeat_with_each_frame": True, "delay_zero": True}
        manifest["one_pass_seconds"] = (len(prefix.rows)+len(payload)*repeats)/book.pwm_hz
        files["manifest.json"] = encode(manifest)
        files["preamble_mt.txt"] = "".join(f"({m},0);\n" for m, _ in prefix.rows).encode("utf-8")
    if phase:
        manifest["phase_compensation"] = {"symbols": list(phase), "repeats_per_symbol": repeats,
                                          "repeat_with_each_frame": True}
        manifest["one_pass_seconds"] += len(phase)*repeats/book.pwm_hz
        files["manifest.json"] = encode(manifest)
    if frequency:
        manifest["output_timing"] = frequency.document()
        manifest["one_pass_seconds"] = ((len(prefix.rows) if preamble_rows else 0)
                                        + (len(phase)+len(payload))*repeats)*frequency.period_seconds
        files["manifest.json"] = encode(manifest)
    if independent_prefix:
        manifest["independent_prefix"] = True
        files["manifest.json"] = encode(manifest)
    files["SHA256SUMS.txt"] = "".join(f"{hashlib.sha256(data).hexdigest()}  {name}\n" for name, data in files.items()).encode()
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=destination.parent, suffix=".zip", delete=False) as stream:
            temporary = Path(stream.name)
            with zipfile.ZipFile(stream, "w", compression=zipfile.ZIP_DEFLATED) as archive:
                for name, data in files.items():
                    archive.writestr(name, data)
        os.replace(temporary, destination)
    finally:
        if temporary and temporary.exists():
            temporary.unlink()
    return manifest
