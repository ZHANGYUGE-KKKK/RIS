"""Spatial RIS patterns and playlists, independent of FPC/chip wiring."""
import json
import os
from pathlib import Path
import tempfile
import uuid

from ris_mapping import GEOMETRY, integer, source

MODES = {"once": "顺序一次", "loop": "顺序循环", "pingpong": "往返循环", "random": "随机循环"}


class Pattern:
    def __init__(self, rows=None):
        rows = ["0" * 20] * 20 if rows is None else rows
        if not isinstance(rows, (tuple, list)) or len(rows) != 20 or any(
                not isinstance(row, str) or len(row) != 20 or set(row) - {"0", "1"} for row in rows):
            raise ValueError("图案需要20行，每行20个0或1")
        self.rows = tuple(rows)

    def count(self):
        return sum(row.count("1") for row in self.rows)

    def cell(self, row, column, value):
        integer(row, 1, 20, "行")
        integer(column, 1, 20, "列")
        integer(value, 0, 1, "电平")
        rows = list(self.rows)
        rows[row - 1] = rows[row - 1][:column - 1] + str(value) + rows[row - 1][column:]
        return Pattern(rows)

    def line(self, axis, index, value):
        integer(index, 1, 20, "行列编号")
        integer(value, 0, 1, "电平")
        if axis == "row":
            rows = list(self.rows)
            rows[index - 1] = str(value) * 20
        elif axis == "column":
            rows = [row[:index - 1] + str(value) + row[index:] for row in self.rows]
        else:
            raise ValueError("未知行列类型")
        return Pattern(rows)

    def inverted(self):
        return Pattern([row.translate(str.maketrans("01", "10")) for row in self.rows])


def _mapped_cells(mapping):
    if mapping.count() != 400 or len(mapping.ports) != 10:
        raise ValueError("下发整幅图案前，请先载入完整的400路映射")
    cells = {}
    for key, entry in mapping.channels.items():
        if not (entry["basis"] == "wiring" or entry["verified"]):
            raise ValueError(f"FPC{key[0]}/CH{key[1]:02d} 的手动映射尚未实测确认")
        cells[entry["row"], entry["column"]] = source(*key)
    if len(cells) != 400:
        raise ValueError("映射包含重复位置")
    return cells


def compile_frame(pattern, mapping):
    image = bytearray(50)
    for (row, column), info in _mapped_cells(mapping).items():
        if pattern.rows[row - 1][column - 1] == "1":
            image[info["chip"]] |= 1 << info["bit"]
    return bytes(image)


def from_image(image, mapping):
    if len(image) != 50:
        raise ValueError("板端图案长度应为50字节")
    rows = [["0"] * 20 for _ in range(20)]
    for (row, column), info in _mapped_cells(mapping).items():
        rows[row - 1][column - 1] = str((image[info["chip"]] >> info["bit"]) & 1)
    return Pattern(["".join(row) for row in rows])


def dwell_ms(value):
    return integer(value, 100, 3600000, "停留时间(ms)")


class PatternLibrary:
    def __init__(self):
        self.patterns = {}
        self.playlist = []
        self.mode = "once"

    @classmethod
    def defaults(cls):
        result = cls()
        for name, rows in (("全0", ["0" * 20] * 20), ("全1", ["1" * 20] * 20),
                           ("棋盘格", ["".join(str((r + c) % 2) for c in range(20)) for r in range(20)])):
            result.put(name, Pattern(rows))
        return result

    def put(self, name, pattern, pattern_id=None):
        if not isinstance(name, str) or not name.strip() or len(name.strip()) > 64:
            raise ValueError("图案名需要1–64个字符")
        name = name.strip()
        if pattern_id is not None and pattern_id not in self.patterns:
            raise ValueError("所选图案已不存在")
        if any(p["name"] == name and key != pattern_id for key, p in self.patterns.items()):
            raise ValueError("已有同名图案，请更换名称或选择原图案后保存")
        if pattern_id is None and len(self.patterns) >= 256:
            raise ValueError("图案库最多保存256个图案")
        key = pattern_id or uuid.uuid4().hex
        self.patterns[key] = {"id": key, "name": name, "rows": list(pattern.rows)}
        return key

    def delete(self, key):
        del self.patterns[key]
        self.playlist = [step for step in self.playlist if step["pattern"] != key]

    def add_step(self, key, duration):
        if key not in self.patterns:
            raise ValueError("请先保存或选择图案")
        if len(self.playlist) >= 1024:
            raise ValueError("播放列表最多1024项")
        self.playlist.append({"pattern": key, "dwell_ms": dwell_ms(duration)})

    def document(self):
        return {"format": "RIS-PATTERN-LIBRARY", "version": 1, "geometry": dict(GEOMETRY),
                "patterns": list(self.patterns.values()), "playlist": [dict(s) for s in self.playlist], "mode": self.mode}

    @classmethod
    def from_document(cls, doc):
        if not isinstance(doc, dict) or doc.get("format") != "RIS-PATTERN-LIBRARY" or type(doc.get("version")) is not int or doc["version"] != 1:
            raise ValueError("不是支持的RIS图案库JSON（不能使用FPC映射JSON代替）")
        if doc.get("geometry") != GEOMETRY or not isinstance(doc.get("mode"), str) or doc["mode"] not in MODES:
            raise ValueError("图案库的尺寸、方向或播放模式不匹配")
        patterns, steps = doc.get("patterns"), doc.get("playlist")
        if not isinstance(patterns, list) or len(patterns) > 256 or not isinstance(steps, list) or len(steps) > 1024:
            raise ValueError("图案或播放列表格式/长度错误")
        result = cls()
        for item in patterns:
            if not isinstance(item, dict) or set(item) != {"id", "name", "rows"}:
                raise ValueError("图案记录格式错误")
            key = item["id"]
            if not isinstance(key, str) or not key or len(key) > 128 or key in result.patterns:
                raise ValueError("图案ID无效或重复")
            generated = result.put(item["name"], Pattern(item["rows"]))
            value = result.patterns.pop(generated)
            result.patterns[key] = {**value, "id": key}
        for step in steps:
            if not isinstance(step, dict) or set(step) != {"pattern", "dwell_ms"} or not isinstance(step["pattern"], str):
                raise ValueError("播放项格式错误")
            result.add_step(step["pattern"], step["dwell_ms"])
        result.mode = doc["mode"]
        return result

    @classmethod
    def load(cls, path):
        def unique(pairs):
            result = {}
            for key, value in pairs:
                if key in result:
                    raise ValueError(f"JSON字段重复：{key}")
                result[key] = value
            return result
        with Path(path).open(encoding="utf-8") as stream:
            return cls.from_document(json.load(stream, object_pairs_hook=unique))

    def save(self, path):
        # Validate before replacing a persistent library.
        self.from_document(self.document())
        path = Path(path)
        name = None
        try:
            with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent,
                                             prefix=".ris-pattern-", suffix=".tmp", delete=False) as stream:
                name = stream.name
                json.dump(self.document(), stream, ensure_ascii=False, indent=2)
                stream.write("\n")
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(name, path)
        finally:
            if name and os.path.exists(name):
                os.unlink(name)
