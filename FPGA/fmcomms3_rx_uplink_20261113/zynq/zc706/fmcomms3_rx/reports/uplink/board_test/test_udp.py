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

ip("addr", "del", f"{receiver}/24", "dev", nic)
try:
    ip("addr", "add", f"{peer}/24", "dev", nic)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sink:
        sink.bind((peer, 7061))
        sink.settimeout(8)
        for seq, kind, payload in ((4201, 1, "收端 PL 实测".encode()),
                                   (4202, 0, bytes(range(256)) * 4)):
            start = time.monotonic()
            reply = send_command(f"UPLINK {seq} {kind} {payload.hex()}")
            assert (reply["sequence"], reply["length"]) == (seq, len(payload))
            got_seq, got_kind, got_payload, stamp = receive_frame(sink)
            assert (got_seq, got_kind, got_payload) == (seq, kind, payload)
            print(json.dumps(dict(source=f"{receiver}:7061", destination=f"{peer}:7061",
                                  seq=seq, kind=kind, length=len(payload), rx_ms=stamp,
                                  host_ms=round((time.monotonic() - start) * 1000),
                                  crc="PASS", bytes_equal=True)), flush=True)
finally:
    subprocess.run(("ip", "addr", "del", f"{peer}/24", "dev", nic), check=False)
    ip("addr", "add", f"{receiver}/24", "dev", nic)
