#!/usr/bin/env python3
"""Live network/AXI test. Changes outputs; always finishes with all LOW."""
import argparse
import json
from pathlib import Path
import socket
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "host"))
from ris_client import DEFAULT_HOST, DEFAULT_PORT, RisClient


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    args = parser.parse_args()
    with RisClient(args.host, args.port) as client:
        def check(command, expected=None, advance=None, ok=True):
            before = client.command("STATUS")
            reply = client.command(command)
            assert reply["ok"] == ok and reply["errors"] == 0, reply
            if expected is not None:
                assert bytes.fromhex(reply["image"]) == bytes(expected), reply
            if advance is not None:
                assert reply["frames"] == before["frames"] + advance, reply
            print(f"PASS: {command[:45]} rc={reply['rc']} frames={reply['frames']}")
            return reply

        try:
            check("ALL 0", bytes(50), 1)
            check("ALL 1", bytes([255]) * 50, 1)
            check("ALL 0", bytes(50), 1)
            image = bytearray(50)
            for index in (0, 49):
                image[index] = 0x81
                check(f"CHIP {index} 81", image, 1)
            image[45:50] = bytes([0xAA]) * 5
            check("GROUP 9 AA", image, 1)
            image[49] &= 0x7f
            check("BIT 49 7 0", image, 1)
            image = bytes((i * 37) & 255 for i in range(50))
            check("FRAME " + image.hex(), image, 1)
            for invalid in ("CHIP 50 FF", "CHIP -1 FF", "CHIP 0 GG", "GROUP 10 FF", "BIT 0 8 1", "ALL 2", "BLINK 99", "FRAME 00", "OE 2", "STATUS junk"):
                check(invalid, image, 0, ok=False)
            assert not check("OE 0", image, 0)["oe"]
            assert check("OE 1", image, 0)["oe"]
            check("ALL 0", bytes(50), 1)
            started = check("BLINK 200")
            time.sleep(0.55)
            reply = client.command("STATUS")
            assert reply["blink_ms"] == 200 and reply["frames"] >= started["frames"] + 2
            stopped = check("STOP")
            time.sleep(0.3)
            assert client.command("STATUS")["frames"] == stopped["frames"]
            print("PASS: periodic switching and STOP hold")
        finally:
            client.command("ALL 0")
    time.sleep(0.1)
    with socket.create_connection((args.host, args.port), timeout=3) as raw:
        for part in (b"123 STA", b"TU", b"S\n"):
            raw.sendall(part)
            time.sleep(0.02)
        data = bytearray()
        while b"\n" not in data:
            data.extend(raw.recv(1024))
        reply = json.loads(data)
        assert reply["id"] == 123 and reply["ok"] and reply["image"] == "00" * 50
    print("PASS: fragmented TCP request and reconnect")
    print("RIS_NETWORK_TEST_PASS: real lwIP/AXI/50 mirrors; final all LOW, OE enabled")


if __name__ == "__main__":
    main()
