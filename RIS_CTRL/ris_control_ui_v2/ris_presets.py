"""Portable, data-only output presets. Reading/exporting never contacts a board."""
from dataclasses import fields
from decimal import Decimal, InvalidOperation
import json
import math
import os
from pathlib import Path
import re
import struct
import tempfile

from ris_actions import OutputAction, PlaybackStep, PlaylistPlan
from ris_mapping import RisMapping
from ris_mt import compile_mt
from ris_patterns import MODES, dwell_ms
from ris_qam256 import phase_reference_symbols
from ris_qam_preamble import Preamble
from ris_qam_transport import QamPlan

FORMAT = "ris-control-preset"
MAX_FILE_BYTES = 2 * 1024 * 1024
MAX_SLOTS = 10


def integer(value, low, high, name):
    if type(value) is not int or not low <= value <= high:
        raise ValueError(f"{name}需要是{low}–{high}之间的整数")
    return value


def boolean(value, name):
    if type(value) is not bool:
        raise ValueError(f"{name}需要是布尔值")
    return value


def text(value, name, limit=1024):
    if not isinstance(value, str) or len(value) > limit or any(ord(c) < 32 for c in value):
        raise ValueError(f"{name}格式有误")
    return value


def hex_bytes(value, maximum, name, minimum=0):
    if not isinstance(value, str) or len(value) % 2 or not minimum * 2 <= len(value) <= maximum * 2 or not re.fullmatch(r"[0-9a-fA-F]*", value):
        raise ValueError(f"{name}的十六进制数据或长度有误")
    return bytes.fromhex(value)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"JSON字段重复：{key}")
        result[key] = value
    return result


def invalid_constant(_):
    raise ValueError("JSON包含非有限数值")


def read_json(path, maximum=MAX_FILE_BYTES):
    # Bound reads even when a file grows while being read.
    with Path(path).open("rb") as stream:
        raw = stream.read(maximum + 1)
    if len(raw) > maximum:
        raise ValueError("预设文件过大")
    try:
        return json.loads(raw.decode("utf-8-sig"), object_pairs_hook=unique_object, parse_constant=invalid_constant)
    except (UnicodeError, json.JSONDecodeError, RecursionError) as error:
        raise ValueError("预设JSON格式有误") from error


def write_json(path, document):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(document, stream, ensure_ascii=False, indent=2, allow_nan=False)
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        if temporary and temporary.exists():
            temporary.unlink()


def validate_command(command):
    command = text(command, "输出指令", 128)
    words = command.split(" ")
    op = words[0]
    if command == "STOP":
        return command
    if op in ("ALL", "OE") and len(words) == 2 and words[1] in ("0", "1"):
        return command
    if op == "FRAME" and len(words) == 2:
        return "FRAME " + hex_bytes(words[1], 50, "静态图案", 50).hex().upper()
    limits = {"BLINK": ((100, 60000),), "FASTTICKS": ((30, 150000000),),
              "BIT": ((0, 49), (0, 7), (0, 1))}
    if op in limits and len(words) == len(limits[op]) + 1:
        if all(re.fullmatch(r"[0-9]{1,10}", word) and low <= int(word) <= high
               for word, (low, high) in zip(words[1:], limits[op])):
            return " ".join((op, *(str(int(word)) for word in words[1:])))
    if op in ("CHIP", "GROUP") and len(words) == 3 and re.fullmatch(r"[0-9]{1,2}", words[1]):
        if 0 <= int(words[1]) < (50 if op == "CHIP" else 10):
            return f"{op} {int(words[1])} {hex_bytes(words[2], 1, '芯片字节', 1).hex().upper()}"
    raise ValueError("预设包含不支持或参数越界的输出指令")


def decimal_rows(value, maximum):
    if not isinstance(value, list) or not 1 <= len(value) <= maximum:
        raise ValueError(f"MT表需要1–{maximum}行")
    result = []
    for row in value:
        if not isinstance(row, list) or len(row) != 2:
            raise ValueError("MT表每行需要M和T两个数值")
        try:
            numbers = tuple(Decimal(text(v, "MT百分比", 64)) for v in row)
            if not all(v.is_finite() and 0 <= v <= 100 for v in numbers):
                raise ValueError("MT百分比需要在0–100之间")
        except InvalidOperation as error:
            raise ValueError("MT百分比格式有误") from error
        result.append(numbers)
    return tuple(result)


def validate_qam(plan):
    """Validate loaded tables before the global button can stop an old run."""
    integer(plan.modulation_order, 64, 256, "QAM阶数")
    if plan.modulation_order not in (64, 256):
        raise ValueError("只支持64QAM或256QAM")
    boolean(plan.loop, "循环")
    boolean(plan.independent_prefix, "独立前缀")
    integer(plan.slot_ticks, 1 if plan.base_period_ticks else 60, 1000000, "计时参数")
    integer(plan.slots, 1, 65535, "硬件周期")
    integer(plan.repeats, 1, 1000000, "K")
    integer(plan.base_period_ticks, 0, 65535, "PWM周期计时")
    integer(plan.logical_slots, 0, 4096, "码本slice数")
    integer(plan.logical_repeats, 0, 1000000, "数据K")
    integer(plan.frame_copies, 1, 4096, "帧重复数")
    for value, name in ((plan.source_pwm_hz, "源码本频率"), (plan.angle, "码本方向")):
        if type(value) not in (int, float) or not math.isfinite(value):
            raise ValueError(f"{name}有误")
    if plan.source_pwm_hz <= 0:
        raise ValueError("源码本频率需要大于0")
    text(plan.fingerprint, "码本指纹", 256)
    if plan.base_period_ticks and (plan.slot_ticks != 1 or plan.slots % plan.base_period_ticks):
        raise ValueError("QAM周期计时不一致")
    if len(plan.blocks[0]) % 52 or not 1 <= plan.frames <= 2048:
        raise ValueError("QAM图案字典有误")
    if any(plan.blocks[0][i+50:i+52] != b"\0\0" for i in range(0, len(plan.blocks[0]), 52)):
        raise ValueError("QAM图案填充字段有误")
    if len(plan.blocks[1]) % 4 or not 1 <= plan.events <= 32768 or len(plan.blocks[2]) != 1024:
        raise ValueError("QAM事件或符号表长度有误")
    if not 1 <= len(plan.payload) <= 4096 or len(plan.prefix_descriptors) % 4 or len(plan.prefix_descriptors) > 56:
        raise ValueError("QAM正式数据或前缀长度有误")
    events = tuple(struct.iter_unpack("<HH", plan.blocks[1]))
    if any(fid >= plan.frames or duration < (29 if plan.base_period_ticks else 1) for fid, duration in events):
        raise ValueError("QAM事件的图案索引或持续时间有误")
    descriptors = tuple(struct.iter_unpack("<HH", plan.blocks[2] + plan.prefix_descriptors))
    for first, count in set(descriptors):
        if not count or first + count > plan.events or sum(n for _, n in events[first:first+count]) != plan.slots:
            raise ValueError("QAM描述索引或PWM周期有误")
    if plan.phase_symbols and plan.phase_symbols != phase_reference_symbols(plan.modulation_order, True):
        raise ValueError("相偏参考点与调制方式不匹配")
    if plan.preamble and plan.preamble.slots != plan.logical_slots:
        raise ValueError("前导码与码本slice数不一致")
    if plan.independent_prefix:
        rows = len(plan.preamble.rows) if plan.preamble else 0
        if (len(plan.prefix_descriptors) != 4*(rows+len(plan.phase_symbols)) or
                plan.logical_payload != plan.payload or plan.logical_repeats != plan.repeats or
                not plan.logical_slots or plan.slots != (plan.base_period_ticks or plan.logical_slots) or
                any(v >= plan.modulation_order for v in plan.payload)):
            raise ValueError("QAM前缀与正式数据参数不一致")
        if plan.base_period_ticks and plan.base_period_ticks < 29*plan.logical_slots:
            raise ValueError("QAM的PWM频率超出slice网格上限")
        if plan.actual_pwm_hz > 300000000/(29*64) + 0.000001:
            raise ValueError("QAM的PWM频率超出支持范围")
        for i, symbol in enumerate(plan.phase_symbols):
            if descriptors[256+rows+i] != descriptors[symbol]:
                raise ValueError("相偏描述与QAM符号表不一致")
        if plan.preamble:
            for i in range(len(plan.preamble.rows)):
                expected = [(b"\xff"*50 if level else bytes(50), n)
                            for level, n in plan.preamble.runs(i, plan.base_period_ticks)]
                first, count = descriptors[256+i]
                actual = [(plan.blocks[0][fid*52:fid*52+50], n) for fid, n in events[first:first+count]]
                if actual != expected:
                    raise ValueError("前导码MT参数与输出表不一致")
    elif plan.prefix_descriptors:
        raise ValueError("旧QAM模式不能包含独立前缀")


def document_for_action(action, source="", name=None):
    if action.kind == "command":
        payload = {"command": validate_command(action.payload)}
    elif action.kind == "mt":
        plan = action.payload
        payload = {"rows": [[format(m, "f"), format(t, "f")] for m, t in plan.rows],
                   "requested_hz": format(plan.requested, "f"), "loop": plan.loop}
    elif action.kind == "playlist":
        payload = {"mode": action.payload.mode,
                   "steps": [{"name": step.name, "image_hex": step.image.hex(), "dwell_ms": step.dwell_ms}
                             for step in action.payload.steps]}
    elif action.kind == "qam":
        plan = action.payload
        payload = {field.name: getattr(plan, field.name) for field in fields(plan)
                   if field.name not in ("blocks", "preamble", "logical_payload", "phase_symbols", "prefix_descriptors")}
        payload["blocks"] = {key: block.hex() for key, block in zip("FESP", plan.blocks)}
        payload["logical_payload"] = plan.logical_payload.hex()
        payload["phase_symbols"] = plan.phase_symbols.hex()
        payload["prefix_descriptors"] = plan.prefix_descriptors.hex()
        payload["preamble"] = ({"slots": plan.preamble.slots,
                                "rows": [[format(m, "f"), format(t, "f")] for m, t in plan.preamble.rows]}
                               if plan.preamble else None)
        payload["crc32"] = plan.crc
    else:
        raise ValueError("当前操作不支持导出为预设")
    document = {"format": FORMAT, "version": 1, "name": name or action.summary,
                "source": source, "action": {"kind": action.kind, "summary": action.summary,
                                             "tag": action.tag, "payload": payload},
                "mapping": action.mapping_document}
    action_from_document(document)
    return document


def action_from_document(document):
    try:
        if not isinstance(document, dict) or document.get("format") != FORMAT or type(document.get("version")) is not int or document["version"] != 1:
            raise ValueError("请选择由“导出当前配置”生成的RIS预设JSON")
        text(document["name"], "预设名称")
        text(document["source"], "来源功能")
        data = document["action"]
        kind, summary, tag, payload = data["kind"], text(data["summary"], "配置说明"), text(data["tag"], "配置标识", 64), data["payload"]
        mapping = document.get("mapping")
        if mapping is not None:
            mapping = RisMapping.from_document(mapping).document()
        if kind == "command":
            plan = validate_command(payload["command"])
        elif kind == "mt":
            rows = decimal_rows(payload["rows"], 512)
            plan = compile_mt(rows, text(payload["requested_hz"], "MT频率", 64), "Hz", boolean(payload["loop"], "MT循环"))
        elif kind == "playlist":
            steps = payload["steps"]
            if payload["mode"] not in MODES or not isinstance(steps, list) or not 1 <= len(steps) <= 1024:
                raise ValueError("图案播放模式或列表长度有误")
            plan = PlaylistPlan(tuple(PlaybackStep(text(step["name"], "图案名称"),
                               hex_bytes(step["image_hex"], 50, "图案", 50), dwell_ms(step["dwell_ms"])) for step in steps), payload["mode"])
        elif kind == "qam":
            args = dict(payload)
            crc = integer(args.pop("crc32"), 0, 0xffffffff, "QAM包CRC")
            blocks = args.pop("blocks")
            args["blocks"] = tuple(hex_bytes(blocks[key], maximum, "QAM"+key)
                                   for key, maximum in zip("FESP", (2048*52, 32768*4, 1024, 4096)))
            for key, maximum in (("logical_payload", 4096), ("phase_symbols", 4), ("prefix_descriptors", 56)):
                args[key] = hex_bytes(args[key], maximum, key)
            prefix = args["preamble"]
            args["preamble"] = Preamble.compile(decimal_rows(prefix["rows"], 10), integer(prefix["slots"], 1, 4096, "前导码slice数")) if prefix is not None else None
            if set(args) != {field.name for field in fields(QamPlan)}:
                raise ValueError("QAM配置字段缺失或版本不支持")
            plan = QamPlan(**args)
            validate_qam(plan)
            if plan.crc != crc:
                raise ValueError("QAM预设CRC不一致，文件可能不完整")
        else:
            raise ValueError("不支持的预设功能类型")
        return OutputAction(kind, plan, summary, mapping_document=mapping, tag=tag)
    except (KeyError, TypeError, AttributeError, OverflowError, RecursionError) as error:
        raise ValueError("预设字段缺失、类型错误或版本不支持") from error


def load_preset(path):
    document = read_json(path)
    return document, action_from_document(document)


def save_preset(path, action, source=""):
    if Path(path).suffix.lower() != ".json":
        raise ValueError("预设请保存为JSON文件")
    document = document_for_action(action, source, Path(path).stem)
    if len(json.dumps(document, ensure_ascii=False, indent=2, allow_nan=False).encode("utf-8")) + 1 > MAX_FILE_BYTES:
        raise ValueError("预设文件超过2 MiB，请减少播放项或缩短名称")
    write_json(path, document)
    return document
