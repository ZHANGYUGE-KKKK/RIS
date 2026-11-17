import json
import socket
import struct
import subprocess
import time
import zlib

nic = "enx6c1ff767213a"
receiver = "192.168.2.12"
peer = "192.168.2.11"

def ip(*args):
    subprocess.run(("ip", *args), check=True)

def send_command(command):
    with socket.create_connection(("192.168.1.10", 5001), timeout=12) as control:
        control.sendall(command.encode("ascii") + b"\n")
        with control.makefile("rb") as reader:
            reply = json.loads(reader.readline())
    if reply.get("ok") is not True:
        raise RuntimeError(reply)
    return reply

def receive_frame(sink):
    raw, source = sink.recvfrom(2048)
    assert source == (receiver, 7061), source
    magic, version, header, kind, zero, seq, length, reserved, stamp, crc = struct.unpack(
        "!4sBBBBIHHII", raw[:24])
    assert (magic, version, header, zero, reserved) == (b"RUP1", 1, 24, 0, 0)
    assert length == len(raw) - header
    body = raw[24:]
    assert zlib.crc32(raw[:20] + body) == crc
    return seq, kind, body, stamp


from pathlib import Path
from hashlib import sha256

directory = Path(__file__).resolve().parent
iq = directory / "pwm3_known_iq.bin"
assert sha256(iq.read_bytes()).hexdigest() == "044472b966fc6230a7df64434ca950e9cea60c9773da483b4b566fceaeba67c7"
xsct = "/home/wenhan/SOFTWARE/VIVADO2022.2/Vitis/2022.2/bin/xsct"
truth = {1: "01234567", 2: "76543210", 3: "02461357"}

ip("addr", "del", f"{receiver}/24", "dev", nic)
try:
    ip("addr", "add", f"{peer}/24", "dev", nic)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sink:
        sink.bind((peer, 7061))
        sink.settimeout(15)
        marker = b"PWM3 replay ARP check"
        send_command(f"UPLINK 4299 1 {marker.hex()}")
        assert receive_frame(sink)[:3] == (4299, 1, marker)
        with (directory / "replay_xsct.log").open("w") as log:
            result = subprocess.run(("runuser", "-u", "wenhan", "--", xsct, "-nodisp",
                                     str(directory / "replay.tcl")),
                                    stdout=log, stderr=subprocess.STDOUT, timeout=55)
        print((directory / "replay_xsct.log").read_text(), end="", flush=True)
        result.check_returncode()
        seq, kind, payload, stamp = receive_frame(sink)
        report = json.loads(payload)
        assert kind == 1 and report["type"] == "pwm3"
        assert abs(report["carrier_hz"] - 798036) < 100, report
        assert len(report["frames"]) == 15, report
        for index, frame in enumerate(report["frames"]):
            user = index % 3 + 1
            assert frame == {"user": user, "symbols": truth[user]}, (index, frame)
        print(json.dumps(dict(result="PWM3_BOARD_REPLAY_PASS", sequence=seq, rx_ms=stamp,
                              source=f"{receiver}:7061", destination=f"{peer}:7061",
                              crc="PASS", **report)), flush=True)
finally:
    subprocess.run(("ip", "addr", "del", f"{peer}/24", "dev", nic), check=False)
    ip("addr", "add", f"{receiver}/24", "dev", nic)
