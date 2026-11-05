"""RIS mappings and the user-confirmed back-inserted 4x10 adapter wiring."""
import copy
import csv
import json
import os
from pathlib import Path
import tempfile

ROWS = COLS = 20
CHANNELS = 40
PORTS = tuple(f"{side}{i}" for side in ("T", "B") for i in range(1, 6))
GEOMETRY = {"rows": 20, "columns": 20, "half_rows": 10,
            "columns_per_port": 4, "ports_per_side": 5,
            "view": "topology_BIAS_at_top"}
LEGACY_WIRING_PROFILE = "back_insert_4x10_straight_20261023"
WIRING_PROFILE = "back_insert_4x10_straight_measured_rows_20261023"


def integer(value, minimum, maximum, label):
    if type(value) is not int or not minimum <= value <= maximum:
        raise ValueError(f"{label}需要在 {minimum}–{maximum} 之间")
    return value


def source(fpc, channel):
    integer(fpc, 1, 10, "FPC")
    integer(channel, 1, 40, "通道")
    output = (fpc - 1) * 40 + channel - 1
    chip, bit = divmod(output, 8)
    return {"output": output + 1, "chip": chip, "reference": f"U{chip + 4}", "bit": bit}


def adapter_terminal(channel):
    """Local RIS_Q001..040 on the adapter; U1..U4 here are its headers."""
    integer(channel, 1, CHANNELS, "通道")
    header, pin = divmod(40 - channel, 10)
    pair, offset = divmod(channel - 1, 2)
    return {"adapter_net": f"RIS_Q{channel:03d}", "header": f"U{header + 1}",
            "header_pin": pin + 1, "fpc_pin": 60 - pair * 3 - offset}


def pin_trace(fpc, channel):
    info = source(fpc, channel)
    return {**info, **adapter_terminal(channel), "chip_pin": info["bit"] + 2,
            "control_net": f"RIS_Q{info['output']:03d}"}


def wired_cell(port, channel):
    """Measured RIS rows; top U4/U3/U2/U1 and bottom U1/U2/U3/U4."""
    if port not in PORTS:
        raise ValueError("未知 RIS 接口")
    terminal = adapter_terminal(channel)
    header = int(terminal["header"][1])
    left = (int(port[1]) - 1) * 4 + 1
    if port[0] == "T":
        return 11 - terminal["header_pin"], left + 4 - header
    return 10 + terminal["header_pin"], left + header - 1


def reverse_half_row(row):
    """Reverse each 10-row half separately, retaining its top/bottom region."""
    integer(row, 1, ROWS, "行")
    return 11 - row if row <= 10 else 31 - row


def probe_command(fpc, channel):
    info = source(fpc, channel)
    frame = bytearray(50)
    frame[info["chip"]] = 1 << info["bit"]
    return "FRAME " + frame.hex().upper()


def fpc_probe_command(fpc):
    integer(fpc, 1, 10, "FPC")
    frame = bytearray(50)
    frame[(fpc - 1) * 5:fpc * 5] = b"\xff" * 5
    return "FRAME " + frame.hex().upper()


def cell_port(row, column):
    integer(row, 1, ROWS, "行")
    integer(column, 1, COLS, "列")
    return f"{'T' if row <= 10 else 'B'}{(column - 1) // 4 + 1}"


def port_label(port):
    if port not in PORTS:
        raise ValueError("未知 RIS 接口")
    start = (int(port[1]) - 1) * 4 + 1
    return f"{'上端' if port[0] == 'T' else '下端'} {port[1]} · 列 {start}–{start + 3}"


class RisMapping:
    def __init__(self):
        self.ports = {}
        self.channels = {}
        self.notes = ""
        self.migration_message = ""

    def copy(self):
        return copy.deepcopy(self)

    def bind(self, fpc, port):
        integer(fpc, 1, 10, "FPC")
        if port not in PORTS:
            raise ValueError("请选择 RIS 上端或下端接口")
        owner = next((key for key, value in self.ports.items() if value == port and key != fpc), None)
        if owner is not None:
            raise ValueError(f"{port_label(port)} 已绑定 FPC{owner}，请先解除该绑定")
        if self.ports.get(fpc) != port and self.count(fpc):
            raise ValueError("此 FPC 已有通道映射；请先清除此 FPC，再更换接口（可撤销）")
        self.ports[fpc] = port

    def unbind(self, fpc):
        integer(fpc, 1, 10, "FPC")
        self.ports.pop(fpc, None)
        self.channels = {key: value for key, value in self.channels.items() if key[0] != fpc}

    def bind_wiring(self, fpc, port):
        candidate = self.copy()
        candidate.bind(fpc, port)
        candidate.generate_wiring(fpc)
        self.ports, self.channels = candidate.ports, candidate.channels

    def generate_wiring(self, fpc=None):
        """Fill missing records atomically; preserve records and reject conflicts."""
        if fpc is not None:
            integer(fpc, 1, 10, "FPC")
        groups = sorted(self.ports) if fpc is None else [fpc]
        if not groups or any(group not in self.ports for group in groups):
            raise ValueError("请先绑定 FPC 与 RIS 接口")
        candidate = self.copy()
        for group in groups:
            for channel in range(1, 41):
                row, column = wired_cell(candidate.ports[group], channel)
                previous = candidate.channels.get((group, channel))
                if previous:
                    if (previous["row"], previous["column"]) != (row, column):
                        raise ValueError(f"FPC{group}/CH{channel:02d} 的已有记录与接线表 R{row:02d} C{column:02d} 不同；"
                                         "已保留全部原记录，请核对后再生成")
                else:
                    candidate.assign(group, channel, row, column, basis="wiring")
        self.channels = candidate.channels

    def pending(self, fpc):
        return [channel for channel in range(1, 41)
                if (fpc, channel) not in self.channels or
                (self.channels[fpc, channel]["basis"] == "wiring" and not self.channels[fpc, channel]["verified"])]

    def count(self, fpc=None, verified=False):
        return sum((fpc is None or key[0] == fpc) and (not verified or value["verified"])
                   for key, value in self.channels.items())

    def at(self, row, column):
        for key, value in self.channels.items():
            if (value["row"], value["column"]) == (row, column):
                return key
        return None

    def assign(self, fpc, channel, row, column, verified=False, basis="manual"):
        source(fpc, channel)
        port = cell_port(row, column)
        if type(verified) is not bool:
            raise ValueError("实测确认标记必须是布尔值")
        if basis not in ("manual", "wiring"):
            raise ValueError("未知映射依据")
        if fpc not in self.ports:
            raise ValueError("请先将此 FPC 绑定到一个 RIS 接口")
        if port != self.ports[fpc]:
            raise ValueError(f"该单元不在 FPC{fpc} 的 {port_label(self.ports[fpc])} 范围内")
        if basis == "wiring" and (row, column) != wired_cell(port, channel):
            raise ValueError("接线表映射与已确认的安装方向不一致")
        owner = self.at(row, column)
        if owner is not None and owner != (fpc, channel):
            raise ValueError(f"R{row:02d} C{column:02d} 已对应 FPC{owner[0]} / CH{owner[1]:02d}；请先移除原记录")
        self.channels[fpc, channel] = {"row": row, "column": column, "verified": verified, "basis": basis}

    def remove(self, fpc, channel):
        source(fpc, channel)
        self.channels.pop((fpc, channel), None)

    def document(self):
        return {"format": "RIS-FPC-MAPPING", "version": 2, "wiring_profile": WIRING_PROFILE,
                "geometry": dict(GEOMETRY),
                "channel_convention": "five_chips_ascending_each_Q0_to_Q7_not_connector_pin_number",
                "ports": {str(k): self.ports[k] for k in sorted(self.ports)},
                "channels": [{"fpc": key[0], "channel": key[1], **self.channels[key]}
                             for key in sorted(self.channels)], "notes": self.notes}

    @classmethod
    def from_document(cls, doc):
        if not isinstance(doc, dict) or doc.get("format") != "RIS-FPC-MAPPING" or type(doc.get("version")) is not int or doc["version"] not in (1, 2):
            raise ValueError("不是支持的 RIS 映射文件（version=1/2）")
        legacy = doc["version"] == 2 and doc.get("wiring_profile") == LEGACY_WIRING_PROFILE
        if doc["version"] == 2 and doc.get("wiring_profile") not in (WIRING_PROFILE, LEGACY_WIRING_PROFILE):
            raise ValueError("映射文件的小板接线或安装方向不匹配")
        if doc.get("geometry") != GEOMETRY:
            raise ValueError("映射文件的阵列尺寸或观察方向不匹配")
        if doc.get("channel_convention") != "five_chips_ascending_each_Q0_to_Q7_not_connector_pin_number":
            raise ValueError("映射文件的通道编号约定不匹配")
        if not isinstance(doc.get("ports"), dict) or not isinstance(doc.get("channels"), list):
            raise ValueError("接口或通道记录格式错误")
        result = cls()
        for fpc, port in doc["ports"].items():
            if fpc not in {str(i) for i in range(1, 11)}:
                raise ValueError("映射文件包含无效的 FPC 编号")
            result.bind(int(fpc), port)
        for entry in doc["channels"]:
            fields = {"fpc", "channel", "row", "column", "verified"}
            if doc["version"] == 2:
                fields.add("basis")
            if not isinstance(entry, dict) or set(entry) != fields:
                raise ValueError("通道记录缺少字段或包含未知字段")
            source(entry["fpc"], entry["channel"])
            key = entry["fpc"], entry["channel"]
            if key in result.channels:
                raise ValueError("映射文件包含重复的通道")
            basis = entry.get("basis", "manual")
            if legacy and basis == "wiring":
                row, column = wired_cell(result.ports.get(entry["fpc"]), entry["channel"])
                if (entry["row"], entry["column"]) != (reverse_half_row(row), column):
                    raise ValueError("旧版接线表记录与原接线规则不一致，未载入")
                # Validate the original file's bounds, region and uniqueness before
                # migrating. The current wiring rule must not accept old rows.
                result.assign(*key, entry["row"], entry["column"], entry["verified"], basis="manual")
                result.channels[key]["basis"] = "wiring"
            else:
                result.assign(*key, entry["row"], entry["column"], entry["verified"], basis)
        if not isinstance(doc.get("notes", ""), str):
            raise ValueError("备注格式错误")
        result.notes = doc.get("notes", "")
        if legacy:
            corrected = cls()
            corrected.ports = dict(result.ports)
            corrected.notes = result.notes
            count = 0
            for key, value in result.channels.items():
                row, verified = value["row"], value["verified"]
                if value["basis"] == "wiring":
                    row, verified = reverse_half_row(row), False
                    count += 1
                try:
                    corrected.assign(*key, row, value["column"], verified, value["basis"])
                except ValueError as error:
                    raise ValueError(f"旧版行映射修正与手动记录冲突，未载入：{error}") from error
            corrected.migration_message = (f"已按实测修正旧版接线表的{count}路行映射（上区01↔10，下区11↔20）；"
                                           "保留FPC绑定、列号和手动记录，修正项需重新实测；请保存JSON")
            return corrected
        return result

    @classmethod
    def load(cls, path):
        def unique(pairs):
            result = {}
            for key, value in pairs:
                if key in result:
                    raise ValueError(f"JSON 包含重复字段：{key}")
                result[key] = value
            return result
        with Path(path).open(encoding="utf-8") as stream:
            return cls.from_document(json.load(stream, object_pairs_hook=unique))

    def save(self, path):
        # Write next to the destination, then replace atomically.
        path = Path(path)
        name = None
        try:
            with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent,
                                             prefix=".ris-map-", suffix=".tmp", delete=False) as stream:
                name = stream.name
                json.dump(self.document(), stream, ensure_ascii=False, indent=2)
                stream.write("\n")
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(name, path)
        finally:
            if name and os.path.exists(name):
                os.unlink(name)

    def export_csv(self, path):
        with Path(path).open("w", encoding="utf-8-sig", newline="") as stream:
            writer = csv.writer(stream)
            writer.writerow(["FPC", "logical_channel", "output", "chip_index_0based", "reference", "Q",
                             "RIS_port", "row", "column", "verified", "basis", "chip_pin", "FPC_pin",
                             "control_net", "adapter_net", "adapter_header", "header_pin"])
            for fpc in range(1, 11):
                for channel in range(1, 41):
                    info = pin_trace(fpc, channel)
                    value = self.channels.get((fpc, channel), {})
                    writer.writerow([fpc, channel, info["output"], info["chip"], info["reference"],
                                     info["bit"], self.ports.get(fpc, ""), value.get("row", ""),
                                     value.get("column", ""), int(value["verified"]) if value else "",
                                     value.get("basis", ""), info["chip_pin"], info["fpc_pin"], info["control_net"],
                                     info["adapter_net"], info["header"], info["header_pin"]])
