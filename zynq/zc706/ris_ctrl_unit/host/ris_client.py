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
        except (KeyError, TypeError, ValueError) as error:
            raise ProtocolError(f"无法识别板卡响应：{error}") from error
        return reply

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()
