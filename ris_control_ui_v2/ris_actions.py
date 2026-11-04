"""Prepared output snapshots and presentation of confirmed controller state."""
from dataclasses import dataclass

from ris_frequency import active_frequency, frequency_text
from ris_patterns import MODES


@dataclass(frozen=True)
class PlaybackStep:
    name: str
    image: bytes
    dwell_ms: int


@dataclass(frozen=True)
class PlaylistPlan:
    steps: tuple
    mode: str


@dataclass(frozen=True)
class OutputAction:
    kind: str
    payload: object
    summary: str
    callback: object = None
    mapping_document: object = None
    tag: str = ""


def describe_command(command):
    fields = command.split()
    op = fields[0]
    if op == "ALL":
        return f"400 路全{'低 · 0' if fields[1] == '0' else '高 · 1'}"
    if op == "STOP":
        return "停止切换 / 保持当前输出"
    if op == "OE":
        return "使能全板输出" if fields[1] == "1" else "禁能全板输出 · 高阻"
    if op == "BLINK":
        return f"全0 / 全1慢速循环 · 每次间隔 {fields[1]} ms"
    if op == "FASTTICKS":
        return f"全0 / 全1硬件方波 · {frequency_text(150_000_000 / int(fields[1]))}"
    if op == "BIT":
        return f"第 {int(fields[1]) + 1} 片 Q{fields[2]} → {fields[3]}"
    if op == "CHIP":
        return f"第 {int(fields[1]) + 1} 片 → HEX {fields[2]}"
    if op == "GROUP":
        return f"第 {int(fields[1]) + 1} 个 5 片组 → HEX {fields[2]}"
    if op == "FRAME":
        image = bytes.fromhex(fields[1])
        return f"静态图案 · {sum(value.bit_count() for value in image)}/400 路高"
    return command


def confirmed_status(connected, reply, action=None, playback=None):
    """Never infer a running mode from a page selection or an edited parameter."""
    if not connected or not reply:
        return "未连接", "工作状态未确认；连接后读取板端状态", "#94a3b8"
    if not reply["ok"] or reply["errors"]:
        return "执行异常", f"rc={reply['rc']} · 错误 0x{reply['errors']:08X}", "#fca5a5"
    if reply.get("qam_supported"):
        qs = reply["qam_status"]
        if reply.get("qam_uploading"):
            return "256QAM上传中", f"已确认 {reply['qam_received']:,}/{reply['qam_expected']:,} 字节 · 输出保持", "#93c5fd"
        if qs & 12:
            return "256QAM预检中", "等待FPGA检查完整符号表", "#93c5fd"
        if qs & 1:
            if reply["qam_error"]:
                return "256QAM执行异常", f"板端错误码 {reply['qam_error']} · 保持最后图案", "#fca5a5"
            frequency = 300000000 / (reply["qam_slot_ticks"] * reply["qam_period_slots"])
            prefix_plan = (action.payload if action and action.kind == "qam" and
                           getattr(action.payload, "preamble", None) and reply["qam_crc"] == action.payload.crc else None)
            if prefix_plan:
                detail = (f"PWM {frequency_text(prefix_plan.actual_pwm_hz)} · 前导{len(prefix_plan.preamble.rows)}周期 + "
                          f"{len(prefix_plan.logical_payload)}符号×K{prefix_plan.logical_repeats} · 包CRC {reply['qam_crc']:08X}")
            else:
                detail = f"板端索引周期 {frequency_text(frequency)} · 重复参数K={reply['qam_repeats']} · 包CRC {reply['qam_crc']:08X}"
            if not reply["oe"]:
                return "256QAM输出禁能", detail + " · 板端OE=0", "#fbbf24"
            if qs & 2:
                if prefix_plan:
                    return ("前导码 + 256QAM帧循环" if reply["qam_loop"] else "前导码 + 256QAM播放一次"), detail, "#5eead4"
                return ("256QAM循环播放" if reply["qam_loop"] else "256QAM播放一次"), detail, "#5eead4"
            return ("前导码 + 256QAM单次完成 · 保持" if prefix_plan else "256QAM单次完成 · 保持"), detail, "#cbd5e1"
    if not reply["oe"]:
        return "输出禁能 · 高阻", "板端已确认 OE=0", "#fbbf24"
    if reply.get("mt_running"):
        title, detail = "MT 模式运行", "循环方式未回读"
        if action and action.kind == "mt":
            plan = action.payload
            title = "MT 模式循环" if plan.loop else "MT 播放一次"
            if plan.loop and all(row[0] == 0 for row in plan.rows):
                title = "全0循环 · MT"
            elif plan.loop and all(row[0] == 100 for row in plan.rows):
                title = "全1循环 · MT"
            detail = f"{len(plan.rows)} 个周期 · {'循环整表' if plan.loop else '完成后置低'}"
        return title, f"{frequency_text(active_frequency(reply))} · {detail}", "#5eead4"
    if active_frequency(reply):
        return "全0 / 全1循环", f"FPGA 方波 · {frequency_text(active_frequency(reply))} · 50% 占空比", "#5eead4"
    if reply["blink_ms"]:
        return "全0 / 全1慢速循环", f"每次切换间隔 {reply['blink_ms']} ms", "#5eead4"
    if playback and playback.active and playback.confirmed_index is not None:
        index = playback.confirmed_index
        step = playback.steps[index]
        return f"图案 · {MODES[playback.mode]}", f"第 {index + 1}/{len(playback.steps)} 项 · {step['name']}", "#93c5fd"
    image = bytes.fromhex(reply["image"])
    count = sum(value.bit_count() for value in image)
    title = "停止 · 全0保持" if count == 0 else ("停止 · 全1保持" if count == 400 else "停止 · 图案保持")
    if action and action.kind == "mt" and not action.payload.loop:
        title = "MT 一次完成 · 全0保持"
    if action and action.tag == "qam_static" and action.payload == "FRAME " + reply["image"].upper():
        title = "256QAM静态码片"
        return title, f"静态保持 · {count}/400路高 · 非QAM播放", "#cbd5e1"
    return title, f"静态命令镜像 · {count}/400 路高 · 输出已使能", "#cbd5e1"
