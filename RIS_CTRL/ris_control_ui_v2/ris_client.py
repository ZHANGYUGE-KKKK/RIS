#!/usr/bin/env python3
"""RIS706 TCP client. One outstanding request; mutating commands are not retried."""
import json
import socket

DEFAULT_HOST = "192.168.1.11"
DEFAULT_PORT = 7060


class ProtocolError(RuntimeError):
    pass


class RisClient:
    def __init__(self, host=DEFAULT_HOST, port=DEFAULT_PORT, timeout=3.0):
        self.socket = socket.create_connection((host, port), timeout=timeout)
        self.socket.settimeout(timeout)
        self.socket.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.sequence = 0
        self.buffer = bytearray()

    def close(self):
        self.socket.close()

    def command(self, command):
        if any(c in command for c in "\r\n\x00"):
            raise ValueError("A command must be one text line")
        self.sequence = self.sequence % 0xffffffff + 1
        wire = f"{self.sequence} {command}\n".encode("ascii")
        if len(wire) >= 160:
            raise ValueError("Command is too long")
        self.socket.sendall(wire)
        while b"\n" not in self.buffer:
            data = self.socket.recv(1024)
            if not data:
                raise ConnectionError("板卡关闭了连接")
            self.buffer.extend(data)
            if len(self.buffer) > 4096:
                raise ProtocolError("板卡响应超过长度限制")
        line, _, rest = self.buffer.partition(b"\n")
        self.buffer[:] = rest
        try:
            reply = json.loads(line)
            if reply["device"] != "RIS706" or reply["version"] != 1 or reply["id"] != self.sequence:
                raise ValueError("设备或命令编号不匹配")
            image = bytes.fromhex(reply["image"])
            if len(image) != 50 or any(type(reply[k]) is not int for k in ("rc", "status", "errors", "frames", "blink_ms", "slots")):
                raise ValueError("状态字段格式错误")
            if type(reply["ok"]) is not bool or type(reply["oe"]) is not bool:
                raise ValueError("输出状态格式错误")
            if "fast_supported" in reply:
                if type(reply["fast_supported"]) is not bool or type(reply.get("fast_mhz")) is not int or reply["fast_mhz"] not in (0, 1, 3, 5):
                    raise ValueError("高速模式字段格式错误")
                if type(reply.get("fast_edges")) is not int or not 0 <= reply["fast_edges"] <= 0xffffffff:
                    raise ValueError("高速计数格式错误")
                if reply["fast_mhz"] and (not reply["fast_supported"] or reply["blink_ms"]):
                    raise ValueError("高速与慢速模式冲突")
                if "fast_variable" in reply:
                    ticks = reply.get("fast_ticks")
                    if type(reply["fast_variable"]) is not bool or type(ticks) is not int or not (ticks == 0 or 30 <= ticks <= 150_000_000):
                        raise ValueError("可编程分频字段格式错误")
                    if reply["fast_variable"] and not reply["fast_supported"]:
                        raise ValueError("可编程方波能力冲突")
                    if ticks and (not reply["fast_variable"] or reply["blink_ms"]):
                        raise ValueError("方波与慢速模式冲突")
                    if reply["fast_mhz"] and ticks != 150 // reply["fast_mhz"]:
                        raise ValueError("方波频率与分频读数不一致")
            if "mt_supported" in reply:
                if type(reply["mt_supported"]) is not bool or type(reply.get("mt_running")) is not bool:
                    raise ValueError("MT 能力字段格式错误")
                period, loaded = reply.get("mt_period"), reply.get("mt_loaded")
                if type(period) is not int or type(loaded) is not int or not 0 <= loaded <= 2048:
                    raise ValueError("MT 状态字段格式错误")
                if reply["mt_supported"] and not 60 <= period <= 300_000_000:
                    raise ValueError("MT 周期超出范围")
                if reply["mt_running"] and (not reply["mt_supported"] or reply["blink_ms"] or reply.get("fast_ticks", 0)):
                    raise ValueError("MT 与其他运行模式冲突")
            if "qam_supported" in reply:
                if type(reply["qam_supported"]) is not bool:
                    raise ValueError("QAM能力字段格式错误")
                if reply["qam_supported"]:
                    limits = {"qam_abi": (1, 1), "qam_status": (0, 31), "qam_error": (0, 4),
                              "qam_received": (0, 242744), "qam_expected": (0, 242744),
                              "qam_crc": (0, 0xffffffff), "qam_slot_ticks": (1 if reply.get("qam_order") == 64 else 60, 1000000),
                              "qam_repeats": (1, 1000000), "qam_period_slots": (1, 65535),
                              "qam_frames": (0, 2048), "qam_events": (0, 32768),
                              "qam_symbols": (0, 256), "qam_payload": (0, 4096),
                              "qam_max_frames": (1, 2048), "qam_max_events": (1, 32768),
                              "qam_max_payload": (1, 4096), "qam_min_ticks": (60, 1000000),
                              "qam_max_ticks": (60, 1000000), "qam_clock_hz": (300000000, 300000000)}
                    for key, (low, high) in limits.items():
                        if type(reply.get(key)) is not int or not low <= reply[key] <= high:
                            raise ValueError(f"QAM状态字段格式错误：{key}")
                    if any(key in reply for key in ("qam64_supported", "qam_order", "qam64_min_event_ticks")):
                        if type(reply["qam64_supported"]) is not bool or type(reply.get("qam_order")) is not int or reply["qam_order"] not in (64,256):
                            raise ValueError("64QAM能力或阶数错误")
                        if reply["qam64_supported"] and reply.get("qam64_min_event_ticks") != 29:
                            raise ValueError("64QAM最短边沿间隔错误")
                        if reply["qam_order"] == 64 and (not reply["qam64_supported"] or reply["qam_slot_ticks"] != 1):
                            raise ValueError("64QAM计时模式错误")
                    if "qam_prefix_supported" in reply:
                        if type(reply["qam_prefix_supported"]) is not bool:
                            raise ValueError("独立前导码能力字段无效")
                        for key, high in (("qam_max_prefix",14), ("qam_prefix_count",14), ("qam_preamble_rows",10)):
                            if type(reply.get(key)) is not int or not 0 <= reply[key] <= high:
                                raise ValueError("独立前导码状态字段无效")
                    if any(type(reply.get(key)) is not bool for key in ("qam_uploading", "qam_loop")):
                        raise ValueError("QAM模式字段格式错误")
                    if reply["qam_min_ticks"] > reply["qam_max_ticks"]:
                        raise ValueError("QAM时序能力矛盾")
                    if reply["qam_status"] & 2 and (not reply["qam_status"] & 1 or reply.get("mt_running") or reply.get("fast_ticks") or reply["blink_ms"]):
                        raise ValueError("QAM运行状态与其他模式冲突")
        except (KeyError, TypeError, ValueError) as error:
            raise ProtocolError(f"无法识别板卡响应：{error}") from error
        return reply

    def upload_qam(self, plan, cancel, progress=lambda *_: None):
        """Only called after the global apply gate; no mutating request retries."""
        plan.check_capability(self.command("STATUS"))
        received = 0
        for command in plan.commands():
            if cancel.is_set():
                reply = self.command("STOP")
                if not reply["ok"]: raise ProtocolError("QAM取消后的STOP未确认")
                return reply, True
            reply = self.command(command)
            if not reply["ok"] or reply["errors"]:
                # Packet reached the device and was explicitly rejected.
                # Abort this authorized upload; never start a partial table.
                cleanup = self.command("STOP")
                raise ProtocolError(f"QAM上传/启动被拒绝：{command.split()[0]} rc={reply['rc']}；停止{'已确认' if cleanup['ok'] else '未确认'}")
            if command.startswith("QDATA "):
                received += len(command.split()[3]) // 2
                if reply.get("qam_received") != received:
                    self.command("STOP")
                    raise ProtocolError("QAM分块确认字节数不一致，上传已中止")
                progress(received, plan.total_bytes)
        if cancel.is_set():
            reply = self.command("STOP")
            if not reply["ok"]: raise ProtocolError("QAM取消后的STOP未确认")
            return reply, True
        if (reply.get("qam_crc") != plan.crc or not reply.get("qam_status", 0) & 1 or reply.get("qam_error") or
            reply.get("qam_slot_ticks") != plan.slot_ticks or reply.get("qam_repeats") != plan.repeats or
            reply.get("qam_period_slots") != plan.slots or reply.get("qam_loop") is not plan.loop or
            (plan.base_period_ticks and reply.get("qam_order") != 64) or
            (plan.independent_prefix and (reply.get("qam_prefix_count") != len(plan.prefix_descriptors)//4 or
                                         reply.get("qam_preamble_rows") != (len(plan.preamble.rows) if plan.preamble else 0)))):
            self.command("STOP")
            raise ProtocolError("QAM启动确认与本次配置快照不一致，已请求停止")
        return reply, False

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()
